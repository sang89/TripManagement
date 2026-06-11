import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';

/// Full-screen QR scanner — scans a session QR code and joins that session.
/// Accepts a full invite URL (`…/session/invite/{uuid}`), `?code={uuid}`, or a raw UUID.
class SessionScanScreen extends StatefulWidget {
  const SessionScanScreen({super.key});

  @override
  State<SessionScanScreen> createState() => _SessionScanScreenState();
}

class _SessionScanScreenState extends State<SessionScanScreen> {
  late final MobileScannerController _controller;
  bool _handling = false;
  // True when the native camera plugin is unavailable (simulator, web, etc.)
  bool _cameraUnavailable = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
    // Probe camera availability; MissingPluginException thrown on simulator.
    _controller.start().catchError((Object e) {
      if (e is MissingPluginException || e is PlatformException) {
        if (mounted) setState(() => _cameraUnavailable = true);
      }
    });
  }

  static final _uuidRe = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractCode(String raw) => _uuidRe.firstMatch(raw)?.group(0);

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final code = _extractCode(raw);
    if (code == null) return;
    await _handleCode(code);
  }

  Future<void> _enterCodeManually() async {
    final ctrl = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter invite code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Paste the invite code or message you received.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'e.g. 25b282ec-8cfc-…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Join session',
              onPressed: () => Navigator.pop(ctx, ctrl.text),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (code == null || !mounted) return;
    final extracted = _extractCode(code);
    if (extracted == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No invite code found — check what you pasted.')));
      return;
    }
    await _handleCode(extracted);
  }

  Future<void> _handleCode(String code) async {
    if (_handling) return;
    setState(() => _handling = true);
    await _controller.stop();

    try {
      final rows = await Supabase.instance.client.rpc(
        'get_session_by_invite_code',
        params: {'p_invite_code': code},
      ) as List<dynamic>;

      if (!mounted) return;
      if (rows.isEmpty) {
        _showError('Session not found — this QR code is invalid.');
        return;
      }
      final session = Map<String, dynamic>.from(rows.first as Map);
      await _showJoinSheet(session, code);
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

  Future<void> _showJoinSheet(Map<String, dynamic> s, String code) async {
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
    final isFull = capacity != null && going >= capacity;
    final isLocked = lockHours != null &&
        startAt != null &&
        DateTime.now().isAfter(startAt.subtract(Duration(hours: lockHours)));
    final fmt = DateFormat('EEE, MMM d · h:mm a');

    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
              _InfoRow(icon: Icons.schedule_outlined, text: fmt.format(startAt)),
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
              _Banner(text: l10n.signupEventFull, color: AppTheme.danger)
            else
              AppButton(
                label: isFull
                    ? '⏳  ${l10n.signupJoinWaitlist}'
                    : '🎟️  ${l10n.signupClaimSpot}',
                onPressed: () => Navigator.pop(ctx, true),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (joined != true) {
      setState(() => _handling = false);
      _controller.start();
      return;
    }

    await _join(code, s);
  }

  Future<void> _join(String code, Map<String, dynamic> s) async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthProvider>();
    final provider = context.read<EventProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final rows = await Supabase.instance.client.rpc('rsvp_session', params: {
        'p_invite_code': code,
        'p_display_name': auth.userName,
      }) as List<dynamic>;
      if (rows.isNotEmpty) {
        final r = rows.first as Map<String, dynamic>;
        final status = r['rsvp_status'] as String?;
        final pos = r['signup_position'] as int? ?? 0;
        messenger.showSnackBar(SnackBar(
          content: Text(status == 'waitlisted'
              ? l10n.signupWaitlistPosition(pos)
              : l10n.signupConfirmedPosition(pos)),
        ));
      }
      // Refresh caches if the user already has this event loaded.
      final eventId = s['event_id'] as String?;
      if (eventId != null) {
        try {
          await provider.fetchUpcomingSessions(eventId);
          final sessionId = s['session_id'] as String?;
          if (sessionId != null) {
            await provider.refreshSessionRoster(sessionId);
          }
        } catch (_) {}
      }
      navigator.pop();
    } catch (e) {
      final msg = e.toString();
      messenger.showSnackBar(SnackBar(
        content: Text(msg.contains('already_signed_up')
            ? 'You are already signed up for this session.'
            : msg.contains('signup_locked')
                ? l10n.signupLocked
                : msg.contains('session_full')
                    ? l10n.signupEventFull
                    : msg),
      ));
      if (mounted) {
        setState(() => _handling = false);
        _controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan to join'),
      ),
      body: _cameraUnavailable ? _buildNoCameraFallback() : _buildScanner(),
    );
  }

  // Shown on simulator / devices where the camera plugin isn't available.
  Widget _buildNoCameraFallback() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_rounded,
                  size: 64, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(height: 20),
              Text(
                'Camera not available on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Use a physical device to scan, or paste the invite code below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
              ),
              const SizedBox(height: 32),
              _enterCodeButton(),
            ],
          ),
        ),
      );

  Widget _buildScanner() => Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Camera error: ${error.errorDetails?.message ?? error.errorCode.name}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    _enterCodeButton(),
                  ],
                ),
              ),
            ),
          ),
          // Viewfinder frame
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
                  'Point the camera at a session QR code',
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
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.5)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 14)),
      );
}
