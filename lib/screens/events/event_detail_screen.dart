import 'dart:async';
import 'dart:io';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../models/event_bring_item.dart';
import '../../models/event_expense.dart';
import '../../models/event_poll.dart';
import '../../models/event_guest.dart';
import '../../models/event_message.dart';
import '../../models/event_photo.dart';
import '../../models/event_stop.dart';
import '../../models/friendship.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_chat_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/user_lookup_service.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/add_member_sheet.dart';
import '../../widgets/ai_itinerary_sheet.dart';
import '../../widgets/event_map_widget.dart';
import '../../widgets/event_stop_form_sheet.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _aiChatSession = AiChatSession();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final eventId = widget.eventId;
      context.read<EventProvider>()
        ..fetchPhotos(eventId)
        ..fetchExpenses(eventId)
        ..fetchBringList(eventId)
        ..fetchPolls(eventId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAiSheet(BuildContext context, Event event, bool isOrganizer) {
    final sub = context.read<SubscriptionProvider>();
    if (!sub.isPro) {
      context.push('/paywall');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AiItinerarySheet(event: event, session: _aiChatSession),
    );
  }

  List<EventMapPin> _buildMapPins(Event event) {
    final pins = <EventMapPin>[];
    if (event.startLat != null && event.startLng != null) {
      pins.add(EventMapPin(
        id: 'start',
        position: LatLng(event.startLat!, event.startLng!),
        title: event.startLocation ?? 'Start',
        isStart: true,
      ));
    }
    for (final stop in event.stops) {
      if (stop.addressLat != null && stop.addressLng != null) {
        pins.add(EventMapPin(
          id: stop.id,
          position: LatLng(stop.addressLat!, stop.addressLng!),
          title: stop.title,
          subtitle: stop.address.isNotEmpty ? stop.address : null,
        ));
      }
    }
    if (event.locationLat != null && event.locationLng != null) {
      pins.add(EventMapPin(
        id: 'destination',
        position: LatLng(event.locationLat!, event.locationLng!),
        title: event.location,
        isDestination: true,
      ));
    }
    return pins;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<EventProvider>(
      builder: (_, provider, _) {
        final event = provider.getById(widget.eventId);
        if (event == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final authUid = context.read<AuthProvider>().userId;
        final isOrganizer = event.createdBy == authUid;
        final canInvite = event.isTrip &&
            (isOrganizer ||
                event.guests.any(
                    (g) => g.userId == authUid && g.status == 'accepted'));

        return Scaffold(
          appBar: AppBar(
            title: Text(event.title, overflow: TextOverflow.ellipsis),
            bottom: TabBar(
              controller: _tabController,
              tabAlignment: TabAlignment.fill,
              labelStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    text: l10n.infoTab),
                Tab(
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    text: l10n.chatTabLabel),
                Tab(
                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                    text: l10n.photosTab),
                Tab(
                    icon: const Icon(Icons.grid_view_outlined, size: 20),
                    text: l10n.organizeTab),
              ],
            ),
            actions: [
              if (event.isTrip)
                IconButton(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  tooltip: l10n.generateWithAi,
                  onPressed: () => _openAiSheet(context, event, isOrganizer),
                ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.shareEvent,
                onPressed: () => _shareEvent(context, event),
              ),
              if (isOrganizer)
                PopupMenuButton<_EventAction>(
                  onSelected: (action) async {
                    if (action == _EventAction.edit) {
                      context.push('/event/${event.id}/edit');
                    } else {
                      await _confirmDelete(context, event, provider);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _EventAction.edit,
                      child: Row(children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(l10n.editEvent),
                      ]),
                    ),
                    PopupMenuItem(
                      value: _EventAction.delete,
                      child: Row(children: [
                        const Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.danger),
                        const SizedBox(width: 10),
                        Text(l10n.deleteEventTitle,
                            style:
                                const TextStyle(color: AppTheme.danger)),
                      ]),
                    ),
                  ],
                )
              else if (event.isTrip)
                IconButton(
                  icon: const Icon(Icons.exit_to_app_outlined,
                      color: AppTheme.danger),
                  tooltip: l10n.leaveTripTooltip,
                  onPressed: () => _confirmLeave(context, event, provider),
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _InfoTabGroup(
                event: event,
                authUid: authUid,
                isOrganizer: isOrganizer,
                canInvite: canInvite,
                pins: _buildMapPins(event),
              ),
              _ChatTab(eventId: event.id),
              _PhotosTab(
                event: event,
                photos: provider.photosFor(event.id),
                authUid: authUid,
                isOrganizer: isOrganizer,
              ),
              _OrganizeTabGroup(
                event: event,
                authUid: authUid,
                isOrganizer: isOrganizer,
                items: provider.bringItemsFor(event.id),
                expenses: provider.expensesFor(event.id),
                polls: provider.pollsFor(event.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareEvent(BuildContext context, Event event) async {
    final l10n = AppLocalizations.of(context);
    final url = 'https://tripmanagement.app/event/invite/${event.inviteCode}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.linkCopied)),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Event event, EventProvider provider) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteEventTitle),
        content: Text(l10n.deleteEventMessage(event.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.deleteEvent(event.id);
      if (context.mounted) context.go('/events');
    }
  }

  Future<void> _confirmLeave(
      BuildContext context, Event event, EventProvider provider) async {
    final l10n = AppLocalizations.of(context);
    bool blockReinvite = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.leaveEventTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.leaveEventMessage(
                  event.title.isNotEmpty ? event.title : 'this event')),
              const SizedBox(height: 8),
              SwitchListTile(
                value: blockReinvite,
                onChanged: (v) => setS(() => blockReinvite = v),
                title: Text(l10n.blockReinviteLabel,
                    style: const TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.leave,
                  style: const TextStyle(color: AppTheme.danger)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.leaveEvent(event.id, blockReinvite: blockReinvite);
      if (context.mounted) context.go('/events');
    }
  }
}

enum _EventAction { edit, delete }

// ── Info tab group (Details | Route | Guests inner tabs) ─────────────────────

class _InfoTabGroup extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final bool canInvite;
  final List<EventMapPin> pins;

  const _InfoTabGroup({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.canInvite,
    required this.pins,
  });

  @override
  State<_InfoTabGroup> createState() => _InfoTabGroupState();
}

class _InfoTabGroupState extends State<_InfoTabGroup>
    with SingleTickerProviderStateMixin {
  late TabController _ctrl;

  int get _tabCount => widget.event.isTrip ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final event = widget.event;

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: colorScheme.surfaceContainerLow,
          child: TabBar(
            controller: _ctrl,
            tabAlignment: TabAlignment.fill,
            labelColor: AppTheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: AppTheme.primary,
            dividerColor: colorScheme.outlineVariant,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: [
              Tab(icon: const Icon(Icons.info_outline_rounded, size: 18), text: l10n.detailsTab),
              if (event.isTrip) Tab(icon: const Icon(Icons.route_outlined, size: 18), text: l10n.routeTab),
              Tab(icon: const Icon(Icons.people_outline, size: 18), text: l10n.guestsTab),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _ctrl,
            children: [
              _InfoTab(event: event, authUid: widget.authUid),
              if (event.isTrip)
                _RouteTab(event: event, pins: widget.pins),
              _GuestsTab(
                event: event,
                isOrganizer: widget.isOrganizer,
                canInvite: widget.canInvite,
                authUid: widget.authUid,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Organize tab group (Todo | Expenses | Polls inner tabs) ──────────────────

class _OrganizeTabGroup extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final List<EventBringItem> items;
  final List<EventExpense> expenses;
  final List<EventPoll> polls;

  const _OrganizeTabGroup({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.items,
    required this.expenses,
    required this.polls,
  });

  @override
  State<_OrganizeTabGroup> createState() => _OrganizeTabGroupState();
}

class _OrganizeTabGroupState extends State<_OrganizeTabGroup>
    with SingleTickerProviderStateMixin {
  late TabController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: colorScheme.surfaceContainerLow,
          child: TabBar(
            controller: _ctrl,
            tabAlignment: TabAlignment.fill,
            labelColor: AppTheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: AppTheme.primary,
            dividerColor: colorScheme.outlineVariant,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: [
              Tab(icon: const Icon(Icons.checklist_outlined, size: 18), text: l10n.todoTab),
              Tab(icon: const Icon(Icons.receipt_outlined, size: 18), text: l10n.expensesTab),
              Tab(icon: const Icon(Icons.poll_outlined, size: 18), text: l10n.pollsTab),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _ctrl,
            children: [
              _TodoTab(
                event: widget.event,
                authUid: widget.authUid,
                items: widget.items,
                isOrganizer: widget.isOrganizer,
              ),
              _ExpensesTab(
                event: widget.event,
                expenses: widget.expenses,
                authUid: widget.authUid,
                isOrganizer: widget.isOrganizer,
              ),
              _PollsTab(
                event: widget.event,
                authUid: widget.authUid,
                polls: widget.polls,
                isOrganizer: widget.isOrganizer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Info tab ─────────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final Event event;
  final String? authUid;

  const _InfoTab({required this.event, required this.authUid});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('EEEE, MMMM d, y');
    final timeFmt = DateFormat('h:mm a');
    final myGuest =
        event.guests.where((g) => g.userId == authUid).firstOrNull;
    final isOrganizer = event.createdBy == authUid;

    // For trip-type: show start→stops→destination map; for others: single location pin
    final pins = <EventMapPin>[];
    if (event.isTrip) {
      if (event.startLat != null && event.startLng != null) {
        pins.add(EventMapPin(
          id: 'start',
          position: LatLng(event.startLat!, event.startLng!),
          title: event.startLocation ?? 'Start',
          isStart: true,
        ));
      }
      for (final stop in event.stops) {
        if (stop.addressLat != null && stop.addressLng != null) {
          pins.add(EventMapPin(
            id: stop.id,
            position: LatLng(stop.addressLat!, stop.addressLng!),
            title: stop.title,
          ));
        }
      }
    }
    if (event.locationLat != null && event.locationLng != null) {
      pins.add(EventMapPin(
        id: 'destination',
        position: LatLng(event.locationLat!, event.locationLng!),
        title: event.location,
        isDestination: !event.isTrip,
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date row
        _DetailRow(
          icon: Icons.calendar_today_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fmt.format(event.startAt.toLocal()),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                event.endAt != null
                    ? '${timeFmt.format(event.startAt.toLocal())} – ${timeFmt.format(event.endAt!.toLocal())}'
                    : timeFmt.format(event.startAt.toLocal()),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),

        if (event.isTrip && event.startLocation != null &&
            event.startLocation!.isNotEmpty)
          _DetailRow(
            icon: Icons.trip_origin_outlined,
            child: Text(event.startLocation!),
          ),

        if (event.location.isNotEmpty)
          _DetailRow(
            icon: Icons.location_on_outlined,
            child: Text(event.location),
          ),

        if (event.description.isNotEmpty) ...[
          const Divider(height: 24),
          Text(event.description),
        ],

        // RSVP counts (non-trip) or member counts (trip)
        const Divider(height: 24),
        if (event.isTrip)
          Row(
            children: [
              _CountChip(
                  label: '${event.goingCount} accepted',
                  color: Colors.green),
              const SizedBox(width: 8),
              _CountChip(
                  label: '${event.pendingCount} pending',
                  color: Colors.orange),
              const SizedBox(width: 8),
              _CountChip(
                  label: '${event.declinedCount} declined',
                  color: AppTheme.danger),
            ],
          )
        else
          Row(
            children: [
              _CountChip(
                  label: l10n.goingCount(event.goingCount),
                  color: Colors.green),
              const SizedBox(width: 8),
              _CountChip(
                  label: l10n.maybeCount(event.maybeCount),
                  color: Colors.orange),
              const SizedBox(width: 8),
              _CountChip(
                  label: l10n.declinedCount(event.declinedCount),
                  color: AppTheme.danger),
            ],
          ),

        if (event.capacity != null) ...[
          const SizedBox(height: 4),
          Text(
            '${l10n.eventCapacity}: ${event.capacity}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],

        // My RSVP (non-trip only)
        if (!isOrganizer && !event.isTrip) ...[
          const Divider(height: 24),
          Text(l10n.changeRsvp,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _RsvpButtons(event: event, myGuest: myGuest),
        ],

        // Organiser
        if (event.organizerName != null) ...[
          const Divider(height: 24),
          _DetailRow(
            icon: Icons.person_outline,
            child: Text(l10n.organizedBy(event.organizerName!)),
          ),
        ],

        // Map preview
        if (pins.isNotEmpty) ...[
          const SizedBox(height: 16),
          EventMapWidget(pins: pins, compact: true),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Todo tab ──────────────────────────────────────────────────────────────────

class _TodoTab extends StatelessWidget {
  final Event event;
  final String? authUid;
  final List<EventBringItem> items;
  final bool isOrganizer;

  const _TodoTab({
    required this.event,
    required this.authUid,
    required this.items,
    required this.isOrganizer,
  });

  String get _myName {
    final me = event.guests.where((g) => g.userId == authUid).firstOrNull;
    return me?.displayName ?? 'Me';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.checklist_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(l10n.bringListEmpty,
                        style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final row = _BringItemRow(
                    item: item,
                    isOrganizer: isOrganizer,
                    myName: _myName,
                    l10n: l10n,
                    eventId: event.id,
                  );
                  if (!isOrganizer) return row;
                  return Slidable(
                    key: ValueKey(item.id),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.44,
                      children: [
                        SlidableAction(
                          onPressed: (_) => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => _AddBringItemSheet(
                              l10n: l10n,
                              guests: event.guests,
                              existingItem: item,
                              onAdd: (label, note, assignedToName) =>
                                  context.read<EventProvider>().updateBringItem(
                                        itemId: item.id,
                                        eventId: event.id,
                                        label: label,
                                        note: note,
                                        assignedToName: assignedToName,
                                        clearAssignedToName:
                                            assignedToName == null,
                                      ),
                              onDelete: () => context
                                  .read<EventProvider>()
                                  .deleteBringItem(item.id, event.id),
                            ),
                          ),
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          icon: Icons.edit_outlined,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        SlidableAction(
                          onPressed: (_) => context
                              .read<EventProvider>()
                              .deleteBringItem(item.id, event.id),
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white,
                          icon: Icons.delete_outline,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ],
                    ),
                    child: row,
                  );
                },
              ),
        if (isOrganizer)
          Positioned(
            bottom: 16,
            right: 16,
            child: AppFab(
              icon: Icons.add,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _AddBringItemSheet(
                  l10n: l10n,
                  guests: event.guests,
                  onAdd: (label, note, assignedToName) =>
                      context.read<EventProvider>().addBringItem(
                            eventId: event.id,
                            label: label,
                            note: note,
                            assignedToName: assignedToName,
                          ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BringItemRow extends StatelessWidget {
  final EventBringItem item;
  final bool isOrganizer;
  final String myName;
  final AppLocalizations l10n;
  final String eventId;

  const _BringItemRow({
    required this.item,
    required this.isOrganizer,
    required this.myName,
    required this.l10n,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Done checkbox ──────────────────────────────────────────
          AppTappable(
            onTap: () => context
                .read<EventProvider>()
                .markBringItemDone(item.id, eventId, !item.isDone),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
              child: Icon(
                item.isDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 26,
                color: item.isDone ? Colors.green[600] : Colors.grey[400],
              ),
            ),
          ),

          // ── Label + note + assignees ───────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration:
                        item.isDone ? TextDecoration.lineThrough : null,
                    color: item.isDone ? Colors.grey[400] : null,
                  ),
                ),
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.note!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
                if (item.isAssigned) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text(
                        item.assignedToName!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Actions ────────────────────────────────────────────────
          if (!item.isDone && !item.isAssigned) ...[
            AppTappable(
              onTap: () => context
                  .read<EventProvider>()
                  .assignBringItem(item.id, eventId, myName),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  l10n.bringListTake,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _AddBringItemSheet extends StatefulWidget {
  final AppLocalizations l10n;
  final List<EventGuest> guests;
  final EventBringItem? existingItem;
  final Future<void> Function(String label, String? note, String? assignedToName)
      onAdd;
  final VoidCallback? onDelete;

  const _AddBringItemSheet({
    required this.l10n,
    required this.guests,
    this.existingItem,
    required this.onAdd,
    this.onDelete,
  });

  @override
  State<_AddBringItemSheet> createState() => _AddBringItemSheetState();
}

class _AddBringItemSheetState extends State<_AddBringItemSheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _noteCtrl;
  final Set<String> _assignedGuestIds = {};

  bool get _isEdit => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    _labelCtrl = TextEditingController(text: existing?.label ?? '');
    _noteCtrl = TextEditingController(text: existing?.note ?? '');
    if (existing != null && existing.isAssigned) {
      final assignedNames = existing.assignedToNames.toSet();
      for (final g in widget.guests) {
        if (assignedNames.contains(g.displayName)) {
          _assignedGuestIds.add(g.id);
        }
      }
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<EventGuest> get _assignableGuests => widget.guests
      .where((g) =>
          g.status == 'going' ||
          g.status == 'maybe' ||
          g.status == 'accepted')
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final assignable = _assignableGuests;
    final allSelected =
        assignable.isNotEmpty && assignable.every((g) => _assignedGuestIds.contains(g.id));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header drag handle ──────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEdit ? l10n.bringListEditItem : l10n.bringListAddItem,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_isEdit && widget.onDelete != null)
                  AppTappable(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDelete!();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                      child: Icon(Icons.delete_outline,
                          size: 22, color: AppTheme.danger),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 16),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _labelCtrl,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      label: Text.rich(
                        TextSpan(
                          text: l10n.bringListItemLabel,
                          children: const [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: AppTheme.danger),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        InputDecoration(labelText: l10n.bringListNote),
                  ),
                  if (assignable.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(l10n.bringListAssignTo,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        AppTappable(
                          onTap: () => setState(() {
                            if (allSelected) {
                              _assignedGuestIds.clear();
                            } else {
                              _assignedGuestIds.addAll(assignable.map((g) => g.id));
                            }
                          }),
                          child: Text(
                            allSelected ? l10n.deselectAll : l10n.selectAll,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...assignable.map((g) => _GuestSelectRow(
                          guest: g,
                          selected: _assignedGuestIds.contains(g.id),
                          onTap: () => setState(() {
                            if (_assignedGuestIds.contains(g.id)) {
                              _assignedGuestIds.remove(g.id);
                            } else {
                              _assignedGuestIds.add(g.id);
                            }
                          }),
                        )),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: AppButton(
              label: _isEdit ? l10n.save : l10n.bringListAddItem,
              onPressed: () {
                final text = _labelCtrl.text.trim();
                if (text.isEmpty) return;
                final note = _noteCtrl.text.trim();
                final assigned = _assignableGuests
                    .where((g) => _assignedGuestIds.contains(g.id))
                    .map((g) => g.displayName)
                    .join(', ');
                Navigator.pop(context);
                widget.onAdd(
                  text,
                  note.isEmpty ? null : note,
                  assigned.isEmpty ? null : assigned,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Polls tab ─────────────────────────────────────────────────────────────────

class _PollsTab extends StatelessWidget {
  final Event event;
  final String? authUid;
  final List<EventPoll> polls;
  final bool isOrganizer;

  const _PollsTab({
    required this.event,
    required this.authUid,
    required this.polls,
    required this.isOrganizer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        polls.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.poll_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(l10n.pollsEmpty,
                        style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: polls.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PollCard(
                    poll: polls[i],
                    authUid: authUid,
                    isOrganizer: isOrganizer,
                    eventId: event.id,
                    l10n: l10n,
                  ),
                ),
              ),
        if (isOrganizer)
          Positioned(
            bottom: 16,
            right: 16,
            child: AppFab(
              icon: Icons.add,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _CreatePollSheet(
                  l10n: l10n,
                  onCreate: (question, options) =>
                      context.read<EventProvider>().createPoll(
                            event.id,
                            question,
                            options,
                          ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PollCard extends StatelessWidget {
  final EventPoll poll;
  final String? authUid;
  final bool isOrganizer;
  final String eventId;
  final AppLocalizations l10n;

  const _PollCard({
    required this.poll,
    required this.authUid,
    required this.isOrganizer,
    required this.eventId,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final myVoteOptionId =
        authUid != null ? poll.myVoteOptionId(authUid!) : null;
    final total = poll.totalVotes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    poll.question,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (isOrganizer)
                  AppTappable(
                    onTap: () => context
                        .read<EventProvider>()
                        .deletePoll(poll.id, eventId),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.danger),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final option in poll.options) ...[
              _PollOptionRow(
                option: option,
                votes: poll.votesFor(option.id),
                total: total,
                isSelected: myVoteOptionId == option.id,
                onTap: authUid == null
                    ? null
                    : () {
                        final provider = context.read<EventProvider>();
                        if (myVoteOptionId == null) {
                          provider.vote(poll.id, option.id, eventId);
                        } else if (myVoteOptionId != option.id) {
                          provider.changeVote(poll.id, option.id, eventId);
                        }
                      },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Text(
              l10n.pollsVoteCount(total),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  final EventPollOption option;
  final int votes;
  final int total;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PollOptionRow({
    required this.option,
    required this.votes,
    required this.total,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? votes / total : 0.0;

    return AppTappable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
        children: [
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 20,
            color: isSelected ? AppTheme.primary : Colors.grey[400],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? AppTheme.primary : null,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSelected
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '${(pct * 100).round()}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppTheme.primary : Colors.grey[600],
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _CreatePollSheet extends StatefulWidget {
  final AppLocalizations l10n;
  final Future<void> Function(String question, List<String> options) onCreate;

  const _CreatePollSheet({required this.l10n, required this.onCreate});

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _submitting = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length >= 5) return;
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) return;
    final options =
        _optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (options.length < 2) return;
    setState(() => _submitting = true);
    Navigator.pop(context);
    await widget.onCreate(question, options);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _questionCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                label: Text.rich(
                  TextSpan(
                    text: l10n.pollsQuestion,
                    children: const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: AppTheme.danger),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _optionCtrls.length; i++) ...[
              TextField(
                controller: _optionCtrls[i],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                    labelText: l10n.pollsOptionHint(i + 1)),
              ),
              const SizedBox(height: 8),
            ],
            if (_optionCtrls.length < 5)
              AppTappable(
                onTap: _addOption,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    l10n.pollsAddOption,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            AppButton(
              label: l10n.pollsAddPoll,
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _DetailRow({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 10),
            Expanded(child: child),
          ],
        ),
      );
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CountChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      );
}

class _RsvpButtons extends StatefulWidget {
  final Event event;
  final EventGuest? myGuest;

  const _RsvpButtons({required this.event, required this.myGuest});

  @override
  State<_RsvpButtons> createState() => _RsvpButtonsState();
}

class _RsvpButtonsState extends State<_RsvpButtons> {
  bool _loading = false;

  Future<void> _rsvp(String status) async {
    final l10n = AppLocalizations.of(context);
    if (widget.event.isFull && status == 'going') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventFull)),
      );
      return;
    }
    // Declined needs no note — apply immediately.
    if (status == 'declined') {
      setState(() => _loading = true);
      await context.read<EventProvider>().rsvp(widget.event.id, status);
      if (mounted) setState(() => _loading = false);
      return;
    }
    // Going / Maybe: show optional note sheet.
    final existingNote = widget.myGuest?.rsvpNote ?? '';
    final note = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _RsvpNoteSheet(
        initialNote: existingNote,
        l10n: l10n,
      ),
    );
    if (!mounted) return;
    // note == null means sheet was dismissed without confirming.
    if (note == null) return;
    setState(() => _loading = true);
    await context.read<EventProvider>().rsvp(
          widget.event.id,
          status,
          note: note,
        );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = widget.myGuest?.status;

    if (_loading) {
      return const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)));
    }

    return Wrap(
      spacing: 8,
      children: [
        _RsvpButton(
          label: l10n.rsvpGoing,
          icon: Icons.check_circle_outline,
          selected: current == 'going',
          color: Colors.green,
          onTap: () => _rsvp('going'),
        ),
        _RsvpButton(
          label: l10n.rsvpMaybe,
          icon: Icons.help_outline,
          selected: current == 'maybe',
          color: Colors.orange,
          onTap: () => _rsvp('maybe'),
        ),
        _RsvpButton(
          label: l10n.rsvpDeclined,
          icon: Icons.cancel_outlined,
          selected: current == 'declined',
          color: AppTheme.danger,
          onTap: () => _rsvp('declined'),
        ),
      ],
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppTappable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? color : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Route tab (trip-type only) ────────────────────────────────────────────────

enum _RouteView { list, map }

class _RouteTab extends StatefulWidget {
  final Event event;
  final List<EventMapPin> pins;

  const _RouteTab({required this.event, required this.pins});

  @override
  State<_RouteTab> createState() => _RouteTabState();
}

class _RouteTabState extends State<_RouteTab> {
  _RouteView _view = _RouteView.list;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // ── List / Map toggle ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<_RouteView>(
            segments: [
              ButtonSegment(
                value: _RouteView.list,
                icon: const Icon(Icons.list_outlined, size: 18),
                label: Text(l10n.routeTab),
              ),
              ButtonSegment(
                value: _RouteView.map,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(l10n.mapTab),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (s) =>
                setState(() => _view = s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),

        // ── Content ───────────────────────────────────────────────────
        Expanded(
          child: _view == _RouteView.map
              ? widget.pins.isEmpty
                  ? Center(
                      child: Text(l10n.noStopsInItinerary,
                          style:
                              TextStyle(color: Colors.grey[500])))
                  : EventMapWidget(pins: widget.pins)
              : _buildList(context, l10n),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    final event = widget.event;

    if (event.stops.isEmpty) {
      return Stack(
        children: [
          Center(
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
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: AppFab(
              onPressed: () =>
                  showEventStopFormSheet(context, eventId: event.id),
              icon: Icons.add_location_alt_outlined,
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
          itemCount: event.stops.length,
          itemBuilder: (context, index) {
            final stop = event.stops[index];
            return Slidable(
              key: ValueKey(stop.id),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) =>
                        _confirmDeleteStop(context, stop),
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_outline,
                    label: l10n.delete,
                  ),
                ],
              ),
              child: _StopCard(stop: stop, eventId: event.id),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: AppFab(
            onPressed: () =>
                showEventStopFormSheet(context, eventId: event.id),
            icon: Icons.add_location_alt_outlined,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteStop(
      BuildContext context, EventStop stop) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeStopTitle),
        content: Text(l10n.removeStopMessage(stop.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context
          .read<EventProvider>()
          .deleteStop(stop.id, stop.eventId);
    }
  }
}

class _StopCard extends StatelessWidget {
  final EventStop stop;
  final String eventId;

  const _StopCard({required this.stop, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFmt = DateFormat('MMM d  h:mm a');
    return AppTappable(
      onTap: () => showEventStopFormSheet(context,
          eventId: eventId, existing: stop),
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
                      style:
                          TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ],
              if (stop.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(stop.notes,
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 13),
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

// ── Guests tab ────────────────────────────────────────────────────────────────

class _GuestsTab extends StatefulWidget {
  final Event event;
  final bool isOrganizer;
  final bool canInvite;
  final String? authUid;

  const _GuestsTab({
    required this.event,
    required this.isOrganizer,
    required this.canInvite,
    required this.authUid,
  });

  @override
  State<_GuestsTab> createState() => _GuestsTabState();
}

class _GuestsTabState extends State<_GuestsTab> {
  final Set<String> _resendingIds = {};

  Future<void> _resend(EventGuest guest) async {
    setState(() => _resendingIds.add(guest.id));
    final l10n = AppLocalizations.of(context);
    try {
      await context.read<EventProvider>().resendInvite(guest.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.inviteResentTo(guest.displayName))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _resendingIds.remove(guest.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final event = widget.event;

    if (event.isTrip) {
      return _buildTripMembersList(context, l10n);
    }

    // Non-trip: RSVP groups
    final groups = <String, List<EventGuest>>{
      'going': [],
      'maybe': [],
      'declined': [],
    };
    for (final g in event.guests) {
      groups[g.status]?.add(g);
    }

    return Stack(
      children: [
        event.guests.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noGuestsYet,
                        style: TextStyle(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                children: [
                  for (final status in [
                    'going',
                    'maybe',
                    'declined'
                  ]) ...[
                    if (groups[status]!.isNotEmpty) ...[
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          switch (status) {
                            'going' => l10n.rsvpGoing,
                            'maybe' => l10n.rsvpMaybe,
                            _ => l10n.rsvpDeclined,
                          },
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      ...groups[status]!.map((g) => _GuestTile(
                            guest: g,
                            isOrganizer: widget.isOrganizer,
                          )),
                    ],
                  ],
                ],
              ),
        if (widget.isOrganizer)
          Positioned(
            bottom: 16,
            right: 16,
            child: AppFab(
              onPressed: _showAddGuest,
              icon: Icons.person_add_outlined,
            ),
          ),
      ],
    );
  }

  Widget _buildTripMembersList(
      BuildContext context, AppLocalizations l10n) {
    final event = widget.event;
    return Stack(
      children: [
        event.guests.isEmpty
            ? Center(
                child: Text(l10n.noGuestsYet,
                    style: TextStyle(color: Colors.grey[500])))
            : Builder(builder: (context) {
                final sortedGuests = [...event.guests]
                  ..sort((a, b) {
                    if (a.role == 'organizer') return -1;
                    if (b.role == 'organizer') return 1;
                    return 0;
                  });
                return ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: sortedGuests.length,
                itemBuilder: (_, i) {
                  final g = sortedGuests[i];
                  final isMe = g.userId != null &&
                      g.userId == widget.authUid;
                  final canResend = g.status == 'pending' &&
                      widget.canInvite &&
                      g.userId != null &&
                      g.userId != widget.authUid;

                  String? inviterLabel;
                  if (g.invitedBy != null) {
                    if (g.invitedBy == widget.authUid) {
                      inviterLabel = l10n.invitedBy(l10n.you);
                    } else {
                      final inviter = event.guests
                          .where((x) => x.userId == g.invitedBy)
                          .firstOrNull;
                      if (inviter != null) {
                        inviterLabel =
                            l10n.invitedBy(inviter.displayName);
                      }
                    }
                  }

                  final hasEmail = g.email != null &&
                      g.email!.isNotEmpty &&
                      !isMe;
                  final hasAvatar =
                      g.avatarUrl != null && g.avatarUrl!.isNotEmpty;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: g.role == 'organizer'
                          ? AppTheme.primary
                          : Colors.grey[200],
                      backgroundImage: hasAvatar
                          ? NetworkImage(g.avatarUrl!)
                          : null,
                      child: hasAvatar
                          ? null
                          : Text(
                              g.displayName.isNotEmpty
                                  ? g.displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  color: g.role == 'organizer'
                                      ? Colors.white
                                      : AppTheme.primary),
                            ),
                    ),
                    title: Text(isMe ? l10n.you : g.displayName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(g.role == 'organizer'
                                ? l10n.organizer
                                : l10n.member),
                            if (g.userId != null) ...[
                              const SizedBox(width: 6),
                              _StatusChip(
                                label: switch (g.status) {
                                  'pending' => l10n.invitePending,
                                  'declined' => l10n.inviteDeclined,
                                  'left' => l10n.memberLeft,
                                  _ => l10n.inviteAccepted,
                                },
                                color: switch (g.status) {
                                  'pending' => Colors.orange,
                                  'declined' => AppTheme.danger,
                                  'left' => Colors.grey,
                                  _ => Colors.green,
                                },
                              ),
                            ],
                          ],
                        ),
                        if (hasEmail)
                          Text(
                            g.email!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (inviterLabel != null)
                          Text(
                            inviterLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    trailing: canResend
                        ? _resendingIds.contains(g.id)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2),
                              )
                            : Tooltip(
                                message: l10n.resendInvite,
                                waitDuration: Duration.zero,
                                preferBelow: false,
                                child: IconButton(
                                  icon:
                                      const Icon(Icons.send_outlined),
                                  iconSize: 20,
                                  onPressed: () => _resend(g),
                                ),
                              )
                        : null,
                    dense: true,
                    isThreeLine: hasEmail || inviterLabel != null,
                  );
                },
              );
              }),
        if (widget.canInvite)
          Positioned(
            bottom: 16,
            right: 16,
            child: AppFab(
              onPressed: () => showAddMemberSheet(context, eventId: event.id),
              icon: Icons.person_add_outlined,
            ),
          ),
      ],
    );
  }

  Future<void> _showAddGuest() async {
    final sub = context.read<SubscriptionProvider>();
    if (!sub.isPro && widget.event.guests.length >= 10) {
      context.push('/paywall');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddGuestSheet(eventId: widget.event.id),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GuestTile extends StatelessWidget {
  final EventGuest guest;
  final bool isOrganizer;

  const _GuestTile({required this.guest, required this.isOrganizer});

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        guest.avatarUrl != null && guest.avatarUrl!.isNotEmpty;
    final contact = [
      if (guest.email != null) guest.email!,
      if (guest.phone != null) guest.phone!,
    ].join(' · ');

    final hasNote =
        guest.rsvpNote != null && guest.rsvpNote!.isNotEmpty;

    Widget? subtitle;
    if (hasNote && contact.isNotEmpty) {
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            guest.rsvpNote!,
            style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey[700]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(contact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ],
      );
    } else if (hasNote) {
      subtitle = Text(
        guest.rsvpNote!,
        style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey[700]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    } else if (contact.isNotEmpty) {
      subtitle =
          Text(contact, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        backgroundImage:
            hasAvatar ? NetworkImage(guest.avatarUrl!) : null,
        child: hasAvatar
            ? null
            : Text(
                guest.displayName.isNotEmpty
                    ? guest.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: AppTheme.primary),
              ),
      ),
      title: Text(guest.displayName),
      subtitle: subtitle,
      trailing: isOrganizer
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppTheme.danger, size: 20),
              onPressed: () => _removeGuest(context),
            )
          : null,
      dense: true,
    );
  }

  Future<void> _removeGuest(BuildContext context) async {
    try {
      await Supabase.instance.client
          .from('event_guests')
          .delete()
          .eq('id', guest.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}

// ── RSVP note sheet ───────────────────────────────────────────────────────────

class _RsvpNoteSheet extends StatefulWidget {
  final String initialNote;
  final AppLocalizations l10n;

  const _RsvpNoteSheet({required this.initialNote, required this.l10n});

  @override
  State<_RsvpNoteSheet> createState() => _RsvpNoteSheetState();
}

class _RsvpNoteSheetState extends State<_RsvpNoteSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 200,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.rsvpNoteLabel,
              hintText: l10n.rsvpNoteHint,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: l10n.confirmRsvp,
            onPressed: () => Navigator.pop(context, _ctrl.text),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Chat tab ──────────────────────────────────────────────────────────────────

class _ChatTab extends StatefulWidget {
  final String eventId;

  const _ChatTab({required this.eventId});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    try {
      await context.read<EventChatProvider>().sendMessage(text);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final authUid = context.read<AuthProvider>().userId;

    return Column(
      children: [
        Expanded(
          child: Consumer<EventChatProvider>(
            builder: (_, chat, _) {
              if (chat.loading && chat.messages.isEmpty) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              if (chat.messages.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context).chatNoMessages,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: chat.messages.length,
                itemBuilder: (_, i) {
                  final msg = chat.messages[i];
                  return _MessageBubble(
                    msg: msg,
                    isMe: msg.userId == authUid,
                  );
                },
              );
            },
          ),
        ),
        _ChatInput(ctrl: _ctrl, sending: _sending, onSend: _send),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final EventMessage msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        msg.senderAvatarUrl != null && msg.senderAvatarUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[200],
              backgroundImage:
                  hasAvatar ? NetworkImage(msg.senderAvatarUrl!) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      (msg.senderName?.isNotEmpty == true)
                          ? msg.senderName![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primary),
                    ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe && msg.senderName != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(msg.senderName!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppTheme.primary
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe
                        ? null
                        : Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                        color: isMe ? Colors.white : null,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool sending;
  final VoidCallback onSend;

  const _ChatInput(
      {required this.ctrl,
      required this.sending,
      required this.onSend});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
                top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText:
                        AppLocalizations.of(context).chatSendHint,
                    border: const OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(24))),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              sending
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2)))
                  : IconButton(
                      onPressed: onSend,
                      icon: const Icon(Icons.send_rounded,
                          color: AppTheme.primary),
                    ),
            ],
          ),
        ),
      );
}

// ── Photos tab ────────────────────────────────────────────────────────────────

class _PhotosTab extends StatefulWidget {
  final Event event;
  final List<EventPhoto> photos;
  final String? authUid;
  final bool isOrganizer;

  const _PhotosTab({
    required this.event,
    required this.photos,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<_PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<_PhotosTab> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (image == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final db = Supabase.instance.client;
      final eventId = widget.event.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$eventId/$fileName';

      await db.storage.from('event-photos').uploadBinary(
        storagePath,
        bytes,
        fileOptions:
            FileOptions(contentType: 'image/$ext', upsert: false),
      );

      if (mounted) {
        await context
            .read<EventProvider>()
            .addPhoto(eventId: eventId, storagePath: storagePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        widget.photos.isEmpty
            ? Center(
                child: Text(l10n.noPhotosYet,
                    style: TextStyle(color: Colors.grey[400])))
            : GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: widget.photos.length,
                itemBuilder: (_, i) {
                  final photo = widget.photos[i];
                  final canDelete = widget.isOrganizer ||
                      photo.uploadedBy == widget.authUid;
                  return GestureDetector(
                    onLongPress: canDelete
                        ? () => _confirmDelete(context, photo)
                        : null,
                    onTap: () => _showFullScreen(context, photo),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: photo.publicUrl != null
                          ? Image.network(photo.publicUrl!,
                              fit: BoxFit.cover)
                          : Container(color: Colors.grey[200]),
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: AppFab(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: Icons.add_a_photo,
            child: _uploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : null,
          ),
        ),
      ],
    );
  }

  void _showFullScreen(BuildContext context, EventPhoto photo) {
    if (photo.publicUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(photo.publicUrl!),
              ),
            ),
            AppTappable(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, EventPhoto photo) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deletePhoto),
        content: Text(l10n.deletePhotoConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<EventProvider>().deletePhoto(photo);
    }
  }
}

// ── Expenses tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends StatefulWidget {
  final Event event;
  final List<EventExpense> expenses;
  final String? authUid;
  final bool isOrganizer;

  const _ExpensesTab({
    required this.event,
    required this.expenses,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  void _showSettlement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettlementSheet(
        event: widget.event,
        expenses: widget.expenses,
      ),
    );
  }

  void _showAddExpense([EventExpense? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) =>
          _AddExpenseSheet(event: widget.event, existing: existing),
    );
  }

  Future<void> _confirmDelete(EventExpense expense) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteExpenseTitle),
        content: Text(l10n.deleteExpenseMessage(expense.description)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context
          .read<EventProvider>()
          .deleteExpense(expense.id, expense.eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        widget.expenses.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_outlined,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noExpensesYet,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: widget.expenses.length,
                itemBuilder: (_, i) => _ExpenseCard(
                  expense: widget.expenses[i],
                  event: widget.event,
                  authUid: widget.authUid,
                  canEdit: widget.isOrganizer,
                  onEdit: () => _showAddExpense(widget.expenses[i]),
                  onDelete: () => _confirmDelete(widget.expenses[i]),
                ),
              ),
        if (widget.expenses.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.extended(
              heroTag: 'settle_up',
              onPressed: _showSettlement,
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.balance_rounded),
              label: Text(AppLocalizations.of(context).settleUp),
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: AppFab(onPressed: _showAddExpense),
        ),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final EventExpense expense;
  final Event event;
  final String? authUid;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.event,
    required this.authUid,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');
    final myGuest =
        event.guests.where((g) => g.userId == authUid).firstOrNull;
    final mySplit = myGuest != null
        ? expense.splits
            .where((s) => s.guestId == myGuest.id)
            .firstOrNull
        : null;

    // Determine how much the current user paid.
    final payerNames = expense.paidByName.split(', ');
    final iAmPayer = expense.paidByUserId == authUid ||
        (myGuest != null && payerNames.contains(myGuest.displayName));
    final amountIPaid = iAmPayer ? expense.amount / payerNames.length : 0.0;

    // Net owed = my share of the expense minus what I already paid.
    final myShare = mySplit?.amount ?? 0.0;
    final netOwed = myShare - amountIPaid;
    // Only show a balance line if there's something meaningful to show.
    final showBalance = (mySplit != null || iAmPayer) && netOwed.abs() > 0.005;

    final card = AppTappable(
      onTap: canEdit ? onEdit : null,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(expense.description,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(fmt.format(expense.amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Paid by ${expense.paidByName}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              if (showBalance) ...[
                const Divider(height: 16),
                Text(
                  netOwed > 0
                      ? l10n.totalOwed(fmt.format(netOwed))
                      : l10n.youAreOwed(fmt.format(-netOwed)),
                  style: TextStyle(
                    fontSize: 13,
                    color: netOwed > 0 ? AppTheme.danger : AppTheme.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!canEdit) return card;

    return Slidable(
      key: ValueKey(expense.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppTheme.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: card,
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  final Event event;
  final EventExpense? existing;

  const _AddExpenseSheet({required this.event, this.existing});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  // paidBy — multi selection
  final Set<String> _paidByGuestIds = {};
  // split — multi selection; always equal share
  final Set<String> _splitGuestIds = {};
  bool _loading = false;
  String? _validationError;

  List<EventGuest> get _guests =>
      widget.event.guests.where((g) => g.isAccepted).toList();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _descCtrl.text = existing.description;
      _amountCtrl.text = existing.amount.toStringAsFixed(2);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final guests = _guests;
      if (guests.isEmpty) return;
      if (existing != null) {
        // Pre-select payers and splits from the existing expense.
        setState(() {
          for (final g in guests) {
            if (g.userId == existing.paidByUserId ||
                existing.paidByName
                    .split(', ')
                    .contains(g.displayName)) {
              _paidByGuestIds.add(g.id);
            }
          }
          for (final split in existing.splits) {
            _splitGuestIds.add(split.guestId);
          }
          if (_paidByGuestIds.isEmpty) {
            _paidByGuestIds.add(guests.first.id);
          }
        });
      } else {
        final myUid = context.read<AuthProvider>().userId;
        final me = guests.firstWhere(
          (g) => g.userId == myUid,
          orElse: () => guests.first,
        );
        setState(() => _paidByGuestIds.add(me.id));
      }
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_descCtrl.text.trim().isEmpty) return 'Description is required.';
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      return 'Enter a valid amount greater than 0.';
    }
    if (_paidByGuestIds.isEmpty) return 'Select who paid.';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    setState(() { _loading = true; _validationError = null; });
    final amount = double.parse(_amountCtrl.text.trim());
    final payers = _guests.where((g) => _paidByGuestIds.contains(g.id)).toList();
    final paidByName = payers.map((g) => g.displayName).join(', ');
    final paidByUserId = payers.length == 1 ? payers.first.userId : null;

    try {
      final provider = context.read<EventProvider>();
      if (_isEdit) {
        await provider.updateExpense(
          expenseId: widget.existing!.id,
          eventId: widget.event.id,
          amount: amount,
          description: _descCtrl.text.trim(),
          splitGuestIds: _splitGuestIds.toList(),
          customSplitAmounts: null,
          paidByUserId: paidByUserId,
          paidByName: paidByName,
        );
      } else {
        await provider.addExpense(
          eventId: widget.event.id,
          amount: amount,
          description: _descCtrl.text.trim(),
          splitGuestIds: _splitGuestIds.toList(),
          customSplitAmounts: null,
          paidByUserId: paidByUserId,
          paidByName: paidByName,
        );
      }
      if (mounted) {
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _toggleSplit(String guestId) {
    setState(() {
      if (_splitGuestIds.contains(guestId)) {
        _splitGuestIds.remove(guestId);
      } else {
        _splitGuestIds.add(guestId);
      }
      _validationError = null;
    });
  }

  void _selectAllSplit() {
    setState(() {
      for (final g in _guests) {
        _splitGuestIds.add(g.id);
      }
      _validationError = null;
    });
  }

  void _deselectAllSplit() {
    setState(() {
      _splitGuestIds.clear();
      _validationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final guests = _guests;
    final allPaidBySelected = guests.isNotEmpty &&
        guests.every((g) => _paidByGuestIds.contains(g.id));
    final allSelected = guests.isNotEmpty &&
        guests.every((g) => _splitGuestIds.contains(g.id));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      _isEdit ? l10n.editExpense : l10n.addExpense,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                AppTappable(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fields ──────────────────────────────────────────
                  TextField(
                    controller: _descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) =>
                        setState(() => _validationError = null),
                    decoration: InputDecoration(
                      labelText: '${l10n.expenseDescription} *',
                      prefixIcon:
                          const Icon(Icons.receipt_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    onChanged: (_) =>
                        setState(() => _validationError = null),
                    decoration: InputDecoration(
                      labelText: '${l10n.expenseAmount} *',
                      prefixIcon:
                          const Icon(Icons.attach_money_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                  const SizedBox(height: 20),

                  // ── Paid by ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.paidBy,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      if (guests.isNotEmpty)
                        AppTappable(
                          onTap: () => setState(() {
                            if (allPaidBySelected) {
                              _paidByGuestIds.clear();
                            } else {
                              _paidByGuestIds
                                  .addAll(guests.map((g) => g.id));
                            }
                            _validationError = null;
                          }),
                          child: Text(
                            allPaidBySelected
                                ? l10n.deselectAll
                                : l10n.selectAll,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.primary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (guests.isEmpty)
                    Text(l10n.noGuestsYet,
                        style: TextStyle(color: Colors.grey[500]))
                  else
                    ...guests.map((g) => _GuestSelectRow(
                          guest: g,
                          selected: _paidByGuestIds.contains(g.id),
                          onTap: () => setState(() {
                            if (_paidByGuestIds.contains(g.id)) {
                              _paidByGuestIds.remove(g.id);
                            } else {
                              _paidByGuestIds.add(g.id);
                            }
                            _validationError = null;
                          }),
                        )),

                  const SizedBox(height: 20),

                  // ── Split among ─────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.splitAmong,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      if (guests.isNotEmpty)
                        AppTappable(
                          onTap: allSelected
                              ? _deselectAllSplit
                              : _selectAllSplit,
                          child: Text(
                            allSelected ? l10n.deselectAll : l10n.selectAll,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.primary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (guests.isEmpty)
                    Text(l10n.noGuestsYet,
                        style: TextStyle(color: Colors.grey[500]))
                  else
                    ...guests.map((g) => _GuestSelectRow(
                          guest: g,
                          selected: _splitGuestIds.contains(g.id),
                          onTap: () => _toggleSplit(g.id),
                        )),

                  // ── Validation error ────────────────────────────────
                  if (_validationError != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: AppTheme.danger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: const TextStyle(
                                color: AppTheme.danger,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Submit ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: AppButton(
              label: _isEdit ? l10n.saveChanges : l10n.addExpense,
              onPressed: _submit,
              loading: _loading,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guest selector row ────────────────────────────────────────────────────────

class _GuestSelectRow extends StatelessWidget {
  final EventGuest guest;
  final bool selected;
  final VoidCallback onTap;

  const _GuestSelectRow({
    required this.guest,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppTappable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: selected
                    ? AppTheme.primary
                    : Colors.grey[200],
                backgroundImage: guest.avatarUrl != null &&
                        guest.avatarUrl!.isNotEmpty
                    ? NetworkImage(guest.avatarUrl!)
                    : null,
                child: (guest.avatarUrl == null ||
                        guest.avatarUrl!.isEmpty)
                    ? Text(
                        guest.displayName.isNotEmpty
                            ? guest.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : AppTheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guest.displayName,
                  style: TextStyle(
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppTheme.primary : Colors.transparent,
                  border: Border.all(
                    color:
                        selected ? AppTheme.primary : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Lookup state (for _AddGuestSheet) ─────────────────────────────────────────

sealed class _LookupState {}

class _LookupIdle extends _LookupState {}

class _LookupSearching extends _LookupState {}

class _LookupFound extends _LookupState {
  final LinkedUserInfo user;
  _LookupFound(this.user);
}

class _LookupNotFound extends _LookupState {}

// ── Add Guest sheet (non-trip events) ─────────────────────────────────────────

class _AddGuestSheet extends StatefulWidget {
  final String eventId;

  const _AddGuestSheet({required this.eventId});

  @override
  State<_AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<_AddGuestSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _phone = '';
  _LookupState _lookupState = _LookupIdle();
  Timer? _debounce;
  bool _nameTouched = false;
  int _lookupGeneration = 0;
  bool _loading = false;

  final _lookupService = UserLookupService();

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final atIndex = value.indexOf('@');
    if (atIndex < 1) return false;
    final domain = value.substring(atIndex + 1);
    final dotIndex = domain.lastIndexOf('.');
    if (dotIndex < 1) return false;
    return domain.length - dotIndex - 1 >= 2;
  }

  void _onEmailChanged(String _) => _scheduleOrClear();

  void _onPhoneChanged(String value) {
    _phone = value;
    _scheduleOrClear();
  }

  void _scheduleOrClear() {
    final hasEmail = _isValidEmail(_emailCtrl.text.trim());
    final hasPhone = _phone.replaceAll(RegExp(r'\D'), '').length >= 7;

    if (hasEmail || hasPhone) {
      _debounce?.cancel();
      _debounce =
          Timer(const Duration(milliseconds: 400), _performLookup);
    } else {
      _debounce?.cancel();
      if (_lookupState is! _LookupIdle) {
        setState(() => _lookupState = _LookupIdle());
      }
    }
  }

  Future<void> _performLookup() async {
    if (!mounted) return;

    final email = _emailCtrl.text.trim();
    final phone = _phone;
    final hasEmail = _isValidEmail(email);
    final hasPhone = phone.replaceAll(RegExp(r'\D'), '').length >= 7;
    if (!hasEmail && !hasPhone) return;

    final connectivity = context.read<ConnectivityService>();
    if (!connectivity.isOnline) return;

    final generation = ++_lookupGeneration;
    setState(() => _lookupState = _LookupSearching());

    final result = await _lookupService.findUserByContact(
      email: hasEmail ? email : null,
      phone: hasPhone ? phone : null,
    );

    if (!mounted || _lookupGeneration != generation) return;

    setState(() {
      if (result != null) {
        _lookupState = _LookupFound(result);
        if (!_nameTouched && _nameCtrl.text.isEmpty) {
          final autoName = result.fullName.isNotEmpty
              ? result.fullName
              : email.split('@').first;
          if (autoName.isNotEmpty) _nameCtrl.text = autoName;
        }
      } else {
        _lookupState = _LookupNotFound();
      }
    });
  }

  void _prefillFriend(Friendship f) {
    final myUserId = context.read<AuthProvider>().userId ?? '';
    final otherId = f.otherUserId(myUserId);
    final name = f.otherDisplayName ?? '';
    if (name.isNotEmpty && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = name;
      _nameTouched = true;
    }
    setState(() {
      _lookupState = _LookupFound(LinkedUserInfo(
        userId: otherId,
        fullName: name,
        jobTitle: '',
        phone: '',
        avatarUrl: '',
      ));
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      final userId = switch (_lookupState) {
        _LookupFound(user: final u) => u.userId,
        _ => null,
      };
      await context.read<EventProvider>().addGuest(
            eventId: widget.eventId,
            displayName: name,
            email: _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            phone: _phone.isEmpty ? null : _phone,
            userId: userId,
          );
      if (mounted) {
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(l10n.addGuest,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                AppTappable(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Consumer<FriendsProvider>(
            builder: (context, friends, _) {
              final accepted = friends.accepted;
              if (accepted.isEmpty) return const SizedBox.shrink();
              final myUserId =
                  context.read<AuthProvider>().userId ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      l10n.friendsTabFriends,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600]),
                    ),
                  ),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: accepted.length,
                      itemBuilder: (_, i) {
                        final f = accepted[i];
                        final isSelected = switch (_lookupState) {
                          _LookupFound(user: final u) =>
                            u.userId == f.otherUserId(myUserId),
                          _ => false,
                        };
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: avatarColors(
                                    f.otherDisplayName ?? '')
                                .first,
                            child: Text(
                              avatarInitials(f.otherDisplayName ?? ''),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(f.otherDisplayName ?? ''),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.accent)
                              : null,
                          onTap: () => _prefillFriend(f),
                          dense: true,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 16),
                ],
              );
            },
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.emailOptional,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    onChanged: _onEmailChanged,
                  ),
                  const SizedBox(height: 12),
                  AppPhoneField(
                    label: l10n.phoneOptional,
                    onChanged: _onPhoneChanged,
                  ),
                  const SizedBox(height: 12),
                  _GuestLookupStatus(state: _lookupState),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.fullNameLabel,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    onChanged: (_) => _nameTouched = true,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AppButton(
              label: l10n.addGuest,
              onPressed: _submit,
              loading: _loading,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestLookupStatus extends StatelessWidget {
  final _LookupState state;

  const _GuestLookupStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      _LookupIdle() => const SizedBox.shrink(),
      _LookupSearching() => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(l10n.memberSearching,
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
      _LookupFound(user: final u) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _GuestLinkedUserCard(user: u),
        ),
      _LookupNotFound() => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(l10n.memberNoAccountFound,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ),
    };
  }
}

class _GuestLinkedUserCard extends StatelessWidget {
  final LinkedUserInfo user;

  const _GuestLinkedUserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = avatarColors(user.fullName);
    final initials = avatarInitials(user.fullName);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isNotEmpty ? user.fullName : '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.jobTitle.isNotEmpty)
                  Text(
                    user.jobTitle,
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, size: 12, color: AppTheme.accent),
                const SizedBox(width: 3),
                Text(
                  l10n.memberLinkedAccount,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settlement data models ─────────────────────────────────────────────────

class _PersonBalance {
  final String guestId;
  final String name;
  final String? avatarUrl;
  final double paid;
  final double owes;

  const _PersonBalance({
    required this.guestId,
    required this.name,
    this.avatarUrl,
    required this.paid,
    required this.owes,
  });

  double get net => paid - owes;
}

class _Settlement {
  final String fromName;
  final String? fromAvatar;
  final String toName;
  final String? toAvatar;
  final double amount;

  const _Settlement({
    required this.fromName,
    this.fromAvatar,
    required this.toName,
    this.toAvatar,
    required this.amount,
  });
}

// ── Settlement sheet ───────────────────────────────────────────────────────

class _SettlementSheet extends StatefulWidget {
  final Event event;
  final List<EventExpense> expenses;

  const _SettlementSheet({required this.event, required this.expenses});

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  final _shareButtonKey = GlobalKey();
  bool _exporting = false;

  List<_PersonBalance> _computeBalances() {
    final guests = widget.event.guests.where((g) => g.isAccepted).toList();
    final paid = <String, double>{for (final g in guests) g.id: 0.0};
    final owes = <String, double>{for (final g in guests) g.id: 0.0};

    for (final expense in widget.expenses) {
      final payerNames = expense.paidByName.split(', ');
      final amountPerPayer = expense.amount / payerNames.length;
      for (final g in guests) {
        final isPayer = expense.paidByUserId.isNotEmpty
            ? g.userId == expense.paidByUserId
            : payerNames.contains(g.displayName);
        if (isPayer) paid[g.id] = (paid[g.id] ?? 0) + amountPerPayer;
      }
      for (final split in expense.splits) {
        if (owes.containsKey(split.guestId)) {
          owes[split.guestId] = (owes[split.guestId] ?? 0) + split.amount;
        }
      }
    }

    return guests
        .map((g) => _PersonBalance(
              guestId: g.id,
              name: g.displayName,
              avatarUrl: g.avatarUrl,
              paid: paid[g.id] ?? 0,
              owes: owes[g.id] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.net.compareTo(a.net));
  }

  List<_Settlement> _computeSettlements(List<_PersonBalance> balances) {
    final creditors = balances.where((b) => b.net > 0.005).toList();
    final debtors = balances.where((b) => b.net < -0.005).toList();
    final credAmounts = creditors.map((c) => c.net).toList();
    final debtAmounts = debtors.map((d) => -d.net).toList();

    final settlements = <_Settlement>[];
    int ci = 0, di = 0;
    while (ci < creditors.length && di < debtors.length) {
      final amount = min(credAmounts[ci], debtAmounts[di]);
      if (amount > 0.005) {
        settlements.add(_Settlement(
          fromName: debtors[di].name,
          fromAvatar: debtors[di].avatarUrl,
          toName: creditors[ci].name,
          toAvatar: creditors[ci].avatarUrl,
          amount: amount,
        ));
      }
      credAmounts[ci] -= amount;
      debtAmounts[di] -= amount;
      if (credAmounts[ci] < 0.005) ci++;
      if (debtAmounts[di] < 0.005) di++;
    }
    return settlements;
  }

  // ── Export helpers ─────────────────────────────────────────────────────────

  Rect? _shareOrigin() {
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  void _showExportOptions(BuildContext context) {
    if (!context.read<SubscriptionProvider>().isPro) {
      context.push('/paywall');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Save as Image'),
              subtitle: const Text('Export a screenshot of this summary'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                // Wait for the dismiss animation to finish before capturing
                await Future.delayed(const Duration(milliseconds: 400));
                if (mounted) _exportImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as PDF'),
              subtitle: const Text('Generate a shareable PDF report'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await Future.delayed(const Duration(milliseconds: 400));
                if (mounted) _exportPdf();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _exportImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final origin = _shareOrigin();
    setState(() => _exporting = true);
    try {
      // Rasterise the first page of the PDF at 150 dpi — always the full
      // content regardless of how long the sheet is.
      final pdfBytes = await _buildPdfBytes();
      final raster = await Printing.raster(pdfBytes, dpi: 150).first;
      final bytes = await raster.toPng();
      final safeName =
          widget.event.title.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final name = '${safeName}_settle_up.png';
      if (kIsWeb) {
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: name, mimeType: 'image/png')],
          subject: '${widget.event.title} — Settle Up',
          sharePositionOrigin: origin,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '${widget.event.title} — Settle Up',
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _buildPdfBytes() async {
    final fmt = NumberFormat.currency(symbol: '\$');
    final balances = _computeBalances();
    final settlements = _computeSettlements(balances);
    final totalSpent = widget.expenses.fold(0.0, (s, e) => s + e.amount);
    final now = DateTime.now();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.102, 0.322, 0.463),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Settle Up',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(widget.event.title,
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 13)),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(fmt.format(totalSpent),
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold)),
                        pw.Text('Total spent',
                            style: const pw.TextStyle(
                                color: PdfColors.white, fontSize: 11)),
                      ],
                    ),
                    pw.Row(children: [
                      _pdfStat('Expenses', '${widget.expenses.length}'),
                      pw.SizedBox(width: 24),
                      _pdfStat('People', '${balances.length}'),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // The Score
          pw.Text('THE SCORE',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                  color: PdfColors.grey600)),
          pw.SizedBox(height: 8),
          ...balances.map((b) => _pdfBalanceRow(b, fmt)),
          pw.SizedBox(height: 20),

          // Settlement plan
          pw.Text('SETTLEMENT PLAN',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                  color: PdfColors.grey600)),
          pw.SizedBox(height: 8),
          if (settlements.isEmpty)
            pw.Text('Everyone is square! No payments needed.',
                style: const pw.TextStyle(color: PdfColors.grey))
          else
            ...settlements.map((s) => _pdfSettlementRow(s, fmt)),

          pw.SizedBox(height: 24),
          pw.Text(
            'Generated on ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
            style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final origin = _shareOrigin();
    setState(() => _exporting = true);
    try {
      final bytes = await _buildPdfBytes();
      final safeName =
          widget.event.title.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final name = '${safeName}_settle_up.pdf';
      if (kIsWeb) {
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: name, mimeType: 'application/pdf')],
          subject: '${widget.event.title} — Settle Up',
          sharePositionOrigin: origin,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: '${widget.event.title} — Settle Up',
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  pw.Widget _pdfStat(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold)),
          pw.Text(label,
              style:
                  const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
        ],
      );

  pw.Widget _pdfBalanceRow(_PersonBalance b, NumberFormat fmt) {
    final isPositive = b.net >= 0;
    final netColor = isPositive ? PdfColors.green700 : PdfColors.red700;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(b.name,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.Text(
                  'Paid ${fmt.format(b.paid)}  ·  Split ${fmt.format(b.owes)}',
                  style:
                      const pw.TextStyle(color: PdfColors.grey600, fontSize: 11)),
            ],
          ),
          pw.Text(
            '${isPositive ? '+' : ''}${fmt.format(b.net)}',
            style: pw.TextStyle(
                color: netColor,
                fontWeight: pw.FontWeight.bold,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSettlementRow(_Settlement s, NumberFormat fmt) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Row(
          children: [
            pw.Text(s.fromName,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(width: 8),
            pw.Text('pays', style: const pw.TextStyle(color: PdfColors.grey600)),
            pw.SizedBox(width: 8),
            pw.Text(fmt.format(s.amount),
                style: pw.TextStyle(
                    color: PdfColors.red700,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13)),
            pw.SizedBox(width: 8),
            pw.Text('to', style: const pw.TextStyle(color: PdfColors.grey600)),
            pw.SizedBox(width: 8),
            pw.Text(s.toName,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 13)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');
    final balances = _computeBalances();
    final settlements = _computeSettlements(balances);
    final totalSpent = widget.expenses.fold(0.0, (sum, e) => sum + e.amount);
    final participantCount =
        widget.event.guests.where((g) => g.isAccepted).length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💸 ${l10n.settleUp}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.event.title,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AppTappable(
                      key: _shareButtonKey,
                      onTap: _exporting ? null : () => _showExportOptions(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _exporting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Icon(Icons.ios_share,
                                color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ),
                    AppTappable(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.close,
                            color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HeaderStat(
                      label: l10n.totalSpent,
                      value: fmt.format(totalSpent),
                      large: true,
                    ),
                    const Spacer(),
                    _HeaderStat(
                      label: 'Expenses',
                      value: '${widget.expenses.length}',
                      align: CrossAxisAlignment.center,
                    ),
                    const SizedBox(width: 20),
                    _HeaderStat(
                      label: 'People',
                      value: '$participantCount',
                      align: CrossAxisAlignment.center,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Scrollable body ──────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetSectionHeader(icon: '🏆', title: l10n.theScore),
                  const SizedBox(height: 10),
                  ...balances.map((b) => _BalanceRow(balance: b, fmt: fmt)),
                  const SizedBox(height: 24),
                  _SheetSectionHeader(
                      icon: '💳', title: l10n.settlementPlan),
                  const SizedBox(height: 10),
                  if (settlements.isEmpty)
                    _AllSquareCard(message: l10n.allSquare)
                  else
                    ...settlements.map(
                        (s) => _SettlementRow(settlement: s, fmt: fmt)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final bool large;
  final CrossAxisAlignment align;

  const _HeaderStat({
    required this.label,
    required this.value,
    this.large = false,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: large ? 30 : 20,
            fontWeight: FontWeight.bold,
            letterSpacing: large ? -1.0 : -0.3,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  final String icon;
  final String title;

  const _SheetSectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final _PersonBalance balance;
  final NumberFormat fmt;

  const _BalanceRow({required this.balance, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final net = balance.net;
    final isPositive = net > 0.005;
    final isNegative = net < -0.005;
    final netColor = isPositive
        ? AppTheme.accent
        : isNegative
            ? AppTheme.danger
            : Colors.grey[500]!;
    final netBg = isPositive
        ? AppTheme.accent.withValues(alpha: 0.1)
        : isNegative
            ? AppTheme.danger.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            backgroundImage: balance.avatarUrl != null &&
                    balance.avatarUrl!.isNotEmpty
                ? NetworkImage(balance.avatarUrl!)
                : null,
            child: (balance.avatarUrl == null || balance.avatarUrl!.isEmpty)
                ? Text(
                    balance.name.isNotEmpty
                        ? balance.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Paid ${fmt.format(balance.paid)}  ·  Split ${fmt.format(balance.owes)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: netBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPositive
                  ? '+${fmt.format(net)}'
                  : isNegative
                      ? fmt.format(net)
                      : '✓ even',
              style: TextStyle(
                color: netColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  final _Settlement settlement;
  final NumberFormat fmt;

  const _SettlementRow({required this.settlement, required this.fmt});

  Widget _avatar(String name, String? url) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
      backgroundImage:
          url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: (url == null || url.isEmpty)
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _avatar(settlement.fromName, settlement.fromAvatar),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              settlement.fromName,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            children: [
              Text(
                fmt.format(settlement.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.danger,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 28, height: 2, color: Colors.grey[300]),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
          Expanded(
            child: Text(
              settlement.toName,
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _avatar(settlement.toName, settlement.toAvatar),
        ],
      ),
    );
  }
}

class _AllSquareCard extends StatelessWidget {
  final String message;

  const _AllSquareCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.1),
            AppTheme.primaryLight.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
