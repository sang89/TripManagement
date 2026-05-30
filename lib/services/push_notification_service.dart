import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages FCM push notifications: token registration, permission requests,
/// and routing tap-to-open actions to the Trips screen.
///
/// Call [init] once after sign-in, after [Firebase.initializeApp] has run.
/// If [onTripInviteTap] is provided it is called when the user taps a
/// trip_invite notification (foreground or cold-start).
class PushNotificationService {
  final void Function()? onTripInviteTap;

  PushNotificationService({this.onTripInviteTap});

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> init() async {
    // Push is only available on real mobile devices — skip on web / desktop.
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;

    // 1. Request permission (iOS prompt; Android 13+ POST_NOTIFICATIONS).
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      'PushNotificationService: permission=${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 2. Get the FCM token and persist it.
    //    On iOS, getToken() throws if the APNS token hasn't been set yet.
    //    Check it first; if absent, onTokenRefresh (step 3) will deliver the
    //    FCM token once iOS sets the APNS token in the background.
    if (Platform.isIOS) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('PushNotificationService: APNS token not ready, relying on onTokenRefresh');
      } else {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _saveToken(token);
      }
    } else {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
    }

    // 3. Listen for token refreshes.
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

    // 4. Handle notification tap when app was terminated (cold start).
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    _handleMessage(initial);

    // 5. Handle notification tap when app was backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  Future<void> _saveToken(String token) async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _db.from('device_tokens').upsert(
        {'user_id': uid, 'token': token, 'platform': platform},
        onConflict: 'user_id, token',
      );
      debugPrint('PushNotificationService: token saved ($platform)');
    } catch (e, st) {
      debugPrint('PushNotificationService._saveToken error: $e\n$st');
    }
  }

  /// Remove the current device token on sign-out so the user no longer
  /// receives notifications on this device.
  Future<void> removeToken() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return;
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;
      // Same APNS guard as init() — skip silently if token never arrived.
      if (Platform.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _db
          .from('device_tokens')
          .delete()
          .eq('user_id', uid)
          .eq('token', token);
    } catch (e, st) {
      debugPrint('PushNotificationService.removeToken error: $e\n$st');
    }
  }

  void _handleMessage(RemoteMessage? message) {
    if (message == null) return;
    final type = message.data['type'] as String?;
    if (type == 'trip_invite') {
      onTripInviteTap?.call();
    }
  }
}
