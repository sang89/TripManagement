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
import '../../responsive/breakpoints.dart';
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
    final l10n = AppLocalizations.of(context);

    // Build the queue from the cache immediately — _liveSessions is kept fresh
    // by the Realtime UPDATE handler, so it's reliable for instant navigation.
    // Kick off a background refresh so the *next* tap sees any changes that
    // arrived while the app was suspended (Realtime doesn't run when paused).
    final cachedQueue = buildLiveQueue(
        provider.events, provider.liveSessions, uid, DateTime.now());

    if (cachedQueue.isNotEmpty) {
      // Navigate instantly from cache, then refresh in the background.
      final index = _liveCursor % cachedQueue.length;
      context.go(cachedQueue[index].route);
      setState(() => _liveCursor = index + 1);
      unawaited(provider.fetchLiveSessions());
      return;
    }

    // Cache is empty (cold start / first tap after long suspend) — fetch first,
    // then navigate. This is the rare path; normal taps never reach here.
    try {
      await provider.fetchLiveSessions();
    } catch (_) {
      /* ignore — fall through to empty-queue snackbar */
    }
    if (!mounted) return;

    final freshQueue = buildLiveQueue(
        provider.events, provider.liveSessions, uid, DateTime.now());
    if (freshQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.liveNoneNow)),
      );
      return;
    }
    final index = _liveCursor % freshQueue.length;
    context.go(freshQueue[index].route);
    setState(() => _liveCursor = index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = widget.navigationShell.currentIndex;
    final uid = context.read<AuthProvider>().userId ?? '';
    // Watch providers unconditionally so both mobile and desktop paths are
    // reactive to badge-count changes.
    final eventProvider = context.watch<EventProvider>();
    final friendsProvider = context.watch<FriendsProvider>();

    void go(int index) => widget.navigationShell
        .goBranch(index, initialLocation: index == current);

    // ── Desktop layout ────────────────────────────────────────────────────────
    if (isDesktop(context)) {
      final pendingInvites = eventProvider.pendingInviteCount;
      final friendRequests = friendsProvider.incomingRequests.length;
      final liveCount = buildLiveQueue(
              eventProvider.events, eventProvider.liveSessions, uid, DateTime.now())
          .length;

      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: current,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              minWidth: 88,
              leading: _LiveRailButton(count: liveCount, onTap: _onLiveTap),
              destinations: [
                NavigationRailDestination(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  icon: Badge(
                    isLabelVisible: pendingInvites > 0,
                    label: Text('$pendingInvites'),
                    child: const Icon(Icons.event_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: pendingInvites > 0,
                    label: Text('$pendingInvites'),
                    child: const Icon(Icons.event_rounded),
                  ),
                  label: Text(l10n.navEvents),
                ),
                NavigationRailDestination(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  icon: Badge(
                    isLabelVisible: friendRequests > 0,
                    label: Text('$friendRequests'),
                    child: const Icon(Icons.people_outline),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: friendRequests > 0,
                    label: Text('$friendRequests'),
                    child: const Icon(Icons.people_rounded),
                  ),
                  label: Text(l10n.navFriends),
                ),
                NavigationRailDestination(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: Text(l10n.navProfile),
                ),
              ],
              trailing: _JoinRailButton(
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                      builder: (_) => const SessionScanScreen()),
                ),
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

    // ── Mobile layout (unchanged) ─────────────────────────────────────────────
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            painter: _NotchedBarPainter(
              color: Colors.white,
              borderColor: Colors.grey.shade300,
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

  const _NotchedBarPainter({required this.color, required this.borderColor});

  // Smooth cubic-bezier notch — horizontal tangents at every transition point
  // (entry, bottom, exit) so there are no visible kinks.
  Path _barPath(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Half-width from center where the flat bar starts curving down.
    const spread = 62.0;
    // Deepest point below the bar top edge.
    const depth = 33.0;
    // Bezier inner arm lengths — control how gradually the curve sweeps.
    const arm1 = 38.0; // distance from entry/exit that the first cp stays flat
    const arm2 = 20.0; // x-distance from center that the second cp sits

    return Path()
      ..moveTo(0, 0)
      ..lineTo(cx - spread, 0)
      // Left shoulder → notch bottom (arrives horizontal at the centre)
      ..cubicTo(
        cx - arm1, 0,      // cp1 – flat departure from the bar line
        cx - arm2, depth,  // cp2 – settles near the deepest point
        cx, depth,         // P3  – bottom centre; tangent is horizontal
      )
      // Notch bottom → right shoulder (departs horizontal from the centre)
      ..cubicTo(
        cx + arm2, depth,  // cp1 – flat departure from the bottom
        cx + arm1, 0,      // cp2 – rising back to bar level
        cx + spread, 0,    // P3  – back to the flat bar line
      )
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
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
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter old) =>
      old.color != color || old.borderColor != borderColor;
}

// ── Desktop rail helper widgets ───────────────────────────────────────────────

/// Leading widget for the desktop [NavigationRail] — shows the Live sensor
/// icon with a badge count and a text label.
class _LiveRailButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _LiveRailButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final live = count > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: AppTappable(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: live,
              label: Text('$count'),
              child: Icon(
                Icons.sensors_rounded,
                color:
                    live ? const Color(0xFFDC2626) : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Live',
              style: TextStyle(
                fontSize: 11,
                color: live
                    ? const Color(0xFFDC2626)
                    : Colors.grey.shade500,
                fontWeight:
                    live ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trailing widget for the desktop [NavigationRail] — QR code scanner to join
/// a live session by scanning a code.
class _JoinRailButton extends StatelessWidget {
  final VoidCallback onTap;

  const _JoinRailButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: IconButton(
        icon: const Icon(Icons.qr_code_scanner_rounded),
        onPressed: onTap,
        tooltip: 'Join',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
