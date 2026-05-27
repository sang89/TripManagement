import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../config/api_keys.dart';
import '../l10n/app_localizations.dart';
import '../models/trip_stop.dart';
import '../providers/trip_provider.dart';
import '../services/trip_places_service.dart';
import 'places_autocomplete_field.dart';

/// Opens the stop form sheet.
/// - [tripId] null → draft mode; [onDraftSave] is called instead of the provider.
/// - [tripId] non-null → normal mode; saves directly via TripProvider.
Future<void> showTripStopFormSheet(
  BuildContext context, {
  String? tripId,
  TripStop? existing,
  void Function(TripStop draft)? onDraftSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _TripStopFormSheet(
      tripId: tripId,
      existing: existing,
      onDraftSave: onDraftSave,
    ),
  );
}

class _TripStopFormSheet extends StatefulWidget {
  final String? tripId;
  final TripStop? existing;
  final void Function(TripStop draft)? onDraftSave;

  const _TripStopFormSheet({
    this.tripId,
    this.existing,
    this.onDraftSave,
  });

  @override
  State<_TripStopFormSheet> createState() => _TripStopFormSheetState();
}

class _TripStopFormSheetState extends State<_TripStopFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;
  DateTime? _arriveAt;
  DateTime? _departAt;
  double? _addressLat;
  double? _addressLng;
  bool _loading = false;

  final _places = TripPlacesService(kGooglePlacesApiKey);

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _titleCtrl = TextEditingController(text: s?.title ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _arriveAt = s?.arriveAt;
    _departAt = s?.departAt;
    _addressLat = s?.addressLat;
    _addressLng = s?.addressLng;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isArrival) async {
    final now = DateTime.now();
    final initial =
        (isArrival ? _arriveAt : _departAt) ?? _arriveAt ?? now;
    final firstDate =
        isArrival ? DateTime(2020) : (_arriveAt ?? DateTime(2020));
    final lastDate =
        isArrival ? (_departAt ?? DateTime(2100)) : DateTime(2100);

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
      if (isArrival) {
        _arriveAt = picked;
        if (_departAt != null && !picked.isBefore(_departAt!)) {
          _departAt = null;
        }
      } else {
        _departAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final title = _titleCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    // Draft mode — return data to caller without touching the provider
    if (widget.onDraftSave != null) {
      final draft = TripStop(
        id: widget.existing?.id ?? '',
        tripId: widget.existing?.tripId ?? '',
        title: title,
        address: address,
        notes: notes,
        arriveAt: _arriveAt,
        departAt: _departAt,
        sortOrder: widget.existing?.sortOrder ?? 0,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        addressLat: _addressLat,
        addressLng: _addressLng,
      );
      if (mounted) Navigator.pop(context);
      widget.onDraftSave!(draft);
      return;
    }

    final provider = context.read<TripProvider>();
    if (widget.existing == null) {
      await provider.addStop(
        widget.tripId!,
        title: title,
        address: address,
        notes: notes,
        arriveAt: _arriveAt,
        departAt: _departAt,
        addressLat: _addressLat,
        addressLng: _addressLng,
      );
    } else {
      await provider.updateStop(widget.existing!.copyWith(
        title: title,
        address: address,
        notes: notes,
        arriveAt: _arriveAt,
        departAt: _departAt,
        clearArriveAt: _arriveAt == null,
        clearDepartAt: _departAt == null,
        addressLat: _addressLat,
        addressLng: _addressLng,
        clearAddressLat: _addressLat == null,
        clearAddressLng: _addressLng == null,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(isEdit ? l10n.editStop : l10n.addStopButton,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.stopTitleLabel,
                        prefixIcon: const Icon(Icons.place_outlined),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 12),
                    PlacesAutocompleteField(
                      controller: _addressCtrl,
                      label: l10n.addressOptional,
                      prefixIcon: Icons.location_on_outlined,
                      placesService: _places,
                      onCoordinatesChanged: (lat, lng) => setState(() {
                        _addressLat = lat;
                        _addressLng = lng;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _DateTimeRow(
                      label: l10n.arriveLabel,
                      value: _arriveAt,
                      onTap: () => _pickDateTime(true),
                      onClear: () => setState(() => _arriveAt = null),
                    ),
                    const SizedBox(height: 12),
                    _DateTimeRow(
                      label: l10n.departLabel,
                      value: _departAt,
                      onTap: () => _pickDateTime(false),
                      onClear: () => setState(() => _departAt = null),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.notesOptional,
                        prefixIcon: const Icon(Icons.notes_outlined),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: isEdit ? l10n.saveChanges : l10n.addStopButton,
                      onPressed: _loading ? () {} : _save,
                      loading: _loading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final display = value != null
        ? '${value!.month}/${value!.day}/${value!.year}  '
            '${TimeOfDay.fromDateTime(value!).format(context)}'
        : l10n.notSet;
    return AppTappable(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time_outlined),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(display,
            style: TextStyle(
                color: value != null ? null : Colors.grey[500])),
      ),
    );
  }
}
