import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../responsive/breakpoints.dart';

class EventTypeListScreen extends StatelessWidget {
  final EventType eventType;

  const EventTypeListScreen({super.key, required this.eventType});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authUid = context.read<AuthProvider>().userId;

    final label = switch (eventType) {
      EventType.trip => l10n.eventTypeTrip,
      EventType.birthday => l10n.eventTypeBirthday,
      EventType.wedding => l10n.eventTypeWedding,
      EventType.tournament => l10n.eventTypeTournament,
      EventType.quickBites => l10n.eventTypeQuickBites,
      EventType.signup => l10n.eventTypeSignup,
    };

    void goNew() =>
        context.push('/event/new?type=${eventType.dbValue}');

    return Scaffold(
      appBar: AppBar(title: Text(label)),
      floatingActionButton: AppFab(onPressed: goNew),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop(context) ? 900 : double.infinity,
          ),
          child: Consumer<EventProvider>(
        builder: (_, provider, _) {
          if (!provider.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.loadError != null && provider.events.isEmpty) {
            return Center(
              child: Text(
                provider.loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.danger),
              ),
            );
          }

          final myEvents = provider.myEvents
              .where((e) => e.eventType == eventType)
              .toList();
          final invited = provider.invitedEvents
              .where((e) => e.eventType == eventType)
              .toList();

          if (myEvents.isEmpty && invited.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noEventsYet,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 180,
                    child: AppButton(onPressed: goNew, label: l10n.newEvent),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (myEvents.isNotEmpty) ...[
                _SectionHeader(l10n.myEvents),
                ...myEvents
                    .map((e) => _EventCard(event: e, authUid: authUid)),
              ],
              if (invited.isNotEmpty) ...[
                _SectionHeader(l10n.invitedEvents),
                ...invited
                    .map((e) => _EventCard(event: e, authUid: authUid)),
              ],
            ],
          );
        },
      ),
        ),
      ),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
}

// ─── Event card ───────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Event event;
  final String? authUid;

  const _EventCard({required this.event, required this.authUid});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('EEE, MMM d · h:mm a');
    final myGuest =
        event.guests.where((g) => g.userId == authUid).firstOrNull;
    final isOrganizer = event.createdBy == authUid;

    final typeIcon = switch (event.eventType) {
      EventType.trip => Icons.luggage_outlined,
      EventType.birthday => Icons.cake_outlined,
      EventType.wedding => Icons.favorite_outline,
      EventType.tournament => Icons.emoji_events_outlined,
      EventType.quickBites => Icons.restaurant_outlined,
      EventType.signup => Icons.how_to_reg_outlined,
    };

    final pendingCount = event.isTrip
        ? event.guests.where((g) => g.status == 'pending').length
        : 0;

    return AppTappable(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                            width: 0.8),
                      ),
                      child: Text(
                        '$pendingCount pending',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (isOrganizer)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.organizer,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  else if (myGuest != null && !event.isTrip)
                    _RsvpChip(status: myGuest.status, l10n: l10n),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fmt.format(event.startAt.toLocal()),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (event.location.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people_outline,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    event.isTrip
                        ? '${event.goingCount} member${event.goingCount == 1 ? '' : 's'}'
                        : l10n.goingCount(event.goingCount),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (!event.isTrip && event.maybeCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      l10n.maybeCount(event.maybeCount),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── RSVP chip ────────────────────────────────────────────────────────────────

class _RsvpChip extends StatelessWidget {
  final String status;
  final AppLocalizations l10n;

  const _RsvpChip({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'going' => (l10n.rsvpGoing, Colors.green),
      'maybe' => (l10n.rsvpMaybe, Colors.orange),
      _ => (l10n.rsvpDeclined, AppTheme.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
