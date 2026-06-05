import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/friends_provider.dart';
import '../../providers/event_provider.dart';

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
              _NavItem(
                icon: Consumer<EventProvider>(
                  builder: (_, events, _) => Badge(
                    isLabelVisible: events.pendingInviteCount > 0,
                    label: Text('${events.pendingInviteCount}'),
                    child: Icon(
                      current == 0 ? Icons.event : Icons.event_outlined,
                      size: 28,
                      color: current == 0 ? AppTheme.primary : Colors.grey,
                    ),
                  ),
                ),
                label: l10n.navEvents,
                selected: current == 0,
                onTap: () => go(0),
              ),
              _NavItem(
                icon: Consumer<FriendsProvider>(
                  builder: (_, friends, _) => Badge(
                    isLabelVisible: friends.incomingRequests.isNotEmpty,
                    label: Text('${friends.incomingRequests.length}'),
                    child: Icon(
                      current == 1 ? Icons.people : Icons.people_outline,
                      size: 28,
                      color: current == 1 ? AppTheme.primary : Colors.grey,
                    ),
                  ),
                ),
                label: l10n.navFriends,
                selected: current == 1,
                onTap: () => go(1),
              ),
              _NavItem(
                icon: Icon(
                  current == 2 ? Icons.person : Icons.person_outline,
                  size: 28,
                  color: current == 2 ? AppTheme.primary : Colors.grey,
                ),
                label: l10n.navProfile,
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

class _NavItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppTappable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? AppTheme.primary : Colors.grey,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
