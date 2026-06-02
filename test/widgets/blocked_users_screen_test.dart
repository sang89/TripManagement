// ignore_for_file: prefer_initializing_formals
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/models/blocked_user.dart';
import 'package:trip_management/providers/blocked_users_provider.dart';
import 'package:trip_management/screens/settings/blocked_users_screen.dart';

// ── Fake provider ──────────────────────────────────────────────────────────────

class _FakeBlockedUsersProvider extends BlockedUsersProvider {
  final List<BlockedUser> _users;
  final bool _loading;
  final String? _unblockError;

  String? lastUnblockedId;

  _FakeBlockedUsersProvider({
    List<BlockedUser> users = const [],
    bool loading = false,
    String? unblockError,
  })  : _users = users,
        _loading = loading,
        _unblockError = unblockError;

  @override
  Future<void> load() async {}

  @override
  List<BlockedUser> get blocked => _users;

  @override
  bool get loading => _loading;

  @override
  Future<void> unblockUser(String userId) async {
    if (_unblockError != null) throw Exception(_unblockError);
    lastUnblockedId = userId;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BlockedUser _user(String id, String name) => BlockedUser(
      userId: id,
      fullName: name,
      avatarUrl: '',
      blockedAt: DateTime(2025),
    );

Widget _wrap(_FakeBlockedUsersProvider provider) =>
    ChangeNotifierProvider<BlockedUsersProvider>.value(
      value: provider,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlockedUsersScreen(),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('BlockedUsersScreen', () {
    testWidgets('shows loading indicator while loading', (tester) async {
      await tester.pumpWidget(_wrap(_FakeBlockedUsersProvider(loading: true)));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no blocked users', (tester) async {
      await tester.pumpWidget(_wrap(_FakeBlockedUsersProvider()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
      // Empty message appears
      expect(
        find.textContaining("haven't blocked"),
        findsOneWidget,
      );
    });

    testWidgets('shows blocked user names in list', (tester) async {
      final provider = _FakeBlockedUsersProvider(
        users: [
          _user('u1', 'Alice'),
          _user('u2', 'Bob'),
        ],
      );
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('Unblock button calls unblockUser with correct id',
        (tester) async {
      final provider = _FakeBlockedUsersProvider(
        users: [_user('u1', 'Alice')],
      );
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(provider.lastUnblockedId, 'u1');
    });

    testWidgets('shows error snackbar when unblock fails', (tester) async {
      final provider = _FakeBlockedUsersProvider(
        users: [_user('u1', 'Alice')],
        unblockError: 'network error',
      );
      await tester.pumpWidget(_wrap(provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
