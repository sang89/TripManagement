import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navEvents)),
      floatingActionButton: AppFab(onPressed: () => context.push('/event/new')),
      body: Consumer<EventProvider>(
        builder: (_, provider, _) {
          final all = [...provider.myEvents, ...provider.invitedEvents];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: EventType.values.map((type) {
                final count =
                    all.where((e) => e.eventType == type).length;
                return _TypeTile(
                  type: type,
                  count: count,
                  l10n: l10n,
                  onTap: () =>
                      context.push('/events/${type.dbValue}'),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ─── Type tile ──────────────────────────────────────────────────────────────

class _TypeTile extends StatelessWidget {
  final EventType type;
  final int count;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _TypeTile({
    required this.type,
    required this.count,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, colors, label) = switch (type) {
      EventType.trip => (
          Icons.luggage_outlined,
          [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
          l10n.eventTypeTrip,
        ),
      EventType.birthday => (
          Icons.cake_outlined,
          [const Color(0xFFAD1457), const Color(0xFFF06292)],
          l10n.eventTypeBirthday,
        ),
      EventType.wedding => (
          Icons.favorite_outline,
          [const Color(0xFF6A1B9A), const Color(0xFFBA68C8)],
          l10n.eventTypeWedding,
        ),
      EventType.social => (
          Icons.celebration_outlined,
          [const Color(0xFFE65100), const Color(0xFFFF8A65)],
          l10n.eventTypeSocial,
        ),
    };

    return AppTappable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count == 0
                  ? '–'
                  : '$count ${count == 1 ? 'event' : 'events'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
