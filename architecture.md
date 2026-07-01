# App Architecture

> **Keep this file current.** After any session that adds a feature, changes the DB schema, adds a provider/widget/screen, or changes a described behaviour — update this file and any relevant domain doc (`invite_flow.md`, etc.) before finishing. See `CLAUDE.md` for the full documentation rule.

## Overview

**TripManagement** is a Flutter app for planning and organising events — trips, birthdays, weddings, sports tournaments, quick bites, and signups. All event types share chat, guests, photos, and expenses. Trip-type events additionally feature itinerary stops, a map, and a member-invite flow. It shares the same Supabase project and Google Cloud project as PropertyManagement, so the same user account works in both apps. Targets iOS, Android, and web.

---

## Design Philosophy

**Colorful and fun. This is a hard rule — not a suggestion.**

This app should feel vibrant and joyful — not corporate, not minimal, not grey. Every screen a user touches should feel alive. Concrete rules:

### Colour
- Use gradients, bright accent colours, and bold icons liberally on cards, tiles, and buttons.
- Event-type tiles use per-type gradient backgrounds (blue, pink, purple, orange, green).
- Section headers, labels, and icon accents must use the section's identity colour — never fall back to `Colors.grey` as a primary colour.
- Avoid flat grey placeholders; always give elements a colour hint that matches their category.
- When adding new UI components, default to "more colourful" rather than "more neutral".

### Buttons and CTAs
- **Primary action buttons must use a gradient** — never a flat solid fill. Use `LinearGradient` in a `DecoratedBox`/`Container` + `Material`/`InkWell` pattern, not `ElevatedButton.style` (which can't do gradient).
- Add a coloured `boxShadow` (glow) beneath every gradient button — `blurRadius: 14`, `offset: Offset(0, 5)`, colour = button's dominant colour at `alpha: 0.45`.
- The glow and gradient colour should reflect the action type: green for positive/join actions, amber/orange for waitlist, red for destructive actions.
- Secondary/destructive inline actions use `OutlinedButton` with a coloured border matching the action type.

### Icons and emoji
- Food/category icons must use naturally-coloured emoji rather than monochrome Material icons wherever possible.
- Vote/interaction elements should have a fun, tactile feel — gradient circles, animated state transitions, coloured shadows.

### Collapsible sections
- Section tiles (e.g. guide sections) must use a coloured icon and a coloured title — never a plain grey label.
- Each section gets its own identity colour: organiser = orange, member = pink, utility/info = purple, danger = red.

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
| QR code rendering | qr_flutter (pure Dart/Canvas, works on iOS/Android/web) | `qr_flutter ^4.1.0` |
| GIF image caching | cached_network_image (network image with disk cache) | `cached_network_image ^3.4.1` |
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
│   ├── event.dart          # Event; EventType enum (trip/birthday/wedding/tournament/quickBites/signup); embeds List<EventGuest> + List<EventStop>; trip-specific fields (startLocation, startLat/Lng); quick-bites fields (budgetPerHead, cuisineTags, rsvpDeadline, vibe); birthday fields (honoreeDisplayName, birthYear, predictionsRevealedAt, wishesRevealedAt); signup fields (waitlistEnabled, signupLockHours); getters isBirthday, isSignup, isTournament, isSignupLocked, honoreeAge
│   ├── event_guest.dart    # EventGuest — id, eventId, userId (nullable), displayName, status (going/maybe/declined/pending/accepted/left), invitedBy, blockReinvite, role, rsvpNote (nullable); isWaitlisted getter
│   ├── event_session.dart  # EventSession (id, eventId, sessionNumber, startAt, endAt, inviteCode, createdAt, goingCount, waitlistCount, capacity, waitlistEnabled, signupLockHours, isPublic, requiresApproval); computed: isFull, isLocked, hasEnded, isUpcoming; copyWithCounts(). EventSessionRosterEntry (id, sessionId, userId nullable, displayName, email, phone, status going/waitlisted/pending_review, signupOrder, attended nullable, signupConfirmed, signedUpAt); computed: isGoing, isWaitlisted; copyWith(status, attended, signupConfirmed, signupOrder)
│   ├── tournament.dart     # Tournament models (tournament events): free-form sport + skill_level (Strings, not enums); enums Discipline/DivisionFormat/ScoringSystem/DivisionStatus/EntrantStatus/MatchStatus/BracketType/CourtStatus (each fromString/dbValue); ScoringConfig (JSONB value object, free-form sport label + editable rules, defaultFor(String)); TournamentDivision (+ copyWithCounts/copyWith with clearX flags); TournamentEntrant; TournamentMatch (+ nested MatchGame, next-match auto-advance plumbing); Court; BracketSegmentConfig (builder-only, not persisted — one division lane in the builder); DraftEntrant (builder-only, a not-yet-registered entrant typed in the pool)
│   ├── event_stop.dart     # EventStop — id, eventId, title, address, lat/lng, arriveAt, departAt, notes, sortOrder
│   ├── event_message.dart  # EventMessage — id, eventId, userId, content, enriched senderName
│   ├── event_photo.dart    # EventPhoto — id, eventId, storagePath, caption, publicUrl (resolved at load); has copyWith(caption)
│   ├── event_expense.dart  # EventExpense + EventExpenseSplit for cost splitting
│   ├── event_bring_item.dart # EventBringItem — id, eventId, label, quantity, claimedBy (nullable), claimedByName, claimedAt, createdBy, createdAt
│   ├── event_poll.dart     # EventPollReaction + EventPollVote + EventPollOption (+ optional placeMetadata + reactions list) + EventPoll; helpers: totalVotes, votesFor, myVoteOptionId, myVoteId, reactionsFor, myReactionEmojis; pollType: 'general'|'restaurant'|'activity'|'cake'
│   ├── event_wishlist_item.dart # EventWishlistItem — id, eventId, label, priceRange, link, createdBy, claimedBy (nullable), claimedByName, claimedAt, isReceived
│   ├── event_gift_pool.dart # EventGiftPool (id, eventId, giftName, targetAmount, pledges[]) + EventGiftPledge; totalPledged computed
│   ├── event_prediction.dart # EventPrediction — id, eventId, submittedBy, submittedByName, predictionText, createdAt; sealed until event.predictionsRevealedAt
│   ├── event_wish.dart     # EventWish — id, eventId, submittedBy, submittedByName, wishText, createdAt; sealed until event.wishesRevealedAt
│   ├── event_toast.dart    # EventToast — id, eventId, submittedBy, submittedByName, toastText, toastType ('sweet'|'funny'|'poem'), sortOrder, createdAt
│   ├── friendship.dart     # Friendship — id, requesterId, addresseeId, status, enriched name
│   └── blocked_user.dart   # BlockedUser — userId, fullName, avatarUrl, blockedAt
├── providers/              # ChangeNotifiers — hold state, talk to Supabase
│   ├── auth_provider.dart          # Auth session; login/register/logout
│   ├── event_provider.dart         # All events (organizer + guest); stops/members/photos/expenses; birthday CRUD (wishlist, gift pool, predictions, wishes, toasts, reveal mechanics); signup session CRUD (fetchUpcomingSessions, fetchPastSessions, loadMorePastSessions, addSession, cancelSessionSignup, removeSessionRosterEntry, promoteSessionRosterEntry, demoteSessionRosterEntry, reorderSessionRoster, markSessionAttendance, toggleSessionConfirmed, approveSessionRosterEntry, rejectSessionRosterEntry); session caches: _upcomingSessions / _pastSessions (paginated, 20/page) + _sessionRosters (100/page) + _mySessionStatuses; queue activity CRUD (fetchSessionQueues, createQueueActivity, deleteQueueActivity, joinQueue, leaveQueue, startQueue, advanceRound, joinFreePool, leaveFreePool); queue caches: _sessionQueues / _queueEntries / _freePool; full CRUD + Realtime; pendingInviteCount for badge; setEventArchived(eventId, bool) — per-user "Move to Past" toggling the caller's own event_guests.is_archived (synced to own devices via the existing event_guests UPDATE handler); addPollOption(); createPoll() accepts pollType param; static applyOrder()
│   ├── event_chat_provider.dart    # Event-scoped chat; paginated load + Realtime INSERT; scoped to /event/:id route
│   ├── invitations_provider.dart   # Pending trip-event invitations for the current user; Realtime
│   ├── friends_provider.dart       # Friend list + requests; two Realtime channels; searchUsers RPC
│   ├── notifications_provider.dart # In-app notification center; fetches trip_notifications table (TM-only; never the shared notifications table); Realtime Broadcast subscription on trip_notifications_{userId}; unreadCount badge; markRead/markAllRead/deleteNotification; static tripTypes + propertyManagementTypes for isolation tests
│   ├── blocked_users_provider.dart # Global block list; blockUser RPC + optimistic unblock
│   └── settings_provider.dart      # Theme mode + language persistence
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── events/
│   │   ├── events_screen.dart       # Events tab (shell tab 0): Upcoming / Invited / Past tabs + type-filter chips + list/calendar toggle; type tiles grid (Trip/Birthday/Wedding/Tournament/Quick Bites). Tab membership uses Event.isPastFor(userId): an event is "Past" when its end date has passed (auto) OR the user manually archived it. Single-day events (no endAt) never auto-move — long-press a card → "Move to Past" / "Move to Upcoming" (per-user, via EventProvider.setEventArchived → event_guests.is_archived). Past-tab cards render desaturated + faded (ColorFiltered greyscale + Opacity 0.6) in EventCard.
│   │   ├── event_form_screen.dart   # Create / edit event; EventType picker; trip-type shows start location + destination fields; quick-bites shows budget/vibe/cuisine/rsvp fields; birthday shows honoree name + birth year fields
│   │   ├── event_detail_screen.dart # Dynamic tabs: trips = Info/Route/Map/Chat/Photos/Organize; non-trip = Info/Chat/Photos/Organize; birthday = Info/Chat/Photos/Organize/Memories. Photos tab (innovative overhaul): Polaroid Wall grid (_PolaroidCard — spring-in entrance via elasticOut, random ±10° tilt, white card with caption strip); AI Memory Generator (_MemoryButton — gradient pill, calls Gemini via direct HTTP, renders _MemoryCardModal with photo fan collage + italic memory text + hashtags + Share/Copy); Cinematic Stories Viewer (_StoriesViewerPage replaces old page viewer — Ken Burns zoom/pan per photo via _KenBurnsImage, Instagram-style per-photo progress bars auto-advancing every 5s, double-tap heart burst, long-press pause, swipe-down dismiss, caption sheet, delete); rate-limit 20 uploads/hour per user; multi-select batch upload. `photo_view` package removed; `flutter_staggered_grid_view` stays in pubspec but unused. Chat tab enhanced: @mention overlay (_MentionSuggestionsBar) shows filtered member list when typing `@`, inserts `@[userId:displayName]` token; emoji-insert button (reuses _EmojiPickerSheet in insertMode); GIF button opens _GifPickerSheet (Giphy API trending + search, 2-col grid; `kGiphyApiKey`); message bubbles render GIFs via CachedNetworkImage and mention tokens as teal RichText spans; chat background customisable per-event via _ChatThemePickerSheet (8 gradient/solid presets); theme persisted in events.chat_background and propagated live via Realtime. Organize inner tabs: Roster/Activity/Polls/Invite (signup — "Activity" tab replaces Expenses); Todo/Expenses/Polls/Explore (trip); Todo/Expenses/Polls (+Cravings for quickBites; +Celebrate/Gifts for birthday). Trip Explore tab: _ExploreTab fetches Viator Affiliate API activities (sorted by cheapest/top-rated), shows _ActivityCard per result (image/rating/price/platform badge/"Book on Viator" button), plus _PlatformBrowseButton rows for GetYourGuide and Klook affiliate browse links. Signup extras: _SignupRosterTab (sessions list + "Add session" → _SessionCard per session; _SessionRosterRow cards with confirmation/attendance toggles, ReorderableListView, swipe-to-promote/demote/remove via _SlideAction; _SignupInviteTab shows per-session QR + session picker + add-manually). Birthday extras: _BirthdayHeroCard, _CelebrateTab, _GiftsTab, _MemoriesTabGroup. Polls (all event types incl. Cravings): each `_PollCard` header shows a gradient `🎡 Spin` pill (`_SpinWheelButton`, shown when ≥2 options) that opens `PollWheelSheet` — a weighted spin wheel (arc ∝ votes; 0-vote options keep a min slice) that randomly picks a "fate decides" winner without mutating votes
│   │   ├── event_invite_screen.dart # Public RSVP screen — no auth required; fetches event by invite_code
│   │   ├── session_invite_screen.dart # Public session signup — no auth required; fetches session by invite_code via get_session_by_invite_code; calls rsvp_session; route /session/invite/:code
│   │   └── session_scan_screen.dart # In-app QR scanner (mobile_scanner) — scans a session QR, shows join sheet (session info + claim/waitlist button), calls rsvp_session; opened from the signup Invite tab "Scan a QR code" button
│   ├── friends/
│   │   ├── friends_screen.dart  # Friends tab (shell tab 1): accepted list + search + Requests tab with badge; "From Contacts" AppBar button (non-web)
│   │   └── contacts_screen.dart # Batch-match device contacts against registered users; "Add to Trip" (opens trip-event picker) + share-sheet invite
│   ├── profile/
│   │   └── profile_screen.dart     # Gradient header with avatar + _TierBadge (Free = two-part amber upgrade pill; Pro = accent workspace_premium pill); InfoCards for personal/contact info; _AccountCard with save (when editing) + sign-out (shell tab 2)
│   ├── settings/
│   │   ├── settings_screen.dart      # Theme, language, account, notifications, privacy sections
│   │   └── blocked_users_screen.dart # List of globally blocked users with Unblock action
│   ├── notifications/
│   │   └── notifications_screen.dart  # Notification center; ListView of AppNotification tiles with relative timestamps; swipe-to-delete; mark-all-read action; empty state; navigates to target route on tap
│   └── shell/
│       └── shell_scaffold.dart     # StatefulShellRoute wrapper; AppBar with bell icon (NotificationsProvider badge) → /notifications; bottom nav with 3 tabs (Events + pending badge, Friends + request badge, Profile) + 1 action button (Join / QR scanner → SessionScanScreen) + raised center "Live" button (cycles through currently-live events/sessions)
├── services/
│   ├── ai_chat_service.dart            # Abstract interface + factory
│   ├── edge_function_ai_chat_service.dart   # Release — proxies through Supabase Edge Function
│   ├── gemini_direct_ai_chat_service.dart   # Dev — calls Gemini directly
│   ├── gemini_service.dart             # Raw Gemini HTTP client, retry/backoff logic
│   ├── gemini_tools.dart               # Tool declarations: kGeminiTools (general chat), kItineraryTools (create_stop + clear_stops)
│   ├── ai_itinerary_service.dart       # Conversational AI service — AiItineraryService.chat() sends message + history to Gemini with no tools; returns AiTripChatResult (text + updatedHistory); system prompt includes trip name/dates/guests/stops
│   ├── push_notification_service.dart  # FCM token registration + permission handling
│   ├── trip_places_service.dart        # Google Places autocomplete + details (mobile + web)
│   ├── trip_places_web.dart            # Web impl via Google Maps JS SDK + dart:js_interop
│   ├── trip_places_stub.dart           # Stub for non-web builds
│   ├── activity_suggestions_service.dart # Viator Affiliate API product search + GYG/Klook affiliate deep-link builders; 10-min in-memory cache per destination
│   ├── directions_service.dart         # Google Maps Directions API; decodes encoded polyline
│   ├── cache_entry.dart                # Generic TTL cache wrapper
│   ├── local_cache.dart                # SharedPreferences JSON cache (offline read support)
│   ├── connectivity_service.dart       # Network state monitor (connectivity_plus)
│   └── offline_queue.dart              # Persistent write-ahead queue, replayed on reconnect
├── widgets/
│   ├── event_card.dart                 # Event summary card (type icon, title, date, location, member/going count, pending badge for trips)
│   ├── event_map_widget.dart           # flutter_map (Stadia Maps tiles) with start + numbered stop + destination markers + real road polyline; exports LatLng
│   ├── event_stop_form_sheet.dart      # Add / edit stop bottom sheet (trip-type events)
│   ├── ai_itinerary_sheet.dart         # AI chat bottom sheet (75% screen height): AiChatSession (messages + history) lifted to EventDetailScreen for persistence; _ChatBubble (MarkdownBody for AI, plain Text for user), _TypingBubble (animated 3-dot), _InputBar (pill TextField + send), _EmptyState
│   ├── add_member_sheet.dart           # Add member bottom sheet — friends quick-add chips + account lookup; calls EventProvider.addMember()
│   ├── places_autocomplete_field.dart  # Text field with Places suggestions dropdown
│   ├── destination_search_dialog.dart  # Full-screen Places search dialog
│   ├── wheel_math.dart                 # Pure logic for the poll spin wheel: WheelSegment, kWheelPalette, buildSegments (weight=max(votes,1)), pickWeightedIndex (seeded RNG), targetAngleForIndex, indexAtPointer
│   ├── poll_wheel_sheet.dart           # PollWheelSheet — "spin the wheel" decider for any poll; CustomPaint wheel (arcs ∝ votes) + fixed pointer, easeOutCubic 4.5s spin, haptic ratchet ticks, custom CustomPaint confetti burst, result card. Local-only (never mutates votes)
│   └── tournament/                     # Tournament-event Organize tabs + display helpers
│       ├── tournament_tabs.dart        # TournamentDivisionsTab, TournamentEntrantsTab, TournamentBracketTab, TournamentCourtsTab + add/register sheets
│       ├── tournament_bracket_view.dart # Division picker + generate-CTA + RR standings table / single-elim round columns / pool standings
│       ├── bracket_builder_screen.dart # Multi-division bracket builder (drag-and-drop entrant pool → division lanes → Generate All)
│       └── tournament_labels.dart      # Display-string extensions for tournament enums (hardcoded English, like signup tabs)
│   (tournament pure logic: lib/utils/bracket_math.dart — seeding/pairings/byes/wiring/playoff-from-pools; lib/utils/tournament_standings.dart — RR standings; lib/utils/scoring_rules.dart — game/match winner + best-of validation; lib/utils/court_logic.dart — court queue/double-booking)
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
/notifications           → NotificationsScreen
/event/invite/:code      → EventInviteScreen (public — no auth required)
/session/invite/:code    → SessionInviteScreen (public — no auth required; QR code deep-link for session signup)
```

`SessionScanScreen` is not a named route — it is pushed modally from the "Join" action button in `ShellScaffold`. It handles both session codes (shows inline join sheet + calls `rsvp_session` RPC) and event codes (navigates to `/event/invite/:code`).

**Live button:** The raised red center button in `ShellScaffold` lets users jump straight to whatever is live right now. Each tap advances through a cycling queue built by `buildLiveQueue` (`lib/models/live_queue_item.dart`) from two sources, sorted together by start time: **(1)** each currently-live signup **session** → opens the event's Activity tab with that session pre-selected, and **(2)** each ongoing **event that has no live session** → opens its **Info → Details** tab. When an event has live session(s), only the session(s) represent it (the whole-event entry is de-duped away). Live sessions come from `EventProvider.liveSessions`; `fetchLiveSessions()` populates it from the **union** of two RLS-scoped queries on `event_sessions` — (a) `is_active = true` (what the Activity tab shows) and (b) the live time window `start_at <= now AND (end_at IS NULL OR end_at > now)` (catches sessions the organizer hasn't activated yet) — merged/deduped by id. The **tap fetches this fresh before building the queue** (`_onLiveTap` awaits `fetchLiveSessions()` then navigates), so it never relies on a stale cache (e.g. after a hot reload where `load()` never re-seeded it). The Activity tab (`_SessionActivityTab`) also shows a Live-deep-linked session even when its `is_active` flag isn't set yet, so the jump always lands on the session. **The `/event/:id` route uses `pageBuilder` with a `ValueKey('event-$id-$initialTab-$initialSessionId')`** — without it, go_router reuses the existing `EventDetailScreen` page when navigating to the same `/event/:id` path with only a different query (e.g. tapping Live while the event is already open), so `initState` never re-runs and the tab never switches. The distinct key forces a fresh screen per deep-link target. Each session routes to `/event/:id?tab=session&sessionId=<id>`, which `EventDetailScreen` threads down to `_SessionActivityTab` (via `initialSessionId`) to pre-select that specific session in the activity view — so cycling through one event's live sessions opens each in turn. The button pulses + shows a count badge when anything is live, and is greyed (tap shows a "No live events right now" snackbar) when nothing is live.

**Auth guard:** Unauthenticated users are redirected to `/login`. Exception: `/event/invite/*` and `/session/invite/*` routes are public (accessible without auth). Logged-in users visiting `/login` or `/register` are redirected to `/events`. Guard is driven by `AuthProvider` as a `refreshListenable`.

---

## State Management

`ChangeNotifier` providers, injected via `MultiProvider` at the root:

| Provider | Owns | Key methods |
|---|---|---|
| `AuthProvider` | Auth session, current user | `init()`, `login()`, `register()`, `logout()`; `isLoggedIn`, `userId`, `userEmail`, `userName` |
| `EventProvider` | All events (organizer + guest) + nested stops/members | `load()`, `clear()`, `getById(id)`, `addEvent()`, `updateEvent()`, `deleteEvent()`, `updateChatBackground(eventId, key)`, `rsvp(eventId, status, {note})`, `addGuest(eventId, displayName, [email, phone, userId])`, `addMember(eventId, ...)` (trip-type invite flow with `ReinviteBlockedException`), `removeMember()`, `leaveEvent()`, `resendInvite(guestId)`, `addStop()`, `updateStop()`, `deleteStop()`, `reorderStops()`, `fetchPhotos(eventId)`, `addPhoto()`, `deletePhoto()`, `updatePhotoCaption(photoId, caption)`, `fetchExpenses(eventId)`, `addExpense()`, `settleSplit()`, `fetchBringList(eventId)`, `addBringItem()`, `deleteBringItem()`, `claimBringItem()`, `unclaimBringItem()`, `fetchPolls(eventId)`, `createPoll()`, `deletePoll()`, `vote()`, `changeVote()`, `reactToPollOption()`, `unreactToPollOption()`; **signup sessions:** `fetchUpcomingSessions(eventId)`, `fetchPastSessions(eventId)`, `loadMorePastSessions(eventId)`, `fetchSessionRoster(sessionId)`, `loadMoreRoster(sessionId)`, `refreshSessionRoster(sessionId)`, `addSession(eventId, startAt, endAt, {capacity, waitlistEnabled, signupLockHours, isPublic, requiresApproval})`, `cancelSessionSignup(rosterId, sessionId, eventId)`, `removeSessionRosterEntry()`, `promoteSessionRosterEntry()`, `demoteSessionRosterEntry()`, `reorderSessionRoster()`, `markSessionAttendance()`, `toggleSessionConfirmed()`, `approveSessionRosterEntry()`, `rejectSessionRosterEntry()`; session accessors: `upcomingSessionsFor(eventId)`, `pastSessionsFor(eventId)`, `rosterFor(sessionId)`, `myStatusFor(sessionId)`, `hasMoreUpcomingFor()`, `hasMorePastFor()`, `hasMoreRosterFor()`; computed `myEvents`, `invitedEvents`, `pendingInviteCount` (badge); getters `bringItemsFor(eventId)`, `pollsFor(eventId)`; static `applyOrder(events, order)`; Realtime via `event_sync_<userId>` channel |
| `EventChatProvider` | Event-scoped chat | `init()`, `sendMessage(content, {messageType})`, `sendGif(gifUrl)`, `loadMore()`; paginated (50/page); optimistic append with temp ID; after-send mention hook calls `send-mention-notification` Edge Function; single Realtime channel; scoped to `/event/:id` route |
| `InvitationsProvider` | Pending trip-event invitations for signed-in user | `init(userId)`, `clear()`, `accept()`, `decline(blockReinvite:)` |
| `NotificationsProvider` | In-app notification center | `init(userId)`, `clear()`, `reload()`, `markRead(id)`, `markAllRead()`, `deleteNotification(id)`; `unreadCount` (bell badge); Realtime Broadcast subscription on channel `trip_notifications_<userId>`; reads/writes `trip_notifications` only — never the shared `notifications` table |
| `FriendsProvider` | Friend list + pending requests | `init(userId)`, `clear()`, `sendRequest(addresseeId)`, `accept(id)`, `decline(id)`, `remove(id)`, `searchUsers(query)`; computed getters `accepted`, `incomingRequests`, `outgoingRequests`; two Realtime channels |
| `BlockedUsersProvider` | Global block list | `load()`, `clear()`, `blockUser(userId)`, `unblockUser(userId)`, `isBlocked(userId)`; optimistic unblock with revert on error; loaded on login, cleared on logout |
| `SubscriptionProvider` | Pro entitlement state | `load(userId)`, `clear()`, `purchaseMobile(packageId)`, `restore()`; computed `isPro`, `currentPeriodEnd`; web reads Supabase `user_subscriptions`; mobile reads RevenueCat entitlement `'pro'` |
| `SettingsProvider` | Theme mode + language preference | `load()`, `setThemeMode()`, `setLocale()` |
| `ConnectivityService` | Network state | `init()`, `isOnline` — notifies on change |
| `OfflineQueue` | Pending write operations | `init()`, `enqueue()`, `flush()`, `pendingCount`, `hasPending` |

Providers are pre-loaded on startup if the user is already logged in. `AuthProvider` notifies on auth state change, which triggers `EventProvider.load()` / `EventProvider.clear()`, `InvitationsProvider.init()` / `InvitationsProvider.clear()`, `FriendsProvider.init()` / `FriendsProvider.clear()`, `BlockedUsersProvider.load()` / `BlockedUsersProvider.clear()`, `NotificationsProvider.init()` / `NotificationsProvider.clear()`.

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

### Data scope quick-reference

For signup events specifically, data is split across two scopes:

| Scope | Tables | What lives here |
|---|---|---|
| **Event-level** | `events`, `event_guests`, `event_messages`, `event_photos`, `event_expenses`, `event_bring_list_items`, `event_polls` / `event_poll_options` / `event_poll_votes`, birthday tables | Identity, settings, capacity rules, member list, shared chat, shared photo album, shared expenses/polls/bring-list, birthday features |
| **Session-level** | `event_sessions`, `event_session_roster` | Individual occurrences (date/time, QR invite code, going_count, waitlist_count); per-session signup list with attendance and confirmation |

**Key rule:** Chat and photos are **event-scoped** — one shared thread and album for the whole recurring event, not one per session. Sessions only own their date, their QR code, and their attendance roster.

---

### Tables

#### `events`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `created_by` | uuid FK→auth.users | organizer |
| `title` | text | |
| `description` | text | default '' |
| `event_type` | event_type enum | `trip` \| `birthday` \| `wedding` \| `tournament` \| `quick_bites` \| `signup`; default `trip` |
| `location` | text | destination for trips; venue for others |
| `location_lat/lng` | float8 nullable | |
| `start_location` | text nullable | trip-only — departure point |
| `start_lat/lng` | float8 nullable | trip-only |
| `start_at` | timestamptz | required |
| `end_at` | timestamptz nullable | |
| `capacity` | integer nullable | null = unlimited |
| `invite_code` | uuid UNIQUE | auto-generated; used for public share link |
| `budget_per_head` | numeric(10,2) nullable | quick_bites-only — expected spend per person |
| `cuisine_tags` | text[] default '{}' | quick_bites-only — e.g. Japanese, Italian, BBQ |
| `rsvp_deadline` | timestamptz nullable | quick_bites-only — RSVP cutoff time |
| `vibe` | text nullable | quick_bites-only — preset mood label |
| `honoree_name` | text nullable | birthday-only — name of the person being celebrated |
| `birth_year` | integer nullable | birthday-only — used to compute age ("Turning 28") |
| `predictions_revealed_at` | timestamptz nullable | birthday-only — when organizer revealed predictions |
| `wishes_revealed_at` | timestamptz nullable | birthday-only — when organizer blew out the candles |
| `waitlist_enabled` | boolean default true | signup-only — whether to put overflow guests on a waitlist |
| `signup_lock_hours` | integer nullable | signup-only — hours before session `start_at` when signups/cancellations lock |
| `chat_background` | text nullable | preset key string for the chat background theme (e.g. `'gradient_rose'`, `'solid_dark'`); null = default |
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
| `rsvp_note` | text nullable | optional note shown to all members when RSVPing going/maybe |
| `is_archived` | bool default false | per-user "Move to Past" flag — when true this user has archived the event to their own Past tab (others unaffected) |
| `created_at` | timestamptz | |

**Constraints:** Partial UNIQUE INDEX on `(event_id, user_id) WHERE user_id IS NOT NULL`  
**REPLICA IDENTITY:** FULL (DELETE payloads include event_id for Realtime routing)

**Status values:** `going` | `maybe` | `declined` (non-trip); `pending` | `accepted` | `declined` | `left` (trip). Signup events do not use event_guests for per-session roster — see event_sessions / event_session_roster below.

**Status lifecycle (trip-type events):**
```
INSERT with status='pending'   ← new linked-user invite
  → accepted / declined        ← invitee action
  → left                       ← member voluntarily leaves (accepted → left)
  → pending again              ← re-invite via upsert
```

Unlinked guests (user_id IS NULL) and non-trip events: inserted directly as `going`.

#### `event_sessions` (signup events only)
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | CASCADE delete |
| `session_number` | integer | Monotonically increasing per event; UNIQUE(event_id, session_number) |
| `start_at` | timestamptz | Session date/time |
| `end_at` | timestamptz nullable | |
| `invite_code` | uuid UNIQUE | Per-session QR target; QR encodes `{kAppBaseUrl}/session/invite/{invite_code}` — **app-only**: joined by scanning with the in-app scanner (`SessionScanScreen`). A `session-signup` Edge Function serving a public HTML page also exists but is not currently linked from the QR. |
| `created_at` | timestamptz | |

**RLS:** Organizer full access; event members can SELECT.

#### `event_session_roster` (signup events only)
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `session_id` | uuid FK→event_sessions | CASCADE delete |
| `user_id` | uuid FK→auth.users nullable | Null for anonymous signups |
| `display_name` | text | |
| `email / phone` | text nullable | |
| `status` | text | `going` \| `waitlisted` \| `pending_review` (requires_approval sessions only) |
| `signup_order` | integer nullable | Monotonically increasing; organizer can reorder via batch UPDATE |
| `attended` | boolean nullable | null=not marked; true=attended; false=no-show; set after session ends |
| `signup_confirmed` | boolean default false | Pre-session confirmation; organizer or own user can toggle |
| `signed_up_at` | timestamptz | |

**RLS:** Organizer full access; each entry's own user can SELECT their row.

> Full reference: **`signup_queue.md`** — all queue logic: DB tables, RPCs, playing-status animations, free-pool computation, duplicate prevention, "Just Played! Back in Line" algorithm, drag-to-reorder, gesture model, spot-circle tap behaviour, Realtime coverage, and optimistic update pattern.

#### `session_queue_activities` (signup events only — in-session Queue Up activities)
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | CASCADE delete |
| `name` | text | e.g. "Court 1" |
| `players_per_round` | integer | How many players per active slot |
| `max_rounds` | integer nullable | null = no limit; queue auto-ends when `current_round > max_rounds` |
| `current_round` | integer default 0 | 0 = not started; 1+ = active |
| `status` | text | `waiting` \| `active` \| `ended` |
| `waiting_count` | integer | Denormalized; maintained by `trg_queue_entry_counts` trigger |
| `playing_count` | integer | Denormalized; maintained by `trg_queue_entry_counts` trigger |
| `created_by` | uuid FK→auth.users nullable | |
| `created_at` | timestamptz | |

**RLS:** Organizer full access; event members can SELECT.  
**REPLICA IDENTITY:** FULL; added to `supabase_realtime`.

#### `session_queue_entries` (players inside a specific queue)
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `activity_id` | uuid FK→session_queue_activities | CASCADE delete |
| `user_id` | uuid FK→auth.users nullable | |
| `display_name` | text | |
| `avatar_url` | text nullable | |
| `status` | text | `playing` \| `waiting` |
| `queue_position` | integer | 1-based; lower = earlier in waiting list |
| `rounds_played` | integer default 0 | |
| `joined_at` | timestamptz | |

**Constraint:** UNIQUE(activity_id, user_id).  
**RLS:** Organizer full access; event members can SELECT; members join/leave via RPCs.  
**REPLICA IDENTITY:** FULL; added to `supabase_realtime`.

#### `session_free_pool` (members checked in but not in any queue)
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | CASCADE delete |
| `user_id` | uuid FK→auth.users | NOT NULL |
| `display_name` | text | |
| `avatar_url` | text nullable | |
| `checked_in_at` | timestamptz | |

**Constraint:** UNIQUE(event_id, user_id).  
**RLS:** Organizer full access; event members can SELECT; own user manages own row.  
**REPLICA IDENTITY:** FULL; added to `supabase_realtime`.

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

#### `event_bring_list_items`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | CASCADE delete |
| `label` | text | item description e.g. "Wine", "Dessert" |
| `quantity` | int default 1 | |
| `claimed_by` | uuid FK→auth.users nullable | null = unclaimed |
| `claimed_at` | timestamptz nullable | |
| `created_by` | uuid FK→auth.users | organizer who added the item |
| `created_at` | timestamptz | |

**RLS:** members SELECT; organizer INSERT/DELETE; any member can UPDATE (`claimed_by`/`claimed_at`) when `claimed_by IS NULL` (claim) or when `claimed_by = auth.uid()` (unclaim).

#### `event_polls`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | CASCADE delete |
| `question` | text | |
| `created_by` | uuid FK→auth.users | organizer only |
| `created_at` | timestamptz | |

#### `event_poll_options`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `poll_id` | uuid FK→event_polls | CASCADE delete |
| `text` | text | option label |
| `sort_order` | int default 0 | |
| `place_metadata` | jsonb nullable | non-null for restaurant-vote options — stores Places API data (place_id, name, rating, price_level, cuisine, lat/lng) |

#### `event_poll_votes`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `poll_id` | uuid FK→event_polls | CASCADE delete |
| `option_id` | uuid FK→event_poll_options | CASCADE delete |
| `user_id` | uuid FK→auth.users | |
| `created_at` | timestamptz | |

**Constraint:** `UNIQUE (poll_id, user_id)` — one vote per user per poll. Changing vote = DELETE own vote + INSERT new.  
**RLS:** members SELECT all; members INSERT own vote; organizer INSERT polls/options; DELETE own vote.

#### `event_poll_reactions`
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `option_id` | uuid FK→event_poll_options | CASCADE delete |
| `user_id` | uuid FK→auth.users | |
| `emoji` | text | one of `['🔥','😂','👍','❤️','😬']` |
| `created_at` | timestamptz | |

**Constraint:** `UNIQUE (option_id, user_id, emoji)` — one of each emoji per user per option (Slack-style multi-react).  
**RLS:** members SELECT; members INSERT own; DELETE own.  
**Realtime:** REPLICA IDENTITY FULL — DELETE payloads carry option_id for cache resolution.  
**UX:** Long-press any poll option (custom or restaurant) to open an animated emoji picker. Emojis are shuffled on each open. Reactions appear as teal-tinted pills below the option with counts.

#### Birthday tables (migration `20260608000000_add_birthday_features.sql`)

**`event_wishlist_items`** — claimable gift list  
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `event_id` | uuid FK→events | CASCADE delete |
| `label` | text | gift name |
| `price_range` | text nullable | |
| `link` | text nullable | external product link |
| `created_by` | uuid FK→auth.users | |
| `claimed_by` | uuid FK→auth.users nullable | who claimed this gift |
| `claimed_by_name` | text nullable | display name of claimer |
| `claimed_at` | timestamptz nullable | |
| `is_received` | bool default false | organizer marks after party |

**RLS:** members SELECT/INSERT/UPDATE; creator or organizer DELETE. The claim detail (`claimed_by_name`) is visible to organizer and to the claimer; guests only see "someone's on it" in the UI.

**`event_gift_pools`** + **`event_gift_pledges`** — group gift coordination  
Pool: `id, event_id, gift_name, target_amount, created_by`. Organizer-only INSERT/DELETE.  
Pledge: `id, pool_id, pledged_by, pledged_by_name, amount, pledged_at`. Any member can insert/delete their own pledge.

**`event_predictions`** — sealed birthday predictions  
`id, event_id, submitted_by, submitted_by_name, prediction_text, created_at`. Visible to submitter + organizer at all times; visible to all members after `events.predictions_revealed_at IS NOT NULL`. Reveal triggered by organizer via `revealPredictions(eventId)`.

**`event_wishes`** — candle wish reveal  
`id, event_id, submitted_by, submitted_by_name, wish_text, created_at`. Same reveal mechanic via `events.wishes_revealed_at`; organizer triggers `revealWishes(eventId)`.

**`event_toasts`** — speech submissions  
`id, event_id, submitted_by, submitted_by_name, toast_text, toast_type ('sweet'|'funny'|'poem'), sort_order, created_at`. Organizer can reorder (`reorderToasts`). Members can INSERT/DELETE own; organizer can UPDATE all.

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
| `avatar_url` | text nullable | Shared / PropertyManagement avatar — do **not** write from TripManagement |
| `trip_avatar_url` | text nullable | TripManagement-specific avatar URL (includes `?v={ts}` cache-buster) |
| `job_title` | text nullable | |

**RLS:** users can only SELECT/UPDATE their own profile row (`user_id = auth.uid()`). Cross-user reads require the `get_trip_profile_names` SECURITY DEFINER function (TripManagement) or `get_profile_names` (PropertyManagement).

**Avatar separation rule:** Both apps share the same Supabase project and `avatars` storage bucket, so avatar paths are namespaced per app:
- PropertyManagement writes to `{userId}/avatar` → stored in `avatar_url`
- TripManagement writes to `trip/{userId}/avatar` → stored in `trip_avatar_url`

In TripManagement UI, always read `UserProfile.displayAvatarUrl` (returns `trip_avatar_url ?? avatar_url`), never `avatarUrl` directly. A `?v={timestamp}` query param is appended to bust Flutter's `NetworkImage` cache on re-upload.

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
| `content` | text | Plain text or GIF URL (when `message_type = 'gif'`) |
| `message_type` | text default `'text'` | `'text'` \| `'gif'` — controls rendering in `_MessageBubble` |
| `created_at` | timestamptz | |

**Index:** `(event_id, created_at DESC)` for paginated fetch  
**RLS:** SELECT and INSERT use `auth_user_is_event_member(event_id)`; no UPDATE or DELETE (messages are permanent).  
**Realtime:** `REPLICA IDENTITY FULL`; added to `supabase_realtime` publication.

`EventChatProvider` subscribes to one channel per event (`chat_<eventId>`, filter `event_id = eventId`) for INSERT events. Messages are paginated (50 per page, newest-first from DB, reversed in-memory to oldest→newest). Optimistic appends use a `temp_<timestamp>` placeholder ID.

**@mention token format:** Mentions are embedded inline as `@[userId:displayName]` tokens in the `content` field. `EventChatProvider.parseMentionedIds()` extracts user IDs; `EventChatProvider.plainPreview()` strips tokens to `@Name` for FCM previews. After the DB INSERT, `_sendMentionNotifications()` is called (fire-and-forget) to invoke the `send-mention-notification` Edge Function.

**GIF messages:** `content` holds the full-quality Giphy CDN URL (`images.original.url`). The Flutter client renders `CachedNetworkImage` in the bubble instead of text. Thumbnails (`images.fixed_width.url`) are shown in the `_GifPickerSheet` picker grid. Key: `kGiphyApiKey`. (Tenor API was considered but is shut down June 30, 2026.)

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

#### Tournament tables (tournament events only)

Migrations `20260622000200` (tables/RLS/triggers/realtime) + `20260622000300` (RPCs). A tournament Event owns **divisions** (draws), each with its own **entrants** (teams), **matches** (+ nested **games**), and the event-level **courts**. RLS mirrors `event_sessions`: organizer full access + members can SELECT via `auth_user_is_event_member`. Denormalized counts on `tournament_divisions` are maintained by O(1) delta triggers (`_update_division_entrant_count`, `_update_division_match_counts`); the resulting division UPDATE is the reliable Realtime signal. All five tables have `REPLICA IDENTITY FULL` and are in `supabase_realtime`.

- **`tournament_divisions`** — `id, event_id FK→events CASCADE, name, sport (free-form text), discipline ('singles'|'doubles'|'mixed'), skill_level (free-form text, e.g. "B"/"DUPR 3.5"/"Open"), format ('round_robin'|'single_elimination'|'pools_playoff'), scoring_config jsonb (fully editable: system/points_to_win/win_by_two/cap/best_of), team_size (1|2), entrant_cap?, pool_count?, advance_per_pool?, status ('setup'|'registration'|'seeded'|'in_progress'|'completed'), bracket_generated_at?, entrant_count, match_count, completed_match_count, bundle_id UUID?` (last three counts are denormalized; `bundle_id` groups divisions created together by the bracket builder). `UNIQUE(event_id, name)`. **`sport` and `skill_level` are free-form** (CHECK constraints dropped in migration `20260623000000`) so organizers can run any sport + rating scheme; only `discipline` (team size) and `format` (bracket algorithm) stay constrained because the engine depends on them.
- **`tournament_entrants`** — `id, division_id FK CASCADE, team_name, player1_user_id? FK→auth.users, player1_name, player2_user_id?, player2_name?, seed?, pool_id?, status ('registered'|'checked_in'|'withdrawn'), registered_at`.
- **`tournament_matches`** — `id, division_id FK CASCADE, bracket_type ('pool'|'winners'), round_number, match_number, pool_id?, entrant1_id?/entrant2_id?/winner_entrant_id? FK→entrants SET NULL, next_match_id? (self-FK, winner auto-advance), next_match_slot? (1|2), court_id? FK→courts SET NULL, status ('pending'|'scheduled'|'in_progress'|'completed'|'bye'|'walkover'), scheduled_order?`. Populated at bracket generation (M3).
- **`tournament_match_games`** — `id, match_id FK CASCADE, game_number, entrant1_score, entrant2_score, winner_entrant_id?`. `UNIQUE(match_id, game_number)`. Recorded at scoring (M4).
- **`tournament_courts`** — `id, event_id FK CASCADE, name, status ('available'|'in_use'|'closed'), current_match_id? FK→matches SET NULL, sort_order`.

Tournament RPCs (all `SECURITY DEFINER`, organizer-checked unless noted): `create_tournament_division`, `update_tournament_division`, `delete_tournament_division`, `register_tournament_entrant` (any event member), `withdraw_tournament_entrant` (organizer or linked player — soft, sets `withdrawn`), `remove_tournament_entrant` (organizer hard delete), `add_tournament_court`, `update_tournament_court`, `delete_tournament_court`, and `generate_division_bracket(p_division_id, p_plan jsonb, p_seeds jsonb)` (migration `20260622000400`). `create_event` is unchanged for tournaments (divisions are configured after creation, like signup sessions).

**Bracket generation:** Dart computes the full plan (seeding, pairings, byes pre-advanced, next-match wiring via local indices) in `lib/utils/bracket_math.dart` — `nextPowerOfTwo`, `seedOrder` (canonical single-elim seeding), `buildSingleElimination`, `buildRoundRobin` (circle method), `distributeIntoPools` (snake), `buildPoolsStage`, `buildPlayoffFromPools` (cross-pool seeded playoff once pools finish), `poolsComplete`, `buildBracketPlan` (dispatch by format). `generate_division_bracket` then inserts the plan transactionally (two-pass: insert matches → wire `next_match_id`/slot from an idx→uuid map), persists seeds, and sets `bracket_generated_at` + status `in_progress`. Round-robin/pool standings are computed client-side in `lib/utils/tournament_standings.dart` (`computeStandings`: wins → head-to-head → game diff → point diff; optional `poolId` filter) — no standings table. `EventProvider.generateBracket(division)` orchestrates.

**Scoring & auto-advance (M4):** `record_match_score(p_match_id, p_games jsonb)` (migration `20260622000500`) derives the per-game winner (higher score) and match winner (more games) server-side, marks the match `completed`, **auto-advances** the winner into `next_match`'s slot (promoting that match to `scheduled` once both slots fill), and frees the court. Re-recording is blocked once the downstream match is completed. `lib/utils/scoring_rules.dart` (`ScoringRules.gameWinner`/`matchWinner`/`gameTally`) drives the score-sheet UI's live validation (win-by-2, cap, best-of). For pools→playoff, only pool matches are generated up front; once all pool matches complete, the organizer taps **Generate Playoffs** → `seed_division_playoffs(p_division_id, p_plan jsonb)` (migration `20260622000600`) inserts the cross-pool-seeded single-elim playoff. Provider: `recordMatchScore`, `seedPlayoffs`.

**Customization — rosters, team ties, manual builder, templates (M6–M9):** Beyond the built-in formats, organizers can define their own structures.
- **Team rosters** (`entrant_kind` = individual|team, `roster_size`): team entrants have a ranked roster in `tournament_entrant_players` (migration `20260623000100`); `register_tournament_team(p_division_id, p_team_name, p_players jsonb)` (`20260623000200`).
- **Team ties** (`tournament_matches.is_tie`, division `tie_config` jsonb = submatch_count/pairing_rule/win_threshold): a tie's sub-matches live in `tournament_tie_submatches` (`20260623000500`). `_ensure_tie_submatches(tie_id)` builds them once both teams are known — `same_rank` joins rosters by position, `manual` leaves slots for `set_submatch_player`. `record_submatch_score(p_submatch_id, p_games jsonb)` derives the sub-match winner, recomputes the tie vs `win_threshold`, completes the parent tie, and **auto-advances** the tie winner (building the next tie's sub-matches) (`20260623000600`). `generate_division_bracket` marks team-division matches `is_tie` and seeds round-1 sub-matches. Dart: `pairSubmatches` (bracket_math), `tieWinner` (scoring_rules).
- **Manual builder** (`format` = `custom`): no auto-generation — `add_tournament_match` / `update_tournament_match` / `delete_tournament_match` (`20260623000700`) let the organizer hand-build rounds/matches/ties; UI `_ManualBuilder` in `tournament_bracket_view.dart`.
- **Rule templates**: `tournament_templates` (per-user, owner-only) + `save_tournament_template` / `delete_tournament_template` (`20260623000800`); the Add-Division form offers built-in presets + saved templates ("start from template") and "save as template". Model `TournamentTemplate`; provider `fetchTemplates`/`saveTemplate`/`deleteTemplate`.
- Free-form `sport`/`skill_level` (CHECK dropped, `20260623000000`). New realtime tables: `tournament_entrant_players`, `tournament_tie_submatches`. Provider gains `registerTeam`, `recordSubmatchScore`, `setSubmatchPlayer`, manual `addManualMatch`/`updateManualMatch`/`deleteManualMatch`, and template methods.

**Court assignment (M5):** `assign_match_to_court(p_match_id, p_court_id)`, `unassign_match_from_court(p_match_id)`, `reorder_court_queue(p_court_id, p_match_ids uuid[])` (migration `20260622000700`). A match assigned to a court gets `court_id` + `scheduled_order` (its queue position); the lowest-order non-completed match on a court is "on court now", the rest "next up". `record_match_score` frees the court on completion. Pure scheduling logic is in `lib/utils/court_logic.dart` (`courtQueue`, `doubleBookedEntrants`, `unassignedReady`); the Courts tab shows per-court queues + a double-booking warning banner, and bracket match cards have an "Assign court" action. Provider: `assignMatchToCourt`, `unassignMatchFromCourt`, `reorderCourtQueue`, `fetchAllMatchesForEvent`, `assignedMatchesForCourt`, `doubleBookedEntrantIds`.

Model: `lib/models/tournament.dart`; UI: `lib/widgets/tournament/` (Organize tabs Divisions / Teams / Bracket / Courts; `tournament_bracket_view.dart` renders the generate-CTA, RR standings table, the single-elim **bracket tree**, pool standings, tie sheet, and manual builder); provider methods + Realtime handlers live in `EventProvider`. Tournament events also get a **Guide** sub-tab in the Info tab group (`_TournamentGuideTab` in `event_detail_screen.dart`, mirroring `_SignupGuideTab`).

- **Bracket tree** (`_EliminationTree` + `_TreeMatchCard` + `_BracketLinesPainter`): matches are absolutely positioned so each round's match is centred between its two feeders (geometry in `bracketCenterSlots`, `bracket_math.dart`); elbow connector lines via a `CustomPainter`; compact fixed-height boxes (winner bolded, court accent bar); **two-axis scroll** (horizontal → later rounds, vertical → tall first round). Tap a ready match → score/tie sheet; long-press → court actions.
- **Member picker**: the player fields in the add-team / roster forms have a searchable member picker (`_MemberPickerSheet`/`_PlayerNameField`) that fills the name and links the chosen member's `user_id` (feeds cross-division double-booking). Free-form typing is still allowed.
- **First-run hint** (`_DivisionsFirstRunHint`): empty Divisions tab shows two setup paths — "Build Structure" (opens the multi-division builder) and "Add Single Division" (the existing one-at-a-time form). When divisions already exist, a small FAB (tree icon) opens the builder alongside the "Add Division" extended FAB.
- **Multi-division bracket builder** (`BracketBuilderScreen`, `lib/widgets/tournament/bracket_builder_screen.dart`): drag-and-drop screen that creates multiple linked divisions in one shot. Organizer adds entrant names to a pool, creates division lanes (each with its own name + format/template), drags entrant chips from pool → lanes, then taps "Generate All". Provider `createDivisionBundle()` iterates over segments: `createDivision` → `registerEntrant` per entrant → `generateBracket` (skipped for `custom` format). Layout: wide (≥700 px) = pool panel on left (240 px) + horizontally-scrollable lane cards; narrow (phone) = vertical scroll with shared-config card + pool card + lane cards. Two interaction modes: long-press drag (`LongPressDraggable`/`DragTarget`) and tap-to-select + tap-lane-to-assign. Template picker per lane reuses the same built-in preset list as the Add-Division form. Builder-only models: `BracketSegmentConfig` (one lane's config) + `DraftEntrant` (a pool entrant not yet in Supabase).
- **Built-in templates**: 9 starter presets in the Add-Division "Start from template" picker (badminton/pickleball × singles/doubles/mixed × knockout/round-robin/pools, + two team-tie starters), alongside user-saved templates.
- **One entry per player per division** (migration `20260623001000`): `register_tournament_entrant`/`register_tournament_team` reject a player already in an active entrant of the same division, and a player partnering themselves — matched by linked `user_id` AND case-insensitive name. The same player may still enter *other* divisions.

**RLS helper:** `auth_user_is_event_member(p_event_id uuid)` — `SECURITY DEFINER` function; returns true if caller is event creator OR has a guest row with `status IN ('going','maybe','accepted','pending')` for that event. `declined`/`left` do not grant access.

**Authenticated RPCs (`authenticated` role only):**
- `create_event(p_title, p_description, p_location, p_start_at, [p_location_lat, p_location_lng, p_end_at, p_capacity, p_event_type, p_start_location, p_start_lat, p_start_lng, p_budget_per_head, p_cuisine_tags, p_rsvp_deadline, p_vibe, p_honoree_name, p_birth_year, p_waitlist_enabled, p_signup_lock_hours])` — `SECURITY DEFINER`; inserts an event row with `created_by = auth.uid()`; auto-creates `event_sessions` session #1 when `event_type = 'signup'`.
- `add_event_session(p_event_id, p_start_at, p_end_at)` — organizer creates a new session occurrence; increments session_number; returns the new session row.
- `rsvp_session(p_invite_code, p_display_name, p_email, p_phone)` — atomic signup for a specific session via its invite_code; locks parent event for capacity check; assigns sequential signup_order; returns (roster_id, signup_position, rsvp_status, confirmed_count, waitlist_count, session_capacity). Grantee: anon + authenticated.
- `cancel_session_signup(p_roster_id)` — guest self-cancels from a session; enforces signup_lock_hours; auto-promotes first waitlisted guest.
- `session_remove_roster_entry(p_roster_id)` — organizer removes a roster entry; auto-promotes waitlist.
- `session_promote_roster_entry(p_roster_id)` — organizer promotes a waitlisted entry to going; raises session_full if no capacity.
- `session_demote_roster_entry(p_roster_id)` — organizer demotes a confirmed entry to end of waitlist.
- `session_mark_attendance(p_roster_id, p_attended)` — organizer marks attended/no-show; only callable after session end_at.
- `toggle_session_confirmed(p_roster_id, p_confirmed)` — toggles signup_confirmed on a session roster entry; organizer or the entry's own user.
- `get_session_by_invite_code(p_invite_code)` — public read (anon + authenticated); returns session + parent event info + going/waitlist counts + organizer name + capacity settings, including `requires_approval` (consumed by the QR-scan join sheet and public session-invite page to show "Request to join"). Keep this column list in sync with those callers — see `bugs.md` H.
- `resend_event_invite(p_guest_id uuid)` — resets `status = 'pending'` for a guest row; triggers `on_invite_inserted` for re-notification.
- `get_profile_names(p_user_ids uuid[])` — returns `(user_id, full_name, email, phone, avatar_url)` for a list of user IDs, bypassing `user_profiles` RLS. Used by PropertyManagement. **Do not call from TripManagement** — use `get_trip_profile_names` instead.
- `get_trip_profile_names(p_user_ids uuid[])` — TripManagement variant of `get_profile_names`. Returns `COALESCE(trip_avatar_url, avatar_url) as avatar_url`, so callers automatically get the app-specific photo with fallback to the shared photo. Called by `EventProvider._enrichGuestNames()`, `FriendsProvider._enrichNames()`, `BlockedUsersProvider.load()`, and `EventChatProvider`.
- `search_users(p_query text)` — returns `(user_id, full_name, email)` for users matching the query by name, email, or phone, excluding the caller and existing friends. Limit 20.
- `find_users_by_contacts(p_phones text[], p_emails text[])` — batch-lookup used by `ContactsScreen`. Excludes caller, blocked users (either direction), and existing friends.

**Public RPCs (`anon` + `authenticated` access):**
- `get_event_by_invite_code(p_invite_code uuid)` — returns event info + RSVP counts (going/maybe/declined) + organizer name + `waitlist_enabled` + `signup_lock_hours` + `event_type` text; used by `EventInviteScreen` without auth.
- `get_session_by_invite_code(p_invite_code uuid)` — returns session + parent event info + going/waitlist counts; used by `SessionInviteScreen` without auth.
- `rsvp_event_public(p_invite_code, p_display_name, p_email, p_phone, p_rsvp_status)` — inserts an anonymous `event_guests` row (user_id = null); enforces capacity limit; returns event summary.

**Storage:** `event-photos` bucket (public read); path = `{event_id}/{filename}`.

**Realtime publication:** `events`, `event_guests`, `event_messages`, `event_photos`, `event_expenses`, `event_stops`, `event_bring_list_items`, `event_sessions`, `event_session_roster`, `tournament_divisions`, `tournament_entrants`, `tournament_matches`, `tournament_match_games`, `tournament_courts`, and `trip_notifications` all added to `supabase_realtime`. `EventProvider` channel: `event_sync_<userId>`. `NotificationsProvider` channel: `trip_notifications_<userId>` (Realtime Broadcast — the `broadcast_trip_notification` DB trigger posts to this channel after INSERT/UPDATE on `trip_notifications`). Note: the shared `notifications` table is PropertyManagement's — TripManagement must never subscribe to or query it.

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

#### `event_bring_list_items`
| Policy | Operation | Rule |
|---|---|---|
| `bring_select` | SELECT | `auth_user_is_event_member(event_id)` |
| `bring_organiser_insert` | INSERT | organizer (`events.created_by = auth.uid()`) |
| `bring_organiser_delete` | DELETE | organizer |
| `bring_member_claim` | UPDATE | `claimed_by IS NULL` (claim) OR `claimed_by = auth.uid()` (unclaim) |

#### `event_polls`, `event_poll_options`, `event_poll_votes`
All SELECT gated by `auth_user_is_event_member(event_id)` (via join to `event_polls`).  
INSERT polls/options: organizer only.  
INSERT votes: `user_id = auth.uid() AND auth_user_is_event_member(event_id)`.  
DELETE votes: `user_id = auth.uid()` (own vote only).

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

### Cross-app notification isolation (hard rule — do not break)

TripManagement and PropertyManagement share the same Supabase project. The `notifications` table is owned by PropertyManagement. TripManagement owns `trip_notifications`. These tables must remain completely separate.

**The rule, in full:**

| What | TripManagement | PropertyManagement |
|---|---|---|
| Write notifications to | `trip_notifications` via `insert_trip_notification()` | `notifications` via `insert_notification()` |
| Read notifications from | `trip_notifications` only | `notifications` only |
| Realtime channel | `trip_notifications_<userId>` | `notifications_<userId>` |
| Dart query | `.from('trip_notifications')` | `.from('notifications')` |

**Why this matters:** PM reads its table without a type filter. If TM ever writes to `notifications`, every TM notification (session join requests, kicks, friend requests…) immediately appears in the PM notification centre. This is silent — no error is thrown, no alarm fires.

**Regression guard:** `test/regression/notification_isolation_test.dart` enforces this at three levels:
1. **Source scanner** — fails if any file in `lib/` contains `.from('notifications')`.
2. **Migration guard** — fails if the isolation migration is missing or reverted.
3. **Type classification** — fails if any notification type is unclassified or appears in both lists.

**Adding a new notification type:**
1. Add the type to `NotificationsProvider.tripTypes`.
2. Add it to `allKnownTypes` in `test/regression/notification_isolation_test.dart`.
3. Add a DB trigger function that calls `insert_trip_notification()` (never `insert_notification()`).
4. Add migration, run `supabase db push`.

---

### DB Triggers

| Trigger | Table | Event | Function | Effect |
|---|---|---|---|---|
| `on_event_guest_invite` | `event_guests` | AFTER INSERT OR UPDATE | `handle_new_event_invite()` | Writes `event_invite` in-app notification + calls `send-invite-notification` Edge Function when `status = 'pending'` AND `user_id IS NOT NULL`. |
| `on_invite_response` | `event_guests` | AFTER UPDATE | `notify_invite_response()` | Writes `event_invite_accepted` or `event_invite_declined` notification to organizer and calls `send-push-notification`. |
| `on_member_kicked` | `event_guests` | AFTER DELETE | `notify_member_kicked()` | Writes `event_kicked` notification to the deleted user and calls `send-push-notification`. |
| `on_guest_reinvite_check` | `event_guests` | BEFORE UPDATE | `prevent_blocked_reinvite()` | Raises exception `blocked_reinvite` if `old.block_reinvite = true` and `new.status = 'pending'`. |
| `on_waitlist_promoted` | `event_session_roster` | AFTER UPDATE | `handle_waitlist_promotion()` | Writes `session_promoted` in-app notification + calls `send-waitlist-promoted-notification` Edge Function on `waitlisted → going`. |
| `on_session_join_request` | `event_session_roster` | AFTER INSERT | `notify_session_join_request()` | Writes `session_join_request` notification to organizer when `status = 'pending_review'`. |
| `on_session_decision` | `event_session_roster` | AFTER UPDATE | `notify_session_decision()` | Writes `session_approved` or `session_rejected` notification to user on `pending_review → going/rejected`. |
| `on_session_demoted` | `event_session_roster` | AFTER UPDATE | `notify_session_demoted()` | Writes `session_demoted` notification to user on `going → waitlisted`. |
| `on_friend_request` | `friendships` | AFTER INSERT | `notify_friend_request()` | Writes `friend_request` notification to addressee and calls `send-push-notification`. |
| `on_friend_accepted` | `friendships` | AFTER UPDATE | `notify_friend_accepted()` | Writes `friend_accepted` notification to requester on `pending → accepted`. |
| `on_new_user` | `auth.users` | AFTER INSERT | `handle_new_user()` | Auto-creates `user_profiles` row on sign-up. |

**TripManagement helpers:** `insert_trip_notification(user_id, type, title, body, reference_id, metadata)` — SECURITY DEFINER, bypasses RLS to write a row into `trip_notifications` for any user. All 10 TM trigger functions call this. `call_push_edge_function(user_id, type, title, body, data)` — calls `send-push-notification` via pg_net.

**PropertyManagement helper (do not call from TM):** `insert_notification(…)` — writes to the shared `notifications` table. TripManagement trigger functions must NEVER call this function.

---

### Edge Functions

#### `send-invite-notification`
Called by the `on_event_guest_invite` trigger. Reads FCM tokens from `device_tokens`, exchanges the service-account JSON for an OAuth2 access token, and sends an FCM v1 API push notification. Stale/unregistered tokens are deleted automatically.

#### `send-waitlist-promoted-notification`
Called by the `on_waitlist_promoted` trigger. Sends FCM push when a roster entry is promoted from waitlist to confirmed.

#### `send-push-notification`
Generic push notification function — called by `call_push_edge_function()` helper for all new notification types. Accepts `{ user_id, type, title, body, data }`, sends FCM to all device tokens for the user.

#### `send-mention-notification`
Client-initiated (called directly from Flutter after a message with `@[userId:…]` tokens is sent). Validates mentioned users are active event members; respects `user_profiles.mention_notifications_enabled` opt-out; writes in-app `trip_notifications` rows (type `chat_mention`, `reference_id = event_id`); sends FCM push to each opted-in user's devices. Uses `event_guests` and `events` tables (updated from legacy `trip_members`/`trips` naming). Accepts `event_id` or legacy `trip_id` in the request body.

#### `places-proxy`
Server-side proxy for Google Places (New) REST + Geocoding so the Google API key never ships in the app for those calls. Holds the `GOOGLE_PLACES_API_KEY` secret; deployed with `--no-verify-jwt` so the `photo` action loads in `Image.network`/web `<img>`. Actions via `?action=`: `searchText`, `autocomplete`, `placeDetails`, `restaurantDetails`, `geocode`, `photo`. The `photo` action streams image bytes (never a keyed redirect URL). Called from `TripPlacesService` (native REST + `placesPhotoUrl`) and the Cravings geocode helpers in `event_detail_screen.dart`. Deploy: `supabase functions deploy places-proxy --no-verify-jwt`. See `api.md → Google Places API (New)`. The Directions API and the web Maps JS SDK remain the only client-side uses of `kGooglePlacesApiKey`.

**Secrets required (all functions):**
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

### Leaving an event

Available from the AppBar button in Event Detail for **all non-organizer members who are not already `left`** (applies to every event type — trip, birthday, wedding, tournament, quickBites). A confirmation dialog includes the same **"Don't allow future invitations"** checkbox:
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

`EventProvider._subscribeRealtime()` uses a single channel (`event_sync_<userId>`) and handles events across 10 tables:

| Table | Event | Handler | Notes |
|---|---|---|---|
| `events` | UPDATE | Reconstructs `Event` from payload scalars, preserves in-memory `guests` + `stops` | |
| `event_guests` | INSERT | `EventGuest.fromJson(row)` → append with dedup guard | |
| `event_guests` | UPDATE | `EventGuest.fromJson(row)` → full row replace | Covers accept/decline/leave/name changes |
| `event_guests` | DELETE | Remove by id | Requires `REPLICA IDENTITY FULL` for `event_id` in payload |
| `event_stops` | INSERT | `EventStop.fromJson(row)` → append + re-sort, dedup guard | |
| `event_stops` | UPDATE | `EventStop.fromJson(row)` → replace in-place + re-sort | |
| `event_stops` | DELETE | Remove by id | Requires `REPLICA IDENTITY FULL` on `event_stops` |
| `event_photos` | INSERT | `fetchPhotos(eventId)` | |
| `event_photos` | DELETE | In-memory remove by id + `notifyListeners()` | Requires `REPLICA IDENTITY FULL` |
| `event_expenses` | INSERT / UPDATE / DELETE | `fetchExpenses(eventId)` | `REPLICA IDENTITY FULL` on expenses; DELETE handler falls back to refreshing all loaded events if eventId missing |
| `event_bring_list_items` | INSERT / UPDATE / DELETE | `fetchBringList(eventId)` | Requires `REPLICA IDENTITY FULL`; migration `20260605060000_bringlist_realtime.sql` adds table to publication |
| `event_polls` (via option/vote tables) | INSERT / DELETE | `_resolveEventIdForPoll(pollId)` DB fallback → `fetchPolls(eventId)` | Handles cache-cold race via DB fallback |
| `event_poll_reactions` | INSERT / DELETE | `_resolveEventIdForOption(optionId)` DB fallback → `fetchPolls(eventId)` | Reactions with REPLICA IDENTITY FULL carry option_id in DELETE |
| `event_sessions` | INSERT | `fetchUpcomingSessions(eventId)` + `fetchPastSessions(eventId)` | New session added by organizer on another device |
| `event_sessions` | UPDATE | `_patchSessionInCache` with new `going_count` / `waitlist_count` | Fired by DB trigger after every roster change; keeps session card counts live |
| `event_session_roster` | INSERT | `refreshSessionRoster(sessionId)` — only if session already in cache | New signup (QR scan or invite code entry) |
| `event_session_roster` | UPDATE | `_patchRosterEntry` with new `status` / `signup_order` / `attended` / `signup_confirmed` | Covers promote, demote, attendance, confirmation |
| `event_session_roster` | DELETE | In-memory remove by id | Cancel or organizer removal; requires `REPLICA IDENTITY FULL` (migration `20260610000001`) |
| `session_queue_activities` | UPDATE | In-memory patch `_sessionQueues[eventId]` | Denormalized count change after entry INSERT/DELETE |
| `session_queue_activities` | DELETE | Remove from cache + clear `_queueEntries[id]` | Organizer deletes queue |
| `session_queue_entries` | INSERT / UPDATE / DELETE | In-memory patch `_queueEntries[activityId]`, sorted by `queue_position` | Live queue position updates for all members |
| `session_free_pool` | INSERT / DELETE | In-memory patch `_freePool[eventId]` | Check-in / check-out updates |

`InvitationsProvider` subscribes separately (INSERT + UPDATE on `event_guests` filtered by `user_id = currentUser` and `status = 'pending'`) to keep the invite badge current for the invited user's own device.

---

## Push Notifications

`PushNotificationService.init()` is called on every login:
1. Calls `requestPermission()`. If denied → returns early; no token is registered, no DB entry created.
2. Gets the FCM token and upserts it into `device_tokens`.
3. Listens for token refresh → upserts new token.
4. Handles cold-start / background notification taps → routes by type.

**Notification types and routing:**
| Type | Navigates to |
|---|---|
| `trip_invite`, `event_invite` | `/events` |
| `chat_mention` | `/event/:eventId` (the event where the mention occurred; `reference_id` = eventId) |
| `event_invite_accepted`, `event_invite_declined` | `/event/:eventId` |
| `event_kicked` | `/events` (user no longer has access) |
| `session_join_request`, `session_approved`, `session_rejected`, `session_demoted`, `session_promoted` | `/event/:eventId` |
| `friend_request`, `friend_accepted` | `/friends` |

If the user has not granted notification permission, the in-app notification center (driven by `NotificationsProvider`) is the primary delivery path — the app works fully without push permission.

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
- `kGooglePlacesApiKey` — now used client-side **only** for the Directions API (mobile) and the web Maps JS SDK; Places REST + photos are proxied via `places-proxy`. Required Google Cloud APIs: Places API (New), Directions API, Geocoding API (for the proxy `geocode` action), Maps JavaScript API (web). The Maps SDK itself is no longer a dependency.

---

## AI Chat Service

The AI layer mirrors PropertyManagement's design — provider-agnostic, build-mode-selected:

| Build mode | Implementation | Where the key lives |
|---|---|---|
| Release | `EdgeFunctionAIChatService` | Supabase secret `GEMINI_API_KEY` |
| Debug | `GeminiDirectAIChatService` | `kGeminiApiKey` in `api_keys.dart` |

Override in debug: `--dart-define=FORCE_EDGE_FUNCTION=true`

Tool declarations live in `lib/services/gemini_tools.dart`:
- `kGeminiTools` — general chat tools (empty by default)

The optional `tools` parameter on `AIChatService.send()` lets callers override the tool set per request. `AiItineraryService` passes `tools: const []` (purely conversational — no tool-calling). The AI trip planner entry point is the `auto_awesome_outlined` AppBar button on `EventDetailScreen` (trip events only). Chat state (`AiChatSession` with messages + history) is lifted to `_EventDetailScreenState` so it persists across sheet close/reopen. Users must be organizer OR Pro to open the sheet (organizers always free).

---

## Places Search

`TripPlacesService` provides address autocomplete, lat/lng lookup, restaurant search (Cravings) and restaurant photos.

- **Server-side key:** all native REST calls and all restaurant photos route through the `places-proxy` Edge Function (holds `GOOGLE_PLACES_API_KEY`). The Google key is no longer used client-side for these. See `api.md → Google Places API (New)` for the action table.
- **Mobile** (iOS/Android): REST calls to `places-proxy?action={autocomplete,placeDetails,searchText,restaurantDetails,geocode}` via `http` package.
- **Web**: address autocomplete/details load the Google Maps JS SDK and call `google.maps.importLibrary('places')` — implemented in `trip_places_web.dart` using `dart:js_interop` (conditional export via `if (dart.library.js_interop)`), using the referrer-restricted web key. Restaurant search + photos use `places-proxy`.
- **Photos:** `placesPhotoUrl(photoRef, maxWidth:)` builds a `places-proxy?action=photo` URL; the proxy streams the image bytes so the key is never exposed. Used by Cravings poll cards and the restaurant detail sheet.
- **Caching:** Suggestions are cached in-memory with a 1-hour TTL (`CacheEntry`). Place details are cached indefinitely per session. Photos carry a 1-day `Cache-Control` from the proxy.

---

## Subscription & Monetisation

TripManagement uses a **freemium + Pro** model. Subscriptions are per-app — a TripManagement Pro subscription never grants access to PropertyManagement Pro, even though the apps share the same Supabase project.

### Platform split

| Platform | Purchase processor | Source of truth |
|---|---|---|
| iOS | RevenueCat (App Store) | RevenueCat entitlement → webhook → `user_subscriptions` |
| Android | RevenueCat (Google Play) | RevenueCat entitlement → webhook → `user_subscriptions` |
| Web | Stripe Checkout | Stripe webhook → `user_subscriptions` |

### `user_subscriptions` table

Stores one row per active or historical subscription, keyed by `stripe_subscription_id` (web) or `revenuecat_original_app_user_id` (mobile). The `app` column (`trip_management` | `property_management`) ensures complete isolation between apps.

**isPro check:** any row where `user_id = auth.uid() AND app = 'trip_management' AND status IN ('active', 'trialing') AND current_period_end > now()`.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid FK→auth.users CASCADE | |
| `app` | text | `trip_management` \| `property_management` |
| `platform` | text | `ios` \| `android` \| `web` |
| `stripe_customer_id` | text nullable | web only |
| `stripe_subscription_id` | text UNIQUE nullable | web only; used for upsert |
| `stripe_price_id` | text nullable | web only |
| `revenuecat_original_app_user_id` | text nullable | mobile only (future) |
| `status` | text | `active` \| `trialing` \| `past_due` \| `canceled` \| `unpaid` \| `paused` |
| `current_period_end` | timestamptz nullable | |
| `trial_end` | timestamptz nullable | |
| `created_at / updated_at` | timestamptz | |

**RLS:** users can SELECT their own rows; only service role (Edge Functions) can INSERT/UPDATE.

### Web Stripe flow

```
Flutter web → stripe-create-checkout Edge Function → Stripe Checkout Session
  → browser redirect to Stripe-hosted page
  → payment completed
  → Stripe redirects to /events?stripe_success=true
  → stripe-webhook Edge Function fires (checkout.session.completed)
  → upserts user_subscriptions row
  → SubscriptionProvider refreshes on next app foreground
```

`StripeService` (`lib/services/stripe_service.dart`) — web-only; calls `stripe-create-checkout` and opens the returned URL via `url_launcher`. The Stripe secret key lives in Supabase secrets (`STRIPE_SECRET_KEY`) — never in the app bundle. Price IDs (`kStripePriceIdMonthly`, `kStripePriceIdAnnual`) are safe for the client and live in `api_keys.dart`.

### Edge Functions

#### `stripe-create-checkout`
Authenticated (Supabase JWT). Receives `{ price_id, success_url, cancel_url, app }`, creates a Stripe Checkout Session with `mode: subscription`, a 14-day trial, and `metadata: { user_id, app }` on the subscription, and returns `{ url }`.

**Secrets required:**
```
supabase secrets set STRIPE_SECRET_KEY='sk_live_...'
```

#### `stripe-webhook`
Public endpoint called by Stripe. Verifies `Stripe-Signature` header (HMAC-SHA256). Handles:
- `checkout.session.completed` — upserts subscription row, grants immediate access
- `customer.subscription.updated` — keeps status / period_end in sync (renewals, pauses, plan changes)
- `customer.subscription.deleted` — marks row `status = 'canceled'`

**Secrets required:**
```
supabase secrets set STRIPE_SECRET_KEY='sk_live_...'
supabase secrets set STRIPE_WEBHOOK_SECRET='whsec_...'
supabase secrets set SUPABASE_SERVICE_ROLE_KEY='<key>'
```

Register in Stripe Dashboard → Developers → Webhooks → Add endpoint:
- URL: `https://qgeocaectbdfonrorwco.supabase.co/functions/v1/stripe-webhook`
- Events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`

### iOS / Android RevenueCat

`purchases_flutter: ^10.2.2` is in `pubspec.yaml`. API keys (`kRevenueCatAppleApiKey`, `kRevenueCatGoogleApiKey`) live in `api_keys.dart`. `MainActivity` extends `FlutterFragmentActivity` (required by RevenueCat). In-App Purchase capability must be enabled in Xcode.

**RevenueCat webhook** (future): will POST to a `revenuecat-webhook` Edge Function and upsert `user_subscriptions` with `platform = 'ios'|'android'`.

### Freemium gates

| Gate | Free limit | Where enforced |
|---|---|---|
| Event creation | 3 organiser-owned events | `EventsScreen._onFabTap()` |
| Guest count | 10 guests per event | `_GuestsTabState._showAddGuest()` |
| Expense export | Pro only | `_ExpensesTabState._showExportOptions()` |

All gates push to `/paywall`. `PaywallScreen` (`lib/screens/subscription/paywall_screen.dart`) has a dark navy gradient hero (glow orbs, gold PRO badge, "Upgrade to Pro" title), animated billing toggle (Annual/Monthly with gradient pill slider), feature cards with colored icons, Basic vs Pro comparison table, gradient CTA button, and mobile-only "Restore purchases" link.

The `ProfileScreen` header shows a `_TierBadge` below the user's name/email: free users see a two-part pill (shield "Free" | amber gradient "Upgrade →") that navigates to `/paywall`; Pro users see a `workspace_premium_rounded` badge in `AppTheme.accent`.

---

## Responsive Layout (Big-screen / Desktop / Web)

Breakpoint: **900 px** (`kDesktopBreakpoint` in `lib/responsive/breakpoints.dart`).

Helper: `isDesktop(BuildContext context)` — returns `true` when `MediaQuery.sizeOf(context).width >= 900`.

### Shell at ≥900 px

`lib/screens/shell/shell_scaffold.dart` switches from the custom notched bottom bar to a `NavigationRail`:

```
Scaffold(body: Row([
  NavigationRail(destinations: [Events, Friends, Profile],
                 leading: _LiveRailButton, trailing: _JoinRailButton),
  VerticalDivider,
  Expanded(child: navigationShell),
]))
```

Mobile layout (< 900 px) is unchanged.

### Responsive modals

`lib/responsive/responsive_modal.dart` exports `showResponsiveModal<T>()`:
- Desktop: `showDialog` → centered `Dialog` with rounded corners, `ConstrainedBox(maxWidth, maxHeight)`
- Mobile: `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`

All `showModalBottomSheet` calls throughout the app use `showResponsiveModal` instead of the raw function.

Default sizes: `maxWidth: 560, maxHeight: 700`. Overrides for large content:

| Content | maxWidth | maxHeight |
|---------|----------|-----------|
| Score entry, large forms | 640 | 800 |
| GIF picker, bracket config | 900 | 900 |

### Max-width constraints per screen

Each screen wraps its body in `Align(topCenter) > ConstrainedBox(maxWidth: N)` on desktop:

| Screen | File | maxWidth |
|--------|------|----------|
| Events list | `screens/events/events_screen.dart` | 1000 |
| Event form | `screens/events/event_form_screen.dart` | 640 |
| Event type list | `screens/events/event_type_list_screen.dart` | 900 |
| Settings | `screens/settings/settings_screen.dart` | 800 |
| Profile | `screens/profile/profile_screen.dart` | 720 |
| Friends | `screens/friends/friends_screen.dart` | 800 |
| Notifications | `screens/notifications/notifications_screen.dart` | 800 |

### Tournament bracket

`lib/widgets/tournament/tournament_bracket_view.dart` uses `LayoutBuilder` to scale card dimensions:

| Width | cardW | cardH | colGap | rowGap |
|-------|-------|-------|--------|--------|
| < 900 | 190 | 66 | 46 | 30 |
| 900–1399 | 230 | 76 | 56 | 36 |
| ≥ 1400 | 280 | 76 | 56 | 36 |

Round-robin and pools views get `ConstrainedBox(maxWidth: 960)` at ≥900 px.

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
