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
          Consumer<FriendsProvider>(
            builder: (context, friends, _) {
              final accepted = friends.accepted;
              if (accepted.isEmpty) return const SizedBox.shrink();
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
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: accepted.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final f = accepted[i];
                        return ActionChip(
                          avatar: CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                avatarColors(f.otherDisplayName ?? '').first,
                            child: Text(
                              avatarInitials(f.otherDisplayName ?? ''),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          label: Text(f.otherDisplayName ?? ''),
                          onPressed: () => _prefillFriend(f),
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
