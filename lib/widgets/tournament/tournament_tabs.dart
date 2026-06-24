import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../models/event.dart';
import '../../models/event_guest.dart';
import '../../models/tournament.dart';
import '../../providers/event_provider.dart';
import 'bracket_builder_screen.dart';
import 'tournament_bracket_view.dart';
import 'tournament_labels.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Tournament Organize tabs (M2): Divisions, Entrants, Bracket, Courts.
//
// Secondary UI strings are hardcoded English, matching the existing signup /
// quick-bites tabs convention; the tab labels themselves are localized.
// ═══════════════════════════════════════════════════════════════════════════

// ── Divisions tab ────────────────────────────────────────────────────────────

class TournamentDivisionsTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  const TournamentDivisionsTab({
    super.key,
    required this.event,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<TournamentDivisionsTab> createState() => _TournamentDivisionsTabState();
}

class _TournamentDivisionsTabState extends State<TournamentDivisionsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchTournament(widget.event.id);
    });
  }

  Future<void> _addDivision() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DivisionFormSheet(eventId: widget.event.id),
    );
  }

  Future<void> _openBuilder() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BracketBuilderScreen(eventId: widget.event.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final divisions = context.watch<EventProvider>().divisionsFor(widget.event.id);
    return Scaffold(
      body: divisions.isEmpty
          ? (widget.isOrganizer
              ? _DivisionsFirstRunHint(
                  onAdd: _addDivision,
                  onBuildStructure: _openBuilder,
                )
              : const _EmptyState(
                  icon: Icons.account_tree_outlined,
                  message:
                      'No divisions yet.\nThe organizer hasn\'t set up any draws for this tournament.',
                ))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: divisions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _DivisionCard(
                division: divisions[i],
                isOrganizer: widget.isOrganizer,
              ),
            ),
      // Empty state uses the inline buttons; FABs appear once there are divisions.
      floatingActionButton: widget.isOrganizer && divisions.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_builder',
                  onPressed: _openBuilder,
                  tooltip: 'Build structure',
                  child: const Icon(Icons.account_tree_rounded),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'fab_add',
                  onPressed: _addDivision,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Division'),
                ),
              ],
            )
          : null,
    );
  }
}

/// First-run guidance shown to organizers when a tournament has no divisions
/// yet — explains the concept and offers two setup paths.
class _DivisionsFirstRunHint extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onBuildStructure;
  const _DivisionsFirstRunHint({
    required this.onAdd,
    required this.onBuildStructure,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_tree_rounded,
                  size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Set up your draws',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A division is one draw with its own format and bracket. '
              'Add divisions one at a time, or use Build Structure to create '
              'multiple draws at once by dragging entrants into groups.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onBuildStructure,
              icon: const Icon(Icons.account_tree_rounded),
              label: const Text('Build Structure'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Single Division'),
            ),
            const SizedBox(height: 16),
            Text(
              'See Info → Guide for the full walkthrough.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}


class _DivisionCard extends StatelessWidget {
  final TournamentDivision division;
  final bool isOrganizer;
  const _DivisionCard({required this.division, required this.isOrganizer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = division.matchCount == 0
        ? null
        : division.completedMatchCount / division.matchCount;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(sportIcon(division.sport), color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    division.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOrganizer)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') {
                        _confirmDelete(context, division);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (division.sport.isNotEmpty) _Chip(division.sport),
                _Chip(division.discipline.label),
                if (division.skillLevel.isNotEmpty)
                  _Chip(division.skillLevel),
                _Chip(division.format.label),
                _Chip('${division.entrantCount} teams'),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${division.completedMatchCount}/${division.matchCount} matches played',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, TournamentDivision division) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete division?'),
        content: Text(
            'This permanently removes "${division.name}", its teams, and any bracket.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context
        .read<EventProvider>()
        .deleteDivision(division.id, division.eventId);
  }
}

// ── Add/edit division sheet ──────────────────────────────────────────────────

class _DivisionFormSheet extends StatefulWidget {
  final String eventId;
  const _DivisionFormSheet({required this.eventId});

  @override
  State<_DivisionFormSheet> createState() => _DivisionFormSheetState();
}

class _DivisionFormSheetState extends State<_DivisionFormSheet> {
  final _nameCtrl = TextEditingController();
  final _sportCtrl = TextEditingController(text: 'Badminton');
  final _skillCtrl = TextEditingController();
  Discipline _discipline = Discipline.doubles;
  DivisionFormat _format = DivisionFormat.singleElimination;
  final _capCtrl = TextEditingController();
  final _poolCountCtrl = TextEditingController(text: '2');
  final _advanceCtrl = TextEditingController(text: '2');

  // Entrant kind: individual (1–2 players) or team (ranked roster of N).
  EntrantKind _entrantKind = EntrantKind.individual;
  final _rosterSizeCtrl = TextEditingController(text: '10');
  // Tie settings (team kind).
  final _submatchCountCtrl = TextEditingController(text: '3');
  final _winThresholdCtrl = TextEditingController(text: '2');
  PairingRule _pairingRule = PairingRule.sameRank;

  // Editable scoring rules.
  ScoringSystem _system = ScoringSystem.rally;
  final _pointsCtrl = TextEditingController(text: '21');
  final _capPointCtrl = TextEditingController(text: '30');
  bool _winByTwo = true;
  int _bestOf = 3;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sportCtrl.dispose();
    _skillCtrl.dispose();
    _capCtrl.dispose();
    _poolCountCtrl.dispose();
    _advanceCtrl.dispose();
    _pointsCtrl.dispose();
    _capPointCtrl.dispose();
    _rosterSizeCtrl.dispose();
    _submatchCountCtrl.dispose();
    _winThresholdCtrl.dispose();
    super.dispose();
  }

  bool get _isTeam => _entrantKind == EntrantKind.team;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchTemplates();
    });
  }

  /// Built-in starter templates (always available, alongside user-saved ones).
  List<TournamentTemplate> _builtInTemplates() {
    Map<String, dynamic> cfg(
      String sport,
      String discipline,
      String format, {
      String kind = 'individual',
      int? poolCount,
      int? advancePerPool,
      int? rosterSize,
      TieConfig? tie,
    }) =>
        {
          'sport': sport,
          'discipline': discipline,
          'skill_level': '',
          'format': format,
          'entrant_kind': kind,
          'scoring_config': ScoringConfig.defaultFor(sport).toJson(),
          'pool_count': ?poolCount,
          'advance_per_pool': ?advancePerPool,
          'roster_size': ?rosterSize,
          if (tie != null) 'tie_config': tie.toJson(),
        };
    return [
      TournamentTemplate(
          id: 'builtin:bad_singles_se',
          name: 'Badminton Singles — Knockout',
          config: cfg('Badminton', 'singles', 'single_elimination')),
      TournamentTemplate(
          id: 'builtin:bad_doubles_rr',
          name: 'Badminton Doubles — Round Robin',
          config: cfg('Badminton', 'doubles', 'round_robin')),
      TournamentTemplate(
          id: 'builtin:bad_doubles_pools',
          name: 'Badminton Doubles — Pools → Playoffs',
          config: cfg('Badminton', 'doubles', 'pools_playoff',
              poolCount: 4, advancePerPool: 2)),
      TournamentTemplate(
          id: 'builtin:pkl_dbl_rr',
          name: 'Pickleball Doubles — Round Robin',
          config: cfg('Pickleball', 'doubles', 'round_robin')),
      TournamentTemplate(
          id: 'builtin:pkl_dbl_pools',
          name: 'Pickleball Doubles — Pools → Playoffs',
          config: cfg('Pickleball', 'doubles', 'pools_playoff',
              poolCount: 4, advancePerPool: 2)),
      TournamentTemplate(
          id: 'builtin:pkl_singles_se',
          name: 'Pickleball Singles — Knockout',
          config: cfg('Pickleball', 'singles', 'single_elimination')),
      TournamentTemplate(
          id: 'builtin:mixed_rr',
          name: 'Mixed Doubles — Round Robin',
          config: cfg('Badminton', 'mixed', 'round_robin')),
      TournamentTemplate(
          id: 'builtin:team_ties_5',
          name: 'Team Ties — 5 singles',
          config: cfg('Badminton', 'singles', 'single_elimination',
              kind: 'team',
              rosterSize: 5,
              tie: const TieConfig(
                  submatchCount: 5,
                  pairingRule: PairingRule.sameRank,
                  winThreshold: 3))),
      TournamentTemplate(
          id: 'builtin:team_ties_3',
          name: 'Team Ties — 3 singles',
          config: cfg('Badminton', 'singles', 'single_elimination',
              kind: 'team',
              rosterSize: 3,
              tie: const TieConfig(
                  submatchCount: 3,
                  pairingRule: PairingRule.sameRank,
                  winThreshold: 2))),
    ];
  }

  void _applyConfig(Map<String, dynamic> c) {
    final sc = ScoringConfig.fromJson(
        (c['scoring_config'] as Map?)?.cast<String, dynamic>() ?? const {});
    final tc = c['tie_config'] != null
        ? TieConfig.fromJson((c['tie_config'] as Map).cast<String, dynamic>())
        : null;
    setState(() {
      _sportCtrl.text = (c['sport'] as String?) ?? _sportCtrl.text;
      _discipline = Discipline.fromString(c['discipline'] as String?);
      _skillCtrl.text = (c['skill_level'] as String?) ?? '';
      _format = DivisionFormat.fromString(c['format'] as String?);
      _system = sc.system;
      _pointsCtrl.text = '${sc.pointsToWin}';
      _capPointCtrl.text = sc.cap?.toString() ?? '';
      _winByTwo = sc.winByTwo;
      _bestOf = sc.bestOf;
      _capCtrl.text = (c['entrant_cap'])?.toString() ?? '';
      if (c['pool_count'] != null) _poolCountCtrl.text = '${c['pool_count']}';
      if (c['advance_per_pool'] != null) {
        _advanceCtrl.text = '${c['advance_per_pool']}';
      }
      _entrantKind = EntrantKind.fromString(c['entrant_kind'] as String?);
      if (c['roster_size'] != null) _rosterSizeCtrl.text = '${c['roster_size']}';
      if (tc != null) {
        _submatchCountCtrl.text = '${tc.submatchCount}';
        _winThresholdCtrl.text = '${tc.winThreshold}';
        _pairingRule = tc.pairingRule;
      }
    });
  }

  Map<String, dynamic> _currentConfig() => {
        'sport': _sportCtrl.text.trim(),
        'discipline': _discipline.dbValue,
        'skill_level': _skillCtrl.text.trim(),
        'format': _format.dbValue,
        'entrant_kind': _entrantKind.dbValue,
        'entrant_cap': int.tryParse(_capCtrl.text.trim()),
        'pool_count': int.tryParse(_poolCountCtrl.text.trim()),
        'advance_per_pool': int.tryParse(_advanceCtrl.text.trim()),
        'roster_size': _isTeam ? int.tryParse(_rosterSizeCtrl.text.trim()) : null,
        'scoring_config': ScoringConfig(
          sport: _sportCtrl.text.trim().isEmpty ? 'Custom' : _sportCtrl.text.trim(),
          system: _system,
          pointsToWin: int.tryParse(_pointsCtrl.text.trim()) ?? 21,
          winByTwo: _winByTwo,
          cap: int.tryParse(_capPointCtrl.text.trim()),
          bestOf: _bestOf,
        ).toJson(),
        'tie_config': _isTeam
            ? TieConfig(
                submatchCount: int.tryParse(_submatchCountCtrl.text.trim()) ?? 3,
                pairingRule: _pairingRule,
                winThreshold: int.tryParse(_winThresholdCtrl.text.trim()) ?? 2,
              ).toJson()
            : null,
      };

  Future<void> _saveAsTemplate() async {
    final ctrl = TextEditingController(
        text: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await context.read<EventProvider>().saveTemplate(name, _currentConfig());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved template "$name"')));
    }
  }

  /// Prefill the scoring fields from a known sport's preset (free-form sports
  /// just keep whatever the organizer typed).
  void _applySportPreset(String sport) {
    final cfg = ScoringConfig.defaultFor(sport);
    setState(() {
      _system = cfg.system;
      _pointsCtrl.text = '${cfg.pointsToWin}';
      _capPointCtrl.text = cfg.cap?.toString() ?? '';
      _winByTwo = cfg.winByTwo;
      _bestOf = cfg.bestOf;
    });
  }

  String get _suggestedName {
    final skill = _skillCtrl.text.trim();
    return skill.isEmpty
        ? _discipline.label
        : '${_discipline.label} · $skill';
  }

  Future<void> _save() async {
    final name =
        _nameCtrl.text.trim().isEmpty ? _suggestedName : _nameCtrl.text.trim();
    final scoring = ScoringConfig(
      sport: _sportCtrl.text.trim().isEmpty ? 'Custom' : _sportCtrl.text.trim(),
      system: _system,
      pointsToWin: int.tryParse(_pointsCtrl.text.trim()) ?? 21,
      winByTwo: _winByTwo,
      cap: int.tryParse(_capPointCtrl.text.trim()), // null if blank
      bestOf: _bestOf,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<EventProvider>().createDivision(
            eventId: widget.eventId,
            name: name,
            sport: _sportCtrl.text.trim(),
            discipline: _discipline,
            skillLevel: _skillCtrl.text.trim(),
            format: _format,
            scoringConfig: scoring,
            entrantCap: int.tryParse(_capCtrl.text.trim()),
            poolCount: _format == DivisionFormat.poolsPlayoff
                ? int.tryParse(_poolCountCtrl.text.trim())
                : null,
            advancePerPool: _format == DivisionFormat.poolsPlayoff
                ? int.tryParse(_advanceCtrl.text.trim())
                : null,
            entrantKind: _entrantKind,
            rosterSize:
                _isTeam ? int.tryParse(_rosterSizeCtrl.text.trim()) : null,
            tieConfig: _isTeam
                ? TieConfig(
                    submatchCount:
                        int.tryParse(_submatchCountCtrl.text.trim()) ?? 3,
                    pairingRule: _pairingRule,
                    winThreshold:
                        int.tryParse(_winThresholdCtrl.text.trim()) ?? 2,
                  )
                : null,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Could not add division. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add Division',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Start from a built-in or saved template.
                  Builder(builder: (context) {
                    final userTemplates =
                        context.watch<EventProvider>().templates;
                    final all = [..._builtInTemplates(), ...userTemplates];
                    return AppPickerField<TournamentTemplate>(
                      label: 'Start from template (optional)',
                      value: null,
                      hint: 'Choose a template…',
                      items: all,
                      labelOf: (t) => t.name,
                      onChanged: (t) => _applyConfig(t.config),
                    );
                  }),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Name (optional)',
                      hintText: _suggestedName,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sport — free-form text + quick presets.
                  TextField(
                    controller: _sportCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sport',
                      hintText: 'e.g. Badminton, Tennis, Squash',
                    ),
                  ),
                  _PresetChips(
                    presets: kSportPresets,
                    selected: _sportCtrl.text.trim(),
                    onTap: (v) {
                      _sportCtrl.text = v;
                      _applySportPreset(v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Entrant kind — individual (1–2 players) vs team (roster).
                  AppPickerField<EntrantKind>(
                    label: 'Entrants',
                    value: _entrantKind,
                    items: EntrantKind.values,
                    labelOf: (k) => k == EntrantKind.individual
                        ? 'Individuals (singles/doubles)'
                        : 'Teams (ranked roster)',
                    onChanged: (v) => setState(() => _entrantKind = v),
                  ),
                  const SizedBox(height: 16),

                  if (!_isTeam) ...[
                    AppPickerField<Discipline>(
                      label: 'Discipline',
                      value: _discipline,
                      items: Discipline.values,
                      labelOf: (d) => d.label,
                      onChanged: (v) => setState(() => _discipline = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isTeam) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _rosterSizeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Players per team'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _submatchCountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Sub-matches / tie'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _winThresholdCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Wins to take tie'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPickerField<PairingRule>(
                            label: 'Pairing',
                            value: _pairingRule,
                            items: PairingRule.values,
                            labelOf: (r) => r == PairingRule.sameRank
                                ? 'By rank'
                                : 'Manual',
                            onChanged: (v) =>
                                setState(() => _pairingRule = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Skill level — free-form text + quick presets.
                  TextField(
                    controller: _skillCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Skill level (optional)',
                      hintText: 'e.g. B, Open, DUPR 3.5',
                    ),
                  ),
                  _PresetChips(
                    presets: kSkillPresets,
                    selected: _skillCtrl.text.trim(),
                    onTap: (v) => setState(() => _skillCtrl.text = v),
                  ),
                  const SizedBox(height: 16),

                  AppPickerField<DivisionFormat>(
                    label: 'Format',
                    value: _format,
                    items: DivisionFormat.values,
                    labelOf: (f) => f.label,
                    onChanged: (v) => setState(() => _format = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _capCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _isTeam
                          ? 'Max teams (optional)'
                          : 'Max entrants (optional)',
                    ),
                  ),
                  if (_format == DivisionFormat.poolsPlayoff) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _poolCountCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Pools'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _advanceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Advance / pool'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Editable scoring rules ──────────────────────────────
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Scoring rules',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pointsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Points to win'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _capPointCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Point cap',
                            hintText: 'none',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppPickerField<int>(
                    label: 'Best of (games)',
                    value: _bestOf,
                    items: const [1, 3, 5],
                    labelOf: (n) => '$n',
                    onChanged: (v) => setState(() => _bestOf = v),
                  ),
                  const SizedBox(height: 8),
                  AppPickerField<ScoringSystem>(
                    label: 'Scoring system',
                    value: _system,
                    items: ScoringSystem.values,
                    labelOf: (s) => s == ScoringSystem.rally
                        ? 'Rally (every rally scores)'
                        : 'Side-out (server scores)',
                    onChanged: (v) => setState(() => _system = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Win by 2'),
                    value: _winByTwo,
                    onChanged: (v) => setState(() => _winByTwo = v),
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
          AppButton(label: 'Add Division', onPressed: _save, loading: _saving),
          TextButton.icon(
            onPressed: _saving ? null : _saveAsTemplate,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Save as template'),
          ),
        ],
      ),
    );
  }
}

/// A row of quick-pick chips that fill a free-form field.
class _PresetChips extends StatelessWidget {
  final List<String> presets;
  final String selected;
  final ValueChanged<String> onTap;
  const _PresetChips({
    required this.presets,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: presets
            .map((p) => ChoiceChip(
                  label: Text(p),
                  selected: selected == p,
                  onSelected: (_) => onTap(p),
                  visualDensity: VisualDensity.compact,
                ))
            .toList(),
      ),
    );
  }
}

/// Maps registration RPC errors to friendly messages.
String friendlyRegisterError(Object e) {
  final s = e.toString();
  if (s.contains('duplicate_player_in_team')) {
    return 'A player can’t be entered twice on the same team.';
  }
  if (s.contains('player_already_registered')) {
    return 'That player is already entered in this division.';
  }
  if (s.contains('division_full')) return 'This division is full.';
  if (s.contains('registration_closed')) {
    return 'Registration is closed — the bracket is already generated.';
  }
  if (s.contains('second_player_required')) return 'Doubles needs two players.';
  if (s.contains('singles_no_partner')) return 'Singles takes one player only.';
  return 'Could not register. Please try again.';
}

// ── Member picker (searchable) + player-name field ───────────────────────────

/// A searchable bottom sheet of the event's members; returns the chosen guest.
Future<EventGuest?> _pickMember(BuildContext context, String eventId) {
  return showModalBottomSheet<EventGuest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MemberPickerSheet(eventId: eventId),
  );
}

class _MemberPickerSheet extends StatefulWidget {
  final String eventId;
  const _MemberPickerSheet({required this.eventId});

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final events = context.read<EventProvider>().events;
    Event? event;
    for (final e in events) {
      if (e.id == widget.eventId) {
        event = e;
        break;
      }
    }
    final members = (event?.guests ?? [])
        .where((g) => g.status != 'declined' && g.status != 'left')
        .toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    final filtered = _q.isEmpty
        ? members
        : members
            .where((m) => m.displayName.toLowerCase().contains(_q))
            .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Choose member',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search members',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _q = v.toLowerCase().trim()),
          ),
          const SizedBox(height: 8),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No members yet. Invite people from the Info → Members tab.',
                  textAlign: TextAlign.center),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final m = filtered[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        m.displayName.isNotEmpty
                            ? m.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    title: Text(m.displayName),
                    subtitle: m.role == 'organizer' ? const Text('Organizer') : null,
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A player-name text field with a "choose member" action. [onMember] fires
/// with the picked guest, or null when the field is typed in manually (so the
/// caller can clear any linked user id).
class _PlayerNameField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String eventId;
  final ValueChanged<EventGuest?> onMember;
  const _PlayerNameField({
    required this.controller,
    required this.label,
    required this.eventId,
    required this.onMember,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: const Icon(Icons.person_search_outlined),
          tooltip: 'Choose member',
          onPressed: () async {
            final g = await _pickMember(context, eventId);
            if (g != null) {
              controller.text = g.displayName;
              onMember(g);
            }
          },
        ),
      ),
      onChanged: (_) => onMember(null),
    );
  }
}

// ── Entrants tab ─────────────────────────────────────────────────────────────

class TournamentEntrantsTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  const TournamentEntrantsTab({
    super.key,
    required this.event,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<TournamentEntrantsTab> createState() => _TournamentEntrantsTabState();
}

class _TournamentEntrantsTabState extends State<TournamentEntrantsTab> {
  String? _selectedDivisionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchDivisions(widget.event.id);
    });
  }

  void _ensureFetched(String divisionId) {
    final p = context.read<EventProvider>();
    if (p.entrantsFor(divisionId).isEmpty) {
      p.fetchEntrants(divisionId);
    }
  }

  Future<void> _register(TournamentDivision division) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => division.entrantKind == EntrantKind.team
          ? _TeamFormSheet(division: division)
          : _EntrantFormSheet(division: division, authUid: widget.authUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EventProvider>();
    final divisions = p.divisionsFor(widget.event.id);
    if (divisions.isEmpty) {
      return const _EmptyState(
        icon: Icons.groups_outlined,
        message: 'Add a division first, then register teams into it.',
      );
    }
    final selected = divisions.firstWhere(
      (d) => d.id == _selectedDivisionId,
      orElse: () => divisions.first,
    );
    _ensureFetched(selected.id);
    final entrants = p.activeEntrantsFor(selected.id);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppPickerField<TournamentDivision>(
              label: 'Division',
              value: selected,
              items: divisions,
              labelOf: (d) => d.name,
              onChanged: (d) => setState(() => _selectedDivisionId = d.id),
            ),
          ),
          if (!selected.registrationOpen)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Registration is closed (bracket generated).',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ),
          Expanded(
            child: entrants.isEmpty
                ? const _EmptyState(
                    icon: Icons.person_add_alt_1_outlined,
                    message: 'No teams registered yet.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: entrants.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = entrants[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(e.seed?.toString() ?? '${i + 1}'),
                        ),
                        title: Text(e.teamName),
                        subtitle: Text(e.isTeam
                            ? '${e.players.length} players · '
                                '${e.players.take(3).map((p) => p.name).join(", ")}'
                                '${e.players.length > 3 ? "…" : ""}'
                            : e.isDoubles
                                ? '${e.player1Name} / ${e.player2Name}'
                                : e.player1Name),
                        trailing: widget.isOrganizer && selected.registrationOpen
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => context
                                    .read<EventProvider>()
                                    .removeEntrant(e.id, selected.id),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton:
          (widget.isOrganizer || selected.registrationOpen) &&
                  selected.registrationOpen
              ? FloatingActionButton.extended(
                  onPressed: () => _register(selected),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Team'),
                )
              : null,
    );
  }
}

class _EntrantFormSheet extends StatefulWidget {
  final TournamentDivision division;
  final String? authUid;
  const _EntrantFormSheet({required this.division, required this.authUid});

  @override
  State<_EntrantFormSheet> createState() => _EntrantFormSheetState();
}

class _EntrantFormSheetState extends State<_EntrantFormSheet> {
  final _teamCtrl = TextEditingController();
  final _p1Ctrl = TextEditingController();
  final _p2Ctrl = TextEditingController();
  String? _p1UserId; // set when a player is chosen from members
  String? _p2UserId;
  bool _saving = false;
  String? _error;

  bool get _isDoubles => widget.division.teamSize == 2;

  @override
  void dispose() {
    _teamCtrl.dispose();
    _p1Ctrl.dispose();
    _p2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p1 = _p1Ctrl.text.trim();
    final p2 = _p2Ctrl.text.trim();
    if (p1.isEmpty || (_isDoubles && p2.isEmpty)) {
      setState(() => _error = 'Please enter all player names.');
      return;
    }
    final team = _teamCtrl.text.trim().isNotEmpty
        ? _teamCtrl.text.trim()
        : (_isDoubles ? '$p1 / $p2' : p1);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<EventProvider>().registerEntrant(
            divisionId: widget.division.id,
            teamName: team,
            player1Name: p1,
            player1UserId: _p1UserId,
            player2Name: _isDoubles ? p2 : null,
            player2UserId: _isDoubles ? _p2UserId : null,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = friendlyRegisterError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Team — ${widget.division.name}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlayerNameField(
                    controller: _p1Ctrl,
                    label: _isDoubles ? 'Player 1' : 'Player name',
                    eventId: widget.division.eventId,
                    onMember: (g) => _p1UserId = g?.userId,
                  ),
                  if (_isDoubles) ...[
                    const SizedBox(height: 16),
                    _PlayerNameField(
                      controller: _p2Ctrl,
                      label: 'Player 2',
                      eventId: widget.division.eventId,
                      onMember: (g) => _p2UserId = g?.userId,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _teamCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Team name (optional)'),
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
          AppButton(label: 'Add Team', onPressed: _save, loading: _saving),
        ],
      ),
    );
  }
}

// ── Team roster registration (team-kind divisions) ──────────────────────────

class _TeamFormSheet extends StatefulWidget {
  final TournamentDivision division;
  const _TeamFormSheet({required this.division});

  @override
  State<_TeamFormSheet> createState() => _TeamFormSheetState();
}

class _TeamFormSheetState extends State<_TeamFormSheet> {
  final _teamCtrl = TextEditingController();
  late final List<TextEditingController> _playerCtrls;
  late final List<String?> _playerUserIds; // linked member ids (parallel)
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = (widget.division.rosterSize ?? 4).clamp(1, 64);
    _playerCtrls = List.generate(n, (_) => TextEditingController());
    _playerUserIds = List.filled(n, null, growable: true);
  }

  @override
  void dispose() {
    _teamCtrl.dispose();
    for (final c in _playerCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final players = <({String name, int rank, String? userId})>[];
    for (var i = 0; i < _playerCtrls.length; i++) {
      final name = _playerCtrls[i].text.trim();
      if (name.isNotEmpty) {
        players.add((name: name, rank: i + 1, userId: _playerUserIds[i]));
      }
    }
    if (_teamCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a team name.');
      return;
    }
    if (players.isEmpty) {
      setState(() => _error = 'Add at least one player.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<EventProvider>().registerTeam(
            divisionId: widget.division.id,
            teamName: _teamCtrl.text.trim(),
            players: players,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = friendlyRegisterError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Team — ${widget.division.name}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Players are ranked top-to-bottom (rank 1 first).',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _teamCtrl,
                    decoration: const InputDecoration(labelText: 'Team name'),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _playerCtrls.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PlayerNameField(
                        controller: _playerCtrls[i],
                        label: 'Rank ${i + 1}',
                        eventId: widget.division.eventId,
                        onMember: (g) => _playerUserIds[i] = g?.userId,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _playerCtrls.add(TextEditingController());
                        _playerUserIds.add(null);
                      }),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add player'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(label: 'Add Team', onPressed: _save, loading: _saving),
        ],
      ),
    );
  }
}

// ── Bracket tab ──────────────────────────────────────────────────────────────

class TournamentBracketTab extends StatelessWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  const TournamentBracketTab({
    super.key,
    required this.event,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    return TournamentBracketView(
      event: event,
      authUid: authUid,
      isOrganizer: isOrganizer,
    );
  }
}

// ── Courts tab ───────────────────────────────────────────────────────────────

class TournamentCourtsTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  const TournamentCourtsTab({
    super.key,
    required this.event,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<TournamentCourtsTab> createState() => _TournamentCourtsTabState();
}

class _TournamentCourtsTabState extends State<TournamentCourtsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().fetchAllMatchesForEvent(widget.event.id);
      context.read<EventProvider>().fetchCourts(widget.event.id);
    });
  }

  Future<void> _addCourt() async {
    final ctrl = TextEditingController(
        text: 'Court ${context.read<EventProvider>().courtsFor(widget.event.id).length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Court'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Court name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await context.read<EventProvider>().addCourt(widget.event.id, name);
  }

  String _matchLabel(EventProvider p, TournamentMatch m) {
    final e1 = p.entrantById(widget.event.id, m.entrant1Id)?.teamName ?? 'TBD';
    final e2 = p.entrantById(widget.event.id, m.entrant2Id)?.teamName ?? 'TBD';
    return '$e1  vs  $e2';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<EventProvider>();
    final courts = p.courtsFor(widget.event.id);
    final doubleBooked = p.doubleBookedEntrantIds(widget.event.id);
    final hasWarning = doubleBooked.isNotEmpty;

    return Scaffold(
      body: courts.isEmpty
          ? const _EmptyState(
              icon: Icons.stadium_outlined,
              message: 'No courts yet.\nAdd the courts available at your venue.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (hasWarning)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A player is scheduled on two courts at once. Check the queues below.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...courts.map((c) => _CourtCard(
                      court: c,
                      event: widget.event,
                      isOrganizer: widget.isOrganizer,
                      matches: p.assignedMatchesForCourt(widget.event.id, c.id),
                      matchLabel: (m) => _matchLabel(p, m),
                    )),
              ],
            ),
      floatingActionButton: widget.isOrganizer
          ? FloatingActionButton.extended(
              onPressed: _addCourt,
              icon: const Icon(Icons.add),
              label: const Text('Add Court'),
            )
          : null,
    );
  }
}

class _CourtCard extends StatelessWidget {
  final Court court;
  final Event event;
  final bool isOrganizer;
  final List<TournamentMatch> matches; // queue, first = on court now
  final String Function(TournamentMatch) matchLabel;
  const _CourtCard({
    required this.court,
    required this.event,
    required this.isOrganizer,
    required this.matches,
    required this.matchLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_tennis_rounded,
                    color: matches.isEmpty ? Colors.grey : AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(court.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (isOrganizer)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => context
                        .read<EventProvider>()
                        .deleteCourt(court.id, event.id),
                  ),
              ],
            ),
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Idle — no match assigned.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              )
            else
              ...matches.asMap().entries.map((e) {
                final i = e.key;
                final m = e.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: i == 0
                      ? const Icon(Icons.play_circle_fill, color: Colors.green)
                      : CircleAvatar(
                          radius: 12, child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 11))),
                  title: Text(matchLabel(m),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(i == 0 ? 'On court now' : 'Next up'),
                  trailing: isOrganizer
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => context
                              .read<EventProvider>()
                              .unassignMatchFromCourt(m, event.id),
                        )
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── Small shared widgets ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
