import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../config/api_keys.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../models/trip_stop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/trip_places_service.dart';
import '../../widgets/places_autocomplete_field.dart';
import '../../widgets/trip_map_widget.dart';
import '../../widgets/add_member_sheet.dart';
import '../../widgets/trip_stop_form_sheet.dart';

class TripFormScreen extends StatefulWidget {
  final String? tripId;

  const TripFormScreen({super.key, this.tripId});

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _startLocationCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _startAt;
  DateTime? _endAt;
  bool _loading = false;
  String? _error;
  double? _startLat;
  double? _startLng;
  double? _destinationLat;
  double? _destinationLng;

  Trip? _existing;
  List<TripMember> _pendingMembers = [];
  List<TripStop> _pendingStops = [];
  // userIds that were re-invited in this edit session (left→pending).
  final Set<String> _reinvitedUserIds = {};

  final _places = TripPlacesService(kGooglePlacesApiKey);

  bool get _isEdit => widget.tripId != null;

  // Pin order: start → stops (sorted) → destination — matches driving direction.
  List<TripMapPin> get _mapPins {
    final pins = <TripMapPin>[];
    if (_startLat != null && _startLng != null) {
      pins.add(TripMapPin(
        id: 'start',
        position: LatLng(_startLat!, _startLng!),
        title: _startLocationCtrl.text.isEmpty
            ? 'Start'
            : _startLocationCtrl.text,
        isStart: true,
      ));
    }
    for (int i = 0; i < _sortedStops.length; i++) {
      final s = _sortedStops[i];
      if (s.addressLat != null && s.addressLng != null) {
        pins.add(TripMapPin(
          id: 'stop_$i',
          position: LatLng(s.addressLat!, s.addressLng!),
          title: s.title,
          subtitle: s.address.isNotEmpty ? s.address : null,
        ));
      }
    }
    if (_destinationLat != null && _destinationLng != null) {
      pins.add(TripMapPin(
        id: 'destination',
        position: LatLng(_destinationLat!, _destinationLng!),
        title: _destinationCtrl.text.isEmpty
            ? 'Destination'
            : _destinationCtrl.text,
        isDestination: true,
      ));
    }
    return pins;
  }

  List<TripStop> get _sortedStops {
    final sorted = List.of(_pendingStops);
    sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  void _onReorderStops(int oldIndex, int newIndex) {
    setState(() {
      final ordered = List.of(_sortedStops);
      final moved = ordered.removeAt(oldIndex);
      ordered.insert(newIndex, moved);
      _pendingStops = ordered
          .asMap()
          .entries
          .map((e) => e.value.copyWith(sortOrder: e.key))
          .toList();
    });
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  void _loadExisting() {
    final trip = context.read<TripProvider>().getById(widget.tripId!);
    if (trip == null) return;
    _existing = trip;
    _titleCtrl.text = trip.title;
    _startLocationCtrl.text = trip.startLocation ?? '';
    _destinationCtrl.text = trip.destination;
    _notesCtrl.text = trip.notes;
    setState(() {
      _startAt = trip.startAt;
      _endAt = trip.endAt;
      _startLat = trip.startLat;
      _startLng = trip.startLng;
      _destinationLat = trip.destinationLat;
      _destinationLng = trip.destinationLng;
      _pendingMembers = List.of(trip.members);
      _pendingStops = List.of(trip.stops);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _startLocationCtrl.dispose();
    _destinationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initial = (isStart ? _startAt : _endAt) ?? _startAt ?? now;
    // End date can't be before start; start date can't be after end
    final firstDate = isStart ? DateTime(2020) : (_startAt ?? DateTime(2020));
    final lastDate = isStart ? (_endAt ?? DateTime(2100)) : DateTime(2100);

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startAt = picked;
        // If new start is at or after existing end, clear end so user re-picks
        if (_endAt != null && !picked.isBefore(_endAt!)) _endAt = null;
      } else {
        _endAt = picked;
      }
    });
  }

  void _openAddStopSheet({TripStop? existing}) {
    final idx = existing != null
        ? _pendingStops.indexWhere(
            (s) => s.id == existing.id && s.title == existing.title)
        : -1;

    showTripStopFormSheet(
      context,
      existing: existing,
      onDraftSave: (draft) {
        setState(() {
          final saved = TripStop(
            id: existing?.id ?? '',
            tripId: existing?.tripId ?? '',
            title: draft.title,
            address: draft.address,
            notes: draft.notes,
            arriveAt: draft.arriveAt,
            departAt: draft.departAt,
            sortOrder: existing?.sortOrder ?? _pendingStops.length,
            createdAt: existing?.createdAt ?? draft.createdAt,
            addressLat: draft.addressLat,
            addressLng: draft.addressLng,
          );
          if (idx >= 0) {
            _pendingStops[idx] = saved;
          } else {
            _pendingStops.add(saved);
          }
        });
      },
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_startAt != null && _endAt != null && !_endAt!.isAfter(_startAt!)) {
      setState(() => _error = l10n.endDateAfterStart);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<TripProvider>();

      if (_isEdit && _existing != null) {
        final startLocText = _startLocationCtrl.text.trim();
        final updated = _existing!.copyWith(
          title: _titleCtrl.text.trim(),
          startLocation: startLocText.isEmpty ? null : startLocText,
          clearStartLocation: startLocText.isEmpty,
          startLat: _startLat,
          clearStartLat: _startLat == null,
          startLng: _startLng,
          clearStartLng: _startLng == null,
          destination: _destinationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          destinationLat: _destinationLat,
          destinationLng: _destinationLng,
        );
        await provider.updateTrip(updated);

        // Sync members
        final existingMemberIds =
            _existing!.members.map((m) => m.id).toSet();
        final pendingMemberIds = _pendingMembers.map((m) => m.id).toSet();
        for (final m in _existing!.members) {
          if (!pendingMemberIds.contains(m.id)) {
            await provider.removeMember(m.id, widget.tripId!);
          }
        }
        for (final m in _pendingMembers) {
          if (!existingMemberIds.contains(m.id)) {
            await provider.addMember(widget.tripId!,
                displayName: m.displayName,
                email: m.email,
                phone: m.phone,
                userId: m.userId);
          }
        }

        // Re-invite members whose status was changed from 'left'/'declined' to
        // 'pending' in this session (upsert reactivates the existing DB row and
        // fires the invite notification via the extended trigger).
        for (final m in _pendingMembers) {
          if (m.userId != null && _reinvitedUserIds.contains(m.userId)) {
            await provider.addMember(widget.tripId!,
                displayName: m.displayName,
                email: m.email,
                phone: m.phone,
                userId: m.userId);
          }
        }

        // Sync stops: delete removed, add new drafts, update edited existing
        final existingStopIds = _existing!.stops.map((s) => s.id).toSet();
        final pendingExistingIds = _pendingStops
            .where((s) => s.id.isNotEmpty)
            .map((s) => s.id)
            .toSet();
        for (final id in existingStopIds) {
          if (!pendingExistingIds.contains(id)) {
            await provider.deleteStop(id, widget.tripId!);
          }
        }
        for (final s in _pendingStops) {
          if (s.id.isEmpty) {
            await provider.addStop(widget.tripId!,
                title: s.title,
                address: s.address,
                notes: s.notes,
                arriveAt: s.arriveAt,
                departAt: s.departAt,
                sortOrder: s.sortOrder,
                addressLat: s.addressLat,
                addressLng: s.addressLng);
          } else if (existingStopIds.contains(s.id)) {
            await provider.updateStop(s);
          }
        }

        if (mounted) context.pop();
      } else {
        final startLocText = _startLocationCtrl.text.trim();
        final trip = await provider.addTrip(
          title: _titleCtrl.text.trim(),
          startLocation: startLocText.isEmpty ? null : startLocText,
          startLat: _startLat,
          startLng: _startLng,
          destination: _destinationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          destinationLat: _destinationLat,
          destinationLng: _destinationLng,
        );
        for (final m in _pendingMembers) {
          await provider.addMember(trip.id,
              displayName: m.displayName,
              email: m.email,
              phone: m.phone,
              userId: m.userId);
        }
        for (int i = 0; i < _sortedStops.length; i++) {
          final s = _sortedStops[i];
          await provider.addStop(trip.id,
              title: s.title,
              address: s.address,
              notes: s.notes,
              arriveAt: s.arriveAt,
              departAt: s.departAt,
              sortOrder: i,
              addressLat: s.addressLat,
              addressLng: s.addressLng);
        }
        if (mounted) context.go('/trip/${trip.id}');
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _loading = false;
        _error = e is ReinviteBlockedException
            ? l10n.reinviteBlockedError
            : e.toString();
      });
    }
  }

  void _openAddMemberSheet() {
    showAddMemberSheet(
      context,
      onAdd: (draft) => setState(() {
        if (draft.userId != null) {
          // Check if this user already has a row in the form (e.g. status='left'
          // or 'declined'). If so, update in-place instead of adding a duplicate.
          final existingIdx = _pendingMembers.indexWhere(
            (m) =>
                m.userId == draft.userId &&
                (m.status == 'left' || m.status == 'declined'),
          );
          if (existingIdx >= 0) {
            _reinvitedUserIds.add(draft.userId!);
            _pendingMembers[existingIdx] =
                _pendingMembers[existingIdx].copyWith(
              displayName: draft.displayName,
              status: 'pending',
            );
            return;
          }
          // Don't add a duplicate if already pending/accepted.
          if (_pendingMembers.any((m) => m.userId == draft.userId)) return;
        }
        _pendingMembers.add(draft);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUid = context.read<AuthProvider>().userId;
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('MMM d, y  h:mm a');
    final timeFmt = DateFormat('MMM d  h:mm a');
    final sorted = _sortedStops;

    return PopScope(
      // Never allow the system back gesture / button to pop by itself.
      // Instead, auto-save if the required fields are filled; otherwise
      // discard and pop (avoids showing validation errors during back-nav).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _loading) return;
        final canSave = _titleCtrl.text.trim().isNotEmpty &&
            _destinationCtrl.text.trim().isNotEmpty;
        if (canSave) {
          await _save();
        } else {
          // Required fields empty — just discard and go back.
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editTrip : l10n.newTrip),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
          Expanded(child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: l10n.tripTitle,
                prefixIcon: const Icon(Icons.flight_takeoff_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 16),

            // Start location — optional Places autocomplete
            PlacesAutocompleteField(
              controller: _startLocationCtrl,
              label: l10n.startingFromLabel,
              prefixIcon: Icons.trip_origin_outlined,
              placesService: _places,
              onCoordinatesChanged: (lat, lng) => setState(() {
                _startLat = lat;
                _startLng = lng;
              }),
            ),
            const SizedBox(height: 16),

            // Destination — inline Places autocomplete
            PlacesAutocompleteField(
              controller: _destinationCtrl,
              label: l10n.destinationLabel,
              prefixIcon: Icons.location_on_outlined,
              placesService: _places,
              onCoordinatesChanged: (lat, lng) => setState(() {
                _destinationLat = lat;
                _destinationLng = lng;
              }),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 16),

            // Dates
            _DateTimeTile(
              label: l10n.startLabel,
              value: _startAt,
              display: _startAt != null
                  ? fmt.format(_startAt!)
                  : l10n.setStartDateTime,
              onTap: () => _pickDateTime(true),
            ),
            const SizedBox(height: 12),
            _DateTimeTile(
              label: l10n.endLabel,
              value: _endAt,
              display: _endAt != null
                  ? fmt.format(_endAt!)
                  : l10n.setEndDateTime,
              onTap: () => _pickDateTime(false),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: l10n.notesOptional,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
              maxLines: 4,
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      const TextStyle(color: AppTheme.danger, fontSize: 13),
                  textAlign: TextAlign.center),
            ],

            // ── Stops ──────────────────────────────────────────────────────
            const SizedBox(height: 28),
            Row(
              children: [
                Text(l10n.stopsSection,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openAddStopSheet(),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.addStop),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.noStopsYet,
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 13)),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                onReorderItem: _onReorderStops,
                itemBuilder: (context, index) {
                  final stop = sorted[index];
                  final timeLabel = stop.arriveAt != null
                      ? timeFmt.format(stop.arriveAt!)
                      : null;
                  return ListTile(
                    key: ValueKey(
                        'stop_${stop.id}_${stop.createdAt.millisecondsSinceEpoch}'),
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      radius: 18,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    title: Text(stop.title,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stop.address.isNotEmpty)
                          Text(stop.address,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        if (timeLabel != null)
                          Text(timeLabel,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.drag_handle,
                                color: Colors.grey, size: 20),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: AppTheme.primary),
                          onPressed: () =>
                              _openAddStopSheet(existing: stop),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.danger),
                          onPressed: () =>
                              setState(() => _pendingStops.remove(stop)),
                        ),
                      ],
                    ),
                    dense: true,
                  );
                },
              ),

            // ── Map preview ────────────────────────────────────────────────
            const SizedBox(height: 28),
            Text(l10n.mapSection,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TripMapWidget(pins: _mapPins, compact: true),

            // ── Members ────────────────────────────────────────────────────
            const SizedBox(height: 28),
            Row(
              children: [
                Text(l10n.membersSection,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primary, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openAddMemberSheet,
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: Text(l10n.addMember),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_isEdit)
              ..._existingMemberTiles(context, authUid)
            else ...[
              _youOrganizerTile(context),
              ..._pendingMemberTiles(context),
            ],
            const SizedBox(height: 8),
          ],
        )), // Expanded + ListView
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AppButton(
                label: _isEdit ? l10n.saveChanges : l10n.saveTrip,
                onPressed: _save,
                loading: _loading,
              ),
            ),
          ),
        ], // Column children
      ), // Column
      ),
    ), // PopScope
    );
  }

  Widget _youOrganizerTile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
          backgroundColor: AppTheme.primary,
          child: Icon(Icons.person, color: Colors.white, size: 18)),
      title: Text(l10n.you),
      subtitle: Text(l10n.organizer),
      dense: true,
    );
  }

  List<Widget> _pendingMemberTiles(BuildContext context) {
    return _pendingMembers.map((m) {
      final detail = [
        if (m.email != null) m.email!,
        if (m.phone != null) m.phone!,
      ].join(' · ');
      final hasAvatar = m.avatarUrl != null && m.avatarUrl!.isNotEmpty;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          backgroundImage: hasAvatar ? NetworkImage(m.avatarUrl!) : null,
          child: hasAvatar
              ? null
              : Text(m.displayName[0].toUpperCase(),
                  style: const TextStyle(color: AppTheme.primary)),
        ),
        title: Text(m.displayName),
        subtitle: detail.isNotEmpty ? Text(detail) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.userId != null)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.link, size: 16, color: AppTheme.accent),
              ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppTheme.danger, size: 20),
              onPressed: () => setState(() => _pendingMembers.remove(m)),
            ),
          ],
        ),
        dense: true,
      );
    }).toList();
  }

  List<Widget> _existingMemberTiles(BuildContext context, String? authUid) {
    final l10n = AppLocalizations.of(context);
    return _pendingMembers.map((m) {
      final isMe = m.userId == authUid;
      final roleLabel =
          m.role == 'organizer' ? l10n.organizer : l10n.member;
      final contact = [
        if (m.email != null) m.email!,
        if (m.phone != null) m.phone!,
      ].join(' · ');
      final subtitleText =
          contact.isNotEmpty ? '$roleLabel · $contact' : roleLabel;
      final hasAvatar = m.avatarUrl != null && m.avatarUrl!.isNotEmpty;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor:
              m.role == 'organizer' ? AppTheme.primary : Colors.grey[200],
          backgroundImage: hasAvatar ? NetworkImage(m.avatarUrl!) : null,
          child: hasAvatar
              ? null
              : Text(m.displayName[0].toUpperCase(),
                  style: TextStyle(
                      color: m.role == 'organizer'
                          ? Colors.white
                          : AppTheme.primary)),
        ),
        title: Text(isMe ? l10n.you : m.displayName),
        subtitle: Text(subtitleText),
        trailing: isMe
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.userId != null)
                    _StatusChip(
                      label: switch (m.status) {
                        'pending' => l10n.invitePending,
                        'declined' => l10n.inviteDeclined,
                        'left' => l10n.memberLeft,
                        _ => l10n.inviteAccepted,
                      },
                      color: switch (m.status) {
                        'pending' => Colors.orange,
                        'declined' => AppTheme.danger,
                        'left' => Colors.grey,
                        _ => Colors.green,
                      },
                    ),
                  if (m.status != 'left')
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppTheme.danger, size: 20),
                      onPressed: () =>
                          setState(() => _pendingMembers.remove(m)),
                    ),
                ],
              ),
        dense: true,
      );
    }).toList();
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String display;
  final VoidCallback onTap;

  const _DateTimeTile(
      {required this.label,
      required this.value,
      required this.display,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(display,
            style:
                TextStyle(color: value != null ? null : Colors.grey[500])),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
