# App Architecture

> **Keep this file current.** After any session that adds a feature, changes the DB schema, adds a provider/widget/screen, or changes a described behaviour — update this file and any relevant domain doc (`invite_flow.md`, etc.) before finishing. See `CLAUDE.md` for the full documentation rule.

## Overview

**TripManagement** is a Flutter app for planning and organising trips — destinations, itinerary stops, travel dates, and travel companions. It shares the same Supabase project and Google Cloud project as PropertyManagement, so the same user account works in both apps. Targets iOS, Android, and web.

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
├── main.dart               # App entry, Supabase init, GoRouter, MultiProvider
├── config/
│   └── api_keys.dart       # Supabase URL/anon key, Google Places/Maps key, Gemini key (gitignored)
├── models/                 # Pure data classes — toJson/fromJson, no Flutter deps
│   ├── trip.dart           # Trip; embeds List<TripMember> + List<TripStop>
│   ├── trip_member.dart    # TripMember — see model details below
│   ├── trip_stop.dart      # TripStop (title, address, lat/lng, arrive_at, depart_at, sort_order)
│   ├── friendship.dart     # Friendship — id, requesterId, addresseeId, status, enriched name
│   └── chat_message.dart   # ChatMessage — id, tripId, userId, content, enriched senderName
├── providers/              # ChangeNotifiers — hold state, talk to Supabase
│   ├── auth_provider.dart      # Auth session; login/register/logout
│   ├── trip_provider.dart      # All trips + nested stops/members; full CRUD + Realtime
│   ├── invitations_provider.dart  # Pending invitations for the current user; Realtime
│   ├── friends_provider.dart   # Friend list + requests; two Realtime channels; searchUsers RPC
│   ├── chat_provider.dart      # Trip-scoped chat messages; paginated load + Realtime INSERT
│   └── settings_provider.dart  # Theme mode + language persistence
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── friends/
│   │   └── friends_screen.dart  # Friends tab: accepted list + search + Requests tab with badge
│   ├── profile/
│   │   └── profile_screen.dart     # Edit display name, avatar; sign-out
│   ├── settings/
│   │   └── settings_screen.dart    # Theme, language, account actions
│   ├── shell/
│   │   └── shell_scaffold.dart     # StatefulShellRoute wrapper; 3-tab bottom nav; invite + friend-request badges
│   └── trips/
│       ├── trips_screen.dart       # Trip list; invite banner; swipe-to-delete/leave; tap → detail
│       ├── trip_form_screen.dart   # Create / edit trip (destination, dates, notes, map preview, members)
│       └── trip_detail_screen.dart # Tabbed: Overview + Itinerary + Map + Chat (4 tabs)
├── services/
│   ├── ai_chat_service.dart            # Abstract interface + factory
│   ├── edge_function_ai_chat_service.dart   # Release — proxies through Supabase Edge Function
│   ├── gemini_direct_ai_chat_service.dart   # Dev — calls Gemini directly
│   ├── gemini_service.dart             # Raw Gemini HTTP client, retry/backoff logic
│   ├── gemini_tools.dart               # Tool declarations (empty — add trip tools here)
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
│   ├── trip_card.dart                  # Trip summary card (title, destination, date range, member count)
│   ├── trip_map_widget.dart            # flutter_map (OpenStreetMap tiles) with numbered stop markers + real road polyline; exports LatLng
│   ├── trip_stop_form_sheet.dart       # Add / edit stop bottom sheet
│   ├── add_member_sheet.dart           # Add member bottom sheet — friends quick-add chips + account lookup
│   ├── places_autocomplete_field.dart  # Text field with Places suggestions dropdown
│   └── destination_search_dialog.dart  # Full-screen Places search dialog
└── theme/
    └── app_theme.dart      # Re-export shim → AppTheme from shared_ui
```

---

## Navigation (GoRouter)

All routes are defined in `main.dart`. Auth state drives a redirect guard. The app uses `StatefulShellRoute.indexedStack` (go_router) for a 2-tab bottom nav shell.

**Shell branches (bottom nav tabs):**

| Tab | Icon | Route | Sub-routes |
|---|---|---|---|
| Trips | `map_outlined` | `/trips` → TripsScreen | `/trip/new`, `/trip/:id`, `/trip/:id/edit` |
| Friends | `people_outline` | `/friends` → FriendsScreen | — |

`/trip/:id` route builder in `main.dart` creates a scoped `ChatProvider` and wraps `TripDetailScreen` in `ChangeNotifierProvider<ChatProvider>`, enabling test injection without touching widget state.

**Top-level routes (outside shell):**
```
/           → redirects to /trips
/home       → redirects to /trips
/login      → LoginScreen
/register   → RegisterScreen
```

**Auth guard:** Unauthenticated users are redirected to `/login`. Logged-in users visiting `/login` or `/register` are redirected to `/trips`. Guard is driven by `AuthProvider` as a `refreshListenable`.

---

## State Management

`ChangeNotifier` providers, injected via `MultiProvider` at the root:

| Provider | Owns | Key methods |
|---|---|---|
| `AuthProvider` | Auth session, current user | `init()`, `login()`, `register()`, `logout()`; `isLoggedIn`, `userId`, `userEmail`, `userName` |
| `TripProvider` | All trips + members + stops | `load()`, `clear()`, `getById(id)`, CRUD for trips/members/stops; `resendInvite(memberId)` — re-sends FCM push for pending invite; Realtime subscription for member updates |
| `InvitationsProvider` | Pending invitations for signed-in user | `init(userId)`, `clear()`, `accept()`, `decline(blockReinvite:)` |
| `FriendsProvider` | Friend list + pending requests | `init(userId)`, `clear()`, `sendRequest(addresseeId)`, `accept(id)`, `decline(id)`, `remove(id)`, `searchUsers(query)`; computed getters `accepted`, `incomingRequests`, `outgoingRequests`; two Realtime channels |
| `ChatProvider` | Trip-scoped chat messages | `init()`, `sendMessage(content)`, `loadMore()`; paginated (50/page); optimistic append with temp ID; single Realtime channel |
| `SettingsProvider` | Theme mode + language preference | `load()`, `setThemeMode()`, `setLocale()` |
| `ConnectivityService` | Network state | `init()`, `isOnline` — notifies on change |
| `OfflineQueue` | Pending write operations | `init()`, `enqueue()`, `flush()`, `pendingCount`, `hasPending` |

Providers are pre-loaded on startup if the user is already logged in. `AuthProvider` notifies on auth state change, which triggers `TripProvider.load()` / `TripProvider.clear()`, `InvitationsProvider.init()` / `InvitationsProvider.clear()`, and `FriendsProvider.init()` / `FriendsProvider.clear()`.

`ChatProvider` is **not global** — it is instantiated in the `/trip/:id` GoRouter route builder (not in `MultiProvider`) so it is scoped to a single trip and disposed when the user navigates away.

### Offline behaviour

`TripProvider` accepts a `ConnectivityService` and `OfflineQueue`. When offline:

- **`load()`** — serves the last-saved JSON cache from `SharedPreferences` (key `cache_trips_v1_<userId>`). Falls back to cache on network errors even when nominally online.
- **Write operations** — applied optimistically to the in-memory list immediately, then either sent to Supabase (online) or added to `OfflineQueue` (offline). The cache is updated after every mutation so app restarts reflect pending changes.
- **Queue flush** — `OfflineQueue` auto-flushes when `ConnectivityService` reports coming back online. Operations are replayed in order using `upsert`/`update`/`delete`. Failed ops stay in the queue and are retried on the next flush.
- **Logout** — `clear()` evicts the cache key for that user.

Client-side UUID generation (`uuid` package) ensures new records have a stable ID before and after the Supabase round-trip.

---

## Database (Supabase)

**Project ref:** `qgeocaectbdfonrorwco` (shared with PropertyManagement)

### Tables

#### `trips`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `created_by` | uuid FK→auth.users | organizer |
| `title` | text | |
| `start_location` | text nullable | |
| `start_lat/lng` | float8 nullable | |
| `destination` | text | |
| `destination_lat/lng` | float8 nullable | |
| `start_at / end_at` | timestamptz nullable | |
| `notes` | text | |
| `created_at / updated_at` | timestamptz | |

#### `trip_members`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `trip_id` | uuid FK→trips | |
| `user_id` | uuid FK→auth.users nullable | null = unlinked guest |
| `display_name` | text | |
| `role` | text | `organizer` \| `member` |
| `email` | text nullable | |
| `phone` | text nullable | |
| `status` | text | `pending` \| `accepted` \| `declined` \| `left` — constraint enforced |
| `invited_by` | uuid FK→auth.users nullable | userId of who sent the invite |
| `block_reinvite` | bool default false | invitee opted out of future invites to this trip |
| `created_at` | timestamptz | |

**Constraints:**
- `trip_members_trip_user_unique` UNIQUE `(trip_id, user_id)` — NULL values are treated as distinct so multiple guest rows are allowed; linked users may only appear once per trip
- `REPLICA IDENTITY FULL` — DELETE payloads include the full old row (needed so the Realtime DELETE handler can access `trip_id`)

**Status lifecycle:**
```
INSERT with status='pending'   ← new linked-user invite
  → accepted / declined        ← invitee action
  → left                       ← member voluntarily leaves (accepted → left)
  → pending again              ← re-invite via upsert (requires trip_members_reinvite policy)
```

Unlinked guests (user_id IS NULL) are inserted directly as `accepted`.

#### `trip_stops`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `trip_id` | uuid FK→trips | |
| `title` | text | |
| `address` | text | |
| `address_lat/lng` | float8 nullable | |
| `arrive_at / depart_at` | timestamptz nullable | |
| `notes` | text | |
| `sort_order` | int | client-side drag-to-reorder |
| `created_at` | timestamptz | |

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

#### `trip_messages`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `trip_id` | uuid FK→trips | |
| `user_id` | uuid FK→auth.users | sender |
| `content` | text | non-empty constraint |
| `created_at` | timestamptz | |

**Index:** `trip_messages_trip_created ON trip_messages (trip_id, created_at DESC)`  
**RLS:** SELECT and INSERT use `auth_user_is_trip_member(trip_id)`; no UPDATE or DELETE (messages are permanent).  
**Realtime:** Added to `supabase_realtime` publication; `REPLICA IDENTITY FULL`.

`ChatProvider` subscribes to one channel per trip (`chat_<tripId>`, filter `trip_id = tripId`) for INSERT events. Messages are paginated (50 per page, newest-first from DB, reversed in-memory to oldest→newest). Optimistic appends use a `temp_<timestamp>` placeholder ID that is replaced on the Realtime INSERT confirmation.

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

---

### Row-Level Security (RLS)

#### `trips`
| Policy | Operation | Rule |
|---|---|---|
| `trips_select` | SELECT | `created_by = auth.uid()` OR `auth_user_is_trip_member(id)` OR `auth_user_has_pending_invite(id)` |
| `trips_insert` | INSERT | `created_by = auth.uid()` |
| `trips_update` | UPDATE | `created_by = auth.uid()` |
| `trips_delete` | DELETE | `created_by = auth.uid()` |

#### `trip_members`
| Policy | Operation | Rule |
|---|---|---|
| `trip_members_select` | SELECT | organizer OR `auth_user_is_trip_member(trip_id)` OR `auth_user_has_pending_invite(trip_id)` |
| `trip_members_insert` | INSERT | organizer OR `auth_user_is_trip_member(trip_id)` |
| `trip_members_update_own_status` | UPDATE | `user_id = auth.uid()` (invitee accepts/declines/leaves their own row) |
| `trip_members_reinvite` | UPDATE | USING: old `status in ('left','declined')` AND caller is organizer or member; WITH CHECK: new `status = 'pending'` |
| `trip_members_leave` | DELETE | `user_id = auth.uid()` *(legacy — prefer UPDATE to 'left' status)* |

**RLS helper functions** (`SECURITY DEFINER` to avoid recursion):
- `auth_user_is_trip_member(p_trip_id)` — returns true if current user has an `accepted` row for this trip
- `auth_user_has_pending_invite(p_trip_id)` — returns true if current user has a `pending` row for this trip
- `find_user_by_contact(p_email, p_phone)` — looks up a user by email/phone (used in `AddMemberSheet`)
- `get_profile_names(p_user_ids uuid[])` — returns `(user_id, full_name, email, phone)` for a list of user IDs, bypassing `user_profiles` RLS so every trip member can read each other's names and contact details. Falls back to `split_part(email, '@', 1)` when `full_name` is blank. Called by `TripProvider._enrichMemberNames()` and `FriendsProvider._enrichNames()` after fetching. Only callable by `authenticated` role.
- `search_users(p_query text)` — returns `(user_id, full_name, email)` for users matching the query by name, email, or phone (digits-stripped match), excluding the caller and any users already in a `pending`/`accepted` friendship with the caller. Limit 20. Called by `FriendsProvider.searchUsers()`. Only callable by `authenticated` role.

#### `trip_stops`
All trip members (organizer or accepted linked user) can SELECT/INSERT/UPDATE/DELETE stops for their trips. Uses `auth_user_is_trip_member()` to avoid recursion.

#### `friendships`
| Policy | Operation | Rule |
|---|---|---|
| `friendships_select` | SELECT | `requester_id = auth.uid() OR addressee_id = auth.uid()` |
| `friendships_insert` | INSERT | `requester_id = auth.uid()` |
| `friendships_update` | UPDATE | `requester_id = auth.uid() OR addressee_id = auth.uid()` |

#### `trip_messages`
| Policy | Operation | Rule |
|---|---|---|
| `trip_messages_select` | SELECT | `auth_user_is_trip_member(trip_id)` |
| `trip_messages_insert` | INSERT | `user_id = auth.uid() AND auth_user_is_trip_member(trip_id)` |

---

### DB Triggers

| Trigger | Table | Event | Function | Effect |
|---|---|---|---|---|
| `on_invite_inserted` | `trip_members` | AFTER INSERT OR UPDATE | `handle_new_invite()` | Calls `send-invite-notification` Edge Function via `pg_net` when `status = 'pending'` AND `user_id IS NOT NULL`. Fires on INSERT (new invite) and on UPDATE where status changes *to* `pending` (re-invite). |
| `on_member_reinvite_check` | `trip_members` | BEFORE UPDATE | `prevent_blocked_reinvite()` | Raises exception `blocked_reinvite` if `old.block_reinvite = true` and `new.status = 'pending'`. Prevents re-inviting a user who opted out. |
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

## Invite & Membership Flow

> Full reference: **`invite_flow.md`** — status lifecycle diagram, RLS policy table, DB objects reference, re-invite and block_reinvite details.

### Adding a member

1. Organizer or accepted member taps "Add member" (FAB on Overview tab or "Add member" in Edit Trip).
2. `AddMemberSheet` shows — type name + email/phone. A debounced lookup (300 ms, with generation counter to discard stale results) calls `find_user_by_contact()` to find a linked account.
3. On confirm, `TripProvider.addMember()` is called:
   - Linked user (`userId != null`): **upsert** on `(trip_id, user_id)`. If a `left`/`declined` row already exists, it is reset to `pending` (re-invite). If `block_reinvite = true`, throws `ReinviteBlockedException` immediately (in-memory fast-reject) with a DB trigger as a safety net.
   - Guest (`userId == null`): plain INSERT, status `accepted` immediately.
4. `on_invite_inserted` trigger fires → FCM push sent to invitee's devices.
5. `InvitationsProvider` on the invitee's device receives the INSERT/UPDATE via Realtime → invite banner appears without needing a re-login.

### Accepting / declining an invitation

The invite banner in `TripsScreen` shows all pending invitations. Tapping **Accept** calls `InvitationsProvider.accept()` (sets `status = 'accepted'`). Tapping **Decline** opens a confirmation dialog with a **"Don't allow future invitations to this trip"** checkbox:
- Without checkbox: `status = 'declined'`
- With checkbox: `status = 'declined'`, `block_reinvite = true`

### Leaving an accepted trip

Available from both the trip list (swipe action) and the AppBar button in Trip Detail. A confirmation dialog includes the same **"Don't allow future invitations to this trip"** checkbox:
- Without checkbox: `status = 'left'` — row preserved, chip shown to other members
- With checkbox: `status = 'left'`, `block_reinvite = true`

The trip is removed from the leaving user's local list immediately. Other members see a "Left" chip via the Realtime UPDATE handler.

### Re-inviting someone who left or declined

`addMember()` calls `.upsert(onConflict: 'trip_id,user_id')` which updates the existing row to `status = 'pending'`. This requires the `trip_members_reinvite` RLS policy (USING: old status is `left`/`declined`; WITH CHECK: new status is `pending`). The `on_invite_inserted` UPDATE trigger fires → new FCM push sent.

If the user had set `block_reinvite = true`:
1. In-memory fast-reject in `addMember()` throws `ReinviteBlockedException` (no network call).
2. DB trigger `on_member_reinvite_check` is the authoritative fallback for stale caches.
3. UI shows: *"This user has opted out of future invitations to this trip"*.

### Consistency guarantee

**Trip records must be consistent across all members at all times.** Every mutation — to trip metadata, stops, or members — must propagate to every accepted member's device via Supabase Realtime without requiring a reload.

`TripProvider._subscribeRealtime()` uses a single channel (`trip_sync_<userId>`) and handles all 7 event types across 3 tables:

| Table | Event | Handler | Notes |
|---|---|---|---|
| `trips` | UPDATE | Reconstructs `Trip` from payload scalars, preserves in-memory `members` + `stops` | See ⚠ rule below |
| `trip_members` | INSERT | `TripMember.fromJson(row)` → append with dedup guard | Covers new-member-added for bystanders |
| `trip_members` | UPDATE | `TripMember.fromJson(row)` → full row replace (all fields) | Covers accept/decline/leave/display-name changes |
| `trip_members` | DELETE | Remove by id | Requires `REPLICA IDENTITY FULL` on `trip_members` for `trip_id` in `oldRecord` |
| `trip_stops` | INSERT | `TripStop.fromJson(row)` → append + re-sort, dedup guard | |
| `trip_stops` | UPDATE | `TripStop.fromJson(row)` → replace in-place + re-sort | |
| `trip_stops` | DELETE | Remove by id | Requires `REPLICA IDENTITY FULL` on `trip_stops` (migration 001700) |

**Realtime publication:** `trips`, `trip_members`, `trip_stops`, `friendships`, and `trip_messages` are all in `supabase_realtime`.

**`REPLICA IDENTITY FULL`** is set on both `trip_members` (migration 001000) and `trip_stops` (migration 001700) so DELETE payloads include `trip_id`.

**⚠ Enforcement rule for new `trips` columns:** The `trips UPDATE` handler reconstructs the `Trip` object field-by-field from the Realtime payload. Stop and member handlers use `fromJson` and are automatically future-proof. **Any new column added to the `trips` table must also be added to the `trips UPDATE` branch of `_subscribeRealtime()` in `trip_provider.dart`.** A code comment marks the exact location.

`InvitationsProvider` subscribes separately (INSERT + UPDATE on `trip_members` filtered by `user_id = currentUser`) to keep the invite banner current for the invited user's own device.

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

`TripMapWidget` renders the trip using **flutter_map** (pure Dart, OpenStreetMap tiles — no native Maps SDK required):
- **Start marker** — green circle with `Icons.trip_origin`.
- **Destination marker** — primary-colour circle with `Icons.location_on`.
- **Stop markers** — numbered circles (primary colour, white border), counted from 1.
- **Route polyline** — fetched from `DirectionsService` (Directions API) on mount and whenever pins change. Solid `4px` line when a real route is loaded; dashed `3px` fallback drawn directly between pins while loading or if the API fails.
- **Compact mode** (`compact: true`) — fixed 220 px height, gestures disabled so a parent `ListView` can still scroll. Non-compact maps are fully interactive (pan + pinch-zoom; rotation disabled).
- **Session-level route cache** — keyed by pipe-separated `lat,lng` waypoints; `prefetchRoute()` is called by the trip list screen so routes are warm before the user opens a trip.
- `TripMapWidget` **exports `LatLng`** from `latlong2` — callers don't need a separate `latlong2` import.

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
- **Member name enrichment** — `trip_members.display_name` is set at invite time (from the inviter's input or the `find_user_by_contact` result). After `load()`, `TripProvider._enrichMemberNames()` calls `get_profile_names` to patch in-memory `displayName` from the canonical `user_profiles.full_name`. This corrects cases where the stored name is an email (e.g. organisers on older records). The enriched state is saved to cache so offline sessions also show correct names.
- **New `trips` column rule** — Any column added to the `trips` table must also be added to the `trips UPDATE` handler in `TripProvider._subscribeRealtime()` (the handler reconstructs the `Trip` object field-by-field from the Realtime payload). Stop and member handlers use `fromJson` and are automatically future-proof.
- **Trip consistency** — any mutation to a trip or its members must propagate via Supabase Realtime. Prefer UPDATE over DELETE for state transitions (e.g. `status = 'left'`) so other members' Realtime UPDATE handlers pick up the change and preserve the row for display.
- **`REPLICA IDENTITY FULL`** is set on `trip_members` so DELETE payloads include the full old row (including `trip_id`), not just the PK — required for the DELETE Realtime handler.
- **RLS never uses direct subqueries into `trip_members`** from `trip_members` policies — always goes through `auth_user_is_trip_member()` or `auth_user_has_pending_invite()` SECURITY DEFINER functions to avoid infinite recursion.
- **Upsert requires a named UNIQUE CONSTRAINT** (not a partial unique index) for PostgREST's `onConflict` to work. The constraint `trip_members_trip_user_unique UNIQUE (trip_id, user_id)` covers this. NULL user_id values are treated as distinct by PostgreSQL so multiple guest rows per trip are allowed.
- **API keys** are never committed. See `~/.claude/CLAUDE.md` for the full key management rules.
