import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/models/event.dart';
import 'package:trip_management/models/event_session.dart';
import 'package:trip_management/providers/auth_provider.dart';
import 'package:trip_management/providers/event_provider.dart';
import 'package:trip_management/providers/friends_provider.dart';
import 'package:trip_management/screens/shell/shell_scaffold.dart';

class _FakeAuth extends AuthProvider {
  @override
  String? get userId => 'u1';
}

class _FakeEvents extends EventProvider {
  _FakeEvents(this._injected, this._injectedSessions);
  final List<Event> _injected;
  final List<EventSession> _injectedSessions;

  @override
  List<Event> get events => _injected;
  @override
  List<EventSession> get liveSessions => _injectedSessions;
  @override
  Future<void> fetchLiveSessions() async {} // never hit Supabase in tests
}

/// fetchLiveSessions throws (network/RLS failure). The Live button must not
/// crash — it falls back to the (empty) cache and shows the snackbar.
class _ThrowingFakeEvents extends EventProvider {
  @override
  List<Event> get events => const [];
  @override
  List<EventSession> get liveSessions => const [];
  @override
  Future<void> fetchLiveSessions() async => throw Exception('network down');
}

/// Simulates the real cache: liveSessions is EMPTY until fetchLiveSessions runs
/// (as happens after a hot reload where load() never re-seeded it). Tapping Live
/// must fetch first, then navigate to the now-discovered session.
class _LazyFakeEvents extends EventProvider {
  _LazyFakeEvents(this._injected, this._lazySessions);
  final List<Event> _injected;
  final List<EventSession> _lazySessions;
  bool _fetched = false;
  int fetchCount = 0;

  @override
  List<Event> get events => _injected;
  @override
  List<EventSession> get liveSessions => _fetched ? _lazySessions : const [];
  @override
  Future<void> fetchLiveSessions() async {
    fetchCount++;
    _fetched = true;
    notifyListeners();
  }
}

Event _event({
  required String id,
  required DateTime startAt,
  DateTime? endAt,
}) =>
    Event(
      id: id,
      createdBy: 'u1',
      title: 'Event $id',
      description: '',
      location: '',
      startAt: startAt,
      endAt: endAt,
      inviteCode: 'code-$id',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
      guests: const [],
    );

Widget _harness(EventProvider events) {
  final router = GoRouter(
    initialLocation: '/events',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/events',
              builder: (_, _) => const Scaffold(body: Text('EVENTS')),
            ),
            GoRoute(
              path: '/event/:id',
              builder: (_, state) {
                final id = state.pathParameters['id'];
                final tab = state.uri.queryParameters['tab'] ?? 'info';
                return Scaffold(body: Text('EVENT-$id-$tab'));
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/friends',
              builder: (_, _) => const Scaffold(body: Text('FRIENDS')),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const Scaffold(body: Text('PROFILE')),
            ),
          ]),
        ],
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EventProvider>.value(value: events),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
      ChangeNotifierProvider<FriendsProvider>.value(value: FriendsProvider()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  final now = DateTime.now();

  Finder liveButton() => find.byIcon(Icons.sensors_rounded);

  // The Live button pulses forever when items are live, so pumpAndSettle would
  // time out. Pump a couple of bounded frames to flush navigation instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('cycles through live SESSIONS on repeated taps', (tester) async {
    // Two events, each with one live session. The Live button cycles through the
    // sessions (Activity tab), never the events' Info tab.
    final e1 = _event(
      id: 'e1',
      startAt: now.subtract(const Duration(days: 1)),
      endAt: now.add(const Duration(days: 1)),
    );
    final e2 = _event(
      id: 'e2',
      startAt: now.subtract(const Duration(days: 1)),
      endAt: now.add(const Duration(days: 1)),
    );
    final sX = EventSession(
      id: 'sx',
      eventId: 'e1',
      sessionNumber: 1,
      startAt: now.subtract(const Duration(minutes: 30)),
      endAt: now.add(const Duration(minutes: 30)),
      inviteCode: 'sx',
      createdAt: DateTime(2026, 6, 1),
    );
    final sY = EventSession(
      id: 'sy',
      eventId: 'e2',
      sessionNumber: 1,
      startAt: now.subtract(const Duration(minutes: 10)),
      endAt: now.add(const Duration(minutes: 50)),
      inviteCode: 'sy',
      createdAt: DateTime(2026, 6, 1),
    );

    await tester.pumpWidget(_harness(_FakeEvents([e1, e2], [sX, sY])));
    await settle(tester);

    // Badge shows the live session count.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('EVENTS'), findsOneWidget);

    // First tap → earliest session (sX, on e1) → Session tab.
    await tester.tap(liveButton(), warnIfMissed: false);
    await settle(tester);
    expect(find.text('EVENT-e1-session'), findsOneWidget);

    // Second tap → next session (sY, on e2).
    await tester.tap(liveButton(), warnIfMissed: false);
    await settle(tester);
    expect(find.text('EVENT-e2-session'), findsOneWidget);

    // Third tap → cycles back to sX.
    await tester.tap(liveButton(), warnIfMissed: false);
    await settle(tester);
    expect(find.text('EVENT-e1-session'), findsOneWidget);
  });

  testWidgets('ongoing event with NO live session routes to Info', (tester) async {
    final ongoing = _event(
      id: 'oe',
      startAt: now.subtract(const Duration(hours: 1)),
      endAt: now.add(const Duration(hours: 1)),
    );

    await tester.pumpWidget(_harness(_FakeEvents([ongoing], const [])));
    await settle(tester);

    expect(find.text('1'), findsOneWidget); // badge counts the live event

    await tester.tap(liveButton(), warnIfMissed: false);
    await settle(tester);
    expect(find.text('EVENT-oe-info'), findsOneWidget); // Info → Details
  });

  testWidgets('live session routes to the session tab', (tester) async {
    final e = _event(
      id: 'sess-evt',
      startAt: now.subtract(const Duration(days: 1)),
      endAt: now.add(const Duration(days: 10)),
    );
    final s = EventSession(
      id: 's1',
      eventId: 'sess-evt',
      sessionNumber: 1,
      startAt: now.subtract(const Duration(minutes: 5)),
      endAt: now.add(const Duration(minutes: 55)),
      inviteCode: 'sc',
      createdAt: DateTime(2026, 6, 1),
    );

    await tester.pumpWidget(_harness(_FakeEvents([e], [s])));
    await settle(tester);

    await tester.tap(liveButton(), warnIfMissed: false);
    await settle(tester);
    expect(find.text('EVENT-sess-evt-session'), findsOneWidget);
  });

  testWidgets(
      'tap fetches live sessions first, then routes to the session (stale-cache fix)',
      (tester) async {
    // Cache starts empty (as after a hot reload). The event itself is over, so
    // the ONLY live item is the session — and it's only discovered once the tap
    // triggers fetchLiveSessions.
    final e = _event(
      id: 'sess-evt',
      startAt: now.subtract(const Duration(days: 2)),
      endAt: now.subtract(const Duration(days: 1)),
    );
    final s = EventSession(
      id: 's1',
      eventId: 'sess-evt',
      sessionNumber: 1,
      startAt: now.subtract(const Duration(minutes: 5)),
      endAt: now.add(const Duration(minutes: 55)),
      inviteCode: 'sc',
      createdAt: DateTime(2026, 6, 1),
    );
    final lazy = _LazyFakeEvents([e], [s]);

    await tester.pumpWidget(_harness(lazy));
    await settle(tester);

    // Before tapping, the cache is empty → no badge.
    expect(find.text('1'), findsNothing);

    await tester.tap(liveButton(), warnIfMissed: false);
    await settle(tester);

    // The tap must have fetched, then navigated to the session's Activity tab.
    expect(lazy.fetchCount, greaterThan(0));
    expect(find.text('EVENT-sess-evt-session'), findsOneWidget);
  });

  testWidgets('no live items → snackbar and no badge', (tester) async {
    final future = _event(
      id: 'future',
      startAt: now.add(const Duration(days: 1)),
      endAt: now.add(const Duration(days: 2)),
    );

    await tester.pumpWidget(_harness(_FakeEvents([future], const [])));
    await settle(tester);

    // Greyed state: no count badge rendered.
    expect(find.text('1'), findsNothing);

    await tester.tap(liveButton(), warnIfMissed: false);
    await tester.pump(); // let the snackbar appear
    expect(find.text('No live events right now'), findsOneWidget);
    // Still on the events tab — no navigation happened.
    expect(find.text('EVENTS'), findsOneWidget);
  });

  testWidgets('completely empty: repeated taps never error (no % by zero)',
      (tester) async {
    await tester.pumpWidget(_harness(_FakeEvents(const [], const [])));
    await settle(tester);

    // Tap several times — the empty-queue guard must run before any
    // `_liveCursor % queue.length`, so this can never divide by zero / index.
    for (var i = 0; i < 3; i++) {
      await tester.tap(liveButton(), warnIfMissed: false);
      await settle(tester);
      expect(find.text('EVENTS'), findsOneWidget); // never navigated
    }
    expect(tester.takeException(), isNull);
    expect(find.text('No live events right now'), findsWidgets);
  });

  testWidgets('fetchLiveSessions failure does not crash the tap',
      (tester) async {
    await tester.pumpWidget(_harness(_ThrowingFakeEvents()));
    await settle(tester);

    await tester.tap(liveButton(), warnIfMissed: false);
    await settle(tester);

    // The thrown refresh is swallowed; empty cache → snackbar, no crash.
    expect(tester.takeException(), isNull);
    expect(find.text('No live events right now'), findsOneWidget);
    expect(find.text('EVENTS'), findsOneWidget);
  });
}
