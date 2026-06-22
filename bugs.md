# Known Bugs, Gotchas & Audit Checklists

> **Keep this file current.** When a non-obvious bug is fixed, add an entry here so future
> sessions don't re-introduce it. When a new feature area has subtle invariants that aren't
> obvious from the code, document them here as a checklist.

---

## Signup events

Signup events are the most complex event type — sessions, rosters, attendance, QR signup, and
approval flows all interact. Every change to signup code must be audited against the scenarios
below before marking the task complete.

### Fixed bugs (regression tests in `test/models/event_session_test.dart` and `test/providers/event_provider_session_test.dart`)

| # | File | What went wrong | Fix |
|---|---|---|---|
| 1 | `event_detail_screen.dart`, `event_provider.dart`, `event_session.dart` | `_AttendanceChip` callback type was `void Function(bool)` — null couldn't be passed, so the cycle was `null → true → false → true` instead of `null → true → false → null`. The "no-show → unset" step was unreachable. | Added `clearAttended` flag to `copyWith`; changed callback and `markSessionAttendance` to accept `bool?`. |
| 2 | `session_scan_screen.dart` | `rsvp_session` can return `pending_review` for approval-gated sessions. The snackbar only checked `waitlisted`, so `pending_review` users saw "You're confirmed at position #N". | Added `status == 'pending_review'` branch showing `signupPendingReview` string. |
| 3 | `session_invite_screen.dart` | Same `pending_review` issue — success screen showed green check + "confirmed" message. | Added `isPendingReview` branches; shows amber `pending_actions` icon + correct message. |
| 4 | `event_provider.dart` (`_subscribeRealtime`) | The `event_sessions UPDATE` Realtime handler called `copyWithCounts(goingCount, waitlistCount)` only. When an organizer edited capacity, dates, `requiresApproval`, etc. on another device, other clients kept stale values indefinitely. | Handler now rebuilds via `EventSession.fromJson({...payload fields merged with existing...})` so all fields propagate. |
| 5 | `event_detail_screen.dart` | The promote-button guard used `confirmed.length < cap` where `confirmed` is the in-memory paginated roster slice (up to 100 entries). A session with 120 going entries would show the promote button as enabled even though it was full. | Changed guard to `widget.session.goingCount < cap` (DB-authoritative denormalized count). |
| A | `event_detail_screen.dart` (`_SignupCTAButton`) | `build()` computed its own `label = isWaitlist ? '...' : '...'` and discarded `widget.label`. The parent passed `'🔍  Request to join'` for `requiresApproval` sessions, but the button always showed "Claim your spot". | Changed to `final label = widget.label;`. |
| B | `event_detail_screen.dart` (member status chip) | Non-organizer status chip only had an explicit branch for `going`; everything else fell through to the waitlist chip. For `pending_review` users, `my.order` is 0, so the chip showed `⏳ #0 wait`. | Added `else if (my.status == 'pending_review')` showing `🔍 Pending` in purple. |
| C | `event_provider.dart` (`refreshSessionRoster`) | When fetching the first roster page (100 entries), the method called `_mySessionStatuses.remove(sessionId)` whenever the current user wasn't found. For sessions with >100 attendees, a user at position #101+ lost their "Cancel my spot" button until the full roster was loaded. | Only clears `_mySessionStatuses` when `hasMore == false` (all entries loaded and user genuinely absent). |
| D | `event_detail_screen.dart` (`_AddSessionGuestButton`) | `catch (_) {}` silently swallowed every error (locked session, full with no waitlist, duplicate). The sheet always closed as if success, giving the organizer no feedback. Also called `fetchUpcomingSessions` but NOT `refreshSessionRoster`, so the new entry never appeared in the expanded card. | Added error snackbar; sheet stays open on error; calls `refreshSessionRoster` + `fetchUpcomingSessions` on success. |
| E | `session_scan_screen.dart` (`_SessionJoinSheet`, `_showSessionJoinSheet`) | `requires_approval` was never read from the session payload. For approval-gated sessions the sheet always showed "Claim your spot", giving users false expectations — they'd get `pending_review` status instead. | Added `requiresApproval` field; sheet shows "Request to join" button and a disclaimer when true. |
| F | `session_invite_screen.dart` | Same `requires_approval` blind spot as Bug E. Form header and submit button both showed "Claim your spot". | Read `requires_approval` from payload; show "Request to join" header + approval disclaimer + correct button label. |
| G | `event_provider.dart` (`reorderSessionRoster`, Realtime INSERT/UPDATE handlers) | `reorderSessionRoster` updated `signupOrder` field values but never re-sorted the in-memory list. Realtime INSERT sorted by `(signupOrder ?? 0)` treating `pending_review` entries (null order) as position 0. Realtime UPDATE patched fields without resorting. Other devices saw stale visual order after any reorder or promotion. | Added `_rosterOrder` comparator (null last) used by all three code paths; `_patchRosterEntry` gains `resort` flag. |
| H | `migrations/...revert_paid_registration.sql` → `get_session_by_invite_code` | **RPC return-column dropped during an unrelated revert.** The migration that reverted paid-registration redefined `get_session_by_invite_code` and silently omitted `requires_approval` from its `RETURNS TABLE`. Bugs E/F had taught `session_scan_screen.dart` + `session_invite_screen.dart` to read `requires_approval` — but the getter no longer returned it, so `s['requires_approval'] as bool? ?? false` was always `false`, re-introducing the exact symptom E/F fixed (QR/code joiners of approval-gated sessions saw "Claim spot" instead of "Request to join"). The in-app path was unaffected because it reads the `EventSession` model from `.select()`. | New migration `20260620000000_session_invite_requires_approval.sql` re-adds `requires_approval` to the getter's `RETURNS TABLE` + `SELECT` + `GROUP BY`. **Gotcha:** when a `DROP FUNCTION ... RETURNS TABLE(...)` is rewritten during a revert/refactor, diff the column list against every Dart `rpc(...)` caller — a dropped column fails silently as a runtime `null`, not a compile or query error. |

### Known limitation (low priority, documented)

- **`loadMoreRoster` drops `pending_review` entries in paginated sessions** — Fixed in B10 (cursor now uses `signed_up_at + id`). Previously the `signup_order`-based cursor never matched `null`-order pending_review entries.

### Design decision (B4): `pending_review` entries are NOT auto-promoted

When a `going` member cancels or is removed, `cancel_session_signup` and
`session_remove_roster_entry` auto-promote the **top waitlisted** entry only.
`pending_review` entries are **intentionally skipped** — they require explicit
organizer approval via `session_approve_request`.

**Why:** `pending_review` means the organizer has not yet decided to admit this
person. Auto-promoting them would bypass the approval gate entirely. The correct
flow is: spot opens → organizer sees the pending badge → organizer approves the
candidate they prefer.

**Invariant:** A `pending_review` entry NEVER automatically becomes `going` or
`waitlisted`. Only `session_approve_request` (sets `going`) or
`session_reject_request` (deletes + notifies) can change its state.

### Invariants to verify on every signup change

**Organizer perspective**
- **Add session** — session appears in upcoming list; capacity/lock/approval settings saved; auto-add self and pre-add names produce going roster entries with sequential `signup_order`.
- **Edit session** — capacity, `requiresApproval`, `signupLockHours`, `isPublic`, `start_at`, `end_at` changes propagate to **all clients** via Realtime. The `event_sessions UPDATE` handler must reconstruct all fields, not just counts (see Bug 4).
- **Promote / demote** — promote button guard uses `session.goingCount` (DB count), not `roster.length` (paginated slice). See Bug 5.
- **Attendance marking** — chip cycles **null → true → false → null** (three states). Callback is `void Function(bool?)`. See Bug 1.
- **Approve / reject** — `approveSessionRosterEntry` reloads the full roster page 1 (to get the new `signup_order` from the DB); `rejectSessionRosterEntry` removes the entry in-place and does NOT refresh counts — rely on Realtime trigger for count update.
- **Manual add (organizer)** — `_AddSessionGuestButton` must call BOTH `refreshSessionRoster` AND `fetchUpcomingSessions` after success; must show a snackbar on error and keep the sheet open. See Bug D.
- **Reorder roster** — `reorderSessionRoster` updates `signupOrder` values AND re-sorts the in-memory list using `_rosterOrder`. See Bug G.
- **Invite tab** — QR code and link are per-session (each session has its own `invite_code`); session picker must update both.
- **`requiresApproval` in join UIs** — all three join entry points (`_SignupCTAButton`, `_SessionJoinSheet`, `SessionInviteScreen`) must read `requires_approval` and show "Request to join" label + approval disclaimer. See Bugs A, E, F.

**Member / attendee perspective (non-organizer)**
- **Status chip** — three distinct visual states: `✓ Going` (green), `⏳ #N wait` (orange), `🔍 Pending` (purple). Do NOT fall through `pending_review` to the waitlist chip. See Bug B.
- **CTA button label** — `_SignupCTAButton.build()` uses `widget.label`. Never recompute the label inside the build method. See Bug A.
- **Cancel spot** — available when `!isLocked && myEntry != null && myEntry.status != 'pending_review'`. Pending-review users see a locked-style banner instead.
- **Post-RSVP snackbar** — `rsvp_session` returns `going`, `waitlisted`, or `pending_review`. All three must show a distinct message. See Bugs 2, 3.
- **myStatus after `refreshSessionRoster`** — only clear `_mySessionStatuses[sessionId]` when `hasMore == false`. See Bug C.
- **Roster visual order** — `_sessionRosters[sessionId]` is always kept sorted by `_rosterOrder` (ascending `signup_order`, nulls last). Never use `(signupOrder ?? 0)` as a sort key — that puts `pending_review` entries at position 0. See Bug G.

### Test files for signup
- `test/models/event_session_test.dart` — model: `copyWith`/`clearAttended`, attendance cycle, `pending_review` status, Realtime field preservation, `isFull` from `goingCount`, roster pagination invariant.
- `test/providers/event_provider_session_test.dart` — cache accessor defaults, Realtime merge pattern, promote-guard, `requiresApproval` label selection, myStatus pagination logic.
- Add widget tests when new UI state paths are introduced (status chip variants, CTA label variants).

---

## Realtime delivery rules — hard-won lessons

### Rule 1: Unfiltered Postgres Changes + restricted RLS = unreliable delivery

Supabase Realtime Postgres Changes **requires an explicit `filter` parameter** for tables where the subscriber has a restricted SELECT policy. Without a filter, Supabase evaluates RLS server-side to decide who gets each event — and for non-organizer members this evaluation is unreliable in practice (events are silently dropped).

**What works:**
- Organizer subscriptions (unfiltered) — organizer has "full access" SELECT policy, always receives all events ✓
- Filtered subscriptions `user_id = eq.<userId>` — Supabase matches the filter directly without RLS evaluation ✓
- `event_sessions UPDATE` (unfiltered) — all members have unrestricted SELECT on sessions ✓

**What doesn't work reliably:**
- Unfiltered `event_session_roster` DELETE for non-organizer members (e.g. kick, reject)
- Unfiltered `event_session_roster` UPDATE for non-organizer members

### Rule 2: SECURITY DEFINER DELETE in a function = UPDATE-before-DELETE pattern required

When a SECURITY DEFINER function does `DELETE FROM table`, the WAL change is generated under the function owner's role. Supabase Realtime may not reliably deliver this DELETE to subscribers with restricted policies.

**Fix pattern:** UPDATE the row status to a transient signal value (`'rejected'`, `'removed'`) first, then DELETE. The UPDATE event is reliably received (row still exists during RLS evaluation). The app treats `'rejected'`/`'removed'` as a removal signal.

Migrations: `20260612000002_reject_realtime_fix.sql`, `20260612000003_remove_realtime_fix.sql`

### Rule 3: `notifyListeners()` can be swallowed when Flutter considers the widget already clean

If `notifyListeners()` fires twice in quick succession (e.g. once from the Realtime handler and once from the subsequent async `refreshSessionRoster`), Flutter may process the first rebuild and mark the widget clean before the second fires. The second `notifyListeners()` is then a no-op.

**Fix:** Use a `StreamController<String>.broadcast()` (see `EventProvider.sessionStatusCleared`). Widgets subscribe to this stream and call `setState()` directly — this is unconditional and always triggers a rebuild, bypassing the scheduler/dirty-check mechanism.

### Rule 4: `event_sessions UPDATE` is the universal reliable signal

The DB trigger `trg_session_roster_counts` fires `event_sessions UPDATE` whenever `going_count` or `waitlist_count` changes. This event reliably reaches ALL subscribers (every member can SELECT event_sessions). Piggybacking `refreshSessionRoster` on this event keeps roster cards in sync for everyone — including non-organizer members who wouldn't otherwise receive individual `event_session_roster` DELETE events.

---

## Notification system

### Rule 5: `insert_notification` originally used `ON CONFLICT DO NOTHING` — silent deduplication

The `notifications` table has a partial unique index on `(user_id, type, reference_id) WHERE reference_id IS NOT NULL` (from PropertyManagement's `lease_expiry` deduplication). `insert_notification` originally used `ON CONFLICT DO NOTHING`, which silently swallowed any notification that shared the same `(user_id, type, session_id/event_id)` combination as an existing row. When a user tested the same action more than once (e.g. invite, remove from session, approve join request), the second notification was silently dropped — the trigger fired and ran to completion without error, but the row was never inserted.

**Symptom:** Bell badge never changed, even after waiting for the 30-second polling cycle.

**Fix:** Changed `insert_notification` to `ON CONFLICT ... DO UPDATE SET is_read = false, created_at = now(), title/body/metadata = EXCLUDED.*`. Repeat actions now refresh the existing notification to unread rather than disappearing silently. Migration: `20260613000003_fix_notification_upsert.sql`.

### Rule 6: `broadcast_notification` trigger must fire on INSERT OR UPDATE

The DB trigger that sends a Realtime Broadcast to wake the Flutter client originally fired `AFTER INSERT` only. After the ON CONFLICT fix (Rule 5), a duplicate notification becomes an UPDATE, not an INSERT. The broadcast trigger never fired, so the Flutter client was not notified in real time. The 30-second poll would eventually catch new inserts, but not upserted (refreshed) notifications.

**Fix:** Changed `on_notification_inserted` trigger to `AFTER INSERT OR UPDATE`; added a guard `IF NEW.is_read = true THEN RETURN NEW` so mark-as-read operations do not trigger unnecessary broadcasts. Migration: `20260613000003_fix_notification_upsert.sql`.

### Rule 7: Broadcast callback should do a full reload, not incremental fetch

The `_fetchLatest()` incremental fetch deduplicates by notification ID. When an existing notification is upserted (same ID, new `is_read = false`), `_fetchLatest()` sees the row again (updated `created_at` satisfies the `gte` filter) but filters it out as "already known". The local state never reflects the refreshed unread status.

**Fix:** Changed the broadcast callback from `_fetchLatest()` to `_fetch()` (full reload). The 30-second poll timer still uses `_fetchLatest()` for efficiency — it only misses the upsert-refresh edge case, which the broadcast handles in real time.

---

## General gotchas

### go_router reuses the page on same-path navigation — deep-links to a tab/section are ignored
`context.go('/event/:id?tab=session&sessionId=X')` while already on `/event/:id` (or when go_router
otherwise reuses the page) does **not** re-run the screen's `initState`, because the **path is
unchanged** — only the query differs. Any state read once in `initState` (here: `initialTab`,
`initialSessionId` → the outer `TabController`'s initial index) is therefore silently ignored, and
the user stays on whatever tab they were on (the Live button "lands on Info instead of Session").
**Fix:** give the route a `pageBuilder` with a `ValueKey` that includes the deep-link target
(`'event-$id-$initialTab-$initialSessionId'`), so a different tab/section is a distinct page and
rebuilds fresh. **Lesson for tests:** a widget test that constructs the screen directly with the
target args ALWAYS gets a fresh `initState` and will pass while the real app fails — the e2e test
must drive the real `ShellScaffold` button → real GoRoute → real screen, including the "already on
the event" reuse path (see `test/screens/live_button_full_chain_test.dart`).



### A `State` that recreates a `TabController` must use `TickerProviderStateMixin` (plural)
`SingleTickerProviderStateMixin` permanently records that a ticker was created — disposing the old
`TabController` frees its ticker, but the mixin still throws *"multiple tickers were created"* on the
next `createTicker`. So any `State` that recreates its controller (in `didUpdateWidget` when the
event type changes, or in the `build` hot-reload/length guard) **must** use `TickerProviderStateMixin`.
This surfaced when the bottom-nav **Live** button (`ShellScaffold`) navigated between events of
different types: the reused `EventDetailScreen` rebuilt `_InfoTabGroup`/`_OrganizeTabGroup` with a new
event type, hit `didUpdateWidget`, and tried to recreate the `TabController` under the single-ticker
mixin → crash. Fixed by switching `_InfoTabGroupState`, `_OrganizeTabGroupState`, and
`_MemoriesTabGroupState` to `TickerProviderStateMixin`. **Invariant:** if a `State` ever reassigns
`_ctrl = TabController(...)` after `initState`, it cannot use `SingleTickerProviderStateMixin`.

### Events with no `endAt` never become "Past" automatically
"Past" was historically computed as `endAt != null && endAt < now`. Single-day events have
`endAt == null`, so this is **always false** — they stay "Ongoing"/Upcoming forever and pile up on
the landing page. The fix: `Event.isPastFor(userId)` is the single source of truth, combining
`isDatePast` (end date passed) with `isArchivedFor(userId)` (the user manually moved it to Past).
The per-user manual archive (`event_guests.is_archived`, toggled by `EventProvider.setEventArchived`,
surfaced via long-press on `EventCard`) is the intended mechanism for getting no-end-date events out
of Upcoming. **Invariant:** use `event.isPastFor(currentUserId)` everywhere you decide Upcoming vs
Past — never re-derive the `endAt < now` check inline (it will reintroduce this bug). `isArchived` is
per-user: only the actor's view changes; other members keep seeing the event in their Upcoming.

### Realtime UPDATE handlers must reconstruct all columns
When a Supabase Realtime UPDATE payload arrives, `payload.newRecord` contains the full row.
Do not use a `copyWith`-style partial update that only patches the fields you expect to change —
the organizer might have changed any field from another device. Always rebuild the full object
from the payload, falling back to the existing cached value for any missing key.

**Bad:**
```dart
(s) => s.copyWithCounts(goingCount: row['going_count'] ?? s.goingCount)
```

**Good:**
```dart
(s) => EventSession.fromJson({
  'id': s.id,
  'going_count': row['going_count'] ?? s.goingCount,
  'capacity': row.containsKey('capacity') ? row['capacity'] : s.capacity,
  // ... all other fields
})
```

### Three-nullable-state patterns need an explicit "clear" flag
Dart's `copyWith` pattern cannot distinguish "caller passed null" from "caller omitted the param".
Whenever a field is nullable and null is a meaningful value (not just "unchanged"), add a
`clearX = false` boolean parameter:

```dart
EventSessionRosterEntry copyWith({
  bool? attended,
  bool clearAttended = false,
  ...
}) => EventSessionRosterEntry(
  attended: clearAttended ? null : (attended ?? this.attended),
  ...
);
```

### `status` string comparisons — use all three signup values
`event_session_roster.status` has **three** values: `'going'`, `'waitlisted'`, `'pending_review'`.
Any `if`/`switch` that only handles two of them will silently misbehave for the third.
Always cover all three explicitly.

### Paginated roster — myStatus can outlive the visible page
`EventProvider._sessionRosters[sessionId]` holds at most `_kRosterPageSize` (100) entries.
`_mySessionStatuses[sessionId]` is the authoritative "am I signed up?" source and must not
be cleared based solely on absence from a paginated roster slice. Only clear it when the full
roster has been loaded (`hasMore == false`) and the user's entry genuinely does not exist.
