import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? referenceId;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.referenceId,
    this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    return AppNotification(
      id: m['id'] as String,
      type: m['type'] as String,
      title: m['title'] as String,
      body: m['body'] as String? ?? '',
      referenceId: m['reference_id'] as String?,
      metadata: m['metadata'] as Map<String, dynamic>?,
      isRead: m['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      referenceId: referenceId,
      metadata: metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  String get iconEmoji {
    switch (type) {
      case 'event_invite':          return '🎉';
      case 'event_invite_accepted': return '🎊';
      case 'event_invite_declined': return '💔';
      case 'event_kicked':          return '🚪';
      case 'session_join_request':  return '✋';
      case 'session_approved':      return '⭐';
      case 'session_rejected':      return '❌';
      case 'session_demoted':       return '⬇️';
      case 'session_promoted':      return '🚀';
      case 'session_removed':       return '⚡';
      case 'friend_request':        return '💌';
      case 'friend_accepted':       return '🏅';
      default:                      return '📢';
    }
  }

  IconData get icon {
    switch (type) {
      case 'event_invite':
        return Icons.mail_outline_rounded;
      case 'event_invite_accepted':
        return Icons.check_circle_outline_rounded;
      case 'event_invite_declined':
        return Icons.cancel_outlined;
      case 'event_kicked':
        return Icons.exit_to_app_rounded;
      case 'session_join_request':
        return Icons.person_add_alt_1_outlined;
      case 'session_approved':
        return Icons.check_circle_outline_rounded;
      case 'session_rejected':
        return Icons.cancel_outlined;
      case 'session_demoted':
        return Icons.arrow_downward_rounded;
      case 'session_removed':
        return Icons.exit_to_app_rounded;
      case 'session_promoted':
        return Icons.celebration_outlined;
      case 'friend_request':
        return Icons.person_add_alt_outlined;
      case 'friend_accepted':
        return Icons.people_outline_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'event_invite':
      case 'session_join_request':
      case 'friend_request':
        return const Color(0xFF5B21B6);
      case 'event_invite_accepted':
      case 'session_approved':
      case 'session_promoted':
      case 'friend_accepted':
        return const Color(0xFF059669);
      case 'event_invite_declined':
      case 'session_rejected':
      case 'event_kicked':
      case 'session_removed':
        return const Color(0xFFDC2626);
      case 'session_demoted':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get targetRoute {
    switch (type) {
      case 'event_invite':
      case 'event_invite_accepted':
      case 'event_invite_declined':
        return referenceId != null ? '/event/$referenceId' : '/events';
      case 'event_kicked':
        return '/events';
      case 'session_join_request':
      case 'session_approved':
      case 'session_rejected':
      case 'session_demoted':
      case 'session_promoted':
      case 'session_removed':
        // metadata contains event_id; ?tab=session opens the Session tab directly
        final eventId = metadata?['event_id'] as String?;
        return eventId != null ? '/event/$eventId?tab=session' : '/events';
      case 'friend_request':
      case 'friend_accepted':
        return '/friends';
      default:
        return '/events';
    }
  }
}

class NotificationsProvider extends ChangeNotifier with WidgetsBindingObserver {
  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;

  List<AppNotification> _notifications = [];
  RealtimeChannel? _channel;
  Timer? _pollTimer;
  bool _isLoading = false;

  NotificationsProvider();

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Test-only: seed the in-memory list without a Supabase connection.
  // ignore: avoid_setters_without_getters
  void setNotificationsForTest(List<AppNotification> notifs) {
    _notifications = List.of(notifs);
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> init(String userId) async {
    _userId = userId;
    WidgetsBinding.instance.addObserver(this);
    await _fetch();
    _subscribe();
    _startPolling();
  }

  void clear() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    _channel = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _notifications = [];
    _userId = null;
    notifyListeners();
  }

  // Catch up on missed broadcasts the moment the app returns to foreground.
  // The WebSocket drops when iOS suspends the app, so broadcasts sent while
  // backgrounded are lost. Re-fetching + re-subscribing here fills the gap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId != null) {
      _fetch();
      _subscribe();
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_userId != null) _fetch();
    });
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  // Public so tests can verify the whitelist without a Supabase connection.
  static const tripTypes = [
    'event_invite', 'event_invite_accepted', 'event_invite_declined',
    'event_kicked',
    'session_join_request', 'session_approved', 'session_rejected',
    'session_demoted', 'session_promoted', 'session_removed',
    'friend_request', 'friend_accepted',
    'system',
  ];

  Future<void> _fetch() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _db
          .from('notifications')
          .select()
          .eq('user_id', _userId!)
          .inFilter('type', tripTypes)
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = List<Map<String, dynamic>>.from(data as List)
          .map(AppNotification.fromMap)
          .toList();
    } catch (e, st) {
      debugPrint('NotificationsProvider._fetch error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => _fetch();

  // ─── Realtime ─────────────────────────────────────────────────────────────

  void _subscribe() {
    if (_userId == null) return;
    _channel?.unsubscribe();
    // Primary: Realtime Broadcast — the DB trigger on notifications sends a
    // broadcast for every INSERT or unread UPDATE, bypassing the
    // RLS/SECURITY-DEFINER issue that prevents Postgres Changes delivery.
    // Use a full reload so upserted (refreshed) notifications are reflected
    // correctly — incremental fetch deduplicates by ID and would miss updates.
    _channel = _db
        .channel('trip_notifications_$_userId')
        .onBroadcast(
          event: 'new_notification',
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  // ─── Mutations ────────────────────────────────────────────────────────────

  Future<void> markRead(String id) async {
    if (_userId == null) return;
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx < 0 || _notifications[idx].isRead) return;

    _notifications = List.of(_notifications)
      ..[idx] = _notifications[idx].copyWith(isRead: true);
    notifyListeners();

    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', _userId!);
    } catch (e, st) {
      debugPrint('NotificationsProvider.markRead error: $e\n$st');
    }
  }

  Future<void> markAllRead() async {
    if (_userId == null) return;
    if (_notifications.every((n) => n.isRead)) return;

    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();

    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _userId!)
          .eq('is_read', false);
    } catch (e, st) {
      debugPrint('NotificationsProvider.markAllRead error: $e\n$st');
    }
  }

  Future<void> deleteNotification(String id) async {
    if (_userId == null) return;
    _notifications = _notifications.where((n) => n.id != id).toList();
    notifyListeners();

    try {
      await _db
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', _userId!);
    } catch (e, st) {
      debugPrint('NotificationsProvider.deleteNotification error: $e\n$st');
    }
  }
}
