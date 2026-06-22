import 'dart:math';
import 'dart:ui' show Color;

/// One drawable slice of the spin wheel.
class WheelSegment {
  final String optionId;
  final String label;

  /// Effective slice weight (always >= 1 — see [buildSegments]).
  final int weight;
  final Color color;

  /// Food emoji for restaurant-poll options; null otherwise.
  final String? emoji;

  const WheelSegment({
    required this.optionId,
    required this.label,
    required this.weight,
    required this.color,
    this.emoji,
  });
}

/// Vibrant slice palette — harmonises with the existing poll gradients
/// (teal→lime for generic polls, indigo→purple for restaurant polls) and fills
/// the rest of the ring with bright, joyful accents.
const List<Color> kWheelPalette = [
  Color(0xFF00B09B), // teal
  Color(0xFF667EEA), // indigo
  Color(0xFFFF6B6B), // coral
  Color(0xFFFFC048), // amber
  Color(0xFF764BA2), // purple
  Color(0xFF12C2E9), // cyan
  Color(0xFF96C93D), // lime
  Color(0xFFF761A1), // magenta
  Color(0xFFFF9A3D), // tangerine
];

/// Builds the wheel slices from poll options.
///
/// Each option keeps a **minimum slice** (`weight = max(votes, 1)`) so options
/// with zero votes are still on the wheel and can still win, while voted options
/// get proportionally bigger arcs. A poll with no votes at all becomes equal
/// slices. Colours cycle through [palette]; the wrap-around adjacency (last slice
/// touching the first) is fixed so no two neighbouring slices share a colour
/// whenever the palette is large enough.
List<WheelSegment> buildSegments({
  required List<({String id, String text, String? emoji})> options,
  required int Function(String optionId) votesFor,
  List<Color> palette = kWheelPalette,
}) {
  final n = options.length;
  final segments = <WheelSegment>[];
  for (var i = 0; i < n; i++) {
    final o = options[i];
    var color = palette[i % palette.length];
    // Circular adjacency: if the last slice would match the first, nudge it.
    if (i == n - 1 && n > 1 && color == palette[0]) {
      color = palette[(i + 1) % palette.length];
    }
    segments.add(WheelSegment(
      optionId: o.id,
      label: o.text,
      weight: max(votesFor(o.id), 1),
      color: color,
      emoji: o.emoji,
    ));
  }
  return segments;
}

/// Total weight across all slices.
int totalWeight(List<WheelSegment> segs) =>
    segs.fold(0, (sum, s) => sum + s.weight);

/// Picks a slice index with probability proportional to slice weight.
///
/// Deterministic when [rng] is seeded — this is the test seam that makes the
/// landed option assertable. Returns 0 for an empty list.
int pickWeightedIndex(List<WheelSegment> segs, Random rng) {
  if (segs.isEmpty) return 0;
  final total = totalWeight(segs);
  var r = rng.nextInt(total);
  for (var i = 0; i < segs.length; i++) {
    if (r < segs[i].weight) return i;
    r -= segs[i].weight;
  }
  return segs.length - 1;
}

/// Cumulative sweep (radians) from the wheel origin to the start of slice [index].
double _cumStartAngle(List<WheelSegment> segs, int index) {
  final total = totalWeight(segs);
  var before = 0;
  for (var i = 0; i < index; i++) {
    before += segs[i].weight;
  }
  return 2 * pi * before / total;
}

/// The wheel rotation (radians) that brings slice [index] under the fixed top
/// pointer, plus [extraTurns] full revolutions for a satisfying spin.
///
/// [jitter] in [-1, 1] offsets the landing within the slice (fraction of the
/// slice half-sweep) so it doesn't always stop dead-centre. The result still
/// lands inside the slice for any |jitter| <= 1.
double targetAngleForIndex(
  List<WheelSegment> segs,
  int index, {
  int extraTurns = 5,
  double jitter = 0,
}) {
  final total = totalWeight(segs);
  final sweep = 2 * pi * segs[index].weight / total;
  final mid = _cumStartAngle(segs, index) + sweep / 2;
  final offset = jitter.clamp(-1.0, 1.0) * (sweep / 2) * 0.85;
  return extraTurns * 2 * pi - (mid + offset);
}

/// Which slice sits under the fixed top pointer at a given [rotation]. Inverse of
/// [targetAngleForIndex]; used by tests and by the haptic-tick boundary check.
int indexAtPointer(List<WheelSegment> segs, double rotation) {
  if (segs.isEmpty) return 0;
  final total = totalWeight(segs);
  // Angle from the wheel origin currently under the pointer.
  var a = (-rotation) % (2 * pi);
  if (a < 0) a += 2 * pi;
  var acc = 0.0;
  for (var i = 0; i < segs.length; i++) {
    final sweep = 2 * pi * segs[i].weight / total;
    if (a < acc + sweep) return i;
    acc += sweep;
  }
  return segs.length - 1;
}
