import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/models/event.dart';
import 'package:trip_management/providers/auth_provider.dart';
import 'package:trip_management/providers/event_provider.dart';
import 'package:trip_management/providers/notifications_provider.dart';
import 'package:trip_management/providers/subscription_provider.dart';
import 'package:trip_management/screens/events/event_type_list_screen.dart';
import 'package:trip_management/screens/events/events_screen.dart';

// ── Fakes ──────────────────────────────────────────────────────────────────────

class _FakeAuth extends AuthProvider {
  @override
  String? get userId => 'user-1';
}

class _FakeNotifs extends NotificationsProvider {
  @override
  int get unreadCount => 0;
}

class _FakeSubscription extends SubscriptionProvider {
  @override
  bool get isPro => false;
}

class _FakeEvents extends EventProvider {
  @override
  bool get loaded => true;
  @override
  List<Event> get events => [];
  @override
  List<Event> get myEvents => [];
  @override
  List<Event> get invitedEvents => [];
  @override
  int get pendingInviteCount => 0;
}

Widget _wrapEventTypeList(EventType type) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EventProvider>.value(value: _FakeEvents()),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EventTypeListScreen(eventType: type),
    ),
  );
}

Widget _wrapEventsScreen() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EventProvider>.value(value: _FakeEvents()),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
      ChangeNotifierProvider<NotificationsProvider>.value(value: _FakeNotifs()),
      ChangeNotifierProvider<SubscriptionProvider>.value(value: _FakeSubscription()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const EventsScreen(),
    ),
  );
}

void main() {
  group('FAB → AppBar add button migration', () {
    testWidgets('EventTypeListScreen has + IconButton in AppBar, no FAB',
        (tester) async {
      await tester.pumpWidget(_wrapEventTypeList(EventType.trip));
      await tester.pump();

      // No FloatingActionButton anywhere
      expect(find.byType(FloatingActionButton), findsNothing);

      // + icon is present in the AppBar actions area
      final addIcons = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.add),
      );
      expect(addIcons, findsOne);
    });

    testWidgets('EventsScreen has + IconButton in AppBar, no FAB',
        (tester) async {
      await tester.pumpWidget(_wrapEventsScreen());
      await tester.pump();

      // No FloatingActionButton anywhere
      expect(find.byType(FloatingActionButton), findsNothing);

      // + icon is present somewhere in the tree (AppBar actions area)
      expect(find.byIcon(Icons.add), findsOne);
    });
  });
}
