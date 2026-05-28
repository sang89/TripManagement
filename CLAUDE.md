# TripManagement — Claude Code Rules

See `~/.claude/CLAUDE.md` for global rules shared across all apps (UI wrappers, cross-platform
compatibility, layout overflow prevention, testing requirements, post-edit validation).

## Documentation

These files are the authoritative reference for this project. Read the relevant doc before
implementing any feature in its domain:

| File | Contents |
|---|---|
| `architecture.md` | Full folder structure, tech stack, nav routes, state management, DB schema (tables, columns, RLS, triggers), Realtime coverage, push notifications, key conventions |
| `invite_flow.md` | Complete invite lifecycle — add member, accept, decline, leave, block reinvite, re-invite, RLS policy table, DB objects reference |
| `api.md` | Every external API — Supabase, Gemini, Google Places, Maps SDK, Directions API |
| `Supabase_migration.md` | Migration workflow, how to add/push migrations, syncing with PropertyManagement |

**Rule:** When adding a new external API, add an entry to `api.md` first. When changing the DB schema, follow `Supabase_migration.md` — never run SQL in the Supabase dashboard.

**Rule:** After any session that adds a feature, changes the DB schema, adds a new provider/widget/screen, or changes a behaviour described in these docs — **update `architecture.md` and any relevant domain doc (`invite_flow.md`, etc.) before finishing**. These files must always reflect the current state of the codebase so future Claude sessions start with accurate context.

## App architecture

This app shares the same Supabase project as PropertyManagement — the same user account
works in both apps. Supabase URL and anon key live in `lib/config/api_keys.dart` (git-ignored).

See `architecture.md` for the full folder structure and conventions. Quick reference:

```
lib/
├── config/         API keys (git-ignored)
├── models/         trip.dart, trip_member.dart, trip_stop.dart
├── providers/      auth_provider, trip_provider, invitations_provider, settings_provider
├── screens/
│   ├── auth/       Login, Register
│   ├── profile/    Profile edit screen
│   ├── settings/   Settings screen (theme, language, account)
│   ├── shell/      ShellScaffold (bottom nav — Trips + Journal tabs; invite badge)
│   └── trips/      trips_screen (list + invite banner), trip_form_screen (create/edit), trip_detail_screen
├── services/       Places, Directions, AI chat, push notifications (see api.md)
├── theme/          Re-export shim → shared_ui AppTheme
├── widgets/        trip_card, trip_map_widget, trip_stop_form_sheet, add_member_sheet
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

## Invite & membership

See `invite_flow.md` for the full reference. Key rules:
- Every mutation to `trip_members` must propagate to all members' devices via Supabase Realtime — see `architecture.md → Consistency guarantee`.
- Prefer UPDATE over DELETE for state transitions (e.g. `status = 'left'`).
- `trip_members` has `REPLICA IDENTITY FULL` — DELETE payloads carry the full old row.
- The `trip_members_trip_user_unique` UNIQUE CONSTRAINT (not a partial index) on `(trip_id, user_id)` enables PostgREST upsert. NULLs are treated as distinct, so guest rows are unaffected.

## Map & routes

`TripMapWidget` (`lib/widgets/trip_map_widget.dart`) renders destination + numbered stops.
`DirectionsService` (`lib/services/directions_service.dart`) fetches real road routes from
the Google Maps Directions API. The Directions API must be enabled in Google Cloud Console
(same key as Places — `kGooglePlacesApiKey`).

See `api.md → Google Maps — Directions API` for full details.

## Localization

10 languages: en, fr, de, es, ar, ja, ko, pt, vi, zh. ARB files live in `lib/l10n/`.
Run `flutter gen-l10n` after editing any `.arb` file. Always add new strings to **all 10**
language files — use a Python script to batch-insert into non-English files anchored on a
nearby key, then verify with `flutter gen-l10n`.

## Running analysis

Always scope to `lib/` and `test/` to exclude Xcode/SPM build artefacts:

```bash
flutter analyze lib/ test/
flutter test
```
