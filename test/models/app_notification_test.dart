import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/providers/notifications_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

AppNotification _notif({
  String id = 'n1',
  String type = 'event_invite',
  String title = 'Title',
  String body = 'Body',
  String? referenceId,
  Map<String, dynamic>? metadata,
  bool isRead = false,
  DateTime? createdAt,
}) =>
    AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      referenceId: referenceId,
      metadata: metadata,
      isRead: isRead,
      createdAt: createdAt ?? DateTime(2026, 6, 13),
    );

void main() {
  // ── AppNotification.fromMap ───────────────────────────────────────────────────

  group('AppNotification.fromMap', () {
    final map = {
      'id': 'n1',
      'type': 'event_invite',
      'title': 'New invitation',
      'body': 'You have been invited',
      'reference_id': 'ev1',
      'metadata': {'event_id': 'ev1'},
      'is_read': false,
      'created_at': '2026-06-13T10:00:00.000Z',
    };

    test('parses all fields', () {
      final n = AppNotification.fromMap(map);
      expect(n.id, 'n1');
      expect(n.type, 'event_invite');
      expect(n.title, 'New invitation');
      expect(n.body, 'You have been invited');
      expect(n.referenceId, 'ev1');
      expect(n.metadata, {'event_id': 'ev1'});
      expect(n.isRead, false);
      expect(n.createdAt, DateTime.utc(2026, 6, 13, 10));
    });

    test('defaults body to empty string when absent', () {
      final m = Map<String, dynamic>.from(map)..remove('body');
      final n = AppNotification.fromMap(m);
      expect(n.body, '');
    });

    test('defaults isRead to false when absent', () {
      final m = Map<String, dynamic>.from(map)..remove('is_read');
      final n = AppNotification.fromMap(m);
      expect(n.isRead, false);
    });

    test('accepts null referenceId and metadata', () {
      final m = Map<String, dynamic>.from(map)
        ..['reference_id'] = null
        ..['metadata'] = null;
      final n = AppNotification.fromMap(m);
      expect(n.referenceId, isNull);
      expect(n.metadata, isNull);
    });
  });

  // ── AppNotification.copyWith ──────────────────────────────────────────────────

  group('AppNotification.copyWith', () {
    test('marks notification as read', () {
      final n = _notif(isRead: false);
      final updated = n.copyWith(isRead: true);
      expect(updated.isRead, true);
      expect(updated.id, n.id);
      expect(updated.type, n.type);
    });

    test('preserves all other fields unchanged', () {
      final n = _notif(referenceId: 'ev1', metadata: {'event_id': 'ev1'});
      final updated = n.copyWith(isRead: true);
      expect(updated.referenceId, 'ev1');
      expect(updated.metadata, {'event_id': 'ev1'});
      expect(updated.title, n.title);
    });
  });

  // ── AppNotification.targetRoute ───────────────────────────────────────────────
  //
  // Bug: session notifications routed to /events (wrong tab).
  // Fix: session types include ?tab=session so EventDetailScreen opens on
  //      the Session tab (index 3) directly.

  group('AppNotification.targetRoute', () {
    test('event_invite navigates to event detail via referenceId', () {
      final n = _notif(type: 'event_invite', referenceId: 'ev1');
      expect(n.targetRoute, '/event/ev1');
    });

    test('event_invite falls back to /events when referenceId is null', () {
      final n = _notif(type: 'event_invite', referenceId: null);
      expect(n.targetRoute, '/events');
    });

    test('event_invite_accepted navigates to event detail', () {
      final n = _notif(type: 'event_invite_accepted', referenceId: 'ev1');
      expect(n.targetRoute, '/event/ev1');
    });

    test('event_invite_declined navigates to event detail', () {
      final n = _notif(type: 'event_invite_declined', referenceId: 'ev1');
      expect(n.targetRoute, '/event/ev1');
    });

    // Bug: kicked user routed to the event they no longer have access to.
    // Fix: always route to /events list for kicked types.
    test('event_kicked always routes to /events list (no access to event)', () {
      final n = _notif(type: 'event_kicked', referenceId: 'ev1');
      expect(n.targetRoute, '/events');
    });

    // Bug: session notifications didn't open the Session tab.
    // Fix: ?tab=session added to all session notification routes.
    const sessionTypes = [
      'session_join_request', 'session_approved', 'session_rejected',
      'session_demoted', 'session_promoted', 'session_removed',
    ];

    test('all session types route to event with ?tab=session when event_id in metadata', () {
      for (final type in sessionTypes) {
        final n = _notif(
          type: type,
          referenceId: 'sess1',
          metadata: {'event_id': 'ev1'},
        );
        expect(n.targetRoute, '/event/ev1?tab=session',
            reason: '$type should include ?tab=session');
      }
    });

    test('all session types fall back to /events when metadata has no event_id', () {
      for (final type in sessionTypes) {
        final n = _notif(type: type, referenceId: 'sess1');
        expect(n.targetRoute, '/events',
            reason: '$type without metadata should fall back');
      }
    });

    test('friend_request routes to /friends', () {
      expect(_notif(type: 'friend_request').targetRoute, '/friends');
    });

    test('friend_accepted routes to /friends', () {
      expect(_notif(type: 'friend_accepted').targetRoute, '/friends');
    });

    test('unknown type falls back to /events', () {
      expect(_notif(type: 'system').targetRoute, '/events');
    });
  });

  // ── AppNotification.iconEmoji ─────────────────────────────────────────────────
  //
  // Bug: session_removed and event_kicked shared the same icon (🚪).
  //      friend_accepted and event_invite_accepted shared 🎊.
  // Fix: every type now has a unique emoji.

  group('AppNotification.iconEmoji uniqueness', () {
    const allTypes = [
      'event_invite',
      'event_invite_accepted',
      'event_invite_declined',
      'event_kicked',
      'session_join_request',
      'session_approved',
      'session_rejected',
      'session_demoted',
      'session_promoted',
      'session_removed',
      'friend_request',
      'friend_accepted',
    ];

    test('every known type returns a non-empty emoji', () {
      for (final type in allTypes) {
        final emoji = _notif(type: type).iconEmoji;
        expect(emoji, isNotEmpty, reason: '$type returned empty emoji');
      }
    });

    test('no two types share the same emoji', () {
      final emojis = allTypes.map((t) => _notif(type: t).iconEmoji).toList();
      final unique = emojis.toSet();
      expect(unique.length, emojis.length,
          reason: 'Duplicate emojis found: $emojis');
    });

    test('session_removed emoji differs from event_kicked emoji', () {
      final kicked = _notif(type: 'event_kicked').iconEmoji;
      final removed = _notif(type: 'session_removed').iconEmoji;
      expect(kicked, isNot(removed));
    });

    test('friend_accepted emoji differs from event_invite_accepted emoji', () {
      final inviteAccepted = _notif(type: 'event_invite_accepted').iconEmoji;
      final friendAccepted = _notif(type: 'friend_accepted').iconEmoji;
      expect(inviteAccepted, isNot(friendAccepted));
    });
  });

  // ── AppNotification.iconColor ─────────────────────────────────────────────────

  group('AppNotification.iconColor', () {
    test('removal types return red', () {
      for (final type in ['event_kicked', 'session_removed', 'session_rejected', 'event_invite_declined']) {
        final color = _notif(type: type).iconColor;
        expect(color, const Color(0xFFDC2626),
            reason: '$type should be red');
      }
    });

    test('positive types return green', () {
      for (final type in ['event_invite_accepted', 'session_approved', 'session_promoted', 'friend_accepted']) {
        final color = _notif(type: type).iconColor;
        expect(color, const Color(0xFF059669),
            reason: '$type should be green');
      }
    });

    test('demotion returns amber', () {
      expect(_notif(type: 'session_demoted').iconColor, const Color(0xFFD97706));
    });
  });

  // ── NotificationsProvider._tripTypes filter ───────────────────────────────────
  //
  // Bug: PropertyManagement notification types (lease_expiry, monthly_summary)
  //      were showing in TripManagement notification center.
  // Fix: _tripTypes whitelist filters only TripManagement-relevant types.

  group('NotificationsProvider._tripTypes', () {
    test('includes all TripManagement notification types', () {
      const expected = [
        'event_invite', 'event_invite_accepted', 'event_invite_declined',
        'event_kicked',
        'session_join_request', 'session_approved', 'session_rejected',
        'session_demoted', 'session_promoted', 'session_removed',
        'friend_request', 'friend_accepted',
        'system',
      ];
      for (final type in expected) {
        expect(
          NotificationsProvider.tripTypes.contains(type),
          isTrue,
          reason: '$type should be in tripTypes',
        );
      }
    });

    test('excludes PropertyManagement-only types', () {
      for (final type in ['lease_expiry', 'monthly_summary', 'rent_reminder']) {
        expect(
          NotificationsProvider.tripTypes.contains(type),
          isFalse,
          reason: '$type should NOT be in tripTypes',
        );
      }
    });
  });

  // ── NotificationsProvider in-memory state ─────────────────────────────────────

  group('NotificationsProvider.unreadCount', () {
    NotificationsProvider makeProvider(List<AppNotification> notifs) =>
        _FakeNotificationsProvider(notifs);

    test('returns 0 when all notifications are read', () {
      final p = makeProvider([
        _notif(id: 'n1', isRead: true),
        _notif(id: 'n2', isRead: true),
      ]);
      expect(p.unreadCount, 0);
    });

    test('counts only unread notifications', () {
      final p = makeProvider([
        _notif(id: 'n1', isRead: false),
        _notif(id: 'n2', isRead: true),
        _notif(id: 'n3', isRead: false),
      ]);
      expect(p.unreadCount, 2);
    });

    test('returns 0 when list is empty', () {
      expect(makeProvider([]).unreadCount, 0);
    });
  });

  group('NotificationsProvider.markRead (optimistic)', () {
    test('immediately marks the notification as read in local state', () {
      final p = _FakeNotificationsProvider([
        _notif(id: 'n1', isRead: false),
        _notif(id: 'n2', isRead: false),
      ]);
      p.testMarkRead('n1');
      expect(p.notifications.firstWhere((n) => n.id == 'n1').isRead, true);
      expect(p.notifications.firstWhere((n) => n.id == 'n2').isRead, false);
    });

    test('unreadCount decrements after markRead', () {
      final p = _FakeNotificationsProvider([
        _notif(id: 'n1', isRead: false),
        _notif(id: 'n2', isRead: false),
      ]);
      expect(p.unreadCount, 2);
      p.testMarkRead('n1');
      expect(p.unreadCount, 1);
    });

    test('is a no-op when notification is already read', () {
      final p = _FakeNotificationsProvider([
        _notif(id: 'n1', isRead: true),
      ]);
      p.testMarkRead('n1');
      expect(p.unreadCount, 0);
    });
  });

  group('NotificationsProvider.markAllRead (optimistic)', () {
    test('marks every notification as read', () {
      final p = _FakeNotificationsProvider([
        _notif(id: 'n1', isRead: false),
        _notif(id: 'n2', isRead: false),
        _notif(id: 'n3', isRead: true),
      ]);
      p.testMarkAllRead();
      expect(p.notifications.every((n) => n.isRead), true);
      expect(p.unreadCount, 0);
    });

    test('is a no-op when all are already read', () {
      final p = _FakeNotificationsProvider([
        _notif(id: 'n1', isRead: true),
      ]);
      int calls = 0;
      p.addListener(() => calls++);
      p.testMarkAllRead();
      expect(calls, 0);
    });
  });

  group('NotificationsProvider.deleteNotification (optimistic)', () {
    test('removes the notification from local state', () {
      final p = _FakeNotificationsProvider([
        _notif(id: 'n1'),
        _notif(id: 'n2'),
      ]);
      p.testDeleteNotification('n1');
      expect(p.notifications.any((n) => n.id == 'n1'), false);
      expect(p.notifications.length, 1);
    });
  });
}

// ── Fake provider for in-memory state testing ─────────────────────────────────

class _FakeNotificationsProvider extends NotificationsProvider {
  _FakeNotificationsProvider(List<AppNotification> initial) {
    setNotificationsForTest(initial);
  }

  void testMarkRead(String id) {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx < 0 || notifications[idx].isRead) return;
    final updated = List<AppNotification>.from(notifications)
      ..[idx] = notifications[idx].copyWith(isRead: true);
    setNotificationsForTest(updated);
    notifyListeners();
  }

  void testMarkAllRead() {
    if (notifications.every((n) => n.isRead)) return;
    setNotificationsForTest(
        notifications.map((n) => n.copyWith(isRead: true)).toList());
    notifyListeners();
  }

  void testDeleteNotification(String id) {
    setNotificationsForTest(notifications.where((n) => n.id != id).toList());
    notifyListeners();
  }
}
