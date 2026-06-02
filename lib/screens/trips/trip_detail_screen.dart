import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../models/trip_stop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/add_member_sheet.dart';
import '../../widgets/trip_map_widget.dart';
import '../../widgets/trip_stop_form_sheet.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0; // tracked for FAB visibility
  // Track last prefetched waypoints key so we only fire a new prefetch when
  // the route actually changes (destination or stop coordinates change).
  String? _lastPrefetchKey;

  static const _tabIcons = [
    Icons.info_outline_rounded,
    Icons.route_outlined,
    Icons.map_outlined,
    Icons.chat_bubble_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabIcons.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteStop(BuildContext context, TripStop stop) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeStopTitle),
        content: Text(l10n.removeStopMessage(stop.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.remove,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TripProvider>().deleteStop(stop.id, widget.tripId);
    }
  }

  // Pin order: start → stops (by sortOrder) → destination.
  // This matches the driving direction passed to DirectionsService.
  List<TripMapPin> _buildMapPins(Trip trip) {
    final pins = <TripMapPin>[];
    if (trip.startLat != null && trip.startLng != null) {
      pins.add(TripMapPin(
        id: 'start',
        position: LatLng(trip.startLat!, trip.startLng!),
        title: trip.startLocation ?? 'Start',
        isStart: true,
      ));
    }
    for (final stop in trip.stops) {
      if (stop.addressLat != null && stop.addressLng != null) {
        pins.add(TripMapPin(
          id: stop.id,
          position: LatLng(stop.addressLat!, stop.addressLng!),
          title: stop.title,
          subtitle: stop.address.isNotEmpty ? stop.address : null,
        ));
      }
    }
    if (trip.destinationLat != null && trip.destinationLng != null) {
      pins.add(TripMapPin(
        id: 'destination',
        position: LatLng(trip.destinationLat!, trip.destinationLng!),
        title: trip.destination,
        isDestination: true,
      ));
    }
    return pins;
  }

  Future<void> _confirmLeave(Trip trip) async {
    final l10n = AppLocalizations.of(context);
    bool blockReinvite = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l10n.leaveTripTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.leaveTripMessage(
                  trip.title.isNotEmpty ? trip.title : l10n.thisTripFallback)),
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
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.leave,
                  style: const TextStyle(color: AppTheme.danger)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<TripProvider>().leaveTrip(trip.id, blockReinvite: blockReinvite);
      if (mounted) context.go('/trips');
    }
  }

  void _addMember(Trip trip) {
    showAddMemberSheet(
      context,
      onAdd: (member) {
        context
            .read<TripProvider>()
            .addMember(
              trip.id,
              displayName: member.displayName,
              email: member.email,
              phone: member.phone,
              userId: member.userId,
            )
            .catchError((Object e) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          final msg = e is ReinviteBlockedException
              ? l10n.reinviteBlockedError
              : e.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppTheme.danger,
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabLabels = [l10n.overview, l10n.itinerary, l10n.mapTab, l10n.chatTabLabel];
    final trip = context.watch<TripProvider>().getById(widget.tripId);
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.tripNotFound)),
      );
    }

    // Pre-warm the Directions API route in the background so the Map tab shows
    // the real road polyline as soon as it opens.  No-op if already cached.
    final prefetchPins = _buildMapPins(trip);
    final prefetchWaypoints = prefetchPins.map((p) => p.position).toList();
    if (prefetchWaypoints.length >= 2) {
      final wpKey = prefetchWaypoints
          .map((p) => '${p.latitude},${p.longitude}')
          .join('|');
      if (wpKey != _lastPrefetchKey) {
        _lastPrefetchKey = wpKey;
        TripMapWidget.prefetchRoute(prefetchWaypoints);
        // Also pre-render stop-pin icons so they are cached before the Map tab
        // opens.  Only stop pins (not start/destination) get numbered icons.
        final stopCount =
            prefetchPins.where((p) => !p.isStart && !p.isDestination).length;
        TripMapWidget.prefetchIcons(stopCount);
      }
    }

    final currentUserId = context.read<AuthProvider>().userId;
    final isOrganizer = trip.createdBy == currentUserId;
    // Any accepted member (including the organizer) may invite others.
    final canInvite = isOrganizer ||
        trip.members.any(
          (m) => m.userId == currentUserId && m.status == 'accepted',
        );

    return Scaffold(
        appBar: AppBar(
          title: Text(trip.title),
          bottom: TabBar(
            controller: _tabController,
            tabs: List.generate(
              _tabIcons.length,
              (i) => Tab(icon: Icon(_tabIcons[i], size: 20), text: tabLabels[i]),
            ),
            labelStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          actions: [
            if (isOrganizer)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editTripTooltip,
                onPressed: () => context.push('/trip/${trip.id}/edit'),
              )
            else
              IconButton(
                icon: const Icon(Icons.exit_to_app_outlined,
                    color: AppTheme.danger),
                tooltip: l10n.leaveTripTooltip,
                onPressed: () => _confirmLeave(trip),
              ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(
                trip: trip, currentUserId: currentUserId, canInvite: canInvite),
            _ItineraryTab(
              trip: trip,
              onDeleteStop: (s) => _confirmDeleteStop(context, s),
            ),
            TripMapWidget(pins: _buildMapPins(trip)),
            const _ChatTab(),
          ],
        ),
        floatingActionButton: switch (_tabIndex) {
          0 when canInvite => AppFab(onPressed: () => _addMember(trip)),
          1 => AppFab(
              onPressed: () => showTripStopFormSheet(context, tripId: trip.id),
            ),
          _ => null,
        },
      );
  }
}

class _OverviewTab extends StatefulWidget {
  final Trip trip;
  final String? currentUserId;
  final bool canInvite;

  const _OverviewTab({
    required this.trip,
    this.currentUserId,
    required this.canInvite,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final Set<String> _resendingIds = {};

  Future<void> _resend(TripMember member) async {
    setState(() => _resendingIds.add(member.id));
    final l10n = AppLocalizations.of(context);
    try {
      await context.read<TripProvider>().resendInvite(member.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inviteResentTo(member.displayName))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resendingIds.remove(member.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final currentUserId = widget.currentUserId;
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('MMM d, y  h:mm a');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (trip.startLocation != null &&
            trip.startLocation!.isNotEmpty) ...[
          _InfoRow(
            icon: Icons.trip_origin_outlined,
            label: l10n.startingFrom,
            value: trip.startLocation!,
          ),
          const SizedBox(height: 12),
        ],
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: l10n.destination,
          value: trip.destination,
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: l10n.startLabel,
          value:
              trip.startAt != null ? fmt.format(trip.startAt!) : l10n.notSet,
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.event_outlined,
          label: l10n.endLabel,
          value: trip.endAt != null ? fmt.format(trip.endAt!) : l10n.notSet,
        ),
        if (trip.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.notes_outlined,
            label: l10n.notes,
            value: trip.notes,
          ),
        ],
        const SizedBox(height: 24),
        Text(l10n.membersSection,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...trip.members.map((m) {
              final isMe = m.userId != null && m.userId == currentUserId;
              final canResend = m.status == 'pending' &&
                  widget.canInvite &&
                  m.userId != null &&
                  m.userId != currentUserId;

              // Resolve inviter name from the already-loaded members list.
              String? inviterLabel;
              if (m.invitedBy != null) {
                if (m.invitedBy == currentUserId) {
                  inviterLabel = l10n.invitedBy(l10n.you);
                } else {
                  final inviter = trip.members
                      .where((x) => x.userId == m.invitedBy)
                      .firstOrNull;
                  if (inviter != null) {
                    inviterLabel = l10n.invitedBy(inviter.displayName);
                  }
                }
              }

              final hasEmail =
                  m.email != null && m.email!.isNotEmpty && !isMe;
              final hasExtraLine = hasEmail || inviterLabel != null;

              final hasAvatar =
                  m.avatarUrl != null && m.avatarUrl!.isNotEmpty;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: m.role == 'organizer'
                      ? AppTheme.primary
                      : Colors.grey[200],
                  backgroundImage:
                      hasAvatar ? NetworkImage(m.avatarUrl!) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          m.displayName.isNotEmpty
                              ? m.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: m.role == 'organizer'
                                  ? Colors.white
                                  : AppTheme.primary)),
                ),
                title: Text(isMe ? l10n.you : m.displayName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(m.role == 'organizer'
                            ? l10n.organizer
                            : l10n.member),
                        if (m.userId != null) ...[
                          const SizedBox(width: 6),
                          _StatusChip(
                            label: switch (m.status) {
                              'pending'  => l10n.invitePending,
                              'declined' => l10n.inviteDeclined,
                              'left'     => l10n.memberLeft,
                              _          => l10n.inviteAccepted,
                            },
                            color: switch (m.status) {
                              'pending'  => Colors.orange,
                              'declined' => AppTheme.danger,
                              'left'     => Colors.grey,
                              _          => Colors.green,
                            },
                          ),
                        ],
                      ],
                    ),
                    if (hasEmail)
                      Text(
                        m.email!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                    ? _resendingIds.contains(m.id)
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
                              icon: const Icon(Icons.send_outlined),
                              iconSize: 20,
                              onPressed: () => _resend(m),
                            ),
                          )
                    : null,
                dense: true,
                isThreeLine: hasExtraLine,
              );
            }),
      ],
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
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
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

class _ItineraryTab extends StatelessWidget {
  final Trip trip;
  final void Function(TripStop stop) onDeleteStop;

  const _ItineraryTab(
      {required this.trip, required this.onDeleteStop});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (trip.stops.isEmpty) {
      return Center(
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
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: trip.stops.length,
      itemBuilder: (context, index) {
        final stop = trip.stops[index];
        return Slidable(
          key: ValueKey(stop.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => onDeleteStop(stop),
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: l10n.delete,
              ),
            ],
          ),
          child: _StopCard(stop: stop, tripId: trip.id),
        );
      },
    );
  }
}

class _StopCard extends StatelessWidget {
  final TripStop stop;
  final String tripId;

  const _StopCard({required this.stop, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeFmt = DateFormat('MMM d  h:mm a');
    return AppTappable(
      onTap: () =>
          showTripStopFormSheet(context, tripId: tripId, existing: stop),
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
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ],
              if (stop.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(stop.notes,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Chat tab ──────────────────────────────────────────────────────────────────

class _ChatTab extends StatefulWidget {
  const _ChatTab();

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  // null = not in mention mode; '' = "@" typed but no query yet
  String? _mentionQuery;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _messageCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _messageCtrl.removeListener(_onTextChanged);
    _scrollCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _messageCtrl.text;
    final cursor = _messageCtrl.selection.baseOffset;
    if (cursor < 0) {
      if (_mentionQuery != null) setState(() => _mentionQuery = null);
      return;
    }
    final beforeCursor = text.substring(0, cursor);
    final atIdx = beforeCursor.lastIndexOf('@');
    if (atIdx >= 0) {
      final afterAt = beforeCursor.substring(atIdx + 1);
      if (!afterAt.contains(' ')) {
        final q = afterAt.toLowerCase();
        if (_mentionQuery != q) setState(() => _mentionQuery = q);
        return;
      }
    }
    if (_mentionQuery != null) setState(() => _mentionQuery = null);
  }

  void _insertMention(TripMember member) {
    final text = _messageCtrl.text;
    final cursor = _messageCtrl.selection.baseOffset;
    final beforeCursor = text.substring(0, cursor);
    final atIdx = beforeCursor.lastIndexOf('@');
    if (atIdx < 0) return;
    final before = text.substring(0, atIdx);
    final after = text.substring(cursor);
    final insertion = '@${member.displayName} ';
    final newText = '$before$insertion$after';
    _messageCtrl.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: before.length + insertion.length),
    );
    setState(() => _mentionQuery = null);
  }

  List<TripMember> _suggestions(String tripId, String myUserId) {
    final trip = context.read<TripProvider>().getById(tripId);
    if (trip == null || _mentionQuery == null) return [];
    return trip.members
        .where((m) =>
            m.status == 'accepted' &&
            m.userId != myUserId &&
            (_mentionQuery!.isEmpty ||
                m.displayName.toLowerCase().contains(_mentionQuery!)))
        .toList();
  }

  void _notifyMentions(String text, String tripId, String myUserId) {
    final mentionRegex = RegExp(r'@(\S+)');
    final names = mentionRegex
        .allMatches(text)
        .map((m) => m.group(1)!.toLowerCase())
        .toSet();
    if (names.isEmpty) return;

    final trip = context.read<TripProvider>().getById(tripId);
    if (trip == null) return;

    final mentionedIds = trip.members
        .where((m) =>
            m.userId != null &&
            m.userId != myUserId &&
            m.status == 'accepted' &&
            names.contains(m.displayName.toLowerCase()))
        .map((m) => m.userId!)
        .toList();
    if (mentionedIds.isEmpty) return;

    final preview = text.length > 80 ? '${text.substring(0, 80)}…' : text;
    Supabase.instance.client.functions
        .invoke('send-mention-notification', body: {
          'trip_id': tripId,
          'mentioned_user_ids': mentionedIds,
          'message_preview': preview,
        })
        // ignore: unawaited_futures
        .then((_) {}, onError: (Object e) =>
            debugPrint('send-mention-notification error: $e'));
  }

  void _onScroll() {
    // Load more when the user scrolls to the top (oldest messages).
    if (_scrollCtrl.position.pixels <= 60) {
      final chat = context.read<ChatProvider>();
      if (chat.hasMore && !chat.loading) {
        chat.loadMore();
      }
    }
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _messageCtrl.clear();
    final tripId = context.read<ChatProvider>().tripId;
    final myUserId = context.read<AuthProvider>().userId ?? '';
    try {
      await context.read<ChatProvider>().sendMessage(text);
      _notifyMentions(text, tripId, myUserId);
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
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
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chat = context.watch<ChatProvider>();
    final myUserId = context.read<AuthProvider>().userId ?? '';
    final tripId = chat.tripId;
    final suggestions = _suggestions(tripId, myUserId);

    return Column(
      children: [
        // Loading indicator while fetching older messages
        if (chat.loading && chat.messages.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),

        // Message list
        Expanded(
          child: chat.loading && chat.messages.isEmpty
              ? const Center(child: CircularProgressIndicator.adaptive())
              : chat.messages.isEmpty
                  ? Center(
                      child: Text(
                        l10n.chatNoMessages,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: chat.messages.length,
                      itemBuilder: (_, i) {
                        final msg = chat.messages[i];
                        final isMe = msg.userId == myUserId;
                        return _ChatBubble(message: msg, isMe: isMe);
                      },
                    ),
        ),

        // @mention suggestions
        if (suggestions.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (_, i) {
                  final m = suggestions[i];
                  final url = (m.avatarUrl?.isNotEmpty == true)
                      ? m.avatarUrl
                      : null;
                  final initials = m.displayName.isNotEmpty
                      ? m.displayName[0].toUpperCase()
                      : '?';
                  return AppTappable(
                    onTap: () => _insertMention(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.18),
                            foregroundImage:
                                url != null ? NetworkImage(url) : null,
                            child: url == null
                                ? Text(initials,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(m.displayName,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Input field
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 4 : 8,
              top: 6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.chatSendHint,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 4),
                _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: AppTheme.primary,
                        tooltip: l10n.chatSend,
                        onPressed: _send,
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('h:mm a');
    final bubbleColor =
        isMe ? AppTheme.primary : const Color(0xFFE9E9EB);
    final textColor = isMe ? Colors.white : Colors.black87;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.65;

    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
      ),
      child: _MentionText(
        text: message.content,
        style: TextStyle(fontSize: 15, color: textColor),
        isMe: isMe,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _Avatar(
              avatarUrl: message.senderAvatarUrl,
              name: message.senderName ?? '',
            ),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: align,
            children: [
              if (!isMe && message.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    message.senderName!,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary),
                  ),
                ),
              bubble,
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Text(
                  timeFmt.format(message.createdAt.toLocal()),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _MentionText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool isMe;

  const _MentionText(
      {required this.text, required this.style, this.isMe = false});

  static final _mentionRegex = RegExp(r'@\S+');

  @override
  Widget build(BuildContext context) {
    final mentionColor =
        isMe ? Colors.white.withValues(alpha: 0.8) : AppTheme.primary;
    final spans = <InlineSpan>[];
    int last = 0;
    for (final match in _mentionRegex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(color: mentionColor, fontWeight: FontWeight.w600),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(
      text: TextSpan(style: style, children: spans),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;

  const _Avatar({required this.avatarUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = (avatarUrl?.isNotEmpty == true) ? avatarUrl : null;

    return CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.18),
      foregroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(initials,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary))
          : null,
    );
  }
}
