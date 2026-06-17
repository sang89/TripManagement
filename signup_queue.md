# Signup Event — Queue Up System

> **Keep this file current.** Any change to queue logic, DB schema, RPCs, or UI behaviour must be reflected here in the same session.

Full context on signup events lives in `architecture.md` (DB tables, Realtime coverage). This file covers only the queue-up sub-system that appears on the **Activity tab** of an active session.

---

## Concepts

| Term | Meaning |
|---|---|
| **Queue row** | A `session_queue_activities` record — one "game slot" with N spots (e.g. badminton court for 4 players) |
| **Entry** | A `session_queue_entries` record — one player occupying a spot in a queue row |
| **Free pool** | All event members who are checked-in but not in any queue — computed client-side, never stored |
| **Sort order** | Integer on each queue row controlling display order (#1, #2, …) |

---

## DB Tables

### `session_queue_activities`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | |
| `session_id` | uuid FK→event_sessions | |
| `name` | text | Display name (e.g. "Queue 1") |
| `players_per_round` | integer | Spots per row |
| `allow_duplicates` | boolean | Whether a player can appear in more than one row |
| `status` | text | `'waiting'` \| `'active'` \| `'ended'` — see Playing Status below |
| `sort_order` | integer | Controls display order; gaps allowed |
| `waiting_count` | integer | Denormalized; maintained by DB trigger |
| `playing_count` | integer | Denormalized; maintained by DB trigger |

### `session_queue_entries`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `activity_id` | uuid FK→session_queue_activities CASCADE | |
| `user_id` | uuid nullable | NULL for anonymous/guest members |
| `display_name` | text | Always populated |
| `avatar_url` | text nullable | |
| `queue_position` | integer | 1-based; lower = earlier in list |

---

## Supabase RPCs

All RPCs enforce member-level access (not organizer-only) unless noted.

| RPC | Signature | Effect |
|---|---|---|
| `setup_session_queues` | `(p_session_id, p_count, p_spots, p_allow_duplicates)` | Organizer-only. Idempotent: increases/decreases count, updates spots and allow_duplicates |
| `join_queue` | `(p_activity_id)` | Self-join: inserts an entry for the calling user |
| `leave_queue` | `(p_entry_id)` | Remove one entry by ID |
| `add_member_to_queue` | `(p_activity_id, p_user_id nullable, p_display_name, p_avatar_url)` | Any member can add another member (app user or anonymous guest) |
| `clear_queue` | `(p_activity_id)` | Deletes all entries from the row; resets `status = 'waiting'` |
| `set_queue_status` | `(p_activity_id, p_status)` | Sets `status` to `'waiting'`, `'active'`, or `'ended'`; does NOT affect entries |
| `move_queue_to_position` | `(p_activity_id, p_session_id, p_new_position)` | Moves one row to a new `sort_order`; bulk-shifts the affected range in O(range) SQL updates; does NOT touch `status` |
| `reorder_session_queues` | `(p_session_id, p_ordered_ids uuid[])` | Reassigns sort_orders sequentially for all IDs; use only when the full order is known (e.g. from a bulk-import) |

---

## Playing Status (`status` column)

| Status | Visual | Meaning |
|---|---|---|
| `waiting` | Normal grey card | Queue is idle; members waiting |
| `active` | Teal animated card + shimmer sweep | Members in this row are currently playing |
| `ended` | (reserved) | Queue has finished all rounds |

### Animations (Flutter side)
- **Toggle switch** (`_switchCtrl`, 550 ms, plays once): `ScaleTransition` bounce (1.0 → 1.06 → 1.0, `elasticOut`) + teal `ColoredBox` flash overlay (0 → 0.38 → 0 opacity).
- **Constant shimmer** (`_shimmerCtrl`, 2 800 ms, `repeat()`): diagonal `LinearGradient` sweep left → right across the card (`RepaintBoundary`-isolated). The sweep center travels from x = −3.5 to x = +3.5 in alignment units, so it's off-screen ~50% of the cycle (natural pause between sweeps).
- Both overlays use `IgnorePointer` so they never intercept taps.

---

## Free Pool

The free pool is **client-side only** — no DB table.

**Computation** (`EventProvider._recomputeFreePool`):
1. Collect all entries across every queue row in the session.
2. Build two exclusion sets:
   - `inQueueByUserId`: `userId` values of entries where `userId != null`
   - `inQueueByName`: lowercase `displayName` values of entries where `userId == null`
3. Filter event guests: keep guests not in either exclusion set.
4. Store result in `_freePool[sessionId]`.

**Triggers**: called after every `fetchSessionQueues`, every Realtime entry INSERT/UPDATE/DELETE, and every Realtime queue activity UPDATE.

---

## Duplicate Prevention

Controlled by `allow_duplicates` on the queue activity (set at setup time).

When `allow_duplicates == false`:

- **Self-join ("Add myself")**: the `join_queue` RPC enforces uniqueness server-side (raises `already_in_queue`).
- **Add someone else** (`_showMemberPicker`): the candidate list is filtered client-side across **all queues in the session** (not just the current row):
  - App users excluded by `userId` set union.
  - Anonymous guests excluded by case-insensitive `displayName` set union.

---

## Queue Card Actions

Tapping the queue card (anywhere except spot circles) opens the **Queue Actions sheet**.

| Button | Condition shown | Behaviour |
|---|---|---|
| 🔥 **Game On!** | Always | Sets `status = 'active'`; starts shimmer animation |
| 😴 **Back to Waiting** | Only when `status == 'active'` | Sets `status = 'waiting'`; stops shimmer |
| 🔄 **Just Played! Back in Line** | Only when a non-empty queue has an empty queue after it | See "Back in Line" logic below |
| 💨 **Evict All** | Only when queue has ≥ 1 entry | Calls `clear_queue`; resets status to `'waiting'` |

### "Just Played! Back in Line" logic

Goal: the played group releases their spot at the top and slides into the first available empty slot, while teams waiting between them move up.

Algorithm (`EventProvider.moveQueuePastFirstEmpty`):

1. Find `currentIdx` of this queue row in the sorted list.
2. Find `firstEmptyIdx` = first queue row after `currentIdx` with no entries.
3. `targetSortOrder = queues[firstEmptyIdx].sortOrder - 1` — slots the played row **before** the empty slot, so the empty slot is not displaced.
4. Optimistic local update: `removeAt(currentIdx)`, `insert(firstEmptyIdx - 1, played)`, reset `status = 'waiting'` on the local copy → instant UI.
5. DB: call `move_queue_to_position` (O(range) updates) then `set_queue_status('waiting')`.

**Eligibility** (`canMoveQueuePastEmpty`): returns `true` when any queue after `currentIdx` has zero entries. The button is hidden otherwise.

---

## Drag-to-Reorder

Long-press on the `#N` number column (left side of the card) activates drag.

- **Widget**: `ReorderableListView.builder` with `buildDefaultDragHandles: false` + `ReorderableDelayedDragStartListener` scoped to the number column.
- **Drag handle**: `Icons.drag_handle_rounded` shown below the `#N` label when `status == 'waiting'`; replaced by the ▶ badge when `status == 'active'`.
- **Provider method** (`moveQueueByIndex`): computes `targetSortOrder = queues[newIndex].sortOrder`, optimistic local reorder, then calls `move_queue_to_position`. **Status is preserved** — dragging does not reset `status`.
- **Realtime**: `handleQueueActivityUpdate` re-sorts by `sort_order` on every UPDATE, so all clients converge automatically.

---

## Gesture Model (Flutter)

```
GestureDetector(onTap → queue actions sheet)      ← whole card
  ScaleTransition (switch animation)
    Stack
      AnimatedContainer (base card)
        Row
          GestureDetector(onTap → actions sheet)  ← number column only
            ReorderableDelayedDragStartListener   ← long-press → drag
              SizedBox(#N + drag handle icon)
          Expanded → SingleChildScrollView
            Row of _SpotCircle widgets
              GestureDetector(onTap → ...)        ← each circle, wins arena
      IgnorePointer → shimmer overlay
      IgnorePointer → flash overlay
```

**Gesture arena resolution:**
- Tapping a spot circle → inner `GestureDetector` wins; outer loses (child wins arena).
- Tapping the number area → number `GestureDetector` wins; outer loses.
- Tapping card background (no child GD) → outer `GestureDetector` opens action sheet.
- Long-press on number → `ReorderableDelayedDragStartListener` wins; tap GD times out.

---

## Spot Circle Tap Behaviour

| User | Is organizer | Tap result |
|---|---|---|
| Self | any | Leave-slot confirmation sheet |
| Other app user | yes | Kick confirmation sheet |
| Other app user | no | User profile sheet (avatar + name + friend status/add) |
| Anonymous guest | any | No tap action |
| Empty spot | any | Add-to-slot sheet (add self or pick from roster) |

### User profile sheet (non-organizer)
Only shown for entries with a non-null `userId` that isn't the current user. Checks `FriendsProvider` for relationship status and shows one of:
- 👋 Already friends
- ⏳ Friend request sent (outgoing pending)
- 🤝 Accept Friend Request (incoming pending)
- 🤝 Add Friend (no relationship)

---

## Realtime Coverage

| Table | Event | Handler | Effect |
|---|---|---|---|
| `session_queue_activities` | INSERT | `handleQueueActivityInsert` | Add to `_sessionQueues[sessionId]`, index in `_activityMeta` |
| `session_queue_activities` | UPDATE | `handleQueueActivityUpdate` | Patch in-place, re-sort by `sort_order`, recompute free pool |
| `session_queue_activities` | DELETE | `handleQueueActivityDelete` | Remove from cache, clear entries cache, recompute free pool |
| `session_queue_entries` | INSERT | `handleQueueEntryInsert` | Append to `_queueEntries[activityId]`, sort by `queue_position`, recompute free pool |
| `session_queue_entries` | UPDATE | `handleQueueEntryUpdate` | Patch in-place, sort, recompute free pool |
| `session_queue_entries` | DELETE | `handleQueueEntryDelete` | Remove from cache, recompute free pool |

All changes propagate to every connected client in real time. The 8-second client-side poll (`_queuePollTimer`) serves as a fallback sync if a Realtime event is missed.

---

## Optimistic Update Pattern

Every mutation follows the same pattern to keep the UI snappy:
1. Apply the change to the local cache immediately → `notifyListeners()`.
2. `await` the RPC (so the next poll sees the correct DB state before overwriting the cache).
3. Realtime events arrive shortly after and confirm/correct the local state.

**Why `await` matters**: fire-and-forget (`unawaited`) DB calls can race with the 8-second poll, which re-fetches from the DB and overwrites the optimistic cache before the write completes — causing visible reverts.
