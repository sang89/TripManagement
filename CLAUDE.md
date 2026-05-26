# TripManagement — Claude Code Rules

See `~/.claude/CLAUDE.md` for global rules shared across all apps (UI wrappers, cross-platform
compatibility, layout overflow prevention, testing requirements, post-edit validation).

## App architecture

This app shares the same Supabase project as PropertyManagement — the same user account
works in both apps. Supabase URL and anon key live in `lib/config/api_keys.dart` (git-ignored).

**Folder structure:**
```
lib/
├── config/         API keys (git-ignored)
├── models/         Data models (add as features are built)
├── providers/      ChangeNotifier providers — auth, settings, and trip-domain providers
├── screens/        UI screens, organised by feature
│   ├── auth/       Login, Register
│   └── home/       Trip list (home screen)
├── services/       Supabase queries, AI chat service
├── theme/          Re-export shim → shared_ui AppTheme
└── main.dart       App entry point, GoRouter, provider wiring
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

## Navigation

GoRouter with auth redirect guard. Add new routes in `main.dart`.
Current routes: `/login`, `/register`, `/home`.

As the app grows, migrate to a `StatefulShellRoute` with bottom navigation tabs (see
PropertyManagement's `shell_scaffold.dart` for the pattern).

## Database

All Supabase schema changes must go through migration files. Create a `supabase/` folder
mirroring PropertyManagement's structure when the first migration is needed.

Trip data is isolated per user via Supabase Row Level Security — add RLS policies to every
new table.

## Localization

English strings are currently hardcoded. When adding a second language, set up Flutter's
built-in l10n (ARB files, `flutter gen-l10n`) following the same pattern as PropertyManagement.
Add `generate: true` to `pubspec.yaml` and create `lib/l10n/` at that point.
