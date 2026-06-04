# App Architecture

> **Keep this file current.** After any session that adds a feature, changes the DB schema, adds a provider/widget/screen, or changes a described behaviour — update this file and any relevant domain doc (`invite_flow.md`, etc.) before finishing. See `CLAUDE.md` for the full documentation rule.

## Overview

**TripManagement** is a Flutter app for planning and organising events — trips, birthdays, weddings, and social gatherings. All event types share chat, guests, photos, and expenses. Trip-type events additionally feature itinerary stops, a map, and a member-invite flow. It shares the same Supabase project and Google Cloud project as PropertyManagement, so the same user account works in both apps. Targets iOS, Android, and web.

---

## Tech Stack

| Layer | Choice | Package |
|---|---|---|
| UI framework | Flutter (Material 3) | `flutter` SDK |
| Shared UI / theme | Shared package | `shared_ui` (local path) |
| Shared logging | Firebase Analytics + Crashlytics | `shared_logging` (local path) |
| State management | Provider pattern | `provider ^6.1.2` |
| Navigation | Declarative routing | `go_router ^14.6.2` |
| Backend / Database | Supabase (Postgres + Auth + Realtime) | `supabase_flutter ^2.9.0` |
| Push notifications | Firebase Cloud Messaging (FCM) | `firebase_messaging` |
| Secure storage | Flutter Secure Storage | `flutter_secure_storage ^9.2.4` |
| Offline cache | SharedPreferences JSON cache | `shared_preferences ^2.3.0` |
| Offline queue | Write-ahead queue, replayed on reconnect | (same package) |
| Connectivity | Network state monitor | `connectivity_plus ^6.1.0` |
| Client UUID gen | Offline ID generation | `uuid ^4.5.0` |
| Address / place search | Google Places API (New) — mobile + web | `http ^1.4.0` |
| Maps | flutter_map + OpenStreetMap tiles (pure Dart, no native SDK) | `flutter_map ^8.1.1`, `latlong2 ^0.9.1` |
| Real road routes | Google Maps Directions API | `http ^1.4.0` (REST) |
| AI chat (planned) | Google Gemini 2.5 Flash Lite | `http ^1.4.0` |
| Date / number formatting | intl | `intl ^0.20.2` |
| Swipe-to-delete | flutter_slidable | `flutter_slidable ^3.1.1` |
| Web interop | package:web | `web ^1.1.1` |

---

## Folder Structure

```
lib/
├── main.dart               # App entry, Supabase init, GoRouter, MultiProvider (3-tab shell)
├── config/
│   └── api_keys.dart       # Supabase URL/anon key, Google Places/Maps key, Gemini key (gitignored)
├── models/                 # Pure data classes — toJson/fromJson, no Flutter deps
│   ├── event.dart          # Event; EventType enum (trip/birthday/wedding/social); embeds List<EventGuest> + List<EventStop>; trip-specific fields (startLocation, startLat/Lng)
│   ├── event_guest.dart    # EventGuest — id, eventId, userId (nullable), displayName, status (going/maybe/declined/pending/accepted/left), invitedBy, blockReinvite, role
│   ├── event_stop.dart     # EventStop — id, eventId, title, address, lat/lng, arriveAt, departAt, notes, sortOrder
│   ├── event_message.dart  # EventMessage — id, eventId, userId, content, enriched senderName
│   ├── event_photo.dart    # EventPhoto — id, eventId, storagePath, publicUrl (resolved at load)
│   ├── event_expense.dart  # EventExpense + EventExpenseSplit for cost splitting
│   ├── friendship.dart     # Friendship — id, requesterId, addresseeId, status, enriched name
│   └── blocked_user.dart   # BlockedUser — userId, fullName, avatarUrl, blockedAt
├── providers/              # ChangeNotifiers — hold state, talk to Supabase
│   ├── auth_provider.dart          # Auth session; login/register/logout
│   ├── event_provider.dart         # All events (organizer + guest); stops/members/photos/expenses; full CRUD + Realtime; pendingInviteCount for badge
│   ├── event_chat_provider.dart    # Event-scoped chat; paginated load + Realtime INSERT; scoped to /event/:id route
│   ├── invitations_provider.dart   # Pending trip-event invitations for the current user; Realtime
│   ├── friends_provider.dart       # Friend list + requests; two Realtime channels; searchUsers RPC
│   ├── blocked_users_provider.dart # Global block list; blockUser RPC + optimistic unblock
│   └── settings_provider.dart      # Theme mode + language persistence
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── events/
│   │   ├── events_screen.dart       # Events tab (shell tab 0): My events + Invited sections; type filter chips (All/Trip/Birthday/Wedding/Social)
│   │   ├── event_form_screen.dart   # Create / edit event; EventType picker; trip-type shows start location + destination fields; non-trip shows single location field
│   │   ├── event_detail_screen.dart # Dynamic tabs: 7 for trips (Info, Route, Map, Guests, Chat, Photos, Expenses), 5 for others (Info, Guests, Chat, Photos, Expenses)
│   │   └── event_invite_screen.dart # Public RSVP screen — no auth required; fetches event by invite_code
│   ├── friends/
│   │   ├── friends_screen.dart  # Friends tab (shell tab 1): accepted list + search + Requests tab with badge; "From Contacts" AppBar button (non-web)
│   │   └── contacts_screen.dart # Batch-match device contacts against registered users; "Add to Trip" (opens trip-event picker) + share-sheet invite
│   ├── profile/
│   │   └── profile_screen.dart     # Edit display name, avatar; sign-out (shell tab 2)
│   ├── settings/
│   │   ├── settings_screen.dart      # Theme, language, account, notifications, privacy sections
│   │   └── blocked_users_screen.dart # List of globally blocked users with Unblock action
│   └── shell/
│       └── shell_scaffold.dart     # StatefulShellRoute wrapper; 3-tab bottom nav (Events + pending badge, Friends + request badge, Profile)
├── services/
│   ├── ai_chat_service.dart            # Abstract interface + factory
│   ├── edge_function_ai_chat_service.dart   # Release — proxies through Supabase Edge Function
│   ├── gemini_direct_ai_chat_service.dart   # Dev — calls Gemini directly
│   ├── gemini_service.dart             # Raw Gemini HTTP client, retry/backoff logic
│   ├── gemini_tools.dart               # Tool declarations (empty — add event tools here)
│   ├── push_notification_service.dart  # FCM token registration + permission handling
│   ├── trip_places_service.dart        # Google Places autocomplete + details (mobile + web)
│   ├── trip_places_web.dart            # Web impl via Google Maps JS SDK + dart:js_interop
│   ├── trip_places_stub.dart           # Stub for non-web builds
│   ├── directions_service.dart         # Google Maps Directions API; decodes encoded polyline
│   ├── cache_entry.dart                # Generic TTL cache wrapper
│   ├── local_cache.dart                # SharedPreferences JSON cache (offline read support)
│   ├── connectivity_service.dart       # Network state monitor (connectivity_plus)
│   └── offline_queue.dart              # Persistent write-ahead queue, replayed on reconnect
├── widgets/
│   ├── event_card.dart                 # Event summary card (type icon, title, date, location, member/going count, pending badge for trips)
│   ├── event_map_widget.dart           # flutter_map (Stadia Maps tiles) with start + numbered stop + destination markers + real road polyline; exports LatLng
│   ├── event_stop_form_sheet.dart      # Add / edit stop bottom sheet (trip-type events)
│   ├── add_member_sheet.dart           # Add member bottom sheet — friends quick-add chips + account lookup; calls EventProvider.addMember()
│   ├── places_autocomplete_field.dart  # Text field with Places suggestions dropdown
│   └── destination_search_dialog.dart  # Full-screen Places search dialog
└── theme/
    └── app_theme.dart      # Re-export shim → AppTheme from shared_ui
```

---

## Navigation (GoRouter)

All routes are defined in `main.dart`. Auth state drives a redirect guard. The app uses `StatefulShellRoute.indexedStack` (go_router) for a 3-tab bottom nav shell.

**Shell branches (bottom nav tabs):**

| Tab | Icon | Route | Sub-routes |
|---|---|---|---|
| Events | `event_outlined` | `/events` → EventsScreen | `/event/new`, `/event/:id`, `/event/:id/edit` |
| Friends | `people_outline` | `/friends` → FriendsScreen | — |
| Profile | `person_outline` | `/profile` → ProfileScreen | `/profile/settings` → SettingsScreen, `/profile/settings/blocked` → BlockedUsersScreen |

`/event/:id` creates a scoped `EventChatProvider` (wraps `EventDetailScreen` in `ChangeNotifierProvider`, enabling test injection).

**Top-level routes (outside shell):**
```
/                        → redirects to /events
/home                    → redirects to /events
/trips                   → redirects to /events        (backward-compat)
/trip/:id                → redirects to /event/:id      (backward-compat)
/trip/:id/edit           → redirects to /event/:id/edit (backward-compat)
/login                   → LoginScreen
/register                → RegisterScreen
/event/invite/:code      → EventInviteScreen (public — no auth required)
```

**Auth guard:** Unauthenticated users are redirected to `/login`. Exception: `/event/invite/*` routes are public (accessible without auth). Logged-in users visiting `/login` or `/register` are redirected to `/events`. Guard is driven by `AuthProvider` as a `refreshListenable`.

---

## State Management

`ChangeNotifier` providers, injected via `MultiProvider` at the root:

| Provider | Owns | Key methods |
|---|---|---|
| `AuthProvider` | Auth session, current user | `init()`, `login()`, `register()`, `logout()`; `isLoggedIn`, `userId`, `userEmail`, `userName` |
| `EventProvider` | All events (organizer + guest) + nested stops/members | `load()`, `clear()`, `getById(id)`, `addEvent()`, `updateEvent()`, `deleteEvent()`, `rsvp(eventId, status)`, `addGuest(eventId, displayName, [email, phone, userId])`, `addMember(eventId, ...)` (trip-type invite flow with `ReinviteBlockedException`), `removeMember()`, `leaveEvent()`, `resendInvite(guestId)`, `addStop()`, `updateStop()`, `deleteStop()`, `reorderStops()`, `fetchPhotos(eventId)`, `addPhoto()`, `deletePhoto()`, `fetchExpenses(eventId)`, `addExpense()`, `settleSplit()`; computed `myEvents`, `invitedEvents`, `pendingInviteCount` (badge); Realtime via `event_sync_<userId>` channel |
| `EventChatProvider` | Event-scoped chat | `init()`, `sendMessage(content)`, `loadMore()`; paginated (50/page); optimistic append with temp ID; single Realtime channel; scoped to `/event/:id` route |
| `InvitationsProvider` | Pending trip-event invitations for signed-in user | `init(userId)`, `clear()`, `accept()`, `decline(blockReinvite:)` |
| `FriendsProvider` | Friend list + pending requests | `init(userId)`, `clear()`, `sendRequest(addresseeId)`, `accept(id)`, `decline(id)`, `remove(id)`, `searchUsers(query)`; computed getters `accepted`, `incomingRequests`, `outgoingRequests`; two Realtime channels |
| `BlockedUsersProvider` | Global block list | `load()`, `clear()`, `blockUser(userId)`, `unblockUser(userId)`, `isBlocked(userId)`; optimistic unblock with revert on error; loaded on login, cleared on logout |
| `SettingsProvider` | Theme mode + language preference | `load()`, `setThemeMode()`, `setLocale()` |
| `ConnectivityService` | Network state | `init()`, `isOnline` — notifies on change |
| `OfflineQueue` | Pending write operations | `init()`, `enqueue()`, `flush()`, `pendingCount`, `hasPending` |

Providers are pre-loaded on startup if the user is already logged in. `AuthProvider` notifies on auth state change, which triggers `EventProvider.load()` / `EventProvider.clear()`, `InvitationsProvider.init()` / `InvitationsProvider.clear()`, `FriendsProvider.init()` / `FriendsProvider.clear()`, `BlockedUsersProvider.load()` / `BlockedUsersProvider.clear()`.

`EventChatProvider` is **not global** — it is instantiated in the GoRouter `/event/:id` route builder (not in `MultiProvider`), scoped to one event, and disposed when the user navigates away.

### Offline behaviour

`EventProvider` accepts a `ConnectivityService` and `OfflineQueue`. When offline:

- **`load()`** — serves the last-saved JSON cache from `SharedPreferences` (key `cache_events_v1_<userId>`). Falls back to cache on network errors even when nominally online.
- **Write operations** — applied optimistically to the in-memory list immediately, then either sent to Supabase (online) or added to `OfflineQueue` (offline). The cache is updated after every mutation so app restarts reflect pending changes.
- **Queue flush** — `OfflineQueue` auto-flushes when `ConnectivityService` reports coming back online. Operations are replayed in order using `upsert`/`update`/`delete`. Failed ops stay in the queue and are retried on the next flush.
- **Logout** — `clear()` evicts the cache key for that user.

Client-side UUID generation (`uuid` package) ensures new records have a stable ID before and after the Supabase round-trip.

---

## Database (Supabase)

**Project ref:** `qgeocaectbdfonrorwco` (shared with PropertyManagement)

### Tables

#### `events`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `created_by` | uuid FK→auth.users | organizer |
| `title` | text | |
| `description` | text | default '' |
| `event_type` | event_type enum | `trip` \| `birthday` \| `wedding` \| `social`; default `social` |
| `location` | text | destination for trips; venue for others |
| `location_lat/lng` | float8 nullable | |
| `start_location` | text nullable | trip-only — departure point |
| `start_lat/lng` | float8 nullable | trip-only |
| `start_at` | timestamptz | required |
| `end_at` | timestamptz nullable | |
| `capacity` | integer nullable | null = unlimited |
| `invite_code` | uuid UNIQUE | auto-generated; used for public share link |
| `created_at / updated_at` | timestamptz | |

#### `event_guests`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | CASCADE delete |
| `user_id` | uuid FK→auth.users nullable | null for non-app RSVPs |
| `display_name` | text | |
| `email / phone` | text nullable | |
| `status` | text | non-trip: `going`\|`maybe`\|`declined`; trip: `pending`\|`accepted`\|`declined`\|`left` |
| `rsvp_at` | timestamptz | updated on each status change |
| `invited_by` | uuid FK→auth.users nullable | userId of who sent the invite (trip-type) |
| `block_reinvite` | bool default false | invitee opted out of future invites to this event |
| `role` | text default 'member' | `organizer` \| `member` |
| `created_at` | timestamptz | |

**Constraints:** Partial UNIQUE INDEX on `(event_id, user_id) WHERE user_id IS NOT NULL`  
**REPLICA IDENTITY:** FULL (DELETE payloads include event_id for Realtime routing)

**Status lifecycle (trip-type events):**
```
INSERT with status='pending'   ← new linked-user invite
  → accepted / declined        ← invitee action
  → left                       ← member voluntarily leaves (accepted → left)
  → pending again              ← re-invite via upsert
```

Unlinked guests (user_id IS NULL) and non-trip events: inserted directly as `going`.

#### `event_stops`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | CASCADE delete; trip-type events only |
| `title` | text | |
| `address` | text | |
| `address_lat/lng` | float8 nullable | |
| `arrive_at / depart_at` | timestamptz nullable | |
| `notes` | text | |
| `sort_order` | int | client-side drag-to-reorder |
| `created_at` | timestamptz | |

**REPLICA IDENTITY:** FULL; added to `supabase_realtime` publication  
**RLS:** SELECT/INSERT/UPDATE/DELETE via `auth_user_is_event_member(event_id)`

#### `friendships`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `requester_id` | uuid FK→auth.users | user who sent the request |
| `addressee_id` | uuid FK→auth.users | user who received the request |
| `status` | text | `pending` \| `accepted` \| `declined` \| `removed` — constraint enforced |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

**Constraints:** `friendships_pair_unique UNIQUE (requester_id, addressee_id)`  
**RLS:** SELECT for either party; INSERT only as requester; UPDATE for either party.  
**Realtime:** Added to `supabase_realtime` publication; `REPLICA IDENTITY FULL`.

`FriendsProvider` uses **two channels** per user to work around Supabase Realtime's single-column filter limit:
- `friends_req_<userId>` — filter `requester_id = userId`
- `friends_addr_<userId>` — filter `addressee_id = userId`

Both callbacks trigger a full `_fetch()` refetch.

#### `user_profiles`
Auto-created on user sign-up (trigger). Stores `full_name`, `avatar_url`, `job_title` (DB only — removed from UI).

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid unique FK→auth.users | one profile per user |
| `full_name` | text default '' | set from `raw_user_meta_data->>'name'` on sign-up |
| `avatar_url` | text nullable | |
| `job_title` | text nullable | |

**RLS:** users can only SELECT/UPDATE their own profile row (`user_id = auth.uid()`). Cross-user reads require the `get_profile_names` SECURITY DEFINER function.

#### `device_tokens`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid FK→auth.users | |
| `token` | text | FCM registration token |
| `platform` | text | `ios` \| `android` \| `web` |
| `created_at` | timestamptz | |

Upserted on login / token refresh. Stale tokens (FCM 404/UNREGISTERED) are deleted by the `send-invite-notification` Edge Function.

#### `user_blocks`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `blocker_id` | uuid FK→auth.users | user who initiated the block |
| `blocked_id` | uuid FK→auth.users | user who was blocked |
| `created_at` | timestamptz | |

**Constraints:** UNIQUE `(blocker_id, blocked_id)`; CHECK `blocker_id <> blocked_id`  
**RLS:** SELECT/INSERT/DELETE only where `blocker_id = auth.uid()`

**Associated RPCs (`SECURITY DEFINER`):**
- `block_user(p_blocked_id uuid)` — atomically DELETEs any friendship row (either direction) then INSERTs into `user_blocks`. Called by `BlockedUsersProvider.blockUser()`.
- `get_blocked_users()` — returns `(user_id, full_name, avatar_url, blocked_at)` for all users blocked by the caller. Called by `BlockedUsersProvider.load()`.

**Block enforcement:**
- `find_user_by_contact` excludes callers who are blocked by the target (so the blocked user can't find the blocker when adding trip members).
- `search_users` excludes both directions (blocker ↔ blocked are invisible to each other in friend search).
- `friendships_insert` RLS WITH CHECK prevents sending a friend request to someone who has blocked you.

#### `event_messages`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | |
| `user_id` | uuid FK→auth.users | sender |
| `content` | text | |
| `created_at` | timestamptz | |

**Index:** `(event_id, created_at DESC)` for paginated fetch  
**RLS:** SELECT and INSERT use `auth_user_is_event_member(event_id)`; no UPDATE or DELETE (messages are permanent).  
**Realtime:** `REPLICA IDENTITY FULL`; added to `supabase_realtime` publication.

`EventChatProvider` subscribes to one channel per event (`chat_<eventId>`, filter `event_id = eventId`) for INSERT events. Messages are paginated (50 per page, newest-first from DB, reversed in-memory to oldest→newest). Optimistic appends use a `temp_<timestamp>` placeholder ID.

#### `event_photos`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | |
| `uploaded_by` | uuid FK→auth.users | |
| `storage_path` | text | key in `event-photos` Storage bucket: `{event_id}/{filename}` |
| `caption` | text | default '' |
| `created_at` | timestamptz | |

**REPLICA IDENTITY:** FULL

#### `event_expenses`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | |
| `paid_by_user_id` | uuid FK→auth.users | |
| `paid_by_name` | text | snapshot of payer name at creation time |
| `amount` | numeric(10,2) | > 0 |
| `description` | text | |
| `created_at` | timestamptz | |

#### `event_expense_splits`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | denormalized for RLS — avoids join |
| `expense_id` | uuid FK→event_expenses | |
| `guest_id` | uuid FK→event_guests | |
| `amount` | numeric(10,2) | share for this guest |
| `settled` | boolean | default false |
| `settled_at` | timestamptz nullable | |

**RLS helper:** `auth_user_is_event_member(p_event_id uuid)` — `SECURITY DEFINER` function; returns true if caller is event creator OR has a guest row with `status IN ('going','maybe','accepted','pending')` for that event. `declined`/`left` do not grant access.

**Authenticated RPCs (`authenticated` role only):**
- `create_event(p_title, p_description, p_location, p_start_at, [p_location_lat, p_location_lng, p_end_at, p_capacity, p_event_type, p_start_location, p_start_lat, p_start_lng])` — `SECURITY DEFINER`; inserts an event row with `created_by = auth.uid()`, bypassing the RLS INSERT check. Used by `EventProvider.addEvent()` to avoid 42501 errors.
- `resend_event_invite(p_guest_id uuid)` — resets `status = 'pending'` for a guest row; triggers `on_invite_inserted` for re-notification.
- `get_profile_names(p_user_ids uuid[])` — returns `(user_id, full_name, email, phone, avatar_url)` for a list of user IDs, bypassing `user_profiles` RLS. Called by `EventProvider._enrichGuestNames()`, `FriendsProvider._enrichNames()`, and `BlockedUsersProvider.load()`.
- `search_users(p_query text)` — returns `(user_id, full_name, email)` for users matching the query by name, email, or phone, excluding the caller and existing friends. Limit 20.
- `find_users_by_contacts(p_phones text[], p_emails text[])` — batch-lookup used by `ContactsScreen`. Excludes caller, blocked users (either direction), and existing friends.

**Public RPCs (`anon` + `authenticated` access):**
- `get_event_by_invite_code(p_invite_code uuid)` — returns event info + RSVP counts + organizer name; used by `EventInviteScreen` without auth.
- `rsvp_event_public(p_invite_code, p_display_name, p_email, p_phone, p_rsvp_status)` — inserts an anonymous `event_guests` row (user_id = null); enforces capacity limit; returns event summary.

**Storage:** `event-photos` bucket (public read); path = `{event_id}/{filename}`.

**Realtime publication:** `events`, `event_guests`, `event_messages`, `event_photos`, `event_expenses`, `event_stops` all added to `supabase_realtime`. `EventProvider` channel: `event_sync_<userId>`.

---

### Row-Level Security (RLS)

#### `events`
| Policy | Operation | Rule |
|---|---|---|
| `events_select` | SELECT | `created_by = auth.uid()` OR `auth_user_is_event_member(id)` |
| `events_insert` | INSERT | `created_by = auth.uid()` (also via `create_event` RPC for edge cases) |
| `events_update` | UPDATE | `created_by = auth.uid()` |
| `events_delete` | DELETE | `created_by = auth.uid()` |

#### `event_guests`
| Policy | Operation | Rule |
|---|---|---|
| `event_guests_select` | SELECT | `auth_user_is_event_member(event_id)` (pending status counts for read) |
| `event_guests_insert` | INSERT | organizer OR `auth_user_is_event_member(event_id)` |
| `event_guests_update_own_status` | UPDATE | `user_id = auth.uid()` (invitee accepts/declines/leaves their own row) |
| `event_guests_reinvite` | UPDATE | USING: old `status in ('left','declined')` AND caller is organizer or member; WITH CHECK: new `status = 'pending'` |

**RLS helper functions** (`SECURITY DEFINER` to avoid recursion):
- `auth_user_is_event_member(p_event_id)` — returns true if caller is creator OR has `status IN ('going','maybe','accepted','pending')` for that event
- `find_user_by_contact(p_email, p_phone)` — looks up a user by email/phone (used in `AddMemberSheet`)

#### `event_stops`
All event members (organizer or active guest) can SELECT/INSERT/UPDATE/DELETE stops for their events. Uses `auth_user_is_event_member()`.

#### `event_messages`
| Policy | Operation | Rule |
|---|---|---|
| `event_messages_select` | SELECT | `auth_user_is_event_member(event_id)` |
| `event_messages_insert` | INSERT | `user_id = auth.uid() AND auth_user_is_event_member(event_id)` |

#### `event_photos`, `event_expenses`, `event_expense_splits`
All gated by `auth_user_is_event_member(event_id)`.

#### `friendships`
| Policy | Operation | Rule |
|---|---|---|
| `friendships_select` | SELECT | `requester_id = auth.uid() OR addressee_id = auth.uid()` |
| `friendships_insert` | INSERT | `requester_id = auth.uid()` AND addressee has not blocked caller (`NOT EXISTS` check in `user_blocks`) |
| `friendships_update` | UPDATE | `requester_id = auth.uid() OR addressee_id = auth.uid()` |

#### `user_blocks`
| Policy | Operation | Rule |
|---|---|---|
| `user_blocks_select` | SELECT | `blocker_id = auth.uid()` |
| `user_blocks_insert` | INSERT | `blocker_id = auth.uid()` |
| `user_blocks_delete` | DELETE | `blocker_id = auth.uid()` |

---

### DB Triggers

| Trigger | Table | Event | Function | Effect |
|---|---|---|---|---|
| `on_invite_inserted` | `event_guests` | AFTER INSERT OR UPDATE | `handle_new_invite()` | Calls `send-invite-notification` Edge Function via `pg_net` when `status = 'pending'` AND `user_id IS NOT NULL`. Fires on INSERT (new invite) and on UPDATE where status changes *to* `pending` (re-invite). |
| `on_guest_reinvite_check` | `event_guests` | BEFORE UPDATE | `prevent_blocked_reinvite()` | Raises exception `blocked_reinvite` if `old.block_reinvite = true` and `new.status = 'pending'`. Prevents re-inviting a user who opted out. |
| `on_new_user` | `auth.users` | AFTER INSERT | `handle_new_user()` | Auto-creates `user_profiles` row on sign-up. |

---

### Edge Functions

#### `send-invite-notification`
Called by the `on_invite_inserted` trigger via `pg_net.http_post`. Reads FCM tokens from `device_tokens`, exchanges the service-account JSON for an OAuth2 access token, and sends an FCM v1 API push notification. Stale/unregistered tokens are deleted automatically.

**Secrets required:**
```
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<json>'
supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<key>'
```
**Vault secret required** (run once, never commit):
```sql
select vault.create_secret('<service_role_key>', 'service_role_key');
```

---

## Invite & Membership Flow (Trip-type Events)

> Full reference: **`invite_flow.md`** — status lifecycle diagram, RLS policy table, DB objects reference, re-invite and block_reinvite details.

The invite flow applies **only to trip-type events** (`event.isTrip == true`). Non-trip events use a simple RSVP flow (going/maybe/declined) via public share link or organizer-adds-guest.

### Adding a member

1. Organizer or accepted member taps "Add member" (FAB on Route/Guests tab in event detail).
2. `AddMemberSheet` shows — type name + email/phone. A debounced lookup (400 ms) calls `find_user_by_contact()` to find a linked account.
3. On confirm, `EventProvider.addMember()` is called:
   - Linked user (`userId != null`): **upsert** on `(event_id, user_id)`. If a `left`/`declined` row already exists, it is reset to `pending` (re-invite). If `block_reinvite = true`, throws `ReinviteBlockedException` immediately (in-memory fast-reject) with a DB trigger as a safety net.
   - Guest (`userId == null`): plain INSERT, status `going` immediately.
4. `on_invite_inserted` trigger fires → FCM push sent to invitee's devices.
5. `InvitationsProvider` on the invitee's device receives the INSERT/UPDATE via Realtime → invite badge updates immediately.

### Accepting / declining an invitation

`InvitationsProvider` shows pending event-guest rows for the current user. Tapping **Accept** calls `InvitationsProvider.accept()` (sets `status = 'accepted'`). Tapping **Decline** opens a confirmation dialog with a **"Don't allow future invitations to this event"** checkbox:
- Without checkbox: `status = 'declined'`
- With checkbox: `status = 'declined'`, `block_reinvite = true`

### Leaving an accepted trip event

Available from the AppBar button in Event Detail (non-organizer trip members only). A confirmation dialog includes the same **"Don't allow future invitations"** checkbox:
- Without checkbox: `status = 'left'` — row preserved, "Left" chip shown to other members
- With checkbox: `status = 'left'`, `block_reinvite = true`

### Re-inviting someone who left or declined

`addMember()` calls `.upsert(onConflict: 'event_id,user_id')` which updates the existing row to `status = 'pending'`. The `event_guests_reinvite` RLS policy guards this. The `on_invite_inserted` UPDATE trigger fires → new FCM push sent.

If the user had set `block_reinvite = true`:
1. In-memory fast-reject in `addMember()` throws `ReinviteBlockedException` (no network call).
2. DB trigger `on_guest_reinvite_check` is the authoritative fallback for stale caches.
3. UI shows: *"This user has opted out of future invitations to this event"*.

### Consistency guarantee

**Event records must be consistent across all members at all times.** Every mutation — to event metadata, stops, or guests — must propagate to every member's device via Supabase Realtime without requiring a reload.

`EventProvider._subscribeRealtime()` uses a single channel (`event_sync_<userId>`) and handles events across 5 tables:

| Table | Event | Handler | Notes |
|---|---|---|---|
| `events` | UPDATE | Reconstructs `Event` from payload scalars, preserves in-memory `guests` + `stops` | |
| `event_guests` | INSERT | `EventGuest.fromJson(row)` → append with dedup guard | |
| `event_guests` | UPDATE | `EventGuest.fromJson(row)` → full row replace | Covers accept/decline/leave/name changes |
| `event_guests` | DELETE | Remove by id | Requires `REPLICA IDENTITY FULL` for `event_id` in payload |
| `event_stops` | INSERT | `EventStop.fromJson(row)` → append + re-sort, dedup guard | |
| `event_stops` | UPDATE | `EventStop.fromJson(row)` → replace in-place + re-sort | |
| `event_stops` | DELETE | Remove by id | Requires `REPLICA IDENTITY FULL` on `event_stops` |

`InvitationsProvider` subscribes separately (INSERT + UPDATE on `event_guests` filtered by `user_id = currentUser` and `status = 'pending'`) to keep the invite badge current for the invited user's own device.

---

## Push Notifications

`PushNotificationService.init()` is called on every login:
1. Calls `requestPermission()`. If denied → returns early; no token is registered, no DB entry created.
2. Gets the FCM token and upserts it into `device_tokens`.
3. Listens for token refresh → upserts new token.
4. Handles cold-start / background notification taps → navigates to the relevant trip.

If the user has not granted notification permission, the in-app invite banner (driven by `InvitationsProvider`) is the primary delivery path — the app works fully without push permission.

---

## Map & Route Display

`EventMapWidget` (`lib/widgets/event_map_widget.dart`) renders a trip-type event using **flutter_map** (Stadia Maps tiles — pure Dart, no native Maps SDK required):
- **Start marker** — green circle with `Icons.trip_origin`.
- **Destination marker** — primary-colour circle with `Icons.location_on`.
- **Stop markers** — numbered circles (primary colour, white border), counted from 1.
- **Route polyline** — fetched from `DirectionsService` (Directions API) on mount and whenever pins change. Solid `4px` line when a real route is loaded; dashed `3px` fallback drawn directly between pins while loading or if the API fails.
- **Compact mode** (`compact: true`) — fixed 220 px height, gestures disabled so a parent `ListView` can still scroll. Non-compact maps are fully interactive (pan + pinch-zoom; rotation disabled).
- **Session-level route cache** — keyed by pipe-separated `lat,lng` waypoints; `prefetchRoute()` is called by the events list so routes are warm before the user opens an event.
- `EventMapWidget` **exports `LatLng`** from `latlong2` — callers don't need a separate `latlong2` import.

**Pin order** (both detail screen and form preview): start (green) → numbered stops → destination (blue). This order is passed directly to `DirectionsService` as the waypoints list, so the road route follows the same sequence.

`DirectionsService.getRoute(waypoints)`:
1. Calls `GET https://maps.googleapis.com/maps/api/directions/json` with origin, destination, and intermediate waypoints.
2. Extracts `routes[0].overview_polyline.points` (Google encoded polyline).
3. Decodes the encoded string into `List<LatLng>` (`latlong2`) using the standard algorithm.

**Required APIs:**
- `kStadiaMapsApiKey` — Stadia Maps key for tile rendering (sign up at stadiamaps.com; free tier 200k tiles/month). No native setup — key is a URL query parameter only.
- `kGooglePlacesApiKey` — Directions API must be enabled in Google Cloud Console (same key as Places). The Maps SDK itself is no longer a dependency.

---

## AI Chat Service

The AI layer mirrors PropertyManagement's design — provider-agnostic, build-mode-selected:

| Build mode | Implementation | Where the key lives |
|---|---|---|
| Release | `EdgeFunctionAIChatService` | Supabase secret `GEMINI_API_KEY` |
| Debug | `GeminiDirectAIChatService` | `kGeminiApiKey` in `api_keys.dart` |

Override in debug: `--dart-define=FORCE_EDGE_FUNCTION=true`

Trip-specific Gemini tool declarations live in `lib/services/gemini_tools.dart` (`kGeminiTools`, `kWriteToolNames`). Currently empty — add trip CRUD tools here as AI features are built.

---

## Places Search

`TripPlacesService` provides address autocomplete and lat/lng lookup for both the destination field and stop addresses.

- **Mobile** (iOS/Android): REST calls to `places.googleapis.com/v1/places:autocomplete` and `places.googleapis.com/v1/places/{placeId}` via `http` package.
- **Web**: loads the Google Maps JS SDK and calls `google.maps.importLibrary('places')` — implemented in `trip_places_web.dart` using `dart:js_interop`. Conditional export via `if (dart.library.js_interop)`.
- **Caching:** Suggestions are cached in-memory with a 1-hour TTL (`CacheEntry`). Place details are cached indefinitely per session.

---

## Key Conventions

- **Models** are plain Dart classes with `toJson()` / `fromJson()`. No Flutter imports.
- **Swipe to delete** everywhere (via `Slidable`) with a confirmation dialog before destructive actions.
- **`flutter analyze lib/ test/` must pass** before any session ends — scoped to exclude build artefacts.
- **Schema changes** always go through a migration file in `supabase/migrations/`, never the Supabase dashboard directly.
- **Guest name enrichment** — `event_guests.display_name` is set at invite/add time. After `load()`, `EventProvider._enrichGuestNames()` calls `get_profile_names` to patch in-memory `displayName` from the canonical `user_profiles.full_name`. The enriched state is saved to cache so offline sessions show correct names.
- **New `events` column rule** — Any column added to the `events` table must also be added to the `events UPDATE` handler in `EventProvider._subscribeRealtime()` (the handler reconstructs the `Event` object field-by-field from the Realtime payload). Stop and guest handlers use `fromJson` and are automatically future-proof.
- **Event consistency** — any mutation to an event, its guests, or its stops must propagate via Supabase Realtime. Prefer UPDATE over DELETE for state transitions (e.g. `status = 'left'`) so other members' Realtime UPDATE handlers pick up the change and preserve the row for display.
- **`REPLICA IDENTITY FULL`** is set on `event_guests` and `event_stops` so DELETE payloads include `event_id` — required for the DELETE Realtime handler.
- **RLS never uses direct subqueries into `event_guests`** from `event_guests` policies — always goes through `auth_user_is_event_member()` SECURITY DEFINER function to avoid infinite recursion.
- **Upsert requires a named UNIQUE CONSTRAINT** for PostgREST's `onConflict` to work. The partial unique index on `(event_id, user_id) WHERE user_id IS NOT NULL` covers linked users; NULL user_id values are treated as distinct so multiple unlinked guest rows are allowed per event.
- **API keys** are never committed. See `~/.claude/CLAUDE.md` for the full key management rules.
