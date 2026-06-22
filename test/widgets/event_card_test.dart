import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/models/event.dart';
import 'package:trip_management/models/event_guest.dart';
import 'package:trip_management/providers/event_provider.dart';
import 'package:trip_management/widgets/event_card.dart';

// Captures setEventArchived calls without touching Supabase.
class _FakeEventProvider extends EventProvider {
  String? lastEventId;
  bool? lastArchived;

  @override
  Future<void> setEventArchived(String eventId, bool archived) async {
    lastEventId = eventId;
    lastArchived = archived;
  }
}

EventGuest _guest(String userId, {bool archived = false}) => EventGuest(
      id: 'g-$userId',
      eventId: 'e1',
      userId: userId,
      displayName: userId,
      status: 'going',
      rsvpAt: DateTime(2026, 6, 1),
      createdAt: DateTime(2026, 6, 1),
      isArchived: archived,
    );

Event _event({
  required DateTime startAt,
  DateTime? endAt,
  List<EventGuest> guests = const [],
}) =>
    Event(
      id: 'e1',
      createdBy: 'u1',
      title: 'Test Event',
      description: '',
      location: '',
      startAt: startAt,
      endAt: endAt,
      inviteCode: 'code',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
      guests: guests,
    );

Widget _wrap(Event event, {String? currentUserId, EventProvider? provider}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: EventCard(event: event, currentUserId: currentUserId),
        ),
      ),
      // Tapping a card navigates here — a no-op stub so tap doesn't throw.
      GoRoute(
        path: '/event/:id',
        builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
  return ChangeNotifierProvider<EventProvider>.value(
    value: provider ?? _FakeEventProvider(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  final now = DateTime.now();

  group('EventCard dim treatment', () {
    testWidgets('upcoming event is NOT dimmed', (tester) async {
      final event = _event(
        startAt: now.add(const Duration(days: 2)),
        guests: [_guest('me')],
      );
      await tester.pumpWidget(_wrap(event, currentUserId: 'me'));
      expect(find.byKey(const ValueKey('eventCardDim')), findsNothing);
    });

    testWidgets('event archived by current user is dimmed', (tester) async {
      final event = _event(
        startAt: now.subtract(const Duration(days: 10)),
        guests: [_guest('me', archived: true)],
      );
      await tester.pumpWidget(_wrap(event, currentUserId: 'me'));
      expect(find.byKey(const ValueKey('eventCardDim')), findsOneWidget);
    });

    testWidgets('date-past event is dimmed', (tester) async {
      final event = _event(
        startAt: now.subtract(const Duration(days: 3)),
        endAt: now.subtract(const Duration(days: 2)),
        guests: [_guest('me')],
      );
      await tester.pumpWidget(_wrap(event, currentUserId: 'me'));
      expect(find.byKey(const ValueKey('eventCardDim')), findsOneWidget);
    });
  });

  group('EventCard long-press move sheet', () {
    testWidgets('upcoming event offers Move to Past and calls provider',
        (tester) async {
      final provider = _FakeEventProvider();
      final event = _event(
        startAt: now.add(const Duration(days: 2)),
        guests: [_guest('me')],
      );
      await tester.pumpWidget(
          _wrap(event, currentUserId: 'me', provider: provider));

      await tester.longPress(find.byType(EventCard));
      await tester.pumpAndSettle();
      expect(find.text('Move to Past'), findsOneWidget);

      await tester.tap(find.text('Move to Past'));
      await tester.pumpAndSettle();
      expect(provider.lastEventId, 'e1');
      expect(provider.lastArchived, isTrue);
    });

    testWidgets('archived (not date-past) event offers Move to Upcoming',
        (tester) async {
      final provider = _FakeEventProvider();
      final event = _event(
        startAt: now.subtract(const Duration(days: 10)),
        guests: [_guest('me', archived: true)],
      );
      await tester.pumpWidget(
          _wrap(event, currentUserId: 'me', provider: provider));

      await tester.longPress(find.byType(EventCard));
      await tester.pumpAndSettle();
      expect(find.text('Move to Upcoming'), findsOneWidget);

      await tester.tap(find.text('Move to Upcoming'));
      await tester.pumpAndSettle();
      expect(provider.lastArchived, isFalse);
    });

    testWidgets('genuinely date-past event has no long-press action',
        (tester) async {
      final event = _event(
        startAt: now.subtract(const Duration(days: 3)),
        endAt: now.subtract(const Duration(days: 2)),
        guests: [_guest('me')],
      );
      await tester.pumpWidget(_wrap(event, currentUserId: 'me'));

      await tester.longPress(find.byType(EventCard));
      await tester.pumpAndSettle();
      expect(find.text('Move to Past'), findsNothing);
      expect(find.text('Move to Upcoming'), findsNothing);
    });
  });
}
