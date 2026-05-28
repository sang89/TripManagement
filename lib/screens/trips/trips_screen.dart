import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invitations_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/trip_card.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabIcons = [
    Icons.format_list_bulleted_rounded,
    Icons.flight_takeoff_rounded,
    Icons.history_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabIcons.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Trip> _filtered(List<Trip> trips, int tabIndex) {
    final now = DateTime.now();
    return switch (tabIndex) {
      0 => trips,
      1 => trips
          .where((t) => t.endAt == null || t.endAt!.isAfter(now))
          .toList(),
      2 => trips
          .where((t) => t.endAt != null && t.endAt!.isBefore(now))
          .toList(),
      _ => trips,
    };
  }

  Widget _tripSlide(BuildContext context, Trip trip) {
    final l10n = AppLocalizations.of(context);
    final currentUserId = context.read<AuthProvider>().userId;
    final isOrganizer = trip.createdBy == currentUserId;
    return Slidable(
      key: ValueKey(trip.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          if (isOrganizer)
            SlidableAction(
              onPressed: (_) => _confirmDelete(context, trip),
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: l10n.delete,
            )
          else
            SlidableAction(
              onPressed: (_) => _confirmLeave(context, trip),
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              icon: Icons.exit_to_app_outlined,
              label: l10n.leave,
            ),
        ],
      ),
      child: TripCard(trip: trip),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Trip trip) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTripTitle),
        content: Text(l10n.deleteTripMessage(trip.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TripProvider>().deleteTrip(trip.id);
    }
  }

  Future<void> _confirmLeave(BuildContext context, Trip trip) async {
    final l10n = AppLocalizations.of(context);
    bool blockReinvite = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.leaveTripTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.leaveTripMessage(
                  trip.title.isNotEmpty ? trip.title : l10n.thisTripFallback)),
              const SizedBox(height: 8),
              SwitchListTile(
                value: blockReinvite,
                onChanged: (v) => setS(() => blockReinvite = v),
                title: Text(l10n.blockReinviteLabel,
                    style: const TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.leave,
                  style: const TextStyle(color: AppTheme.danger)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TripProvider>().leaveTrip(trip.id, blockReinvite: blockReinvite);
    }
  }

  Widget _tabBody(BuildContext context, int tabIndex) {
    final provider = context.watch<TripProvider>();
    final l10n = AppLocalizations.of(context);

    if (!provider.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text(l10n.couldNotLoadTrips,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(provider.loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              AppButton(
                label: l10n.retry,
                onPressed: () => context.read<TripProvider>().load(),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered(provider.trips, tabIndex);

    // Invite card is shown at the top of the "All" tab only.
    final showInvites = tabIndex == 0;

    if (filtered.isEmpty && !showInvites) {
      return _EmptyState(tabIndex: tabIndex);
    }

    if (filtered.isEmpty && showInvites) {
      return Consumer<InvitationsProvider>(
        builder: (context, invitations, _) {
          if (invitations.pendingCount == 0) {
            return _EmptyState(tabIndex: tabIndex);
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [_InviteCard(invitations: invitations)],
          );
        },
      );
    }

    final list = AppReorderableList<Trip>(
      padding: const EdgeInsets.symmetric(vertical: 8),
      items: filtered,
      keyOf: (trip) => ValueKey(trip.id),
      onReorder: (oldIndex, newIndex) {
        final visibleIds = filtered.map((t) => t.id).toList();
        context.read<TripProvider>().reorderTrips(
              visibleIds,
              oldIndex,
              newIndex,
            );
      },
      itemBuilder: (context, trip, index) => _tripSlide(context, trip),
    );

    if (!showInvites) return list;

    return Consumer<InvitationsProvider>(
      builder: (context, invitations, _) {
        if (invitations.pendingCount == 0) return list;
        return Column(
          children: [
            _InviteCard(invitations: invitations),
            Expanded(child: list),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabLabels = [l10n.all, l10n.upcoming, l10n.past];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myTrips),
        bottom: TabBar(
          controller: _tabController,
          tabs: List.generate(
            _tabIcons.length,
            (i) => Tab(icon: Icon(_tabIcons[i], size: 20), text: tabLabels[i]),
          ),
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(
          _tabIcons.length,
          (i) => _tabBody(context, i),
        ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => context.push('/trip/new'),
      ),
    );
  }
}

/// Section shown at the top of the Trips list when the user has pending invites.
/// Each invite gets its own card with full-width Accept / Decline buttons.
class _InviteCard extends StatelessWidget {
  final InvitationsProvider invitations;

  const _InviteCard({required this.invitations});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = AppTheme.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    color: accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.tripInvitationsTitle(invitations.pendingCount),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // One card per invite
          ...invitations.invites.map(
            (invite) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InviteRow(invite: invite),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatefulWidget {
  final InvitationItem invite;

  const _InviteRow({required this.invite});

  @override
  State<_InviteRow> createState() => _InviteRowState();
}

class _InviteRowState extends State<_InviteRow> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invite = widget.invite;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip title
            Text(
              invite.tripTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (invite.destination != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      invite.destination!,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (_loading)
              const Center(
                child: SizedBox(
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Decline — minimal, no fill
                  TextButton(
                    onPressed: () => _decline(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[500],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text(l10n.declineInvite),
                  ),
                  const SizedBox(width: 6),
                  // Accept — filled pill
                  FilledButton.icon(
                    onPressed: () => _accept(context),
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: Text(l10n.acceptInvite),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    setState(() => _loading = true);
    try {
      await context
          .read<InvitationsProvider>()
          .accept(widget.invite.memberId, context.read<TripProvider>());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decline(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    bool blockReinvite = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.declineInviteConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.declineInviteConfirmMessage(widget.invite.tripTitle)),
              const SizedBox(height: 8),
              SwitchListTile(
                value: blockReinvite,
                onChanged: (v) => setS(() => blockReinvite = v),
                title: Text(l10n.blockReinviteLabel,
                    style: const TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.declineInvite,
                  style: const TextStyle(color: AppTheme.danger)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    setState(() => _loading = true);
    try {
      await context.read<InvitationsProvider>().decline(
            widget.invite.memberId,
            context.read<TripProvider>(),
            blockReinvite: blockReinvite,
          );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final int tabIndex;

  const _EmptyState({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = [l10n.noTripsYet, l10n.noUpcomingTrips, l10n.noPastTrips];
    final subtitles = [
      l10n.noTripsHint,
      l10n.noUpcomingTripsHint,
      l10n.noPastTripsHint,
    ];
    final title = titles[tabIndex];
    final subtitle = subtitles[tabIndex];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flight_takeoff_rounded,
              size: 64, color: AppTheme.primaryLight),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }
}
