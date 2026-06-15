import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/event_card.dart';
import '../../widgets/event_type_banner.dart';
import '../notifications/notifications_screen.dart';

enum _EventTab { upcoming, invited, past }

// Vibrant gradient mixing all five event type colours + one icon from each.
const _kAllEventsBannerTheme = EventTypeBannerTheme(
  gradientColors: [
    Color(0xFF1565C0), // trip blue
    Color(0xFF7B1FA2), // wedding purple
    Color(0xFFE91E63), // birthday pink
    Color(0xFFFF6F00), // quick-bites orange
  ],
  icons: [
    Icons.flight_rounded,
    Icons.cake_rounded,
    Icons.favorite_rounded,
    Icons.celebration_rounded,
    Icons.restaurant_rounded,
    Icons.luggage_rounded,
    Icons.music_note_rounded,
    Icons.auto_awesome_rounded,
    Icons.camera_alt_rounded,
    Icons.local_florist_rounded,
    Icons.stars_rounded,
    Icons.diamond_rounded,
  ],
);

// ─── Shared filter helper ─────────────────────────────────────────────────────

List<Event> _filteredEvents({
  required EventProvider provider,
  required _EventTab tab,
  required EventType? typeFilter,
  required String? currentUserId,
}) {
  final now = DateTime.now();
  var events = [...provider.myEvents, ...provider.invitedEvents];

  events = switch (tab) {
    _EventTab.upcoming => events
        .where((e) => !(e.endAt != null && e.endAt!.isBefore(now)))
        .toList(),
    _EventTab.invited => events
        .where((e) =>
            !(e.endAt != null && e.endAt!.isBefore(now)) &&
            currentUserId != null &&
            e.guests.any((g) => g.userId == currentUserId && g.isPending))
        .toList(),
    _EventTab.past => events
        .where((e) => e.endAt != null && e.endAt!.isBefore(now))
        .toList(),
  };

  if (typeFilter != null) {
    events = events.where((e) => e.eventType == typeFilter).toList();
  }
  return events;
}

// Returns events that overlap with [day] (handles multi-day trips).
List<Event> _eventsOnDay(DateTime day, List<Event> events) {
  final d = DateTime(day.year, day.month, day.day);
  return events.where((e) {
    final start = DateTime(e.startAt.year, e.startAt.month, e.startAt.day);
    if (e.endAt == null) return start == d;
    final end = DateTime(e.endAt!.year, e.endAt!.month, e.endAt!.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }).toList();
}

Color _dotColorFor(EventType type) => switch (type) {
      EventType.trip => const Color(0xFF1565C0),
      EventType.birthday => const Color(0xFFE91E63),
      EventType.wedding => const Color(0xFF7B1FA2),
      EventType.social => const Color(0xFF00897B),
      EventType.quickBites => const Color(0xFFE64A19),
      EventType.signup => const Color(0xFF2E7D32),
    };

// ─── Screen ───────────────────────────────────────────────────────────────────

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  _EventTab _selectedTab = _EventTab.upcoming;
  EventType? _typeFilter;
  bool _calendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    // On web, Stripe redirects back to /events?stripe_success=true after payment.
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
    final provider = context.watch<EventProvider>();
    final userId = context.read<AuthProvider>().userId;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          flexibleSpace: EventTypeBanner(
            theme: _kAllEventsBannerTheme,
            height: double.infinity,
          ),
          title: Text(l10n.navEvents),
          actions: [
            Consumer<NotificationsProvider>(
              builder: (_, notifs, _) => AppTappable(
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
                // UnconstrainedBox breaks the AppBar's stretch constraint
                // (which inflates action widgets to the full AppBar height,
                // ~104px with the TabBar bottom). Without it, SizedBox(40,40)
                // is overridden to 104px tall and Positioned(top:N) anchors
                // to the top of that giant box, far from the icon.
                child: UnconstrainedBox(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          notifs.unreadCount > 0
                              ? Icons.notifications_rounded
                              : Icons.notifications_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        if (notifs.unreadCount > 0)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                notifs.unreadCount > 9
                                    ? '9+'
                                    : '${notifs.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _calendarView
                    ? Icons.view_list_rounded
                    : Icons.calendar_month_rounded,
                color: Colors.white,
              ),
              tooltip: _calendarView
                  ? l10n.listViewToggle
                  : l10n.calendarViewToggle,
              onPressed: () => setState(() {
                _calendarView = !_calendarView;
                if (!_calendarView) _selectedDay = null;
              }),
            ),
          ],
          bottom: TabBar(
            onTap: (i) => setState(() => _selectedTab = _EventTab.values[i]),
            tabAlignment: TabAlignment.fill,
            labelStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                  icon: const Icon(Icons.schedule, size: 20),
                  text: l10n.upcoming),
              Tab(
                icon: _BadgedIcon(
                  icon: Icons.mail_outline,
                  count: provider.pendingInviteCount,
                ),
                text: l10n.invitedEvents,
              ),
              Tab(
                  icon: const Icon(Icons.history, size: 20),
                  text: l10n.past),
            ],
          ),
        ),
        floatingActionButton: AppFab(onPressed: _onFabTap),
        body: Column(
          children: [
            _TypeFilterRow(
              selected: _typeFilter,
              onChanged: (v) => setState(() => _typeFilter = v),
              l10n: l10n,
            ),
            const Divider(height: 1),
            Expanded(
              child: _calendarView
                  ? _CalendarView(
                      provider: provider,
                      tab: _selectedTab,
                      typeFilter: _typeFilter,
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      onDaySelected: (sel, foc) => setState(() {
                        _selectedDay = sel;
                        _focusedDay = foc;
                      }),
                      onPageChanged: (foc) =>
                          setState(() => _focusedDay = foc),
                      l10n: l10n,
                      currentUserId: userId,
                    )
                  : _EventList(
                      provider: provider,
                      tab: _selectedTab,
                      typeFilter: _typeFilter,
                      l10n: l10n,
                      onCreateTap: _onFabTap,
                      currentUserId: userId,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Badged icon for tab bar ──────────────────────────────────────────────────

class _BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  const _BadgedIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 20),
          if (count > 0)
            Positioned(
              top: -4,
              right: -10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
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
        itemCount: types.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _TypeChip(
              label: l10n.filterAll,
              isSelected: selected == null,
              gradientColors: [
                AppTheme.primary,
                AppTheme.primary.withValues(alpha: 0.7)
              ],
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
            EventType.signup => l10n.eventTypeSignup,
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
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
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

// ─── Calendar view ───────────────────────────────────────────────────────────

class _CalendarView extends StatelessWidget {
  final EventProvider provider;
  final _EventTab tab;
  final EventType? typeFilter;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final void Function(DateTime focused) onPageChanged;
  final AppLocalizations l10n;
  final String? currentUserId;

  const _CalendarView({
    required this.provider,
    required this.tab,
    required this.typeFilter,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.l10n,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEvents(
      provider: provider,
      tab: tab,
      typeFilter: typeFilter,
      currentUserId: currentUserId,
    );

    final dayEvents = selectedDay != null
        ? _eventsOnDay(selectedDay!, filtered)
        : <Event>[];

    return Column(
      children: [
        TableCalendar<Event>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
          eventLoader: (day) => _eventsOnDay(day, filtered),
          calendarFormat: CalendarFormat.month,
          calendarBuilders: CalendarBuilders(
            markerBuilder: (ctx, day, events) {
              if (events.isEmpty) return null;
              final types = events.map((e) => e.eventType).toSet().toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: types
                      .take(5)
                      .map((t) => Container(
                            width: 6,
                            height: 6,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: _dotColorFor(t),
                              shape: BoxShape.circle,
                            ),
                          ))
                      .toList(),
                ),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: const BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            selectedDecoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            weekendTextStyle:
                const TextStyle(color: Color(0xFFE91E63)),
            outsideTextStyle: TextStyle(color: Colors.grey.shade400),
            markersMaxCount: 5,
            markerDecoration: const BoxDecoration(shape: BoxShape.circle),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
            leftChevronIcon:
                const Icon(Icons.chevron_left, color: AppTheme.primary),
            rightChevronIcon:
                const Icon(Icons.chevron_right, color: AppTheme.primary),
          ),
        ),
        const Divider(height: 1),
        if (selectedDay != null) ...[
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Text(
              DateFormat('EEEE, MMMM d').format(selectedDay!),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _DayEventList(
              events: dayEvents,
              l10n: l10n,
              currentUserId: currentUserId,
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Text(
                '👆 Tap a date to see events',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade500),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Day event list ───────────────────────────────────────────────────────────

class _DayEventList extends StatelessWidget {
  final List<Event> events;
  final AppLocalizations l10n;
  final String? currentUserId;

  const _DayEventList({
    required this.events,
    required this.l10n,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          l10n.noEventsOnDay,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey.shade500),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: events.length,
      itemBuilder: (ctx, i) =>
          EventCard(event: events[i], currentUserId: currentUserId),
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

    var events = _filteredEvents(
      provider: provider,
      tab: tab,
      typeFilter: typeFilter,
      currentUserId: currentUserId,
    );

    if (tab == _EventTab.past) {
      events.sort((a, b) =>
          (b.endAt ?? b.startAt).compareTo(a.endAt ?? a.startAt));
    } else {
      events.sort((a, b) => a.startAt.compareTo(b.startAt));
    }

    if (events.isEmpty) {
      return _EmptyState(
        tab: tab,
        l10n: l10n,
        onCreateTap: onCreateTap,
        pendingCount: provider.pendingInviteCount,
      );
    }

    final isInvited = tab == _EventTab.invited;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: events.length + (isInvited ? 1 : 0),
      itemBuilder: (context, index) {
        if (isInvited && index == 0) return const _SwipeHint();

        final event = events[isInvited ? index - 1 : index];
        final card = EventCard(event: event, currentUserId: currentUserId);

        if (!isInvited) return card;

        return Dismissible(
          key: ValueKey(event.id),
          direction: DismissDirection.horizontal,
          background: const _SwipeBackground(accept: true),
          secondaryBackground: const _SwipeBackground(accept: false),
          onDismissed: (direction) {
            final status = direction == DismissDirection.startToEnd
                ? 'accepted'
                : 'declined';
            provider.rsvp(event.id, status);
            final label = status == 'accepted' ? '✓ Accepted' : 'Declined';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(label),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: card,
        );
      },
    );
  }
}

// ─── Swipe hint ──────────────────────────────────────────────────────────────

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_back_rounded, size: 13, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                'Swipe left to decline',
                style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Swipe right to accept',
                style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.green.shade600),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Swipe background ────────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  final bool accept;
  const _SwipeBackground({required this.accept});

  @override
  Widget build(BuildContext context) => Container(
        color: accept ? Colors.green.shade400 : Colors.red.shade400,
        alignment:
            accept ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              accept ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: Colors.white,
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              accept ? 'Accept' : 'Decline',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
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
      _EventTab.upcoming => (
          '🎉',
          l10n.noUpcomingEvents,
          l10n.noUpcomingEventsHint
        ),
      _EventTab.invited => (
          '✉️',
          'No pending invites',
          "Events you've been invited to will appear here."
        ),
      _EventTab.past => ('📅', l10n.noPastEvents, l10n.noPastEventsHint),
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
                child:
                    AppButton(label: l10n.newEvent, onPressed: onCreateTap),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
