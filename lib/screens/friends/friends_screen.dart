import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/friendship.dart';
import '../../providers/friends_provider.dart';
import '../../utils/avatar_utils.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
    // Give the tab animation time to complete before requesting focus.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navFriends),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.people_outline, size: 20), text: l10n.friendsTabFriends),
            Consumer<FriendsProvider>(
              builder: (_, friends, _) {
                final count = friends.incomingRequests.length;
                return Tab(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.person_add_outlined, size: 20),
                  ),
                  text: l10n.friendsTabRequests,
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSearch,
        tooltip: l10n.friendsAddFriend,
        child: const Icon(Icons.person_add_outlined),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendsTab(searchFocusNode: _searchFocusNode),
          _RequestsTab(),
        ],
      ),
    );
  }
}

// ─── Friends tab ───────────────────────────────────────────────────────────────

class _FriendsTab extends StatefulWidget {
  final FocusNode searchFocusNode;

  const _FriendsTab({required this.searchFocusNode});

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, String>> _searchResults = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _doSearch(value.trim()));
  }

  Future<void> _doSearch(String query) async {
    setState(() => _searching = true);
    final results = await context.read<FriendsProvider>().searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(String userId, String name) async {
    final l10n = AppLocalizations.of(context);
    try {
      await context.read<FriendsProvider>().sendRequest(userId);
      if (mounted) {
        _searchCtrl.clear();
        setState(() => _searchResults = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.friendsRequestSent)),
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
    }
  }

  void _showFriendSheet(Friendship f) {
    final name = f.otherDisplayName ?? '';
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                _Avatar(name: name, size: 72),
                const SizedBox(height: 14),
                Text(name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (f.otherEmail?.isNotEmpty == true)
                  _ContactRow(
                      icon: Icons.email_outlined, label: f.otherEmail!),
                if (f.otherPhone?.isNotEmpty == true)
                  _ContactRow(
                      icon: Icons.phone_outlined, label: f.otherPhone!),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmRemove(f);
                  },
                  icon: const Icon(Icons.person_remove_outlined),
                  label: Text(l10n.friendsRemove),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemove(Friendship f) async {
    final l10n = AppLocalizations.of(context);
    final name = f.otherDisplayName ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.friendsRemove),
        content: Text(l10n.friendsRemoveConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.friendsRemove,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<FriendsProvider>().remove(f.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final friends = context.watch<FriendsProvider>().accepted;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            focusNode: widget.searchFocusNode,
            decoration: InputDecoration(
              hintText: l10n.friendsSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchResults = [];
                          _searching = false;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
        ),

        // Search results
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator.adaptive(),
          )
        else if (_searchResults.isNotEmpty)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ..._searchResults.map((r) {
                    final email = r['email'] ?? '';
                    final displayName = (r['fullName']?.isNotEmpty == true)
                        ? r['fullName']!
                        : email.split('@').first;
                    return ListTile(
                      leading: _Avatar(name: displayName),
                      title: Text(displayName),
                      subtitle: Text(email,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => _sendRequest(r['userId']!, displayName),
                        child: Text(l10n.friendsAddFriend),
                      ),
                    );
                  }),
                ],
              ),
            ),
          )
        else if (_searchCtrl.text.trim().length >= 2 && _searchResults.isEmpty && !_searching)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.friendsNoResults,
                style: TextStyle(color: Colors.grey[600])),
          )

        // Friends list
        else if (friends.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline,
                      size: 64, color: AppTheme.primaryLight),
                  const SizedBox(height: 16),
                  Text(l10n.friendsNoFriends),
                  const SizedBox(height: 8),
                  Text(l10n.friendsNoFriendsHint,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: friends.length,
              itemBuilder: (_, i) {
                final f = friends[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Slidable(
                    key: ValueKey(f.id),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.25,
                      children: [
                        SlidableAction(
                          onPressed: (_) => _confirmRemove(f),
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                          icon: Icons.person_remove_outlined,
                          label: l10n.friendsRemove,
                        ),
                      ],
                    ),
                    child: _FriendCard(
                      name: f.otherDisplayName ?? '',
                      onTap: () => _showFriendSheet(f),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─── Requests tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final friends = context.watch<FriendsProvider>();
    final incoming = friends.incomingRequests;
    final outgoing = friends.outgoingRequests;

    if (incoming.isEmpty && outgoing.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined,
                  size: 36, color: AppTheme.primaryLight),
            ),
            const SizedBox(height: 20),
            Text(l10n.friendsNoRequests,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Friend requests will appear here',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (incoming.isNotEmpty) ...[
          _SectionHeader(label: l10n.friendsIncomingSection),
          const SizedBox(height: 8),
          ...incoming.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _IncomingRequestCard(friendship: f),
              )),
        ],
        if (outgoing.isNotEmpty) ...[
          if (incoming.isNotEmpty) const SizedBox(height: 8),
          _SectionHeader(label: l10n.friendsOutgoingSection),
          const SizedBox(height: 8),
          ...outgoing.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OutgoingRequestCard(friendship: f),
              )),
        ],
      ],
    );
  }
}

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

class _IncomingRequestCard extends StatefulWidget {
  final Friendship friendship;

  const _IncomingRequestCard({required this.friendship});

  @override
  State<_IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends State<_IncomingRequestCard> {
  bool _loading = false;

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = widget.friendship;
    final name = f.otherDisplayName ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Avatar(name: name, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Wants to be friends',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_loading)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2))
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      final provider = context.read<FriendsProvider>();
                      _act(() => provider.decline(f.id));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(l10n.friendsDecline, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final provider = context.read<FriendsProvider>();
                      _act(() => provider.accept(f.id));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(l10n.friendsAccept, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingRequestCard extends StatefulWidget {
  final Friendship friendship;

  const _OutgoingRequestCard({required this.friendship});

  @override
  State<_OutgoingRequestCard> createState() => _OutgoingRequestCardState();
}

class _OutgoingRequestCardState extends State<_OutgoingRequestCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = widget.friendship;
    final name = f.otherDisplayName ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Avatar(name: name, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Pending',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryLight)),
                  ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2))
            else
              IconButton(
                onPressed: () async {
                  setState(() => _loading = true);
                  final provider = context.read<FriendsProvider>();
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await provider.decline(f.id);
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: AppTheme.danger));
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                tooltip: l10n.friendsCancelRequest,
                icon: Icon(Icons.close_rounded, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Friend card (accepted list) ───────────────────────────────────────────────

class _FriendCard extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;

  const _FriendCard({required this.name, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _Avatar(name: name, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact info row ─────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ContactRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// ─── Shared avatar widget ──────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final double size;

  const _Avatar({required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final colors = avatarColors(name);
    final initials = avatarInitials(name);
    return Container(
      width: size,
      height: size,
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
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.33,
        ),
      ),
    );
  }
}
