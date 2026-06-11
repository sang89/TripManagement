import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/invite_codec.dart';

/// Public RSVP screen — accessible without authentication.
/// Fetches event info by invite_code and lets anyone RSVP.
class EventInviteScreen extends StatefulWidget {
  final String inviteCode;

  const EventInviteScreen({super.key, required this.inviteCode});

  @override
  State<EventInviteScreen> createState() => _EventInviteScreenState();
}

class _EventInviteScreenState extends State<EventInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Decode once — accepts both encoded (22-char) and raw UUID forms.
  late final String _uuid = InviteCodec.decode(widget.inviteCode);

  bool _loading = true;
  bool _submitting = false;
  bool _done = false;
  String? _error;
  Map<String, dynamic>? _eventData;
  String _rsvpStatus = 'going';

  // Signup-specific result
  String? _signupStatus;
  int? _signupPosition;

  @override
  void initState() {
    super.initState();
    _fetchEvent();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchEvent() async {
    try {
      final data = await Supabase.instance.client.rpc(
        'get_event_by_invite_code',
        params: {'p_invite_code': _uuid},
      ) as List<dynamic>;

      if (data.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Event not found.';
        });
        return;
      }
      setState(() {
        _eventData = Map<String, dynamic>.from(data.first as Map);
        _loading = false;
      });

      // If authenticated, pre-fill name.
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        try {
          final profile = await Supabase.instance.client
              .from('user_profiles')
              .select('full_name')
              .eq('user_id', auth.userId!)
              .maybeSingle();
          if (profile != null && mounted) {
            _nameCtrl.text = (profile['full_name'] as String?)?.trim() ?? '';
          }
        } catch (_) {}
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool get _isSignupEvent =>
      (_eventData?['event_type'] as String?) == 'signup';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isSignupEvent) {
        final rows = await Supabase.instance.client.rpc(
          'rsvp_signup_event',
          params: {
            'p_invite_code': _uuid,
            'p_display_name': _nameCtrl.text.trim(),
            'p_email': _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            'p_phone': _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
          },
        ) as List<dynamic>;
        if (rows.isNotEmpty) {
          final r = rows.first as Map<String, dynamic>;
          _signupStatus = r['rsvp_status'] as String?;
          _signupPosition = r['signup_position'] as int?;
        }
      } else {
        await Supabase.instance.client.rpc(
          'rsvp_event_public',
          params: {
            'p_invite_code': _uuid,
            'p_display_name': _nameCtrl.text.trim(),
            'p_email': _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            'p_phone': _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
            'p_rsvp_status': _rsvpStatus,
          },
        );
      }
      setState(() {
        _submitting = false;
        _done = true;
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _submitting = false;
        _error = msg.contains('event_full') || msg.contains('event_full')
            ? AppLocalizations.of(context).eventFull
            : msg.contains('signup_locked')
                ? AppLocalizations.of(context).signupLocked
                : msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _eventData == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
        ),
      );
    }
    if (_done) {
      final successMsg = _isSignupEvent && _signupPosition != null
          ? (_signupStatus == 'waitlisted'
              ? l10n.signupWaitlistPosition(_signupPosition!)
              : l10n.signupConfirmedPosition(_signupPosition!))
          : l10n.rsvpSuccess;
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isSignupEvent && _signupStatus == 'waitlisted'
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_rounded,
                color: _isSignupEvent && _signupStatus == 'waitlisted'
                    ? Colors.orange
                    : Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(successMsg,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              if (isLoggedIn)
                TextButton(
                  onPressed: () => context.go('/events'),
                  child: const Text('View my events'),
                ),
            ],
          ),
        ),
      );
    }

    final eventData = _eventData!;
    final title = eventData['title'] as String? ?? '';
    final location = eventData['location'] as String? ?? '';
    final startAt = eventData['start_at'] != null
        ? DateTime.parse(eventData['start_at'] as String).toLocal()
        : null;
    final organizer = eventData['organizer_name'] as String? ?? '';
    final goingCount = eventData['going_count'] as int? ?? 0;
    final maybeCount = eventData['maybe_count'] as int? ?? 0;
    final waitlistCount = eventData['waitlist_count'] as int? ?? 0;
    final capacity = eventData['capacity'] as int?;
    final waitlistEnabled = eventData['waitlist_enabled'] as bool? ?? true;
    final signupLockHours = eventData['signup_lock_hours'] as int?;
    final isSignup = _isSignupEvent;
    final isFull = capacity != null && goingCount >= capacity;
    final isLocked = isSignup &&
        signupLockHours != null &&
        startAt != null &&
        DateTime.now()
            .isAfter(startAt.subtract(Duration(hours: signupLockHours)));
    final fmt = DateFormat('EEE, MMM d · h:mm a');

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event info header
                Text(l10n.publicRsvpTitle,
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (startAt != null)
                  _InfoRow(
                    icon: Icons.schedule_outlined,
                    text: fmt.format(startAt),
                  ),
                if (location.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: location,
                  ),
                if (organizer.isNotEmpty)
                  _InfoRow(
                    icon: Icons.person_outline,
                    text: l10n.organizedBy(organizer),
                  ),
                if (isSignup && capacity != null)
                  _InfoRow(
                    icon: Icons.event_seat_rounded,
                    text: l10n.signupSpotsFilled(goingCount, capacity),
                  )
                else
                  _InfoRow(
                    icon: Icons.people_outline,
                    text: '${l10n.goingCount(goingCount)}  ·  ${l10n.maybeCount(maybeCount)}',
                  ),
                if (isSignup && waitlistCount > 0)
                  _InfoRow(
                    icon: Icons.hourglass_top_rounded,
                    text: l10n.signupWaitlistCount(waitlistCount),
                  ),

                const Divider(height: 32),

                // Lock banner — shown instead of the form for locked signup events
                if (isLocked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock_rounded,
                            color: Colors.orange, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.signupLockedMessage,
                            style: const TextStyle(
                                color: Colors.orange, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]

                // RSVP selection (hidden for signup events)
                else if (!isSignup) ...[
                  Text(l10n.changeRsvp,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  _RsvpSelector(
                    selected: _rsvpStatus,
                    onChanged: (s) => setState(() => _rsvpStatus = s),
                    l10n: l10n,
                  ),
                  const SizedBox(height: 20),
                ] else if (isFull && !waitlistEnabled) ...[
                  Center(
                    child: Text(l10n.signupEventFull,
                        style: const TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  Center(
                    child: Text(
                      isFull
                          ? l10n.signupJoinWaitlist
                          : l10n.signupClaimSpot,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Guest info fields + submit — hidden entirely when locked
                if (!isLocked) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(labelText: l10n.publicRsvpName),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l10n.required : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration:
                        InputDecoration(labelText: l10n.publicRsvpEmail),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  if (!isSignup)
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration:
                          InputDecoration(labelText: l10n.publicRsvpPhone),
                      keyboardType: TextInputType.phone,
                    ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: AppTheme.danger),
                        textAlign: TextAlign.center),
                  ],

                  const SizedBox(height: 24),
                  if (!isSignup || !(isFull && !waitlistEnabled))
                    AppButton(
                      label: isSignup
                          ? (isFull
                              ? l10n.signupJoinWaitlist
                              : l10n.signupClaimSpot)
                          : switch (_rsvpStatus) {
                              'going' => l10n.rsvpGoing,
                              'maybe' => l10n.rsvpMaybe,
                              _ => l10n.rsvpDeclined,
                            },
                      onPressed: _submit,
                      loading: _submitting,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            ),
          ],
        ),
      );
}

class _RsvpSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  const _RsvpSelector({
    required this.selected,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Chip(
            label: l10n.rsvpGoing,
            color: Colors.green,
            selected: selected == 'going',
            onTap: () => onChanged('going'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: l10n.rsvpMaybe,
            color: Colors.orange,
            selected: selected == 'maybe',
            onTap: () => onChanged('maybe'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: l10n.rsvpDeclined,
            color: AppTheme.danger,
            selected: selected == 'declined',
            onTap: () => onChanged('declined'),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppTappable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.grey[600],
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      );
}
