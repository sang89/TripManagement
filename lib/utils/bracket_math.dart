import '../models/tournament.dart';
import 'tournament_standings.dart';

/// Thrown when a division's format + entrant count would generate more than
/// [kMaxBracketMatches] matches (e.g. a huge round-robin).
class TooManyMatchesError implements Exception {
  final int estimated;
  const TooManyMatchesError(this.estimated);
  @override
  String toString() =>
      'TooManyMatchesError: $estimated matches exceeds the $kMaxBracketMatches limit';
}

// Pure, deterministic bracket-generation logic. Dart computes the full match
// plan (seeding, pairings, byes, next-match wiring); the
// generate_division_bracket RPC just inserts the plan transactionally. Keeping
// this in Dart makes it unit-testable.

/// One planned match. `idx` is a local index used to wire `nextMatchIdx`
/// before real UUIDs exist; the RPC maps idx → uuid on insert.
class BracketMatchSpec {
  final int idx;
  final BracketType bracketType;
  final int roundNumber;
  final int matchNumber;
  final String? poolId;
  final String? entrant1Id;
  final String? entrant2Id;
  final String? winnerEntrantId; // set for byes
  final MatchStatus status;
  final int? nextMatchIdx;
  final int? nextMatchSlot; // 1 or 2
  final bool isTie; // team-vs-team match (sub-matches created server-side)

  const BracketMatchSpec({
    required this.idx,
    required this.bracketType,
    required this.roundNumber,
    required this.matchNumber,
    this.poolId,
    this.entrant1Id,
    this.entrant2Id,
    this.winnerEntrantId,
    required this.status,
    this.nextMatchIdx,
    this.nextMatchSlot,
    this.isTie = false,
  });

  BracketMatchSpec asTie() => BracketMatchSpec(
        idx: idx,
        bracketType: bracketType,
        roundNumber: roundNumber,
        matchNumber: matchNumber,
        poolId: poolId,
        entrant1Id: entrant1Id,
        entrant2Id: entrant2Id,
        winnerEntrantId: winnerEntrantId,
        status: status,
        nextMatchIdx: nextMatchIdx,
        nextMatchSlot: nextMatchSlot,
        isTie: true,
      );

  Map<String, dynamic> toJson() => {
        'idx': idx,
        'bracket_type': bracketType.dbValue,
        'round_number': roundNumber,
        'match_number': matchNumber,
        'pool_id': poolId,
        'entrant1_id': entrant1Id,
        'entrant2_id': entrant2Id,
        'winner_entrant_id': winnerEntrantId,
        'status': status.dbValue,
        'next_match_idx': nextMatchIdx,
        'next_match_slot': nextMatchSlot,
        'is_tie': isTie,
      };
}

/// Vertical centre of match [index] in [round] (0-based) for the bracket-tree
/// renderer, in "slot" units (1 slot = one first-round match's height). Each
/// round's match is centred between its two feeders so the tree lines up:
/// `bracketCenterSlots(r+1, i)` is the midpoint of `bracketCenterSlots(r, 2i)`
/// and `bracketCenterSlots(r, 2i+1)`.
double bracketCenterSlots(int round, int index) => (index + 0.5) * (1 << round);

/// Smallest power of two >= n (minimum 2).
int nextPowerOfTwo(int n) {
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p < 2 ? 2 : p;
}

/// Canonical seed slot order for a [size]-slot single-elim bracket.
/// Property: seeds 1 and 2 end up in opposite halves, and first-round pairings
/// are (seed i) vs (seed size+1-i). Built by the standard recursive interleave.
List<int> seedOrder(int size) {
  assert(size >= 2 && (size & (size - 1)) == 0, 'size must be a power of 2');
  var rounds = <int>[1, 2];
  while (rounds.length < size) {
    final n = rounds.length * 2;
    final next = <int>[];
    for (final s in rounds) {
      next.add(s);
      next.add(n + 1 - s);
    }
    rounds = next;
  }
  return rounds;
}

/// Result of planning a bracket: the match specs plus how seeds map to entrants
/// (so the RPC can persist the assigned seed numbers).
class BracketPlan {
  final List<BracketMatchSpec> matches;
  /// entrantId → assigned 1-based seed.
  final Map<String, int> seeds;
  const BracketPlan({required this.matches, required this.seeds});
}

/// Build a single-elimination plan for [entrantIds] in seed order
/// (entrantIds[0] is seed 1, etc.). Byes go to the top seeds; bye winners are
/// pre-advanced into the next round.
BracketPlan buildSingleElimination(List<String> entrantIds,
    {int startIdx = 0, BracketType bracketType = BracketType.winners}) {
  final n = entrantIds.length;
  if (n < 2) {
    throw ArgumentError('Need at least 2 entrants to build a bracket');
  }
  final size = nextPowerOfTwo(n);
  final order = seedOrder(size); // length size, seed numbers per slot
  final seeds = <String, int>{
    for (var i = 0; i < n; i++) entrantIds[i]: i + 1,
  };

  // Slot → entrantId (null = bye/phantom seed).
  String? entrantForSeed(int seed) => seed <= n ? entrantIds[seed - 1] : null;
  final slotEntrant = order.map(entrantForSeed).toList();

  final rounds = <List<BracketMatchSpec>>[];
  var idx = startIdx;

  // Round 1.
  final round1 = <BracketMatchSpec>[];
  for (var m = 0; m < size ~/ 2; m++) {
    final a = slotEntrant[2 * m];
    final b = slotEntrant[2 * m + 1];
    final isBye = a == null || b == null;
    round1.add(BracketMatchSpec(
      idx: idx++,
      bracketType: bracketType,
      roundNumber: 1,
      matchNumber: m + 1,
      entrant1Id: a,
      entrant2Id: b,
      winnerEntrantId: isBye ? (a ?? b) : null,
      status: isBye ? MatchStatus.bye : MatchStatus.scheduled,
    ));
  }
  rounds.add(round1);

  // Subsequent rounds (empty entrants initially).
  var prevCount = size ~/ 2;
  var roundNum = 2;
  while (prevCount > 1) {
    final count = prevCount ~/ 2;
    final list = <BracketMatchSpec>[];
    for (var m = 0; m < count; m++) {
      list.add(BracketMatchSpec(
        idx: idx++,
        bracketType: bracketType,
        roundNumber: roundNum,
        matchNumber: m + 1,
        status: MatchStatus.pending,
      ));
    }
    rounds.add(list);
    prevCount = count;
    roundNum++;
  }

  // Flatten to a mutable working list keyed by idx for wiring.
  final all = <BracketMatchSpec>[for (final r in rounds) ...r];
  final byIdx = {for (final m in all) m.idx: m};

  // Wire next_match: round r match m → round r+1 match m~/2, slot (m%2)+1.
  // Rebuild specs with next-match references and bye pre-advancement.
  final entrant1Override = <int, String?>{};
  final entrant2Override = <int, String?>{};
  final statusOverride = <int, MatchStatus>{};
  final nextIdxOf = <int, int>{};
  final nextSlotOf = <int, int>{};

  for (var r = 0; r < rounds.length - 1; r++) {
    final cur = rounds[r];
    final nxt = rounds[r + 1];
    for (var m = 0; m < cur.length; m++) {
      final spec = cur[m];
      final target = nxt[m ~/ 2];
      final slot = (m % 2) + 1;
      nextIdxOf[spec.idx] = target.idx;
      nextSlotOf[spec.idx] = slot;
      // Pre-advance bye winners into the next match's slot.
      if (spec.status == MatchStatus.bye && spec.winnerEntrantId != null) {
        if (slot == 1) {
          entrant1Override[target.idx] = spec.winnerEntrantId;
        } else {
          entrant2Override[target.idx] = spec.winnerEntrantId;
        }
      }
    }
  }

  // A next-round match with BOTH entrants now filled (two byes feeding it) is a
  // real scheduled match, not pending.
  for (final m in all) {
    final e1 = entrant1Override.containsKey(m.idx)
        ? entrant1Override[m.idx]
        : m.entrant1Id;
    final e2 = entrant2Override.containsKey(m.idx)
        ? entrant2Override[m.idx]
        : m.entrant2Id;
    if (m.status == MatchStatus.pending && e1 != null && e2 != null) {
      statusOverride[m.idx] = MatchStatus.scheduled;
    }
  }

  final result = byIdx.values.map((m) {
    return BracketMatchSpec(
      idx: m.idx,
      bracketType: m.bracketType,
      roundNumber: m.roundNumber,
      matchNumber: m.matchNumber,
      poolId: m.poolId,
      entrant1Id: entrant1Override.containsKey(m.idx)
          ? entrant1Override[m.idx]
          : m.entrant1Id,
      entrant2Id: entrant2Override.containsKey(m.idx)
          ? entrant2Override[m.idx]
          : m.entrant2Id,
      winnerEntrantId: m.winnerEntrantId,
      status: statusOverride[m.idx] ?? m.status,
      nextMatchIdx: nextIdxOf[m.idx],
      nextMatchSlot: nextSlotOf[m.idx],
    );
  }).toList()
    ..sort((a, b) => a.idx.compareTo(b.idx));

  return BracketPlan(matches: result, seeds: seeds);
}

/// Build a round-robin plan (circle method). Every entrant plays every other
/// once; no next-match wiring. [poolId] tags pool matches in pools→playoff.
List<BracketMatchSpec> buildRoundRobin(
  List<String> entrantIds, {
  int startIdx = 0,
  BracketType bracketType = BracketType.winners,
  String? poolId,
}) {
  if (entrantIds.length < 2) {
    throw ArgumentError('Need at least 2 entrants for round robin');
  }
  final players = List<String?>.from(entrantIds);
  if (players.length.isOdd) players.add(null); // bye placeholder
  final m = players.length;
  final rounds = m - 1;
  final half = m ~/ 2;

  final specs = <BracketMatchSpec>[];
  var idx = startIdx;
  var arr = List<String?>.from(players);
  for (var r = 0; r < rounds; r++) {
    var matchNum = 1;
    for (var i = 0; i < half; i++) {
      final a = arr[i];
      final b = arr[m - 1 - i];
      if (a != null && b != null) {
        specs.add(BracketMatchSpec(
          idx: idx++,
          bracketType: bracketType,
          roundNumber: r + 1,
          matchNumber: matchNum++,
          poolId: poolId,
          entrant1Id: a,
          entrant2Id: b,
          status: MatchStatus.scheduled,
        ));
      }
    }
    // Rotate: fix arr[0], move last to front of the rotating tail.
    arr = [arr[0], arr[m - 1], ...arr.sublist(1, m - 1)];
  }
  return specs;
}

/// Snake (serpentine) distribution of seeded entrants into [poolCount] pools so
/// the top seeds spread across pools. Returns a list of pools (each a list of
/// entrant ids), pool 0 = "A", etc.
List<List<String>> distributeIntoPools(List<String> seededIds, int poolCount) {
  assert(poolCount >= 1);
  final pools = List.generate(poolCount, (_) => <String>[]);
  var row = 0;
  for (var i = 0; i < seededIds.length; i++) {
    final col = row.isEven ? i % poolCount : poolCount - 1 - (i % poolCount);
    pools[col].add(seededIds[i]);
    if ((i + 1) % poolCount == 0) row++;
  }
  return pools;
}

/// Pool label for a 0-based pool index: 0→A, 1→B, ...
String poolLabel(int index) => String.fromCharCode(65 + index);

/// Build the pool-stage matches for a pools→playoff division. The playoff
/// bracket is generated later (after pools finish), once finishers are known.
BracketPlan buildPoolsStage(List<String> entrantIds, int poolCount) {
  if (entrantIds.length < 2) {
    throw ArgumentError('Need at least 2 entrants');
  }
  final seeds = <String, int>{
    for (var i = 0; i < entrantIds.length; i++) entrantIds[i]: i + 1,
  };
  final pools = distributeIntoPools(entrantIds, poolCount);
  final matches = <BracketMatchSpec>[];
  var idx = 0;
  for (var p = 0; p < pools.length; p++) {
    if (pools[p].length < 2) continue;
    final poolMatches = buildRoundRobin(
      pools[p],
      startIdx: idx,
      bracketType: BracketType.pool,
      poolId: poolLabel(p),
    );
    matches.addAll(poolMatches);
    idx += poolMatches.length;
  }
  return BracketPlan(matches: matches, seeds: seeds);
}

/// Whether every pool match in [poolMatches] has been completed (so the
/// playoff bracket can be seeded).
bool poolsComplete(List<TournamentMatch> poolMatches) =>
    poolMatches.isNotEmpty &&
    poolMatches.every((m) => m.status == MatchStatus.completed);

/// After pool play completes, seed a single-elimination playoff from the pool
/// standings. Qualifiers are the top [advancePerPool] of each pool, ordered by
/// finish rank then pool (so pool winners are the top seeds); the canonical
/// seeding then cross-places them (A1 vs B2, B1 vs A2, …). Returns a winners
/// bracket. Throws if fewer than 2 qualifiers.
BracketPlan buildPlayoffFromPools(
  List<TournamentEntrant> entrants,
  List<TournamentMatch> poolMatches,
  int advancePerPool,
) {
  final poolIds = poolMatches
      .map((m) => m.poolId)
      .whereType<String>()
      .toSet()
      .toList()
    ..sort();

  // pool → its standings (already ranked).
  final perPool = <String, List<StandingRow>>{
    for (final p in poolIds)
      p: computeStandings(entrants, poolMatches, poolId: p),
  };

  // Interleave by rank: [A1, B1, …, A2, B2, …].
  final seeded = <String>[];
  for (var rank = 1; rank <= advancePerPool; rank++) {
    for (final p in poolIds) {
      final rows = perPool[p]!;
      if (rows.length >= rank) seeded.add(rows[rank - 1].entrantId);
    }
  }

  if (seeded.length < 2) {
    throw ArgumentError('Not enough qualifiers for a playoff');
  }
  return buildSingleElimination(seeded, bracketType: BracketType.winners);
}

/// Hard ceiling on generated matches (mirrors the server guard). Prevents a
/// round-robin of thousands (O(N²) = millions of rows) from being built/sent.
const int kMaxBracketMatches = 4096;

/// Estimate the match count a division+entrant-count would generate, without
/// materializing the plan — used to fail fast before building a huge list.
int estimateMatchCount(TournamentDivision division, int n) {
  if (n < 2) return 0;
  switch (division.format) {
    case DivisionFormat.singleElimination:
      return nextPowerOfTwo(n) - 1;
    case DivisionFormat.roundRobin:
      return n * (n - 1) ~/ 2;
    case DivisionFormat.poolsPlayoff:
      final pools = distributeIntoPools(
          List.generate(n, (i) => '$i'), division.poolCount ?? 2);
      var total = 0;
      for (final p in pools) {
        total += p.length * (p.length - 1) ~/ 2;
      }
      final qualifiers = (division.poolCount ?? 2) * (division.advancePerPool ?? 2);
      if (qualifiers >= 2) total += nextPowerOfTwo(qualifiers) - 1;
      return total;
    case DivisionFormat.custom:
      return 0;
  }
}

/// Build the full plan for a division based on its format. Caller passes
/// entrant ids already in seed order. For team divisions every match is marked
/// as a tie (the server builds its sub-matches). Throws [TooManyMatchesError]
/// if the configuration would exceed [kMaxBracketMatches].
BracketPlan buildBracketPlan(TournamentDivision division, List<String> seededIds) {
  if (estimateMatchCount(division, seededIds.length) > kMaxBracketMatches) {
    throw TooManyMatchesError(estimateMatchCount(division, seededIds.length));
  }
  final BracketPlan plan;
  switch (division.format) {
    case DivisionFormat.singleElimination:
      plan = buildSingleElimination(seededIds);
    case DivisionFormat.roundRobin:
      plan = BracketPlan(
        matches: buildRoundRobin(seededIds),
        seeds: {for (var i = 0; i < seededIds.length; i++) seededIds[i]: i + 1},
      );
    case DivisionFormat.poolsPlayoff:
      plan = buildPoolsStage(seededIds, division.poolCount ?? 2);
    case DivisionFormat.custom:
      // Manual builder — no auto-generated plan; organizer adds matches by hand.
      return const BracketPlan(matches: [], seeds: {});
  }
  if (division.entrantKind == EntrantKind.team) {
    return BracketPlan(
      matches: plan.matches.map((m) => m.asTie()).toList(),
      seeds: plan.seeds,
    );
  }
  return plan;
}

/// Pair two teams' rosters into tie sub-matches by the [rule].
/// `same_rank`: roster position i of each team, up to [submatchCount].
/// `manual`: [submatchCount] unpaired slots (organizer assigns players).
/// Players are passed in roster order (rank 1 first). Returns a list of
/// (position, side1PlayerId?, side2PlayerId?).
List<({int position, String? side1, String? side2})> pairSubmatches(
  List<String> teamAPlayerIds,
  List<String> teamBPlayerIds,
  TieConfig tieConfig,
) {
  final n = tieConfig.submatchCount;
  if (tieConfig.pairingRule == PairingRule.manual) {
    return [for (var i = 0; i < n; i++) (position: i + 1, side1: null, side2: null)];
  }
  final pairs = <({int position, String? side1, String? side2})>[];
  final limit = [n, teamAPlayerIds.length, teamBPlayerIds.length]
      .reduce((a, b) => a < b ? a : b);
  for (var i = 0; i < limit; i++) {
    pairs.add((position: i + 1, side1: teamAPlayerIds[i], side2: teamBPlayerIds[i]));
  }
  return pairs;
}
