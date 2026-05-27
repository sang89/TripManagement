# TripManagement — Claude Code Rules

See `~/.claude/CLAUDE.md` for global rules shared across all apps (UI wrappers, cross-platform
compatibility, layout overflow prevention, testing requirements, post-edit validation).

## Documentation

These files are the authoritative reference for this project. Read the relevant doc before
implementing any feature in its domain:

| File | Contents |
|---|---|
| `architecture.md` | Full folder structure, tech stack, nav routes, state management, DB schema, map/route details |
| `api.md` | Every external API — Supabase, Gemini, Google Places, Maps SDK, Directions API |
| `Supabase_migration.md` | Migration workflow, how to add/push migrations, syncing with PropertyManagement |

**Rule:** When adding a new external API, add an entry to `api.md` first. When changing the DB schema, follow `Supabase_migration.md` — never run SQL in the Supabase dashboard.

## App architecture

This app shares the same Supabase project as PropertyManagement — the same user account
works in both apps. Supabase URL and anon key live in `lib/config/api_keys.dart` (git-ignored).

See `architecture.md` for the full folder structure and conventions. Quick reference:

```
lib/
├── config/         API keys (git-ignored)
├── models/         trip.dart, trip_member.dart, trip_stop.dart
├── providers/      auth_provider, settings_provider, trip_provider
├── screens/        UI screens, organised by feature
│   ├── auth/       Login, Register
│   ├── shell/      ShellScaffold (bottom nav — Trips + Journal tabs)
│   └── trips/      trips_screen (list), trip_form_screen (create/edit), trip_detail_screen
├── services/       Places, Directions, AI chat (see api.md)
├── theme/          Re-export shim → shared_ui AppTheme
├── widgets/        trip_card, trip_map_widget, trip_stop_form_sheet
└── main.dart       App entry point, StatefulShellRoute, provider wiring
```

## Shared UI

Import shared widgets and theme via:
```dart
import 'package:shared_ui/shared_ui.dart';
```

The `lib/theme/app_theme.dart` shim re-exports `AppTheme` from `shared_ui` so existing
relative imports (`import '../theme/app_theme.dart'`) also work.

## AI service

`lib/services/ai_chat_service.dart` mirrors the pattern from PropertyManagement:
- **Release**: calls the shared Supabase `ai-chat` Edge Function (same function, same Supabase project)
- **Debug**: calls Gemini directly using `kGeminiApiKey`

Add trip-specific Gemini tool declarations to `lib/services/gemini_tools.dart` as AI features
are built. The Edge Function (`supabase/functions/ai-chat/`) is shared — do not add
trip-specific logic there; use the tools list passed in the request body instead.

See `api.md` for the full AI service architecture.

## Navigation

GoRouter with auth redirect guard and `StatefulShellRoute.indexedStack` for the 2-tab shell.
Routes:
- `/login`, `/register` — auth screens
- `/trips` — trip list (shell tab 0)
- `/trip/new`, `/trip/:id`, `/trip/:id/edit` — trip CRUD (also shell tab 0)
- `/journal` — placeholder (shell tab 1)

## Database

All Supabase schema changes must go through migration files in `supabase/migrations/`.
See `Supabase_migration.md` for the full workflow.

Both apps share the same Supabase project (`qgeocaectbdfonrorwco`), so TripManagement's
`supabase/migrations/` must contain ALL remote migrations (including PropertyManagement's).
Keep it in sync by copying any new PropertyManagement migration files here too.

Never instruct the user to run SQL manually in the Supabase dashboard — always use `supabase db push`.

Trip data is isolated per user via Supabase Row Level Security — add RLS policies to every
new table.

## Map & routes

`TripMapWidget` (`lib/widgets/trip_map_widget.dart`) renders destination + numbered stops.
`DirectionsService` (`lib/services/directions_service.dart`) fetches real road routes from
the Google Maps Directions API. The Directions API must be enabled in Google Cloud Console
(same key as Places — `kGooglePlacesApiKey`).

See `api.md → Google Maps — Directions API` for full details.

## Localization

English strings are currently hardcoded. When adding a second language, set up Flutter's
built-in l10n (ARB files, `flutter gen-l10n`) following the same pattern as PropertyManagement.
Add `generate: true` to `pubspec.yaml` and create `lib/l10n/` at that point.

## Running analysis

Always scope to `lib/` and `test/` to exclude Xcode/SPM build artefacts:

```bash
flutter analyze lib/ test/
flutter test
```
