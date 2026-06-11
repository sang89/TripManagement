import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/friendship.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../providers/friends_provider.dart';
import '../services/connectivity_service.dart';
import '../services/user_lookup_service.dart';
import '../utils/avatar_utils.dart';

/// Opens the add-member bottom sheet for a trip-type event.
Future<void> showAddMemberSheet(
  BuildContext context, {
  required String eventId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddMemberSheet(eventId: eventId),
  );
}

// ─── Lookup state ──────────────────────────────────────────────────────────────

sealed class _LookupState {}

class _LookupIdle extends _LookupState {}

class _LookupSearching extends _LookupState {}

class _LookupFound extends _LookupState {
  final LinkedUserInfo user;
  _LookupFound(this.user);
}

class _LookupNotFound extends _LookupState {}

// ─── Sheet widget ──────────────────────────────────────────────────────────────

class AddMemberSheet extends StatefulWidget {
  final String eventId;

  const AddMemberSheet({super.key, required this.eventId});

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _phone = '';
  _LookupState _lookupState = _LookupIdle();
  Timer? _debounce;
  bool _nameTouched = false;
  int _lookupGeneration = 0;
  bool _loading = false;

  // Selected friend (from the picker)
  Friendship? _selectedFriend;

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

  void _selectFriend(Friendship f) {
    final myUserId = context.read<AuthProvider>().userId ?? '';
    final otherId = f.otherUserId(myUserId);
    final name = f.otherDisplayName ?? '';
    if (name.isNotEmpty && (_nameCtrl.text.isEmpty || !_nameTouched)) {
      _nameCtrl.text = name;
      _nameTouched = true;
    }
    setState(() {
      _selectedFriend = f;
      _lookupState = _LookupFound(LinkedUserInfo(
        userId: otherId,
        fullName: name,
        jobTitle: '',
        phone: '',
        avatarUrl: '',
      ));
    });
  }

  void _clearFriend() {
    setState(() {
      _selectedFriend = null;
      _lookupState = _LookupIdle();
      _nameCtrl.clear();
      _nameTouched = false;
    });
  }

  Future<void> _openFriendPicker(List<Friendship> friends) async {
    final picked = await showModalBottomSheet<Friendship>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FriendPickerSheet(
        friends: friends,
        selectedId: _selectedFriend?.id,
      ),
    );
    if (picked != null && mounted) _selectFriend(picked);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    final userId = switch (_lookupState) {
      _LookupFound(user: final u) => u.userId,
      _ => null,
    };

    try {
      await context.read<EventProvider>().addMember(
            widget.eventId,
            displayName: name,
            email: _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            phone: _phone.isEmpty ? null : _phone,
            userId: userId,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final msg = e is ReinviteBlockedException
          ? l10n.reinviteBlockedError
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                Text(l10n.addMember,
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Friend picker field ──────────────────────────────────
                  Consumer<FriendsProvider>(
                    builder: (context, friends, _) {
                      final accepted = friends.accepted;
                      if (accepted.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FriendPickerField(
                            selected: _selectedFriend,
                            label: l10n.selectFriendOptional,
                            onTap: () => _openFriendPicker(accepted),
                            onClear: _clearFriend,
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
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
                  _LookupStatusWidget(state: _lookupState),
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
              label: l10n.addMember,
              onPressed: _submit,
              loading: _loading,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Friend picker field ───────────────────────────────────────────────────────

class _FriendPickerField extends StatelessWidget {
  final Friendship? selected;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _FriendPickerField({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = selected != null
        ? avatarColors(selected!.otherDisplayName ?? '')
        : <Color>[Colors.grey.shade300, Colors.grey.shade400];

    return AppTappable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected != null
                ? AppTheme.accent.withValues(alpha: 0.5)
                : theme.colorScheme.outline.withValues(alpha: 0.4),
            width: selected != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected != null
              ? AppTheme.accent.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            if (selected != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  avatarInitials(selected!.otherDisplayName ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected!.otherDisplayName ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.grey[500],
              ),
            ] else ...[
              Icon(Icons.people_outline_rounded,
                  size: 20, color: Colors.grey[500]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
              ),
              Icon(Icons.expand_more_rounded,
                  size: 20, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Friend picker sheet ───────────────────────────────────────────────────────

class _FriendPickerSheet extends StatefulWidget {
  final List<Friendship> friends;
  final String? selectedId;

  const _FriendPickerSheet({required this.friends, this.selectedId});

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _query.isEmpty
        ? widget.friends
        : widget.friends.where((f) {
            final name = (f.otherDisplayName ?? '').toLowerCase();
            return name.contains(_query);
          }).toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              l10n.friendsTabFriends,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchFriends,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: filtered.isEmpty ? 1 : filtered.length,
              itemBuilder: (_, i) {
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.friendsNoResults,
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ),
                  );
                }
                final f = filtered[i];
                final name = f.otherDisplayName ?? '';
                final isSelected = f.id == widget.selectedId;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: avatarColors(name),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      avatarInitials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppTheme.accent)
                      : null,
                  onTap: () => Navigator.pop(context, f),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lookup status widget ──────────────────────────────────────────────────────

class _LookupStatusWidget extends StatelessWidget {
  final _LookupState state;

  const _LookupStatusWidget({required this.state});

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
              Text(
                l10n.memberSearching,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      _LookupFound(user: final u) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _LinkedUserCard(user: u),
        ),
      _LookupNotFound() => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            l10n.memberNoAccountFound,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ),
    };
  }
}

// ─── Linked-user preview card ──────────────────────────────────────────────────

class _LinkedUserCard extends StatelessWidget {
  final LinkedUserInfo user;

  const _LinkedUserCard({required this.user});

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
