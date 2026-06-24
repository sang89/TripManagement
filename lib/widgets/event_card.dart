import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import 'event_type_banner.dart';

// Standard luminance greyscale matrix — desaturates past/archived cards.
const ColorFilter _kGreyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

class EventCard extends StatelessWidget {
  final Event event;
  final String? currentUserId;

  const EventCard({super.key, required this.event, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = event.isPastFor(currentUserId);
    final isOngoing = !isPast &&
        event.startAt.isBefore(now) &&
        (event.endAt == null || event.endAt!.isAfter(now));

    final isPendingInvite = !isPast &&
        currentUserId != null &&
        event.guests.any(
            (g) => g.userId == currentUserId && g.isPending);

    final statusLabel = isPendingInvite
        ? 'Invited'
        : isOngoing
            ? 'Ongoing'
            : isPast
                ? 'Past'
                : 'Upcoming';
    final statusColor = isPendingInvite
        ? Colors.orange
        : isOngoing
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
      EventType.tournament => Icons.emoji_events_outlined,
      EventType.quickBites => Icons.restaurant_outlined,
      EventType.signup => Icons.how_to_reg_outlined,
    };

    final pendingCount =
        event.isTrip ? event.guests.where((g) => g.status == 'pending').length : 0;
    const String? recurringLabel = null;

    // Move-to-Past / Move-to-Upcoming availability (per-user).
    final canMoveToPast = !isPast;
    final canRestore =
        event.isArchivedFor(currentUserId) && !event.isDatePast;
    final hasLongPressAction = canMoveToPast || canRestore;

    Widget body = _ThemedCardBody(
      bannerTheme: bannerThemeFor(event.eventType),
      typeIcon: typeIcon,
      title: event.title,
      location: event.location,
      dateRange: dateRange,
      guestCount: event.guests.length,
      pendingCount: pendingCount,
      recurringLabel: recurringLabel,
      statusLabel: statusLabel,
      statusColor: statusColor,
    );

    // Past / archived cards read as "done": desaturated + faded.
    if (isPast) {
      body = ColorFiltered(
        key: const ValueKey('eventCardDim'),
        colorFilter: _kGreyscale,
        child: Opacity(opacity: 0.6, child: body),
      );
    }

    return AppTappable(
      onTap: () => context.push('/event/${event.id}'),
      onLongPress: hasLongPressAction
          ? () => _showMoveSheet(context, toPast: canMoveToPast)
          : null,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }

  Future<void> _showMoveSheet(BuildContext context,
      {required bool toPast}) async {
    final l10n = AppLocalizations.of(context);
    final provider = context.read<EventProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final accent = toPast ? AppTheme.primary : AppTheme.accent;
    final emoji = toPast ? '🗂️' : '🎉';
    final title = toPast ? l10n.moveToPast : l10n.moveToUpcoming;
    final subtitle =
        toPast ? l10n.moveToPastSubtitle : l10n.moveToUpcomingSubtitle;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            // Which event this is about.
            Text(
              event.title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            AppTappable(
              onTap: () => Navigator.of(ctx).pop(true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.12),
                      accent.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.25), width: 1),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade600,
                                height: 1.25),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: accent.withValues(alpha: 0.6)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    await provider.setEventArchived(event.id, toPast);
    messenger.showSnackBar(
      SnackBar(
        content: Text(toPast ? l10n.movedToPast : l10n.movedToUpcoming),
        duration: const Duration(seconds: 2),
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
  final String? recurringLabel;
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
    this.recurringLabel,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    // Stack without StackFit.expand — the non-positioned content child drives height.
    // Positioned.fill children (banner + fade) stretch to match.
    return Stack(
      children: [
        Positioned.fill(
          child: EventTypeBanner(theme: bannerTheme),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.60),
                ],
              ),
            ),
          ),
        ),
        // Content drives the card height — no Spacer, no fixed size
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, size: 20, color: Colors.white),
                  const Spacer(),
                  if (recurringLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 0.8),
                      ),
                      child: Text(
                        recurringLabel!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (pendingCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount pending',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _StatusChip(
                      label: statusLabel, color: statusColor, onImage: true),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (location.isNotEmpty) ...[
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(dateRange,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 12),
                  const Icon(Icons.people_outline,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text('$guestCount',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ],
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
