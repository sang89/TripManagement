# External API Reference

All external API integrations used by TripManagement. **When adding a new external API, add an entry here first.** Config keys live in `lib/config/api_keys.dart`.

---

## Supabase

**Purpose:** Primary backend — database and authentication.  
**Config keys:** `kSupabaseUrl`, `kSupabaseAnonKey` (`lib/config/api_keys.dart`)  
**Project URL:** `https://qgeocaectbdfonrorwco.supabase.co` (shared with PropertyManagement)

### Auth

| Operation | Provider |
|-----------|----------|
| Sign up / sign in / sign out | `lib/providers/auth_provider.dart` |

### Database tables

| Table | Used by provider |
|-------|-----------------|
| `trips` | `TripProvider` |
| `trip_members` | `TripProvider` |
| `trip_stops` | `TripProvider` |

*(PropertyManagement tables also exist in this project — they are managed by PropertyManagement's `supabase/migrations/` and ignored by TripManagement's Flutter code.)*

### Schema changes

Follow the migration workflow in `Supabase_migration.md`. Because both apps share the same Supabase project, always keep TripManagement's `supabase/migrations/` in sync with PropertyManagement's when new migrations are added there.

---

## Supabase Edge Functions

Edge Functions are Deno TypeScript functions deployed to Supabase. They hold server-side secrets and handle AI proxying.

### Inventory

| Function | Path | Purpose |
|----------|------|---------|
| `ai-chat` | `supabase/functions/ai-chat/index.ts` | AI chat proxy — holds `GEMINI_API_KEY`, selects model by tier. Shared with PropertyManagement. |

### Deployment workflow

```bash
# Deploy a function (run from project root)
supabase functions deploy ai-chat

# Set / update a secret
supabase secrets set GEMINI_API_KEY=<key>

# List deployed secrets (names only, values hidden)
supabase secrets list

# View live logs
supabase functions logs ai-chat
```

### Local testing

```bash
# Serve all functions locally (requires Docker)
supabase start
supabase functions serve
# Function available at: http://localhost:54321/functions/v1/ai-chat
# Force it from the app: flutter run --dart-define=FORCE_EDGE_FUNCTION=true
```

### Adding a new Edge Function

1. Create `supabase/functions/<name>/index.ts`.
2. Add it to the inventory table above.
3. Deploy: `supabase functions deploy <name>`.
4. Set secrets: `supabase secrets set KEY=value`.
5. Document the request/response contract in the relevant section below.

### Updating the AI model

All model selection lives in `modelForUser(userId)` inside `supabase/functions/ai-chat/index.ts`. Redeploy the function — no Flutter code changes needed:

```bash
supabase functions deploy ai-chat
```

---

## Google Gemini

**Purpose:** AI trip planning assistant (planned — wired up but no trip-specific tools yet).  
**Base URL:** `https://generativelanguage.googleapis.com/v1beta`  
**Model:** `gemini-2.5-flash-lite` (configurable per tier via Edge Function)

### Service layer (provider-agnostic)

| Build mode | Implementation | Key location |
|---|---|---|
| Release | `EdgeFunctionAIChatService` | Supabase secret `GEMINI_API_KEY` |
| Debug | `GeminiDirectAIChatService` | `kGeminiApiKey` in `api_keys.dart` |

Override in debug: `--dart-define=FORCE_EDGE_FUNCTION=true`

| File | Role |
|------|------|
| `lib/services/ai_chat_service.dart` | Abstract interface + `AIChatService.create()` factory |
| `lib/services/edge_function_ai_chat_service.dart` | Production — proxies through Edge Function |
| `lib/services/gemini_direct_ai_chat_service.dart` | Dev — calls Gemini directly via `GeminiService` |
| `lib/services/gemini_service.dart` | Raw Gemini HTTP client, retry/backoff (429 handling) |
| `lib/services/gemini_tools.dart` | Tool declarations for trip CRUD (currently empty) |
| `supabase/functions/ai-chat/index.ts` | Edge Function — holds key, selects model by tier (shared) |

### Adding trip tools

Add function declarations to `lib/services/gemini_tools.dart`:
```dart
const Set<String> kWriteToolNames = {'create_trip', 'update_trip', ...};
const List<Map<String, dynamic>> kGeminiTools = [
  {
    'name': 'create_trip',
    'description': '...',
    'parameters': { ... },
  },
];
```

Write tools must be in `kWriteToolNames` — the tool-call loop uses this set to gate the native confirmation dialog.

### Edge Function request/response

**Request** (from `EdgeFunctionAIChatService`):
```json
{ "systemContext": "...", "contents": [...], "tools": [...] }
```

**Response** (one Gemini round; tool-call loop stays in Flutter):
```json
{ "type": "text", "text": "..." }
{ "type": "tool_call", "name": "create_trip", "args": {}, "modelParts": [...] }
```

---

## Google Places API (New)

**Purpose:** Address autocomplete and lat/lng lookup for trip destinations and stops.  
**Config key:** `kGooglePlacesApiKey` (`lib/config/api_keys.dart`)  
**Enabled APIs required:** Places API (New) — already enabled on this key.

| Endpoint | Method | Used for |
|----------|--------|---------|
| `https://places.googleapis.com/v1/places:autocomplete` | POST | Autocomplete suggestions |
| `https://places.googleapis.com/v1/places/{placeId}` | GET | Fetch formatted address + coordinates |

| File | Role |
|------|------|
| `lib/services/trip_places_service.dart` | Entry point — platform-adaptive, in-memory cache |
| `lib/services/trip_places_stub.dart` | No-op stub for non-web builds |
| `lib/services/trip_places_web.dart` | Web implementation via Google Maps JS SDK + `dart:js_interop` |
| `lib/widgets/places_autocomplete_field.dart` | Inline autocomplete text field |
| `lib/widgets/destination_search_dialog.dart` | Full-screen search dialog |

**Platform notes:**
- **Native (iOS/Android):** REST calls via `http` package.
- **Web:** Loads Google Maps JS SDK and calls `google.maps.importLibrary('places')` — conditional export via `if (dart.library.js_interop)`.

**Caching:**
- Suggestions: in-memory, 1-hour TTL per query (`CacheEntry`).
- Place details: in-memory, indefinite per session.

---

## Google Maps — Maps SDK

**Purpose:** Interactive map in `TripMapWidget` showing the trip destination, ordered stops, and the route between them.  
**Config key:** `kGooglePlacesApiKey` (same key as Places)  
**Enabled APIs required:** Maps SDK for Android, Maps SDK for iOS, Maps JavaScript API — already enabled.

| File | Role |
|------|------|
| `lib/widgets/trip_map_widget.dart` | Map widget — markers, polyline, fit-bounds camera |
| `android/app/src/main/AndroidManifest.xml` | `com.google.android.geo.API_KEY` meta-data |
| `ios/Runner/AppDelegate.swift` | `GMSServices.provideAPIKey(...)` |
| `web/index.html` | Maps JS script `src` with key param |

**⚠ Key rotation:** If `kGooglePlacesApiKey` is rotated, update all four locations (Dart constant + 3 native files).

---

## Google Maps — Directions API

**Purpose:** Fetch real road-following routes between trip stops (replaces straight-line polylines).  
**Config key:** `kGooglePlacesApiKey` (same key)  
**Enabled APIs required:** **Directions API** — must be enabled separately in Google Cloud Console.

| Endpoint | Method | Used for |
|----------|--------|---------|
| `https://maps.googleapis.com/maps/api/directions/json` | GET | Driving route through ordered waypoints |

| File | Role |
|------|------|
| `lib/services/directions_service.dart` | REST call, encoded-polyline decoder |
| `lib/widgets/trip_map_widget.dart` | Calls `DirectionsService.getRoute()` on mount and pin change |

**Request params:** `origin={lat,lng}`, `destination={lat,lng}`, `waypoints={lat,lng}|...` (middle stops), `key=`.

**Response path:** `routes[0].overview_polyline.points` → Google encoded polyline string.

**Fallback:** While the request is in flight or if the API returns an error, `TripMapWidget` draws a dashed straight-line polyline and silently retries on the next pin change.

---

## Adding a new external API

1. Add the API key / base URL constant to `lib/config/api_keys.dart`.
2. Create a service file under `lib/services/<name>_service.dart`.
3. Add an entry to this file (`api.md`) covering: purpose, config key, endpoints, and relevant files.
4. If the API is platform-specific, follow the conditional-export pattern in `lib/services/trip_places_service.dart`.

### Swapping the AI provider

The AI service layer is provider-agnostic. To add a different LLM:
1. Update `supabase/functions/ai-chat/index.ts` to call the new provider and translate its response into the same `{ type, text/name/args/modelParts }` DTO.
2. No Flutter code changes needed.
3. Update this file with the new provider's details.
