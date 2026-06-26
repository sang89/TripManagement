import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/widgets/tournament/live_elapsed_timer.dart';

void main() {
  group('LiveElapsedTimer', () {
    testWidgets('shows elapsed minutes and seconds', (tester) async {
      final startedAt = DateTime.now().subtract(const Duration(seconds: 65));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveElapsedTimer(startedAt: startedAt),
          ),
        ),
      );
      // 65 seconds = 1m 05s
      expect(find.textContaining('1m 05s'), findsOneWidget);
    });

    testWidgets('displays zero elapsed for a just-started match', (tester) async {
      final startedAt = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveElapsedTimer(startedAt: startedAt),
          ),
        ),
      );
      expect(find.textContaining('0m'), findsOneWidget);
    });
  });
}
