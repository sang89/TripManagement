# Invite Flow

Reference for the full lifecycle of trip member invitations — from adding a member through accepting, declining, leaving, blocking, and re-inviting.

---

## Actors & Roles

| Actor | `trip_members.role` | Can invite others? | Can leave? |
|---|---|---|---|
| **Organizer** | `organizer` | Yes | No (owns the trip) |
| **Accepted member** | `member`, status `accepted` | Yes | Yes |
| **Pending invitee** | `member`, status `pending` | No | — (accept/decline instead) |

---

## Status Lifecycle

```
INSERT → 'pending'          ← new linked-user invite
              │
    ┌─────────┴──────────┐
    ▼                    ▼
'accepted'           'declined'  ← invitee acts on InvitationsProvider
    │                    │
    ▼ (leave)            │
 'left'  ◄───────────────┘  (also reachable directly)
    │
    └── re-invite via upsert → 'pending' again
            (blocked by block_reinvite = true if opted out)
```

Guest members (`user_id IS NULL`) are inserted directly as `accepted` — no pending step.

---

## Adding a Member (`AddMemberSheet`)

**Entry points:**
- FAB on the Overview tab of `TripDetailScreen` — available to organizer and accepted members (`canInvite` flag)
- "Add member" button in `TripFormScreen` — available during create AND edit

**Lookup flow:**
1. User types name + email/phone in `AddMemberSheet`.
2. A debounced lookup (300 ms) fires only when the email passes `_isValidEmail()` or the phone is non-empty.
3. A generation counter (`_lookupGeneration`) discards stale responses when the user types faster than the network responds.
4. Calls `find_user_by_contact(p_email, p_phone)` Supabase function → returns `{user_id, full_name}` or null.
5. Shows status chip: "Searching…" → "Account found" / "No account found".

**Provider call:**
```dart
TripProvider.addMember(tripId, displayName:, email:, phone:, userId:)
```

**Logic in `addMember()`:**
- **Fast-reject**: if in-memory trip already has a member with this `userId` and `blockReinvite = true` → throws `ReinviteBlockedException` immediately (no network call).
- **Linked user** (`userId != null`): `.upsert(onConflict: 'trip_id,user_id')` — reactivates a `left`/`declined` row to `pending` instead of inserting a duplicate.
- **Guest** (`userId == null`): plain `.insert()`, status `accepted` immediately.
- **In-memory**: replaces existing member by `userId` if found; otherwise appends.

**DB trigger fires** (`on_invite_inserted` AFTER INSERT OR UPDATE):
- Condition: `new.status = 'pending' AND new.user_id IS NOT NULL AND (INSERT OR old.status ≠ 'pending')`
- Calls `send-invite-notification` Edge Function via `pg_net` → FCM push to invitee's devices.

---

## Receiving an Invitation

`InvitationsProvider` subscribes to `trip_members` Realtime (INSERT + UPDATE filtered by `user_id = currentUser`). When a new `pending` row arrives:
1. `_fetch()` reloads all pending rows for this user.
2. The invite banner in `TripsScreen` updates immediately — no re-login needed.
3. A FCM push notification is delivered in parallel (if permission granted).

If push permission was **denied**: no FCM token is registered → `send-invite-notification` returns `{sent:0, reason:'no_device_tokens'}` gracefully. The in-app banner via Realtime is the primary path and still works.

---

## Accepting an Invitation

`InvitationsProvider.accept(memberId, tripProvider)`:
1. UPDATEs `status = 'accepted'` on the member row.
2. Removes the invite from the local `_invites` list.
3. Calls `tripProvider.load()` — newly accepted trip appears in the Trips list.

**RLS:** `trip_members_update_own_status` (USING: `user_id = auth.uid()`).

---

## Declining an Invitation

Tapping **Decline** on the invite card opens a confirmation dialog with a checkbox:

> ☐ Don't allow future invitations to this trip

`InvitationsProvider.decline(memberId, tripProvider, {blockReinvite: bool})`:
1. UPDATEs `status = 'declined'` (and optionally `block_reinvite = true`).
2. Removes from local `_invites`.
3. Calls `tripProvider.load()` (trip is removed from their list since RLS no longer grants access).

**RLS:** `trip_members_update_own_status`.

---

## Leaving an Accepted Trip

Available from:
- **Trips list** — swipe left → Leave (for non-organizer trips)
- **Trip detail AppBar** — `Icons.exit_to_app_outlined` button (non-organizer only)

Both open a confirmation dialog with the same checkbox:

> ☐ Don't allow future invitations to this trip

`TripProvider.leaveTrip(tripId, {blockReinvite: bool})`:
1. UPDATEs `status = 'left'` (and optionally `block_reinvite = true`) on the user's own member row.
2. Removes the trip from the local `_trips` list immediately.
3. Other members see a **"Left"** chip via the Realtime UPDATE handler (no page reload needed).

**Why UPDATE instead of DELETE:** preserves the row so other members' Realtime UPDATE handler can display the "Left" chip. `REPLICA IDENTITY FULL` is set on `trip_members` so DELETE payloads would include `trip_id`, but UPDATE is preferred to keep the record visible.

**RLS:** `trip_members_update_own_status` (user updates their own row).

---

## Blocking Future Invitations (`block_reinvite`)

Setting `block_reinvite = true` (via the checkbox on leave or decline) writes a permanent opt-out to the `trip_members` row.

**Enforcement layers (in order):**

| Layer | Where | Mechanism |
|---|---|---|
| 1. In-memory fast-reject | `TripProvider.addMember()` | Scans `trip.members` — if `blockReinvite = true` → throws `ReinviteBlockedException` immediately |
| 2. DB trigger | `on_member_reinvite_check` (BEFORE UPDATE) | `prevent_blocked_reinvite()` raises `blocked_reinvite` exception if `old.block_reinvite = true AND new.status = 'pending'` |

**UI error message:** `l10n.reinviteBlockedError` — *"This user has opted out of future invitations to this trip"*  
Shown as a red snackbar (Trip Detail) or inline error text (Edit Trip form).

**RLS note:** `block_reinvite` is writable only by the invitee themselves via `trip_members_update_own_status`. The organizer cannot clear it.

---

## Re-Inviting Someone Who Left or Declined

If `block_reinvite = false`:

1. Organizer/member taps "Add member" and searches for the user.
2. `addMember()` calls `.upsert(onConflict: 'trip_id,user_id')`.
3. **RLS `trip_members_reinvite` policy** allows the UPDATE:
   - USING: `old.status in ('left','declined')` AND caller is organizer or accepted member
   - WITH CHECK: `new.status = 'pending'`
4. Row updated in-place — same UUID preserved, status reset to `pending`.
5. `on_invite_inserted` UPDATE trigger fires → new FCM push sent.

**In the Edit Trip form:**
- If test1 has `status = 'left'`, adding them again via the sheet updates the existing chip in-place to "Pending" (no duplicate row shown).
- `_reinvitedUserIds` tracks which userIds were re-invited in this session.
- At save time, an extra loop calls `addMember()` for each reinvited userId.

---

## RLS Policies Summary (trip_members)

| Policy | Op | USING (old row) | WITH CHECK (new row) |
|---|---|---|---|
| `trip_members_select` | SELECT | organizer OR member OR pending invitee | — |
| `trip_members_insert` | INSERT | — | organizer OR accepted member |
| `trip_members_update_own_status` | UPDATE | `user_id = auth.uid()` | `user_id = auth.uid()` |
| `trip_members_reinvite` | UPDATE | `status in ('left','declined')` AND caller is organizer/member | `status = 'pending'` |
| `trip_members_leave` | DELETE | `user_id = auth.uid()` | — |

---

## DB Objects Reference

| Object | Type | Purpose |
|---|---|---|
| `find_user_by_contact(p_email, p_phone)` | Function | Account lookup by email or phone for the add-member sheet |
| `auth_user_is_trip_member(p_trip_id)` | Function (SECURITY DEFINER) | True if current user has `accepted` row for the trip — used in RLS to avoid recursion |
| `auth_user_has_pending_invite(p_trip_id)` | Function (SECURITY DEFINER) | True if current user has `pending` row — lets invitees read trip details |
| `get_profile_names(p_user_ids uuid[])` | Function (SECURITY DEFINER) | Returns `(user_id, full_name)` for a batch of user IDs, bypassing `user_profiles` RLS. Called by `TripProvider._enrichMemberNames()` after load to patch display names. Falls back to email when `full_name` is blank. Callable by `authenticated` role only. |
| `handle_new_invite()` | Trigger function | Calls send-invite-notification on INSERT or status→pending UPDATE |
| `prevent_blocked_reinvite()` | Trigger function | Blocks re-invite if `block_reinvite = true` |
| `on_invite_inserted` | Trigger (AFTER INSERT OR UPDATE) | Runs `handle_new_invite()` |
| `on_member_reinvite_check` | Trigger (BEFORE UPDATE) | Runs `prevent_blocked_reinvite()` |
| `trip_members_trip_user_unique` | UNIQUE CONSTRAINT on `(trip_id, user_id)` | Enables upsert; NULLs treated as distinct so guests are unaffected |
| `device_tokens` | Table | FCM tokens per user/device; stale tokens auto-deleted by Edge Function |
| `send-invite-notification` | Edge Function | Sends FCM push via service-account OAuth2; called by pg_net trigger |
