import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../utils/avatar_utils.dart';
import '../../utils/formatters.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _editing = false;
  bool _saving = false;
  bool _uploading = false;

  late final TextEditingController _nameCtrl;
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();

    final provider = context.read<UserProfileProvider>();
    if (provider.profile == null && !provider.isLoading) {
      provider.load();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showAvatarOptions(UserProfile profile) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromLibrary),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(l10n.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            if (profile.avatarUrl.isNotEmpty)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: Text(l10n.removePhoto,
                    style: const TextStyle(color: AppTheme.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    setState(() => _uploading = true);
    final error =
        await context.read<UserProfileProvider>().uploadAvatar(image);
    if (!mounted) return;
    setState(() => _uploading = false);

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      error != null
          ? SnackBar(
              content: Text(error == kOfflineUploadError
                  ? l10n.uploadRequiresConnection
                  : l10n.uploadFailed(error)),
              backgroundColor: AppTheme.danger,
            )
          : SnackBar(
              content: Text(l10n.photoUpdated),
              backgroundColor: AppTheme.accent,
            ),
    );
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploading = true);
    final error = await context.read<UserProfileProvider>().removeAvatar();
    if (!mounted) return;
    setState(() => _uploading = false);

    if (error != null) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error == kOfflineUploadError
              ? l10n.removeRequiresConnection
              : l10n.removeFailed(error)),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _enterEdit(UserProfile profile) {
    _nameCtrl.text = profile.fullName;
    _phone = profile.phone;
    setState(() => _editing = true);
  }

  void _cancelEdit() => setState(() => _editing = false);

  Future<void> _save(UserProfile current) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = current.copyWith(
      fullName: _nameCtrl.text.trim(),
      phone: _phone,
    );

    final error = await context.read<UserProfileProvider>().save(updated);

    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      error != null
          ? SnackBar(
              content: Text(l10n.profileSaveFailed(error)),
              backgroundColor: AppTheme.danger,
            )
          : SnackBar(
              content: Text(l10n.profileSaved),
              backgroundColor: AppTheme.accent,
            ),
    );
  }

  Future<void> _cancelTrial() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelTrialConfirmTitle),
        content: Text(l10n.cancelTrialConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.cancelTrial,
                style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SubscriptionProvider>().cancelTrial();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.cancelTrialSuccess)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.cancelTrialError),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.signOut,
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<UserProfileProvider>().clear();
      context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();
    final sub = context.watch<SubscriptionProvider>();
    final auth = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context);

    if (profileProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = profileProvider.profile;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.myProfile)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.failedToLoadProfile),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    context.read<UserProfileProvider>().load(),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final supaUser = Supabase.instance.client.auth.currentUser;
    final memberSinceText = supaUser?.createdAt != null
        ? formatDate(DateTime.parse(supaUser!.createdAt))
        : '—';

    final displayName =
        profile.fullName.isNotEmpty ? profile.fullName : auth.userName;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(l10n.myProfile),
        actions: _editing
            ? [
                TextButton(
                  onPressed: _cancelEdit,
                  child: Text(l10n.cancel,
                      style: const TextStyle(color: Colors.white70)),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: l10n.settingsTooltip,
                  onPressed: () => context.push('/profile/settings'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.editProfileTooltip,
                  onPressed: () => _enterEdit(profile),
                ),
              ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
                  _ProfileHeader(
                    displayName: displayName,
                    email: auth.userEmail,
                    avatarUrl: profile.avatarUrl,
                    updatedAt: profile.updatedAt,
                    uploading: _uploading,
                    isPro: sub.isPro,
                    isInTrial: sub.isInTrial,
                    trialEndsAt: sub.trialEndsAt,
                    onAvatarTap: () => _showAvatarOptions(profile),
                  ),
                  const SizedBox(height: 20),
                  _InfoCard(
                    title: l10n.personalInfoSection,
                    icon: Icons.person_outline,
                    children: [
                      _Field(
                        label: l10n.fullName,
                        value: profile.fullName,
                        controller: _nameCtrl,
                        editing: _editing,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        hint: l10n.fullNameHint,
                        validator: (v) {
                          if (v != null && v.trim().length > 100) {
                            return l10n.nameTooLong;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: l10n.contactInfoSection,
                    icon: Icons.contact_phone_outlined,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    auth.userEmail,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.lock_outline,
                                    size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 3),
                                Text(
                                  l10n.managedByAccount,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _editing
                            ? AppPhoneField(
                                label: l10n.phone,
                                initialValue: _phone,
                                onChanged: (v) => setState(() => _phone = v),
                              )
                            : _ViewRow(
                                label: l10n.phone,
                                value: profile.phone.isEmpty ? '—' : profile.phone,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AccountCard(
                    l10n: l10n,
                    memberSince: memberSinceText,
                    editing: _editing,
                    saving: _saving,
                    isInTrial: sub.isInTrial,
                    onSave: () => _save(profile),
                    onLogout: _logout,
                    onCancelTrial: _cancelTrial,
                    onUpgrade: () => context.push('/paywall'),
                  ),
                ],
          ),
        ),
    );
  }
}

// ─── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String avatarUrl;
  final DateTime updatedAt;
  final bool uploading;
  final bool isPro;
  final bool isInTrial;
  final DateTime? trialEndsAt;
  final VoidCallback onAvatarTap;

  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.updatedAt,
    required this.uploading,
    required this.isPro,
    required this.isInTrial,
    required this.trialEndsAt,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = avatarColors(displayName);
    final initials = avatarInitials(displayName);
    final cacheUrl = avatarUrl.isNotEmpty
        ? '$avatarUrl?cb=${updatedAt.millisecondsSinceEpoch}'
        : '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        children: [
          AppTappable(
            onTap: onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: uploading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : cacheUrl.isNotEmpty
                          ? Image.network(
                              cacheUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, e, st) => Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.primaryLight, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _TierBadge(isPro: isPro, isInTrial: isInTrial, trialEndsAt: trialEndsAt),
        ],
      ),
    );
  }
}

// ─── Tier Badge ────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final bool isPro;
  final bool isInTrial;
  final DateTime? trialEndsAt;

  const _TierBadge({
    required this.isPro,
    required this.isInTrial,
    required this.trialEndsAt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (isPro) {
      final label = isInTrial && trialEndsAt != null
          ? l10n.tierProTrial('${trialEndsAt!.month}/${trialEndsAt!.day}/${trialEndsAt!.year}')
          : l10n.tierPro;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded,
                size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    // Free tier — two-part upgrade badge
    return AppTappable(
      onTap: () => context.push('/paywall'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24, width: 0.5),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 13, color: Colors.white60),
                  const SizedBox(width: 5),
                  Text(
                    l10n.tierFree,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 0.5, height: 18, color: Colors.white24),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Upgrade',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

// ─── Info Card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Editable / view field ─────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final TextEditingController controller;
  final bool editing;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final String hint;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.value,
    required this.controller,
    required this.editing,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.hint = '',
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: editing
          ? TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              validator: validator,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
              ),
            )
          : _ViewRow(
              label: label,
              value: value.isEmpty ? '—' : value,
            ),
    );
  }
}

// ─── View row (label + value) ──────────────────────────────────────────────────

class _ViewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ViewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Account Card ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final AppLocalizations l10n;
  final String memberSince;
  final bool editing;
  final bool saving;
  final bool isInTrial;
  final VoidCallback onSave;
  final VoidCallback onLogout;
  final VoidCallback onCancelTrial;
  final VoidCallback onUpgrade;

  const _AccountCard({
    required this.l10n,
    required this.memberSince,
    required this.editing,
    required this.saving,
    required this.isInTrial,
    required this.onSave,
    required this.onLogout,
    required this.onCancelTrial,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.manage_accounts_outlined,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.accountSectionTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _ViewRow(label: l10n.memberSince, value: memberSince),
            const SizedBox(height: 16),
            if (editing) ...[
              AppButton(
                label: l10n.saveChanges,
                onPressed: onSave,
                loading: saving,
              ),
              const SizedBox(height: 8),
            ],
            if (isInTrial) ...[
              AppTappable(
                onTap: onUpgrade,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        l10n.upgradeNow,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onCancelTrial,
                icon: Icon(Icons.cancel_outlined, color: Colors.grey[600]),
                label: Text(l10n.cancelTrial,
                    style: TextStyle(color: Colors.grey[600])),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: AppTheme.danger),
              label: Text(l10n.signOut,
                  style: const TextStyle(color: AppTheme.danger)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: AppTheme.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
