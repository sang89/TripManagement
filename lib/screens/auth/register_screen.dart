import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import 'package:shared_ui/shared_ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await context.read<AuthProvider>().register(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
    if (!mounted) return;
    if (error == null) {
      context.go('/home');
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
        bottom: false,
        child: Column(
          children: [
          Expanded(child: Center(
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
                    l10n.createAccount,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.planNextAdventure,
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
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: l10n.fullName,
                                prefixIcon:
                                    const Icon(Icons.person_outline),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? l10n.enterYourName
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: l10n.email,
                                prefixIcon:
                                    const Icon(Icons.email_outlined),
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
                              validator: (v) => v == null || v.length < 6
                                  ? l10n.passwordMinimum6
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: l10n.confirmPassword,
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (v) => v != _passwordCtrl.text
                                  ? l10n.passwordsDoNotMatch
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              SelectableText(
                                _error!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.alreadyHaveAccount),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(l10n.signIn),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )), // Expanded + Center
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AppButton(
                  label: l10n.createAccount,
                  onPressed: _register,
                  loading: _loading,
                ),
              ),
            ),
          ),
        ], // Column children
        ), // Column
      ),
    );
  }
}
