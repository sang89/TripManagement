import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide Event;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../providers/friends_provider.dart';
import '../../responsive/responsive_modal.dart';
import '../../widgets/supabase_image.dart';
import 'package:shared_ui/shared_ui.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _ContactMatch {
  final String displayName;
  final String userId;
  final String avatarUrl;

  const _ContactMatch({
    required this.displayName,
    required this.userId,
    required this.avatarUrl,
  });
}

class _ContactInvite {
  final String displayName;
  final String subtitle; // phone or email shown under the name
  final String? phone;
  final String? email;

  const _ContactInvite({
    required this.displayName,
    required this.subtitle,
    this.phone,
    this.email,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const _maxPhones = 1000;
  static const _maxEmails = 1000;

  bool _loading = true;
  bool _permissionDenied = false;
  List<_ContactMatch> _matched = [];
  List<_ContactInvite> _unmatched = [];

  final _searchCtrl = TextEditingController();
  String _query = '';

  // Track which matched user IDs we've sent a request to this session.
  final Set<String> _sent = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_ContactMatch> get _filteredMatched => _query.isEmpty
      ? _matched
      : _matched
          .where((m) => m.displayName.toLowerCase().contains(_query))
          .toList();

  List<_ContactInvite> get _filteredUnmatched => _query.isEmpty
      ? _unmatched
      : _unmatched
          .where((u) =>
              u.displayName.toLowerCase().contains(_query) ||
              u.subtitle.toLowerCase().contains(_query))
          .toList();

  Future<void> _load() async {
    final granted = await FlutterContacts.permissions.has(PermissionType.read);
    if (!mounted) return;
    if (!granted) {
      // Request permission — if still not granted after the prompt, show denied UI.
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      if (!mounted) return;
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
        });
        return;
      }
    }

    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.name,
        ContactProperty.phone,
        ContactProperty.email,
      },
    );
    if (!mounted) return;

    // Collect phones and emails, deduplicated.
    final phones = <String>{};
    final emails = <String>{};

    for (final c in contacts) {
      for (final p in c.phones) {
        final n = p.number.trim();
        if (n.isNotEmpty) phones.add(n);
      }
      for (final e in c.emails) {
        final addr = e.address.trim().toLowerCase();
        if (addr.isNotEmpty) emails.add(addr);
      }
    }

    final phoneList = phones.take(_maxPhones).toList();
    final emailList = emails.take(_maxEmails).toList();

    if (phoneList.isEmpty && emailList.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final db = Supabase.instance.client;
    final rows = await db.rpc('find_users_by_contacts', params: {
      'p_phones': phoneList,
      'p_emails': emailList,
    }) as List<dynamic>;

    if (!mounted) return;

    // Build lookup: normalised phone → userId, and email → userId.
    final matchedUserIds = <String>{};
    final matchedList = <_ContactMatch>[];
    for (final r in rows) {
      final userId = r['user_id'] as String;
      matchedUserIds.add(userId);
      matchedList.add(_ContactMatch(
        displayName: r['full_name'] as String? ?? '',
        userId: userId,
        avatarUrl: r['avatar_url'] as String? ?? '',
      ));
    }

    // Build normalised-phone and email sets from matched rows for fast lookup.
    final matchedPhones = <String>{};
    final matchedEmails = <String>{};
    for (final r in rows) {
      final p = r['matched_phone'] as String? ?? '';
      final e = r['matched_email'] as String? ?? '';
      if (p.isNotEmpty) matchedPhones.add(_normalise(p));
      if (e.isNotEmpty) matchedEmails.add(e.toLowerCase());
    }

    // Contacts not in the app — build invite list.
    final inviteList = <_ContactInvite>[];
    for (final c in contacts) {
      final name = c.displayName ?? '';
      if (name.isEmpty) continue;

      // Check if any phone/email from this contact matched.
      final contactPhones = c.phones.map((p) => _normalise(p.number)).toSet();
      final contactEmails =
          c.emails.map((e) => e.address.trim().toLowerCase()).toSet();

      final hasMatch = contactPhones.intersection(matchedPhones).isNotEmpty ||
          contactEmails.intersection(matchedEmails).isNotEmpty;

      if (hasMatch) continue;

      // Only include contacts that have at least a phone or email.
      final rawPhone = c.phones.isNotEmpty ? c.phones.first.number : null;
      final rawEmail = c.emails.isNotEmpty ? c.emails.first.address : null;
      final subtitle = rawPhone ?? rawEmail;
      if (subtitle == null) continue;

      inviteList.add(_ContactInvite(
        displayName: name,
        subtitle: subtitle,
        phone: rawPhone,
        email: rawEmail,
      ));
    }

    setState(() {
      _matched = matchedList;
      _unmatched = inviteList;
      _loading = false;
    });
  }

  String _normalise(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');

  Future<void> _addFriend(String userId) async {
    setState(() => _sent.add(userId));
    try {
      await context.read<FriendsProvider>().sendRequest(userId);
    } catch (e) {
      if (mounted) {
        setState(() => _sent.remove(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _invite(String name) async {
    final l10n = AppLocalizations.of(context);
    await Share.share(l10n.contactsInviteMessage(name));
  }

  Future<void> _addToTrip(_ContactInvite invite) async {
    final eventProvider = context.read<EventProvider>();
    final trips = eventProvider.myEvents
        .where((e) => e.isTrip)
        .toList();

    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trips yet — create a trip first.')),
      );
      return;
    }

    final selected = await showResponsiveModal<Event>(
      context: context,
      builder: (_) => _TripPickerSheet(trips: trips),
    );

    if (selected == null || !mounted) return;

    try {
      await eventProvider.addMember(
        selected.id,
        displayName: invite.displayName,
        email: invite.email,
        phone: invite.phone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${invite.displayName} added to ${selected.title}')),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactsScreenTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.contacts_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 20),
              Text(
                l10n.contactsPermissionDenied,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('app-settings:')),
                child: Text(l10n.contactsOpenSettings),
              ),
            ],
          ),
        ),
      );
    }

    if (_matched.isEmpty && _unmatched.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.contactsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
        ),
      );
    }

    final matched = _filteredMatched;
    final unmatched = _filteredUnmatched;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search contacts…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: matched.isEmpty && unmatched.isEmpty
              ? Center(
                  child: Text(
                    'No contacts match "$_query"',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  children: [
                    if (matched.isNotEmpty) ...[
                      _SectionHeader(label: l10n.contactsOnApp),
                      const SizedBox(height: 8),
                      ...matched.map((m) => _MatchedCard(
                            match: m,
                            pending: _sent.contains(m.userId),
                            onAdd: () => _addFriend(m.userId),
                          )),
                      const SizedBox(height: 16),
                    ],
                    if (unmatched.isNotEmpty) ...[
                      _SectionHeader(label: l10n.contactsInviteSection),
                      const SizedBox(height: 8),
                      ...unmatched.map((u) => _InviteCard(
                            invite: u,
                            onInvite: () => _invite(u.displayName),
                            onAddToTrip: () => _addToTrip(u),
                          )),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 1.1,
      ),
    );
  }
}

// ── Matched contact card ──────────────────────────────────────────────────────

class _MatchedCard extends StatelessWidget {
  final _ContactMatch match;
  final bool pending;
  final VoidCallback onAdd;

  const _MatchedCard({
    required this.match,
    required this.pending,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(name: match.displayName, avatarUrl: match.avatarUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                match.displayName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            if (pending)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.contactsPending,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500),
                ),
              )
            else
              FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(l10n.contactsAddFriend,
                    style: const TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Invite contact card ───────────────────────────────────────────────────────

enum _InviteAction { addToTrip, invite }

class _InviteCard extends StatelessWidget {
  final _ContactInvite invite;
  final VoidCallback onInvite;
  final VoidCallback onAddToTrip;

  const _InviteCard({
    required this.invite,
    required this.onInvite,
    required this.onAddToTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Avatar(name: invite.displayName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.displayName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    invite.subtitle,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<_InviteAction>(
              onSelected: (action) {
                if (action == _InviteAction.addToTrip) {
                  onAddToTrip();
                } else {
                  onInvite();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _InviteAction.addToTrip,
                  child: Row(
                    children: [
                      const Icon(Icons.luggage_outlined, size: 20),
                      const SizedBox(width: 12),
                      const Text('Add to Trip'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _InviteAction.invite,
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined,
                          size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      const Text('Invite to App'),
                    ],
                  ),
                ),
              ],
              icon: Icon(Icons.more_vert_rounded, color: Colors.grey[500]),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trip picker sheet ─────────────────────────────────────────────────────────

class _TripPickerSheet extends StatelessWidget {
  final List<Event> trips;
  const _TripPickerSheet({required this.trips});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Add to Trip',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: trips
                    .map((t) => ListTile(
                          leading: const Icon(Icons.luggage_outlined),
                          title: Text(t.title),
                          onTap: () => Navigator.pop(context, t),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String avatarUrl;

  const _Avatar({required this.name, this.avatarUrl = ''});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = avatarUrl.isNotEmpty ? avatarUrl : null;
    return SupabaseAvatar(
      url: url,
      radius: 24,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
      fallback: Text(
        initials,
        style: const TextStyle(
            fontWeight: FontWeight.w600, color: AppTheme.primary),
      ),
    );
  }
}
