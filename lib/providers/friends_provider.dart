import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friendship.dart';

/// Manages the signed-in user's friend list and pending friend requests.
///
/// Call [init] after sign-in and [clear] on sign-out.
/// Two Realtime channels watch the `friendships` table — one filtered on
/// `requester_id` and one on `addressee_id` — because Supabase Realtime
/// only supports single-column equality filters.
class FriendsProvider extends ChangeNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  List<Friendship> _friendships = [];
  RealtimeChannel? _reqChannel;
  RealtimeChannel? _addrChannel;
  String? _userId;

  // ─── Computed views ───────────────────────────────────────────────────────

  List<Friendship> get accepted =>
      List.unmodifiable(_friendships.where((f) => f.status == 'accepted'));

  List<Friendship> get incomingRequests => List.unmodifiable(_friendships
      .where((f) => f.addresseeId == _userId && f.status == 'pending'));

  List<Friendship> get outgoingRequests => List.unmodifiable(_friendships
      .where((f) => f.requesterId == _userId && f.status == 'pending'));

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> init(String userId) async {
    _userId = userId;
    await _fetch();
    _subscribe();
  }

  void clear() {
    _reqChannel?.unsubscribe();
    _addrChannel?.unsubscribe();
    _reqChannel = null;
    _addrChannel = null;
    _friendships = [];
    _userId = null;
    notifyListeners();
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    if (_userId == null) return;
    try {
      final data = await _db
          .from('friendships')
          .select('id, requester_id, addressee_id, status, created_at')
          .or('requester_id.eq.$_userId,addressee_id.eq.$_userId')
          .not('status', 'eq', 'removed');

      final rows = List<Map<String, dynamic>>.from(data as List);
      final raw = rows.map(Friendship.fromJson).toList();
      _friendships = await _enrichNames(raw);
    } catch (e, st) {
      debugPrint('FriendsProvider._fetch error: $e\n$st');
    }
    notifyListeners();
  }

  Future<List<Friendship>> _enrichNames(List<Friendship> list) async {
    if (list.isEmpty || _userId == null) return list;
    final otherIds =
        list.map((f) => f.otherUserId(_userId!)).toSet().toList();
    try {
      final profiles = await _db.rpc(
        'get_trip_profile_names',
        params: {'p_user_ids': otherIds},
      ) as List<dynamic>;

      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles) {
        final m = p as Map<String, dynamic>;
        profileMap[m['user_id'] as String] = m;
      }

      return list.map((f) {
        final otherId = f.otherUserId(_userId!);
        final p = profileMap[otherId];
        return f.copyWith(
          otherDisplayName: p?['full_name'] as String? ?? '',
          otherEmail: p?['email'] as String?,
          otherPhone: p?['phone'] as String?,
        );
      }).toList();
    } catch (_) {
      return list;
    }
  }

  // ─── Realtime subscription ────────────────────────────────────────────────

  void _subscribe() {
    if (_userId == null) return;
    _reqChannel?.unsubscribe();
    _addrChannel?.unsubscribe();

    _reqChannel = _db
        .channel('friends_req_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'requester_id',
            value: _userId!,
          ),
          callback: (_) => _fetch(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'requester_id',
            value: _userId!,
          ),
          callback: (_) => _fetch(),
        )
        .subscribe();

    _addrChannel = _db
        .channel('friends_addr_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'addressee_id',
            value: _userId!,
          ),
          callback: (_) => _fetch(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'addressee_id',
            value: _userId!,
          ),
          callback: (_) => _fetch(),
        )
        .subscribe();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> sendRequest(String addresseeId) async {
    if (_userId == null) return;
    await _db.from('friendships').insert({
      'requester_id': _userId,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
    // Realtime will trigger _fetch(); no manual optimistic update needed.
  }

  Future<void> accept(String friendshipId) async {
    await _db
        .from('friendships')
        .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', friendshipId);
  }

  Future<void> decline(String friendshipId) async {
    await _db
        .from('friendships')
        .update({'status': 'declined', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', friendshipId);
  }

  Future<void> remove(String friendshipId) async {
    await _db
        .from('friendships')
        .update({'status': 'removed', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', friendshipId);
  }

  /// Searches for users by name or email, excluding existing friends/requests.
  /// Returns a list of `{'userId': ..., 'fullName': ..., 'email': ...}` maps.
  Future<List<Map<String, String>>> searchUsers(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final data = await _db.rpc(
        'search_users',
        params: {'p_query': query.trim()},
      ) as List<dynamic>;
      return data.map((e) {
        final m = e as Map<String, dynamic>;
        return {
          'userId': m['user_id'] as String,
          'fullName': m['full_name'] as String? ?? '',
          'email': m['email'] as String? ?? '',
        };
      }).toList();
    } catch (e, st) {
      debugPrint('FriendsProvider.searchUsers error: $e\n$st');
      return [];
    }
  }
}
