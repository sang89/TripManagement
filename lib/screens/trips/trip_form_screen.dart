import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../config/api_keys.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../models/trip_stop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/trip_places_service.dart';
import '../../widgets/places_autocomplete_field.dart';
import '../../widgets/trip_map_widget.dart';
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
  final _destinationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _startAt;
  DateTime? _endAt;
  bool _loading = false;
  String? _error;
  double? _destinationLat;
  double? _destinationLng;

  Trip? _existing;
  List<TripMember> _pendingMembers = [];
  List<TripStop> _pendingStops = [];

  final _places = TripPlacesService(kGooglePlacesApiKey);

  bool get _isEdit => widget.tripId != null;

  List<TripMapPin> get _mapPins {
    final pins = <TripMapPin>[];
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
    _destinationCtrl.text = trip.destination;
    _notesCtrl.text = trip.notes;
    setState(() {
      _startAt = trip.startAt;
      _endAt = trip.endAt;
      _destinationLat = trip.destinationLat;
      _destinationLng = trip.destinationLng;
      _pendingMembers = List.of(trip.members);
      _pendingStops = List.of(trip.stops);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
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
        ? _pendingStops.indexWhere((s) => s.id == existing.id && s.title == existing.title)
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
    if (!_formKey.currentState!.validate()) return;
    if (_startAt != null && _endAt != null && !_endAt!.isAfter(_startAt!)) {
      setState(() => _error = 'End date must be after start date.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final provider = context.read<TripProvider>();

      if (_isEdit && _existing != null) {
        final updated = _existing!.copyWith(
          title: _titleCtrl.text.trim(),
          destination: _destinationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          destinationLat: _destinationLat,
          destinationLng: _destinationLng,
        );
        await provider.updateTrip(updated);

        // Sync members
        final existingMemberIds = _existing!.members.map((m) => m.id).toSet();
        final pendingMemberIds = _pendingMembers.map((m) => m.id).toSet();
        for (final m in _existing!.members) {
          if (!pendingMemberIds.contains(m.id)) {
            await provider.removeMember(m.id, widget.tripId!);
          }
        }
        for (final m in _pendingMembers) {
          if (!existingMemberIds.contains(m.id)) {
            await provider.addMember(widget.tripId!,
                displayName: m.displayName, email: m.email, phone: m.phone);
          }
        }

        // Sync stops: delete removed, add new drafts, update edited existing
        final existingStopIds = _existing!.stops.map((s) => s.id).toSet();
        final pendingExistingIds =
            _pendingStops.where((s) => s.id.isNotEmpty).map((s) => s.id).toSet();
        for (final id in existingStopIds) {
          if (!pendingExistingIds.contains(id)) {
            await provider.deleteStop(id, widget.tripId!);
          }
        }
        for (final s in _pendingStops) {
          if (s.id.isEmpty) {
            await provider.addStop(widget.tripId!,
                title: s.title, address: s.address, notes: s.notes,
                arriveAt: s.arriveAt, departAt: s.departAt,
                sortOrder: s.sortOrder,
                addressLat: s.addressLat, addressLng: s.addressLng);
          } else if (existingStopIds.contains(s.id)) {
            await provider.updateStop(s);
          }
        }

        if (mounted) context.pop();
      } else {
        final trip = await provider.addTrip(
          title: _titleCtrl.text.trim(),
          destination: _destinationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          destinationLat: _destinationLat,
          destinationLng: _destinationLng,
        );
        for (final m in _pendingMembers) {
          await provider.addMember(trip.id,
              displayName: m.displayName, email: m.email, phone: m.phone);
        }
        for (int i = 0; i < _sortedStops.length; i++) {
          final s = _sortedStops[i];
          await provider.addStop(trip.id,
              title: s.title, address: s.address, notes: s.notes,
              arriveAt: s.arriveAt, departAt: s.departAt, sortOrder: i,
              addressLat: s.addressLat, addressLng: s.addressLng);
        }
        if (mounted) context.go('/trip/${trip.id}');
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _openAddMemberSheet() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String phone = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('Add member',
                        style: Theme.of(ctx).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppPhoneField(
                      label: 'Phone (optional)',
                      onChanged: (v) => phone = v,
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Add member',
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        setState(() {
                          _pendingMembers.add(TripMember(
                            id: '',
                            tripId: '',
                            displayName: name,
                            role: 'member',
                            email: emailCtrl.text.trim().isEmpty
                                ? null
                                : emailCtrl.text.trim(),
                            phone: phone.isEmpty ? null : phone,
                            createdAt: DateTime.now(),
                          ));
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUid = context.read<AuthProvider>().userId;
    final fmt = DateFormat('MMM d, y  h:mm a');
    final timeFmt = DateFormat('MMM d  h:mm a');
    final sorted = _sortedStops;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit trip' : 'New trip'),
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
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Trip title',
                prefixIcon: Icon(Icons.flight_takeoff_rounded),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Destination — inline Places autocomplete
            PlacesAutocompleteField(
              controller: _destinationCtrl,
              label: 'Destination',
              prefixIcon: Icons.location_on_outlined,
              placesService: _places,
              onCoordinatesChanged: (lat, lng) => setState(() {
                _destinationLat = lat;
                _destinationLng = lng;
              }),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Dates
            _DateTimeTile(
              label: 'Start',
              value: _startAt,
              display: _startAt != null
                  ? fmt.format(_startAt!)
                  : 'Set start date & time',
              onTap: () => _pickDateTime(true),
            ),
            const SizedBox(height: 12),
            _DateTimeTile(
              label: 'End',
              value: _endAt,
              display: _endAt != null
                  ? fmt.format(_endAt!)
                  : 'Set end date & time',
              onTap: () => _pickDateTime(false),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
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
                Text('Stops',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openAddStopSheet(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add stop'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No stops added yet.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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
                          onPressed: () => _openAddStopSheet(existing: stop),
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
            Text('Map',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TripMapWidget(pins: _mapPins, compact: true),

            // ── Members ────────────────────────────────────────────────────
            const SizedBox(height: 28),
            Row(
              children: [
                Text('Members',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primary, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openAddMemberSheet,
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('Add member'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_isEdit)
              ..._existingMemberTiles(authUid)
            else ...[
              _youOrganizerTile(),
              ..._pendingMemberTiles(),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: _isEdit ? 'Save changes' : 'Save trip',
              onPressed: _save,
              loading: _loading,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _youOrganizerTile() => const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
            backgroundColor: AppTheme.primary,
            child: Icon(Icons.person, color: Colors.white, size: 18)),
        title: Text('You'),
        subtitle: Text('Organizer'),
        dense: true,
      );

  List<Widget> _pendingMemberTiles() => _pendingMembers.map((m) {
        final detail = [
          if (m.email != null) m.email!,
          if (m.phone != null) m.phone!,
        ].join(' · ');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            child: Text(m.displayName[0].toUpperCase(),
                style: const TextStyle(color: AppTheme.primary)),
          ),
          title: Text(m.displayName),
          subtitle: detail.isNotEmpty ? Text(detail) : null,
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: AppTheme.danger, size: 20),
            onPressed: () => setState(() => _pendingMembers.remove(m)),
          ),
          dense: true,
        );
      }).toList();

  List<Widget> _existingMemberTiles(String? authUid) =>
      _pendingMembers.map((m) {
        final isMe = m.userId == authUid;
        final roleLabel = m.role == 'organizer' ? 'Organizer' : 'Member';
        final contact = [
          if (m.email != null) m.email!,
          if (m.phone != null) m.phone!,
        ].join(' · ');
        final subtitleText = contact.isNotEmpty ? '$roleLabel · $contact' : roleLabel;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor:
                m.role == 'organizer' ? AppTheme.primary : Colors.grey[200],
            child: Text(m.displayName[0].toUpperCase(),
                style: TextStyle(
                    color: m.role == 'organizer'
                        ? Colors.white
                        : AppTheme.primary)),
          ),
          title: Text(isMe ? 'You' : m.displayName),
          subtitle: Text(subtitleText),
          trailing: isMe
              ? null
              : IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.danger, size: 20),
                  onPressed: () =>
                      setState(() => _pendingMembers.remove(m)),
                ),
          dense: true,
        );
      }).toList();
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
