import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../models/event.dart';
import '../../models/tournament.dart';
import '../../providers/event_provider.dart';
import '../../utils/bracket_math.dart';
import '../../utils/scoring_rules.dart';
import '../../utils/tournament_standings.dart';
import 'tournament_labels.dart';

/// Bracket / standings view for a tournament division. Picks a division, then
/// renders a round-robin standings table + match list, a single-elimination
/// tree, or pools (standings per pool) depending on the format.
class TournamentBracketView extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  const TournamentBracketView({
    super.key,
    required this.event,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<TournamentBracketView> createState() => _TournamentBracketViewState();
}

class _TournamentBracketViewState extends State<TournamentBracketView> {
  String? _selectedDivisionId;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchDivisions(widget.event.id);
    });
  }

  void _ensureLoaded(String divisionId) {
    final p = context.read<EventProvider>();
    if (p.entrantsFor(divisionId).isEmpty) p.fetchEntrants(divisionId);
    if (p.matchesFor(divisionId).isEmpty) p.fetchMatches(divisionId);
  }

  Future<void> _generate(TournamentDivision division) async {
    setState(() => _generating = true);
    try {
      await context.read<EventProvider>().generateBracket(division);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('at least 2')) return 'Add at least 2 teams first.';
    if (s.contains('already_generated')) return 'Bracket already generated.';
    if (s.contains('TooManyMatches') || s.contains('bracket_too_large')) {
      return 'Too many teams for this format — use Pools → Playoffs to split a large field.';
    }
    return 'Could not generate the bracket. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EventProvider>();
    final divisions = p.divisionsFor(widget.event.id);
    if (divisions.isEmpty) {
      return const _Empty(
        icon: Icons.emoji_events_outlined,
        message: 'Add a division and register teams, then generate its bracket.',
      );
    }
    final division = divisions.firstWhere(
      (d) => d.id == _selectedDivisionId,
      orElse: () => divisions.first,
    );
    _ensureLoaded(division.id);
    final entrants = p.activeEntrantsFor(division.id);
    final matches = p.matchesFor(division.id);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: AppPickerField<TournamentDivision>(
            label: 'Division',
            value: division,
            items: divisions,
            labelOf: (d) => d.name,
            onChanged: (d) => setState(() => _selectedDivisionId = d.id),
          ),
        ),
        Expanded(
          child: division.format == DivisionFormat.custom
              ? _ManualBuilder(
                  division: division,
                  entrants: entrants,
                  matches: matches,
                  isOrganizer: widget.isOrganizer,
                )
              : !division.bracketGenerated
                  ? _GenerateCta(
                      division: division,
                      entrantCount: entrants.length,
                      isOrganizer: widget.isOrganizer,
                      generating: _generating,
                      onGenerate: () => _generate(division),
                    )
                  : _BracketBody(
                      division: division,
                      entrants: entrants,
                      matches: matches,
                      isOrganizer: widget.isOrganizer,
                    ),
        ),
      ],
    );
  }
}

class _GenerateCta extends StatelessWidget {
  final TournamentDivision division;
  final int entrantCount;
  final bool isOrganizer;
  final bool generating;
  final VoidCallback onGenerate;
  const _GenerateCta({
    required this.division,
    required this.entrantCount,
    required this.isOrganizer,
    required this.generating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canGenerate = entrantCount >= 2;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              '${division.format.label} · $entrantCount teams',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isOrganizer
                  ? (canGenerate
                      ? 'Generate the bracket to lock registration and create the matches.'
                      : 'Register at least 2 teams to generate the bracket.')
                  : 'The organizer hasn\'t generated this bracket yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
            if (isOrganizer) ...[
              const SizedBox(height: 20),
              AppButton(
                label: 'Generate Bracket',
                loading: generating,
                onPressed: canGenerate ? onGenerate : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BracketBody extends StatelessWidget {
  final TournamentDivision division;
  final List<TournamentEntrant> entrants;
  final List<TournamentMatch> matches;
  final bool isOrganizer;
  const _BracketBody({
    required this.division,
    required this.entrants,
    required this.matches,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    switch (division.format) {
      case DivisionFormat.roundRobin:
        return _RoundRobinView(
            division: division,
            entrants: entrants,
            matches: matches,
            isOrganizer: isOrganizer);
      case DivisionFormat.singleElimination:
        return _EliminationTree(
            division: division,
            entrants: entrants,
            matches: matches
                .where((m) => m.bracketType == BracketType.winners)
                .toList(),
            isOrganizer: isOrganizer);
      case DivisionFormat.poolsPlayoff:
        return _PoolsView(
            division: division,
            entrants: entrants,
            matches: matches,
            isOrganizer: isOrganizer);
      case DivisionFormat.custom:
        // Manual builder is added in M8; placeholder until then.
        return const _Empty(
          icon: Icons.build_outlined,
          message: 'Custom (manual) builder coming soon.',
        );
    }
  }
}

// ── Manual builder (custom-format divisions) ─────────────────────────────────

class _ManualBuilder extends StatelessWidget {
  final TournamentDivision division;
  final List<TournamentEntrant> entrants;
  final List<TournamentMatch> matches;
  final bool isOrganizer;
  const _ManualBuilder({
    required this.division,
    required this.entrants,
    required this.matches,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final e in entrants) e.id: e};
    final rounds = <int, List<TournamentMatch>>{};
    for (final m in matches) {
      (rounds[m.roundNumber] ??= []).add(m);
    }
    final roundNums = rounds.keys.toList()..sort();

    return Stack(
      children: [
        if (matches.isEmpty)
          const _Empty(
            icon: Icons.build_outlined,
            message:
                'Custom (manual) division.\nAdd matches round by round — pick the two sides yourself.',
          )
        else
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final r in roundNums) ...[
                _SectionLabel('Round $r'),
                const SizedBox(height: 8),
                ...(rounds[r]!
                      ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber)))
                    .map((m) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _MatchCard(
                                match: m,
                                byId: byId,
                                division: division,
                                isOrganizer: isOrganizer,
                              ),
                            ),
                            if (isOrganizer)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => context
                                    .read<EventProvider>()
                                    .deleteManualMatch(m.id, division.id),
                              ),
                          ],
                        )),
                const SizedBox(height: 12),
              ],
            ],
          ),
        if (isOrganizer)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: entrants.isEmpty
                  ? null
                  : () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => _AddManualMatchSheet(
                          division: division,
                          entrants: entrants,
                          nextRound: roundNums.isEmpty ? 1 : roundNums.last,
                        ),
                      ),
              icon: const Icon(Icons.add),
              label: Text(division.entrantKind == EntrantKind.team
                  ? 'Add tie'
                  : 'Add match'),
            ),
          ),
      ],
    );
  }
}

class _AddManualMatchSheet extends StatefulWidget {
  final TournamentDivision division;
  final List<TournamentEntrant> entrants;
  final int nextRound;
  const _AddManualMatchSheet({
    required this.division,
    required this.entrants,
    required this.nextRound,
  });

  @override
  State<_AddManualMatchSheet> createState() => _AddManualMatchSheetState();
}

class _AddManualMatchSheetState extends State<_AddManualMatchSheet> {
  late int _round;
  TournamentEntrant? _a;
  TournamentEntrant? _b;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _round = widget.nextRound;
  }

  Future<void> _save() async {
    if (_a == null || _b == null || _a!.id == _b!.id) {
      setState(() => _error = 'Pick two different sides.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<EventProvider>().addManualMatch(
            divisionId: widget.division.id,
            roundNumber: _round,
            entrant1Id: _a!.id,
            entrant2Id: _b!.id,
            isTie: widget.division.entrantKind == EntrantKind.team,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Could not add the match. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isTeam = widget.division.entrantKind == EntrantKind.team;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isTeam ? 'Add tie' : 'Add match',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('Round '),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed:
                            _round > 1 ? () => setState(() => _round--) : null,
                      ),
                      Text('$_round',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => _round++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppPickerField<TournamentEntrant>(
                    label: 'Side A',
                    value: _a,
                    hint: 'Pick…',
                    items: widget.entrants,
                    labelOf: (e) => e.teamName,
                    onChanged: (v) => setState(() => _a = v),
                  ),
                  const SizedBox(height: 12),
                  AppPickerField<TournamentEntrant>(
                    label: 'Side B',
                    value: _b,
                    hint: 'Pick…',
                    items: widget.entrants,
                    labelOf: (e) => e.teamName,
                    onChanged: (v) => setState(() => _b = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
              label: isTeam ? 'Add tie' : 'Add match',
              onPressed: _save,
              loading: _saving),
        ],
      ),
    );
  }
}

// ── Round-robin: standings + match list ──────────────────────────────────────

class _RoundRobinView extends StatelessWidget {
  final TournamentDivision division;
  final List<TournamentEntrant> entrants;
  final List<TournamentMatch> matches;
  final bool isOrganizer;
  const _RoundRobinView({
    required this.division,
    required this.entrants,
    required this.matches,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final e in entrants) e.id: e};
    final standings = computeStandings(entrants, matches);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _StandingsTable(standings: standings, byId: byId),
        const SizedBox(height: 20),
        const _SectionLabel('Matches'),
        ..._matchTiles(context, matches, byId, division, isOrganizer),
      ],
    );
  }
}

// ── Single elimination: proper bracket tree ──────────────────────────────────
// Matches are absolutely positioned so each round's match sits centered between
// its two feeders; elbow connector lines join them (CustomPainter). The whole
// canvas is pinch-zoom/pannable (InteractiveViewer), like Challonge/Toornament.

const double _kCardW = 190;
const double _kCardH = 58;
const double _kColGap = 46; // horizontal room for connector elbows
const double _kRowGap = 30;
const double _kLabelH = 30;
double get _kColW => _kCardW + _kColGap;
double get _kSlotH => _kCardH + _kRowGap;

/// Vertical centre of match [i] in round [r] (rounds halve each step, so a
/// match is centred between the pair of feeders below it).
double _bracketCenterY(int r, int i) =>
    _kLabelH + (i + 0.5) * (1 << r) * _kSlotH;

String _roundName(int r, int total) {
  final fromEnd = total - r - 1;
  if (fromEnd == 0) return 'Final';
  if (fromEnd == 1) return 'Semifinals';
  if (fromEnd == 2) return 'Quarterfinals';
  return 'Round ${r + 1}';
}

class _EliminationTree extends StatelessWidget {
  final TournamentDivision division;
  final List<TournamentEntrant> entrants;
  final List<TournamentMatch> matches;
  final bool isOrganizer;
  const _EliminationTree({
    required this.division,
    required this.entrants,
    required this.matches,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final e in entrants) e.id: e};
    final rounds = <int, List<TournamentMatch>>{};
    for (final m in matches) {
      (rounds[m.roundNumber] ??= []).add(m);
    }
    final roundNums = rounds.keys.toList()..sort();
    if (roundNums.isEmpty) {
      return const _Empty(
          icon: Icons.account_tree_outlined, message: 'No matches.');
    }
    for (final r in roundNums) {
      rounds[r]!.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    }

    final nRounds = roundNums.length;
    final firstCount = rounds[roundNums.first]!.length;
    final totalW = nRounds * _kColW;
    final totalH = _kLabelH + firstCount * _kSlotH + 16;
    final cs = Theme.of(context).colorScheme;

    final children = <Widget>[
      // Connector lines behind the cards.
      Positioned.fill(
        child: CustomPaint(
          painter: _BracketLinesPainter(
            counts: [for (final r in roundNums) rounds[r]!.length],
            lineColor: cs.outlineVariant,
          ),
        ),
      ),
    ];

    for (var ri = 0; ri < nRounds; ri++) {
      final list = rounds[roundNums[ri]]!;
      // Round label.
      children.add(Positioned(
        left: ri * _kColW,
        top: 4,
        width: _kCardW,
        child: Text(
          _roundName(ri, nRounds),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3),
        ),
      ));
      for (var i = 0; i < list.length; i++) {
        children.add(Positioned(
          left: ri * _kColW,
          top: _bracketCenterY(ri, i) - _kCardH / 2,
          width: _kCardW,
          height: _kCardH,
          child: _TreeMatchCard(
            match: list[i],
            byId: byId,
            division: division,
            isOrganizer: isOrganizer,
          ),
        ));
      }
    }

    // Two-axis scrolling: drag right to reach later rounds (the Final), down
    // for tall first rounds. Plain scroll is more discoverable than pan/zoom.
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
        child: SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(children: children),
        ),
      ),
    );
  }
}

/// Draws right-angle "elbow" connectors from each match to the next-round match
/// it feeds (match i in round r → match i~/2 in round r+1).
class _BracketLinesPainter extends CustomPainter {
  final List<int> counts; // matches per round
  final Color lineColor;
  const _BracketLinesPainter({required this.counts, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var r = 0; r < counts.length - 1; r++) {
      for (var i = 0; i < counts[r]; i++) {
        final fromX = r * _kColW + _kCardW;
        final fromY = _bracketCenterY(r, i);
        final toX = (r + 1) * _kColW;
        final toY = _bracketCenterY(r + 1, i ~/ 2);
        final midX = (fromX + toX) / 2;
        final path = Path()
          ..moveTo(fromX, fromY)
          ..lineTo(midX, fromY)
          ..lineTo(midX, toY)
          ..lineTo(toX, toY);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BracketLinesPainter old) =>
      old.counts != counts || old.lineColor != lineColor;
}

/// Compact fixed-height match box for the bracket tree.
class _TreeMatchCard extends StatelessWidget {
  final TournamentMatch match;
  final Map<String, TournamentEntrant> byId;
  final TournamentDivision division;
  final bool isOrganizer;
  const _TreeMatchCard({
    required this.match,
    required this.byId,
    required this.division,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e1 = _entrantLabel(match.entrant1Id, byId, bye: match.isBye);
    final e2 = _entrantLabel(match.entrant2Id, byId, bye: match.isBye);
    final winner = match.winnerEntrantId;
    final g1 = match.isTie
        ? match.submatches.where((s) => s.winnerSide == 1).length
        : match.games.where((g) => g.entrant1Score > g.entrant2Score).length;
    final g2 = match.isTie
        ? match.submatches.where((s) => s.winnerSide == 2).length
        : match.games.where((g) => g.entrant2Score > g.entrant1Score).length;
    final showScore = match.isTie
        ? match.submatches.any((s) => s.isCompleted)
        : match.games.isNotEmpty;
    final canScore = isOrganizer &&
        match.entrant1Id != null &&
        match.entrant2Id != null &&
        !match.isBye;

    Court? court;
    for (final c in context.watch<EventProvider>().courtsFor(division.eventId)) {
      if (c.id == match.courtId) {
        court = c;
        break;
      }
    }

    Widget row(String name, int gw, bool win, bool top) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: win ? FontWeight.w700 : FontWeight.w400,
                        color: win
                            ? AppTheme.primary
                            : (name == 'TBD' || name == 'Bye'
                                ? cs.onSurfaceVariant
                                : null),
                      )),
                ),
                if (showScore)
                  Text('$gw',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              win ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
        );

    final card = Material(
      elevation: 0.5,
      borderRadius: BorderRadius.circular(8),
      color: cs.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            row(e1, g1, winner != null && winner == match.entrant1Id, true),
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            row(e2, g2, winner != null && winner == match.entrant2Id, false),
          ],
        ),
      ),
    );

    return AppTappable(
      onTap: canScore
          ? () => match.isTie
              ? _openTieSheet(context, match, division, byId)
              : _openScoreSheet(context, match, division, byId)
          : null,
      onLongPress: canScore
          ? () => _showMatchActions(context, court)
          : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (court != null)
            Positioned(
              left: -4,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showMatchActions(BuildContext context, Court? court) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.scoreboard_outlined),
              title: Text(match.isTie
                  ? 'Score sub-matches'
                  : (match.isCompleted ? 'Edit score' : 'Enter score')),
              onTap: () => Navigator.pop(sheet, 'score'),
            ),
            if (court == null)
              ListTile(
                leading: const Icon(Icons.stadium_outlined),
                title: const Text('Assign to court'),
                onTap: () => Navigator.pop(sheet, 'assign'),
              )
            else
              ListTile(
                leading: const Icon(Icons.location_off_outlined),
                title: Text('Remove from ${court.name}'),
                onTap: () => Navigator.pop(sheet, 'unassign'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'score') {
      match.isTie
          ? _openTieSheet(context, match, division, byId)
          : _openScoreSheet(context, match, division, byId);
    } else if (action == 'assign') {
      await _pickAndAssignCourt(context, match, division);
    } else if (action == 'unassign') {
      await context
          .read<EventProvider>()
          .unassignMatchFromCourt(match, division.eventId);
    }
  }
}

// ── Pools → playoffs ─────────────────────────────────────────────────────────

class _PoolsView extends StatelessWidget {
  final TournamentDivision division;
  final List<TournamentEntrant> entrants;
  final List<TournamentMatch> matches;
  final bool isOrganizer;
  const _PoolsView({
    required this.division,
    required this.entrants,
    required this.matches,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final e in entrants) e.id: e};
    final poolMatches =
        matches.where((m) => m.bracketType == BracketType.pool).toList();
    final pools = poolMatches.map((m) => m.poolId).whereType<String>().toSet().toList()
      ..sort();
    final playoff =
        matches.where((m) => m.bracketType == BracketType.winners).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final pool in pools) ...[
          _SectionLabel('Pool $pool'),
          const SizedBox(height: 8),
          _StandingsTable(
            standings: computeStandings(entrants, poolMatches, poolId: pool),
            byId: byId,
          ),
          const SizedBox(height: 8),
          ..._matchTiles(
              context,
              poolMatches.where((m) => m.poolId == pool).toList(),
              byId,
              division,
              isOrganizer),
          const SizedBox(height: 20),
        ],
        if (playoff.isNotEmpty) ...[
          const _SectionLabel('Playoffs'),
          const SizedBox(height: 8),
          ..._matchTiles(context, playoff, byId, division, isOrganizer),
        ] else
          _PlayoffSeeder(
            division: division,
            poolMatches: poolMatches,
            isOrganizer: isOrganizer,
          ),
      ],
    );
  }
}

class _PlayoffSeeder extends StatefulWidget {
  final TournamentDivision division;
  final List<TournamentMatch> poolMatches;
  final bool isOrganizer;
  const _PlayoffSeeder({
    required this.division,
    required this.poolMatches,
    required this.isOrganizer,
  });

  @override
  State<_PlayoffSeeder> createState() => _PlayoffSeederState();
}

class _PlayoffSeederState extends State<_PlayoffSeeder> {
  bool _seeding = false;

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      await context.read<EventProvider>().seedPlayoffs(widget.division);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not seed the playoffs.')),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ready = poolsComplete(widget.poolMatches);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Playoffs'),
        const SizedBox(height: 8),
        Text(
          ready
              ? 'Pool play is complete. Seed the playoff bracket from the standings.'
              : 'Playoffs will be seeded from the standings once all pool matches are played.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        if (widget.isOrganizer && ready) ...[
          const SizedBox(height: 12),
          AppButton(
            label: 'Generate Playoffs',
            loading: _seeding,
            onPressed: _seed,
          ),
        ],
      ],
    );
  }
}

// ── Shared pieces ────────────────────────────────────────────────────────────

List<Widget> _matchTiles(
  BuildContext context,
  List<TournamentMatch> matches,
  Map<String, TournamentEntrant> byId,
  TournamentDivision division,
  bool isOrganizer,
) {
  final sorted = [...matches]
    ..sort((a, b) {
      final r = a.roundNumber.compareTo(b.roundNumber);
      return r != 0 ? r : a.matchNumber.compareTo(b.matchNumber);
    });
  return sorted
      .map((m) => _MatchCard(
            match: m,
            byId: byId,
            division: division,
            isOrganizer: isOrganizer,
          ))
      .toList();
}

Future<void> _openScoreSheet(
    BuildContext context, TournamentMatch match, TournamentDivision division,
    Map<String, TournamentEntrant> byId) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MatchScoreSheet(match: match, division: division, byId: byId),
  );
}

Future<void> _openTieSheet(
    BuildContext context, TournamentMatch match, TournamentDivision division,
    Map<String, TournamentEntrant> byId) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TieSheet(tieId: match.id, division: division, byId: byId),
  );
}

/// Shows a court picker and assigns [match] to the chosen court.
Future<void> _pickAndAssignCourt(
    BuildContext context, TournamentMatch match, TournamentDivision division) async {
  final courts = context.read<EventProvider>().courtsFor(division.eventId);
  if (courts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add courts in the Courts tab first.')),
    );
    return;
  }
  final court = await showModalBottomSheet<Court>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Assign to court',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: courts
                  .map((c) => ListTile(
                        leading: const Icon(Icons.sports_tennis_rounded),
                        title: Text(c.name),
                        subtitle: Text(c.status.label),
                        onTap: () => Navigator.pop(sheet, c),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    ),
  );
  if (court == null || !context.mounted) return;
  try {
    await context
        .read<EventProvider>()
        .assignMatchToCourt(match, court.id, division.eventId);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not assign the court.')),
      );
    }
  }
}

String _entrantLabel(String? id, Map<String, TournamentEntrant> byId,
    {required bool bye}) {
  if (id != null) return byId[id]?.teamName ?? 'Unknown';
  return bye ? 'Bye' : 'TBD';
}

class _MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final Map<String, TournamentEntrant> byId;
  final TournamentDivision division;
  final bool isOrganizer;
  const _MatchCard({
    required this.match,
    required this.byId,
    required this.division,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e1 = _entrantLabel(match.entrant1Id, byId, bye: match.isBye);
    final e2 = _entrantLabel(match.entrant2Id, byId, bye: match.isBye);
    final winner = match.winnerEntrantId;
    // For ties, the displayed score is the sub-match tally; otherwise games won.
    final g1 = match.isTie
        ? match.submatches.where((s) => s.winnerSide == 1).length
        : match.games.where((g) => g.entrant1Score > g.entrant2Score).length;
    final g2 = match.isTie
        ? match.submatches.where((s) => s.winnerSide == 2).length
        : match.games.where((g) => g.entrant2Score > g.entrant1Score).length;
    final showScore = match.isTie
        ? match.submatches.any((s) => s.isCompleted)
        : match.games.isNotEmpty;
    // Organizer can score a match once both teams are known and it's not a bye.
    final canScore = isOrganizer &&
        match.entrant1Id != null &&
        match.entrant2Id != null &&
        !match.isBye;
    final courts = context.watch<EventProvider>().courtsFor(division.eventId);
    Court? assignedCourt;
    for (final c in courts) {
      if (c.id == match.courtId) {
        assignedCourt = c;
        break;
      }
    }
    final canAssign = canScore && !match.isCompleted && courts.isNotEmpty;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            _row(context, e1, showScore ? '$g1' : null,
                highlight: winner != null && winner == match.entrant1Id),
            Divider(height: 10, color: cs.outlineVariant),
            _row(context, e2, showScore ? '$g2' : null,
                highlight: winner != null && winner == match.entrant2Id),
            if (assignedCourt != null || canAssign || canScore) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (assignedCourt != null) ...[
                    Icon(Icons.place, size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(assignedCourt.name,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ] else if (canAssign)
                    AppTappable(
                      onTap: () => _assignCourt(context, courts),
                      child: Text('Assign court',
                          style:
                              TextStyle(fontSize: 11, color: AppTheme.primary)),
                    ),
                  const Spacer(),
                  if (canScore)
                    Text(
                      match.isTie
                          ? 'Sub-matches'
                          : (match.isCompleted ? 'Edit score' : 'Enter score'),
                      style: TextStyle(fontSize: 11, color: AppTheme.primary),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (!canScore) return card;
    return AppTappable(
      onTap: () => match.isTie
          ? _openTieSheet(context, match, division, byId)
          : _openScoreSheet(context, match, division, byId),
      child: card,
    );
  }

  Future<void> _assignCourt(BuildContext context, List<Court> courts) async {
    final court = await showModalBottomSheet<Court>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Assign to court',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: courts
                      .map((c) => ListTile(
                            leading: const Icon(Icons.sports_tennis_rounded),
                            title: Text(c.name),
                            subtitle: Text(c.status.label),
                            onTap: () => Navigator.pop(context, c),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (court == null || !context.mounted) return;
    try {
      await context
          .read<EventProvider>()
          .assignMatchToCourt(match, court.id, division.eventId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not assign the court.')),
        );
      }
    }
  }

  Widget _row(BuildContext context, String name, String? score,
      {required bool highlight}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
              color: highlight ? AppTheme.primary : null,
            ),
          ),
        ),
        if (score != null)
          Text(score,
              style: TextStyle(
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w400)),
      ],
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<StandingRow> standings;
  final Map<String, TournamentEntrant> byId;
  const _StandingsTable({required this.standings, required this.byId});

  // Cap eagerly-built DataTable rows; standings beyond this are summarised.
  static const _maxRows = 100;

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const Text('No teams.');
    }
    final shown = standings.length > _maxRows
        ? standings.sublist(0, _maxRows)
        : standings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 44,
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Team')),
              DataColumn(label: Text('W'), numeric: true),
              DataColumn(label: Text('L'), numeric: true),
              DataColumn(label: Text('Game±'), numeric: true),
              DataColumn(label: Text('Pt±'), numeric: true),
            ],
            rows: shown
                .map((s) => DataRow(cells: [
                      DataCell(Text('${s.rank}')),
                      DataCell(Text(byId[s.entrantId]?.teamName ?? '—')),
                      DataCell(Text('${s.won}')),
                      DataCell(Text('${s.lost}')),
                      DataCell(Text(_signed(s.gameDiff))),
                      DataCell(Text(_signed(s.pointDiff))),
                    ]))
                .toList(),
          ),
        ),
        if (standings.length > _maxRows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing top $_maxRows of ${standings.length}.',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  String _signed(int v) => v > 0 ? '+$v' : '$v';
}

// ── Score entry sheet ────────────────────────────────────────────────────────

class _MatchScoreSheet extends StatefulWidget {
  final TournamentMatch match;
  final TournamentDivision division;
  final Map<String, TournamentEntrant> byId;
  const _MatchScoreSheet({
    required this.match,
    required this.division,
    required this.byId,
  });

  @override
  State<_MatchScoreSheet> createState() => _MatchScoreSheetState();
}

class _MatchScoreSheetState extends State<_MatchScoreSheet> {
  late List<List<int>> _games; // [ [s1, s2], ... ]
  bool _saving = false;
  String? _error;

  ScoringConfig get _cfg => widget.division.scoringConfig;

  @override
  void initState() {
    super.initState();
    if (widget.match.games.isNotEmpty) {
      _games = widget.match.games
          .map((g) => [g.entrant1Score, g.entrant2Score])
          .toList();
    } else {
      _games = [
        [0, 0]
      ];
    }
  }

  List<(int, int)> get _tuples =>
      _games.map((g) => (g[0], g[1])).toList();

  int get _winnerSide => ScoringRules.matchWinner(_cfg, _tuples);

  bool get _canAddGame {
    if (_games.length >= _cfg.bestOf) return false;
    // Allow adding the next game only once the current ones are decided and the
    // match isn't already won.
    return _winnerSide == 0 &&
        _games.every((g) => ScoringRules.isGameComplete(_cfg, g[0], g[1]));
  }

  Future<void> _save() async {
    if (_winnerSide == 0) {
      setState(() => _error = 'Enter a complete result (a team must win).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Only persist games that are complete.
      final games = _tuples
          .where((g) => ScoringRules.isGameComplete(_cfg, g.$1, g.$2))
          .toList();
      await context.read<EventProvider>().recordMatchScore(widget.match, games);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Could not save the score. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final e1 = _entrantLabel(widget.match.entrant1Id, widget.byId, bye: false);
    final e2 = _entrantLabel(widget.match.entrant2Id, widget.byId, bye: false);
    final tally = ScoringRules.gameTally(_cfg, _tuples);
    final winnerName =
        _winnerSide == 1 ? e1 : (_winnerSide == 2 ? e2 : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Match Score',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '$e1  vs  $e2 · best of ${_cfg.bestOf} to ${_cfg.pointsToWin}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < _games.length; i++)
                    _GameRow(
                      label: 'Game ${i + 1}',
                      score1: _games[i][0],
                      score2: _games[i][1],
                      complete: ScoringRules.isGameComplete(
                          _cfg, _games[i][0], _games[i][1]),
                      onChanged: (s1, s2) =>
                          setState(() => _games[i] = [s1, s2]),
                      onRemove: _games.length > 1
                          ? () => setState(() => _games.removeAt(i))
                          : null,
                    ),
                  if (_canAddGame)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _games.add([0, 0])),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add game'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            winnerName != null
                ? 'Winner: $winnerName  (${tally.$1}–${tally.$2})'
                : 'Games: ${tally.$1}–${tally.$2}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: winnerName != null ? AppTheme.primary : null,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: 'Save Result',
            loading: _saving,
            onPressed: _winnerSide != 0 ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  final String label;
  final int score1;
  final int score2;
  final bool complete;
  final void Function(int s1, int s2) onChanged;
  final VoidCallback? onRemove;
  const _GameRow({
    required this.label,
    required this.score1,
    required this.score2,
    required this.complete,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label)),
          Expanded(
            child: _Stepper(
              value: score1,
              onChanged: (v) => onChanged(v, score2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('–'),
          ),
          Expanded(
            child: _Stepper(
              value: score2,
              onChanged: (v) => onChanged(score1, v),
            ),
          ),
          SizedBox(
            width: 32,
            child: onRemove != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onRemove,
                  )
                : (complete
                    ? const Icon(Icons.check_circle, size: 18, color: Colors.green)
                    : const SizedBox()),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 22),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 22),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

// ── Tie sheet: a team tie's sub-matches ──────────────────────────────────────

class _TieSheet extends StatelessWidget {
  final String tieId;
  final TournamentDivision division;
  final Map<String, TournamentEntrant> byId;
  const _TieSheet({
    required this.tieId,
    required this.division,
    required this.byId,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EventProvider>();
    final matches = p.matchesFor(division.id);
    final tie = matches.where((m) => m.id == tieId).cast<TournamentMatch?>().firstWhere(
          (m) => m != null,
          orElse: () => null,
        );
    final entrants = p.entrantsFor(division.id);
    final playerById = <String, EntrantPlayer>{
      for (final e in entrants)
        for (final pl in e.players) pl.id: pl,
    };
    TournamentEntrant? entrantOf(String? id) {
      for (final e in entrants) {
        if (e.id == id) return e;
      }
      return null;
    }

    final bottom = MediaQuery.of(context).viewInsets.bottom;
    if (tie == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('Tie not found.'));
    }
    final teamA = entrantOf(tie.entrant1Id);
    final teamB = entrantOf(tie.entrant2Id);
    final tally1 = tie.submatches.where((s) => s.winnerSide == 1).length;
    final tally2 = tie.submatches.where((s) => s.winnerSide == 2).length;
    final isManual = division.tieConfig?.pairingRule == PairingRule.manual;

    String playerName(String? id) => id == null ? 'TBD' : (playerById[id]?.name ?? '—');

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${teamA?.teamName ?? "TBD"}  vs  ${teamB?.teamName ?? "TBD"}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            'Tie score: $tally1 – $tally2'
            '${tie.isCompleted ? "  ·  winner: ${byId[tie.winnerEntrantId]?.teamName ?? ""}" : ""}',
            style: TextStyle(
                fontSize: 12,
                color: tie.isCompleted ? AppTheme.primary : Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final s in tie.submatches)
                    _SubmatchRow(
                      submatch: s,
                      division: division,
                      side1Name: playerName(s.side1PlayerId),
                      side2Name: playerName(s.side2PlayerId),
                      isManual: isManual,
                      teamARoster: teamA?.players ?? const [],
                      teamBRoster: teamB?.players ?? const [],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmatchRow extends StatelessWidget {
  final TieSubmatch submatch;
  final TournamentDivision division;
  final String side1Name;
  final String side2Name;
  final bool isManual;
  final List<EntrantPlayer> teamARoster;
  final List<EntrantPlayer> teamBRoster;
  const _SubmatchRow({
    required this.submatch,
    required this.division,
    required this.side1Name,
    required this.side2Name,
    required this.isManual,
    required this.teamARoster,
    required this.teamBRoster,
  });

  Future<void> _assign(BuildContext context, int side) async {
    final roster = side == 1 ? teamARoster : teamBRoster;
    final picked = await showModalBottomSheet<EntrantPlayer>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: roster
                    .map((pl) => ListTile(
                          title: Text(pl.name),
                          subtitle: pl.playerRank != null
                              ? Text('Rank ${pl.playerRank}')
                              : null,
                          onTap: () => Navigator.pop(sheetContext, pl),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await context
        .read<EventProvider>()
        .setSubmatchPlayer(submatch.id, division.id, side, picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = submatch.winnerSide;
    final g1 = submatch.games.where((g) => g.side1 > g.side2).length;
    final g2 = submatch.games.where((g) => g.side2 > g.side1).length;
    final canScore = submatch.isReady;

    Widget side(int n, String name, int gw) {
      final isWinner = w == n;
      return Expanded(
        child: Row(
          children: [
            Expanded(
              child: name == 'TBD' && isManual
                  ? AppTappable(
                      onTap: () => _assign(context, n),
                      child: Text('Assign…',
                          style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                    )
                  : Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight:
                              isWinner ? FontWeight.w700 : FontWeight.w400,
                          color: isWinner ? AppTheme.primary : null)),
            ),
            if (submatch.isCompleted)
              Text('$gw',
                  style: TextStyle(
                      fontWeight: isWinner ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Match ${submatch.position}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),
            const SizedBox(height: 2),
            side(1, side1Name, g1),
            Divider(height: 10, color: cs.outlineVariant),
            side(2, side2Name, g2),
            if (canScore) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: AppTappable(
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _SubmatchScoreSheet(
                      submatch: submatch,
                      division: division,
                      side1Name: side1Name,
                      side2Name: side2Name,
                    ),
                  ),
                  child: Text(
                    submatch.isCompleted ? 'Edit score' : 'Enter score',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubmatchScoreSheet extends StatefulWidget {
  final TieSubmatch submatch;
  final TournamentDivision division;
  final String side1Name;
  final String side2Name;
  const _SubmatchScoreSheet({
    required this.submatch,
    required this.division,
    required this.side1Name,
    required this.side2Name,
  });

  @override
  State<_SubmatchScoreSheet> createState() => _SubmatchScoreSheetState();
}

class _SubmatchScoreSheetState extends State<_SubmatchScoreSheet> {
  late List<List<int>> _games;
  bool _saving = false;
  String? _error;

  ScoringConfig get _cfg => widget.division.scoringConfig;

  @override
  void initState() {
    super.initState();
    _games = widget.submatch.games.isNotEmpty
        ? widget.submatch.games.map((g) => [g.side1, g.side2]).toList()
        : [
            [0, 0]
          ];
  }

  List<(int, int)> get _tuples => _games.map((g) => (g[0], g[1])).toList();
  int get _winnerSide => ScoringRules.matchWinner(_cfg, _tuples);

  bool get _canAddGame =>
      _games.length < _cfg.bestOf &&
      _winnerSide == 0 &&
      _games.every((g) => ScoringRules.isGameComplete(_cfg, g[0], g[1]));

  Future<void> _save() async {
    if (_winnerSide == 0) {
      setState(() => _error = 'Enter a complete result (a player must win).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final games = _tuples
          .where((g) => ScoringRules.isGameComplete(_cfg, g.$1, g.$2))
          .toList();
      await context
          .read<EventProvider>()
          .recordSubmatchScore(widget.submatch.id, widget.division.id, games);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Could not save the score. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final tally = ScoringRules.gameTally(_cfg, _tuples);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.side1Name}  vs  ${widget.side2Name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('best of ${_cfg.bestOf} to ${_cfg.pointsToWin}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < _games.length; i++)
                    _GameRow(
                      label: 'Game ${i + 1}',
                      score1: _games[i][0],
                      score2: _games[i][1],
                      complete: ScoringRules.isGameComplete(
                          _cfg, _games[i][0], _games[i][1]),
                      onChanged: (s1, s2) =>
                          setState(() => _games[i] = [s1, s2]),
                      onRemove: _games.length > 1
                          ? () => setState(() => _games.removeAt(i))
                          : null,
                    ),
                  if (_canAddGame)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _games.add([0, 0])),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add game'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Games: ${tally.$1}–${tally.$2}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: 'Save Result',
            loading: _saving,
            onPressed: _winnerSide != 0 ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Empty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
