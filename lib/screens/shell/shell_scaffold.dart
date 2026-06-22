import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/live_queue_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/event_provider.dart';
import '../events/session_scan_screen.dart';

class ShellScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScaffold({super.key, required this.navigationShell});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold>
    with WidgetsBindingObserver {
  /// Cursor into the live queue. Always read modulo the queue length, so it
  /// stays valid even as the queue grows or shrinks.
  int _liveCursor = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh which sessions are live after the app returns to the foreground.
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<EventProvider>().fetchLiveSessions());
    }
  }

  Future<void> _onLiveTap() async {
    final provider = context.read<EventProvider>();
    final uid = context.read<AuthProvider>().userId ?? '';
    // Refresh live sessions FIRST, then build the queue from fresh data — the
    // cached list is only seeded at load()/resume, so a tap must not rely on it
    // (e.g. after hot reload load() never re-runs and the cache stays empty).
    // Defensive: never let a refresh failure crash the tap — fall back to the
    // cached list (which may be empty → handled below).
    try {
      await provider.fetchLiveSessions();
    } catch (_) {
      /* ignore — proceed with whatever is cached */
    }
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final queue = buildLiveQueue(
        provider.events, provider.liveSessions, uid, DateTime.now());

    if (queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.liveNoneNow)),
      );
      return;
    }
    final index = _liveCursor % queue.length;
    context.go(queue[index].route);
    setState(() => _liveCursor = index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = widget.navigationShell.currentIndex;
    final uid = context.read<AuthProvider>().userId ?? '';

    void go(int index) => widget.navigationShell
        .goBranch(index, initialLocation: index == current);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            painter: _NotchedBarPainter(
              color: Colors.white,
              borderColor: Colors.grey.shade200,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Events
                  Consumer<EventProvider>(
                    builder: (_, events, _) => _PillNavItem(
                      iconSelected: Icons.event_rounded,
                      iconUnselected: Icons.event_outlined,
                      label: l10n.navEvents,
                      gradient: const [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
                      selected: current == 0,
                      badge: events.pendingInviteCount,
                      onTap: () => go(0),
                    ),
                  ),
                  // Join — action button, not a nav tab
                  _PillNavItem(
                    iconSelected: Icons.qr_code_scanner_rounded,
                    iconUnselected: Icons.qr_code_scanner_rounded,
                    label: 'Join',
                    gradient: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    selected: false,
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const SessionScanScreen()),
                    ),
                  ),
                  // Live — center slot. Reserves the footprint; the raised
                  // circular button is drawn in the Stack overlay below.
                  Expanded(
                    child: Consumer<EventProvider>(
                      builder: (_, events, _) {
                        final count = buildLiveQueue(events.events,
                                events.liveSessions, uid, DateTime.now())
                            .length;
                        return _LiveLabel(count: count);
                      },
                    ),
                  ),
                  // Friends
                  Consumer<FriendsProvider>(
                    builder: (_, friends, _) => _PillNavItem(
                      iconSelected: Icons.people_rounded,
                      iconUnselected: Icons.people_outline,
                      label: l10n.navFriends,
                      gradient: const [Color(0xFFEA580C), Color(0xFFFB923C)],
                      selected: current == 1,
                      badge: friends.incomingRequests.length,
                      onTap: () => go(1),
                    ),
                  ),
                  // Profile
                  _PillNavItem(
                    iconSelected: Icons.person_rounded,
                    iconUnselected: Icons.person_outline,
                    label: l10n.navProfile,
                    gradient: const [Color(0xFF0D9488), Color(0xFF34D399)],
                    selected: current == 2,
                    onTap: () => go(2),
                  ),
                ],
              ),
            ),
          ),
          // Raised circular Live button, centered and protruding above the bar.
          Positioned(
            top: -16,
            left: 0,
            right: 0,
            child: Center(
              child: Consumer<EventProvider>(
                builder: (_, events, _) {
                  final queue = buildLiveQueue(events.events,
                      events.liveSessions, uid, DateTime.now());
                  return _LiveButton(
                    count: queue.length,
                    onTap: _onLiveTap,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The label + reserved space occupying the center Row slot, so the four real
/// nav items stay evenly spaced beneath the raised Live button.
class _LiveLabel extends StatelessWidget {
  final int count;
  const _LiveLabel({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final live = count > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Empty space where the raised circle visually sits.
          const SizedBox(height: 34),
          const SizedBox(height: 4),
          Text(
            l10n.navLive,
            style: TextStyle(
              fontSize: 11,
              color: live ? const Color(0xFFDC2626) : Colors.grey.shade400,
              fontWeight: live ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// The raised circular button. When items are live it continuously emanates
/// staggered "broadcast" rings and gently breathes; greyed and static when
/// nothing is live.
class _LiveButton extends StatefulWidget {
  final int count;
  final VoidCallback onTap;

  const _LiveButton({required this.count, required this.onTap});

  @override
  State<_LiveButton> createState() => _LiveButtonState();
}

class _LiveButtonState extends State<_LiveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  // Phase offsets for the three emanating rings, so they fan out continuously
  // rather than all at once.
  static const _ringPhases = [0.0, 0.34, 0.67];

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_LiveButton old) {
    super.didUpdateWidget(old);
    _syncAnimation();
  }

  void _syncAnimation() {
    final live = widget.count > 0;
    if (live && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!live && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// One expanding, fading halo. [p] is its progress in [0, 1).
  Widget _ring(double p) {
    final size = 50.0 + 42.0 * p;
    final opacity = (1.0 - p).clamp(0.0, 1.0) * 0.40;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEF4444).withValues(alpha: opacity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.count > 0;
    final gradient = live
        ? const [Color(0xFFDC2626), Color(0xFFEF4444)]
        : [Colors.grey.shade400, Colors.grey.shade300];
    final glow = live ? const Color(0xFFEF4444) : Colors.grey;

    final circle = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.sensors_rounded, color: Colors.white, size: 26),
    );

    return AppTappable(
      onTap: widget.onTap,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Emanating rings + a subtle breathing scale on the circle.
            if (live)
              AnimatedBuilder(
                animation: _controller,
                builder: (_, child) {
                  final t = _controller.value;
                  // Gentle breath: 1.0 → ~1.06 → 1.0 across the cycle.
                  final breathe =
                      1.0 + 0.06 * math.sin(t * 2 * math.pi).abs();
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      for (final phase in _ringPhases)
                        _ring((t + phase) % 1.0),
                      Transform.scale(scale: breathe, child: child),
                    ],
                  );
                },
                child: circle,
              )
            else
              circle,
            if (live)
              Positioned(
                top: 0,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border:
                        Border.all(color: const Color(0xFFDC2626), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints the bottom bar background with a concave circular notch carved into
/// the top edge, centered under the raised Live button — plus a soft upward
/// shadow and a hairline top border that follow the notch.
class _NotchedBarPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  /// Radius of the carved notch. Slightly larger than the Live circle's outer
  /// edge (28 + 3px ring) so a small gap shows around the button.
  static const double _notchRadius = 39;

  const _NotchedBarPainter({required this.color, required this.borderColor});

  Path _barPath(Size size) {
    final host = Offset.zero & size;
    final guest = Rect.fromCircle(
      center: Offset(size.width / 2, 0),
      radius: _notchRadius,
    );
    return const CircularNotchedRectangle().getOuterPath(host, guest);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _barPath(size);

    // Soft shadow above the bar (the bar sits at the bottom of the screen).
    canvas.save();
    canvas.translate(0, -2);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();

    // White fill.
    canvas.drawPath(path, Paint()..color = color);

    // Hairline border that traces the top edge and the notch.
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter old) =>
      old.color != color || old.borderColor != borderColor;
}

class _PillNavItem extends StatelessWidget {
  final IconData iconSelected;
  final IconData iconUnselected;
  final String label;
  final List<Color> gradient;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _PillNavItem({
    required this.iconSelected,
    required this.iconUnselected,
    required this.label,
    required this.gradient,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final showGradient = selected;
    final pillDecoration = showGradient
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          );

    final iconWidget = Icon(
      selected ? iconSelected : iconUnselected,
      size: 20,
      color: showGradient ? Colors.white : Colors.grey.shade400,
    );

    return Expanded(
      child: AppTappable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 34,
                  decoration: pillDecoration,
                  alignment: Alignment.center,
                  child: iconWidget,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? gradient.first : Colors.grey.shade400,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
