import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/l10n/app_localizations.dart';
import 'package:trip_management/widgets/poll_wheel_sheet.dart';
import 'package:trip_management/widgets/wheel_math.dart';

List<WheelSegment> _segments({
  Map<String, int> votes = const {},
  bool restaurant = false,
}) {
  final opts = List.generate(
    4,
    (i) => (
      id: 'o$i',
      text: 'Choice $i',
      emoji: restaurant ? '🍣' : null,
    ),
  );
  return buildSegments(options: opts, votesFor: (id) => votes[id] ?? 0);
}

Widget _host(List<WheelSegment> segs,
        {int seed = 123, bool restaurant = false}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => PollWheelSheet(
            question: 'Where to eat?',
            segments: segs,
            l10n: AppLocalizations.of(ctx),
            isRestaurant: restaurant,
            rng: Random(seed),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders title, question and the spin button', (tester) async {
    await tester.pumpWidget(_host(_segments()));
    await tester.pump();
    expect(find.textContaining('Let the wheel decide'), findsOneWidget);
    expect(find.text('Where to eat?'), findsOneWidget);
    expect(find.byKey(const Key('spinWheelButton')), findsOneWidget);
  });

  testWidgets('spinning lands on the seeded weighted winner', (tester) async {
    const seed = 999;
    final segs = _segments(votes: {'o0': 2, 'o1': 5, 'o2': 1, 'o3': 4});
    final expectedIdx = pickWeightedIndex(segs, Random(seed));
    final expectedLabel = segs[expectedIdx].label;

    await tester.pumpWidget(_host(segs, seed: seed));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('spinWheelButton')));
    await tester.tap(find.byKey(const Key('spinWheelButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wheelResultCard')), findsOneWidget);
    expect(find.text(expectedLabel), findsOneWidget);
  });

  testWidgets('restaurant poll shows food headline and emoji result',
      (tester) async {
    final segs = _segments(votes: {'o1': 3}, restaurant: true);
    await tester.pumpWidget(_host(segs, restaurant: true));
    await tester.pump();
    expect(find.textContaining('Time to feast'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('spinWheelButton')));
    await tester.tap(find.byKey(const Key('spinWheelButton')));
    await tester.pumpAndSettle();
    // 🍣 appears on wheel via CustomPaint (not a Text), so the only Text match
    // is the result card's big emoji.
    expect(find.text('🍣'), findsOneWidget);
  });

  testWidgets('zero-vote poll still spins and settles without error',
      (tester) async {
    final segs = _segments(); // all weights become 1
    await tester.pumpWidget(_host(segs));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('spinWheelButton')));
    await tester.tap(find.byKey(const Key('spinWheelButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wheelResultCard')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
