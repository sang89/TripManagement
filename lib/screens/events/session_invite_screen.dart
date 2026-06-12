import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/invite_codec.dart';

/// Public signup screen for a specific session (scanned via session QR code).
/// Accessible without authentication.
class SessionInviteScreen extends StatefulWidget {
  final String inviteCode;

  const SessionInviteScreen({super.key, required this.inviteCode});

  @override
  State<SessionInviteScreen> createState() => _SessionInviteScreenState();
}

class _SessionInviteScreenState extends State<SessionInviteScreen> {
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
  Map<String, dynamic>? _sessionData;
  String? _rsvpStatus;
  int? _rsvpPosition;

  @override
  void initState() {
    super.initState();
    _fetchSession();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSession() async {
    try {
      final data = await Supabase.instance.client.rpc(
        'get_session_by_invite_code',
        params: {'p_invite_code': _uuid},
      ) as List<dynamic>;

      if (data.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Session not found.';
        });
        return;
      }
      setState(() {
        _sessionData = Map<String, dynamic>.from(data.first as Map);
        _loading = false;
      });

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
            _nameCtrl.text =
                (profile['full_name'] as String?)?.trim() ?? '';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client.rpc(
        'rsvp_session',
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
        _rsvpStatus = r['rsvp_status'] as String?;
        _rsvpPosition = r['signup_position'] as int?;
      }
      setState(() {
        _submitting = false;
        _done = true;
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _submitting = false;
        _error = msg.contains('session_full')
            ? AppLocalizations.of(context).signupEventFull
            : msg.contains('signup_locked')
                ? AppLocalizations.of(context).signupLocked
                : msg.contains('already_signed_up')
                    ? 'You are already signed up for this session.'
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
    if (_error != null && _sessionData == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: AppTheme.danger)),
        ),
      );
    }
    if (_done) {
      final isPendingReview = _rsvpStatus == 'pending_review';
      final successMsg = isPendingReview
          ? l10n.signupPendingReview
          : _rsvpPosition != null
              ? (_rsvpStatus == 'waitlisted'
                  ? l10n.signupWaitlistPosition(_rsvpPosition!)
                  : l10n.signupConfirmedPosition(_rsvpPosition!))
              : l10n.rsvpSuccess;
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _rsvpStatus == 'waitlisted'
                    ? Icons.hourglass_top_rounded
                    : isPendingReview
                        ? Icons.pending_actions_rounded
                        : Icons.check_circle_rounded,
                color: _rsvpStatus == 'waitlisted'
                    ? Colors.orange
                    : isPendingReview
                        ? Colors.amber
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

    final d = _sessionData!;
    final title = d['title'] as String? ?? '';
    final location = d['location'] as String? ?? '';
    final startAt = d['start_at'] != null
        ? DateTime.parse(d['start_at'] as String).toLocal()
        : null;
    final sessionNum = d['session_number'] as int? ?? 1;
    final organizer = d['organizer_name'] as String? ?? '';
    final goingCount = (d['going_count'] as num?)?.toInt() ?? 0;
    final waitlistCount = (d['waitlist_count'] as num?)?.toInt() ?? 0;
    final capacity = d['capacity'] as int?;
    final waitlistEnabled = d['waitlist_enabled'] as bool? ?? true;
    final signupLockHours = d['signup_lock_hours'] as int?;
    final requiresApproval = d['requires_approval'] as bool? ?? false;
    final isFull = capacity != null && goingCount >= capacity;
    final isLocked = signupLockHours != null &&
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
                Text('Session #$sessionNum',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (startAt != null)
                  _InfoRow(
                      icon: Icons.schedule_outlined,
                      text: fmt.format(startAt)),
                if (location.isNotEmpty)
                  _InfoRow(
                      icon: Icons.location_on_outlined, text: location),
                if (organizer.isNotEmpty)
                  _InfoRow(
                      icon: Icons.person_outline,
                      text: l10n.organizedBy(organizer)),
                if (capacity != null)
                  _InfoRow(
                    icon: Icons.event_seat_rounded,
                    text: l10n.signupSpotsFilled(goingCount, capacity),
                  )
                else
                  _InfoRow(
                    icon: Icons.people_outline,
                    text: '$goingCount going',
                  ),
                if (waitlistCount > 0)
                  _InfoRow(
                    icon: Icons.hourglass_top_rounded,
                    text: l10n.signupWaitlistCount(waitlistCount),
                  ),

                const Divider(height: 32),

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
                ] else if (isFull && !waitlistEnabled) ...[
                  Center(
                    child: Text(l10n.signupEventFull,
                        style: const TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ] else ...[
                  Text(
                    isFull
                        ? '⏳  ${l10n.signupJoinWaitlist}'
                        : requiresApproval
                            ? '🔍  Request to join'
                            : '🎟️  Sign up for this session',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  if (requiresApproval && !isFull) ...[
                    const SizedBox(height: 4),
                    Text(
                      'This session requires organizer approval. Your request will be reviewed before being confirmed.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        InputDecoration(labelText: l10n.publicRsvpName),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.required : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration:
                        InputDecoration(labelText: l10n.publicRsvpEmail),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration:
                        InputDecoration(labelText: l10n.publicRsvpPhone),
                    keyboardType: TextInputType.phone,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: AppTheme.danger)),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: isFull
                        ? l10n.signupJoinWaitlist
                        : requiresApproval
                            ? 'Request to join'
                            : l10n.signupClaimSpot,
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
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}
