import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../utils/invite_codec.dart';

/// Full-screen universal QR scanner.
///
/// Handles two code types:
///   • Session invite code → shows inline join sheet (session + auto-joins event)
///   • Event invite code   → navigates to /event/invite/:code (public RSVP screen)
///
/// Accessible from the shell nav without being a member of any event.
class SessionScanScreen extends StatefulWidget {
  const SessionScanScreen({super.key});

  @override
  State<SessionScanScreen> createState() => _SessionScanScreenState();
}

class _SessionScanScreenState extends State<SessionScanScreen> {
  late final MobileScannerController _controller;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final uuid = InviteCodec.extract(raw);
    if (uuid == null) return;
    await _handleCode(uuid);
  }

  Future<void> _enterCodeManually() async {
    final input = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _EnterCodeSheet(),
    );
    if (input == null || !mounted) return;
    final uuid = InviteCodec.extract(input);
    if (uuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No invite code found — check what you pasted.')));
      return;
    }
    await _handleCode(uuid);
  }

  /// Looks up the UUID as a session code, then as an event code.
  Future<void> _handleCode(String code) async {
    if (_handling) return;
    setState(() => _handling = true);
    await _controller.stop();

    try {
      // 1. Try session invite code first.
      final sessionRows = await Supabase.instance.client.rpc(
        'get_session_by_invite_code',
        params: {'p_invite_code': code},
      ) as List<dynamic>;

      if (!mounted) return;

      if (sessionRows.isNotEmpty) {
        final session = Map<String, dynamic>.from(sessionRows.first as Map);
        await _showSessionJoinSheet(session, code);
        return;
      }

      // 2. Fall back to event invite code.
      final eventRows = await Supabase.instance.client.rpc(
        'get_event_by_invite_code',
        params: {'p_invite_code': code},
      ) as List<dynamic>;

      if (!mounted) return;

      if (eventRows.isNotEmpty) {
        // Navigate to the public event RSVP screen.
        context.push('/event/invite/$code');
        Navigator.of(context).pop();
        return;
      }

      _showError('QR code not recognised — make sure you\'re scanning an event or session code.');
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    setState(() => _handling = false);
    _controller.start();
  }

  // ── Session join sheet ───────────────────────────────────────────────────────

  Future<void> _showSessionJoinSheet(
      Map<String, dynamic> s, String code) async {
    final l10n = AppLocalizations.of(context);
    final title = s['title'] as String? ?? '';
    final sessionNum = s['session_number'] as int? ?? 1;
    final location = s['location'] as String? ?? '';
    final startAt = s['start_at'] != null
        ? DateTime.parse(s['start_at'] as String).toLocal()
        : null;
    final going = (s['going_count'] as num?)?.toInt() ?? 0;
    final capacity = s['capacity'] as int?;
    final waitlistEnabled = s['waitlist_enabled'] as bool? ?? true;
    final lockHours = s['signup_lock_hours'] as int?;
    final requiresApproval = s['requires_approval'] as bool? ?? false;
    final isFull = capacity != null && going >= capacity;
    final isLocked = lockHours != null &&
        startAt != null &&
        DateTime.now().isAfter(startAt.subtract(Duration(hours: lockHours)));

    final join = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SessionJoinSheet(
        title: title,
        sessionNum: sessionNum,
        location: location,
        startAt: startAt,
        going: going,
        capacity: capacity,
        waitlistEnabled: waitlistEnabled,
        isFull: isFull,
        isLocked: isLocked,
        requiresApproval: requiresApproval,
        l10n: l10n,
      ),
    );

    if (!mounted) return;
    if (join != true) {
      setState(() => _handling = false);
      _controller.start();
      return;
    }

    await _joinSession(code, s);
  }

  Future<void> _joinSession(String code, Map<String, dynamic> s) async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthProvider>();
    final provider = context.read<EventProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    try {
      final rows = await Supabase.instance.client.rpc('rsvp_session', params: {
        'p_invite_code': code,
        'p_display_name': auth.userName,
      }) as List<dynamic>;

      // Close the scanner first, then route the user straight to the event
      // they just joined (sessions tab) so they land on the exact event and
      // session rather than the generic events list.
      navigator.pop();

      if (rows.isNotEmpty) {
        final r = rows.first as Map<String, dynamic>;
        final status = r['rsvp_status'] as String?;
        final pos = r['signup_position'] as int? ?? 0;
        messenger.showSnackBar(SnackBar(
          content: Text(status == 'waitlisted'
              ? l10n.signupWaitlistPosition(pos)
              : status == 'pending_review'
                  ? l10n.signupPendingReview
                  : l10n.signupConfirmedPosition(pos)),
        ));
      }

      // Reload the full event list so the newly joined event appears, then
      // navigate to the event detail's sessions tab so the user is taken to
      // the exact event and session they just joined.
      final eventId = s['event_id'] as String?;
      unawaited(provider.load().then((_) async {
        if (eventId != null) {
          await provider.fetchUpcomingSessions(eventId);
          final sessionId = s['session_id'] as String?;
          if (sessionId != null) {
            await provider.refreshSessionRoster(sessionId);
          }
        }
      }));
      if (eventId != null) {
        router.push('/event/$eventId?tab=session');
      }
    } catch (e) {
      final msg = e.toString();
      messenger.showSnackBar(SnackBar(
        content: Text(msg.contains('already_signed_up')
            ? 'You are already signed up for this session.'
            : msg.contains('signup_locked')
                ? l10n.signupLocked
                : msg.contains('session_full')
                    ? l10n.signupSessionFull
                    : msg),
      ));
      if (mounted) {
        setState(() => _handling = false);
        _controller.start();
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan to join'),
      ),
      body: _buildScanner(),
    );
  }

  Widget _buildScanner() => Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            fit: BoxFit.cover,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.no_photography_rounded,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(height: 20),
                    Text(
                      'Camera not available on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste the invite code instead.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13),
                    ),
                    const SizedBox(height: 32),
                    _enterCodeButton(),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Point the camera at an event or session QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14),
                ),
                const SizedBox(height: 14),
                _enterCodeButton(),
              ],
            ),
          ),
          if (_handling)
            const Center(
                child: CircularProgressIndicator(color: Colors.white)),
        ],
      );

  Widget _enterCodeButton() => AppTappable(
        onTap: _enterCodeManually,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text('Enter code instead',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ── Session join bottom sheet ──────────────────────────────────────────────────

class _SessionJoinSheet extends StatelessWidget {
  final String title;
  final int sessionNum;
  final String location;
  final DateTime? startAt;
  final int going;
  final int? capacity;
  final bool waitlistEnabled;
  final bool isFull;
  final bool isLocked;
  final bool requiresApproval;
  final AppLocalizations l10n;

  const _SessionJoinSheet({
    required this.title,
    required this.sessionNum,
    required this.location,
    required this.startAt,
    required this.going,
    required this.capacity,
    required this.waitlistEnabled,
    required this.isFull,
    required this.isLocked,
    this.requiresApproval = false,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF43A047)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Session #$sessionNum',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (startAt != null)
            _InfoRow(
              icon: Icons.schedule_outlined,
              text: _formatDate(startAt!),
            ),
          if (location.isNotEmpty)
            _InfoRow(icon: Icons.location_on_outlined, text: location),
          _InfoRow(
            icon: Icons.event_seat_rounded,
            text: capacity != null
                ? '$going / $capacity spots filled'
                : '$going signed up',
          ),
          const SizedBox(height: 20),
          if (isLocked)
            _Banner(text: l10n.signupLockedMessage, color: Colors.orange)
          else if (isFull && !waitlistEnabled)
            _Banner(text: l10n.signupSessionFull, color: Colors.red)
          else
            AppButton(
              label: isFull
                  ? '⏳  ${l10n.signupJoinWaitlist}'
                  : requiresApproval
                      ? '🔍  Request to join'
                      : '🎟️  ${l10n.signupClaimSpot}',
              onPressed: () => Navigator.pop(context, true),
            ),
          if (!isLocked && requiresApproval && !(isFull && !waitlistEnabled))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This session requires organizer approval. Your request will be reviewed before being confirmed.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = days[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$weekday, $month ${dt.day} · $hour:$minute $ampm';
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

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 14)),
      );
}

// ── Manual code entry sheet ───────────────────────────────────────────────────
// Owns its own TextEditingController so Flutter disposes it with the widget,
// not externally after the sheet's exit animation has already started.

class _EnterCodeSheet extends StatefulWidget {
  const _EnterCodeSheet();

  @override
  State<_EnterCodeSheet> createState() => _EnterCodeSheetState();
}

class _EnterCodeSheetState extends State<_EnterCodeSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter invite code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Paste the invite code or link you received.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'e.g. JbKC7Iz8Snu46RIzVniQqw',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Join',
            onPressed: () => Navigator.pop(context, _ctrl.text),
          ),
        ],
      ),
    );
  }
}
