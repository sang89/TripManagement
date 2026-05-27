import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip.dart';
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
    return Slidable(
      key: ValueKey(trip.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _confirmDelete(context, trip),
            backgroundColor: AppTheme.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: l10n.delete,
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

    if (filtered.isEmpty) {
      return _EmptyState(tabIndex: tabIndex);
    }

    return AppReorderableList<Trip>(
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
