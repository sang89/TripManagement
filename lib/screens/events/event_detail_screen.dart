import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:math' show Random, min, cos, sin, pi;

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
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_keys.dart';
import '../../l10n/app_localizations.dart';
import '../../models/activity_suggestion.dart';
import '../../models/event.dart';
import '../../models/event_bring_item.dart';
import '../../models/event_expense.dart';
import '../../models/event_gift_pool.dart';
import '../../models/event_poll.dart';
import '../../models/event_guest.dart';
import '../../models/event_session.dart';
import '../../models/event_message.dart';
import '../../models/event_photo.dart';
import '../../models/event_prediction.dart';
import '../../models/event_stop.dart';
import '../../models/event_toast.dart';
import '../../models/event_wish.dart';
import '../../models/event_wishlist_item.dart';
import '../../models/friendship.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_chat_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/subscription_provider.dart';
import '../notifications/notifications_screen.dart';
import '../../services/activity_suggestions_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/trip_places_service.dart';
import '../../services/user_lookup_service.dart';
import '../../utils/avatar_utils.dart';
import '../../utils/invite_codec.dart';
import '../../widgets/event_type_banner.dart';
import '../../widgets/add_member_sheet.dart';
import '../../widgets/ai_itinerary_sheet.dart';
import '../../widgets/event_map_widget.dart';
import '../../widgets/event_stop_form_sheet.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final int initialTab;

  const EventDetailScreen({super.key, required this.eventId, this.initialTab = 0});

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
    // Read the event synchronously (already in provider) to set the correct
    // initial tab count — avoids a dispose-during-build crash on birthday events.
    final event = Provider.of<EventProvider>(context, listen: false)
        .getById(widget.eventId);
    final tabCount = event?.isBirthday == true ? 5 : 4;
    final clampedInitial = widget.initialTab.clamp(0, tabCount - 1);
    _tabController =
        TabController(length: tabCount, initialIndex: clampedInitial, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final eventId = widget.eventId;
      final provider = context.read<EventProvider>();
      provider
        ..fetchPhotos(eventId)
        ..fetchExpenses(eventId)
        ..fetchBringList(eventId)
        ..fetchPolls(eventId);
      final ev = provider.getById(eventId);
      if (ev?.isBirthday == true) {
        provider
          ..fetchWishlist(eventId)
          ..fetchGiftPool(eventId)
          ..fetchPredictions(eventId)
          ..fetchWishes(eventId)
          ..fetchToasts(eventId);
      }
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

        final eventBannerTheme = bannerThemeFor(event.eventType);

        // Use the controller's actual length to gate the 5th tab so that
        // TabBar, TabBarView and the controller are ALWAYS consistent.
        final mainTabCount = _tabController.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(event.title, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            flexibleSpace: EventTypeBanner(theme: eventBannerTheme, height: double.infinity),
            bottom: TabBar(
              controller: _tabController,
              tabAlignment: TabAlignment.fill,
              // Shrink icon + font + padding when 5 tabs to prevent clipping.
              labelStyle: TextStyle(
                  fontSize: mainTabCount > 4 ? 9 : 11,
                  fontWeight: FontWeight.w600),
              labelPadding: mainTabCount > 4
                  ? const EdgeInsets.symmetric(horizontal: 2)
                  : null,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(icon: Icon(Icons.info_outline_rounded, size: mainTabCount > 4 ? 18 : 20), text: l10n.infoTab),
                Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: mainTabCount > 4 ? 18 : 20), text: l10n.chatTabLabel),
                Tab(icon: Icon(Icons.photo_library_outlined, size: mainTabCount > 4 ? 18 : 20), text: l10n.photosTab),
                Tab(icon: Icon(Icons.grid_view_outlined, size: mainTabCount > 4 ? 18 : 20), text: event.isSignup ? 'Session' : l10n.organizeTab),
                if (event.isBirthday)
                  Tab(icon: const Icon(Icons.favorite_rounded, size: 18), text: l10n.memoriesTab),
              ],
            ),
            actions: [
              Consumer<NotificationsProvider>(
                builder: (_, notifs, _) => Badge(
                  isLabelVisible: notifs.unreadCount > 0,
                  label: Text(
                    notifs.unreadCount > 9 ? '9+' : '${notifs.unreadCount}',
                  ),
                  child: IconButton(
                    icon: Icon(
                      notifs.unreadCount > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    tooltip: l10n.notifications,
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                ),
              ),
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
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showEventActions(
                    context,
                    event,
                    l10n,
                    onDelete: () =>
                        _confirmDelete(context, event, provider),
                  ),
                )
              else if (!isOrganizer &&
                  event.guests.any(
                      (g) => g.userId == authUid && g.status != 'left'))
                IconButton(
                  icon: const Icon(Icons.exit_to_app_outlined,
                      color: AppTheme.danger),
                  tooltip: l10n.leave,
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
                key: ValueKey('organize_${event.isQuickBites}_${event.isBirthday}'),
                event: event,
                authUid: authUid,
                isOrganizer: isOrganizer,
                items: provider.bringItemsFor(event.id),
                expenses: provider.expensesFor(event.id),
                polls: provider.pollsFor(event.id),
              ),
              if (event.isBirthday)
                _MemoriesTabGroup(
                  event: event,
                  authUid: authUid,
                  isOrganizer: isOrganizer,
                  wishlistItems: provider.wishlistFor(event.id),
                  giftPool: provider.giftPoolFor(event.id),
                  predictions: provider.predictionsFor(event.id),
                  wishes: provider.wishesFor(event.id),
                  toasts: provider.toastsFor(event.id),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareEvent(BuildContext context, Event event) async {
    final l10n = AppLocalizations.of(context);
    final url = 'https://tripmanagement.app/event/invite/${InviteCodec.encode(event.inviteCode)}';
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

void _showEventActions(
  BuildContext context,
  Event event,
  AppLocalizations l10n, {
  required VoidCallback onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final surface = Theme.of(sheetCtx).colorScheme.surface;
      final onSurface = Theme.of(sheetCtx).colorScheme.onSurface;
      final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
      final cancelBg = isDark
          ? onSurface.withValues(alpha: 0.06)
          : onSurface.withValues(alpha: 0.04);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // single unified panel
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _ActionSheetTile(
                      iconWidget: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 18, color: AppTheme.primary),
                      ),
                      label: l10n.editEvent,
                      subtitle: l10n.editEventSubtitle,
                      labelColor: onSurface,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        context.push('/event/${event.id}/edit');
                      },
                    ),
                    const SizedBox(height: 4),
                    _ActionSheetTile(
                      iconWidget: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete_rounded,
                            size: 18, color: AppTheme.danger),
                      ),
                      label: l10n.deleteEventTitle,
                      subtitle: l10n.deleteEventSubtitle,
                      labelColor: AppTheme.danger,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        onDelete();
                      },
                    ),
                    const SizedBox(height: 8),
                    // cancel — subtle tinted strip at bottom
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                      child: AppTappable(
                        onTap: () => Navigator.pop(sheetCtx),
                        child: Container(
                          width: double.infinity,
                          color: cancelBg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l10n.cancel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionSheetTile extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final String subtitle;
  final Color labelColor;
  final VoidCallback onTap;

  const _ActionSheetTile({
    required this.iconWidget,
    required this.label,
    required this.subtitle,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: labelColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }
}

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

  int get _tabCount => widget.event.isTrip ? 3 : widget.event.isSignup ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: _tabCount, vsync: this);
  }

  @override
  void didUpdateWidget(_InfoTabGroup old) {
    super.didUpdateWidget(old);
    if (old.event.isTrip != widget.event.isTrip ||
        old.event.isSignup != widget.event.isSignup) {
      _ctrl.dispose();
      _ctrl = TabController(length: _tabCount, vsync: this);
    }
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

    // Guard against hot-reload leaving a stale controller with wrong length.
    if (_ctrl.length != _tabCount) {
      _ctrl.dispose();
      _ctrl = TabController(length: _tabCount, vsync: this);
    }

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
              if (event.isSignup) const Tab(icon: Icon(Icons.help_outline_rounded, size: 18), text: 'Guide'),
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
              if (event.isSignup)
                _SignupGuideTab(isOrganizer: widget.isOrganizer),
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
    super.key,
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

  int get _tabCount => widget.event.isSignup
      ? 4
      : widget.event.isQuickBites
          ? 4
          : widget.event.isBirthday
              ? 5
              : widget.event.isTrip
                  ? 4
                  : 3;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: _tabCount, vsync: this);
  }

  @override
  void didUpdateWidget(_OrganizeTabGroup old) {
    super.didUpdateWidget(old);
    if (old.event.isSignup != widget.event.isSignup ||
        old.event.isQuickBites != widget.event.isQuickBites ||
        old.event.isBirthday != widget.event.isBirthday ||
        old.event.isTrip != widget.event.isTrip) {
      _ctrl.dispose();
      _ctrl = TabController(length: _tabCount, vsync: this);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guard against hot-reload leaving a stale controller with wrong length.
    if (_ctrl.length != _tabCount) {
      _ctrl.dispose();
      _ctrl = TabController(length: _tabCount, vsync: this);
    }

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
            // Slightly smaller text when 5 tabs to avoid crowding.
            labelStyle: TextStyle(
                fontSize: _tabCount > 4 ? 11 : 13,
                fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(
                fontSize: _tabCount > 4 ? 11 : 13),
            tabs: [
              if (widget.event.isSignup)
                Tab(icon: const Icon(Icons.format_list_numbered_outlined, size: 18), text: l10n.signupRosterTab)
              else
                Tab(icon: const Icon(Icons.checklist_outlined, size: 18), text: l10n.todoTab),
              Tab(icon: const Icon(Icons.receipt_outlined, size: 18), text: l10n.expensesTab),
              Tab(icon: const Icon(Icons.how_to_vote_outlined, size: 18), text: l10n.pollsTab),
              if (widget.event.isSignup)
                Tab(icon: const Icon(Icons.qr_code_outlined, size: 18), text: l10n.signupInviteTab),
              if (widget.event.isTrip)
                Tab(icon: const Icon(Icons.explore_outlined, size: 18), text: l10n.exploreTab),
              if (widget.event.isQuickBites)
                Tab(icon: const Icon(Icons.ramen_dining_outlined, size: 18), text: l10n.cravingsTab),
              if (widget.event.isBirthday) ...[
                Tab(icon: const Icon(Icons.celebration_rounded, size: 18), text: l10n.celebrateTab),
                Tab(icon: const Icon(Icons.card_giftcard_rounded, size: 18), text: l10n.giftsTab),
              ],
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _ctrl,
            children: [
              if (widget.event.isSignup)
                _SignupRosterTab(
                  event: widget.event,
                  authUid: widget.authUid,
                  isOrganizer: widget.isOrganizer,
                )
              else
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
              if (widget.event.isSignup)
                _SignupInviteTab(event: widget.event),
              if (widget.event.isTrip)
                _ExploreTab(event: widget.event, tabController: _ctrl, tabIndex: 3),
              if (widget.event.isQuickBites)
                _CravingsTab(
                  event: widget.event,
                  authUid: widget.authUid,
                  isOrganizer: widget.isOrganizer,
                ),
              if (widget.event.isBirthday) ...[
                _CelebrateTab(
                  event: widget.event,
                  authUid: widget.authUid,
                  isOrganizer: widget.isOrganizer,
                  polls: widget.polls,
                ),
                _GiftsTab(
                  event: widget.event,
                  authUid: widget.authUid,
                  isOrganizer: widget.isOrganizer,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Signup Guide tab ──────────────────────────────────────────────────────────

class _SignupGuideTab extends StatelessWidget {
  final bool isOrganizer;
  const _SignupGuideTab({required this.isOrganizer});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          'How this works',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          isOrganizer
              ? 'Everything you need to run your recurring sessions.'
              : 'Here\'s how to sign up and what to expect.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
        ),
        const SizedBox(height: 20),

        if (isOrganizer) ...[
          _GuideSectionExpansion(
            title: 'For organisers',
            color: const Color(0xFFEA580C),
            icon: Icons.manage_accounts_rounded,
            steps: [
              _GuideStep(
                emoji: '📅',
                title: 'Create sessions',
                body: 'Tap Organize → Roster → "+ Add session". Pick a date and time. Session #1 is created automatically when you first make the event.',
                color: const Color(0xFFEA580C),
              ),
              _GuideStep(
                emoji: '📲',
                title: 'Share the QR code',
                body: 'Go to Organize → Invite. Select a session, then share its unique QR code or copy the invite code. Each session has its own code.',
                color: const Color(0xFFEA580C),
              ),
              _GuideStep(
                emoji: '👥',
                title: 'Manage the roster',
                body: 'Expand any session in the Roster tab to see who\'s signed up. Swipe a row left to promote, demote, or remove. Drag to reorder.',
                color: const Color(0xFFEA580C),
              ),
              _GuideStep(
                emoji: '✅',
                title: 'Mark attendance',
                body: 'After the session ends, tap each roster entry\'s attendance chip to mark "Attended" or "No-show". Only available once the session has ended.',
                color: const Color(0xFFEA580C),
              ),
              _GuideStep(
                emoji: '🔒',
                title: 'Signup lock',
                body: 'If you set a lock window (e.g. 2 hours), signups and cancellations are disabled that many hours before the session starts.',
                color: const Color(0xFFEA580C),
              ),
              _GuideStep(
                emoji: '✅',
                title: 'Approval requests',
                body: 'Enable "Requires approval" when creating a session to review each signup manually. Pending requests show a purple badge on the session card — tap to approve or reject.',
                color: const Color(0xFFEA580C),
              ),
              _GuideStep(
                emoji: '🔐',
                title: 'Private sessions',
                body: 'Private sessions (shown with a 🔒 badge) are not joinable via a public link. Only people you personally share the invite code with can sign up.',
                color: const Color(0xFFEA580C),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        _GuideSectionExpansion(
          title: 'For members',
          color: const Color(0xFFDB2777),
          icon: Icons.groups_rounded,
          steps: [
            _GuideStep(
              emoji: '🎟️',
              title: 'Claim your spot',
              body: 'Tap the "Join" button (QR scanner icon) in the bottom nav bar, then scan the session QR code or paste the invite code someone shared with you.',
              color: const Color(0xFFDB2777),
            ),
            _GuideStep(
              emoji: '⏳',
              title: 'Waitlist',
              body: 'If the session is full, you join the waitlist. When someone cancels their confirmed spot, the first person on the waitlist is promoted automatically.',
              color: const Color(0xFFDB2777),
            ),
            _GuideStep(
              emoji: '📋',
              title: 'Pending approval',
              body: 'Some sessions require the organizer\'s approval before you\'re confirmed. You\'ll see a "Pending review" status on the session card until the organizer approves or rejects your request.',
              color: const Color(0xFFDB2777),
            ),
            _GuideStep(
              emoji: '✔️',
              title: 'Confirm attendance',
              body: 'Before the session, you can tap your spot\'s confirmation chip to let the organizer know you\'ll definitely be there. This is optional but helpful.',
              color: const Color(0xFFDB2777),
            ),
            _GuideStep(
              emoji: '🔁',
              title: 'Sign up each session',
              body: 'The roster resets for every session. Being signed up for session #3 doesn\'t carry over to #4 — you need to sign up for each one separately.',
              color: const Color(0xFFDB2777),
            ),
            _GuideStep(
              emoji: '❌',
              title: 'Cancel your spot',
              body: 'Expand the session in the Roster tab and tap "Cancel my spot". If there\'s a lock window, cancellation closes at the same time as signups.',
              color: const Color(0xFFDB2777),
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 10),

        _GuideSectionExpansion(
          title: 'Chat & photos',
          color: const Color(0xFF7C3AED),
          icon: Icons.chat_bubble_rounded,
          initiallyExpanded: false,
          steps: [
            _GuideStep(
              emoji: '💬',
              title: 'Shared across all sessions',
              body: 'The Chat and Photos tabs belong to the whole event — one conversation and one photo album for the entire community, not per session.',
              color: const Color(0xFF7C3AED),
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideSectionExpansion extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<_GuideStep> steps;
  final bool initiallyExpanded;

  const _GuideSectionExpansion({
    required this.title,
    required this.color,
    required this.icon,
    required this.steps,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded: initiallyExpanded,
          iconColor: color,
          collapsedIconColor: color.withValues(alpha: 0.6),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          title: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  final Color color;
  final bool isLast;

  const _GuideStep({
    required this.emoji,
    required this.title,
    required this.body,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + dot
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.30), width: 1.5),
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: color.withValues(alpha: 0.18),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(body,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.45)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
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
        // Birthday hero card
        if (event.isBirthday) ...[
          _BirthdayHeroCard(event: event),
          const SizedBox(height: 16),
        ],

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

        // RSVP / member counts — unified across all event types
        const Divider(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _CountChip(
              label: event.isTrip
                  ? '${event.goingCount} ${l10n.inviteAccepted.toLowerCase()}'
                  : l10n.goingCount(event.goingCount),
              color: Colors.green,
            ),
            if (!event.isTrip && event.maybeCount > 0)
              _CountChip(
                  label: l10n.maybeCount(event.maybeCount),
                  color: Colors.amber),
            if (event.pendingCount > 0)
              _CountChip(
                label: '${event.pendingCount} ${l10n.invitePending.toLowerCase()}',
                color: Colors.orange,
              ),
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
    // Filter out legacy [order:*] items created by the removed Orders tab.
    final visibleItems = items.where((i) => !(i.note?.startsWith('[order:') ?? false)).toList();

    return Stack(
      children: [
        visibleItems.isEmpty
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
                itemCount: visibleItems.length,
                itemBuilder: (_, i) {
                  final item = visibleItems[i];
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
    final isRestaurant = poll.isRestaurantPoll;
    final myVotedIds =
        authUid != null ? poll.myVotedOptionIds(authUid!) : const <String>{};
    final total = poll.totalVotes;
    final uniqueVoterCount = poll.votes.map((v) => v.userId).toSet().length;

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
            for (final option in (List.of(poll.options)
                  ..sort((a, b) => poll.votesFor(b.id).compareTo(poll.votesFor(a.id))))) ...[
              Builder(builder: (context) {
                final reactionCounts = authUid != null
                    ? poll.reactionsFor(option.id)
                    : <String, int>{};
                final myEmojis = authUid != null
                    ? poll.myReactionEmojis(option.id, authUid!)
                    : <String>{};

                void handleReact(String emoji) {
                  if (authUid == null) return;
                  context
                      .read<EventProvider>()
                      .reactToPollOption(option.id, emoji, authUid!, eventId);
                }

                void handleUnreact(String emoji) {
                  if (authUid == null) return;
                  final reaction = option.reactions.firstWhere(
                    (r) => r.userId == authUid && r.emoji == emoji,
                    orElse: () => EventPollReaction(
                        id: '', optionId: '', userId: '', emoji: '',
                        createdAt: DateTime.now()),
                  );
                  if (reaction.id.isEmpty) return;
                  context
                      .read<EventProvider>()
                      .unreactToPollOption(reaction.id, option.id, eventId);
                }

                return isRestaurant
                    ? _RestaurantPollOptionRow(
                        key: ValueKey(option.id),
                        option: option,
                        votes: poll.votesFor(option.id),
                        isSelected: myVotedIds.contains(option.id),
                        reactions: reactionCounts,
                        myReactionEmojis: myEmojis,
                        onReact: handleReact,
                        onUnreact: handleUnreact,
                        onTap: authUid == null
                            ? null
                            : () {
                                final provider = context.read<EventProvider>();
                                if (myVotedIds.contains(option.id)) {
                                  provider.unvote(poll.id, option.id, eventId);
                                } else {
                                  provider.vote(poll.id, option.id, eventId);
                                }
                              },
                      )
                    : _PollOptionRow(
                        key: ValueKey(option.id),
                        option: option,
                        votes: poll.votesFor(option.id),
                        total: total,
                        isSelected: myVotedIds.contains(option.id),
                        reactions: reactionCounts,
                        myReactionEmojis: myEmojis,
                        onReact: handleReact,
                        onUnreact: handleUnreact,
                        onTap: authUid == null
                            ? null
                            : () {
                                final provider = context.read<EventProvider>();
                                if (myVotedIds.contains(option.id)) {
                                  provider.unvote(poll.id, option.id, eventId);
                                } else {
                                  provider.vote(poll.id, option.id, eventId);
                                }
                              },
                      );
              }),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Text(
              isRestaurant
                  ? '$uniqueVoterCount voter${uniqueVoterCount == 1 ? '' : 's'}'
                  : l10n.pollsVoteCount(total),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// ~96 emojis for the reaction panel (8-column grid = 12 rows).
const _kAllReactionEmojis = [
  // Faces & emotions
  '😂', '😍', '🥲', '😎', '🤩', '🥳', '😱', '😅', '🤣', '🫡',
  '😤', '🫠', '🥺', '😭', '🙄', '🤔', '😒', '😬', '🤯', '🥴',
  '😵', '🤗', '🥹', '😈', '👻',
  // Love & affection
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
  // Hands & gestures
  '👍', '👎', '🙌', '👏', '🤝', '💪', '👋', '🤙', '✌️', '🤞',
  // Celebration
  '🎉', '🎊', '🏆', '👑', '🎯', '🎪', '🎭', '🎨', '🎰', '🎸',
  // Food & drink
  '🍕', '🍔', '🌮', '🍣', '🍜', '🍝', '🧋', '🍦', '🎂', '🍩',
  // Animals & nature
  '🦁', '🐻', '🐼', '🦊', '🐸', '🦄', '🦋', '🐙', '🦞', '🐳',
  // Fire & energy
  '🔥', '⚡', '💫', '✨', '🌟', '⭐', '🌈', '🌊', '💥', '🎆',
  // Objects & symbols
  '💎', '🚀', '💯', '🎵', '🎶', '💰', '🎮', '🔮', '🧨', '💣',
  // Special / fun
  '💀', '🤖', '👽', '🎃', '🫧', '🌀',
];

// Maximum reactions a single user may place on one option.
const _kMaxReactionsPerUser = 10;

void _showEmojiPickerSheet(
  BuildContext context, {
  required Set<String> myEmojis,
  required void Function(String) onReact,
  required void Function(String) onUnreact,
  int maxReactions = _kMaxReactionsPerUser,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EmojiPickerSheet(
      initialMyEmojis: myEmojis,
      onReact: onReact,
      onUnreact: onUnreact,
      maxReactions: maxReactions,
    ),
  );
}

class _EmojiPickerSheet extends StatefulWidget {
  final Set<String> initialMyEmojis;
  final void Function(String) onReact;
  final void Function(String) onUnreact;
  final int maxReactions;

  const _EmojiPickerSheet({
    required this.initialMyEmojis,
    required this.onReact,
    required this.onUnreact,
    this.maxReactions = _kMaxReactionsPerUser,
  });

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  late final List<String> _shuffled;
  late final Set<String> _myEmojis;

  @override
  void initState() {
    super.initState();
    _shuffled = List.of(_kAllReactionEmojis)..shuffle();
    _myEmojis = Set.of(widget.initialMyEmojis);
  }

  @override
  Widget build(BuildContext context) {
    final maxReached = _myEmojis.length >= widget.maxReactions;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('React 🎉',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: maxReached
                        ? AppTheme.danger.withValues(alpha: 0.12)
                        : const Color(0xFF00B09B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_myEmojis.length} / ${widget.maxReactions}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: maxReached
                          ? AppTheme.danger
                          : const Color(0xFF00796B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _shuffled.length,
              itemBuilder: (ctx, i) {
                final emoji = _shuffled[i];
                final isMine = _myEmojis.contains(emoji);
                final disabled = !isMine && maxReached;
                return TweenAnimationBuilder<double>(
                  key: ValueKey('$emoji-${isMine ? 1 : 0}'),
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (ctx, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: AppTappable(
                    onTap: disabled
                        ? null
                        : () {
                            if (isMine) {
                              widget.onUnreact(emoji);
                            } else {
                              widget.onReact(emoji);
                            }
                            Navigator.pop(context);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isMine
                            ? const Color(0xFF00B09B).withValues(alpha: 0.18)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        border: isMine
                            ? Border.all(
                                color: const Color(0xFF00B09B)
                                    .withValues(alpha: 0.5),
                                width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: TextStyle(
                            fontSize: isMine ? 26 : 22,
                            color: disabled ? Colors.grey.shade300 : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionPills extends StatefulWidget {
  final Map<String, int> reactions;
  final Set<String> myEmojis;
  final void Function(String emoji) onToggle;

  const _ReactionPills({
    required this.reactions,
    required this.myEmojis,
    required this.onToggle,
  });

  @override
  State<_ReactionPills> createState() => _ReactionPillsState();
}

class _ReactionPillsState extends State<_ReactionPills> {
  final _rng = Random();
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = widget.reactions.keys.toList()..shuffle(_rng);
  }

  @override
  void didUpdateWidget(_ReactionPills old) {
    super.didUpdateWidget(old);
    final current = widget.reactions.keys.toSet();
    // Remove emojis that disappeared.
    _order.removeWhere((e) => !current.contains(e));
    // Insert new emojis at a random position.
    for (final e in current.difference(old.reactions.keys.toSet())) {
      final pos = _order.isEmpty ? 0 : _rng.nextInt(_order.length + 1);
      _order.insert(pos, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reactions.isEmpty) {
      return Text(
        'Hold to react',
        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
      );
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: _order.map((emoji) {
        final count = widget.reactions[emoji];
        if (count == null) return const SizedBox.shrink();
        final isMine = widget.myEmojis.contains(emoji);
        final seed = emoji.runes.first;
        final emojiFs = 12.0 + (seed % 4);
        final radius = 8.0 + (seed % 7);
        return Transform.rotate(
          angle: ((seed % 7) - 3) * 0.025,
          child: AppTappable(
            onTap: () => widget.onToggle(emoji),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 7.0 + (seed % 3), vertical: 3),
              decoration: BoxDecoration(
                color: isMine
                    ? const Color(0xFF00B09B).withValues(alpha: 0.13)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: isMine
                      ? const Color(0xFF00B09B).withValues(alpha: 0.4)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji,
                      style: TextStyle(fontSize: emojiFs, height: 1)),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMine
                          ? const Color(0xFF00796B)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  final EventPollOption option;
  final int votes;
  final int total;
  final bool isSelected;
  final VoidCallback? onTap;
  final Map<String, int> reactions;
  final Set<String> myReactionEmojis;
  final void Function(String emoji) onReact;
  final void Function(String emoji) onUnreact;

  const _PollOptionRow({
    super.key,
    required this.option,
    required this.votes,
    required this.total,
    required this.isSelected,
    required this.onTap,
    required this.reactions,
    required this.myReactionEmojis,
    required this.onReact,
    required this.onUnreact,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? votes / total : 0.0;
    final pctLabel = '${(pct * 100).round()}%';

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showEmojiPickerSheet(
        context,
        myEmojis: myReactionEmojis,
        onReact: onReact,
        onUnreact: onUnreact,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00B09B).withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00B09B).withValues(alpha: 0.45)
                : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Gradient check circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF00B09B), Color(0xFF96C93D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: isSelected
                          ? null
                          : Border.all(
                              color: Colors.grey.shade300, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Option text
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color:
                            isSelected ? const Color(0xFF00796B) : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Percentage badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF00B09B), Color(0xFF96C93D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pctLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Gradient progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(color: Colors.grey.shade100),
                      FractionallySizedBox(
                        widthFactor: pct,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSelected
                                  ? const [
                                      Color(0xFF00B09B),
                                      Color(0xFF96C93D)
                                    ]
                                  : [
                                      Colors.grey.shade300,
                                      Colors.grey.shade300
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ReactionPills(
                    reactions: reactions,
                    myEmojis: myReactionEmojis,
                    onToggle: (emoji) {
                      if (myReactionEmojis.contains(emoji)) {
                        onUnreact(emoji);
                      } else {
                        onReact(emoji);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantPollOptionRow extends StatelessWidget {
  final EventPollOption option;
  final int votes;
  final bool isSelected;
  final VoidCallback? onTap;
  final Map<String, int> reactions;
  final Set<String> myReactionEmojis;
  final void Function(String emoji) onReact;
  final void Function(String emoji) onUnreact;

  const _RestaurantPollOptionRow({
    super.key,
    required this.option,
    required this.votes,
    required this.isSelected,
    required this.onTap,
    required this.reactions,
    required this.myReactionEmojis,
    required this.onReact,
    required this.onUnreact,
  });

  @override
  Widget build(BuildContext context) {
    final meta = option.placeMetadata;
    final photoRef = meta?['photo_ref'] as String?;
    final photoUrl = photoRef != null
        ? 'https://places.googleapis.com/v1/$photoRef/media'
            '?maxWidthPx=200&key=$kGooglePlacesApiKey'
        : null;
    final address = meta?['address'] as String?;
    final primaryType = meta?['primary_type'] as String?;
    final foodEmoji = _foodEmojiFor(primaryType, option.text);
    final rating = (meta?['rating'] as num?)?.toDouble();

    return GestureDetector(
      onLongPress: () => _showEmojiPickerSheet(
        context,
        myEmojis: myReactionEmojis,
        onReact: onReact,
        onUnreact: onUnreact,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.45)
                : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Left: thumbnail + info → opens detail sheet.
                Expanded(
                  child: AppTappable(
                    onTap: () => _showRestaurantDetail(
                      context,
                      name: option.text,
                      address: address ?? '',
                      rating: rating,
                      priceLevel: meta?['price_level'] as int?,
                      photoRefs: _photoRefsFromMetadata(meta),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 72,
                            child: photoUrl != null
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: Colors.grey[100],
                                      child: const Icon(Icons.restaurant,
                                          size: 24, color: Colors.black12),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[100],
                                    child: const Icon(Icons.restaurant,
                                        size: 24, color: Colors.black12),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (address != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      address,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (rating != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            size: 12, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Right: vote toggle — gradient circle, easy tap target.
                AppTappable(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Always use gradient so BoxDecoration.lerp stays structurally identical.
                        gradient: LinearGradient(
                          colors: isSelected
                              ? const [Color(0xFF667EEA), Color(0xFF764BA2)]
                              : [
                                  Colors.grey.shade100,
                                  Colors.grey.shade200
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        // Always include a shadow so lerp never hits a null→list transition.
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0xFF667EEA).withValues(alpha: 0.4)
                                : Colors.transparent,
                            blurRadius: isSelected ? 10 : 1,
                            offset: isSelected
                                ? const Offset(0, 4)
                                : Offset.zero,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$votes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(foodEmoji,
                              style:
                                  const TextStyle(fontSize: 18, height: 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _ReactionPills(
                  reactions: reactions,
                  myEmojis: myReactionEmojis,
                  onToggle: (emoji) {
                    if (myReactionEmojis.contains(emoji)) {
                      onUnreact(emoji);
                    } else {
                      onReact(emoji);
                    }
                  },
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

// ── Cravings tab (Quick Bites only) ──────────────────────────────────────────

class _FoodEmojiBubble extends StatelessWidget {
  final String emoji;

  const _FoodEmojiBubble(this.emoji);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 20)),
    );
  }
}

class _CravingsTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;

  const _CravingsTab({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<_CravingsTab> createState() => _CravingsTabState();
}

class _CravingsTabState extends State<_CravingsTab> {
  final _keywordCtrl = TextEditingController();
  List<RestaurantSuggestion> _results = [];
  bool _loading = false;
  String? _error;
  String? _restaurantPollId;

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _keywordCtrl.text.trim();
    if (q.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final svc = TripPlacesService(kGooglePlacesApiKey);
      final results = await svc.searchRestaurants(
        q,
        lat: widget.event.locationLat,
        lng: widget.event.locationLng,
      );
      setState(() { _results = results; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pitch(RestaurantSuggestion r, AppLocalizations l10n) async {
    final provider = context.read<EventProvider>();
    // Validate cached poll ID against live polls.
    if (_restaurantPollId != null) {
      final livePollIds = provider.pollsFor(widget.event.id)
          .map((p) => p.id).toSet();
      if (!livePollIds.contains(_restaurantPollId)) {
        _restaurantPollId = null;
      }
    }
    // Derive current poll ID from live state if not cached.
    _restaurantPollId ??= provider.pollsFor(widget.event.id)
        .where((p) => p.isRestaurantPoll)
        .firstOrNull
        ?.id;

    final metadata = {
      'place_id': r.placeId,
      'name': r.name,
      'address': r.address,
      if (r.rating != null) 'rating': r.rating,
      if (r.priceLevel != null) 'price_level': r.priceLevel,
      if (r.primaryType != null) 'primary_type': r.primaryType,
      if (r.photoRefs.isNotEmpty) 'photo_ref': r.photoRefs.first,
      if (r.photoRefs.isNotEmpty) 'photo_refs': r.photoRefs,
    };
    try {
      _restaurantPollId = await provider.pitchRestaurantOption(
        widget.event.id,
        r.name,
        metadata,
        l10n.cravingsTab,
        existingPollId: _restaurantPollId,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final existingPitchedIds = context.watch<EventProvider>()
        .pollsFor(widget.event.id)
        .where((p) => p.isRestaurantPoll)
        .firstOrNull
        ?.options
        .map((o) => o.placeMetadata?['place_id'] as String?)
        .whereType<String>()
        .toSet() ?? {};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Header card.
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  _FoodEmojiBubble('🍜'),
                  SizedBox(width: 8),
                  _FoodEmojiBubble('🌮'),
                  SizedBox(width: 8),
                  _FoodEmojiBubble('🍕'),
                  SizedBox(width: 8),
                  _FoodEmojiBubble('🍣'),
                  SizedBox(width: 8),
                  _FoodEmojiBubble('🥗'),
                  SizedBox(width: 8),
                  _FoodEmojiBubble('🍔'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.cravingsPrompt,
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF5D4037)),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.cravingsPrivacyNote,
                style: TextStyle(fontSize: 12, color: Colors.brown[400]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Keyword input.
        TextField(
          controller: _keywordCtrl,
          decoration: InputDecoration(
            hintText: l10n.cravingsHint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 10),
        // Full-width search button — avoids Row + ElevatedButton in unbounded-width context.
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _search,
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search_rounded, size: 18),
            label: Text(l10n.cravingsFindButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        if (!_loading && _results.isEmpty && _keywordCtrl.text.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(l10n.cravingsEmpty,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ),
          ),
        for (final r in _results)
          _CravingResultCard(
            restaurant: r,
            isPitched: existingPitchedIds.contains(r.placeId),
            onPitch: () => _pitch(r, l10n),
            l10n: l10n,
          ),
      ],
    );
  }
}

class _CravingResultCard extends StatefulWidget {
  final RestaurantSuggestion restaurant;
  final bool isPitched;
  final VoidCallback onPitch;
  final AppLocalizations l10n;

  const _CravingResultCard({
    required this.restaurant,
    required this.isPitched,
    required this.onPitch,
    required this.l10n,
  });

  @override
  State<_CravingResultCard> createState() => _CravingResultCardState();
}

class _CravingResultCardState extends State<_CravingResultCard> {
  bool _pitching = false;

  Future<void> _handlePitch() async {
    if (_pitching || widget.isPitched) return;
    setState(() => _pitching = true);
    try {
      widget.onPitch();
      await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) setState(() => _pitching = false);
    }
  }

  String _priceLabel(int? level) {
    if (level == null) return '';
    return '\$' * level;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final photoUrl = r.photoRef != null
        ? 'https://places.googleapis.com/v1/${r.photoRef}/media'
            '?maxWidthPx=600&key=$kGooglePlacesApiKey'
        : null;

    return AppTappable(
      onTap: () => _showRestaurantDetail(
        context,
        name: r.name,
        address: r.address,
        rating: r.rating,
        priceLevel: r.priceLevel,
        photoRefs: r.photoRefs,
        isPitched: widget.isPitched,
        onPitch: widget.isPitched ? null : widget.onPitch,
      ),
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoUrl != null)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: Icon(Icons.restaurant, size: 36, color: Colors.black12),
                        ),
                      ),
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey[100],
                  child: const Center(
                    child: Icon(Icons.restaurant, size: 36, color: Colors.black12),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(r.address,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (r.rating != null) ...[
                      const Icon(Icons.star_rounded, size: 15, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(r.rating!.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 10),
                    ],
                    if (r.priceLevel != null)
                      Text(_priceLabel(r.priceLevel),
                          style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.w600)),
                    const Spacer(),
                    widget.isPitched
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                              const SizedBox(width: 4),
                              Text(widget.l10n.cravingsPitched,
                                  style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.w500)),
                            ],
                          )
                        : OutlinedButton.icon(
                            onPressed: _pitching ? null : _handlePitch,
                            icon: _pitching
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_outlined, size: 14),
                            label: Text(widget.l10n.cravingsPitchButton,
                                style: const TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ), // Card
    ); // AppTappable
  }
}

// ── Restaurant detail sheet ───────────────────────────────────────────────────

List<String> _photoRefsFromMetadata(Map<String, dynamic>? meta) {
  if (meta == null) return const [];
  final refs = meta['photo_refs'];
  if (refs is List) return refs.cast<String>();
  final single = meta['photo_ref'] as String?;
  return single != null ? [single] : const [];
}

/// Maps restaurant type/name to a naturally-coloured emoji.
/// BBQ/steak is checked before Japanese/Korean to avoid misclassifying "Wagyu BBQ".
String _foodEmojiFor(String? primaryType, String name) {
  final t = (primaryType ?? '').toLowerCase();
  final n = name.toLowerCase();
  bool m(List<String> needles) => needles.any(t.contains) || needles.any(n.contains);

  // Sushi first (before Japanese)
  if (m(['sushi', 'omakase', 'nigiri', 'maki', 'temaki', 'chirashi']))          return '🍣';
  // Seafood
  if (m(['seafood', 'oyster', 'lobster', 'crab', 'shrimp', 'prawn', 'poke',
          'ceviche', 'clam', 'mussel', 'scallop'])) { return '🦞'; }
  // BBQ / steak before Korean/Japanese (wagyu trap)
  if (m(['steak', 'barbecue', 'smokehouse', 'steakhouse', 'bbq', 'brisket',
          'ribs', 'churrasco', 'wagyu', 'yakiniku', 'limitless', 'smoked meat'])) { return '🥩'; }
  // Ramen / noodles (before Japanese)
  if (m(['ramen', 'noodle', 'pho', 'udon', 'soba', 'pad thai', 'tom yum',
          'banh mi', 'viet'])) { return '🍜'; }
  // Japanese
  if (m(['japanese', 'izakaya', 'yakitori', 'tonkatsu', 'tempura', 'teppanyaki'])) return '🍱';
  // Korean
  if (m(['korean', 'kbbq', 'bibimbap', 'bulgogi', 'kimchi', 'galbi']))           return '🥢';
  // Chinese / dim sum / hot pot
  if (m(['chinese', 'dim_sum', 'dim sum', 'hot_pot', 'hot pot', 'cantonese',
          'szechuan', 'taiwanese', 'wok', 'dumpling', 'bao'])) { return '🥟'; }
  // Pizza
  if (m(['pizza', 'pizzeria', 'neapolitan']))                                     return '🍕';
  // Pasta / Italian
  if (m(['italian', 'pasta', 'trattoria', 'risotto', 'carbonara']))              return '🍝';
  // Burger
  if (m(['burger', 'hamburger', 'smash', 'patty', 'cheeseburger']))              return '🍔';
  // Fast food
  if (m(['fast_food', 'mcdonald', 'kfc', 'chick-fil']))                          return '🍟';
  // Mexican
  if (m(['mexican', 'tex_mex', 'taco', 'burrito', 'quesadilla', 'taqueria',
          'tamale'])) { return '🌮'; }
  // Indian
  if (m(['indian', 'south_asian', 'curry', 'tandoor', 'biryani', 'masala',
          'tikka'])) { return '🍛'; }
  // Middle Eastern / kebab
  if (m(['middle_eastern', 'kebab', 'turkish', 'lebanese', 'persian', 'israeli',
          'falafel', 'shawarma', 'hummus', 'halal', 'gyro'])) { return '🥙'; }
  // Mediterranean / Greek
  if (m(['mediterranean', 'greek', 'spanish', 'tapas', 'paella', 'tzatziki']))   return '🫒';
  // French
  if (m(['french', 'bistro', 'brasserie', 'crepe']))                             return '🥐';
  // Breakfast / brunch
  if (m(['breakfast', 'brunch', 'pancake', 'waffle', 'omelette']))               return '🍳';
  // Cafe / coffee
  if (m(['cafe', 'coffee_shop', 'coffee', 'espresso', 'latte', 'starbucks']))    return '☕';
  // Bakery
  if (m(['bakery', 'pastry', 'croissant', 'boulangerie', 'bread']))              return '🥖';
  // Dessert / sweets
  if (m(['dessert', 'ice_cream', 'sweet', 'donut', 'ice cream', 'gelato',
          'boba', 'bubble tea', 'mochi'])) { return '🍦'; }
  // Wine
  if (m(['wine_bar', 'winery', 'wine bar', 'vineyard']))                         return '🍷';
  // Cocktail bar
  if (m(['cocktail_bar', 'lounge', 'night_club', 'cocktail', 'speakeasy']))      return '🍸';
  // Pub / bar / brewery
  if (m(['bar', 'pub', 'brewery', 'gastropub', 'izakaya', 'beer', 'taproom']))   return '🍺';
  // Vegan / salad
  if (m(['vegetarian', 'vegan', 'health_food', 'plant-based', 'salad',
          'juice bar', 'smoothie'])) { return '🥗'; }
  // Sandwich / deli
  if (m(['sandwich', 'deli', 'sub', 'panini']))                                  return '🥪';

  return '🍽️';
}



void _showRestaurantDetail(
  BuildContext context, {
  required String name,
  required String address,
  required double? rating,
  required int? priceLevel,
  required List<String> photoRefs,
  VoidCallback? onPitch,
  bool isPitched = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RestaurantDetailSheet(
      name: name,
      address: address,
      rating: rating,
      priceLevel: priceLevel,
      photoRefs: photoRefs,
      onPitch: onPitch,
      isPitched: isPitched,
    ),
  );
}

class _RestaurantDetailSheet extends StatefulWidget {
  final String name;
  final String address;
  final double? rating;
  final int? priceLevel;
  final List<String> photoRefs;
  final VoidCallback? onPitch;
  final bool isPitched;

  const _RestaurantDetailSheet({
    required this.name,
    required this.address,
    required this.rating,
    required this.priceLevel,
    required this.photoRefs,
    required this.onPitch,
    required this.isPitched,
  });

  @override
  State<_RestaurantDetailSheet> createState() => _RestaurantDetailSheetState();
}

class _RestaurantDetailSheetState extends State<_RestaurantDetailSheet> {
  final _pageCtrl = PageController();
  int _page = 0;
  String? _yelpUrl;
  bool _yelpLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchYelpUrl();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchYelpUrl() async {
    if (kYelpApiKey.contains('REPLACE_ME')) {
      if (mounted) setState(() => _yelpLoading = false);
      return;
    }
    try {
      final uri = Uri.https('api.yelp.com', '/v3/businesses/search', {
        'term': widget.name,
        'location': widget.address,
        'limit': '1',
      });
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $kYelpApiKey'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final businesses = data['businesses'] as List?;
        if (businesses != null && businesses.isNotEmpty) {
          _yelpUrl = (businesses.first as Map<String, dynamic>)['url'] as String?;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _yelpLoading = false);
  }

  Future<void> _openYelp() async {
    final raw = _yelpUrl;
    final uri = raw != null
        ? Uri.parse(raw)
        : Uri.https('www.yelp.com', '/search', {
            'find_desc': widget.name,
            'find_loc': widget.address,
          });
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _photoUrl(String ref) =>
      'https://places.googleapis.com/v1/$ref/media'
      '?maxWidthPx=800&key=$kGooglePlacesApiKey';

  String _priceLabel(int? level) =>
      level != null ? '\$' * level : '';

  @override
  Widget build(BuildContext context) {
    final hasPhotos = widget.photoRefs.isNotEmpty;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // photo carousel
            if (hasPhotos) ...[
              SizedBox(
                height: 220,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: widget.photoRefs.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => Image.network(
                    _photoUrl(widget.photoRefs[i]),
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, p) => p == null
                        ? child
                        : Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.grey[100],
                      child: const Icon(Icons.restaurant,
                          size: 48, color: Colors.black12),
                    ),
                  ),
                ),
              ),
              if (widget.photoRefs.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.photoRefs.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _page == i ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _page == i
                            ? AppTheme.primary
                            : onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ] else
              Container(
                height: 120,
                color: Colors.grey[100],
                child: const Center(
                  child: Icon(Icons.restaurant, size: 48, color: Colors.black12),
                ),
              ),
            // info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (widget.rating != null) ...[
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < widget.rating!.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (widget.priceLevel != null)
                        Text(
                          _priceLabel(widget.priceLevel),
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.address,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _yelpLoading ? null : _openYelp,
                      icon: _yelpLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(_yelpLoading ? 'Finding on Yelp…' : 'View on Yelp'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (widget.onPitch != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.isPitched
                            ? null
                            : () {
                                Navigator.pop(context);
                                widget.onPitch!();
                              },
                        icon: widget.isPitched
                            ? const Icon(Icons.check_circle, size: 16)
                            : const Icon(Icons.send_outlined, size: 16),
                        label: Text(widget.isPitched
                            ? 'Added to group vote!'
                            : 'Pitch to group'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isPitched
                              ? Colors.green[600]
                              : AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

    // Non-trip: same rich tile design as trip members list.
    final sortedGuests = [...event.guests]
      ..sort((a, b) {
        if (a.role == 'organizer') return -1;
        if (b.role == 'organizer') return 1;
        return 0;
      });

    return Stack(
      children: [
        sortedGuests.isEmpty
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
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: sortedGuests.length,
                itemBuilder: (_, i) {
                  final g = sortedGuests[i];
                  final isMe = g.userId != null &&
                      g.userId == widget.authUid;
                  final canResend = widget.isOrganizer &&
                      g.status == 'pending' &&
                      g.userId != null &&
                      !isMe;
                  final hasEmail = g.email != null &&
                      g.email!.isNotEmpty &&
                      !isMe;
                  final hasAvatar =
                      g.avatarUrl != null && g.avatarUrl!.isNotEmpty;

                  String? inviterLabel;
                  if (g.invitedBy != null) {
                    inviterLabel = g.invitedBy == widget.authUid
                        ? l10n.invitedBy(l10n.you)
                        : l10n.invitedBy(
                            event.guests
                                    .where((x) => x.userId == g.invitedBy)
                                    .firstOrNull
                                    ?.displayName ??
                                '');
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: g.role == 'organizer'
                          ? AppTheme.primary
                          : Colors.grey[200],
                      backgroundImage:
                          hasAvatar ? NetworkImage(g.avatarUrl!) : null,
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
                            const SizedBox(width: 6),
                            _StatusChip(
                              label: switch (g.status) {
                                'pending' => l10n.invitePending,
                                'declined' => l10n.inviteDeclined,
                                'left' => l10n.memberLeft,
                                'maybe' => l10n.rsvpMaybe,
                                _ => l10n.inviteAccepted,
                              },
                              color: switch (g.status) {
                                'pending' => Colors.orange,
                                'declined' => AppTheme.danger,
                                'left' => Colors.grey,
                                'maybe' => Colors.amber,
                                _ => Colors.green,
                              },
                            ),
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
                                  icon: const Icon(Icons.send_outlined),
                                  iconSize: 20,
                                  onPressed: () => _resend(g),
                                ),
                              )
                        : null,
                    dense: true,
                    isThreeLine: hasEmail || inviterLabel != null,
                  );
                },
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
                    authUid: authUid,
                    onReact: (emoji) =>
                        context.read<EventChatProvider>().reactToMessage(msg.id, emoji),
                    onUnreact: (reactionId) =>
                        context.read<EventChatProvider>().unreactToMessage(msg.id, reactionId),
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
  final String? authUid;
  final void Function(String emoji) onReact;
  final void Function(String reactionId) onUnreact;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.authUid,
    required this.onReact,
    required this.onUnreact,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        msg.senderAvatarUrl != null && msg.senderAvatarUrl!.isNotEmpty;
    final reactionCounts = msg.reactionCounts;
    final myEmojis =
        authUid != null ? msg.myReactionEmojis(authUid!) : <String>{};

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
                GestureDetector(
                  onLongPress: () => _showEmojiPickerSheet(
                    context,
                    myEmojis: myEmojis,
                    maxReactions: 1,
                    onReact: onReact,
                    onUnreact: (emoji) {
                      final reaction = msg.reactions.where(
                          (r) => r.userId == authUid && r.emoji == emoji).firstOrNull;
                      if (reaction != null) onUnreact(reaction.id);
                    },
                  ),
                  child: Container(
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
                ),
                if (reactionCounts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _ReactionPills(
                      reactions: reactionCounts,
                      myEmojis: myEmojis,
                      onToggle: (emoji) {
                        if (myEmojis.contains(emoji)) {
                          final reaction = msg.reactions.where(
                              (r) => r.userId == authUid && r.emoji == emoji).firstOrNull;
                          if (reaction != null) onUnreact(reaction.id);
                        } else {
                          onReact(emoji);
                        }
                      },
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

// ── Birthday hero card ────────────────────────────────────────────────────────

class _BirthdayHeroCard extends StatelessWidget {
  final Event event;
  const _BirthdayHeroCard({required this.event});

  String _countdown(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = event.startAt.toLocal().difference(now);
    if (diff.isNegative || diff.inHours < 1) return l10n.birthdayToday;
    if (diff.inDays >= 1) return l10n.birthdayCountdownDays(diff.inDays);
    return l10n.birthdayCountdownHours(diff.inHours);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = event.honoreeDisplayName;
    final age = event.honoreeAge;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFAD1457), Color(0xFFE91E63), Color(0xFFFF8A65)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎂', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name != null
                      ? l10n.birthdayHeroTitle(name)
                      : l10n.eventTypeBirthday,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (age != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.turningAge(age),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _countdown(context),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Celebrate tab (Birthday: Activity Vote + Cake Vote) ──────────────────────

class _CelebrateTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final List<EventPoll> polls;

  const _CelebrateTab({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.polls,
  });

  @override
  State<_CelebrateTab> createState() => _CelebrateTabState();
}

class _CelebrateTabState extends State<_CelebrateTab> {
  final _activityCtrl = TextEditingController();
  final _cakeCtrl = TextEditingController();

  static const _kActivityPresets = [
    '🎮 Games night',
    '🎤 Karaoke',
    '🎬 Movie marathon',
    '🎨 Paint & sip',
    '🔐 Escape room',
    '🍸 Bar crawl',
    '🍕 Dinner out',
    '🎳 Bowling',
  ];

  static const _kCakePresets = [
    '🍫 Chocolate',
    '🍋 Lemon drizzle',
    '🍓 Strawberry',
    '🎂 Red velvet',
    '🍦 Vanilla cream',
    '🥜 Peanut butter',
  ];

  @override
  void dispose() {
    _activityCtrl.dispose();
    _cakeCtrl.dispose();
    super.dispose();
  }

  EventPoll? get _activityPoll => widget.polls
      .where((p) => p.pollType == 'activity')
      .firstOrNull;

  EventPoll? get _cakePoll => widget.polls
      .where((p) => p.pollType == 'cake')
      .firstOrNull;

  String get _honoreeName =>
      widget.event.honoreeDisplayName ?? widget.event.title;

  Future<void> _addActivityOption(String text) async {
    if (text.trim().isEmpty) return;
    final provider = context.read<EventProvider>();
    final existing = _activityPoll;
    if (existing != null) {
      await provider.addPollOption(existing.id, widget.event.id, text.trim());
    } else {
      await provider.createPoll(
        widget.event.id,
        AppLocalizations.of(context).activityVoteTitle(_honoreeName),
        [text.trim()],
        pollType: 'activity',
      );
    }
    _activityCtrl.clear();
  }

  Future<void> _addCakeOption(String text) async {
    if (text.trim().isEmpty) return;
    final provider = context.read<EventProvider>();
    final existing = _cakePoll;
    if (existing != null) {
      await provider.addPollOption(existing.id, widget.event.id, text.trim());
    } else {
      await provider.createPoll(
        widget.event.id,
        AppLocalizations.of(context).cakeVoteTitle(_honoreeName),
        [text.trim()],
        pollType: 'cake',
      );
    }
    _cakeCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activityPoll = _activityPoll;
    final cakePoll = _cakePoll;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // ── Activity Vote ────────────────────────────────────────────────────
        _BirthdaySectionHeader(
          emoji: '🎮',
          title: l10n.activityVoteTitle(_honoreeName),
          color: const Color(0xFF7B1FA2),
        ),
        const SizedBox(height: 12),
        if (activityPoll == null || activityPoll.options.isEmpty)
          _BirthdayEmptyNote(l10n.activityVoteEmpty)
        else
          ...activityPoll.options.map((opt) => _SimplePollOptionRow(
                option: opt,
                poll: activityPoll,
                authUid: widget.authUid,
                eventId: widget.event.id,
                accentColor: const Color(0xFF7B1FA2),
              )),
        const SizedBox(height: 8),
        if (widget.isOrganizer) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _kActivityPresets.map((preset) => ActionChip(
              label: Text(preset, style: const TextStyle(fontSize: 12)),
              onPressed: () => _addActivityOption(preset),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _activityCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.addActivityOption,
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _addActivityOption,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded,
                    color: Color(0xFF7B1FA2)),
                onPressed: () => _addActivityOption(_activityCtrl.text),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 16),

        // ── Cake Vote ────────────────────────────────────────────────────────
        _BirthdaySectionHeader(
          emoji: '🎂',
          title: l10n.cakeVoteTitle(_honoreeName),
          color: const Color(0xFFE91E63),
        ),
        const SizedBox(height: 12),
        if (cakePoll == null || cakePoll.options.isEmpty)
          _BirthdayEmptyNote(l10n.cakeVoteEmpty)
        else
          ...cakePoll.options.map((opt) => _SimplePollOptionRow(
                option: opt,
                poll: cakePoll,
                authUid: widget.authUid,
                eventId: widget.event.id,
                accentColor: const Color(0xFFE91E63),
              )),
        const SizedBox(height: 8),
        if (widget.isOrganizer) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _kCakePresets.map((preset) => ActionChip(
              label: Text(preset, style: const TextStyle(fontSize: 12)),
              onPressed: () => _addCakeOption(preset),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cakeCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.addCakeOption,
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _addCakeOption,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded,
                    color: Color(0xFFE91E63)),
                onPressed: () => _addCakeOption(_cakeCtrl.text),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Gifts tab (Birthday: Wishlist + Group Gift Pool) ─────────────────────────

class _GiftsTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;

  const _GiftsTab({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<_GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends State<_GiftsTab> {
  String get _honoreeName =>
      widget.event.honoreeDisplayName ?? widget.event.title;

  String get _myName {
    final me = widget.event.guests
        .where((g) => g.userId == widget.authUid)
        .firstOrNull;
    return me?.displayName ?? 'Me';
  }

  Future<void> _showAddWishlistItemSheet() async {
    final l10n = AppLocalizations.of(context);
    final labelCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.addWishlistItem,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: labelCtrl,
                autofocus: true,
                decoration:
                    InputDecoration(labelText: l10n.wishlistItemLabel),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(
                    labelText: l10n.wishlistPriceRange),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkCtrl,
                decoration:
                    InputDecoration(labelText: l10n.wishlistLink),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: l10n.save,
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty) return;
                  final label = labelCtrl.text.trim();
                  final price = priceCtrl.text.trim().isEmpty ? null : priceCtrl.text.trim();
                  final link = linkCtrl.text.trim().isEmpty ? null : linkCtrl.text.trim();
                  Navigator.pop(ctx);
                  context.read<EventProvider>().addWishlistItem(
                        eventId: widget.event.id,
                        label: label,
                        priceRange: price,
                        link: link,
                      );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    labelCtrl.dispose();
    priceCtrl.dispose();
    linkCtrl.dispose();
  }

  Future<void> _showCreateGiftPoolSheet() async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.createGiftPool,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration:
                    InputDecoration(labelText: l10n.giftPoolName),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration:
                    InputDecoration(labelText: l10n.giftPoolTarget),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: l10n.save,
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim());
                  if (nameCtrl.text.trim().isEmpty || amount == null || amount <= 0) return;
                  final name = nameCtrl.text.trim();
                  Navigator.pop(ctx);
                  context.read<EventProvider>().createGiftPool(
                        eventId: widget.event.id,
                        giftName: name,
                        targetAmount: amount,
                      );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    amountCtrl.dispose();
  }

  Future<void> _showAddPledgeSheet(EventGiftPool pool) async {
    final l10n = AppLocalizations.of(context);
    final amountCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.pledgeAmount,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.pledgeAmount,
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: l10n.addPledge,
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(ctx);
                  context.read<EventProvider>().addPledge(
                        poolId: pool.id,
                        eventId: widget.event.id,
                        amount: amount,
                        pledgerName: _myName,
                      );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    amountCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.read<EventProvider>();
    final wishlistItems = provider.wishlistFor(widget.event.id);
    final giftPool = provider.giftPoolFor(widget.event.id);
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // ── Wishlist ─────────────────────────────────────────────────────
            _BirthdaySectionHeader(
              emoji: '🎁',
              title: l10n.wishlistTitle(_honoreeName),
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(height: 12),
            if (wishlistItems.isEmpty)
              _BirthdayEmptyNote(l10n.wishlistEmpty(_honoreeName))
            else
              ...wishlistItems.map((item) => _WishlistItemRow(
                    item: item,
                    event: widget.event,
                    authUid: widget.authUid,
                    isOrganizer: widget.isOrganizer,
                    myName: _myName,
                  )),
            if (widget.isOrganizer) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addWishlistItem),
                onPressed: _showAddWishlistItemSheet,
              ),
            ],

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // ── Group Gift Pool ───────────────────────────────────────────────
            _BirthdaySectionHeader(
              emoji: '💸',
              title: l10n.giftPoolTitle,
              color: const Color(0xFF388E3C),
            ),
            const SizedBox(height: 12),
            if (giftPool == null)
              _BirthdayEmptyNote(l10n.giftPoolEmpty)
            else
              _GiftPoolCard(
                pool: giftPool,
                authUid: widget.authUid,
                isOrganizer: widget.isOrganizer,
                onAddPledge: () => _showAddPledgeSheet(giftPool),
                eventId: widget.event.id,
              ),
            if (widget.isOrganizer && giftPool == null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.createGiftPool),
                onPressed: _showCreateGiftPoolSheet,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _WishlistItemRow extends StatelessWidget {
  final EventWishlistItem item;
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final String myName;

  const _WishlistItemRow({
    required this.item,
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.myName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.read<EventProvider>();
    final isMyClaim = item.claimedBy == authUid;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: item.isReceived
            ? Border.all(
                color: const Color(0xFF388E3C).withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: ListTile(
        leading: Text(
          item.isReceived ? '✅' : (item.isClaimed ? '🎁' : '⬜'),
          style: const TextStyle(fontSize: 22),
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: item.isReceived ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.priceRange != null)
              Text(item.priceRange!,
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant)),
            if (item.isClaimed && isOrganizer)
              Text(l10n.itemClaimedBy(item.claimedByName ?? '?'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF388E3C)))
            else if (item.isClaimed && !isMyClaim)
              Text(l10n.itemClaimed,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF388E3C))),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'claim') {
              await provider.claimWishlistItem(item.id, event.id, myName);
            } else if (action == 'unclaim') {
              await provider.unclaimWishlistItem(item.id, event.id);
            } else if (action == 'received') {
              await provider.markWishlistItemReceived(
                  item.id, event.id, !item.isReceived);
            } else if (action == 'delete') {
              await provider.deleteWishlistItem(item.id, event.id);
            } else if (action == 'link') {
              if (item.link != null) {
                final uri = Uri.tryParse(item.link!);
                if (uri != null) launchUrl(uri);
              }
            }
          },
          itemBuilder: (_) => [
            if (!item.isClaimed)
              PopupMenuItem(value: 'claim', child: Text(l10n.claimItem)),
            if (isMyClaim || isOrganizer)
              PopupMenuItem(value: 'unclaim', child: Text(l10n.unclaimItem)),
            if (isOrganizer)
              PopupMenuItem(
                value: 'received',
                child: Text(l10n.markReceived),
              ),
            if (item.link != null)
              const PopupMenuItem(
                  value: 'link', child: Text('Open link 🔗')),
            if (isOrganizer || item.createdBy == authUid)
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppTheme.danger))),
          ],
        ),
      ),
    );
  }
}

class _GiftPoolCard extends StatelessWidget {
  final EventGiftPool pool;
  final String? authUid;
  final bool isOrganizer;
  final VoidCallback onAddPledge;
  final String eventId;

  const _GiftPoolCard({
    required this.pool,
    required this.authUid,
    required this.isOrganizer,
    required this.onAddPledge,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final progress = pool.targetAmount > 0
        ? (pool.totalPledged / pool.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final myPledge = pool.pledges
        .where((p) => p.pledgedBy == authUid)
        .firstOrNull;
    final fmt = NumberFormat.simpleCurrency();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💸', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pool.giftName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (isOrganizer)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.danger, size: 20),
                  onPressed: () =>
                      context.read<EventProvider>().deleteGiftPool(pool.id, eventId),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: colorScheme.outlineVariant,
              color: const Color(0xFF388E3C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.giftPoolProgress(
              fmt.format(pool.totalPledged),
              fmt.format(pool.targetAmount),
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            l10n.giftPoolContributors(pool.pledges.length),
            style: TextStyle(
                fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          if (myPledge != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${l10n.myPledge}: ${fmt.format(myPledge.amount)}',
                  style: const TextStyle(
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context
                      .read<EventProvider>()
                      .deletePledge(myPledge.id, eventId),
                  child: Text(l10n.removePledge,
                      style: const TextStyle(color: AppTheme.danger)),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            AppButton(
              label: l10n.addPledge,
              onPressed: onAddPledge,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Memories tab group (Birthday: Wishes | Predictions | Wall | Toasts) ───────

class _MemoriesTabGroup extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final List<EventWishlistItem> wishlistItems;
  final EventGiftPool? giftPool;
  final List<EventPrediction> predictions;
  final List<EventWish> wishes;
  final List<EventToast> toasts;

  const _MemoriesTabGroup({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.wishlistItems,
    required this.giftPool,
    required this.predictions,
    required this.wishes,
    required this.toasts,
  });

  @override
  State<_MemoriesTabGroup> createState() => _MemoriesTabGroupState();
}

class _MemoriesTabGroupState extends State<_MemoriesTabGroup>
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

  String get _honoreeName =>
      widget.event.honoreeDisplayName ?? widget.event.title;

  String get _myName {
    final me = widget.event.guests
        .where((g) => g.userId == widget.authUid)
        .firstOrNull;
    return me?.displayName ?? 'Me';
  }

  @override
  Widget build(BuildContext context) {
    // Guard against hot-reload leaving a stale controller with wrong length.
    if (_ctrl.length != 3) {
      _ctrl.dispose();
      _ctrl = TabController(length: 3, vsync: this);
    }

    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Material(
          color: colorScheme.surfaceContainerLow,
          child: TabBar(
            controller: _ctrl,
            tabAlignment: TabAlignment.fill,
            labelColor: const Color(0xFFE91E63),
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: const Color(0xFFE91E63),
            dividerColor: colorScheme.outlineVariant,
            labelStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              Tab(icon: const Text('🕯️', style: TextStyle(fontSize: 14)), text: l10n.wishesTab),
              Tab(icon: const Text('🔮', style: TextStyle(fontSize: 14)), text: l10n.predictionsTab),
              Tab(icon: const Text('🥂', style: TextStyle(fontSize: 14)), text: l10n.toastsTitle.split(' ').first),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _ctrl,
            children: [
              _WishesTab(
                event: widget.event,
                authUid: widget.authUid,
                isOrganizer: widget.isOrganizer,
                wishes: widget.wishes,
                myName: _myName,
                honoreeName: _honoreeName,
              ),
              _PredictionsTab(
                event: widget.event,
                authUid: widget.authUid,
                isOrganizer: widget.isOrganizer,
                predictions: widget.predictions,
                myName: _myName,
                honoreeName: _honoreeName,
              ),
              _ToastsTab(
                event: widget.event,
                authUid: widget.authUid,
                isOrganizer: widget.isOrganizer,
                toasts: widget.toasts,
                myName: _myName,
                honoreeName: _honoreeName,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Wishes tab ────────────────────────────────────────────────────────────────

class _WishesTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final List<EventWish> wishes;
  final String myName;
  final String honoreeName;

  const _WishesTab({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.wishes,
    required this.myName,
    required this.honoreeName,
  });

  @override
  State<_WishesTab> createState() => _WishesTabState();
}

class _WishesTabState extends State<_WishesTab> {
  bool _revealing = false;

  bool get _isRevealed => widget.event.wishesRevealedAt != null;
  bool get _alreadySentWish => widget.wishes
      .any((w) => w.submittedBy == widget.authUid);

  Future<void> _sendWish() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.addWish,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text(l10n.wishesSealed(widget.honoreeName),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: l10n.wishHint(widget.honoreeName),
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: l10n.addWish,
                onPressed: () {
                  if (ctrl.text.trim().isEmpty) return;
                  final text = ctrl.text.trim();
                  Navigator.pop(ctx);
                  context.read<EventProvider>().addWish(
                        eventId: widget.event.id,
                        wishText: text,
                        submitterName: widget.myName,
                      );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _revealWishes() async {
    setState(() => _revealing = true);
    try {
      await context.read<EventProvider>().revealWishes(widget.event.id);
    } finally {
      if (mounted) setState(() => _revealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final wishes = widget.wishes;

    if (!_isRevealed) {
      // Pre-reveal view
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('🕯️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              l10n.wishesTitle(widget.honoreeName),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.wishesSealed(widget.honoreeName),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.wishesHowItWorks,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${wishes.length} ${l10n.wishesTab.toLowerCase()} so far',
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 32),
            if (!_alreadySentWish)
              AppButton(
                label: l10n.addWish,
                onPressed: _sendWish,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Wish sent! 🎉',
                    style: TextStyle(
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.w600)),
              ),
            if (widget.isOrganizer) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: _revealing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('🕯️'),
                label: Text(l10n.blowOutCandles),
                onPressed: _revealing ? null : _revealWishes,
              ),
            ],
          ],
        ),
      );
    }

    // Post-reveal view
    return Stack(
      children: [
        wishes.isEmpty
            ? Center(child: Text(l10n.wishesEmpty))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: wishes.length,
                itemBuilder: (_, i) {
                  final wish = wishes[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE91E63).withValues(alpha: 0.08),
                          const Color(0xFFFF8A65).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFE91E63).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wish.wishText,
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '— ${wish.submittedByName}',
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _alreadySentWish ? null : _sendWish,
            backgroundColor: _alreadySentWish
                ? colorScheme.surfaceContainerLow
                : const Color(0xFFE91E63),
            label: Text(
              _alreadySentWish ? 'Wish sent! 🎉' : l10n.addWish,
              style: TextStyle(
                color: _alreadySentWish
                    ? colorScheme.onSurface
                    : Colors.white,
              ),
            ),
            icon: Icon(
              Icons.favorite_rounded,
              color: _alreadySentWish
                  ? colorScheme.onSurface
                  : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Predictions tab ───────────────────────────────────────────────────────────

class _PredictionsTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final List<EventPrediction> predictions;
  final String myName;
  final String honoreeName;

  const _PredictionsTab({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.predictions,
    required this.myName,
    required this.honoreeName,
  });

  @override
  State<_PredictionsTab> createState() => _PredictionsTabState();
}

class _PredictionsTabState extends State<_PredictionsTab> {
  bool _revealing = false;
  bool get _isRevealed => widget.event.predictionsRevealedAt != null;
  bool get _alreadySent =>
      widget.predictions.any((p) => p.submittedBy == widget.authUid);
  bool get _canReveal =>
      widget.isOrganizer &&
      !DateTime.now().isBefore(widget.event.startAt);

  Future<void> _addPrediction() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.addPrediction,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: l10n.predictionHint(widget.honoreeName),
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: l10n.addPrediction,
                onPressed: () {
                  if (ctrl.text.trim().isEmpty) return;
                  final text = ctrl.text.trim();
                  Navigator.pop(ctx);
                  context.read<EventProvider>().addPrediction(
                        eventId: widget.event.id,
                        predictionText: text,
                        submitterName: widget.myName,
                      );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _revealPredictions() async {
    setState(() => _revealing = true);
    try {
      await context
          .read<EventProvider>()
          .revealPredictions(widget.event.id);
    } finally {
      if (mounted) setState(() => _revealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final predictions = widget.predictions;

    return Stack(
      children: [
        if (!_isRevealed && predictions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔮', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    l10n.predictionsHowItWorks,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.predictionsEmpty(widget.honoreeName),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: predictions.length +
                (!_isRevealed ? 2 : 0),
            itemBuilder: (_, i) {
              if (!_isRevealed && i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.predictionsHowItWorks,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                );
              }
              if (!_isRevealed && i == 1) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.predictionsSealed(predictions.length),
                      style: const TextStyle(
                          color: Color(0xFF7B1FA2),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }
              final pred = predictions[_isRevealed ? i : i - 2];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🔮', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isRevealed ? pred.predictionText : '???',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        if ((pred.submittedBy == widget.authUid ||
                                widget.isOrganizer) &&
                            !_isRevealed)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.danger, size: 18),
                            onPressed: () => context
                                .read<EventProvider>()
                                .deletePrediction(pred.id, widget.event.id),
                          ),
                      ],
                    ),
                    if (_isRevealed) ...[
                      const SizedBox(height: 6),
                      Text(
                        '— ${pred.submittedByName}',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_canReveal && !_isRevealed)
                FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: _revealing ? null : _revealPredictions,
                  backgroundColor: const Color(0xFF7B1FA2),
                  label: Text(
                    l10n.revealPredictions,
                    style: const TextStyle(color: Colors.white),
                  ),
                  icon: _revealing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('🔮'),
                ),
              if (!_alreadySent) ...[
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: _addPrediction,
                  backgroundColor: const Color(0xFF7B1FA2).withValues(alpha: 0.85),
                  label: Text(l10n.addPrediction,
                      style: const TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Toasts tab ────────────────────────────────────────────────────────────────

class _ToastsTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final List<EventToast> toasts;
  final String myName;
  final String honoreeName;

  const _ToastsTab({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.toasts,
    required this.myName,
    required this.honoreeName,
  });

  @override
  State<_ToastsTab> createState() => _ToastsTabState();
}

class _ToastsTabState extends State<_ToastsTab> {
  Future<void> _addToast() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddToastSheet(
        event: widget.event,
        myName: widget.myName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final toasts = widget.toasts;
    final colorScheme = Theme.of(context).colorScheme;

    String toastEmoji(String type) => switch (type) {
          'funny' => '🔥',
          'poem' => '📜',
          _ => '🥂',
        };

    String toastLabel(String type) => switch (type) {
          'funny' => l10n.toastTypeFunny,
          'poem' => l10n.toastTypePoem,
          _ => l10n.toastTypeSweet,
        };

    return Stack(
      children: [
        toasts.isEmpty
            ? Center(
                child: _ToastCueCard(
                  honoreeName: widget.honoreeName,
                  onTap: _addToast,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: toasts.length,
                itemBuilder: (_, i) {
                  final toast = toasts[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(toastEmoji(toast.toastType),
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                toastLabel(toast.toastType),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFE91E63),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Spacer(),
                            if (toast.submittedBy == widget.authUid ||
                                widget.isOrganizer)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.danger, size: 18),
                                onPressed: () => context
                                    .read<EventProvider>()
                                    .deleteToast(toast.id, widget.event.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(toast.toastText,
                            style: const TextStyle(
                                fontSize: 15, height: 1.5)),
                        const SizedBox(height: 8),
                        Text(
                          '— ${toast.submittedByName}',
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  );
                },
              ),
        if (toasts.isNotEmpty)
          Positioned(
            bottom: 20,
            right: 16,
            child: AppTappable(
              onTap: _addToast,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFAD1457), Color(0xFFE91E63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🥂', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Birthday shared helpers ───────────────────────────────────────────────────

class _BirthdaySectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final Color color;

  const _BirthdaySectionHeader({
    required this.emoji,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ],
      );
}

class _BirthdayEmptyNote extends StatelessWidget {
  final String text;
  const _BirthdayEmptyNote(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13),
        ),
      );
}

class _SimplePollOptionRow extends StatelessWidget {
  final EventPollOption option;
  final EventPoll poll;
  final String? authUid;
  final String eventId;
  final Color accentColor;

  const _SimplePollOptionRow({
    required this.option,
    required this.poll,
    required this.authUid,
    required this.eventId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final votes = poll.votesFor(option.id);
    final total = poll.totalVotes;
    final fraction = total > 0 ? votes / total : 0.0;
    final myVote = poll.myVoteOptionId(authUid ?? '') == option.id;
    final colorScheme = Theme.of(context).colorScheme;

    return AppTappable(
      onTap: () {
        if (myVote) return;
        context.read<EventProvider>().vote(poll.id, option.id, eventId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: myVote
              ? Border.all(color: accentColor, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: myVote ? accentColor : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: colorScheme.outlineVariant,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  '$votes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    fontSize: 16,
                  ),
                ),
                if (myVote)
                  Icon(Icons.check_circle_rounded,
                      color: accentColor, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toast cue card (animated floating invitation) ─────────────────────────────

class _ToastCueCard extends StatefulWidget {
  final String honoreeName;
  final VoidCallback onTap;
  const _ToastCueCard({required this.honoreeName, required this.onTap});

  @override
  State<_ToastCueCard> createState() => _ToastCueCardState();
}

class _ToastCueCardState extends State<_ToastCueCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _float,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _float.value),
          child: child,
        ),
        child: Transform.rotate(
          angle: -0.04, // 2.3° tilt — looks like a card being handed to you
          child: Container(
            width: 260,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFAD1457), Color(0xFFE91E63), Color(0xFFFF8A80)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(4, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(-2, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Decorative dots like a real card
                Row(
                  children: List.generate(
                    3,
                    (i) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('🎙️', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  "It's your turn!",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Raise a glass\nfor ${widget.honoreeName} 🥂',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 20),
                // Dotted separator
                Row(
                  children: List.generate(
                    18,
                    (_) => Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('✍️', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 6),
                          Text(
                            'Tap to compose',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add Toast sheet (proper StatefulWidget to avoid cross-context issues) ─────

class _AddToastSheet extends StatefulWidget {
  final Event event;
  final String myName;
  const _AddToastSheet({required this.event, required this.myName});

  @override
  State<_AddToastSheet> createState() => _AddToastSheetState();
}

class _AddToastSheetState extends State<_AddToastSheet> {
  final _ctrl = TextEditingController();
  String _type = 'sweet';

  static const _kTypes = [
    ('sweet', '🥂', 'Sweet', Color(0xFFE91E63)),
    ('funny', '🔥', 'Funny', Color(0xFFFF6D00)),
    ('poem', '📜', 'Poem', Color(0xFF7B1FA2)),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accentColor =>
      _kTypes.firstWhere((t) => t.$1 == _type).$4;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final charCount = _ctrl.text.length;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentColor.withValues(alpha: 0.85),
                  _accentColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('🥂',
                    style: TextStyle(fontSize: 32)),
                const SizedBox(height: 6),
                const Text(
                  'Write a toast',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Say something sweet, funny, or poetic for ${widget.event.honoreeDisplayName ?? 'the birthday person'}!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type selector — big tappable cards
                Row(
                  children: _kTypes.map((t) {
                    final isSelected = _type == t.$1;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AppTappable(
                          onTap: () => setState(() => _type = t.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? t.$4.withValues(alpha: 0.12)
                                  : colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? t.$4
                                    : colorScheme.outlineVariant,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(t.$2,
                                    style:
                                        const TextStyle(fontSize: 22)),
                                const SizedBox(height: 4),
                                Text(
                                  t.$3,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? t.$4
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Text field
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _ctrl.text.isEmpty
                          ? colorScheme.outlineVariant
                          : _accentColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: switch (_type) {
                        'funny' => 'Make them laugh 😂',
                        'poem' => 'Roses are red... 🌹',
                        _ => 'From the heart... 💕',
                      },
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      counterStyle: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: AppTappable(
                    onTap: () {
                      if (_ctrl.text.trim().isEmpty) return;
                      final text = _ctrl.text.trim();
                      final type = _type;
                      Navigator.pop(context);
                      context.read<EventProvider>().addToast(
                            eventId: widget.event.id,
                            toastText: text,
                            toastType: type,
                            submitterName: widget.myName,
                          );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: _ctrl.text.trim().isEmpty
                            ? null
                            : LinearGradient(
                                colors: [
                                  _accentColor,
                                  _accentColor.withValues(alpha: 0.75),
                                ],
                              ),
                        color: _ctrl.text.trim().isEmpty
                            ? colorScheme.surfaceContainerLow
                            : null,
                        boxShadow: _ctrl.text.trim().isEmpty
                            ? null
                            : [
                                BoxShadow(
                                  color: _accentColor
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _kTypes
                                .firstWhere((t) => t.$1 == _type)
                                .$2,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            charCount == 0
                                ? 'Write something first'
                                : 'Send toast',
                            style: TextStyle(
                              color: charCount == 0
                                  ? colorScheme.onSurfaceVariant
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Signup Roster tab ─────────────────────────────────────────────────────────

class _SignupRosterTab extends StatefulWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;

  const _SignupRosterTab({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
  });

  @override
  State<_SignupRosterTab> createState() => _SignupRosterTabState();
}

class _SignupRosterTabState extends State<_SignupRosterTab> {
  bool _loadingUpcoming = true;
  bool _showPast = false;
  String? _error;
  // Track by session ID (stable across list refreshes).
  String? _expandedSessionId;

  @override
  void initState() {
    super.initState();
    // B9: tell the provider which event is active so Realtime callbacks
    // can skip notifyListeners() for unrelated events.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EventProvider>().watchEvent(widget.event.id);
    });
    _fetchUpcoming();
  }

  @override
  void dispose() {
    context.read<EventProvider>().watchEvent(null);
    super.dispose();
  }

  Future<void> _fetchUpcoming() async {
    try {
      await context.read<EventProvider>().fetchUpcomingSessions(widget.event.id);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loadingUpcoming = false;
          // Auto-expand only when there is exactly one upcoming session.
          // With multiple sessions the user should choose which to open.
          final upcoming = context
              .read<EventProvider>()
              .upcomingSessionsFor(widget.event.id);
          if (upcoming.length == 1) _expandedSessionId = upcoming.first.id;
        });
      }
    }
  }

  /// Returns deduplicated display names of confirmed event members for pre-add suggestions.
  List<String> _memberSuggestionNames() {
    const excluded = {'left', 'declined'};
    return widget.event.guests
        .where((g) => !excluded.contains(g.status) && g.displayName.isNotEmpty)
        .map((g) => g.displayName)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> _deleteSession(
      BuildContext context, EventSession session) async {
    try {
      await context
          .read<EventProvider>()
          .deleteSession(session.id, widget.event.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cloneSession(BuildContext context, EventSession source) async {
    final provider = context.read<EventProvider>();
    final suggestion = source.startAt.add(const Duration(days: 7));

    if (!context.mounted) return;
    final result = await showModalBottomSheet<_NewSessionConfig>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddSessionSheet(
        suggestion: suggestion,
        template: source,
        memberNames: _memberSuggestionNames(),
      ),
    );
    if (result == null || !context.mounted) return;
    await _applySessionConfig(context, provider, result);
  }

  Future<void> _addSession(BuildContext context) async {
    final provider = context.read<EventProvider>();
    final upcoming = provider.upcomingSessionsFor(widget.event.id);
    final past = provider.pastSessionsFor(widget.event.id);
    final allKnown = [...upcoming, ...past];
    allKnown.sort((a, b) => b.startAt.compareTo(a.startAt));
    final suggestion = allKnown.isNotEmpty
        ? allKnown.first.startAt.add(const Duration(days: 7))
        : widget.event.startAt.add(const Duration(days: 7));

    if (!context.mounted) return;
    final result = await showModalBottomSheet<_NewSessionConfig>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddSessionSheet(
        suggestion: suggestion,
        memberNames: _memberSuggestionNames(),
      ),
    );
    if (result == null || !context.mounted) return;
    await _applySessionConfig(context, provider, result);
  }

  /// Shared post-sheet logic for both _addSession and _cloneSession.
  Future<void> _applySessionConfig(
    BuildContext context,
    EventProvider provider,
    _NewSessionConfig result,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    // Read auth synchronously before any await.
    final auth = context.read<AuthProvider>();
    try {
      final session = await provider.addSession(
        widget.event.id,
        result.startAt,
        null,
        capacity: result.capacity,
        waitlistEnabled: result.waitlistEnabled,
        signupLockHours: result.signupLockHours,
        isPublic: result.isPublic,
        requiresApproval: result.requiresApproval,
      );

      final now = DateTime.now().toUtc().toIso8601String();
      // Signup order: organizer is #1 if autoAddSelf, pre-adds follow.
      int nextOrder = 1;

      if (result.autoAddSelf) {
        await provider.db.from('event_session_roster').insert({
          'session_id': session.id,
          'user_id': auth.userId,
          'display_name': auth.userName,

          'status': 'going',
          'signup_order': nextOrder++,
          'signed_up_at': now,
        });
      }

      for (final name in result.preAddNames) {
        await provider.db.from('event_session_roster').insert({
          'session_id': session.id,
          'display_name': name,
          'status': 'going',
          'signup_order': nextOrder++,
          'signed_up_at': now,
        });
      }

      if (result.autoAddSelf || result.preAddNames.isNotEmpty) {
        await provider.refreshSessionRoster(session.id);
      }
      if (mounted) setState(() => _expandedSessionId = session.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventProvider>();
    final upcoming = provider.upcomingSessionsFor(widget.event.id);
    final past = provider.pastSessionsFor(widget.event.id);
    final hasMoreUpcoming = provider.hasMoreUpcomingFor(widget.event.id);
    final hasMorePast = provider.hasMorePastFor(widget.event.id);

    if (_loadingUpcoming) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: AppTheme.danger)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(
          children: [
            const Text('📅', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                () {
                  final n = upcoming.length;
                  final label = hasMoreUpcoming ? '$n+' : '$n';
                  return '$label upcoming session${n == 1 && !hasMoreUpcoming ? '' : 's'}';
                }(),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.isOrganizer)
              AppTappable(
                onTap: () => _addSession(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Add session',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Upcoming sessions ─────────────────────────────────────────────
        if (upcoming.isEmpty)
          _EmptyState(
              emoji: '📋',
              message: widget.isOrganizer
                  ? 'No upcoming sessions — tap "Add session" to schedule one.'
                  : 'No upcoming sessions scheduled yet.')
        else
          ...upcoming.asMap().entries.map((e) => _SessionCard(
                key: ValueKey(e.value.id),
                session: e.value,
                event: widget.event,
                authUid: widget.authUid,
                isOrganizer: widget.isOrganizer,
                isExpanded: _expandedSessionId == e.value.id,
                position: e.key + 1,
                onToggle: () => setState(() => _expandedSessionId =
                    _expandedSessionId == e.value.id ? null : e.value.id),
                onClone: widget.isOrganizer
                    ? () => _cloneSession(context, e.value)
                    : null,
                onDelete: widget.isOrganizer
                    ? () => _deleteSession(context, e.value)
                    : null,
              )),

        // ── Past sessions ─────────────────────────────────────────────────
        const SizedBox(height: 20),
        _PastSessionsSection(
          event: widget.event,
          authUid: widget.authUid,
          isOrganizer: widget.isOrganizer,
          sessions: past,
          hasMore: hasMorePast,
          isVisible: _showPast,
          expandedSessionId: _expandedSessionId,
          onToggleVisible: () {
            setState(() => _showPast = !_showPast);
            if (!_showPast) return;
            if (past.isEmpty) {
              context.read<EventProvider>().fetchPastSessions(widget.event.id);
            }
          },
          onToggleSession: (id) => setState(() =>
              _expandedSessionId = _expandedSessionId == id ? null : id),
          onCloneSession: (session) => _cloneSession(context, session),
          onDeleteSession: widget.isOrganizer
              ? (session) => _deleteSession(context, session)
              : null,
          onLoadMore: () =>
              context.read<EventProvider>().loadMorePastSessions(widget.event.id),
        ),
      ],
    );
  }
}

// ── Past sessions section ─────────────────────────────────────────────────────

class _PastSessionsSection extends StatelessWidget {
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final List<EventSession> sessions;
  final bool hasMore;
  final bool isVisible;
  final String? expandedSessionId;
  final VoidCallback onToggleVisible;
  final void Function(String sessionId) onToggleSession;
  final void Function(EventSession) onCloneSession;
  final void Function(EventSession)? onDeleteSession;
  final VoidCallback onLoadMore;

  const _PastSessionsSection({
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.sessions,
    required this.hasMore,
    required this.isVisible,
    required this.expandedSessionId,
    required this.onToggleVisible,
    required this.onToggleSession,
    required this.onCloneSession,
    this.onDeleteSession,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTappable(
          onTap: onToggleVisible,
          child: Row(
            children: [
              Icon(
                isVisible
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                'Past sessions',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        if (isVisible) ...[
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No past sessions.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ),
            )
          else
            ...sessions.asMap().entries.map((e) => _SessionCard(
                  key: ValueKey(e.value.id),
                  session: e.value,
                  event: event,
                  authUid: authUid,
                  isOrganizer: isOrganizer,
                  isExpanded: expandedSessionId == e.value.id,
                  position: e.key + 1,
                  onToggle: () => onToggleSession(e.value.id),
                  onClone: isOrganizer ? () => onCloneSession(e.value) : null,
                  onDelete: onDeleteSession != null
                      ? () => onDeleteSession!(e.value)
                      : null,
                )),
          if (hasMore) ...[
            const SizedBox(height: 8),
            Center(
              child: AppTappable(
                onTap: onLoadMore,
                child: Text('Load more past sessions',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ── Session card (lazy roster loading) ───────────────────────────────────────

class _SessionCard extends StatefulWidget {
  final EventSession session;
  final Event event;
  final String? authUid;
  final bool isOrganizer;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onClone;
  final VoidCallback? onDelete;
  // B6: ordinal position in the sorted session list (1-based) for the info sheet.
  final int position;

  const _SessionCard({
    super.key,
    required this.session,
    required this.event,
    required this.authUid,
    required this.isOrganizer,
    required this.isExpanded,
    required this.onToggle,
    this.onClone,
    this.onDelete,
    this.position = 1,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard>
    with TickerProviderStateMixin {
  bool _rosterLoading = false;
  String? _cancellingId;       // roster entry id currently animating out
  AnimationController? _cancelCtrl;
  StreamSubscription<String>? _statusClearedSub;

  @override
  void didUpdateWidget(_SessionCard old) {
    super.didUpdateWidget(old);
    // Always refresh from DB when the card is expanded — avoids showing
    // stale cached data after server-side changes (migrations, other devices).
    if (widget.isExpanded && !old.isExpanded) {
      _loadRoster(forceRefresh: true);
    }
  }

  AnimationController? _pulseCtrl;
  Animation<double>? _pulseAnim;

  @override
  void initState() {
    super.initState();
    if (widget.isExpanded) _loadRoster();
    _initAnims();
    // Subscribe to direct status-cleared signals from the provider. Using a
    // stream + setState guarantees a rebuild even if notifyListeners() was
    // already processed and Flutter considers this widget clean.
    _statusClearedSub = context
        .read<EventProvider>()
        .sessionStatusCleared
        .where((id) => id == widget.session.id)
        .listen((_) {
      if (!mounted) return;
      setState(() {}); // force rebuild immediately
      _loadRoster(forceRefresh: true); // then sync fresh DB state
    });
  }

  void _initAnims() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.10, end: 0.30).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _statusClearedSub?.cancel();
    _pulseCtrl?.dispose();
    _cancelCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadRoster({bool forceRefresh = false}) async {
    final provider = context.read<EventProvider>();
    // On initial widget creation use cache if available (avoids redundant
    // fetches when the provider already has fresh data from a recent signup).
    // On every subsequent expand always go to the DB.
    if (!forceRefresh && provider.rosterFor(widget.session.id) != null) return;
    setState(() => _rosterLoading = true);
    try {
      await provider.refreshSessionRoster(widget.session.id);
    } finally {
      if (mounted) setState(() => _rosterLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('EEE, MMM d · h:mm a');
    final provider = context.watch<EventProvider>();
    final cap = widget.session.capacity;
    final going = widget.session.goingCount;
    final waitlisted = widget.session.waitlistCount;
    final isLocked = widget.session.isLocked;
    final hasEnded = widget.session.hasEnded;
    final fillFraction =
        cap != null && cap > 0 ? (going / cap).clamp(0.0, 1.0) : 0.0;

    // Roster is loaded on demand.
    // B11: cap displayed rows to avoid building hundreds of widgets eagerly.
    // TODO(perf): replace ReorderableListView with a SliverReorderableList
    // backed by a real scroll view for true O(visible) virtualization.
    const kMaxDisplayRows = 50;
    final roster = provider.rosterFor(widget.session.id);
    final confirmed =
        roster?.where((r) => r.status == 'going').toList() ?? [];
    final waitlist =
        roster?.where((r) => r.status == 'waitlisted').toList() ?? [];
    final pending =
        roster?.where((r) => r.status == 'pending_review').toList() ?? [];
    final myEntry = roster?.where((r) => r.userId == widget.authUid).firstOrNull;
    final hasMoreRoster = provider.hasMoreRosterFor(widget.session.id);
    final displayedConfirmed = confirmed.take(kMaxDisplayRows).toList();
    final hiddenConfirmed = confirmed.length - displayedConfirmed.length;
    final displayedWaitlist = waitlist.take(kMaxDisplayRows).toList();
    final hiddenWaitlist = waitlist.length - displayedWaitlist.length;

    final grad = _SessionEmojiBadge.gradientFor(widget.session);
    final accentColor = grad[0];
    final accentColor2 = grad[1];

    // Guard against hot-reload where initState may not have run on existing state.
    if (_pulseCtrl == null) _initAnims();
    final pulseAnim = _pulseAnim!;

    final card = AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: pulseAnim.value),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // ── Card background + content ─────────────────────────────────
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
        children: [
          // ── Header (always visible, counts from DB columns) ──────────────
          AppTappable(
            onTap: widget.onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SessionEmojiBadge(session: widget.session),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmt.format(widget.session.startAt.toLocal()),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              cap != null
                                  ? '$going / $cap spots'
                                  : '$going going${waitlisted > 0 ? '  ·  $waitlisted waiting' : ''}',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.session.isPublic && widget.isOrganizer)
                            _StatusChip(label: '🔒 Private', color: Colors.blueGrey),
                          if (isLocked)
                            _StatusChip(label: 'Locked', color: Colors.orange),
                          if (hasEnded)
                            _StatusChip(label: 'Ended', color: Colors.grey),
                          if (!hasEnded && !isLocked)
                            if (widget.isOrganizer) ...[
                              // Organizer chips: open spots + waitlist demand
                              if (cap != null && going < cap)
                                _StatusChip(
                                  label: '${cap - going} open',
                                  color: const Color(0xFF2E7D32),
                                ),
                              if (waitlisted > 0)
                                _StatusChip(
                                  label: '$waitlisted waiting',
                                  color: Colors.orange,
                                ),
                            ] else ...[
                              // Member chip: personal status
                              Builder(builder: (ctx) {
                                final my = ctx.watch<EventProvider>()
                                    .myStatusFor(widget.session.id);
                                if (my == null) return const SizedBox.shrink();
                                if (my.status == 'going') {
                                  return _StatusChip(
                                    label: '✓ Going',
                                    color: const Color(0xFF2E7D32),
                                  );
                                }
                                if (my.status == 'pending_review') {
                                  return const _StatusChip(
                                    label: '🔍 Pending',
                                    color: Color(0xFF6A1B9A),
                                  );
                                }
                                return _StatusChip(
                                  label: '⏳ #${my.order} wait',
                                  color: Colors.orange,
                                );
                              }),
                            ],
                          if (widget.isOrganizer && widget.onClone != null) ...[
                            const SizedBox(width: 2),
                            AppTappable(
                              onTap: widget.onClone,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ],
                          // B5: Pending-review badge — shown from DB column even
                          // before the roster is expanded; refined by loaded list.
                          if (widget.isOrganizer &&
                              (widget.session.pendingCount > 0 ||
                                  pending.isNotEmpty))
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF6A1B9A),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${pending.isNotEmpty ? pending.length : widget.session.pendingCount}',
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (cap != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fillFraction,
                        minHeight: 5,
                        backgroundColor:
                            const Color(0xFF2E7D32).withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fillFraction >= 1.0
                              ? Colors.redAccent
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expanded roster (loaded lazily on first expand) ──────────────
          if (widget.isExpanded) ...[
            Divider(
                height: 1,
                color: const Color(0xFF2E7D32).withValues(alpha: 0.12)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _rosterLoading || roster == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Confirmed list ────────────────────────────────
                        if (confirmed.isEmpty)
                          _EmptyState(emoji: '🪑', message: 'No one signed up yet.')
                        else if (widget.isOrganizer && !hasEnded)
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorderItem: (oldIdx, newIdx) {
                              final reordered =
                                  List<EventSessionRosterEntry>.from(displayedConfirmed);
                              reordered.insert(
                                  newIdx, reordered.removeAt(oldIdx));
                              context.read<EventProvider>().reorderSessionRoster(
                                    widget.event.id,
                                    widget.session.id,
                                    reordered.map((r) => r.id).toList(),
                                  );
                            },
                            children: displayedConfirmed.asMap().entries.map((e) =>
                                _SessionRosterRow(
                                  key: ValueKey(e.value.id),
                                  position: e.key + 1,
                                  index: e.key,
                                  entry: e.value,
                                  isOrganizer: true,
                                  showDragHandle: true,
                                  showAttendance: hasEnded,
                                  onDemote: widget.session.waitlistEnabled
                                      ? () async {
                                          try {
                                            await context
                                                .read<EventProvider>()
                                                .demoteSessionRosterEntry(
                                                    e.value.id,
                                                    widget.session.id,
                                                    widget.event.id);
                                          } catch (err) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content:
                                                        Text(err.toString())));
                                          }
                                        }
                                      : null,
                                  onRemove: () => _confirmRemoveEntry(
                                      context, e.value, l10n),
                                  onMarkAttendance: hasEnded
                                      ? (att) => context
                                          .read<EventProvider>()
                                          .markSessionAttendance(
                                              e.value.id,
                                              widget.session.id,
                                              widget.event.id,
                                              att)
                                      : null,
                                  onToggleConfirmed: !hasEnded
                                      ? (c) => context
                                          .read<EventProvider>()
                                          .toggleSessionConfirmed(
                                              e.value.id,
                                              widget.session.id,
                                              widget.event.id,
                                              c)
                                      : null,
                                )).toList(),
                          )
                        else
                          ...displayedConfirmed.asMap().entries.map((e) =>
                              _cancelAnimWrapper(
                                id: e.value.id,
                                child: _SessionRosterRow(
                                  key: ValueKey(e.value.id),
                                  position: e.key + 1,
                                  index: e.key,
                                  entry: e.value,
                                  isOrganizer: false,
                                  showAttendance: false,
                                ),
                              )),

                        // B11: hidden-row notice when capped at _kMaxDisplayRows.
                        if (hiddenConfirmed > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '+ $hiddenConfirmed more — load next page to see all',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ),

                        // ── Load more confirmed ──────────────────────────
                        if (hasMoreRoster) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: AppTappable(
                              onTap: () => context
                                  .read<EventProvider>()
                                  .loadMoreRoster(widget.session.id),
                              child: Text('Load more',
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],

                        // ── Waitlist ──────────────────────────────────────
                        if (widget.session.waitlistEnabled) ...[
                          const SizedBox(height: 12),
                          _WaitlistDivider(count: waitlist.length),
                          const SizedBox(height: 8),
                          if (waitlist.isEmpty)
                            _EmptyState(
                                emoji: '🎉',
                                message: 'Waitlist is empty — all good!')
                          else if (widget.isOrganizer && !hasEnded)
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              onReorderItem: (oldIdx, newIdx) {
                                final reordered =
                                    List<EventSessionRosterEntry>.from(
                                        displayedWaitlist);
                                reordered.insert(
                                    newIdx, reordered.removeAt(oldIdx));
                                context
                                    .read<EventProvider>()
                                    .reorderSessionRoster(
                                  widget.event.id,
                                  widget.session.id,
                                  reordered.map((r) => r.id).toList(),
                                  startOrder: 1,
                                );
                              },
                              children: displayedWaitlist.asMap().entries.map((e) =>
                                  _SessionRosterRow(
                                    key: ValueKey(e.value.id),
                                    position: e.key + 1,
                                    index: e.key,
                                    entry: e.value,
                                    isWaitlist: true,
                                    isOrganizer: true,
                                    showDragHandle: true,
                                    showAttendance: false,
                                    onPromote: (cap == null ||
                                            going < cap)
                                        ? () async {
                                            try {
                                              await context
                                                  .read<EventProvider>()
                                                  .promoteSessionRosterEntry(
                                                      e.value.id,
                                                      widget.session.id,
                                                      widget.event.id);
                                            } catch (err) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                  err
                                                          .toString()
                                                          .contains(
                                                              'session_full')
                                                      ? l10n.signupEventFull
                                                      : err.toString(),
                                                ),
                                              ));
                                            }
                                          }
                                        : null,
                                    onRemove: () => _confirmRemoveEntry(
                                        context, e.value, l10n),
                                  )).toList(),
                            )
                          else
                            ...displayedWaitlist.asMap().entries.map((e) =>
                                _cancelAnimWrapper(
                                  id: e.value.id,
                                  child: _SessionRosterRow(
                                    key: ValueKey(e.value.id),
                                    position: e.key + 1,
                                    index: e.key,
                                    entry: e.value,
                                    isWaitlist: true,
                                    isOrganizer: false,
                                    showAttendance: false,
                                  ),
                                )),
                          if (hiddenWaitlist > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '+ $hiddenWaitlist more in waitlist',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500]),
                              ),
                            ),
                        ],

                        // ── Pending Review (organizer only) ──────────────
                        if (widget.isOrganizer && pending.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(children: [
                            const Text('⏳', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 6),
                            Text(
                              'Pending Review (${pending.length})',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6A1B9A)),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          ...pending.map((entry) =>
                              _PendingReviewRow(
                                key: ValueKey(entry.id),
                                entry: entry,
                                onApprove: () async {
                                  try {
                                    await context
                                        .read<EventProvider>()
                                        .approveSessionRosterEntry(
                                            entry.id,
                                            widget.session.id,
                                            widget.event.id);
                                  } catch (err) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(err.toString())));
                                  }
                                },
                                onReject: () async {
                                  try {
                                    await context
                                        .read<EventProvider>()
                                        .rejectSessionRosterEntry(
                                            entry.id,
                                            widget.session.id,
                                            widget.event.id);
                                  } catch (err) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(err.toString())));
                                  }
                                },
                              )),
                        ],

                        // ── Current user CTA ──────────────────────────────
                        if (!hasEnded) ...[
                        const SizedBox(height: 16),
                        if (myEntry == null) ...[
                          if (isLocked)
                            _LockedBanner(message: l10n.signupLocked)
                          else if (widget.session.isFull &&
                              !widget.session.waitlistEnabled)
                            _LockedBanner(
                                message: l10n.signupEventFull,
                                color: AppTheme.danger)
                          else
                            _SignupCTAButton(
                              label: widget.session.isFull
                                  ? l10n.signupJoinWaitlist
                                  : (widget.session.requiresApproval &&
                                          !widget.isOrganizer)
                                      ? '🔍  Request to join'
                                      : '🎟️  ${l10n.signupClaimSpot}',
                              isWaitlist: widget.session.isFull,
                              onPressed: () => _signupForSession(context, l10n),
                            ),
                        ] else ...[
                          if (myEntry.status == 'pending_review')
                            _LockedBanner(
                              message: '🔍 Your request is pending organizer approval.',
                              color: const Color(0xFF6A1B9A),
                            )
                          else if (!isLocked)
                            _CancelSpotButton(
                              label: l10n.signupCancelSpot,
                              isWaitlist: myEntry.status == 'waitlisted',
                              onPressed: () => _cancelForSession(
                                  context, myEntry, l10n),
                            )
                          else
                            _LockedBanner(message: l10n.signupLockedMessage),
                        ],
                        ], // end if (!hasEnded)
                      ],
                    ),
            ),          // closes Padding
          ],            // closes isExpanded spread
        ],              // closes Column.children
        ),              // closes Column
        ),              // closes card background Container
            // ── Animated left border ────────────────────────────────────
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, snap) => Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accentColor.withValues(alpha: pulseAnim.value * 3.0),
                        accentColor.withValues(alpha: pulseAnim.value * 1.2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ── Animated right border ────────────────────────────────────
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, snap) => Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accentColor2.withValues(alpha: pulseAnim.value * 1.2),
                        accentColor2.withValues(alpha: pulseAnim.value * 3.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],            // closes Stack.children
        ),              // closes Stack / ClipRRect child
      ),                // closes ClipRRect
    );

    final cardWithLongPress = GestureDetector(
      onLongPress: () => _showSessionInfo(context),
      child: card,
    );

    if (widget.onDelete == null) return cardWithLongPress;

    return Slidable(
      key: ValueKey('slide-${widget.session.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.50,
        children: [
          SlidableAction(
            onPressed: (_) => _showSessionInfo(context),
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            icon: Icons.bar_chart_rounded,
            label: 'Info',
            borderRadius: BorderRadius.circular(14),
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(context),
            backgroundColor: Colors.red.shade400,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      child: cardWithLongPress,
    );
  }

  void _showSessionInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionInfoSheet(
        session: widget.session,
        position: widget.position,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text(
            'All signed-up members will be notified and the session will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true) widget.onDelete?.call();
  }

  Future<void> _signupForSession(
      BuildContext context, AppLocalizations l10n) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.push('/login');
      return;
    }
    final provider = context.read<EventProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final rows = await Supabase.instance.client.rpc('rsvp_session', params: {
        'p_invite_code': widget.session.inviteCode,
        'p_display_name': auth.userName,
      }) as List<dynamic>;
      if (rows.isNotEmpty && context.mounted) {
        final r = rows.first as Map<String, dynamic>;
        final status = r['rsvp_status'] as String?;
        final pos = r['signup_position'] as int? ?? 0;
        messenger.showSnackBar(SnackBar(
          content: Text(status == 'waitlisted'
              ? l10n.signupWaitlistPosition(pos)
              : status == 'pending_review'
                  ? 'Your request has been submitted — the organizer will review it.'
                  : l10n.signupConfirmedPosition(pos)),
        ));
      }
      // B12: background-refresh only — the Realtime INSERT handler already
      // patches the cache; awaiting here would cause a double round-trip.
      unawaited(provider.refreshSessionRoster(widget.session.id));
    } catch (e) {
      final msg = e.toString();
      messenger.showSnackBar(SnackBar(
        content: Text(msg.contains('signup_locked')
            ? l10n.signupLocked
            : msg.contains('already_signed_up')
                ? 'You are already signed up for this session.'
                : msg.contains('auth_required')
                    ? 'Please log in to sign up for sessions.'
                    : msg),
      ));
      // Roster may be stale — refresh so the correct state (cancel button) shows.
      if (msg.contains('already_signed_up')) {
        unawaited(provider.refreshSessionRoster(widget.session.id));
      }
    }
  }

  /// Wraps [child] with slide-right + fade + height-collapse when this entry
  /// is the one currently being cancelled.
  Widget _cancelAnimWrapper({required String id, required Widget child}) {
    final ctrl = _cancelCtrl;
    if (_cancellingId != id || ctrl == null) return child;

    final slide = Tween<Offset>(begin: Offset.zero, end: const Offset(1.5, 0))
        .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeIn));
    final fade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(
            parent: ctrl, curve: const Interval(0.0, 0.6)));
    final size = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(
            parent: ctrl, curve: const Interval(0.55, 1.0, curve: Curves.easeOut)));

    return SizeTransition(
      sizeFactor: size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      ),
    );
  }

  Future<void> _cancelForSession(BuildContext context,
      EventSessionRosterEntry entry, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signupCancelSpot),
        content: const Text('Are you sure you want to cancel your spot?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.signupCancelSpot,
                  style: const TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // Animate the row out before the API call so the user sees it "leave".
    _cancelCtrl?.dispose();
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _cancelCtrl = ctrl;
    setState(() => _cancellingId = entry.id);
    await ctrl.forward();

    try {
      if (!context.mounted) return;
      await context.read<EventProvider>().cancelSessionSignup(
          entry.id, widget.session.id, widget.event.id);
    } catch (e) {
      // Roll back animation state on failure
      setState(() => _cancellingId = null);
      ctrl.dispose();
      _cancelCtrl = null;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmRemoveEntry(BuildContext context,
      EventSessionRosterEntry entry, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signupRemoveGuest),
        content: Text(
            'Remove ${entry.displayName} from session #${widget.session.sessionNumber}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.remove,
                  style: const TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<EventProvider>().removeSessionRosterEntry(
        entry.id, widget.session.id, widget.event.id);
  }
}


// ── Session info sheet ────────────────────────────────────────────────────────

class _SessionInfoSheet extends StatelessWidget {
  final EventSession session;
  // B6: ordinal position in the sorted session list — stable display label
  // that doesn't have gaps after deletions the way session_number can.
  final int position;

  const _SessionInfoSheet({required this.session, this.position = 1});

  // Picks one string from [options] deterministically based on session id.
  String _pick(List<String> options) {
    final i = session.id.hashCode.abs() % options.length;
    return options[i];
  }

  String get _statusPhrase {
    if (session.hasEnded) {
      return _pick([
        '🏁 That\'s a wrap — session complete!',
        '🎬 And... scene. This one\'s done!',
        '📜 History. This session has ended.',
        '🏆 Another one in the books!',
      ]);
    }
    if (session.isLocked) {
      return _pick([
        '🔒 Signups are closed — doors shut!',
        '⛔ No new signups — the list is locked.',
        '🚪 Too late to join — it\'s locked in!',
      ]);
    }

    final cap = session.capacity;
    final going = session.goingCount;
    final waiting = session.waitlistCount;

    if (cap == null) {
      if (going == 0) {
        return _pick([
          '✨ Open to all — no cap, literally!',
          '🌍 Room for everyone. Be first!',
          '🎉 Unlimited spots — bring the whole crew!',
        ]);
      }
      return _pick([
        '🎊 $going people in — join the party!',
        '🌊 $going going and counting — hop on!',
        '🔓 Open to all — $going already in!',
      ]);
    }

    final open = (cap - going).clamp(0, cap);
    final fill = cap > 0 ? going / cap : 0.0;

    // Full
    if (open <= 0 && waiting > 0) {
      return _pick([
        '🔥 Fully booked + $waiting on the waitlist! It\'s giving sold-out vibes',
        '🎭 Zero spots, $waiting waiting — this session is POPPING',
        '🏟️ Packed house! $waiting people hoping for a no-show',
        '⚡ $waiting people are literally queuing for your spot',
      ]);
    }
    if (open <= 0) {
      return _pick([
        '😤 Fully booked — catch the next one!',
        '🚫 Zero spots left. You snooze, you lose!',
        '💥 Sold out! This one\'s full.',
        '🎯 Full house — no more room!',
      ]);
    }

    // Last spot
    if (open == 1) {
      return _pick([
        '🚨 LAST SPOT. This is your sign.',
        '⚡ One spot left — and it has your name on it',
        '🎯 Final seat in the house. Go!',
        '🔔 Last call! One spot remaining.',
      ]);
    }

    // Very few (2–3)
    if (open <= 3) {
      return _pick([
        '⏳ Only $open spots left — tell your bestie NOW',
        '🌡️ Down to the wire! $open spots remain',
        '💨 $open spots going fast — don\'t blink!',
        '🎪 Almost gone! Grab one of the $open spots left',
      ]);
    }

    // Almost full (80–99%)
    if (fill >= 0.80) {
      return _pick([
        '🔥 Filling up FAST — $open spots left!',
        '🌋 Nearly there — only $open still available',
        '📉 $open spots left and shrinking. Act now!',
        '⚡ $open spots remaining — things are heating up',
      ]);
    }

    // More than half (50–79%)
    if (fill >= 0.50) {
      return _pick([
        '🎯 $open of $cap spots left — the vibe is building',
        '📈 Over halfway full — $open spots still up for grabs',
        '🎶 The crowd is gathering... $open spots to go!',
        '🚀 Momentum is building — $open spots remain',
      ]);
    }

    // Getting started (20–49%)
    if (fill >= 0.20) {
      return _pick([
        '🌱 Getting warmed up — $open spots still available',
        '🎈 Early days — $open spots wide open',
        '😎 Plenty of room — $open spots left, no rush... yet',
        '🛋️ Still comfy — $open of $cap spots free',
      ]);
    }

    // Just started / almost empty
    if (going > 0) {
      return _pick([
        '🐣 Just $going brave soul${going == 1 ? '' : 's'} so far — $open spots free!',
        '🌅 Early bird territory — $open spots open!',
        '🦗 Barely started — $open spots just waiting',
        '🎠 Lots of room — only $going signed up so far',
      ]);
    }

    // Completely empty
    return _pick([
      '👻 Ghost town! Be the legend who signs up first',
      '🦗 Crickets... someone\'s gotta be first!',
      '🌵 Empty as a desert — $cap spots available',
      '🎪 $cap spots, zero takers — your moment to shine!',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, MMM d · h:mm a');
    final grad = _SessionEmojiBadge.gradientFor(session);
    final cap = session.capacity;
    final going = session.goingCount;
    final waiting = session.waitlistCount;
    final fillFraction =
        cap != null && cap > 0 ? (going / cap).clamp(0.0, 1.0) : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header gradient band ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [grad[0], grad[1]],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _SessionEmojiBadge(session: session, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session #$position',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fmt.format(session.startAt.toLocal()),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      if (session.endAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ends ${DateFormat('h:mm a').format(session.endAt!.toLocal())}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.80),
                              fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Capacity bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statusPhrase,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    if (cap != null)
                      Text(
                        '$going/$cap',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: fillFraction != null && fillFraction >= 1.0
                                ? Colors.red
                                : grad[0]),
                      ),
                  ],
                ),
                if (fillFraction != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fillFraction,
                      minHeight: 10,
                      backgroundColor:
                          grad[0].withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        fillFraction >= 1.0 ? Colors.redAccent : grad[0],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Stats row ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _StatBubble(
                  emoji: '✅',
                  count: going,
                  label: 'Going',
                  color: const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 12),
                _StatBubble(
                  emoji: '⏳',
                  count: waiting,
                  label: 'Waitlist',
                  color: Colors.orange,
                ),
                if (cap != null) ...[
                  const SizedBox(width: 12),
                  _StatBubble(
                    emoji: '🪑',
                    count: (cap - going).clamp(0, cap),
                    label: 'Open',
                    color: const Color(0xFF1565C0),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Settings chips ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: session.isPublic
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                  label: session.isPublic ? 'Public' : 'Private',
                  color: session.isPublic
                      ? const Color(0xFF1565C0)
                      : Colors.blueGrey,
                ),
                if (session.waitlistEnabled)
                  const _InfoChip(
                    icon: Icons.list_alt_rounded,
                    label: 'Waitlist on',
                    color: Colors.orange,
                  ),
                if (session.requiresApproval)
                  const _InfoChip(
                    icon: Icons.how_to_reg_rounded,
                    label: 'Approval required',
                    color: Color(0xFF6A1B9A),
                  ),
                if (session.isLocked)
                  const _InfoChip(
                    icon: Icons.lock_rounded,
                    label: 'Signups locked',
                    color: Colors.red,
                  )
                else if (session.signupLockHours != null)
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: 'Locks ${session.signupLockHours}h before',
                    color: Colors.teal,
                  ),
                if (session.hasEnded)
                  const _InfoChip(
                    icon: Icons.flag_rounded,
                    label: 'Ended',
                    color: Colors.grey,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String emoji;
  final int count;
  final String label;
  final Color color;

  const _StatBubble({
    required this.emoji,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.80),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Signup empty state ────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String message;

  const _EmptyState({required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ),
          ],
        ),
      );
}

// ── Signup CTA button ─────────────────────────────────────────────────────────

class _SignupCTAButton extends StatefulWidget {
  final String label;
  final bool isWaitlist;
  final VoidCallback onPressed;

  const _SignupCTAButton({
    required this.label,
    required this.isWaitlist,
    required this.onPressed,
  });

  @override
  State<_SignupCTAButton> createState() => _SignupCTAButtonState();
}

class _SignupCTAButtonState extends State<_SignupCTAButton>
    with TickerProviderStateMixin {

  // Continuous float loop on the big emoji
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  // One-shot press squeeze
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _floatAnim = Tween(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _pressAnim = Tween(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // Capture position and overlay before the async gap.
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    Offset? center;
    if (box != null) {
      final offset = box.localToGlobal(Offset.zero);
      center = Offset(offset.dx + box.size.width / 2, offset.dy + box.size.height / 2);
    }

    await _pressCtrl.forward();
    _pressCtrl.reverse();

    if (center != null && mounted) _launchParticles(overlay, center);
    widget.onPressed();
  }

  void _launchParticles(OverlayState overlay, Offset origin) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CTAParticleBurst(
        origin: origin,
        isWaitlist: widget.isWaitlist,
        onDone: entry.remove,
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final isWaitlist = widget.isWaitlist;
    final colors = isWaitlist
        ? [const Color(0xFFFFB300), const Color(0xFFE65100)]
        : [const Color(0xFF43A047), const Color(0xFF1B5E20)];
    final glowColor =
        isWaitlist ? const Color(0xFFFFB300) : const Color(0xFF43A047);
    final bigEmoji = isWaitlist ? '⏳' : '🎟️';
    final label = widget.label;

    return ScaleTransition(
      scale: _pressAnim,
      child: Container(
        width: double.infinity,
        height: 96,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.55),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: glowColor.withValues(alpha: 0.20),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glossy top-half shine
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.20),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
            // Tappable content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white24,
                highlightColor: Colors.white10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Big floating emoji
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, _) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: Text(bigEmoji,
                              style: const TextStyle(fontSize: 46)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Label + tap hint
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isWaitlist
                                  ? 'You\'ll be notified when a spot opens'
                                  : 'Tap to reserve your place',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.80),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.70),
                          size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CTA particle burst overlay ────────────────────────────────────────────────

class _CTAParticleBurst extends StatefulWidget {
  final Offset origin;
  final bool isWaitlist;
  final VoidCallback onDone;

  const _CTAParticleBurst({
    required this.origin,
    required this.isWaitlist,
    required this.onDone,
  });

  @override
  State<_CTAParticleBurst> createState() => _CTAParticleBurstState();
}

class _CTAParticleBurstState extends State<_CTAParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 8 sparkles evenly spread around the button centre
  static const _angles = [0.0, pi * 0.25, pi * 0.5, pi * 0.75,
                           pi, pi * 1.25, pi * 1.5, pi * 1.75];
  static const _sparkles = ['✨', '⭐', '💫', '🌟', '✨', '💫', '⭐', '🌟'];
  static const _distances = [70.0, 55.0, 80.0, 60.0, 72.0, 58.0, 75.0, 52.0];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroEmoji = widget.isWaitlist ? '⏳' : '🎟️';

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        // Hero: rises 160px, scales 1→1.8, fades out in last 40%
        final heroY = widget.origin.dy - 30 - Curves.easeOut.transform(t) * 160;
        final heroScale = 1.0 + Curves.elasticOut.transform(t.clamp(0.0, 0.6)) * 0.8;
        final heroOpacity = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4).clamp(0.0, 1.0);

        return Stack(
          children: [
            // Hero emoji flies upward
            Positioned(
              left: widget.origin.dx - 22,
              top: heroY - 22,
              child: Opacity(
                opacity: heroOpacity,
                child: Transform.scale(
                  scale: heroScale,
                  child: Text(heroEmoji,
                      style: const TextStyle(fontSize: 36)),
                ),
              ),
            ),

            // Sparkle burst
            for (var i = 0; i < _angles.length; i++)
              Builder(builder: (_) {
                final delay = i * 0.04;
                final localT = ((t - delay) / 0.7).clamp(0.0, 1.0);
                final dist = _distances[i] * Curves.easeOut.transform(localT);
                final dx = cos(_angles[i]) * dist;
                final dy = sin(_angles[i]) * dist;
                final opacity = localT < 0.5
                    ? localT * 2
                    : (1.0 - (localT - 0.5) * 2).clamp(0.0, 1.0);
                return Positioned(
                  left: widget.origin.dx + dx - 10,
                  top: widget.origin.dy + dy - 10,
                  child: Opacity(
                    opacity: opacity,
                    child: Text(_sparkles[i],
                        style: const TextStyle(fontSize: 18)),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// ── Cancel spot button ────────────────────────────────────────────────────────

class _CancelSpotButton extends StatefulWidget {
  final String label;
  final bool isWaitlist;
  final VoidCallback onPressed;

  const _CancelSpotButton({
    required this.label,
    required this.isWaitlist,
    required this.onPressed,
  });

  @override
  State<_CancelSpotButton> createState() => _CancelSpotButtonState();
}

class _CancelSpotButtonState extends State<_CancelSpotButton>
    with TickerProviderStateMixin {

  // Side-to-side run loop
  late final AnimationController _runCtrl;
  late final Animation<double> _runAnim;

  // Press squeeze
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _runCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _runAnim = Tween(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _runCtrl, curve: Curves.easeInOut),
    );

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _pressAnim = Tween(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _runCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // Capture position and overlay before the async gap.
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    Offset? center;
    if (box != null) {
      final offset = box.localToGlobal(Offset.zero);
      center = Offset(offset.dx + box.size.width / 2, offset.dy + box.size.height / 2);
    }

    await _pressCtrl.forward();
    _pressCtrl.reverse();

    if (center != null && mounted) _launchRunAwayBurst(overlay, center);
    widget.onPressed();
  }

  void _launchRunAwayBurst(OverlayState overlay, Offset origin) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _RunAwayBurst(
        origin: origin,
        isWaitlist: widget.isWaitlist,
        onDone: entry.remove,
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    // Slightly translucent danger red gradient — premium but clearly destructive
    const colors = [Color(0xFFEF5350), Color(0xFFC62828)];
    const glowColor = Color(0xFFEF5350);
    final emoji = widget.isWaitlist ? '🏃' : '🚪';
    final subtitle = widget.isWaitlist
        ? 'You\'ll lose your place in line'
        : 'Your confirmed spot will be released';

    return ScaleTransition(
      scale: _pressAnim,
      child: Container(
        width: double.infinity,
        height: 88,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
            BoxShadow(
              color: glowColor.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glossy top shine
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white24,
                highlightColor: Colors.white10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Running emoji bobbing side-to-side
                      AnimatedBuilder(
                        animation: _runAnim,
                        builder: (_, _) => Transform.translate(
                          offset: Offset(_runAnim.value, 0),
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 42)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.80),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Run-away particle burst ───────────────────────────────────────────────────

class _RunAwayBurst extends StatefulWidget {
  final Offset origin;
  final bool isWaitlist;
  final VoidCallback onDone;

  const _RunAwayBurst({
    required this.origin,
    required this.isWaitlist,
    required this.onDone,
  });

  @override
  State<_RunAwayBurst> createState() => _RunAwayBurstState();
}

class _RunAwayBurstState extends State<_RunAwayBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Particles fan out mostly rightward (runner fleeing to the right)
  static const _data = [
    ('💨', 0.0,   80.0),   // right
    ('💨', 0.2,   60.0),   // slight up-right
    ('👋', -0.3,  55.0),   // slight down-right
    ('👟', 0.5,   70.0),   // upper-right
    ('✨',  pi,    45.0),   // left (trailing)
    ('💫', pi * 0.7, 50.0), // lower-left trail
    ('👟', -0.5,  65.0),   // lower-right
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroEmoji = widget.isWaitlist ? '🏃' : '🚪';

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        // Hero: runner slides right and fades
        final heroX = Curves.easeIn.transform(t) * 220;
        final heroOpacity = t < 0.5 ? 1.0 : (1.0 - (t - 0.5) * 2).clamp(0.0, 1.0);

        return Stack(
          children: [
            // Hero emoji runs off to the right
            Positioned(
              left: widget.origin.dx - 22 + heroX,
              top: widget.origin.dy - 22,
              child: Opacity(
                opacity: heroOpacity,
                child: Text(heroEmoji,
                    style: const TextStyle(fontSize: 38)),
              ),
            ),

            // Trailing particles
            for (final (emoji, angle, dist) in _data)
              Builder(builder: (_) {
                final localT = (t / 0.7).clamp(0.0, 1.0);
                final dx = cos(angle) * dist * Curves.easeOut.transform(localT);
                final dy = sin(angle) * dist * Curves.easeOut.transform(localT);
                final opacity = localT < 0.4
                    ? localT / 0.4
                    : (1.0 - (localT - 0.4) / 0.6).clamp(0.0, 1.0);
                return Positioned(
                  left: widget.origin.dx + dx - 10,
                  top: widget.origin.dy + dy - 10,
                  child: Opacity(
                    opacity: opacity,
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 18)),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// ── Signup locked banner ──────────────────────────────────────────────────────

class _LockedBanner extends StatelessWidget {
  final String message;
  final Color color;

  const _LockedBanner(
      {required this.message, this.color = Colors.orange});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13)),
            ),
          ],
        ),
      );
}

// ── Waitlist divider (replaces the removed SectionHeader for waitlist) ────────

class _WaitlistDivider extends StatelessWidget {
  final int count;
  const _WaitlistDivider({required this.count});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Divider(
                color: Colors.orange.withValues(alpha: 0.35), thickness: 1),
          ),
          const SizedBox(width: 10),
          Text(
            '⏳  $count on the waitlist',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
                color: Colors.orange.withValues(alpha: 0.35), thickness: 1),
          ),
        ],
      );
}

// ── Session emoji badge ───────────────────────────────────────────────────────

class _SessionEmojiBadge extends StatelessWidget {
  final EventSession session;
  /// Outer box size in logical pixels. Defaults to 52 (full card size).
  final double size;
  const _SessionEmojiBadge({required this.session, this.size = 52});

  // Fun emoji pool — picked deterministically by session id hash so the same
  // session always shows the same one across devices and reloads.
  static const _emojis = [
    '🦁', '🐼', '🦊', '🐸', '🦄', '🐙', '🦋', '🐬',
    '🦀', '🦖', '🐳', '🦩', '🦚', '🦜', '🦝', '🦥',
    '🚀', '🎸', '🎯', '🎲', '🎪', '🎭', '🎨', '🎺',
    '🏄', '🤸', '🧗', '🏋️', '🤺', '🥊', '🏇', '🧜',
    '🍕', '🍜', '🧁', '🍩', '🌮', '🍣', '🧇', '🥐',
    '🌈', '⚡', '🔥', '💫', '🌊', '🍀', '🌸', '🎋',
    '🤖', '👾', '🎃', '🧸', '💎', '🔮', '🪄', '🎁',
  ];

  // Background colour pairs [start, end] matched to the emoji vibe
  static const _gradients = [
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)], // warm red-orange
    [Color(0xFF4ECDC4), Color(0xFF44A08D)], // teal
    [Color(0xFFA18CD1), Color(0xFFFBC2EB)], // purple-pink
    [Color(0xFFFFD93D), Color(0xFFFF6B6B)], // yellow-red
    [Color(0xFF6BCB77), Color(0xFF4D96FF)], // green-blue
    [Color(0xFFFF9A9E), Color(0xFFFECFEF)], // pink
    [Color(0xFF43E97B), Color(0xFF38F9D7)], // mint
    [Color(0xFFFA709A), Color(0xFFFEE140)], // pink-yellow
  ];

  /// Returns the [start, end] gradient colours for [session], shared with the
  /// card border so the accent colour is always consistent.
  static List<Color> gradientFor(EventSession session) {
    final hash = session.id.hashCode.abs();
    return _gradients[(hash ~/ _emojis.length) % _gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final hash = session.id.hashCode.abs();
    final emoji = _emojis[hash % _emojis.length];
    final grad = _gradients[(hash ~/ _emojis.length) % _gradients.length];

    final radius = size * 0.27;
    final emojiFontSize = size * 0.50;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: grad,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: size >= 40
            ? [
                BoxShadow(
                  color: grad[0].withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: emojiFontSize)),
      ),
    );
  }
}

// ── Session roster row ────────────────────────────────────────────────────────

class _SessionRosterRow extends StatelessWidget {
  final int position;
  final int index;
  final EventSessionRosterEntry entry;
  final bool isWaitlist;
  final bool isOrganizer;
  final bool showDragHandle;
  final bool showAttendance;
  final VoidCallback? onRemove;
  final VoidCallback? onPromote;
  final VoidCallback? onDemote;
  final void Function(bool?)? onMarkAttendance;
  final void Function(bool)? onToggleConfirmed;

  const _SessionRosterRow({
    super.key,
    required this.position,
    required this.index,
    required this.entry,
    this.isWaitlist = false,
    required this.isOrganizer,
    this.showDragHandle = false,
    this.showAttendance = false,
    this.onRemove,
    this.onPromote,
    this.onDemote,
    this.onMarkAttendance,
    this.onToggleConfirmed,
  });

  String? get _medal => isWaitlist
      ? null
      : switch (position) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => null };

  @override
  Widget build(BuildContext context) {
    final posGlow = isWaitlist
        ? const Color(0xFFFFA000)
        : const Color(0xFF2E7D32);
    final isConfirmed = entry.signupConfirmed;

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed
              ? const Color(0xFF2E7D32).withValues(alpha: 0.45)
              : isWaitlist
                  ? const Color(0xFFFFA000).withValues(alpha: 0.20)
                  : const Color(0xFF2E7D32).withValues(alpha: 0.12),
          width: isConfirmed ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: posGlow.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Roster position badge — outlined circle, distinct from the session pill
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: posGlow.withValues(alpha: 0.08),
                    border: Border.all(color: posGlow.withValues(alpha: 0.55), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '#$position',
                      style: TextStyle(
                          color: posGlow,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
                if (_medal != null)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Text(_medal!,
                        style: const TextStyle(fontSize: 16)),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Name + email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (entry.email != null)
                    Text(entry.email!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),

            // Confirmation toggle + attendance toggles + drag handle
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Paid marker — organizer taps to toggle paid/unpaid
                if (!isWaitlist && onToggleConfirmed != null) ...[
                  Tooltip(
                    message: isConfirmed ? 'Paid — tap to unmark' : 'Not paid — tap to mark paid',
                    child: AppTappable(
                      onTap: () => onToggleConfirmed!(!isConfirmed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isConfirmed
                                ? Icons.paid_rounded
                                : Icons.money_off_csred_rounded,
                            key: ValueKey(isConfirmed),
                            size: 24,
                            color: isConfirmed
                                ? const Color(0xFF2E7D32)
                                : Colors.grey[350],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (showAttendance) ...[
                  _AttendanceChip(
                    attended: entry.attended,
                    onMarkAttendance: onMarkAttendance,
                  ),
                  const SizedBox(width: 6),
                ],
                if (showDragHandle)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: Colors.grey[400],
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!isOrganizer) return card;

    return Slidable(
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.56,
        children: [
          if (onPromote != null)
            _SlideAction(
              onPressed: onPromote!,
              icon: Icons.arrow_upward_rounded,
              label: 'Promote',
              color: const Color(0xFF2E7D32),
            ),
          if (onDemote != null)
            _SlideAction(
              onPressed: onDemote!,
              icon: Icons.arrow_downward_rounded,
              label: 'Demote',
              color: const Color(0xFFE65100),
            ),
          _SlideAction(
            onPressed: onRemove!,
            icon: Icons.delete_outline_rounded,
            label: 'Remove',
            color: const Color(0xFFC62828),
          ),
        ],
      ),
      child: card,
    );
  }
}

// ── Attendance dot — post-event check/cross toggle ───────────────────────────

// ── Attendance chip — single tappable chip cycling attended / no-show / unset ──

class _AttendanceChip extends StatelessWidget {
  final bool? attended; // null = not marked, true = attended, false = no-show
  final void Function(bool?)? onMarkAttendance;

  const _AttendanceChip({this.attended, this.onMarkAttendance});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    final IconData icon;
    final String label;

    if (attended == true) {
      bg = const Color(0xFF2E7D32).withValues(alpha: 0.12);
      textColor = const Color(0xFF2E7D32);
      icon = Icons.check_circle_rounded;
      label = 'Attended';
    } else if (attended == false) {
      bg = AppTheme.danger.withValues(alpha: 0.10);
      textColor = AppTheme.danger;
      icon = Icons.cancel_rounded;
      label = 'No-show';
    } else {
      bg = Colors.grey.withValues(alpha: 0.10);
      textColor = Colors.grey;
      icon = Icons.radio_button_unchecked_rounded;
      label = 'Mark';
    }

    Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: attended == null
                ? Colors.grey.withValues(alpha: 0.20)
                : textColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
        ],
      ),
    );

    if (onMarkAttendance == null) return chip;

    // Organizer taps to cycle: unset → attended → no-show → unset
    return AppTappable(
      onTap: () {
        if (attended == null) {
          onMarkAttendance!(true);
        } else if (attended == true) {
          onMarkAttendance!(false);
        } else {
          onMarkAttendance!(null);
        }
      },
      child: chip,
    );
  }
}

// ── Premium floating pill slide action ───────────────────────────────────────

class _SlideAction extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _SlideAction({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => CustomSlidableAction(
        onPressed: (_) => onPressed(),
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // FittedBox.scaleDown lets the pill shrink its content
          // proportionally when the action panel is narrow, preventing
          // both text wrapping and vertical overflow.
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 26),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Signup Invite tab (per-session QR codes) ──────────────────────────────────

class _SignupInviteTab extends StatefulWidget {
  final Event event;

  const _SignupInviteTab({required this.event});

  @override
  State<_SignupInviteTab> createState() => _SignupInviteTabState();
}

class _SignupInviteTabState extends State<_SignupInviteTab> {
  int _selectedIdx = 0;

  @override
  Widget build(BuildContext context) {
    // Invite tab shows upcoming sessions — those are the ones to share QR codes for.
    final upcoming = context.watch<EventProvider>().upcomingSessionsFor(widget.event.id);
    final past = context.read<EventProvider>().pastSessionsFor(widget.event.id);
    final sessions = upcoming.isNotEmpty ? upcoming : past;

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('No sessions yet.',
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 6),
            Text('Create a session first, then share its QR code.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    final idx = _selectedIdx.clamp(0, sessions.length - 1);
    final session = sessions[idx];
    // App-only deep link — scanned with the in-app QR scanner on the same tab.
    final encodedCode = InviteCodec.encode(session.inviteCode);
    final inviteUrl = '$kAppBaseUrl/session/invite/$encodedCode';
    final fmt = DateFormat('EEE, MMM d · h:mm a');
    final inviteMessage =
        '🎟️ You\'re invited to "${widget.event.title}" — '
        'Session #${session.sessionNumber}\n'
        '📅 ${fmt.format(session.startAt.toLocal())}\n'
        'Open the app → Join tab → enter this code:\n$encodedCode';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        const Text('Session QR Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'Each session has a unique QR code. Anyone with the app can scan it to claim a spot instantly.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.45),
        ),

        const SizedBox(height: 20),

        // ── Session picker ──────────────────────────────────────────────
        if (sessions.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sessions.asMap().entries.map((e) {
                final selected = e.key == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppTappable(
                    onTap: () => setState(() => _selectedIdx = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF003D33),
                                  Color(0xFF00695C),
                                  Color(0xFF00897B),
                                ],
                              )
                            : null,
                        color: selected
                            ? null
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF4DB6AC).withValues(alpha: 0.30)
                              : const Color(0xFF00695C).withValues(alpha: 0.25),
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00695C)
                                      .withValues(alpha: 0.40),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        '#${e.value.sessionNumber}  ·  ${DateFormat('MMM d').format(e.value.startAt.toLocal())}',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Selected session info bar ───────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _SessionEmojiBadge(session: session, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Session #${session.sessionNumber} · ${fmt.format(session.startAt.toLocal())}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── QR card ─────────────────────────────────────────────────────
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QrImageView(
              data: inviteUrl,
              version: QrVersions.auto,
              size: 210,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF2E7D32),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1B5E20),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        Center(
          child: Text(
            'Point a phone camera at this code',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),

        const SizedBox(height: 20),

        AppButton(
          label: 'Copy invite code',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: inviteMessage));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invite copied — share it anywhere!')),
            );
          },
        ),

        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),

        // ── Manual add ──────────────────────────────────────────────────
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add manually',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 2),
            Text('For walk-ins or guests without a phone.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 10),
        _AddSessionGuestButton(event: widget.event, session: session),
      ],
    );
  }
}

// ── Add session sheet ────────────────────────────────────────────────────────

class _NewSessionConfig {
  final DateTime startAt;
  final int? capacity;
  final bool waitlistEnabled;
  final int? signupLockHours;
  final List<String> preAddNames;
  final bool autoAddSelf;
  final bool isPublic;
  final bool requiresApproval;

  const _NewSessionConfig({
    required this.startAt,
    this.capacity,
    this.waitlistEnabled = true,
    this.signupLockHours,
    this.preAddNames = const [],
    this.autoAddSelf = false,
    this.isPublic = true,
    this.requiresApproval = false,
  });
}

class _AddSessionSheet extends StatefulWidget {
  final DateTime suggestion;
  final EventSession? template; // pre-fills settings when cloning
  final List<String> memberNames; // event member names for pre-add suggestions
  const _AddSessionSheet({
    required this.suggestion,
    this.template,
    this.memberNames = const [],
  });

  @override
  State<_AddSessionSheet> createState() => _AddSessionSheetState();
}

class _AddSessionSheetState extends State<_AddSessionSheet> {
  late DateTime _startAt;
  final _capacityCtrl = TextEditingController();
  bool _waitlistEnabled = true;
  final _lockCtrl = TextEditingController();
  bool _autoAddSelf = true;
  bool _isPublic = true;
  bool _requiresApproval = false;
  final List<String> _preAddNames = [];
  final _preAddCtrl = TextEditingController();
  bool _preAddHasText = false;

  List<String> get _suggestions {
    final query = _preAddCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return widget.memberNames
        .where((n) =>
            n.toLowerCase().contains(query) && !_preAddNames.contains(n))
        .take(5)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _startAt = widget.suggestion;
    final t = widget.template;
    if (t != null) {
      if (t.capacity != null) _capacityCtrl.text = t.capacity.toString();
      _waitlistEnabled = t.waitlistEnabled;
      if (t.signupLockHours != null) _lockCtrl.text = t.signupLockHours.toString();
    }
  }

  @override
  void dispose() {
    _capacityCtrl.dispose();
    _lockCtrl.dispose();
    _preAddCtrl.dispose();
    super.dispose();
  }

  void _submitPreAdd() {
    final name = _preAddCtrl.text.trim();
    if (name.isNotEmpty && !_preAddNames.contains(name)) {
      setState(() {
        _preAddNames.add(name);
        _preAddHasText = false;
      });
      _preAddCtrl.clear();
    }
  }

  void _addSuggestion(String name) {
    if (!_preAddNames.contains(name)) {
      setState(() {
        _preAddNames.add(name);
        _preAddHasText = false;
      });
      _preAddCtrl.clear();
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (d == null) return;
    final t = TimeOfDay.fromDateTime(_startAt);
    setState(() => _startAt =
        DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (t == null) return;
    setState(() => _startAt = DateTime(
        _startAt.year, _startAt.month, _startAt.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, MMM d · h:mm a');
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Text('📅', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Text('New session',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),

          // Date/time tile
          AppTappable(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.calendar_month_outlined,
                    color: colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(fmt.format(_startAt),
                    style: const TextStyle(fontWeight: FontWeight.w500))),
                AppTappable(
                  onTap: _pickTime,
                  child: Icon(Icons.access_time_rounded,
                      color: colorScheme.onSurfaceVariant, size: 20),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Capacity + waitlist row
          Row(children: [
            Expanded(
              child: TextField(
                controller: _capacityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Max spots',
                  hintText: 'Unlimited',
                  prefixIcon: Icon(Icons.people_outline),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Waitlist', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Switch(
                  value: _waitlistEnabled,
                  onChanged: (v) => setState(() => _waitlistEnabled = v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ]),
          const SizedBox(height: 12),

          // Lock hours
          TextField(
            controller: _lockCtrl,
            decoration: const InputDecoration(
              labelText: 'Lock signups (hours before start)',
              hintText: 'None',
              prefixIcon: Icon(Icons.lock_clock_outlined),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 4),

          // Auto-add myself as #1
          Row(
            children: [
              const Text('👤', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Add myself as #1',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Switch(
                value: _autoAddSelf,
                onChanged: (v) => setState(() => _autoAddSelf = v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Public / private toggle
          Row(
            children: [
              const Text('🌐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Make session public',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Switch(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 4),
            child: Text(
              _isPublic
                  ? 'Visible to all group members — anyone can sign up.'
                  : 'Hidden from the session list. Members can only join via QR code or invite link.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),

          const SizedBox(height: 4),

          // Need Review toggle
          Row(
            children: [
              const Text('🔍', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Need review',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Switch(
                value: _requiresApproval,
                onChanged: (v) => setState(() => _requiresApproval = v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 4),
            child: Text(
              _requiresApproval
                  ? 'Sign-up requests go to pending — organizer must approve before they count as confirmed.'
                  : 'Anyone who signs up is immediately confirmed (or waitlisted if full).',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),

          const SizedBox(height: 20),

          // Pre-add participants
          Text('Pre-add participants',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_preAddNames.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _preAddNames
                  .map((name) => Chip(
                        label: Text(name,
                            style: const TextStyle(fontSize: 11)),
                        deleteIcon: const Icon(Icons.close_rounded, size: 13),
                        onDeleted: () =>
                            setState(() => _preAddNames.remove(name)),
                        labelPadding: const EdgeInsets.only(left: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF2E7D32)
                            .withValues(alpha: 0.10),
                        side: BorderSide(
                            color: const Color(0xFF2E7D32)
                                .withValues(alpha: 0.35)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _preAddCtrl,
            decoration: InputDecoration(
              hintText: 'Type a name and press ↵',
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('🙋', style: TextStyle(fontSize: 18)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              isDense: true,
              suffixIcon: _preAddHasText
                  ? IconButton(
                      icon: const Text('➕',
                          style: TextStyle(fontSize: 18)),
                      tooltip: 'Add',
                      onPressed: _submitPreAdd,
                    )
                  : null,
            ),
            textInputAction: TextInputAction.done,
            onChanged: (v) =>
                setState(() => _preAddHasText = v.trim().isNotEmpty),
            onSubmitted: (_) => _submitPreAdd(),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestions.map((name) {
                return AppTappable(
                  onTap: () => _addSuggestion(name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF2E7D32)
                              .withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👤', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(name,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),

          // Create button
          AppButton(
            label: 'Add session',
            onPressed: () {
              final cap = int.tryParse(_capacityCtrl.text.trim());
              final lock = int.tryParse(_lockCtrl.text.trim());
              Navigator.pop(
                context,
                _NewSessionConfig(
                  startAt: _startAt,
                  capacity: cap,
                  waitlistEnabled: _waitlistEnabled,
                  signupLockHours: lock,
                  preAddNames: List.unmodifiable(_preAddNames),
                  autoAddSelf: _autoAddSelf,
                  isPublic: _isPublic,
                  requiresApproval: _requiresApproval,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Pending review row (organizer approve / reject) ──────────────────────────

class _PendingReviewRow extends StatelessWidget {
  final EventSessionRosterEntry entry;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingReviewRow({
    super.key,
    required this.entry,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6A1B9A).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF6A1B9A).withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (entry.email != null)
                  Text(entry.email!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          AppTappable(
            onTap: onApprove,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👍', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 4),
                  Text('Approve',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppTappable(
            onTap: onReject,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🙅', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text('Reject',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.danger)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add guest manually to a session ──────────────────────────────────────────

class _AddSessionGuestButton extends StatefulWidget {
  final Event event;
  final EventSession session;
  const _AddSessionGuestButton(
      {required this.event, required this.session});

  @override
  State<_AddSessionGuestButton> createState() =>
      _AddSessionGuestButtonState();
}

class _AddSessionGuestButtonState extends State<_AddSessionGuestButton> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add to Session #${widget.session.sessionNumber}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.publicRsvpName),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration:
                  InputDecoration(labelText: l10n.publicRsvpEmail),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Add',
              onPressed: () async {
                if (_nameCtrl.text.trim().isEmpty) return;
                final provider = ctx.read<EventProvider>();
                final messenger = ScaffoldMessenger.of(ctx);
                try {
                  await Supabase.instance.client
                      .rpc('rsvp_session', params: {
                    'p_invite_code': widget.session.inviteCode,
                    'p_display_name': _nameCtrl.text.trim(),
                    'p_email': _emailCtrl.text.trim().isEmpty
                        ? null
                        : _emailCtrl.text.trim(),
                  });
                  unawaited(provider.refreshSessionRoster(widget.session.id));
                  unawaited(provider.fetchUpcomingSessions(widget.event.id));
                  _nameCtrl.clear();
                  _emailCtrl.clear();
                  if (ctx.mounted) {
                    FocusScope.of(ctx).unfocus();
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  final msg = e.toString();
                  messenger.showSnackBar(SnackBar(
                    content: Text(msg.contains('already_signed_up')
                        ? 'This person is already signed up.'
                        : msg.contains('signup_locked')
                            ? 'Signups are locked for this session.'
                            : msg.contains('session_full')
                                ? 'Session is full — enable the waitlist to add more.'
                                : msg),
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppButton(
        label: 'Add Guest Manually',
        onPressed: _show,
      );
}

// ── Explore tab (trip events — affiliate activity suggestions) ────────────────

enum _ExploreSort { cheapest, topRated }

class _ExploreTab extends StatefulWidget {
  final Event event;
  final TabController tabController;
  final int tabIndex;
  const _ExploreTab({required this.event, required this.tabController, required this.tabIndex});

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

// 100 fun quotes shown randomly in the Explore tab header.
const _exploreQuotes = [
  'Life is short. Book the tour. 🎉',
  'Adventures are better than souvenirs ✨',
  'You can sleep when you\'re home 🌍',
  'Do it for the stories',
  'Collect moments, not things',
  'The best view comes after the hardest climb 🏔️',
  'Go where the WiFi is weak and the adventures are strong',
  'Every trip needs at least one spontaneous detour',
  'Not all who wander are lost — some are just finding tours',
  'The world is a book. Don\'t skip any chapters 📖',
  'Making memories one activity at a time',
  'Your couch has zero adventure. Just saying. 🛋️',
  'Good vibes and great experiences ahead 🙌',
  'If in doubt, book the tour',
  'Life\'s too short for boring trips',
  'Say yes to new adventures',
  'The trip you almost didn\'t take is usually the best one',
  'Experiences > Things',
  'You\'ll never regret doing something amazing',
  'Less planning. More doing. 🚀',
  'Wander often. Wonder always.',
  'A bad day of adventure beats a good day at the office',
  'The world won\'t explore itself 🌎',
  'Every destination has a hidden gem. Go find it.',
  'Tour today, brag forever',
  'Adventure is out there. Seriously, go get it.',
  'Turn the map upside down and see what happens 🗺️',
  'Eat. Explore. Repeat.',
  'Be the person who did the thing',
  'No tour, no story. Big tour, big story. 🎢',
  'Life begins at the end of your comfort zone',
  'The only trip you\'ll regret is the one you didn\'t take',
  'Make every trip count ⭐',
  'Go fast. See things. Tell everyone.',
  'The world is too big to stay in one spot',
  'An adventure a day keeps the boredom away 🎠',
  'Find your next great story here',
  'This is your sign to book something fun',
  'Spontaneity is the spice of travel 🌶️',
  'You came, you saw, you booked a tour',
  'Less Netflix. More experiences. 🎡',
  'Your future self will thank you for this one',
  'Today\'s adventure is tomorrow\'s greatest story',
  'Don\'t just visit. Experience.',
  'The best souvenir is a great memory 📸',
  'See the world differently — from a kayak 🚣',
  'Find the fun in every destination',
  'Great trips are made of great experiences',
  'Why sightsee when you can do-see? 🏄',
  'New place, new adventure, new you 🌟',
  'If it scares you a little, book it immediately',
  'Life is an adventure. Add more chapters.',
  'Get out there before you run out of time ⏳',
  'Every adventure starts with a single booking',
  'Make memories that outlast your tan',
  'The best journeys answer questions that begin with \'what if\'',
  'Happiness is planning a trip and then doing it 🎶',
  'Boring is not an option here',
  'Find something to do that you\'ll talk about for years',
  'Take only photos, leave only footprints... after the tour 📍',
  'You didn\'t come this far to only go this far',
  'Somewhere out there is your perfect adventure',
  'Keep calm and book a tour 🎫',
  'See more. Do more. Be more.',
  'Adventures are the best way to learn',
  'Go somewhere you\'ve never been. Do something you\'ve never done.',
  'The world is full of magic. Go find yours. ✨',
  'Stop dreaming. Start exploring.',
  'Your story needs a great next chapter 📝',
  'Adventure: because adulthood is overrated anyway 🎪',
  'Travel far enough to meet yourself',
  'The earth is calling. Pick up. 📞',
  'Explore more. Regret nothing.',
  'Less scroll, more stroll 🚶',
  'Make it a trip worth remembering',
  'The world has a lot to offer. Start here.',
  'Good things happen outside your routine',
  'Chase experiences, not just check-ins',
  'One tour away from a great mood 🎉',
  'Adventure: cheaper than therapy, better than TV',
  'Find the thing that makes this trip unforgettable',
  'A great tour is the best icebreaker with your group',
  'You packed the bags. Now fill them with memories. 🎒',
  'Some trips are planned. The best ones have moments like this.',
  'The map is not the territory — go explore the territory',
  'Life moves fast. Stop and do something cool.',
  'Not all superheroes wear capes. Some book tours. 🦸',
  'Find your extraordinary in the ordinary',
  'Travel: the one thing you buy that makes you richer 💫',
  'The best tour is the one you haven\'t taken yet',
  'On the road again? Make it count.',
  'Your group deserves something epic',
  'Pick the adventure, not the itinerary',
  'Great experiences are just one tap away 👇',
  'Do something your future self will Instagram about',
  'The party doesn\'t stop until the tour starts 🥳',
  'Real talk: you should do this',
  'Here\'s to the trips that change everything 🥂',
  'You only get so many trips. Make this one count.',
  'The adventure is always just around the corner',
];

class _ExploreTabState extends State<_ExploreTab>
    with AutomaticKeepAliveClientMixin {
  final _svc = ActivitySuggestionsService();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  List<ActivitySuggestion> _activities = [];
  bool _loading = false;
  String? _error;
  _ExploreSort _sort = _ExploreSort.cheapest;
  int _currentPage = 1;
  int _totalCount = 0;
  late String _quote;

  @override
  bool get wantKeepAlive => true;

  int get _totalPages =>
      (_totalCount / ActivitySuggestionsService.pageSize).ceil().clamp(1, 9999);

  // Empty search bar → auto-load by destination.
  // User keyword → sent as-is so they can include any location (stop, city en route, etc.).
  String get _searchTerm {
    final kw = _searchCtrl.text.trim();
    if (kw.isNotEmpty) return kw;
    return ActivitySuggestionsService.searchQueryForTest(
        widget.event.location.trim());
  }

  @override
  void initState() {
    super.initState();
    _quote = _exploreQuotes[Random().nextInt(_exploreQuotes.length)];
    widget.tabController.addListener(_onTabChange);
    _loadPage(1);
  }

  void _onTabChange() {
    if (!widget.tabController.indexIsChanging &&
        widget.tabController.index == widget.tabIndex) {
      setState(() => _quote = _exploreQuotes[Random().nextInt(_exploreQuotes.length)]);
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChange);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int page) async {
    if (widget.event.location.trim().isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final start = (page - 1) * ActivitySuggestionsService.pageSize + 1;
      final result = await _svc.searchViator(_searchTerm, start: start);
      if (mounted) {
        setState(() {
          _activities = result.items;
          _totalCount = result.totalCount;
          _currentPage = page;
          _loading = false;
        });
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<ActivitySuggestion> get _sorted {
    final list = List<ActivitySuggestion>.from(_activities);
    if (_sort == _ExploreSort.cheapest) {
      list.sort((a, b) {
        if (a.priceFrom == null && b.priceFrom == null) return 0;
        if (a.priceFrom == null) return 1;
        if (b.priceFrom == null) return -1;
        return a.priceFrom!.compareTo(b.priceFrom!);
      });
    } else {
      list.sort((a, b) {
        if (a.rating == null && b.rating == null) return 0;
        if (a.rating == null) return 1;
        if (b.rating == null) return -1;
        return b.rating!.compareTo(a.rating!);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final l10n = AppLocalizations.of(context);
    final dest = widget.event.location;
    final gygUrl = ActivitySuggestionsService.gygBrowseUrl(dest);
    final klookUrl = ActivitySuggestionsService.klookBrowseUrl(dest);

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('🎭', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 6),
                  Text('🏄', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 6),
                  Text('🗺️', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 6),
                  Text('🎪', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 6),
                  Text('🚵', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _quote,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.exploreSubtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Search bar
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'kayaking Santa Barbara, wine tour Napa...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _loadPage(1);
                    },
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}), // refresh clear button visibility
          onSubmitted: (_) => _loadPage(1),
        ),
        const SizedBox(height: 10),
        // Sort chips
        if (_activities.isNotEmpty) ...[
          Row(
            children: [
              _ExploreSortChip(
                label: l10n.exploreSortCheapest,
                icon: Icons.sell_outlined,
                selected: _sort == _ExploreSort.cheapest,
                onTap: () => setState(() => _sort = _ExploreSort.cheapest),
              ),
              const SizedBox(width: 8),
              _ExploreSortChip(
                label: l10n.exploreSortTopRated,
                icon: Icons.star_outline_rounded,
                selected: _sort == _ExploreSort.topRated,
                onTap: () => setState(() => _sort = _ExploreSort.topRated),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        // Loading
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: CircularProgressIndicator(),
            ),
          ),
        // Error
        if (!_loading && _error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(l10n.exploreLoadError,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _loadPage(_currentPage),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        // Activity cards
        if (!_loading && _error == null) ...[
          for (final activity in _sorted)
            _ActivityCard(activity: activity, l10n: l10n),
          if (_activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.exploreNoResults,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ),
            ),
          if (_totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: _currentPage > 1
                      ? () => _loadPage(_currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Page $_currentPage of $_totalPages',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700]),
                  ),
                ),
                IconButton.outlined(
                  onPressed: _currentPage < _totalPages
                      ? () => _loadPage(_currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
        // More platforms
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text(l10n.exploreMorePlatforms,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 10),
        _PlatformBrowseButton(
          emoji: '🗺️',
          label: l10n.browseGetYourGuide,
          subtitle: 'Strong in Europe & worldwide · 300k+ experiences',
          url: gygUrl,
        ),
        const SizedBox(height: 8),
        _PlatformBrowseButton(
          emoji: '🎡',
          label: l10n.browseKlook,
          subtitle: 'Best for Asia-Pacific · Attractions, transport & tours',
          url: klookUrl,
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivitySuggestion activity;
  final AppLocalizations l10n;

  const _ActivityCard({required this.activity, required this.l10n});

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatPrice(double price, String currency) {
    final symbol = currency == 'USD' ? '\$' : '$currency ';
    return '$symbol${price.toStringAsFixed(0)}';
  }

  Future<void> _launch(BuildContext context) async {
    final uri = Uri.parse(activity.affiliateUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return AppTappable(
      onTap: () => _launch(context),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (a.imageUrl != null)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  a.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey[100],
                    child: const Center(
                      child: Icon(Icons.explore_outlined,
                          size: 36, color: Colors.black12),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ActivityPlatformBadge(a.platform),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (a.rating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 15, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(a.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        if (a.reviewCount != null) ...[
                          const SizedBox(width: 2),
                          Text('(${a.reviewCount})',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                        const SizedBox(width: 10),
                      ],
                      if (a.durationMinutes != null) ...[
                        Icon(Icons.schedule_outlined,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(_formatDuration(a.durationMinutes!),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                      const Spacer(),
                      if (a.priceFrom != null)
                        Text(
                          l10n.exploreFromPrice(
                              _formatPrice(a.priceFrom!, a.currency)),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => _launch(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        a.platform == ActivityPlatform.viator
                            ? l10n.bookOnViator
                            : l10n.bookNow,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityPlatformBadge extends StatelessWidget {
  final ActivityPlatform platform;
  const _ActivityPlatformBadge(this.platform);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (platform) {
      ActivityPlatform.viator => ('Viator', const Color(0xFF1565C0)),
      ActivityPlatform.getYourGuide => ('GYG', const Color(0xFF2E7D32)),
      ActivityPlatform.klook => ('Klook', const Color(0xFFE65100)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ExploreSortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ExploreSortChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppTappable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? Colors.white : Colors.grey[700]),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlatformBrowseButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final Uri url;

  const _PlatformBrowseButton({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) => AppTappable(
        onTap: () async {
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded,
                  size: 16, color: Colors.grey[500]),
            ],
          ),
        ),
      );
}
