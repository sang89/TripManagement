# App Architecture

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
| Backend / Database | Supabase (Postgres + Auth) | `supabase_flutter ^2.9.0` |
| Secure storage | Flutter Secure Storage | `flutter_secure_storage ^9.2.4` |
| Offline cache | SharedPreferences JSON cache | `shared_preferences ^2.3.0` |
| Offline queue | Write-ahead queue, replayed on reconnect | (same package) |
| Connectivity | Network state monitor | `connectivity_plus ^6.1.0` |
| Client UUID gen | Offline ID generation | `uuid ^4.5.0` |
| Address / place search | Google Places API (New) — mobile + web | `http ^1.4.0` |
| Maps | Google Maps Flutter | `google_maps_flutter ^2.9.0` |
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
│   ├── trip_member.dart    # TripMember (role: organizer/member; optional userId for app users)
│   └── trip_stop.dart      # TripStop (title, address, lat/lng, arrive_at, depart_at, sort_order)
├── providers/              # ChangeNotifiers — hold state, talk to Supabase
│   ├── auth_provider.dart  # Auth session; login/register/logout; userName derived from metadata
│   ├── trip_provider.dart  # All trips + nested stops/members; full CRUD
│   └── settings_provider.dart  # Theme mode persistence (flutter_secure_storage)
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── shell/
│   │   └── shell_scaffold.dart     # StatefulShellRoute wrapper; 2-tab bottom nav
│   └── trips/
│       ├── trips_screen.dart       # Trip list; swipe-to-delete; tap → detail
│       ├── trip_form_screen.dart   # Create / edit trip (destination, dates, notes, compact map preview)
│       └── trip_detail_screen.dart # Trip detail — tabbed: Overview (map + stops) + Members
├── services/
│   ├── ai_chat_service.dart            # Abstract interface + AIChatService.create() factory
│   ├── edge_function_ai_chat_service.dart   # Release — proxies through Supabase Edge Function
│   ├── gemini_direct_ai_chat_service.dart   # Dev — calls Gemini directly
│   ├── gemini_service.dart             # Raw Gemini HTTP client, retry/backoff logic
│   ├── gemini_tools.dart               # Tool declarations (empty — trip tools added here as built)
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
│   ├── trip_map_widget.dart            # Google Map with numbered stop markers + real road polyline
│   ├── trip_stop_form_sheet.dart       # Add / edit stop bottom sheet
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
| Journal | `book_outlined` | `/journal` → *(placeholder)* | — |

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
| `TripProvider` | All trips + members + stops | `load()`, `clear()`, `getById(id)`, CRUD for trips/members/stops |
| `SettingsProvider` | Theme mode preference | `load()`, `setThemeMode(ThemeMode)` |
| `ConnectivityService` | Network state | `init()`, `isOnline` — notifies on change |
| `OfflineQueue` | Pending write operations | `init()`, `enqueue()`, `flush()`, `pendingCount`, `hasPending` |

Providers are pre-loaded on startup if the user is already logged in. `AuthProvider` notifies on auth state change, which triggers `TripProvider.load()` or `TripProvider.clear()`.

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

| Table | Parent | Key columns |
|---|---|---|
| `trips` | — | `created_by` (FK→auth.users), `title`, `start_location`, `start_lat`, `start_lng`, `destination`, `destination_lat`, `destination_lng`, `start_at`, `end_at`, `notes`, `updated_at` |
| `trip_members` | `trips` | `trip_id`, `user_id` (nullable FK→auth.users), `display_name`, `role` (organizer/member), `email`, `phone` |
| `trip_stops` | `trips` | `trip_id`, `title`, `address`, `address_lat`, `address_lng`, `arrive_at`, `depart_at`, `notes`, `sort_order` |

**Data loading:** A single aggregated query fetches all nested data per trip:
```dart
.select('*, trip_members(*), trip_stops(*)')
.order('created_at', ascending: false)
```
Stops are sorted client-side by `sort_order` in `Trip.fromJson`.

**Row-Level Security (RLS):**
- `trips` — creator can insert/update/delete; creator + members can select.
- `trip_members` — organizer can insert/delete; creator + own row can select.
- `trip_stops` — all trip members (creator or linked user) can select/insert/update/delete.

**RLS note:** The `trip_stops` policies use a subquery into `trip_members` to check membership. A fix for a potential recursion issue is in `20260526130000_fix_rls_recursion.sql`.

**Schema management:** All changes go through migration files in `supabase/migrations/`. See `Supabase_migration.md` for the workflow. Because both apps share the same Supabase project, TripManagement's `supabase/migrations/` contains **all** remote migrations (including PropertyManagement's). Keep it in sync when PropertyManagement adds new migrations.

---

## Map & Route Display

`TripMapWidget` renders the trip on a Google Map:
- **Destination marker** — blue default marker (azure hue).
- **Stop markers** — numbered circles rendered as custom `BitmapDescriptor` images.
- **Route polyline** — fetched from `DirectionsService` (Directions API) on mount and whenever pins change. Falls back to a dashed straight-line while the request is in flight or if the API returns an error.

**Pin order** (both detail screen and form preview): start (green) → numbered stops → destination (blue). This order is passed directly to `DirectionsService` as the waypoints list, so the road route follows the same sequence.

`DirectionsService.getRoute(waypoints)`:
1. Calls `GET https://maps.googleapis.com/maps/api/directions/json` with origin, destination, and intermediate waypoints.
2. Extracts `routes[0].overview_polyline.points` (Google encoded polyline).
3. Decodes the encoded string into `List<LatLng>` using the standard algorithm.

**Required API:** Directions API must be enabled in Google Cloud Console for `kGooglePlacesApiKey`.

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
- **All form fields are optional** — no required validators; users fill in what they know.
- **Swipe to delete** everywhere (via `Slidable`) with a confirmation dialog before destructive actions.
- **`flutter analyze lib/ test/` must pass** before any session ends — scoped to exclude build artefacts.
- **Schema changes** always go through a migration file in `supabase/migrations/`, never the Supabase dashboard directly.
- **AI writes always require a native confirmation dialog** — never rely on LLM prompt instructions alone.
