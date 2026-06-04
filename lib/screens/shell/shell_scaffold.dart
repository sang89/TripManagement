import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/friends_provider.dart';
import '../../providers/invitations_provider.dart';
import '../../providers/event_provider.dart';

class ShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Consumer<InvitationsProvider>(
              builder: (context, invitations, child) => Badge(
                isLabelVisible: invitations.pendingCount > 0,
                label: Text('${invitations.pendingCount}'),
                child: const Icon(Icons.luggage_outlined),
              ),
            ),
            activeIcon: Consumer<InvitationsProvider>(
              builder: (context, invitations, child) => Badge(
                isLabelVisible: invitations.pendingCount > 0,
                label: Text('${invitations.pendingCount}'),
                child: const Icon(Icons.luggage),
              ),
            ),
            label: l10n.navTrips,
          ),
          BottomNavigationBarItem(
            icon: Consumer<FriendsProvider>(
              builder: (_, friends, _) => Badge(
                isLabelVisible: friends.incomingRequests.isNotEmpty,
                label: Text('${friends.incomingRequests.length}'),
                child: const Icon(Icons.people_outline),
              ),
            ),
            activeIcon: Consumer<FriendsProvider>(
              builder: (_, friends, _) => Badge(
                isLabelVisible: friends.incomingRequests.isNotEmpty,
                label: Text('${friends.incomingRequests.length}'),
                child: const Icon(Icons.people),
              ),
            ),
            label: l10n.navFriends,
          ),
          BottomNavigationBarItem(
            icon: Consumer<EventProvider>(
              builder: (_, events, _) => Badge(
                isLabelVisible: events.pendingRsvpCount > 0,
                label: Text('${events.pendingRsvpCount}'),
                child: const Icon(Icons.celebration_outlined),
              ),
            ),
            activeIcon: Consumer<EventProvider>(
              builder: (_, events, _) => Badge(
                isLabelVisible: events.pendingRsvpCount > 0,
                label: Text('${events.pendingRsvpCount}'),
                child: const Icon(Icons.celebration),
              ),
            ),
            label: l10n.navEvents,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
