import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for caching Supabase query results
/// locally so the app can serve stale data when the device is offline.
///
/// Keys should be versioned and namespaced by `userId`:
/// ```dart
/// static const _cacheKey = 'cache_trips_v1';
/// // actual key used: '$_cacheKey_$userId'
/// ```
///
/// The cache stores the **raw Supabase JSON** (same structure that `fromJson`
/// expects), so there is no separate serialisation step in the providers.
///
/// All methods swallow I/O errors (logged via [debugPrint]) so a transient
/// SharedPreferences failure never breaks the app.
class LocalCache {
  LocalCache._();

  // ─── List helpers ─────────────────────────────────────────────────────────

  /// Persist [rows] as a JSON-encoded list under [key].
  static Future<void> saveList(
    String key,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(rows));
    } catch (e) {
      debugPrint('[LocalCache] $e');
    }
  }

  /// Load and decode a list previously saved with [saveList].
  ///
  /// Returns `null` if the key is absent or the stored JSON is corrupt.
  static Future<List<Map<String, dynamic>>?> loadList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('[LocalCache] $e');
      return null;
    }
  }

  // ─── Single-object helpers ────────────────────────────────────────────────

  /// Persist a single [obj] as JSON under [key].
  static Future<void> saveObject(
    String key,
    Map<String, dynamic> obj,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(obj));
    } catch (e) {
      debugPrint('[LocalCache] $e');
    }
  }

  /// Load and decode an object previously saved with [saveObject].
  ///
  /// Returns `null` if the key is absent or the stored JSON is corrupt.
  static Future<Map<String, dynamic>?> loadObject(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('[LocalCache] $e');
      return null;
    }
  }

  // ─── Eviction ─────────────────────────────────────────────────────────────

  /// Remove the value stored under [key]. No-op if the key is absent.
  static Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      debugPrint('[LocalCache] $e');
    }
  }
}
