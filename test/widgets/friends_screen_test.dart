// ignore_for_file: prefer_initializing_formals
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/models/friendship.dart';
import 'package:trip_management/providers/friends_provider.dart';
import 'package:trip_management/providers/notifications_provider.dart';
import 'package:trip_management/screens/friends/friends_screen.dart';

// ── Fake provider ──────────────────────────────────────────────────────────────

class _FakeFriendsProvider extends FriendsProvider {
  final List<Friendship> _accepted;
  final List<Friendship> _incoming;
  final List<Friendship> _outgoing;

  _FakeFriendsProvider({
    List<Friendship> accepted = const [],
    List<Friendship> incoming = const [],
    List<Friendship> outgoing = const [],
  })  : _accepted = accepted,
        _incoming = incoming,
        _outgoing = outgoing;

  @override
  Future<void> init(String userId) async {}

  @override
  List<Friendship> get accepted => _accepted;

  @override
  List<Friendship> get incomingRequests => _incoming;

  @override
  List<Friendship> get outgoingRequests => _outgoing;

  @override
  Future<List<Map<String, String>>> searchUsers(String query) async => [];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Friendship _friendship({
  required String id,
  required String requesterId,
  required String addresseeId,
  String status = 'accepted',
  String? displayName,
}) =>
    Friendship(
      id: id,
      requesterId: requesterId,
      addresseeId: addresseeId,
      status: status,
      createdAt: DateTime(2026, 5, 30),
      otherDisplayName: displayName,
    );

Widget _wrap(_FakeFriendsProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<FriendsProvider>.value(value: provider),
        ChangeNotifierProvider<NotificationsProvider>.value(
          value: NotificationsProvider(),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FriendsScreen(),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('FriendsScreen', () {
    testWidgets('shows empty state when no friends', (tester) async {
      await tester.pumpWidget(_wrap(_FakeFriendsProvider()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people_outline), findsWidgets);
    });

    testWidgets('shows friend name in accepted list', (tester) async {
      final provider = _FakeFriendsProvider(
        accepted: [
          _friendship(
            id: 'f1',
            requesterId: 'me',
            addresseeId: 'alice',
            displayName: 'Alice Wonder',
          ),
        ],
      );
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(find.text('Alice Wonder'), findsOneWidget);
    });

    testWidgets('Requests tab shows badge when incoming requests exist',
        (tester) async {
      final provider = _FakeFriendsProvider(
        incoming: [
          _friendship(
            id: 'f2',
            requesterId: 'bob',
            addresseeId: 'me',
            status: 'pending',
            displayName: 'Bob',
          ),
        ],
      );
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      // Badge text "1" appears on the Requests tab.
      expect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping Requests tab shows incoming request', (tester) async {
      final provider = _FakeFriendsProvider(
        incoming: [
          _friendship(
            id: 'f3',
            requesterId: 'carol',
            addresseeId: 'me',
            status: 'pending',
            displayName: 'Carol',
          ),
        ],
      );
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.byWidgetPredicate(
          (w) => w is Tab && w.icon is Badge,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Carol'), findsOneWidget);
    });
  });
}
