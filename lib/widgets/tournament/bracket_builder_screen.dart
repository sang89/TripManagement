import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:uuid/uuid.dart';

import '../../models/tournament.dart';
import '../../providers/event_provider.dart';
import 'tournament_labels.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Bracket Structure Builder
//
// Lets tournament organizers create multiple linked divisions at once by:
// 1. Adding entrant names to a shared pool
// 2. Dragging entrant chips into named division lanes
// 3. Picking a format/template per lane
// 4. Tapping "Generate All" to create all divisions, register entrants, and
//    generate brackets in one shot.
//
// Shared config (sport, discipline, skill level, entrant kind) is set once
// at the top of the screen. Per-lane config (name, format, scoring) is set
// on each lane card.
// ═══════════════════════════════════════════════════════════════════════════

const _uuid = Uuid();

class BracketBuilderScreen extends StatefulWidget {
  final String eventId;
  const BracketBuilderScreen({super.key, required this.eventId});

  @override
  State<BracketBuilderScreen> createState() => _BracketBuilderScreenState();
}

class _BracketBuilderScreenState extends State<BracketBuilderScreen> {
  // ── shared division config ─────────────────────────────────────────────────
  final _sportCtrl = TextEditingController(text: 'Badminton');
  final _skillCtrl = TextEditingController();
  Discipline _discipline = Discipline.doubles;
  EntrantKind _entrantKind = EntrantKind.individual;

  // ── pool of unassigned entrants ────────────────────────────────────────────
  final List<DraftEntrant> _pool = [];
  final _addNameCtrl = TextEditingController();
  final _addName2Ctrl = TextEditingController();

  // ── division lanes ─────────────────────────────────────────────────────────
  final List<BracketSegmentConfig> _lanes = [];

  // ── tap-to-assign state ────────────────────────────────────────────────────
  String? _selectedLocalId; // localId of chip selected for tap-to-assign

  // ── generate state ─────────────────────────────────────────────────────────
  bool _generating = false;
  String? _error;

  // ── instructions banner ────────────────────────────────────────────────────
  bool _showInstructions = true;

  @override
  void initState() {
    super.initState();
    _lanes.add(_makeLane('Division A'));
    _lanes.add(_makeLane('Division B'));
  }

  @override
  void dispose() {
    _sportCtrl.dispose();
    _skillCtrl.dispose();
    _addNameCtrl.dispose();
    _addName2Ctrl.dispose();
    super.dispose();
  }

  BracketSegmentConfig _makeLane(String name) => BracketSegmentConfig(
        localId: _uuid.v4(),
        name: name,
        entrants: const [],
        format: DivisionFormat.singleElimination,
        scoringConfig: ScoringConfig.defaultFor(_sportCtrl.text.trim()),
      );

  // ── pool mutations ─────────────────────────────────────────────────────────

  void _addToPool() {
    final name = _addNameCtrl.text.trim();
    if (name.isEmpty) return;
    final name2 =
        _entrantKind == EntrantKind.individual && _discipline != Discipline.singles
            ? _addName2Ctrl.text.trim()
            : null;
    setState(() {
      _pool.add(DraftEntrant(
        localId: _uuid.v4(),
        teamName: name,
        player1Name: name,
        player2Name: name2?.isEmpty == true ? null : name2,
      ));
      _addNameCtrl.clear();
      _addName2Ctrl.clear();
      // Collapse instructions once the user starts adding entrants.
      _showInstructions = false;
    });
  }

  void _returnToPool(String localId) {
    setState(() {
      _selectedLocalId = null;
      for (int i = 0; i < _lanes.length; i++) {
        final idx = _lanes[i].entrants.indexWhere((e) => e.localId == localId);
        if (idx >= 0) {
          final draft = _lanes[i].entrants[idx];
          final updated = List<DraftEntrant>.from(_lanes[i].entrants)
            ..removeAt(idx);
          _lanes[i] = _lanes[i].copyWith(entrants: updated);
          _pool.add(draft);
          return;
        }
      }
    });
  }

  void _assignToLane(String entrantLocalId, String laneLocalId) {
    setState(() {
      _selectedLocalId = null;
      DraftEntrant? draft;
      // Remove from pool first.
      final poolIdx = _pool.indexWhere((e) => e.localId == entrantLocalId);
      if (poolIdx >= 0) {
        draft = _pool[poolIdx];
        _pool.removeAt(poolIdx);
      } else {
        // Remove from another lane.
        for (int i = 0; i < _lanes.length; i++) {
          final idx =
              _lanes[i].entrants.indexWhere((e) => e.localId == entrantLocalId);
          if (idx >= 0) {
            draft = _lanes[i].entrants[idx];
            final updated = List<DraftEntrant>.from(_lanes[i].entrants)
              ..removeAt(idx);
            _lanes[i] = _lanes[i].copyWith(entrants: updated);
            break;
          }
        }
      }
      if (draft == null) return;
      final laneIdx = _lanes.indexWhere((l) => l.localId == laneLocalId);
      if (laneIdx < 0) return;
      final updated = List<DraftEntrant>.from(_lanes[laneIdx].entrants)
        ..add(draft);
      _lanes[laneIdx] = _lanes[laneIdx].copyWith(entrants: updated);
    });
  }

  void _toggleSelect(String localId) {
    setState(() {
      _selectedLocalId = _selectedLocalId == localId ? null : localId;
    });
  }

  // ── lane mutations ─────────────────────────────────────────────────────────

  void _addLane() {
    final idx = _lanes.length + 1;
    const names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final label = idx - 1 < names.length ? names[idx - 1] : '$idx';
    setState(() => _lanes.add(_makeLane('Division $label')));
  }

  void _deleteLane(String laneLocalId) {
    final laneIdx = _lanes.indexWhere((l) => l.localId == laneLocalId);
    if (laneIdx < 0) return;
    setState(() {
      _pool.addAll(_lanes[laneIdx].entrants);
      _lanes.removeAt(laneIdx);
    });
  }

  void _updateLane(BracketSegmentConfig updated) {
    final idx = _lanes.indexWhere((l) => l.localId == updated.localId);
    if (idx < 0) return;
    setState(() => _lanes[idx] = updated);
  }

  // ── validation + generate ──────────────────────────────────────────────────

  String? _validate() {
    if (_lanes.isEmpty) return 'Add at least one division lane.';
    for (final lane in _lanes) {
      if (lane.name.trim().isEmpty) return 'All lanes must have a name.';
      if (lane.entrants.length < 2) {
        return '"${lane.name.trim()}" needs at least 2 entrants.';
      }
    }
    return null;
  }

  Future<void> _generateAll() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await context.read<EventProvider>().createDivisionBundle(
            eventId: widget.eventId,
            segments: _lanes,
            sport: _sportCtrl.text.trim(),
            discipline: _discipline,
            skillLevel: _skillCtrl.text.trim(),
            entrantKind: _entrantKind,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not create structure: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── layout helpers ─────────────────────────────────────────────────────────

  bool get _isWide =>
      MediaQuery.of(context).size.width >= 700;

  void _openHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How to use Build Structure'),
        content: const SingleChildScrollView(
          child: _HowToContent(dense: false),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Structure'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'How it works',
            onPressed: _openHelpDialog,
          ),
          if (_generating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _generateAll,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Generate All'),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            MaterialBanner(
              backgroundColor: cs.errorContainer,
              content: Text(_error!,
                  style: TextStyle(color: cs.onErrorContainer)),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: Text('Dismiss',
                      style: TextStyle(color: cs.onErrorContainer)),
                )
              ],
            ),
          // Step-by-step instructions banner — collapses after first entrant added.
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _showInstructions
                ? _InstructionsBanner(
                    onDismiss: () => setState(() => _showInstructions = false),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: _isWide ? _wideLayout() : _narrowLayout(),
          ),
        ],
      ),
    );
  }

  // ── wide layout (tablet/web): pool left, lanes right ──────────────────────

  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: _PoolPanel(
            pool: _pool,
            entrantKind: _entrantKind,
            discipline: _discipline,
            addNameCtrl: _addNameCtrl,
            addName2Ctrl: _addName2Ctrl,
            selectedLocalId: _selectedLocalId,
            onAdd: _addToPool,
            onToggleSelect: _toggleSelect,
            onDropAccepted: (id) => _returnToPool(id),
            // Shared config controls.
            sportCtrl: _sportCtrl,
            skillCtrl: _skillCtrl,
            onDisciplineChanged: (d) => setState(() => _discipline = d),
            onEntrantKindChanged: (k) => setState(() => _entrantKind = k),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _LanesArea(
            lanes: _lanes,
            selectedLocalId: _selectedLocalId,
            allTemplates: _builtInTemplates(),
            onAssign: _assignToLane,
            onUpdateLane: _updateLane,
            onDeleteLane: _deleteLane,
            onAddLane: _addLane,
            onTapLaneWhenSelected: (laneId) =>
                _selectedLocalId != null ? _assignToLane(_selectedLocalId!, laneId) : null,
          ),
        ),
      ],
    );
  }

  // ── narrow layout (phone): pool card + lanes stacked vertically ────────────

  Widget _narrowLayout() {
    return CustomScrollView(
      slivers: [
        // Shared config section.
        SliverToBoxAdapter(
          child: _SharedConfigCard(
            sportCtrl: _sportCtrl,
            skillCtrl: _skillCtrl,
            discipline: _discipline,
            entrantKind: _entrantKind,
            onDisciplineChanged: (d) => setState(() => _discipline = d),
            onEntrantKindChanged: (k) => setState(() => _entrantKind = k),
          ),
        ),
        // Pool section.
        SliverToBoxAdapter(
          child: _PoolPanel(
            pool: _pool,
            entrantKind: _entrantKind,
            discipline: _discipline,
            addNameCtrl: _addNameCtrl,
            addName2Ctrl: _addName2Ctrl,
            selectedLocalId: _selectedLocalId,
            onAdd: _addToPool,
            onToggleSelect: _toggleSelect,
            onDropAccepted: (id) => _returnToPool(id),
            narrowMode: true,
          ),
        ),
        // Step 2 header.
        SliverToBoxAdapter(
          child: Builder(builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step 2 — Division Lanes',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    'Drag entrant chips into lanes, name each lane, and pick a format.',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }),
        ),
        // Lane cards.
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _LaneCard(
              lane: _lanes[i],
              selectedLocalId: _selectedLocalId,
              allTemplates: _builtInTemplates(),
              onAssign: _assignToLane,
              onUpdate: _updateLane,
              onDelete: () => _deleteLane(_lanes[i].localId),
              onTapWhenSelected: () => _selectedLocalId != null
                  ? _assignToLane(_selectedLocalId!, _lanes[i].localId)
                  : null,
            ),
            childCount: _lanes.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            child: OutlinedButton.icon(
              onPressed: _addLane,
              icon: const Icon(Icons.add),
              label: const Text('Add Division Lane'),
            ),
          ),
        ),
      ],
    );
  }

  // ── built-in templates (same as tournament_tabs.dart) ─────────────────────

  List<TournamentTemplate> _builtInTemplates() {
    ScoringConfig sc(String sport) => ScoringConfig.defaultFor(sport);
    return [
      TournamentTemplate(
        id: 'builtin:se',
        name: 'Knockout (Single Elimination)',
        config: {'format': 'single_elimination', 'scoring_config': sc(_sportCtrl.text.trim()).toJson()},
      ),
      TournamentTemplate(
        id: 'builtin:rr',
        name: 'Round Robin',
        config: {'format': 'round_robin', 'scoring_config': sc(_sportCtrl.text.trim()).toJson()},
      ),
      TournamentTemplate(
        id: 'builtin:pools2',
        name: 'Pools → Playoffs (2 pools, top 2 advance)',
        config: {
          'format': 'pools_playoff',
          'pool_count': 2,
          'advance_per_pool': 2,
          'scoring_config': sc(_sportCtrl.text.trim()).toJson(),
        },
      ),
      TournamentTemplate(
        id: 'builtin:pools4',
        name: 'Pools → Playoffs (4 pools, top 2 advance)',
        config: {
          'format': 'pools_playoff',
          'pool_count': 4,
          'advance_per_pool': 2,
          'scoring_config': sc(_sportCtrl.text.trim()).toJson(),
        },
      ),
      TournamentTemplate(
        id: 'builtin:custom',
        name: 'Custom (manual bracket)',
        config: {'format': 'custom', 'scoring_config': sc(_sportCtrl.text.trim()).toJson()},
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Instructions banner — collapsible, dismissed after first entrant added
// ═══════════════════════════════════════════════════════════════════════════

class _InstructionsBanner extends StatefulWidget {
  final VoidCallback onDismiss;
  const _InstructionsBanner({required this.onDismiss});

  @override
  State<_InstructionsBanner> createState() => _InstructionsBannerState();
}

class _InstructionsBannerState extends State<_InstructionsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.07),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title row — always visible, tap to expand/collapse.
          AppTappable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.account_tree_rounded,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'How to build your structure',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expandable steps — hidden by default.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: const _HowToContent(dense: true),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// The step-by-step instructions used both in the banner and the help dialog.
class _HowToContent extends StatelessWidget {
  final bool dense;
  const _HowToContent({required this.dense});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = [
      (
        icon: Icons.settings_outlined,
        label: 'Set sport & discipline',
        detail: 'Fill in the sport, skill level, and discipline — these apply to all divisions you create.',
      ),
      (
        icon: Icons.person_add_outlined,
        label: 'Add entrants to the pool',
        detail: 'Type each team or player name and tap "Add to pool". Every entrant starts here.',
      ),
      (
        icon: Icons.drag_indicator,
        label: 'Drag entrants into division lanes',
        detail:
            'Long-press an entrant chip to drag it into a division lane. On mobile, tap to select, then tap a lane to assign.',
      ),
      (
        icon: Icons.tune,
        label: 'Pick a format for each lane',
        detail: 'Tap the format chip on each lane to choose Knockout, Round Robin, Pools → Playoffs, or Custom.',
      ),
      (
        icon: Icons.edit_outlined,
        label: 'Name your divisions',
        detail: 'Tap the name field in each lane (e.g. "Elite", "Open") to give it a meaningful label.',
      ),
      (
        icon: Icons.bolt,
        label: 'Generate All',
        detail:
            'Tap "Generate All" to create all divisions, register the entrants, and generate brackets in one shot.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((s) {
        return Padding(
          padding: EdgeInsets.only(bottom: dense ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(s.icon, size: dense ? 16 : 18, color: AppTheme.primary),
              SizedBox(width: dense ? 8 : 10),
              Expanded(
                child: dense
                    ? RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface),
                          children: [
                            TextSpan(
                              text: '${s.label}: ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: s.detail),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(s.detail,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant,
                                  height: 1.4)),
                        ],
                      ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared config card (narrow mode only — wide mode embeds in the pool panel)
// ═══════════════════════════════════════════════════════════════════════════

class _SharedConfigCard extends StatelessWidget {
  final TextEditingController sportCtrl;
  final TextEditingController skillCtrl;
  final Discipline discipline;
  final EntrantKind entrantKind;
  final ValueChanged<Discipline> onDisciplineChanged;
  final ValueChanged<EntrantKind> onEntrantKindChanged;

  const _SharedConfigCard({
    required this.sportCtrl,
    required this.skillCtrl,
    required this.discipline,
    required this.entrantKind,
    required this.onDisciplineChanged,
    required this.onEntrantKindChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Event Config',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: sportCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sport',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: skillCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Skill level',
                    hintText: 'Open',
                    isDense: true,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            AppPickerField<Discipline>(
              label: 'Discipline',
              value: discipline,
              items: Discipline.values,
              labelOf: (d) => d.label,
              onChanged: onDisciplineChanged,
            ),
            const SizedBox(height: 10),
            AppPickerField<EntrantKind>(
              label: 'Entrant type',
              value: entrantKind,
              items: EntrantKind.values,
              labelOf: (k) =>
                  k == EntrantKind.individual ? 'Individuals' : 'Teams',
              onChanged: onEntrantKindChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pool panel — left side on wide, card at top on narrow
// ═══════════════════════════════════════════════════════════════════════════

class _PoolPanel extends StatelessWidget {
  final List<DraftEntrant> pool;
  final EntrantKind entrantKind;
  final Discipline discipline;
  final TextEditingController addNameCtrl;
  final TextEditingController addName2Ctrl;
  final String? selectedLocalId;
  final VoidCallback onAdd;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onDropAccepted;
  final bool narrowMode;

  // Wide mode only — shared config lives here.
  final TextEditingController? sportCtrl;
  final TextEditingController? skillCtrl;
  final ValueChanged<Discipline>? onDisciplineChanged;
  final ValueChanged<EntrantKind>? onEntrantKindChanged;

  const _PoolPanel({
    required this.pool,
    required this.entrantKind,
    required this.discipline,
    required this.addNameCtrl,
    required this.addName2Ctrl,
    required this.selectedLocalId,
    required this.onAdd,
    required this.onToggleSelect,
    required this.onDropAccepted,
    this.narrowMode = false,
    this.sportCtrl,
    this.skillCtrl,
    this.onDisciplineChanged,
    this.onEntrantKindChanged,
  });

  bool get _isDoubles =>
      entrantKind == EntrantKind.individual && discipline != Discipline.singles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Shared config (wide mode only).
        if (!narrowMode && sportCtrl != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: _SharedConfigCard(
              sportCtrl: sportCtrl!,
              skillCtrl: skillCtrl!,
              discipline: discipline,
              entrantKind: entrantKind,
              onDisciplineChanged: onDisciplineChanged!,
              onEntrantKindChanged: onEntrantKindChanged!,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(12, narrowMode ? 0 : 4, 12, 0),
          child: Row(
            children: [
              Text('Step 1 — Entrant Pool',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
          child: Text(
            'Type each team / player name and tap "Add to pool".',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              TextField(
                controller: addNameCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: _isDoubles ? 'Player 1 name' : 'Name / team name',
                  hintText: _isDoubles ? 'e.g. John Smith' : 'e.g. Team Alpha',
                ),
                onSubmitted: (_) => onAdd(),
              ),
              if (_isDoubles) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: addName2Ctrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Player 2 name',
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Add to pool'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (pool.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                Icon(Icons.group_add_outlined,
                    size: 32, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                Text(
                  'Your entrants appear here.\nThen drag them into a division lane below.',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          DragTarget<String>(
            onAcceptWithDetails: (d) => onDropAccepted(d.data),
            builder: (context, candidates, rejected) {
              return Container(
                decoration: candidates.isNotEmpty
                    ? BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pool
                      .map((e) => _EntrantChip(
                            entrant: e,
                            isSelected: selectedLocalId == e.localId,
                            onTap: () => onToggleSelect(e.localId),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        if (pool.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              pool.length == 1
                  ? '1 unassigned — drag or tap it into a lane'
                  : '${pool.length} unassigned — drag or tap into a lane',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.primary,
                  fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );

    if (narrowMode) {
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: body,
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: body,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Lanes area (wide layout)
// ═══════════════════════════════════════════════════════════════════════════

class _LanesArea extends StatelessWidget {
  final List<BracketSegmentConfig> lanes;
  final String? selectedLocalId;
  final List<TournamentTemplate> allTemplates;
  final void Function(String entrantId, String laneId) onAssign;
  final ValueChanged<BracketSegmentConfig> onUpdateLane;
  final ValueChanged<String> onDeleteLane;
  final VoidCallback onAddLane;
  final void Function(String laneId)? onTapLaneWhenSelected;

  const _LanesArea({
    required this.lanes,
    required this.selectedLocalId,
    required this.allTemplates,
    required this.onAssign,
    required this.onUpdateLane,
    required this.onDeleteLane,
    required this.onAddLane,
    this.onTapLaneWhenSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: lanes.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i == lanes.length) {
                return Center(
                  child: SizedBox(
                    width: 160,
                    child: OutlinedButton.icon(
                      onPressed: onAddLane,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Lane'),
                    ),
                  ),
                );
              }
              return SizedBox(
                width: 240,
                child: _LaneCard(
                  lane: lanes[i],
                  selectedLocalId: selectedLocalId,
                  allTemplates: allTemplates,
                  onAssign: onAssign,
                  onUpdate: onUpdateLane,
                  onDelete: () => onDeleteLane(lanes[i].localId),
                  onTapWhenSelected: () =>
                      onTapLaneWhenSelected?.call(lanes[i].localId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Lane card — one per division-to-be-created
// ═══════════════════════════════════════════════════════════════════════════

class _LaneCard extends StatefulWidget {
  final BracketSegmentConfig lane;
  final String? selectedLocalId;
  final List<TournamentTemplate> allTemplates;
  final void Function(String entrantId, String laneId) onAssign;
  final ValueChanged<BracketSegmentConfig> onUpdate;
  final VoidCallback onDelete;
  final VoidCallback? onTapWhenSelected;

  const _LaneCard({
    required this.lane,
    required this.selectedLocalId,
    required this.allTemplates,
    required this.onAssign,
    required this.onUpdate,
    required this.onDelete,
    this.onTapWhenSelected,
  });

  @override
  State<_LaneCard> createState() => _LaneCardState();
}

class _LaneCardState extends State<_LaneCard> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.lane.name);
  }

  @override
  void didUpdateWidget(_LaneCard old) {
    super.didUpdateWidget(old);
    if (old.lane.name != widget.lane.name &&
        _nameCtrl.text != widget.lane.name) {
      _nameCtrl.text = widget.lane.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _openFormatPicker() async {
    final result = await showModalBottomSheet<TournamentTemplate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TemplatePicker(templates: widget.allTemplates),
    );
    if (result == null) return;
    final cfg = result.config;
    widget.onUpdate(widget.lane.copyWith(
      format: DivisionFormat.fromString(cfg['format'] as String?),
      scoringConfig: cfg['scoring_config'] != null
          ? ScoringConfig.fromJson(
              (cfg['scoring_config'] as Map).cast<String, dynamic>())
          : widget.lane.scoringConfig,
      poolCount: cfg['pool_count'] as int?,
      clearPoolCount: cfg['pool_count'] == null,
      advancePerPool: cfg['advance_per_pool'] as int?,
      clearAdvancePerPool: cfg['advance_per_pool'] == null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection = widget.selectedLocalId != null;
    final isHighlighted = hasSelection &&
        !widget.lane.entrants
            .any((e) => e.localId == widget.selectedLocalId);

    return DragTarget<String>(
      onAcceptWithDetails: (d) => widget.onAssign(d.data, widget.lane.localId),
      builder: (context, candidates, _) {
        final isDragOver = candidates.isNotEmpty;
        return AppTappable(
          onTap: hasSelection ? widget.onTapWhenSelected : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isDragOver || isHighlighted
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDragOver || isHighlighted
                    ? AppTheme.primary
                    : cs.outlineVariant,
                width: isDragOver || isHighlighted ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header.
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 10, 6, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          decoration: const InputDecoration.collapsed(
                              hintText: 'Division name'),
                          onChanged: (v) => widget.onUpdate(
                              widget.lane.copyWith(name: v)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Remove lane',
                        onPressed: widget.onDelete,
                        visualDensity: VisualDensity.compact,
                        color: cs.error,
                      ),
                    ],
                  ),
                ),
                // Format chip + hint.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      AppTappable(
                        onTap: _openFormatPicker,
                        child: Chip(
                          avatar: const Icon(Icons.tune, size: 14),
                          label: Text(
                            widget.lane.format.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.10),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '← tap to change',
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                // Drop zone / entrant list.
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: widget.lane.entrants.isEmpty
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            Icon(
                              isDragOver
                                  ? Icons.file_download
                                  : isHighlighted
                                      ? Icons.touch_app_outlined
                                      : Icons.drag_indicator,
                              size: 24,
                              color: isDragOver || isHighlighted
                                  ? AppTheme.primary
                                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isDragOver
                                  ? 'Drop here'
                                  : isHighlighted
                                      ? 'Tap to assign selected entrant'
                                      : 'Long-press drag an entrant here\n(or tap to select, then tap here)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDragOver || isHighlighted
                                      ? AppTheme.primary
                                      : cs.onSurfaceVariant,
                                  fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                          ],
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.lane.entrants
                              .map((e) => _EntrantChip(
                                    entrant: e,
                                    isSelected:
                                        widget.selectedLocalId == e.localId,
                                    inLane: true,
                                    onTap: () => widget.onAssign(
                                        e.localId, widget.lane.localId),
                                  ))
                              .toList(),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Text(
                    widget.lane.entrants.isEmpty
                        ? 'Needs ≥ 2 entrants to generate bracket'
                        : '${widget.lane.entrants.length} entrant${widget.lane.entrants.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 11,
                        color: widget.lane.entrants.isEmpty
                            ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                            : cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Entrant chip — draggable + tappable
// ═══════════════════════════════════════════════════════════════════════════

class _EntrantChip extends StatelessWidget {
  final DraftEntrant entrant;
  final bool isSelected;
  final bool inLane;
  final VoidCallback? onTap;

  const _EntrantChip({
    required this.entrant,
    required this.isSelected,
    this.inLane = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = LongPressDraggable<String>(
      data: entrant.localId,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.05,
          child: _chipWidget(context, dragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _chipWidget(context),
      ),
      child: AppTappable(
        onTap: onTap,
        child: _chipWidget(context),
      ),
    );
    return chip;
  }

  Widget _chipWidget(BuildContext context, {bool dragging = false}) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary
            : inLane
                ? cs.secondaryContainer
                : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppTheme.primary : cs.outlineVariant,
        ),
        boxShadow: dragging
            ? [const BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator,
            size: 12,
            color: isSelected ? Colors.white70 : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            entrant.teamName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Template picker bottom sheet
// ═══════════════════════════════════════════════════════════════════════════

class _TemplatePicker extends StatelessWidget {
  final List<TournamentTemplate> templates;
  const _TemplatePicker({required this.templates});

  @override
  Widget build(BuildContext context) {
    final userTemplates = context.watch<EventProvider>().templates;
    final all = [...templates, ...userTemplates];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Choose format / template',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: all
                  .map((t) => ListTile(
                        leading: Icon(_formatIcon(
                            DivisionFormat.fromString(
                                t.config['format'] as String?))),
                        title: Text(t.name,
                            style: const TextStyle(fontSize: 14)),
                        onTap: () => Navigator.of(context).pop(t),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  IconData _formatIcon(DivisionFormat f) => switch (f) {
        DivisionFormat.singleElimination => Icons.account_tree_outlined,
        DivisionFormat.roundRobin => Icons.swap_horiz,
        DivisionFormat.poolsPlayoff => Icons.grid_view_outlined,
        DivisionFormat.custom => Icons.tune,
      };
}
