import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_provider.dart';

/// A single pending trip-type event invitation for the current user.
class InvitationItem {
  final String guestId;
  final String eventId;
  final String eventTitle;
  final String? destination;
  final DateTime? startAt;
  final DateTime? endAt;
  final String organiserName;

  const InvitationItem({
    required this.guestId,
    required this.eventId,
    required this.eventTitle,
    this.destination,
    this.startAt,
    this.endAt,
    required this.organiserName,
  });
}

/// Provides the list of pending trip-type event invitations for the signed-in user.
///
/// Uses Supabase Realtime to update in real time when a new invite arrives.
/// Call [init] after sign-in and [clear] on sign-out.
class InvitationsProvider extends ChangeNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  List<InvitationItem> _invites = [];
  RealtimeChannel? _channel;
  String? _userId;

  int get pendingCount => _invites.length;
  List<InvitationItem> get invites => List.unmodifiable(_invites);

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> init(String userId) async {
    _userId = userId;
    await _fetch();
    _subscribe();
  }

  void clear() {
    _channel?.unsubscribe();
    _channel = null;
    _invites = [];
    _userId = null;
    notifyListeners();
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (_userId == null) return;
    try {
      final data = await _db
          .from('event_guests')
          .select('id, event_id, events(title, location, start_at, end_at)')
          .eq('user_id', _userId!)
          .eq('status', 'pending');

      final rows = List<Map<String, dynamic>>.from(data as List);
      _invites = rows.map((row) {
        final event = row['events'] as Map<String, dynamic>? ?? {};
        return InvitationItem(
          guestId: row['id'] as String,
          eventId: row['event_id'] as String,
          eventTitle: event['title'] as String? ?? 'Event',
          destination: event['location'] as String?,
          startAt: event['start_at'] != null
              ? DateTime.parse(event['start_at'] as String)
              : null,
          endAt: event['end_at'] != null
              ? DateTime.parse(event['end_at'] as String)
              : null,
          organiserName: 'Someone',
        );
      }).toList();
    } catch (e, st) {
      debugPrint('InvitationsProvider._fetch error: $e\n$st');
    }
    notifyListeners();
  }

  // ─── Realtime subscription ────────────────────────────────────────────────

  void _subscribe() {
    if (_userId == null) return;
    _channel?.unsubscribe();
    _channel = _db
        .channel('invites_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_guests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (_) => _fetch(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_guests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId!,
          ),
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Accept a pending invite. Reloads [eventProvider] so the event appears.
  Future<void> accept(String guestId, EventProvider eventProvider) async {
    try {
      await _db
          .from('event_guests')
          .update({'status': 'accepted'})
          .eq('id', guestId);
      _invites.removeWhere((i) => i.guestId == guestId);
      notifyListeners();
      await eventProvider.load();
    } catch (e, st) {
      debugPrint('InvitationsProvider.accept error: $e\n$st');
      rethrow;
    }
  }

  /// Decline a pending invite.
  Future<void> decline(
    String guestId,
    EventProvider eventProvider, {
    bool blockReinvite = false,
  }) async {
    try {
      await _db.from('event_guests').update({
        'status': 'declined',
        if (blockReinvite) 'block_reinvite': true,
      }).eq('id', guestId);
      _invites.removeWhere((i) => i.guestId == guestId);
      notifyListeners();
      await eventProvider.load();
    } catch (e, st) {
      debugPrint('InvitationsProvider.decline error: $e\n$st');
      rethrow;
    }
  }
}
