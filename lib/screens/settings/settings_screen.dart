import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../services/biometric_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          _AccountCard(),
          SizedBox(height: 12),
          _SecurityCard(),
          SizedBox(height: 12),
          _LanguageCard(),
          SizedBox(height: 12),
          _AboutCard(),
        ],
      ),
    );
  }
}

// ─── Shared section card ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
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
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Security Card ────────────────────────────────────────────────────────────

class _SecurityCard extends StatefulWidget {
  const _SecurityCard();

  @override
  State<_SecurityCard> createState() => _SecurityCardState();
}

class _SecurityCardState extends State<_SecurityCard> {
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final available = await context.read<BiometricService>().isAvailable();
    if (mounted) setState(() => _available = available);
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final enabled = context.watch<SettingsProvider>().biometricLockEnabled;
    return _SectionCard(
      title: l10n.securitySectionTitle,
      icon: Icons.security_outlined,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.fingerprint),
          title: Text(l10n.biometricToggleTitle),
          subtitle: Text(
            l10n.biometricToggleSubtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          value: enabled,
          activeThumbColor: AppTheme.primary,
          activeTrackColor: AppTheme.primaryLight,
          onChanged: (v) =>
              context.read<SettingsProvider>().setBiometricLockEnabled(v),
        ),
      ],
    );
  }
}

// ─── Language data ─────────────────────────────────────────────────────────────

class _Lang {
  final Locale? locale; // null = system default
  final String flag;
  final String name;
  final String native;
  const _Lang(this.locale, this.flag, this.name, this.native);
}

const _langs = [
  _Lang(null,          '🌐', 'System Default', ''),
  _Lang(Locale('en'),  '🇺🇸', 'English',    'English'),
  _Lang(Locale('es'),  '🇪🇸', 'Spanish',    'Español'),
  _Lang(Locale('fr'),  '🇫🇷', 'French',     'Français'),
  _Lang(Locale('de'),  '🇩🇪', 'German',     'Deutsch'),
  _Lang(Locale('pt'),  '🇧🇷', 'Portuguese', 'Português'),
  _Lang(Locale('vi'),  '🇻🇳', 'Vietnamese', 'Tiếng Việt'),
  _Lang(Locale('zh'),  '🇨🇳', 'Chinese',    '中文'),
  _Lang(Locale('ja'),  '🇯🇵', 'Japanese',   '日本語'),
  _Lang(Locale('ko'),  '🇰🇷', 'Korean',     '한국어'),
  _Lang(Locale('ar'),  '🇸🇦', 'Arabic',     'العربية'),
];

// ─── Language Card ─────────────────────────────────────────────────────────────

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  _Lang _currentLang(Locale? locale) => _langs.firstWhere(
        (l) => l.locale == locale,
        orElse: () => _langs.first,
      );

  void _showPicker(BuildContext context, Locale? current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).selectLanguageTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: _langs.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final lang = _langs[i];
                  final selected = lang.locale == current;
                  return ListTile(
                    leading: Text(
                      lang.flag,
                      style: const TextStyle(fontSize: 26),
                    ),
                    title: Text(lang.name),
                    subtitle: lang.native.isNotEmpty &&
                            lang.native != lang.name
                        ? Text(
                            lang.native,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          )
                        : null,
                    trailing: selected
                        ? const Icon(Icons.check, color: AppTheme.accent)
                        : null,
                    onTap: () {
                      context.read<SettingsProvider>().setLocale(lang.locale);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<SettingsProvider>().locale;
    final lang = _currentLang(locale);
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      title: l10n.languageSectionTitle,
      icon: Icons.language,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Text(lang.flag, style: const TextStyle(fontSize: 26)),
          title: Text(lang.name),
          subtitle: lang.native.isNotEmpty && lang.native != lang.name
              ? Text(lang.native,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]))
              : null,
          trailing: const Icon(Icons.expand_more),
          onTap: () => _showPicker(context, locale),
        ),
      ],
    );
  }
}

// ─── Account Card ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChangePasswordSheet(parentContext: context),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n2 = AppLocalizations.of(context);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n2.deleteAccountTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n2.deleteAccountInstructions),
            const SizedBox(height: 16),
            Text(
              l10n2.supportEmail,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n2.close),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: l10n2.supportEmail));
              Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(content: Text(l10n2.emailCopied)),
              );
            },
            child: Text(l10n2.copyEmail),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      title: l10n.accountSectionTitle,
      icon: Icons.manage_accounts_outlined,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.changePasswordTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showChangePasswordSheet(context),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.delete_forever_outlined,
            color: AppTheme.danger,
          ),
          title: Text(
            l10n.deleteAccountTitle,
            style: const TextStyle(color: AppTheme.danger),
          ),
          trailing:
              const Icon(Icons.chevron_right, color: AppTheme.danger),
          onTap: () => _showDeleteAccountDialog(context),
        ),
      ],
    );
  }
}

// ─── Change Password Sheet ─────────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  final BuildContext parentContext;

  const _ChangePasswordSheet({required this.parentContext});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final parentMessenger = ScaffoldMessenger.of(widget.parentContext);
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? '';
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _currentCtrl.text,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newCtrl.text),
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      Navigator.pop(context);
      parentMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.passwordUpdated),
          backgroundColor: AppTheme.accent,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final l10n = AppLocalizations.of(context);
      final message = e.message.toLowerCase().contains('invalid')
          ? l10n.currentPasswordIncorrect
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message), backgroundColor: AppTheme.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failed(e.toString())),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.changePasswordTitle,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: l10n.currentPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                      () => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: l10n.newPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.required;
                if (v.length < 8) return l10n.passwordMinLength;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: l10n.confirmNewPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                      () => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.required;
                if (v != _newCtrl.text) return l10n.passwordsDoNotMatch;
                return null;
              },
            ),
            const SizedBox(height: 24),
            AppButton(
              label: l10n.updatePassword,
              onPressed: _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── About Card ────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context).comingSoon(feature))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      title: l10n.aboutSectionTitle,
      icon: Icons.info_outline,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tag),
          title: Text(l10n.appVersion),
          trailing: Text(
            '1.0.0+1',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(l10n.privacyPolicy),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => _comingSoon(context, l10n.privacyPolicy),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel_outlined),
          title: Text(l10n.termsOfService),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => _comingSoon(context, l10n.termsOfService),
        ),
      ],
    );
  }
}
