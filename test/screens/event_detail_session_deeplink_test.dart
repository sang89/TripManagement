import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:trip_management/providers/notifications_provider.dart';
import 'package:trip_management/screens/events/event_detail_screen.dart';

// ── Fakes that never touch Supabase ──────────────────────────────────────────
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

  @override
  List<Event> get events => [_event];
  @override
  Event? getById(String id) => id == _event.id ? _event : null;

  // Sessions: a live session has start_at < now, so it lives in the "past" list.
  @override
  List<EventSession> upcomingSessionsFor(String eventId) =>
      _sessions.where((s) => s.startAt.isAfter(DateTime.now())).toList();
  @override
  List<EventSession> pastSessionsFor(String eventId) =>
      _sessions.where((s) => !s.startAt.isAfter(DateTime.now())).toList();
  @override
  List<EventSession> get liveSessions => _sessions;

  // All network fetches → no-op / empty.
  @override
  Future<void> fetchUpcomingSessions(String eventId) async {}
  @override
  Future<void> fetchPastSessions(String eventId) async {}
  @override
  Future<void> fetchSessionQueues(String eventId, String sessionId) async {}
  @override
  Future<void> fetchLiveSessions() async {}
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
      startAt: DateTime.now().subtract(const Duration(hours: 2)),
      endAt: DateTime.now().add(const Duration(hours: 2)),
      inviteCode: 'code',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      guests: const [],
      eventType: EventType.signup,
    );

EventSession _session(String id, {bool isActive = false}) => EventSession(
      id: id,
      eventId: 'A',
      sessionNumber: 1,
      startAt: DateTime.now().subtract(const Duration(minutes: 30)),
      endAt: DateTime.now().add(const Duration(minutes: 30)),
      inviteCode: 'sc-$id',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isActive: isActive,
    );

Widget _wrap(EventProvider events, {required int initialTab, String? sessionId}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EventProvider>.value(value: events),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
      ChangeNotifierProvider<NotificationsProvider>.value(value: _FakeNotifs()),
      ChangeNotifierProvider<EventChatProvider>.value(value: _FakeChat()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EventDetailScreen(
        eventId: 'A',
        initialTab: initialTab,
        initialSessionId: sessionId,
      ),
    ),
  );
}

/// Reads the selected index of the TabBar that contains [iconData].
int _tabIndexOf(WidgetTester tester, IconData iconData) {
  final bars = tester.widgetList<TabBar>(find.byType(TabBar));
  for (final bar in bars) {
    final hasIcon = bar.tabs.any((t) =>
        t is Tab && t.icon is Icon && (t.icon as Icon).icon == iconData);
    if (hasIcon) return bar.controller!.index;
  }
  fail('No TabBar found containing icon $iconData');
}

void main() {
  testWidgets(
      'session deep-link lands on Session(3) → Activity(1), not Info', (tester) async {
    final events = _FakeEvents(_signupEvent(), [_session('X', isActive: true)]);

    await tester.pumpWidget(
        _wrap(events, initialTab: 3, sessionId: 'X'));
    await tester.pump(); // first frame
    await tester.pump(const Duration(milliseconds: 400)); // post-frame _loadSessions

    // Outer TabBar (has the Info icon) must be on tab 3 (Session), NOT 0 (Info).
    expect(_tabIndexOf(tester, Icons.info_outline_rounded), 3,
        reason: 'outer tab should be Session (3), not Info (0)');

    // Inner Organize TabBar (has the Roster icon) must be on the Activity tab (1).
    expect(_tabIndexOf(tester, Icons.format_list_numbered_outlined), 1,
        reason: 'inner organize tab should be Activity (1), not Roster (0)');
  });

  testWidgets('without a session deep-link, opens Info(0)', (tester) async {
    final events = _FakeEvents(_signupEvent(), [_session('X', isActive: true)]);
    await tester.pumpWidget(_wrap(events, initialTab: 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_tabIndexOf(tester, Icons.info_outline_rounded), 0);
  });
}
