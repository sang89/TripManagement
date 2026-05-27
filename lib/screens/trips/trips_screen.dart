import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/trip_card.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  int _tabIndex = 0;

  List<Trip> _filtered(List<Trip> trips) {
    final now = DateTime.now();
    return switch (_tabIndex) {
      0 => trips
          .where((t) => t.endAt == null || t.endAt!.isAfter(now))
          .toList(),
      1 => trips
          .where((t) => t.endAt != null && t.endAt!.isBefore(now))
          .toList(),
      _ => trips,
    };
  }

  Future<void> _confirmDelete(BuildContext context, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text('Delete "${trip.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TripProvider>().deleteTrip(trip.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final filtered = _filtered(provider.trips);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: AppTabSelector<int>(
            items: const [
              AppTabItem(label: 'Upcoming', value: 0),
              AppTabItem(label: 'Past', value: 1),
              AppTabItem(label: 'All', value: 2),
            ],
            selected: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
        ),
      ),
      body: !provider.loaded
          ? const Center(child: CircularProgressIndicator())
          : provider.loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined,
                            size: 48, color: AppTheme.danger),
                        const SizedBox(height: 12),
                        const Text('Could not load trips',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(provider.loadError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Retry',
                          onPressed: () =>
                              context.read<TripProvider>().load(),
                        ),
                      ],
                    ),
                  ),
                )
          : filtered.isEmpty
          ? _EmptyState(tabIndex: _tabIndex)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final trip = filtered[index];
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
                        label: 'Delete',
                      ),
                    ],
                  ),
                  child: TripCard(trip: trip),
                );
              },
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
    final messages = [
      ('No upcoming trips', 'Tap + to plan your next adventure.'),
      ('No past trips', 'Your completed trips will appear here.'),
      ('No trips yet', 'Tap + to get started.'),
    ];
    final (title, subtitle) = messages[tabIndex];
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
