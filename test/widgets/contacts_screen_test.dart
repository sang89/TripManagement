import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/providers/friends_provider.dart';
import 'package:trip_management/screens/friends/contacts_screen.dart';

class _FakeFriendsProvider extends FriendsProvider {}

Widget _wrap(Widget child) => ChangeNotifierProvider<FriendsProvider>.value(
      value: _FakeFriendsProvider(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  group('ContactsScreen', () {
    testWidgets('shows loading indicator on initial render', (tester) async {
      await tester.pumpWidget(_wrap(const ContactsScreen()));
      // pump once (process microtasks) but do NOT settle — the screen is
      // waiting for platform contacts API which never resolves in unit tests.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('has the correct AppBar title', (tester) async {
      await tester.pumpWidget(_wrap(const ContactsScreen()));
      await tester.pump();

      expect(find.text('Find from Contacts'), findsOneWidget);
    });
  });
}
