import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trip_provider.dart';

/// A single pending trip invitation for the current user.
class InvitationItem {
  final String memberId;
  final String tripId;
  final String tripTitle;
  final String? destination;
  final DateTime? startAt;
  final DateTime? endAt;
  final String organiserName;

  const InvitationItem({
    required this.memberId,
    required this.tripId,
    required this.tripTitle,
    this.destination,
    this.startAt,
    this.endAt,
    required this.organiserName,
  });
}

/// Provides the list of pending trip invitations for the signed-in user.
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
          .from('trip_members')
          .select('id, trip_id, trips(title, destination, start_at, end_at)')
          .eq('user_id', _userId!)
          .eq('status', 'pending');

      final rows = List<Map<String, dynamic>>.from(data as List);
      _invites = rows.map((row) {
        final trip = row['trips'] as Map<String, dynamic>? ?? {};
        return InvitationItem(
          memberId: row['id'] as String,
          tripId: row['trip_id'] as String,
          tripTitle: trip['title'] as String? ?? 'Trip',
          destination: trip['destination'] as String?,
          startAt: trip['start_at'] != null
              ? DateTime.parse(trip['start_at'] as String)
              : null,
          endAt: trip['end_at'] != null
              ? DateTime.parse(trip['end_at'] as String)
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
          table: 'trip_members',
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
          table: 'trip_members',
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

  /// Accept a pending invite. Reloads [tripProvider] so the trip appears in
  /// the list immediately.
  Future<void> accept(String memberId, TripProvider tripProvider) async {
    try {
      await _db
          .from('trip_members')
          .update({'status': 'accepted'})
          .eq('id', memberId);
      _invites.removeWhere((i) => i.memberId == memberId);
      notifyListeners();
      // Reload trips so the newly accepted one appears.
      await tripProvider.load();
    } catch (e, st) {
      debugPrint('InvitationsProvider.accept error: $e\n$st');
      rethrow;
    }
  }

  /// Decline a pending invite. Reloads [tripProvider] so the trip is removed
  /// from the list (the invitee no longer has access once declined).
  ///
  /// If [blockReinvite] is true, also sets block_reinvite = true so that the
  /// organiser cannot re-invite this user to the same trip.
  Future<void> decline(
    String memberId,
    TripProvider tripProvider, {
    bool blockReinvite = false,
  }) async {
    try {
      await _db.from('trip_members').update({
        'status': 'declined',
        if (blockReinvite) 'block_reinvite': true,
      }).eq('id', memberId);
      _invites.removeWhere((i) => i.memberId == memberId);
      notifyListeners();
      await tripProvider.load();
    } catch (e, st) {
      debugPrint('InvitationsProvider.decline error: $e\n$st');
      rethrow;
    }
  }
}
