import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../models/event_expense.dart';
import '../../models/event_guest.dart';
import '../../models/event_message.dart';
import '../../models/event_photo.dart';
import '../../models/friendship.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_chat_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/friends_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/user_lookup_service.dart';
import '../../utils/avatar_utils.dart';
import '../../widgets/trip_map_widget.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabIcons = [
    Icons.info_outline_rounded,
    Icons.people_outline,
    Icons.chat_bubble_outline_rounded,
    Icons.photo_library_outlined,
    Icons.receipt_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabIcons.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eventId = widget.eventId;
      context.read<EventProvider>()
        ..fetchPhotos(eventId)
        ..fetchExpenses(eventId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

        return Scaffold(
          appBar: AppBar(
            title: Text(event.title, overflow: TextOverflow.ellipsis),
            bottom: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600),
              tabs: [
                Tab(icon: const Icon(Icons.info_outline_rounded, size: 20),
                    text: l10n.infoTab),
                Tab(icon: const Icon(Icons.people_outline, size: 20),
                    text: l10n.guestsTab),
                Tab(icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    text: l10n.chatTabLabel),
                Tab(icon: const Icon(Icons.photo_library_outlined, size: 20),
                    text: l10n.photosTab),
                Tab(icon: const Icon(Icons.receipt_outlined, size: 20),
                    text: l10n.expensesTab),
              ],
            ),
            actions: [
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
                            style: const TextStyle(color: AppTheme.danger)),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _InfoTab(event: event, authUid: authUid),
              _GuestsTab(event: event, isOrganizer: isOrganizer),
              _ChatTab(eventId: event.id),
              _PhotosTab(
                event: event,
                photos: provider.photosFor(event.id),
                authUid: authUid,
                isOrganizer: isOrganizer,
              ),
              _ExpensesTab(
                event: event,
                expenses: provider.expensesFor(event.id),
                authUid: authUid,
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
}

enum _EventAction { edit, delete }

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

    final pins = event.locationLat != null && event.locationLng != null
        ? [
            TripMapPin(
              id: 'event',
              position: LatLng(event.locationLat!, event.locationLng!),
              title: event.location,
              isDestination: true,
            )
          ]
        : <TripMapPin>[];

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

        if (event.location.isNotEmpty)
          _DetailRow(
            icon: Icons.location_on_outlined,
            child: Text(event.location),
          ),

        if (event.description.isNotEmpty) ...[
          const Divider(height: 24),
          Text(event.description),
        ],

        // RSVP counts
        const Divider(height: 24),
        Row(
          children: [
            _CountChip(
                label: l10n.goingCount(event.goingCount), color: Colors.green),
            const SizedBox(width: 8),
            _CountChip(
                label: l10n.maybeCount(event.maybeCount), color: Colors.orange),
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

        // My RSVP
        if (!isOrganizer) ...[
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

        // Map
        if (pins.isNotEmpty) ...[
          const SizedBox(height: 16),
          TripMapWidget(pins: pins, compact: true),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

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
    if (widget.event.isFull && status == 'going') {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventFull)),
      );
      return;
    }
    setState(() => _loading = true);
    await context.read<EventProvider>().rsvp(widget.event.id, status);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = widget.myGuest?.rsvpStatus;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Guests tab ────────────────────────────────────────────────────────────────

class _GuestsTab extends StatefulWidget {
  final Event event;
  final bool isOrganizer;

  const _GuestsTab({required this.event, required this.isOrganizer});

  @override
  State<_GuestsTab> createState() => _GuestsTabState();
}

class _GuestsTabState extends State<_GuestsTab> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = <String, List<EventGuest>>{
      'going': [],
      'maybe': [],
      'declined': [],
    };
    for (final g in widget.event.guests) {
      groups[g.rsvpStatus]?.add(g);
    }

    return Stack(
      children: [
        widget.event.guests.isEmpty
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
                  for (final status in ['going', 'maybe', 'declined']) ...[
                    if (groups[status]!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          switch (status) {
                            'going' => l10n.rsvpGoing,
                            'maybe' => l10n.rsvpMaybe,
                            _ => l10n.rsvpDeclined,
                          },
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
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
            child: FloatingActionButton(
              onPressed: _showAddGuest,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.person_add_outlined, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddGuest() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddGuestSheet(eventId: widget.event.id),
    );
  }
}

class _GuestTile extends StatelessWidget {
  final EventGuest guest;
  final bool isOrganizer;

  const _GuestTile({required this.guest, required this.isOrganizer});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = guest.avatarUrl != null && guest.avatarUrl!.isNotEmpty;
    final contact = [
      if (guest.email != null) guest.email!,
      if (guest.phone != null) guest.phone!,
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        backgroundImage: hasAvatar ? NetworkImage(guest.avatarUrl!) : null,
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
      subtitle: contact.isNotEmpty ? Text(contact, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
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
                return const Center(child: CircularProgressIndicator());
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
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && msg.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
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
                        color: isMe ? Colors.white : null, fontSize: 14),
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
      {required this.ctrl, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border:
                Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).chatSendHint,
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24))),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          child:
                              CircularProgressIndicator(strokeWidth: 2)))
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
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$eventId/$fileName';

      await db.storage.from('event-photos').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
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
          child: FloatingActionButton(
            onPressed: _uploading ? null : _pickAndUpload,
            backgroundColor: AppTheme.primary,
            child: _uploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_a_photo, color: Colors.white),
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
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, EventPhoto photo) async {
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

  const _ExpensesTab({
    required this.event,
    required this.expenses,
    required this.authUid,
  });

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  void _showAddExpense() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddExpenseSheet(
        event: widget.event,
      ),
    );
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
                ),
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showAddExpense,
            backgroundColor: AppTheme.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final EventExpense expense;
  final Event event;
  final String? authUid;

  const _ExpenseCard(
      {required this.expense, required this.event, required this.authUid});

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

    return Card(
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
                      style: const TextStyle(fontWeight: FontWeight.w600)),
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
            if (mySplit != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.totalOwed(fmt.format(mySplit.amount)),
                      style: TextStyle(
                          fontSize: 13,
                          color: mySplit.settled
                              ? Colors.green
                              : AppTheme.danger),
                    ),
                  ),
                  if (!mySplit.settled)
                    TextButton(
                      onPressed: () => context
                          .read<EventProvider>()
                          .settleSplit(mySplit.id, expense.eventId),
                      child: Text(l10n.markSettled),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  final Event event;

  const _AddExpenseSheet({required this.event});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final Set<String> _selectedGuestIds = {};
  bool _loading = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_descCtrl.text.trim().isEmpty || amount == null || amount <= 0) return;
    setState(() => _loading = true);
    try {
      await context.read<EventProvider>().addExpense(
            eventId: widget.event.id,
            amount: amount,
            description: _descCtrl.text.trim(),
            splitGuestIds: _selectedGuestIds.toList(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goingGuests =
        widget.event.guests.where((g) => g.rsvpStatus == 'going').toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(l10n.addExpense,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                      labelText: l10n.expenseDescription),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.expenseAmount, prefixText: '\$'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.splitAmong,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: goingGuests
                    .map((g) => CheckboxListTile(
                          title: Text(g.displayName),
                          value: _selectedGuestIds.contains(g.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selectedGuestIds.add(g.id);
                            } else {
                              _selectedGuestIds.remove(g.id);
                            }
                          }),
                          dense: true,
                          activeColor: AppTheme.primary,
                        ))
                    .toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AppButton(
              label: l10n.addExpense,
              onPressed: _submit,
              loading: _loading,
            ),
          ),
          const SizedBox(height: 8),
        ],
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

// ── Add Guest sheet ────────────────────────────────────────────────────────────

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
      _debounce = Timer(const Duration(milliseconds: 400), _performLookup);
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
            email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
            phone: _phone.isEmpty ? null : _phone,
            userId: userId,
          );
      if (mounted) Navigator.pop(context);
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(l10n.addGuest,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
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
                    constraints: const BoxConstraints(maxHeight: 220),
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
                            backgroundColor:
                                avatarColors(f.otherDisplayName ?? '').first,
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
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
