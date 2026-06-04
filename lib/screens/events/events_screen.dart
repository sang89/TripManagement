import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authUid = context.read<AuthProvider>().userId;

    void goNew() => context.push('/event/new');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navEvents),
      ),
      floatingActionButton: AppFab(
        onPressed: goNew,
      ),
      body: Consumer<EventProvider>(
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
          if (provider.events.isEmpty) {
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
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 180,
                    child: AppButton(
                      onPressed: goNew,
                      label: l10n.newEvent,
                    ),
                  ),
                ],
              ),
            );
          }

          final myEvents = provider.myEvents;
          final invited = provider.invitedEvents;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (myEvents.isNotEmpty) ...[
                _SectionHeader(l10n.myEvents),
                ...myEvents.map((e) => _EventCard(event: e, authUid: authUid)),
              ],
              if (invited.isNotEmpty) ...[
                _SectionHeader(l10n.invitedEvents),
                ...invited.map((e) => _EventCard(event: e, authUid: authUid)),
              ],
            ],
          );
        },
      ),
    );
  }
}

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

class _EventCard extends StatelessWidget {
  final Event event;
  final String? authUid;

  const _EventCard({required this.event, required this.authUid});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('EEE, MMM d · h:mm a');
    final myGuest = event.guests.where((g) => g.userId == authUid).firstOrNull;
    final isOrganizer = event.createdBy == authUid;

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
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                  else if (myGuest != null)
                    _RsvpChip(status: myGuest.rsvpStatus, l10n: l10n),
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
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    l10n.goingCount(event.goingCount),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (event.maybeCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      l10n.maybeCount(event.maybeCount),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
