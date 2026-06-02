import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/connectivity_service.dart';
import '../services/local_cache.dart';
import '../services/offline_queue.dart';

/// Sentinel error key returned when a file-upload operation is attempted
/// while the device is offline.  Callers should check for this value and
/// display a user-friendly message rather than showing the raw string.
const kOfflineUploadError = 'OFFLINE_NO_CONNECTION';

class UserProfileProvider extends ChangeNotifier {
  static const _cacheKey = 'cache_profile_v1';

  UserProfile? _profile;
  bool _loading = false;
  String? _error;
  String? _userId; // Set during load(); used in clear() for cache eviction.

  UserProfile? get profile => _profile;
  bool get isLoading => _loading;
  String? get error => _error;

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  final ConnectivityService? _connectivity;
  final OfflineQueue? _queue;

  UserProfileProvider({
    ConnectivityService? connectivity,
    OfflineQueue? queue,
  })  : _connectivity = connectivity,  // ignore: prefer_initializing_formals
        _queue = queue;                // ignore: prefer_initializing_formals

  bool get _isOnline => _connectivity?.isOnline ?? true;

  // ─── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _userId = _db.auth.currentUser?.id;

      // ── Offline: serve from local cache ──────────────────────────────────
      if (!_isOnline) {
        if (_userId != null) {
          final cached = await LocalCache.loadObject('${_cacheKey}_$_userId');
          if (cached != null) _profile = UserProfile.fromJson(cached);
        }
        return;
      }

      // ── Online: fetch (or create) and refresh cache ───────────────────────
      final data = await _db
          .from('user_profiles')
          .select()
          .eq('user_id', _uid)
          .maybeSingle();

      if (data != null) {
        _profile = UserProfile.fromJson(data);
        unawaited(LocalCache.saveObject('${_cacheKey}_$_uid', data));
      } else {
        final inserted = await _db
            .from('user_profiles')
            .insert({'user_id': _uid})
            .select()
            .single();
        _profile = UserProfile.fromJson(inserted);
        unawaited(LocalCache.saveObject('${_cacheKey}_$_uid', inserted));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─── Save profile ──────────────────────────────────────────────────────────

  /// Updates the user profile. When offline the change is applied locally and
  /// queued; it will sync to Supabase as soon as connectivity is restored.
  Future<String?> save(UserProfile updated) async {
    if (_isOnline) {
      try {
        final row = await _db
            .from('user_profiles')
            .update(updated.toJson())
            .eq('user_id', _uid)
            .select()
            .single();
        _profile = UserProfile.fromJson(row);
        unawaited(LocalCache.saveObject('${_cacheKey}_$_uid', row));
        notifyListeners();
        return null;
      } catch (e) {
        return e.toString();
      }
    } else {
      // Optimistic local update + queue.
      _profile = updated;
      unawaited(LocalCache.saveObject('${_cacheKey}_$_uid', updated.toJson()));
      notifyListeners();
      await _queue?.enqueue(OfflineOperation(
        operationId: OfflineQueue.newOperationId(),
        table: 'user_profiles',
        type: OfflineOperationType.update,
        data: updated.toJson(),
        filters: {'user_id': _uid},
      ));
      return null;
    }
  }

  // ─── Avatar upload / removal ───────────────────────────────────────────────

  /// File uploads require an active connection. Returns [kOfflineUploadError]
  /// when the device is offline so callers can show a user-friendly message.
  Future<String?> uploadAvatar(XFile imageFile) async {
    if (!_isOnline) return kOfflineUploadError;

    try {
      final bytes = await imageFile.readAsBytes();
      final mime = imageFile.mimeType ?? 'image/jpeg';
      final path = '$_uid/avatar';

      await _db.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: mime),
      );

      final url = _db.storage.from('avatars').getPublicUrl(path);

      final row = await _db
          .from('user_profiles')
          .update({'avatar_url': url})
          .eq('user_id', _uid)
          .select()
          .single();
      _profile = UserProfile.fromJson(row);
      unawaited(LocalCache.saveObject('${_cacheKey}_$_uid', row));
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Requires an active connection. Returns [kOfflineUploadError] when offline.
  Future<String?> removeAvatar() async {
    if (!_isOnline) return kOfflineUploadError;

    try {
      await _db.storage.from('avatars').remove(['$_uid/avatar']);
      final row = await _db
          .from('user_profiles')
          .update({'avatar_url': ''})
          .eq('user_id', _uid)
          .select()
          .single();
      _profile = UserProfile.fromJson(row);
      unawaited(LocalCache.saveObject('${_cacheKey}_$_uid', row));
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> setMentionNotificationsEnabled(bool enabled) async {
    if (_profile == null) return;
    _profile = _profile!.copyWith(mentionNotificationsEnabled: enabled);
    notifyListeners();
    try {
      final row = await _db
          .from('user_profiles')
          .update({'mention_notifications_enabled': enabled})
          .eq('user_id', _uid)
          .select()
          .single();
      _profile = UserProfile.fromJson(row);
      unawaited(LocalCache.saveObject('${_cacheKey}_$_uid', row));
      notifyListeners();
    } catch (e) {
      // Revert optimistic update on failure.
      _profile = _profile!.copyWith(mentionNotificationsEnabled: !enabled);
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _profile = null;
    _error = null;
    if (_userId != null) unawaited(LocalCache.remove('${_cacheKey}_$_userId'));
    _userId = null;
    notifyListeners();
  }
}
