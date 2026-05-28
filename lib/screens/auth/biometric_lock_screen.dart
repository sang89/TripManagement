import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/biometric_service.dart';

/// Full-screen biometric gate shown on cold start when the user has an active
/// session and [SettingsProvider.biometricLockEnabled] is true.
///
/// On success: calls [AuthProvider.markBiometricVerified], which triggers the
/// GoRouter refresh that navigates to /trips.
///
/// On "use password instead": signs out, which triggers the router to /login.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _loading = false;
  String? _error;
  String _buttonLabel = '';
  IconData _buttonIcon = Icons.fingerprint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final service = context.read<BiometricService>();
    final types = await service.getAvailableTypes();

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    if (types.contains(BiometricType.face)) {
      setState(() {
        _buttonLabel = l10n.biometricSignInWithFace;
        _buttonIcon = Icons.face_outlined;
      });
    } else if (types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak)) {
      setState(() {
        _buttonLabel = l10n.biometricSignInWithFingerprint;
        _buttonIcon = Icons.fingerprint;
      });
    } else {
      setState(() {
        _buttonLabel = l10n.biometricSignInWithBiometrics;
        _buttonIcon = Icons.lock_open_outlined;
      });
    }

    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_loading) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = context.read<BiometricService>();
    final success = await service.authenticate(
      localizedReason: l10n.biometricReason,
    );

    if (!mounted) return;

    if (success) {
      context.read<AuthProvider>().markBiometricVerified();
      // GoRouter redirect fires automatically → /trips
    } else {
      setState(() {
        _loading = false;
        _error = l10n.biometricFailed;
      });
    }
  }

  Future<void> _usePasswordInstead() async {
    await context.read<SettingsProvider>().setBiometricLockEnabled(false);
    if (!mounted) return;
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.map_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.biometricLockTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.biometricLockSubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _authenticate,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(_buttonIcon, size: 22),
                    label: Text(
                      _buttonLabel.isEmpty
                          ? l10n.biometricSignInWithBiometrics
                          : _buttonLabel,
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                AppTappable(
                  onTap: _usePasswordInstead,
                  child: Text(
                    l10n.usePasswordInstead,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
