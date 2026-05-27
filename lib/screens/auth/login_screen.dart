import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import 'package:shared_ui/shared_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _storage = FlutterSecureStorage();
  static const _keyEmail = 'saved_email';
  static const _keyPassword = 'saved_password';
  static const _keyRemember = 'remember_me';

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final remember = await _storage.read(key: _keyRemember);
    if (remember != 'true') return;
    final email = await _storage.read(key: _keyEmail);
    final password = await _storage.read(key: _keyPassword);
    if (email != null && password != null) {
      setState(() {
        _emailCtrl.text = email;
        _passwordCtrl.text = password;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveOrClearCredentials() async {
    if (_rememberMe) {
      await _storage.write(key: _keyEmail, value: _emailCtrl.text.trim());
      await _storage.write(key: _keyPassword, value: _passwordCtrl.text);
      await _storage.write(key: _keyRemember, value: 'true');
    } else {
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPassword);
      await _storage.write(key: _keyRemember, value: 'false');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await context
        .read<AuthProvider>()
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;

    if (error == null) {
      await _saveOrClearCredentials();
      if (mounted) context.go('/home');
    } else {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flight_takeoff_rounded,
                      size: 72, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appTitle,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.signInToAccount,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.email,
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              validator: (v) =>
                                  v == null || !v.contains('@')
                                      ? l10n.enterValidEmail
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) =>
                                  _loading ? null : _login(),
                              decoration: InputDecoration(
                                labelText: l10n.password,
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => v == null || v.length < 4
                                  ? l10n.passwordTooShort
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppTheme.primary,
                                  onChanged: (v) => setState(
                                      () => _rememberMe = v ?? false),
                                ),
                                AppTappable(
                                  onTap: () => setState(
                                      () => _rememberMe = !_rememberMe),
                                  child: Text(
                                    l10n.rememberMe,
                                    style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              SelectableText(
                                _error!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 16),
                            AppButton(
                              label: l10n.signIn,
                              onPressed: _login,
                              loading: _loading,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.dontHaveAccount),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: Text(l10n.signUp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
