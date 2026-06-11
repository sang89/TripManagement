import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/friends_provider.dart';
import '../../providers/event_provider.dart';
import '../events/session_scan_screen.dart';

class ShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = navigationShell.currentIndex;

    void go(int index) =>
        navigationShell.goBranch(index, initialLocation: index == current);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
          ],
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
    );
  }
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
