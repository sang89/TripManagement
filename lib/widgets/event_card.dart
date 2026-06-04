import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/event.dart';

class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = event.endAt != null && event.endAt!.isBefore(now);
    final isOngoing = !isPast &&
        event.startAt.isBefore(now) &&
        (event.endAt == null || event.endAt!.isAfter(now));

    final statusLabel = isOngoing ? 'Ongoing' : isPast ? 'Past' : 'Upcoming';
    final statusColor = isOngoing
        ? AppTheme.accent
        : isPast
            ? Colors.grey
            : AppTheme.primaryLight;

    final fmt = DateFormat('MMM d, y');
    final dateRange = event.endAt != null
        ? '${fmt.format(event.startAt)} – ${fmt.format(event.endAt!)}'
        : 'From ${fmt.format(event.startAt)}';

    final typeIcon = switch (event.eventType) {
      EventType.trip => Icons.luggage_outlined,
      EventType.birthday => Icons.cake_outlined,
      EventType.wedding => Icons.favorite_outline,
      EventType.social => Icons.celebration_outlined,
    };

    final pendingCount =
        event.isTrip ? event.guests.where((g) => g.status == 'pending').length : 0;

    return AppTappable(
      onTap: () => context.push('/event/${event.id}'),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                            width: 0.8),
                      ),
                      child: Text(
                        '$pendingCount pending',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _StatusChip(label: statusLabel, color: statusColor),
                ],
              ),
              if (event.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateRange,
                    style:
                        TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  const Spacer(),
                  const Icon(Icons.people_outline,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${event.guests.length} guest${event.guests.length == 1 ? '' : 's'}',
                    style:
                        TextStyle(color: Colors.grey[700], fontSize: 14),
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
