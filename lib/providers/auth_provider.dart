import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;

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
  Future<String?> login(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred.';
    }
  }

  /// Returns null on success, error message on failure.
  Future<String?> register(String name, String email, String password) async {
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'An unexpected error occurred.';
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
