import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/trip.dart';
import '../../models/trip_stop.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/trip_map_widget.dart';
import '../../widgets/trip_stop_form_sheet.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0; // tracked for FAB visibility

  static const _tabIcons = [
    Icons.info_outline_rounded,
    Icons.route_outlined,
    Icons.map_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabIcons.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteStop(BuildContext context, TripStop stop) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeStopTitle),
        content: Text(l10n.removeStopMessage(stop.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.remove,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TripProvider>().deleteStop(stop.id, widget.tripId);
    }
  }

  // Pin order: start → stops (by sortOrder) → destination.
  // This matches the driving direction passed to DirectionsService.
  List<TripMapPin> _buildMapPins(Trip trip) {
    final pins = <TripMapPin>[];
    if (trip.startLat != null && trip.startLng != null) {
      pins.add(TripMapPin(
        id: 'start',
        position: LatLng(trip.startLat!, trip.startLng!),
        title: trip.startLocation ?? 'Start',
        isStart: true,
      ));
    }
    for (final stop in trip.stops) {
      if (stop.addressLat != null && stop.addressLng != null) {
        pins.add(TripMapPin(
          id: stop.id,
          position: LatLng(stop.addressLat!, stop.addressLng!),
          title: stop.title,
          subtitle: stop.address.isNotEmpty ? stop.address : null,
        ));
      }
    }
    if (trip.destinationLat != null && trip.destinationLng != null) {
      pins.add(TripMapPin(
        id: 'destination',
        position: LatLng(trip.destinationLat!, trip.destinationLng!),
        title: trip.destination,
        isDestination: true,
      ));
    }
    return pins;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabLabels = [l10n.overview, l10n.itinerary, l10n.mapTab];
    final trip = context.watch<TripProvider>().getById(widget.tripId);
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.tripNotFound)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: List.generate(
            _tabIcons.length,
            (i) => Tab(icon: Icon(_tabIcons[i], size: 20), text: tabLabels[i]),
          ),
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editTripTooltip,
            onPressed: () => context.push('/trip/${trip.id}/edit'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(trip: trip),
          _ItineraryTab(
            trip: trip,
            onDeleteStop: (s) => _confirmDeleteStop(context, s),
          ),
          TripMapWidget(pins: _buildMapPins(trip)),
        ],
      ),
      floatingActionButton: _tabIndex == 1
          ? AppFab(
              onPressed: () =>
                  showTripStopFormSheet(context, tripId: trip.id),
            )
          : null,
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Trip trip;

  const _OverviewTab({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('MMM d, y  h:mm a');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (trip.startLocation != null &&
            trip.startLocation!.isNotEmpty) ...[
          _InfoRow(
            icon: Icons.trip_origin_outlined,
            label: l10n.startingFrom,
            value: trip.startLocation!,
          ),
          const SizedBox(height: 12),
        ],
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: l10n.destination,
          value: trip.destination,
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: l10n.startLabel,
          value:
              trip.startAt != null ? fmt.format(trip.startAt!) : l10n.notSet,
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.event_outlined,
          label: l10n.endLabel,
          value: trip.endAt != null ? fmt.format(trip.endAt!) : l10n.notSet,
        ),
        if (trip.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.notes_outlined,
            label: l10n.notes,
            value: trip.notes,
          ),
        ],
        const SizedBox(height: 24),
        Text(l10n.membersSection,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...trip.members.map((m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: m.role == 'organizer'
                    ? AppTheme.primary
                    : Colors.grey[200],
                child: Text(
                    m.displayName.isNotEmpty
                        ? m.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: m.role == 'organizer'
                            ? Colors.white
                            : AppTheme.primary)),
              ),
              title: Text(m.displayName),
              subtitle: Text(m.role == 'organizer'
                  ? l10n.organizer
                  : l10n.member),
              dense: true,
            )),
      ],
    );
  }
}

class _ItineraryTab extends StatelessWidget {
  final Trip trip;
  final void Function(TripStop stop) onDeleteStop;

  const _ItineraryTab(
      {required this.trip, required this.onDeleteStop});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (trip.stops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined,
                size: 64, color: AppTheme.primaryLight),
            const SizedBox(height: 16),
            Text(l10n.noStopsInItinerary),
            const SizedBox(height: 8),
            Text(l10n.addFirstStop,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: trip.stops.length,
      itemBuilder: (context, index) {
        final stop = trip.stops[index];
        return Slidable(
          key: ValueKey(stop.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => onDeleteStop(stop),
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: l10n.delete,
              ),
            ],
          ),
          child: _StopCard(stop: stop, tripId: trip.id),
        );
      },
    );
  }
}

class _StopCard extends StatelessWidget {
  final TripStop stop;
  final String tripId;

  const _StopCard({required this.stop, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFmt = DateFormat('MMM d  h:mm a');
    return AppTappable(
      onTap: () =>
          showTripStopFormSheet(context, tripId: tripId, existing: stop),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stop.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              if (stop.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(stop.address,
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
              if (stop.arriveAt != null || stop.departAt != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      [
                        if (stop.arriveAt != null)
                          '${l10n.arrive} ${timeFmt.format(stop.arriveAt!)}',
                        if (stop.departAt != null)
                          '${l10n.depart} ${timeFmt.format(stop.departAt!)}',
                      ].join('  ·  '),
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ],
              if (stop.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(stop.notes,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}
