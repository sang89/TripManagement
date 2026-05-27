import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/trip.dart';

class TripCard extends StatelessWidget {
  final Trip trip;

  const TripCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast =
        trip.endAt != null && trip.endAt!.isBefore(now);
    final isOngoing = !isPast &&
        trip.startAt != null &&
        trip.startAt!.isBefore(now) &&
        (trip.endAt == null || trip.endAt!.isAfter(now));

    final statusLabel = isOngoing ? 'Ongoing' : isPast ? 'Past' : 'Upcoming';
    final statusColor = isOngoing
        ? AppTheme.accent
        : isPast
            ? Colors.grey
            : AppTheme.primaryLight;

    final fmt = DateFormat('MMM d, y');
    final dateRange = switch ((trip.startAt, trip.endAt)) {
      (final s?, final e?) => '${fmt.format(s)} – ${fmt.format(e)}',
      (final s?, null) => 'From ${fmt.format(s)}',
      (null, final e?) => 'Until ${fmt.format(e)}',
      _ => 'Dates not set',
    };

    return AppTappable(
      onTap: () => context.push('/trip/${trip.id}'),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusChip(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.destination,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateRange,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  const Spacer(),
                  const Icon(Icons.people_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.members.length} member${trip.members.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
