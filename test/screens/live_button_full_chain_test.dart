import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/models/event.dart';
import 'package:trip_management/models/event_bring_item.dart';
import 'package:trip_management/models/event_expense.dart';
import 'package:trip_management/models/event_photo.dart';
import 'package:trip_management/models/event_poll.dart';
import 'package:trip_management/models/event_session.dart';
import 'package:trip_management/models/session_queue.dart';
import 'package:trip_management/providers/auth_provider.dart';
import 'package:trip_management/providers/event_chat_provider.dart';
import 'package:trip_management/providers/event_provider.dart';
import 'package:trip_management/providers/friends_provider.dart';
import 'package:trip_management/providers/notifications_provider.dart';
import 'package:trip_management/screens/events/event_detail_screen.dart';
import 'package:trip_management/screens/shell/shell_scaffold.dart';

// Drives the FULL real chain: real ShellScaffold Live button → the real
// main.dart-style GoRoute builder → real EventDetailScreen.

class _FakeAuth extends AuthProvider {
  @override
  String? get userId => 'organizer-1';
}

class _FakeNotifs extends NotificationsProvider {
  @override
  int get unreadCount => 0;
}

class _FakeChat extends EventChatProvider {
  _FakeChat() : super(eventId: 'A', userId: 'organizer-1');
  @override
  Future<void> init() async {}
}

class _FakeEvents extends EventProvider {
  _FakeEvents(this._event, this._sessions);
  final Event _event;
  final List<EventSession> _sessions;
  int fetchLiveCount = 0;

  @override
  List<Event> get events => [_event];
  @override
  Event? getById(String id) => id == _event.id ? _event : null;
  @override
  List<EventSession> get liveSessions => _sessions;

  @override
  List<EventSession> upcomingSessionsFor(String eventId) =>
      _sessions.where((s) => s.startAt.isAfter(DateTime.now())).toList();
  @override
  List<EventSession> pastSessionsFor(String eventId) =>
      _sessions.where((s) => !s.startAt.isAfter(DateTime.now())).toList();

  @override
  Future<void> fetchLiveSessions() async {
    fetchLiveCount++;
  }

  @override
  Future<void> fetchUpcomingSessions(String eventId) async {}
  @override
  Future<void> fetchPastSessions(String eventId) async {}
  @override
  Future<void> fetchSessionQueues(String eventId, String sessionId) async {}
  @override
  Future<List<EventPhoto>> fetchPhotos(String eventId, {int offset = 0}) async => [];
  @override
  Future<List<EventExpense>> fetchExpenses(String eventId) async => [];
  @override
  Future<List<EventBringItem>> fetchBringList(String eventId) async => [];
  @override
  Future<List<EventPoll>> fetchPolls(String eventId) async => [];
  @override
  List<EventPhoto> photosFor(String eventId) => [];
  @override
  List<EventExpense> expensesFor(String eventId) => [];
  @override
  List<EventBringItem> bringItemsFor(String eventId) => [];
  @override
  List<EventPoll> pollsFor(String eventId) => [];
  @override
  List<SessionQueueActivity> queuesFor(String sessionId) => [];
  @override
  List<SessionQueueEntry> entriesFor(String activityId) => [];
  @override
  List<SessionFreePoolEntry> freePoolFor(String sessionId) => [];
}

Event _signupEvent() => Event(
      id: 'A',
      createdBy: 'organizer-1',
      title: 'Tennis Club',
      description: '',
      location: '',
      // Event itself is over → the only live item is the session.
      startAt: DateTime.now().subtract(const Duration(days: 2)),
      endAt: DateTime.now().subtract(const Duration(days: 1)),
      inviteCode: 'code',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      guests: const [],
      eventType: EventType.signup,
    );

EventSession _liveSession() => EventSession(
      id: 'X',
      eventId: 'A',
      sessionNumber: 1,
      startAt: DateTime.now().subtract(const Duration(minutes: 30)),
      endAt: DateTime.now().add(const Duration(minutes: 30)),
      inviteCode: 'sc',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isActive: true,
    );

Widget _harness(_FakeEvents events, {String initialLocation = '/events'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/events',
              builder: (_, _) =>
                  const Scaffold(body: Center(child: Text('EVENTS-LIST'))),
            ),
            // Mirrors main.dart's real /event/:id builder.
            GoRoute(
              path: '/event/:id',
              pageBuilder: (_, state) {
                final eventId = state.pathParameters['id']!;
                final tabParam = state.uri.queryParameters['tab'];
                final initialTab = tabParam == 'session' ? 3 : 0;
                final initialSessionId = state.uri.queryParameters['sessionId'];
                return MaterialPage(
                  key: ValueKey('event-$eventId-$initialTab-$initialSessionId'),
                  child: ChangeNotifierProvider<EventChatProvider>.value(
                    value: _FakeChat(),
                    child: EventDetailScreen(
                      eventId: eventId,
                      initialTab: initialTab,
                      initialSessionId: initialSessionId,
                    ),
                  ),
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/friends',
                builder: (_, _) => const Scaffold(body: Text('FRIENDS'))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile',
                builder: (_, _) => const Scaffold(body: Text('PROFILE'))),
          ]),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EventProvider>.value(value: events),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
      ChangeNotifierProvider<NotificationsProvider>.value(value: _FakeNotifs()),
      ChangeNotifierProvider<FriendsProvider>.value(value: FriendsProvider()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

int _tabIndexOf(WidgetTester tester, IconData iconData) {
  final bars = tester.widgetList<TabBar>(find.byType(TabBar));
  for (final bar in bars) {
    final hasIcon = bar.tabs.any((t) =>
        t is Tab && t.icon is Icon && (t.icon as Icon).icon == iconData);
    if (hasIcon) return bar.controller!.index;
  }
  return -1;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  Finder liveButton() => find.byIcon(Icons.sensors_rounded);

  testWidgets('from events list, Live tap → Session(3) → Activity(1)',
      (tester) async {
    final events = _FakeEvents(_signupEvent(), [_liveSession()]);
    await tester.pumpWidget(_harness(events));
    await _settle(tester);

    expect(find.text('EVENTS-LIST'), findsOneWidget);

    await tester.tap(liveButton(), warnIfMissed: false);
    await _settle(tester);

    expect(events.fetchLiveCount, greaterThan(0),
        reason: 'tap must refresh live sessions');
    expect(_tabIndexOf(tester, Icons.info_outline_rounded), 3,
        reason: 'outer tab should be Session (3), not Info (0)');
    expect(_tabIndexOf(tester, Icons.format_list_numbered_outlined), 1,
        reason: 'inner organize tab should be Activity (1)');
  });

  testWidgets(
      'already viewing event A (Info), Live tap → switches to Session(3) [reuse]',
      (tester) async {
    final events = _FakeEvents(_signupEvent(), [_liveSession()]);
    // Start already on the event's Info tab (no session deep-link).
    await tester.pumpWidget(_harness(events, initialLocation: '/event/A'));
    await _settle(tester);

    expect(_tabIndexOf(tester, Icons.info_outline_rounded), 0,
        reason: 'should start on Info');

    await tester.tap(liveButton(), warnIfMissed: false);
    await _settle(tester);

    expect(_tabIndexOf(tester, Icons.info_outline_rounded), 3,
        reason: 'reused screen must switch to Session (3)');
  });
}
