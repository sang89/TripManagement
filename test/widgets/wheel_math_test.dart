import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/widgets/wheel_math.dart';

List<({String id, String text, String? emoji})> _opts(int n) => List.generate(
    n, (i) => (id: 'o$i', text: 'Option $i', emoji: null));

void main() {
  group('buildSegments', () {
    test('zero total votes → all equal weights of 1', () {
      final segs = buildSegments(options: _opts(4), votesFor: (_) => 0);
      expect(segs, hasLength(4));
      expect(segs.every((s) => s.weight == 1), isTrue);
    });

    test('mixed votes use max(raw, 1) so 0-vote options stay on the wheel', () {
      final votes = {'o0': 5, 'o1': 0, 'o2': 3};
      final segs = buildSegments(
        options: _opts(3),
        votesFor: (id) => votes[id] ?? 0,
      );
      expect(segs[0].weight, 5);
      expect(segs[1].weight, 1); // 0 votes → min slice
      expect(segs[2].weight, 3);
    });

    test('colours cycle the palette and avoid the wrap-around duplicate', () {
      final segs = buildSegments(
        options: _opts(kWheelPalette.length),
        votesFor: (_) => 1,
      );
      // No two adjacent slices (including last↔first) share a colour.
      for (var i = 0; i < segs.length; i++) {
        final next = segs[(i + 1) % segs.length];
        expect(segs[i].color, isNot(next.color),
            reason: 'slice $i matches its neighbour');
      }
    });
  });

  group('pickWeightedIndex', () {
    test('is deterministic under a seeded Random', () {
      final segs = buildSegments(options: _opts(5), votesFor: (_) => 1);
      final a = pickWeightedIndex(segs, Random(42));
      final b = pickWeightedIndex(segs, Random(42));
      expect(a, b);
    });

    test('frequency is proportional to weight over many draws', () {
      final votes = {'o0': 1, 'o1': 3, 'o2': 6}; // total 10
      final segs = buildSegments(
        options: _opts(3),
        votesFor: (id) => votes[id]!,
      );
      final rng = Random(7);
      final counts = [0, 0, 0];
      const n = 20000;
      for (var i = 0; i < n; i++) {
        counts[pickWeightedIndex(segs, rng)]++;
      }
      expect(counts[0] / n, closeTo(0.1, 0.03));
      expect(counts[1] / n, closeTo(0.3, 0.03));
      expect(counts[2] / n, closeTo(0.6, 0.03));
    });
  });

  group('targetAngleForIndex / indexAtPointer', () {
    test('round-trips: spinning to the target puts that slice under pointer', () {
      final votes = {'o0': 2, 'o1': 5, 'o2': 1, 'o3': 4};
      final segs = buildSegments(
        options: _opts(4),
        votesFor: (id) => votes[id]!,
      );
      for (var i = 0; i < segs.length; i++) {
        final angle = targetAngleForIndex(segs, i);
        expect(indexAtPointer(segs, angle), i, reason: 'index $i');
      }
    });

    test('jitter still lands inside the slice', () {
      final segs = buildSegments(options: _opts(6), votesFor: (_) => 1);
      for (var i = 0; i < segs.length; i++) {
        expect(indexAtPointer(segs, targetAngleForIndex(segs, i, jitter: 1)), i);
        expect(indexAtPointer(segs, targetAngleForIndex(segs, i, jitter: -1)), i);
      }
    });

    test('extraTurns adds whole revolutions only', () {
      final segs = buildSegments(options: _opts(3), votesFor: (_) => 1);
      final a = targetAngleForIndex(segs, 1, extraTurns: 2);
      final b = targetAngleForIndex(segs, 1, extraTurns: 7);
      expect((b - a) / (2 * pi), closeTo(5, 1e-9));
    });

    test('slice sweeps sum to 2π', () {
      final votes = {'o0': 2, 'o1': 5, 'o2': 1};
      final segs = buildSegments(
        options: _opts(3),
        votesFor: (id) => votes[id]!,
      );
      final total = totalWeight(segs);
      final sum = segs.fold<double>(
          0, (s, seg) => s + 2 * pi * seg.weight / total);
      expect(sum, closeTo(2 * pi, 1e-9));
    });
  });
}
