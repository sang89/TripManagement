import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../models/event.dart';
import '../../models/tournament.dart';
import '../../providers/event_provider.dart';
import '../../responsive/responsive_modal.dart';
import '../../utils/bracket_math.dart';
import '../../utils/scoring_rules.dart';
import '../../utils/tournament_standings.dart';
import 'live_elapsed_timer.dart';
import 'tournament_labels.dart';

const _kMatchEmojis = [
  '⚡', '🔥', '🥊', '🏆', '⚔️', '🎯', '💥', '🌪️', '🎮', '🏅', '💪', '🤺',
];

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
                  : () => showResponsiveModal<void>(
                        context: context,
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
    return LayoutBuilder(builder: (ctx, constraints) {
      final wide = constraints.maxWidth >= 900;
      final listView = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _StandingsTable(standings: standings, byId: byId),
          const SizedBox(height: 20),
          const _SectionLabel('Matches'),
          ..._matchTiles(context, matches, byId, division, isOrganizer),
        ],
      );
      if (!wide) return listView;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: listView,
        ),
      );
    });
  }
}

// ── Single elimination: proper bracket tree ──────────────────────────────────
// Matches are absolutely positioned so each round's match sits centered between
// its two feeders; elbow connector lines join them (CustomPainter). The whole
// canvas is pinch-zoom/pannable (InteractiveViewer), like Challonge/Toornament.

const double _kCardW = 190;
const double _kCardH = 66;
const double _kColGap = 46; // horizontal room for connector elbows
const double _kRowGap = 30;
const double _kLabelH = 38;

/// Vertical centre of match [i] in round [r] (rounds halve each step, so a
/// match is centred between the pair of feeders below it). Geometry comes from
/// the unit-tested [bracketCenterSlots].
double _bracketCenterY(int r, int i, double slotH) =>
    _kLabelH + bracketCenterSlots(r, i) * slotH;

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
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final isWide = w >= 900;
      final colGap = isWide ? 56.0 : _kColGap;
      final rowGap = isWide ? 36.0 : _kRowGap;

      // Dynamically fill ~88% of available width on desktop so the bracket
      // expands naturally rather than sitting in a small fixed-size island.
      final nRounds = roundNums.length;
      final double cardW;
      if (isWide && nRounds > 0) {
        final target = (w * 0.88 / nRounds) - colGap;
        cardW = target.clamp(200.0, 400.0);
      } else {
        cardW = _kCardW;
      }
      final cardH = isWide ? 76.0 : _kCardH;
      final colW = cardW + colGap;
      final slotH = cardH + rowGap;
      final firstCount = rounds[roundNums.first]!.length;
      final totalW = nRounds * colW;
      final totalH = _kLabelH + firstCount * slotH + 16;

      final children = <Widget>[
        // Connector lines behind the cards.
        Positioned.fill(
          child: CustomPaint(
            painter: _BracketLinesPainter(
              counts: [for (final r in roundNums) rounds[r]!.length],
              lineColor: cs.primary.withValues(alpha: 0.28),
              cardW: cardW,
              colW: colW,
              slotH: slotH,
            ),
          ),
        ),
      ];

      for (var ri = 0; ri < nRounds; ri++) {
        final list = rounds[roundNums[ri]]!;
        // Round label pill.
        final isFinal = nRounds - ri - 1 == 0;
        children.add(Positioned(
          left: ri * colW,
          top: 6,
          width: cardW,
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isFinal
                    ? AppTheme.primary.withValues(alpha: 0.13)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFinal)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.emoji_events_rounded,
                          size: 12, color: AppTheme.primary),
                    ),
                  Text(
                    _roundName(ri, nRounds),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFinal ? AppTheme.primary : cs.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
        for (var i = 0; i < list.length; i++) {
          children.add(Positioned(
            left: ri * colW,
            top: _bracketCenterY(ri, i, slotH) - cardH / 2,
            width: cardW,
            height: cardH,
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
    });
  }
}

/// Draws right-angle "elbow" connectors from each match to the next-round match
/// it feeds (match i in round r → match i~/2 in round r+1).
class _BracketLinesPainter extends CustomPainter {
  final List<int> counts; // matches per round
  final Color lineColor;
  final double cardW;
  final double colW;
  final double slotH;
  const _BracketLinesPainter({
    required this.counts,
    required this.lineColor,
    required this.cardW,
    required this.colW,
    required this.slotH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var r = 0; r < counts.length - 1; r++) {
      for (var i = 0; i < counts[r]; i++) {
        final fromX = r * colW + cardW;
        final fromY = _bracketCenterY(r, i, slotH);
        final toX = (r + 1) * colW;
        final toY = _bracketCenterY(r + 1, i ~/ 2, slotH);
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
      old.counts != counts || old.lineColor != lineColor ||
      old.cardW != cardW || old.colW != colW || old.slotH != slotH;
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
    final showScore = match.isTie
        ? match.submatches.any((s) => s.isCompleted)
        : match.games.isNotEmpty;
    final canScore = isOrganizer &&
        match.entrant1Id != null &&
        match.entrant2Id != null &&
        !match.isBye &&
        !match.isWalkover;

    Court? court;
    for (final c in context.watch<EventProvider>().courtsFor(division.eventId)) {
      if (c.id == match.courtId) {
        court = c;
        break;
      }
    }

    final win1 = winner != null && winner == match.entrant1Id;
    final win2 = winner != null && winner == match.entrant2Id;
    final isLive = match.status == MatchStatus.inProgress;

    final borderColor = match.isWalkover
        ? Colors.grey.withValues(alpha: 0.6)
        : match.isCompleted
            ? AppTheme.primary.withValues(alpha: 0.55)
            : isLive
                ? Colors.orange.shade300
                : cs.outlineVariant;
    final borderWidth = (match.isCompleted || match.isWalkover || isLive) ? 1.5 : 1.0;

    // Per-game point scores for each player as a list, e.g. [21, 18].
    List<int> gameScores(int side) => match.games
        .map((g) => side == 1 ? g.entrant1Score : g.entrant2Score)
        .toList();

    Widget playerRow(String name, bool isWin, List<int> scores) {
      final isMuted = name == 'TBD' || name == 'Bye';
      return Expanded(
        child: Container(
          color: isWin ? AppTheme.primary.withValues(alpha: 0.08) : null,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                if (isWin && match.isDecided) ...[
                  Icon(Icons.emoji_events_rounded,
                      size: 12, color: AppTheme.primary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isWin ? FontWeight.w700 : FontWeight.w400,
                      color: isMuted
                          ? cs.onSurfaceVariant
                          : isWin
                              ? AppTheme.primary
                              : cs.onSurface,
                      fontStyle: isMuted ? FontStyle.italic : null,
                    ),
                  ),
                ),
                if (showScore && scores.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final s in scores) ...[
                        const SizedBox(width: 3),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isWin
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$s',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isWin
                                  ? AppTheme.primary
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final card = Material(
      elevation: isLive ? 3 : 1.5,
      shadowColor: AppTheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      color: cs.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          children: [
            playerRow(e1, win1, gameScores(1)),
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            playerRow(e2, win2, gameScores(2)),
          ],
        ),
      ),
    );

    // Label row above the card: court name (left) + status/time (right).
    final hasLabel = court != null || match.scheduledAt != null ||
        match.isLive || match.isWalkover;

    return AppTappable(
      onTap: canScore ? () => _showMatchActions(context, court) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (hasLabel)
            Positioned(
              left: 0,
              right: 0,
              top: -16,
              child: Row(
                children: [
                  if (court != null)
                    Text(
                      court.name,
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  if (match.isWalkover)
                    const Text(
                      'W/O',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontWeight: FontWeight.w700),
                    )
                  else if (match.isLive)
                    LiveElapsedTimer(
                      startedAt: match.startedAt!,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (match.scheduledAt != null)
                    Text(
                      '🕐 ${TimeOfDay.fromDateTime(match.scheduledAt!.toLocal()).format(context)}',
                      style: const TextStyle(fontSize: 9, color: Colors.orange),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showMatchActions(BuildContext context, Court? court) async {
    final e1Name = _entrantLabel(match.entrant1Id, byId, bye: match.isBye);
    final e2Name = _entrantLabel(match.entrant2Id, byId, bye: match.isBye);
    final win1 = match.isDecided && match.winnerEntrantId == match.entrant1Id;
    final win2 = match.isDecided && match.winnerEntrantId == match.entrant2Id;

    final action = await showResponsiveModal<String>(
      context: context,
      maxWidth: 640,
      maxHeight: 800,
      builder: (sheet) {
        final cs = Theme.of(sheet).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // Round / match meta + status badge
              Row(
                children: [
                  Text(
                    'Round ${match.roundNumber}  ·  Match ${match.matchNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  if (match.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    )
                  else if (match.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Side-by-side matchup with winner highlight
              // Both columns always reserve the same 26px trophy slot so
              // the names stay vertically aligned whether or not there's a winner.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 26,
                          child: win1
                              ? const Text('🏆',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18))
                              : null,
                        ),
                        Text(
                          e1Name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: win1
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: win1
                                ? AppTheme.primary
                                : win2
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 26),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          _kMatchEmojis[
                              match.id.hashCode.abs() % _kMatchEmojis.length],
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 26,
                          child: win2
                              ? const Text('🏆',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18))
                              : null,
                        ),
                        Text(
                          e2Name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: win2
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: win2
                                ? AppTheme.primary
                                : win1
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Per-game score breakdown with per-game winner coloring
              if (match.games.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < match.games.length; i++) ...[
                      if (i > 0)
                        Text('  ·  ',
                            style: TextStyle(
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                                fontSize: 12)),
                      () {
                        final g = match.games[i];
                        final e1Wins = g.entrant1Score > g.entrant2Score;
                        return RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${g.entrant1Score}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: e1Wins
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: e1Wins
                                      ? AppTheme.primary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              TextSpan(
                                text: '–',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                              ),
                              TextSpan(
                                text: '${g.entrant2Score}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: e1Wins
                                      ? FontWeight.w500
                                      : FontWeight.w800,
                                  color: e1Wins
                                      ? cs.onSurfaceVariant
                                      : AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Divider(
                  color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
              const SizedBox(height: 12),
              _MatchActionTile(
                icon: Icons.scoreboard_outlined,
                iconColor: Colors.blue,
                label: match.isTie
                    ? 'Score sub-matches'
                    : (match.isCompleted ? 'Edit score' : 'Enter score'),
                onTap: () => Navigator.pop(sheet, 'score'),
              ),
              if (match.isReady && match.startedAt == null) ...[
                _MatchActionTile(
                  icon: Icons.schedule_outlined,
                  iconColor: Colors.orange,
                  label: match.scheduledAt != null
                      ? 'Edit schedule'
                      : 'Set schedule',
                  subtitle: match.scheduledAt != null
                      ? TimeOfDay.fromDateTime(match.scheduledAt!.toLocal())
                          .format(sheet)
                      : null,
                  onTap: () => Navigator.pop(sheet, 'schedule'),
                ),
                if (!match.isTie)
                  _MatchActionTile(
                    icon: Icons.play_circle_outline_rounded,
                    iconColor: Colors.green,
                    label: 'Start match',
                    onTap: () => Navigator.pop(sheet, 'start'),
                  ),
              ],
              if (match.isLive)
                _MatchActionTile(
                  icon: Icons.stop_circle_outlined,
                  iconColor: Colors.red.shade700,
                  label: 'Stop match',
                  subtitle: 'Reset to scheduled',
                  onTap: () => Navigator.pop(sheet, 'stop'),
                ),
              if (match.isReady && !match.isDecided)
                _MatchActionTile(
                  icon: Icons.person_off_outlined,
                  iconColor: Colors.red,
                  label: 'Declare walkover',
                  subtitle: 'No-show or forfeit',
                  onTap: () => Navigator.pop(sheet, 'walkover'),
                ),
              if (court == null && !match.isDecided)
                _MatchActionTile(
                  icon: Icons.stadium_outlined,
                  iconColor: Colors.purple,
                  label: 'Assign to court',
                  onTap: () => Navigator.pop(sheet, 'assign'),
                )
              else if (court != null)
                _MatchActionTile(
                  icon: Icons.location_off_outlined,
                  iconColor: Colors.grey,
                  label: 'Remove from ${court.name}',
                  onTap: () => Navigator.pop(sheet, 'unassign'),
                ),
            ],
          ),
        );
      },
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
    } else if (action == 'schedule') {
      await _showScheduleSheet(context);
    } else if (action == 'start') {
      try {
        await context.read<EventProvider>().startMatch(match);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().contains('match_already_started')
                ? 'Match is already in progress.'
                : 'Could not start the match.'),
          ));
        }
      }
    } else if (action == 'stop') {
      try {
        await context.read<EventProvider>().stopMatch(match);
      } catch (e) {
        if (context.mounted) {
          final msg = e.toString().contains('match_not_in_progress')
              ? 'Match is not currently in progress.'
              : 'Could not stop the match.';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } else if (action == 'walkover') {
      await _showWalkovers(context);
    }
  }

  Future<void> _showWalkovers(BuildContext context) =>
      _showWalkoversForMatch(context, match, byId);

  Future<void> _showScheduleSheet(BuildContext context) async {
    final localNow = DateTime.now().toLocal();
    final eventStartAt = context
        .read<EventProvider>()
        .getById(division.eventId)
        ?.startAt
        .toLocal();
    DateTime? pickedDate = match.scheduledAt?.toLocal() ??
        (eventStartAt != null
            ? DateTime(eventStartAt.year, eventStartAt.month, eventStartAt.day)
            : null);
    TimeOfDay? pickedTime = match.scheduledAt != null
        ? TimeOfDay.fromDateTime(match.scheduledAt!.toLocal())
        : null;
    int? pickedMinutes = match.estimatedDurationMinutes;

    await showResponsiveModal<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (ctx, setSS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Schedule Match',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text(pickedDate != null
                    ? '${pickedDate!.month}/${pickedDate!.day}/${pickedDate!.year}'
                    : 'Tap to set date'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: pickedDate ?? localNow,
                    firstDate: localNow.subtract(const Duration(days: 1)),
                    lastDate: localNow.add(const Duration(days: 365)),
                  );
                  if (d != null) setSS(() => pickedDate = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded),
                title: Text(pickedTime != null
                    ? pickedTime!.format(ctx)
                    : 'Tap to set start time'),
                onTap: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: pickedTime ?? TimeOfDay.now(),
                  );
                  if (t != null) setSS(() => pickedTime = t);
                },
              ),
              const SizedBox(height: 8),
              const Text('Estimated duration',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60, 90].map((min) {
                  final selected = pickedMinutes == min;
                  return ChoiceChip(
                    label: Text('${min}m'),
                    selected: selected,
                    onSelected: (_) =>
                        setSS(() => pickedMinutes = selected ? null : min),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (match.scheduledAt != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(sheet);
                          if (!ctx.mounted) return;
                          await ctx.read<EventProvider>().scheduleMatch(
                                match,
                                scheduledAt: null,
                                estimatedDurationMinutes: null,
                              );
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                  if (match.scheduledAt != null) const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: 'Save',
                      onPressed: (pickedDate == null || pickedTime == null)
                          ? null
                          : () async {
                              Navigator.pop(sheet);
                              if (!ctx.mounted) return;
                              final d = pickedDate!;
                              final dt = DateTime(
                                d.year,
                                d.month,
                                d.day,
                                pickedTime!.hour,
                                pickedTime!.minute,
                              );
                              await ctx.read<EventProvider>().scheduleMatch(
                                    match,
                                    scheduledAt: dt,
                                    estimatedDurationMinutes: pickedMinutes,
                                  );
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

    return LayoutBuilder(builder: (ctx, constraints) {
      final wide = constraints.maxWidth >= 900;
      final listView = ListView(
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
      if (!wide) return listView;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: listView,
        ),
      );
    });
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
  await showResponsiveModal<void>(
    context: context,
    maxWidth: 640,
    maxHeight: 800,
    builder: (_) => _MatchScoreSheet(match: match, division: division, byId: byId),
  );
}

Future<void> _openTieSheet(
    BuildContext context, TournamentMatch match, TournamentDivision division,
    Map<String, TournamentEntrant> byId) async {
  await showResponsiveModal<void>(
    context: context,
    maxWidth: 640,
    maxHeight: 800,
    builder: (_) => _TieSheet(tieId: match.id, division: division, byId: byId),
  );
}

/// Shows a court picker and assigns [match] to the chosen court.
Future<void> _pickAndAssignCourt(
    BuildContext context, TournamentMatch match, TournamentDivision division) async {
  // Fetch fresh court data so status reflects the current DB state.
  await context.read<EventProvider>().fetchCourts(division.eventId);
  if (!context.mounted) return;

  final courts = context.read<EventProvider>().courtsFor(division.eventId);
  if (courts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add courts in the Courts tab first.')),
    );
    return;
  }
  final court = await showResponsiveModal<Court>(
    context: context,
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
              children: courts.map((c) {
                final available = c.status == CourtStatus.available;
                return ListTile(
                  leading: Icon(
                    Icons.sports_tennis_rounded,
                    color: available ? null : Colors.grey,
                  ),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      color: available ? null : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    c.status.label,
                    style: TextStyle(
                      color: available
                          ? Colors.green.shade600
                          : Colors.red.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  enabled: available,
                  onTap: available ? () => Navigator.pop(sheet, c) : null,
                );
              }).toList(),
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
  } catch (e) {
    if (context.mounted) {
      final raw = e.toString();
      final msg = raw.contains('match_not_ready')
          ? 'Match isn\'t ready yet — both teams need to be known.'
          : raw.contains('match_not_assignable')
              ? 'This match is already decided and cannot be assigned to a court.'
              : raw.contains('not_authorized')
                  ? 'Only the event organizer can assign courts.'
                  : raw.contains('court_event_mismatch')
                      ? 'Court does not belong to this event.'
                      : 'Could not assign the court.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

String _entrantLabel(String? id, Map<String, TournamentEntrant> byId,
    {required bool bye}) {
  if (id != null) return byId[id]?.teamName ?? 'Unknown';
  return bye ? 'Bye' : 'TBD';
}

Future<void> _showWalkoversForMatch(BuildContext context, TournamentMatch match,
    Map<String, TournamentEntrant> byId) async {
  final e1 = _entrantLabel(match.entrant1Id, byId, bye: false);
  final e2 = _entrantLabel(match.entrant2Id, byId, bye: false);
  final winnerId = await showResponsiveModal<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Who wins by walkover?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
                'The other team forfeits or did not show up.',
                style: TextStyle(fontSize: 13)),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_rounded, color: AppTheme.primary),
            title: Text(e1),
            subtitle: const Text('Wins by walkover'),
            onTap: () => Navigator.pop(sheet, match.entrant1Id),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_rounded, color: AppTheme.primary),
            title: Text(e2),
            subtitle: const Text('Wins by walkover'),
            onTap: () => Navigator.pop(sheet, match.entrant2Id),
          ),
        ],
      ),
    ),
  );
  if (winnerId == null || !context.mounted) return;
  await context.read<EventProvider>().awardWalkover(match, winnerId);
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
    // Organizer can score a match once both teams are known and it's not a bye or walkover.
    final canScore = isOrganizer &&
        match.entrant1Id != null &&
        match.entrant2Id != null &&
        !match.isBye &&
        !match.isWalkover;
    final courts = context.watch<EventProvider>().courtsFor(division.eventId);
    Court? assignedCourt;
    for (final c in courts) {
      if (c.id == match.courtId) {
        assignedCourt = c;
        break;
      }
    }
    final canAssign = canScore && !match.isDecided && courts.isNotEmpty;

    final win1 = winner != null && winner == match.entrant1Id;
    final win2 = winner != null && winner == match.entrant2Id;
    final isLive = match.status == MatchStatus.inProgress;
    final borderColor = match.isWalkover
        ? Colors.grey.withValues(alpha: 0.6)
        : match.isCompleted
            ? AppTheme.primary.withValues(alpha: 0.5)
            : isLive
                ? Colors.orange.shade300
                : cs.outlineVariant;

    Widget playerRow(String name, String? score, bool isWin) {
      final isMuted = name == 'TBD' || name == 'Bye';
      return Container(
        color: isWin ? AppTheme.primary.withValues(alpha: 0.07) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (isWin && match.isDecided) ...[
              Icon(Icons.emoji_events_rounded,
                  size: 14, color: AppTheme.primary),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isWin ? FontWeight.w700 : FontWeight.w400,
                  color: isMuted
                      ? cs.onSurfaceVariant
                      : isWin
                          ? AppTheme.primary
                          : null,
                  fontStyle: isMuted ? FontStyle.italic : null,
                ),
              ),
            ),
            if (score != null) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isWin ? AppTheme.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  score,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isWin ? Colors.white : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isLive ? 3 : 1,
      shadowColor: AppTheme.primary.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: borderColor,
          width: (match.isDecided || isLive) ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          playerRow(e1, showScore ? '$g1' : null, win1),
          Divider(height: 1, color: cs.outlineVariant),
          playerRow(e2, showScore ? '$g2' : null, win2),
          if (assignedCourt != null || canAssign || canScore ||
              match.scheduledAt != null || match.isLive || match.isWalkover) ...[
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  if (match.isLive) ...[
                    LiveElapsedTimer(
                      startedAt: match.startedAt!,
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                  ] else if (match.scheduledAt != null && !match.isDecided) ...[
                    const Icon(Icons.schedule_rounded, size: 12,
                        color: Colors.orange),
                    const SizedBox(width: 3),
                    Text(
                      TimeOfDay.fromDateTime(match.scheduledAt!.toLocal())
                          .format(context),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.orange),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (assignedCourt != null) ...[
                    Icon(Icons.place_rounded,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text(assignedCourt.name,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ] else if (canAssign)
                    AppTappable(
                      onTap: () => _assignCourt(context, courts),
                      child: Text('Assign court',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.primary)),
                    ),
                  const Spacer(),
                  if (match.isWalkover)
                    const Text('W/O',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w700)),
                  if (canScore) ...[
                    if (match.isReady) ...[
                      AppTappable(
                        onTap: () =>
                            _showWalkoversForMatch(context, match, byId),
                        child: const Text('Walkover',
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: match.isDecided
                            ? cs.surfaceContainerHighest
                            : AppTheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        match.isTie
                            ? 'Sub-matches'
                            : (match.isDecided ? 'Edit score' : 'Enter score'),
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
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
    final court = await showResponsiveModal<Court>(
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
            rows: shown.map((s) {
                  final medal = s.rank == 1
                      ? '🥇'
                      : s.rank == 2
                          ? '🥈'
                          : s.rank == 3
                              ? '🥉'
                              : null;
                  final isTop = s.rank <= 3;
                  return DataRow(
                    color: WidgetStateProperty.resolveWith((_) => s.rank == 1
                        ? Colors.amber.withValues(alpha: 0.06)
                        : null),
                    cells: [
                      DataCell(medal != null
                          ? Text(medal,
                              style: const TextStyle(fontSize: 16))
                          : Text('${s.rank}',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant))),
                      DataCell(Text(byId[s.entrantId]?.teamName ?? '—',
                          style: TextStyle(
                              fontWeight: isTop ? FontWeight.w700 : null))),
                      DataCell(Text('${s.won}',
                          style: TextStyle(
                              fontWeight: isTop ? FontWeight.w700 : null,
                              color: isTop ? Colors.green.shade700 : null))),
                      DataCell(Text('${s.lost}')),
                      DataCell(Text(_signed(s.gameDiff))),
                      DataCell(Text(_signed(s.pointDiff))),
                    ],
                  );
                }).toList(),
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
  final Set<int> _lockedGames = {}; // indices of locked game rows
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
      // Pre-lock any already-complete games loaded from DB.
      for (var i = 0; i < _games.length; i++) {
        if (ScoringRules.isGameComplete(_cfg, _games[i][0], _games[i][1])) {
          _lockedGames.add(i);
        }
      }
    } else {
      _games = [
        [0, 0]
      ];
    }
  }

  void _toggleLock(int i) => setState(() {
        if (_lockedGames.contains(i)) {
          _lockedGames.remove(i);
        } else {
          _lockedGames.add(i);
        }
      });

  List<(int, int)> get _tuples =>
      _games.map((g) => (g[0], g[1])).toList();

  int get _winnerSide => ScoringRules.matchWinner(_cfg, _tuples);

  bool get _canAddGame =>
      _games.length < _cfg.bestOf && _winnerSide == 0;

  Future<void> _save() async {
    // Send any game where scores differ (handles retirements mid-game).
    // The RPC rejects equal scores and requires a decisive winner by game count.
    final games = _tuples.where((g) => g.$1 != g.$2).toList();
    if (games.isEmpty) {
      setState(() => _error = 'No scores entered yet.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<EventProvider>().recordMatchScore(widget.match, games);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.contains('no_decisive_winner')
          ? 'Games are tied — adjust scores so one player leads overall.'
          : 'Could not save the score. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final e1 = _entrantLabel(widget.match.entrant1Id, widget.byId, bye: false);
    final e2 = _entrantLabel(widget.match.entrant2Id, widget.byId, bye: false);
    final tally = ScoringRules.gameTally(_cfg, _tuples);
    final winnerName = _winnerSide == 1 ? e1 : (_winnerSide == 2 ? e2 : null);
    final emoji = _kMatchEmojis[
        widget.match.id.hashCode.abs() % _kMatchEmojis.length];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$emoji  Match Score',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Best of ${_cfg.bestOf} · First to ${_cfg.pointsToWin} pts',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // Column headers: player names
          Row(
            children: [
              Expanded(
                child: Text(e1,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.onSurface)),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Text(e2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < _games.length; i++)
                    _GameScoreRow(
                      gameNumber: i + 1,
                      score1: _games[i][0],
                      score2: _games[i][1],
                      complete: ScoringRules.isGameComplete(
                          _cfg, _games[i][0], _games[i][1]),
                      won1: _winnerSide == 0
                          ? false
                          : _games[i][0] > _games[i][1],
                      won2: _winnerSide == 0
                          ? false
                          : _games[i][1] > _games[i][0],
                      isLocked: _lockedGames.contains(i),
                      onToggleLock: _games[i][0] != _games[i][1] ||
                              _lockedGames.contains(i)
                          ? () => _toggleLock(i)
                          : null,
                      onChanged: _lockedGames.contains(i)
                          ? null
                          : (s1, s2) => setState(() => _games[i] = [s1, s2]),
                      onRemove: (_games.length > 1 &&
                              !_lockedGames.contains(i))
                          ? () => setState(() {
                                _games.removeAt(i);
                                _lockedGames.remove(i);
                              })
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
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: winnerName != null
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              winnerName != null
                  ? '🏅 Winner: $winnerName  (${tally.$1}–${tally.$2})'
                  : 'Games: ${tally.$1}–${tally.$2}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color:
                    winnerName != null ? AppTheme.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Save Result',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _GameScoreRow extends StatelessWidget {
  final int gameNumber;
  final int score1;
  final int score2;
  final bool complete;
  final bool won1;
  final bool won2;
  final bool isLocked;
  final VoidCallback? onToggleLock;
  final void Function(int s1, int s2)? onChanged;
  final VoidCallback? onRemove;

  const _GameScoreRow({
    required this.gameNumber,
    required this.score1,
    required this.score2,
    required this.complete,
    required this.won1,
    required this.won2,
    required this.isLocked,
    required this.onChanged,
    this.onToggleLock,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'GAME $gameNumber',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            // Lock / unlock button
            if (onToggleLock != null)
              AppTappable(
                onTap: onToggleLock,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.green.withValues(alpha: 0.12)
                        : cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLocked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 12,
                        color: isLocked
                            ? Colors.green.shade700
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLocked ? 'Locked' : 'Lock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isLocked
                              ? Colors.green.shade700
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!isLocked && onRemove != null)
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 16, color: cs.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _TappableScore(
                value: score1,
                isWinner: won1,
                isLocked: isLocked,
                onChanged: onChanged != null ? (v) => onChanged!(v, score2) : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('–',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: cs.onSurfaceVariant)),
            ),
            Expanded(
              child: _TappableScore(
                value: score2,
                isWinner: won2,
                isLocked: isLocked,
                onChanged: onChanged != null ? (v) => onChanged!(score1, v) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TappableScore extends StatelessWidget {
  final int value;
  final bool isWinner;
  final bool isLocked;
  final ValueChanged<int>? onChanged;

  const _TappableScore({
    required this.value,
    required this.isWinner,
    required this.isLocked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppTappable(
      onTap: onChanged == null
          ? null
          : () async {
              final result = await showDialog<int>(
                context: context,
                builder: (_) => _ScoreInputDialog(initialValue: value),
              );
              if (result != null) onChanged!(result);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isLocked
              ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
              : isWinner
                  ? AppTheme.primary.withValues(alpha: 0.1)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: isLocked
              ? Border.all(
                  color: Colors.green.withValues(alpha: 0.3), width: 1.5)
              : isWinner
                  ? Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      width: 1.5)
                  : null,
        ),
        child: Column(
          children: [
            Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: isLocked
                    ? cs.onSurface.withValues(alpha: 0.45)
                    : isWinner
                        ? AppTheme.primary
                        : cs.onSurface,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            if (isLocked)
              Icon(Icons.lock_rounded,
                  size: 14,
                  color: Colors.green.shade600)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SmallStepBtn(
                    icon: Icons.remove_rounded,
                    onPressed: (onChanged != null && value > 0)
                        ? () => onChanged!(value - 1)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  _SmallStepBtn(
                    icon: Icons.add_rounded,
                    onPressed:
                        onChanged != null ? () => onChanged!(value + 1) : null,
                  ),
                ],
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SmallStepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _SmallStepBtn({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppTappable(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(
              alpha: onPressed != null ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: onPressed != null
                ? cs.onSurface
                : cs.onSurface.withValues(alpha: 0.25)),
      ),
    );
  }
}

class _ScoreInputDialog extends StatefulWidget {
  final int initialValue;
  const _ScoreInputDialog({required this.initialValue});

  @override
  State<_ScoreInputDialog> createState() => _ScoreInputDialogState();
}

class _ScoreInputDialogState extends State<_ScoreInputDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.initialValue == 0 ? '' : '${widget.initialValue}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = int.tryParse(_ctrl.text);
    if (v != null && v >= 0) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter score',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        textAlign: TextAlign.center,
        style:
            const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
        decoration: const InputDecoration(
          hintText: '0',
          border: OutlineInputBorder(),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Set'),
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
            '${tie.isDecided ? "  ·  winner: ${byId[tie.winnerEntrantId]?.teamName ?? ""}" : ""}',
            style: TextStyle(
                fontSize: 12,
                color: tie.isDecided ? AppTheme.primary : Theme.of(context).hintColor),
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
                      tieIsDecided: tie.isDecided,
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
  final bool tieIsDecided;
  final List<EntrantPlayer> teamARoster;
  final List<EntrantPlayer> teamBRoster;
  const _SubmatchRow({
    required this.submatch,
    required this.division,
    required this.side1Name,
    required this.side2Name,
    required this.isManual,
    required this.tieIsDecided,
    required this.teamARoster,
    required this.teamBRoster,
  });

  Future<void> _assign(BuildContext context, int side) async {
    final roster = side == 1 ? teamARoster : teamBRoster;
    final picked = await showResponsiveModal<EntrantPlayer>(
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
    final canScore = submatch.isReady && !tieIsDecided;

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
                  onTap: () => showResponsiveModal<void>(
                    context: context,
                    maxWidth: 640,
                    maxHeight: 800,
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
  final Set<int> _lockedGames = {};
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
    for (var i = 0; i < _games.length; i++) {
      if (ScoringRules.isGameComplete(_cfg, _games[i][0], _games[i][1])) {
        _lockedGames.add(i);
      }
    }
  }

  void _toggleLock(int i) => setState(() {
        if (_lockedGames.contains(i)) {
          _lockedGames.remove(i);
        } else {
          _lockedGames.add(i);
        }
      });

  List<(int, int)> get _tuples => _games.map((g) => (g[0], g[1])).toList();
  int get _winnerSide => ScoringRules.matchWinner(_cfg, _tuples);

  bool get _canAddGame =>
      _games.length < _cfg.bestOf && _winnerSide == 0;

  Future<void> _save() async {
    final games = _tuples.where((g) => g.$1 != g.$2).toList();
    if (games.isEmpty) {
      setState(() => _error = 'No scores entered yet.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context
          .read<EventProvider>()
          .recordSubmatchScore(widget.submatch.id, widget.division.id, games);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.contains('no_decisive_winner')
          ? 'Scores are tied — adjust so one player leads overall.'
          : 'Could not save the score. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final tally = ScoringRules.gameTally(_cfg, _tuples);
    final winnerName = _winnerSide == 1
        ? widget.side1Name
        : (_winnerSide == 2 ? widget.side2Name : null);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('⚔️  Sub-match Score',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('Best of ${_cfg.bestOf} · First to ${_cfg.pointsToWin} pts',
              style:
                  TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(widget.side1Name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.onSurface)),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Text(widget.side2Name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < _games.length; i++)
                    _GameScoreRow(
                      gameNumber: i + 1,
                      score1: _games[i][0],
                      score2: _games[i][1],
                      complete: ScoringRules.isGameComplete(
                          _cfg, _games[i][0], _games[i][1]),
                      won1: _winnerSide == 0
                          ? false
                          : _games[i][0] > _games[i][1],
                      won2: _winnerSide == 0
                          ? false
                          : _games[i][1] > _games[i][0],
                      isLocked: _lockedGames.contains(i),
                      onToggleLock: _games[i][0] != _games[i][1] ||
                              _lockedGames.contains(i)
                          ? () => _toggleLock(i)
                          : null,
                      onChanged: _lockedGames.contains(i)
                          ? null
                          : (s1, s2) => setState(() => _games[i] = [s1, s2]),
                      onRemove: (_games.length > 1 &&
                              !_lockedGames.contains(i))
                          ? () => setState(() {
                                _games.removeAt(i);
                                _lockedGames.remove(i);
                              })
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
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: winnerName != null
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              winnerName != null
                  ? '🏅 Winner: $winnerName  (${tally.$1}–${tally.$2})'
                  : 'Games: ${tally.$1}–${tally.$2}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: winnerName != null
                    ? AppTheme.primary
                    : cs.onSurfaceVariant,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Save Result',
            loading: _saving,
            onPressed: _save,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
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

class _MatchActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _MatchActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppTappable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
