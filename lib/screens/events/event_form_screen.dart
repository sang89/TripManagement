import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../config/api_keys.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../services/trip_places_service.dart';
import '../../widgets/event_type_banner.dart';
import '../../widgets/places_autocomplete_field.dart';

class EventFormScreen extends StatefulWidget {
  final String? eventId;
  final EventType? defaultEventType;

  const EventFormScreen({super.key, this.eventId, this.defaultEventType});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _startLocationCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _honoreeNameCtrl = TextEditingController();
  final _birthYearCtrl = TextEditingController();

  DateTime? _startAt;
  DateTime? _endAt;
  double? _locationLat;
  double? _locationLng;
  double? _startLat;
  double? _startLng;
  EventType? _eventType;

  // Quick Bites fields
  List<String> _cuisineTags = [];
  DateTime? _rsvpDeadline;
  String? _vibe;

  // Signup fields
  bool _waitlistEnabled = true;
  int? _signupLockHours;

  bool _loading = false;
  String? _error;
  bool _triedToSave = false;

  Event? _existing;
  final _places = TripPlacesService(kGooglePlacesApiKey);
  bool get _isEdit => widget.eventId != null;
  bool get _isTrip => _eventType == EventType.trip;
  bool get _isQuickBites => _eventType == EventType.quickBites;
  bool get _isBirthday => _eventType == EventType.birthday;
  bool get _isSignup => _eventType == EventType.signup;

  static const _kCuisineTags = [
    'Asian', 'Italian', 'Mexican', 'Japanese', 'Chinese',
    'Indian', 'American', 'BBQ', 'Seafood', 'Brunch',
    'Street Food', 'Dessert',
  ];

  static const _kVibes = [
    'Just catching up',
    'Post-work treat',
    'Work lunch',
    'Celebrating something',
    'Post-workout fuel',
    'Hangover cure',
    'No reason needed',
  ];

  @override
  void initState() {
    super.initState();
    _eventType = widget.defaultEventType; // null = no selection on new events
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  void _loadExisting() {
    final event = context.read<EventProvider>().getById(widget.eventId!);
    if (event == null) return;
    _existing = event;
    _titleCtrl.text = event.title;
    _descriptionCtrl.text = event.description;
    _locationCtrl.text = event.location;
    _startLocationCtrl.text = event.startLocation ?? '';
    _capacityCtrl.text = event.capacity?.toString() ?? '';
    _budgetCtrl.text = event.budgetPerHead?.toStringAsFixed(2) ?? '';
    _honoreeNameCtrl.text = event.honoreeDisplayName ?? '';
    _birthYearCtrl.text = event.birthYear?.toString() ?? '';
    setState(() {
      _startAt = event.startAt;
      _endAt = event.endAt;
      _locationLat = event.locationLat;
      _locationLng = event.locationLng;
      _startLat = event.startLat;
      _startLng = event.startLng;
      _eventType = event.eventType;
      _cuisineTags = List<String>.from(event.cuisineTags);
      _rsvpDeadline = event.rsvpDeadline;
      _vibe = event.vibe;
      _waitlistEnabled = event.waitlistEnabled;
      _signupLockHours = event.signupLockHours;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _startLocationCtrl.dispose();
    _capacityCtrl.dispose();
    _budgetCtrl.dispose();
    _honoreeNameCtrl.dispose();
    _birthYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRsvpDeadline() async {
    final now = DateTime.now();
    final initial = _rsvpDeadline ?? _startAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _rsvpDeadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initial = (isStart ? _startAt : _endAt) ?? _startAt ?? now;
    final firstDate =
        isStart ? DateTime(2020) : (_startAt ?? DateTime(2020));
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
        if (_endAt != null && !picked.isBefore(_endAt!)) _endAt = null;
      } else {
        _endAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_eventType == null) {
      setState(() => _triedToSave = true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_startAt == null) {
      setState(() => _error = l10n.required);
      return;
    }
    if (_startAt != null && _endAt != null && !_endAt!.isAfter(_startAt!)) {
      setState(() => _error = l10n.endDateAfterStart);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<EventProvider>();
      final capacity = _capacityCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_capacityCtrl.text.trim());
      final startLocation =
          _isTrip && _startLocationCtrl.text.trim().isNotEmpty
              ? _startLocationCtrl.text.trim()
              : null;
      final budgetPerHead = _isQuickBites && _budgetCtrl.text.trim().isNotEmpty
          ? double.tryParse(_budgetCtrl.text.trim())
          : null;
      final honoreeDisplayName = _isBirthday &&
              _honoreeNameCtrl.text.trim().isNotEmpty
          ? _honoreeNameCtrl.text.trim()
          : null;
      final birthYear = _isBirthday && _birthYearCtrl.text.trim().isNotEmpty
          ? int.tryParse(_birthYearCtrl.text.trim())
          : null;

      if (_isEdit && _existing != null) {
        final updated = _existing!.copyWith(
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          locationLat: _locationLat,
          clearLocationLat: _locationLat == null,
          locationLng: _locationLng,
          clearLocationLng: _locationLng == null,
          startAt: _startAt!,
          endAt: _endAt,
          clearEndAt: _endAt == null,
          capacity: capacity,
          clearCapacity: capacity == null,
          eventType: _eventType!,
          startLocation: startLocation,
          clearStartLocation: startLocation == null,
          startLat: _isTrip ? _startLat : null,
          clearStartLat: !_isTrip || _startLat == null,
          startLng: _isTrip ? _startLng : null,
          clearStartLng: !_isTrip || _startLng == null,
          budgetPerHead: budgetPerHead,
          clearBudgetPerHead: budgetPerHead == null,
          cuisineTags: _isQuickBites ? _cuisineTags : [],
          rsvpDeadline: _isQuickBites ? _rsvpDeadline : null,
          clearRsvpDeadline: !_isQuickBites || _rsvpDeadline == null,
          vibe: _isQuickBites ? _vibe : null,
          clearVibe: !_isQuickBites || _vibe == null,
          honoreeDisplayName: honoreeDisplayName,
          clearHonoreeName: !_isBirthday || honoreeDisplayName == null,
          birthYear: birthYear,
          clearBirthYear: !_isBirthday || birthYear == null,
          waitlistEnabled: _isSignup ? _waitlistEnabled : true,
          signupLockHours: _isSignup ? _signupLockHours : null,
          clearSignupLockHours: !_isSignup || _signupLockHours == null,
        );
        await provider.updateEvent(updated);
        if (mounted) context.pop();
      } else {
        final event = await provider.addEvent(
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          locationLat: _locationLat,
          locationLng: _locationLng,
          startAt: _startAt!,
          endAt: _endAt,
          capacity: capacity,
          eventType: _eventType!,
          startLocation: startLocation,
          startLat: _isTrip ? _startLat : null,
          startLng: _isTrip ? _startLng : null,
          budgetPerHead: budgetPerHead,
          cuisineTags: _isQuickBites ? _cuisineTags : [],
          rsvpDeadline: _isQuickBites ? _rsvpDeadline : null,
          vibe: _isQuickBites ? _vibe : null,
          honoreeDisplayName: _isBirthday ? honoreeDisplayName : null,
          birthYear: _isBirthday ? birthYear : null,
          waitlistEnabled: _isSignup ? _waitlistEnabled : true,
          signupLockHours: _isSignup ? _signupLockHours : null,
        );
        if (mounted) context.go('/event/${event.id}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _eventTypeLabel(EventType type, AppLocalizations l10n) =>
      switch (type) {
        EventType.trip => l10n.eventTypeTrip,
        EventType.birthday => l10n.eventTypeBirthday,
        EventType.wedding => l10n.eventTypeWedding,
        EventType.social => l10n.eventTypeSocial,
        EventType.quickBites => l10n.eventTypeQuickBites,
        EventType.signup => l10n.eventTypeSignup,
      };

  IconData _eventTypeIcon(EventType type) => switch (type) {
        EventType.trip => Icons.luggage_outlined,
        EventType.birthday => Icons.cake_outlined,
        EventType.wedding => Icons.favorite_outline,
        EventType.social => Icons.celebration_outlined,
        EventType.quickBites => Icons.restaurant_outlined,
        EventType.signup => Icons.how_to_reg_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('MMM d, y  h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editEvent : l10n.newEvent),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Event type card grid
                  _EventTypePicker(
                    selected: _eventType,
                    labelOf: (t) => _eventTypeLabel(t, l10n),
                    onChanged: (t) => setState(() {
                      _eventType = t;
                      _triedToSave = false;
                    }),
                  ),

                  // Inline error when user tries to save without a type.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: _triedToSave && _eventType == null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 14, color: AppTheme.danger),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.pleaseSelectEventType,
                                  style: const TextStyle(
                                      color: AppTheme.danger, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),

                  // Title *
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.eventTitle),
                          const Text(' *',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      prefixIcon: Icon(_eventType != null
                          ? _eventTypeIcon(_eventType!)
                          : Icons.event_outlined),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 16),

                  // Description (optional)
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.eventDescription,
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Start location (trip only)
                  if (_isTrip) ...[
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
                  ],

                  // Location / Destination *
                  PlacesAutocompleteField(
                    controller: _locationCtrl,
                    label: _isTrip
                        ? l10n.destinationLabel
                        : l10n.eventLocation,
                    required: true,
                    prefixIcon: Icons.location_on_outlined,
                    placesService: _places,
                    onCoordinatesChanged: (lat, lng) => setState(() {
                      _locationLat = lat;
                      _locationLng = lng;
                    }),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 16),

                  // Start date/time *
                  _DateTimeTile(
                    label: l10n.eventStartDateTime,
                    isRequired: true,
                    value: _startAt,
                    display: _startAt != null
                        ? fmt.format(_startAt!)
                        : l10n.setStartDateTime,
                    onTap: () => _pickDateTime(true),
                  ),
                  const SizedBox(height: 12),

                  // End date/time (optional)
                  _DateTimeTile(
                    label: l10n.eventEndDateTime,
                    value: _endAt,
                    display:
                        _endAt != null ? fmt.format(_endAt!) : l10n.notSet,
                    onTap: () => _pickDateTime(false),
                  ),
                  const SizedBox(height: 16),

                  // Capacity (optional)
                  TextFormField(
                    controller: _capacityCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.eventCapacity,
                      prefixIcon: const Icon(Icons.group_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1) return l10n.required;
                      return null;
                    },
                  ),

                  // ── Quick Bites-only fields ──────────────────────────────
                  if (_isQuickBites) ...[
                    const SizedBox(height: 16),

                    // Budget per head
                    TextFormField(
                      controller: _budgetCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.budgetPerHeadLabel,
                        prefixIcon:
                            const Icon(Icons.attach_money_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return l10n.required;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Vibe picker
                    AppPickerField<String>(
                      label: l10n.vibePickerLabel,
                      value: _vibe,
                      items: _kVibes,
                      labelOf: (v) => v,
                      onChanged: (v) => setState(() => _vibe = v),
                    ),
                    const SizedBox(height: 16),

                    // RSVP deadline
                    _DateTimeTile(
                      label: l10n.rsvpDeadlineLabel,
                      value: _rsvpDeadline,
                      display: _rsvpDeadline != null
                          ? fmt.format(_rsvpDeadline!)
                          : l10n.notSet,
                      onTap: _pickRsvpDeadline,
                    ),
                    const SizedBox(height: 16),

                    // Cuisine tags
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.cuisineTagsLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _kCuisineTags.map((tag) {
                        final selected = _cuisineTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (on) => setState(() {
                            if (on) {
                              _cuisineTags = [..._cuisineTags, tag];
                            } else {
                              _cuisineTags = _cuisineTags
                                  .where((t) => t != tag)
                                  .toList();
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ],

                  // ── Birthday-only fields ─────────────────────────────────
                  if (_isBirthday) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _honoreeNameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.honoreeNameLabel,
                        hintText: l10n.honoreeNameHint,
                        prefixIcon: const Icon(Icons.cake_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _birthYearCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.birthYearLabel,
                        hintText: l10n.birthYearHint,
                        prefixIcon: const Icon(Icons.cake_rounded),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        final currentYear = DateTime.now().year;
                        if (n == null || n < 1900 || n > currentYear) {
                          return l10n.required;
                        }
                        return null;
                      },
                    ),
                  ],

                  // ── Signup-only fields ───────────────────────────────────
                  if (_isSignup) ...[
                    const SizedBox(height: 16),

                    // Waitlist toggle
                    SwitchListTile(
                      value: _waitlistEnabled,
                      onChanged: (v) => setState(() => _waitlistEnabled = v),
                      title: Text(l10n.signupWaitlistEnabled),
                      subtitle: Text(l10n.signupWaitlistDescription,
                          style: const TextStyle(fontSize: 12)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),

                    // Lock hours
                    TextFormField(
                      initialValue: _signupLockHours?.toString() ?? '',
                      decoration: InputDecoration(
                        labelText: 'Lock signups (hours before start)',
                        hintText: 'e.g. 2 — no changes 2 h before start',
                        prefixIcon: const Icon(Icons.lock_clock_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() {
                        _signupLockHours =
                            v.trim().isEmpty ? null : int.tryParse(v.trim());
                      }),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 1) return l10n.required;
                        return null;
                      },
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(
                            color: AppTheme.danger, fontSize: 13),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: AppButton(
                  label: _isEdit ? l10n.saveChanges : l10n.saveEvent,
                  onPressed: _save,
                  loading: _loading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String display;
  final VoidCallback onTap;
  final bool isRequired;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.display,
    required this.onTap,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) => AppTappable(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            label: isRequired
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label),
                    const Text(' *', style: TextStyle(color: Colors.red)),
                  ])
                : Text(label),
            prefixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            display,
            style: TextStyle(color: value != null ? null : Colors.grey[500]),
          ),
        ),
      );
}

// ── Event type picker ─────────────────────────────────────────────────────────
//
// Unselected state: full 2-col grid so each tile is easy to tap.
// Selected state: collapses to a compact single-row horizontal strip so the
//   rest of the form becomes visible immediately.

class _EventTypePicker extends StatelessWidget {
  final EventType? selected;
  final String Function(EventType) labelOf;
  final ValueChanged<EventType> onChanged;

  const _EventTypePicker({
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  static final _icons = {
    EventType.trip: Icons.luggage_rounded,
    EventType.birthday: Icons.cake_rounded,
    EventType.wedding: Icons.favorite_rounded,
    EventType.social: Icons.celebration_rounded,
    EventType.quickBites: Icons.restaurant_rounded,
    EventType.signup: Icons.how_to_reg_rounded,
  };

  // Full grid shown before any selection.
  Widget _grid(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final columns = w >= 600 ? 5 : w >= 380 ? 3 : 2;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: EventType.values.map((type) {
        final theme = bannerThemeFor(type);
        return AppTappable(
          onTap: () => onChanged(type),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  CustomPaint(
                    painter: EventIconPatternPainter(
                      icons: theme.icons,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icons[type]!, size: 38, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          labelOf(type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Compact horizontal chip strip shown after selection.
  Widget _strip(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: EventType.values.map((type) {
          final theme = bannerThemeFor(type);
          final isSelected = type == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppTappable(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? theme.gradientColors
                        : [
                            theme.gradientColors.first.withValues(alpha: 0.18),
                            theme.gradientColors.last.withValues(alpha: 0.18),
                          ],
                  ),
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.gradientColors.last
                                .withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _icons[type]!,
                      size: isSelected ? 20 : 18,
                      color: isSelected
                          ? Colors.white
                          : theme.gradientColors.first,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labelOf(type),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.gradientColors.first,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 280),
      sizeCurve: Curves.easeOut,
      crossFadeState: selected == null
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: _grid(context),
      secondChild: _strip(context),
    );
  }
}
