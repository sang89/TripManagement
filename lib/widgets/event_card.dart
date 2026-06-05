import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/event.dart';
import 'event_type_banner.dart';

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
      EventType.quickBites => Icons.restaurant_outlined,
    };

    final pendingCount =
        event.isTrip ? event.guests.where((g) => g.status == 'pending').length : 0;

    return AppTappable(
      onTap: () => context.push('/event/${event.id}'),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: _ThemedCardBody(
          bannerTheme: bannerThemeFor(event.eventType),
          typeIcon: typeIcon,
          title: event.title,
          location: event.location,
          dateRange: dateRange,
          guestCount: event.guests.length,
          pendingCount: pendingCount,
          statusLabel: statusLabel,
          statusColor: statusColor,
        ),
      ),
    );
  }
}

// ── Themed (gradient + icon pattern) card body ───────────────────────────────

class _ThemedCardBody extends StatelessWidget {
  final EventTypeBannerTheme bannerTheme;
  final IconData typeIcon;
  final String title;
  final String location;
  final String dateRange;
  final int guestCount;
  final int pendingCount;
  final String statusLabel;
  final Color statusColor;

  const _ThemedCardBody({
    required this.bannerTheme,
    required this.typeIcon,
    required this.title,
    required this.location,
    required this.dateRange,
    required this.guestCount,
    required this.pendingCount,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EventTypeBanner(theme: bannerTheme, height: 160),
          // bottom dark fade so text pops
          Align(
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
              child: const SizedBox(height: 80, width: double.infinity),
            ),
          ),
          // content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(typeIcon, size: 18, color: Colors.white),
                    const Spacer(),
                    if (pendingCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pendingCount pending',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _StatusChip(
                        label: statusLabel, color: statusColor, onImage: true),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (location.isNotEmpty) ...[
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: Colors.white70),
                    const SizedBox(width: 3),
                    Text(dateRange,
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 10),
                    const Icon(Icons.people_outline,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 3),
                    Text('$guestCount',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool onImage;

  const _StatusChip(
      {required this.label, required this.color, this.onImage = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onImage
            ? Colors.white.withValues(alpha: 0.25)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: onImage
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.5), width: 0.8)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onImage ? Colors.white : color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
