import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;

  // True once the user has passed biometric verification (or completed a fresh
  // login). Resets to false on every cold start.
  bool _biometricVerified = false;
  bool get biometricVerified => _biometricVerified;

  void markBiometricVerified() {
    _biometricVerified = true;
    notifyListeners();
  }

  bool get isLoggedIn =>
      Supabase.instance.client.auth.currentSession != null;

  String? get userId => Supabase.instance.client.auth.currentUser?.id;

  String get userEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  String get userName {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final name = meta?['name'] as String?;
    return name?.isNotEmpty == true ? name! : userEmail.split('@').first;
  }

  Future<void> init() async {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
    notifyListeners();
  }

  /// Returns null on success, error message on failure.
  Future<String?> login(String email, String password,
      {String? captchaToken}) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
        captchaToken: captchaToken,
      );
      _biometricVerified = true; // fresh login bypasses biometric gate
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred.';
    }
  }

  /// Returns null on success, error message on failure.
  Future<String?> register(String name, String email, String password,
      {String? captchaToken}) async {
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
        captchaToken: captchaToken,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred.';
    }
  }

  /// Signs in with Google.
  ///
  /// On web: triggers a full-page OAuth redirect. Execution does not continue
  /// past this call on success. Returns null on success or silent dismissal.
  /// On native: opens the Google account picker, exchanges the ID token with
  /// Supabase, and returns null on success.
  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        return null;
      }

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) return 'Could not retrieve Google credentials.';

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      _biometricVerified = true;
      return null;
    } on AuthException catch (_) {
      return 'Google sign-in failed. Please try again.';
    } on PlatformException catch (e) {
      switch (e.code) {
        case GoogleSignIn.kSignInCanceledError:
        case GoogleSignIn.kSignInRequiredError:
          return null;
        case GoogleSignIn.kNetworkError:
          return 'No internet connection. Please check your network and try again.';
        default:
          return 'Google sign-in failed. Please try again.';
      }
    } catch (_) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  /// Signs in with Apple.
  ///
  /// Available on iOS, macOS, and web. Not shown on Android.
  Future<String?> signInWithApple() async {
    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: Uri.base.origin,
        );
        return null;
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) return 'Could not retrieve Apple credentials.';

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );
      _biometricVerified = true;
      return null;
    } on AuthException catch (_) {
      return 'Apple sign-in failed. Please try again.';
    } on SignInWithAppleAuthorizationException catch (e) {
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
        case AuthorizationErrorCode.unknown:
        case AuthorizationErrorCode.notInteractive:
          return null;
        case AuthorizationErrorCode.failed:
        case AuthorizationErrorCode.invalidResponse:
        case AuthorizationErrorCode.notHandled:
          return 'Apple sign-in failed. Please try again.';
      }
    } on SignInWithAppleNotSupportedException catch (_) {
      return 'Apple sign-in is not supported on this device.';
    } on SignInWithAppleCredentialsException catch (_) {
      return 'Apple sign-in failed. Please try again.';
    } catch (_) {
      return 'Apple sign-in failed. Please try again.';
    }
  }

  Future<void> logout() async {
    _biometricVerified = false;
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
