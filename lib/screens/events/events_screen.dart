import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/event_card.dart';
import '../../widgets/event_type_banner.dart';

enum _EventTab { upcoming, invited, past }

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  _EventTab _selectedTab = _EventTab.upcoming;
  EventType? _typeFilter;

  @override
  void initState() {
    super.initState();
    // On web, Stripe redirects back to /events?stripe_success=true after payment.
    // Reload subscription so isPro updates without requiring a restart.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final uri = Uri.base;
        if (uri.queryParameters['stripe_success'] == 'true') {
          final uid = context.read<AuthProvider>().userId;
          if (uid != null) {
            context.read<SubscriptionProvider>().load(uid);
          }
          context.go('/events');
        }
      });
    }
  }

  void _onFabTap() {
    final events = context.read<EventProvider>();
    final sub = context.read<SubscriptionProvider>();
    if (!sub.isPro && events.myEvents.length >= 3) {
      context.push('/paywall');
      return;
    }
    context.push('/event/new');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navEvents)),
      floatingActionButton: AppFab(onPressed: _onFabTap),
      body: Consumer<EventProvider>(
        builder: (_, provider, _) {
          return Column(
            children: [
              AppTabSelector<_EventTab>(
                selected: _selectedTab,
                onChanged: (v) => setState(() => _selectedTab = v),
                items: [
                  AppTabItem(label: l10n.upcoming, value: _EventTab.upcoming, icon: Icons.schedule),
                  AppTabItem(label: l10n.invitedEvents, value: _EventTab.invited, icon: Icons.mail_outline, badge: provider.pendingInviteCount),
                  AppTabItem(label: l10n.past, value: _EventTab.past, icon: Icons.history),
                ],
              ),
              _TypeFilterRow(
                selected: _typeFilter,
                onChanged: (v) => setState(() => _typeFilter = v),
                l10n: l10n,
              ),
              const Divider(height: 1),
              Expanded(
                child: _EventList(
                  provider: provider,
                  tab: _selectedTab,
                  typeFilter: _typeFilter,
                  l10n: l10n,
                  onCreateTap: _onFabTap,
                  currentUserId: context.read<AuthProvider>().userId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Type filter chip row ────────────────────────────────────────────────────

class _TypeFilterRow extends StatelessWidget {
  final EventType? selected;
  final ValueChanged<EventType?> onChanged;
  final AppLocalizations l10n;

  const _TypeFilterRow({
    required this.selected,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final types = EventType.values;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: types.length + 1, // +1 for "All"
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _TypeChip(
              label: l10n.filterAll,
              isSelected: selected == null,
              gradientColors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.7)],
              onTap: () => onChanged(null),
            );
          }
          final type = types[index - 1];
          final theme = bannerThemeFor(type);
          final label = switch (type) {
            EventType.trip => l10n.eventTypeTrip,
            EventType.birthday => l10n.eventTypeBirthday,
            EventType.wedding => l10n.eventTypeWedding,
            EventType.social => l10n.eventTypeSocial,
            EventType.quickBites => l10n.eventTypeQuickBites,
          };
          return _TypeChip(
            label: label,
            isSelected: selected == type,
            gradientColors: theme.gradientColors.take(2).toList(),
            onTap: () => onChanged(selected == type ? null : type),
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Event list ──────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  final EventProvider provider;
  final _EventTab tab;
  final EventType? typeFilter;
  final AppLocalizations l10n;
  final VoidCallback onCreateTap;
  final String? currentUserId;

  const _EventList({
    required this.provider,
    required this.tab,
    required this.typeFilter,
    required this.l10n,
    required this.onCreateTap,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (!provider.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.loadError != null) {
      return Center(child: Text(provider.loadError!));
    }

    final now = DateTime.now();
    var events = [...provider.myEvents, ...provider.invitedEvents];

    events = switch (tab) {
      _EventTab.upcoming => events
          .where((e) => !(e.endAt != null && e.endAt!.isBefore(now)))
          .toList(),
      _EventTab.invited => events.where((e) =>
          !(e.endAt != null && e.endAt!.isBefore(now)) &&
          currentUserId != null &&
          e.guests.any((g) => g.userId == currentUserId && g.isPending)).toList(),
      _EventTab.past => events
          .where((e) => e.endAt != null && e.endAt!.isBefore(now))
          .toList(),
    };

    if (typeFilter != null) {
      events = events.where((e) => e.eventType == typeFilter).toList();
    }

    if (tab == _EventTab.past) {
      events.sort((a, b) =>
          (b.endAt ?? b.startAt).compareTo(a.endAt ?? a.startAt));
    } else {
      events.sort((a, b) => a.startAt.compareTo(b.startAt));
    }

    if (events.isEmpty) {
      return _EmptyState(tab: tab, l10n: l10n, onCreateTap: onCreateTap,
          pendingCount: provider.pendingInviteCount);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: events.length,
      itemBuilder: (context, index) => EventCard(
            event: events[index],
            currentUserId: currentUserId,
          ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _EventTab tab;
  final AppLocalizations l10n;
  final VoidCallback onCreateTap;
  final int pendingCount;

  const _EmptyState({
    required this.tab,
    required this.l10n,
    required this.onCreateTap,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final (emoji, title, hint) = switch (tab) {
      _EventTab.upcoming => ('🎉', l10n.noUpcomingEvents, l10n.noUpcomingEventsHint),
      _EventTab.invited  => ('✉️', 'No pending invites', 'Events you\'ve been invited to will appear here.'),
      _EventTab.past     => ('📅', l10n.noPastEvents, l10n.noPastEventsHint),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            if (tab == _EventTab.upcoming) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: AppButton(label: l10n.newEvent, onPressed: onCreateTap),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
