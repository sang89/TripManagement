import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import '../models/trip_member.dart';
import '../models/trip_stop.dart';
import '../services/connectivity_service.dart';
import '../services/local_cache.dart';
import '../services/offline_queue.dart';

/// Thrown when [TripProvider.addMember] is called for a user who has opted out
/// of future invitations to a specific trip (block_reinvite = true).
class ReinviteBlockedException implements Exception {
  const ReinviteBlockedException();
}

class TripProvider extends ChangeNotifier {
  static const _uuid = Uuid();
  static const _cacheKey = 'cache_trips_v1';
  static const _orderKey = 'trips_order_v1';

  SupabaseClient get _db => Supabase.instance.client;
  List<Trip> _trips = [];
  bool _loaded = false;
  String? _loadError;
  String? _userId;
  RealtimeChannel? _realtimeChannel;

  final ConnectivityService? _connectivity;
  final OfflineQueue? _queue;

  TripProvider({this._connectivity, this._queue});

  bool get _isOnline => _connectivity?.isOnline ?? true;
  Future<void> _enqueue(OfflineOperation op) async => _queue?.enqueue(op);

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get loaded => _loaded;
  String? get loadError => _loadError;

  Trip? getById(String id) {
    try {
      return _trips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Cache serialization ───────────────────────────────────────────────────

  /// Full serialization including nested members and stops, matching the
  /// structure that [Trip.fromJson] expects from a Supabase joined query.
  ///
  /// Exposed via [tripToCacheJsonForTest] for unit tests.
  static Map<String, dynamic> _tripToCacheJson(Trip t) => {
        'id': t.id,
        'created_by': t.createdBy,
        'title': t.title,
        'start_location': t.startLocation,
        'start_lat': t.startLat,
        'start_lng': t.startLng,
        'destination': t.destination,
        'notes': t.notes,
        'destination_lat': t.destinationLat,
        'destination_lng': t.destinationLng,
        'start_at': t.startAt?.toUtc().toIso8601String(),
        'end_at': t.endAt?.toUtc().toIso8601String(),
        'created_at': t.createdAt.toIso8601String(),
        'updated_at': t.updatedAt.toIso8601String(),
        'trip_members': t.members
            .map((m) => {
                  'id': m.id,
                  'trip_id': m.tripId,
                  'display_name': m.displayName,
                  'role': m.role,
                  'user_id': m.userId,
                  'email': m.email,
                  'phone': m.phone,
                  'status': m.status,
                  'invited_by': m.invitedBy,
                  'block_reinvite': m.blockReinvite,
                  'avatar_url': m.avatarUrl,
                  'created_at': m.createdAt.toIso8601String(),
                })
            .toList(),
        'trip_stops': t.stops
            .map((s) => {
                  'id': s.id,
                  'trip_id': s.tripId,
                  'title': s.title,
                  'address': s.address,
                  'notes': s.notes,
                  'arrive_at': s.arriveAt?.toUtc().toIso8601String(),
                  'depart_at': s.departAt?.toUtc().toIso8601String(),
                  'sort_order': s.sortOrder,
                  'created_at': s.createdAt.toIso8601String(),
                  'address_lat': s.addressLat,
                  'address_lng': s.addressLng,
                })
            .toList(),
      };

  /// Test-visible alias for [_tripToCacheJson].
  @visibleForTesting
  static Map<String, dynamic> tripToCacheJsonForTest(Trip t) =>
      _tripToCacheJson(t);

  /// Persist the current in-memory state so it's available after a restart.
  /// Called after every successful mutation (online or offline).
  Future<void> _saveCache() async {
    if (_userId == null) return;
    final rows = _trips.map(_tripToCacheJson).toList();
    unawaited(LocalCache.saveList('${_cacheKey}_$_userId', rows));
  }

  // ─── Custom order ──────────────────────────────────────────────────────────

  /// Persist the current trip order (list of IDs) to local cache.
  Future<void> _saveOrder() async {
    if (_userId == null) return;
    await LocalCache.saveObject(
      '${_orderKey}_$_userId',
      {'ids': _trips.map((t) => t.id).toList()},
    );
  }

  /// Load the previously saved trip order (list of IDs), or `null` if none.
  Future<List<String>?> _loadOrder() async {
    if (_userId == null) return null;
    final obj = await LocalCache.loadObject('${_orderKey}_$_userId');
    if (obj == null) return null;
    final ids = obj['ids'];
    if (ids is! List) return null;
    return ids.cast<String>();
  }

  /// Reorder [trips] according to [order] (list of IDs).
  ///
  /// Trips whose ID appears in [order] are placed first (in that order).
  /// Any trips not present in [order] — e.g. newly fetched items — are
  /// appended to the end.
  static List<Trip> applyOrder(List<Trip> trips, List<String>? order) {
    if (order == null || order.isEmpty) return trips;
    final byId = {for (final t in trips) t.id: t};
    final result = <Trip>[];
    for (final id in order) {
      final trip = byId.remove(id);
      if (trip != null) result.add(trip);
    }
    // Append any trips not captured by the saved order (new ones).
    result.addAll(byId.values);
    return result;
  }

  /// Reorder trips using [visibleIds] (the IDs currently shown in the list)
  /// and the [oldIndex] / [newIndex] within that visible set.
  ///
  /// Hidden trips (those not in [visibleIds]) stay in their relative positions
  /// via a slot-replacement strategy: each "visible slot" in the full list is
  /// filled with the next trip from the newly ordered visible sequence.
  ///
  /// Pass `visibleIds: trips.map((t) => t.id).toList()` when the full list is
  /// shown (e.g. "All" tab), or a filtered subset when reordering within a
  /// filtered view (e.g. "Upcoming" tab).
  Future<void> reorderTrips(
    List<String> visibleIds,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;

    // Compute new visible order.
    final movingId = visibleIds[oldIndex];
    final newVisible = List<String>.from(visibleIds);
    newVisible.removeAt(oldIndex);
    newVisible.insert(newIndex, movingId);

    // Slot-replacement: walk the full list and replace each "visible" trip
    // with the next one from [newVisible], leaving hidden trips in place.
    final byId = {for (final t in _trips) t.id: t};
    final visibleSet = visibleIds.toSet();
    var slot = 0;
    _trips = _trips.map((trip) {
      if (visibleSet.contains(trip.id)) {
        return byId[newVisible[slot++]]!;
      }
      return trip;
    }).toList();

    notifyListeners();
    unawaited(_saveOrder());
  }

  // ─── Load / clear ──────────────────────────────────────────────────────────

  Future<void> load() async {
    _userId = _db.auth.currentUser?.id;
    if (_userId == null) return;

    // ── Offline: serve from local cache ───────────────────────────────────────
    if (!_isOnline) {
      final cached = await LocalCache.loadList('${_cacheKey}_$_userId');
      if (cached != null) {
        final order = await _loadOrder();
        _trips = applyOrder(
          cached.map((t) => Trip.fromJson(t)).toList(),
          order,
        );
        _loadError = null;
      }
      _loaded = true;
      notifyListeners();
      return;
    }

    // ── Online: fetch from Supabase and refresh cache ─────────────────────────
    try {
      final data = await _db
          .from('trips')
          .select('*, trip_members(*), trip_stops(*)')
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(data as List);
      final order = await _loadOrder();
      _trips = applyOrder(
        rows.map((t) => Trip.fromJson(t)).toList(),
        order,
      );
      _loadError = null;
      // Enrich member displayNames from user_profiles (SECURITY DEFINER
      // bypasses RLS so every member's name is visible to all trip members).
      await _enrichMemberNames();
      // Save the enriched state so offline sessions also show correct names.
      unawaited(_saveCache());
    } catch (e, st) {
      _loadError = e.toString();
      debugPrint('TripProvider.load error: $e\n$st');
      // Fallback: serve stale cache rather than showing nothing.
      if (_trips.isEmpty) {
        final cached = await LocalCache.loadList('${_cacheKey}_$_userId');
        if (cached != null) {
          final order = await _loadOrder();
          _trips = applyOrder(
            cached.map((t) => Trip.fromJson(t)).toList(),
            order,
          );
        }
      }
    }
    _loaded = true;
    notifyListeners();
    _subscribeRealtime();
  }

  /// Fetches canonical profile names for all linked members via the
  /// `get_profile_names` SECURITY DEFINER function and patches the in-memory
  /// `displayName` so the UI shows real names even when the stored value is
  /// an email address (e.g. for the trip organizer on older records).
  ///
  /// No-ops when offline or when there are no linked members.
  Future<void> _enrichMemberNames() async {
    // Collect every unique user_id across all trips.
    final userIds = <String>{};
    for (final trip in _trips) {
      for (final m in trip.members) {
        if (m.userId != null) userIds.add(m.userId!);
      }
    }
    if (userIds.isEmpty) return;

    try {
      final rows = await _db.rpc(
        'get_profile_names',
        params: {'p_user_ids': userIds.toList()},
      ) as List<dynamic>;
      if (rows.isEmpty) return;

      // Build userId → {fullName, avatarUrl} lookups.
      final nameMap = <String, String>{};
      final avatarMap = <String, String?>{};
      for (final row in rows) {
        final r = row as Map;
        final uid = r['user_id'] as String;
        nameMap[uid] = r['full_name'] as String? ?? '';
        avatarMap[uid] = r['avatar_url'] as String?;
      }

      // Patch displayName and avatarUrl for every linked member.
      _trips = _trips.map((trip) {
        final enriched = trip.members.map((m) {
          if (m.userId == null) return m;
          final name = nameMap[m.userId!];
          final avatar = avatarMap[m.userId!];
          final nameChanged =
              name != null && name.isNotEmpty && name != m.displayName;
          final avatarChanged = avatar != m.avatarUrl;
          if (!nameChanged && !avatarChanged) return m;
          return m.copyWith(
            displayName: nameChanged ? name : null,
            avatarUrl: avatar ?? m.avatarUrl,
          );
        }).toList();
        return trip.copyWith(members: enriched);
      }).toList();
    } catch (e) {
      debugPrint('TripProvider._enrichMemberNames error: $e');
    }
  }

  /// Single Realtime channel that keeps every in-memory trip fully in sync
  /// for all accepted members without requiring a full reload.
  ///
  /// Tables covered (all added to supabase_realtime publication):
  ///   • trips          — UPDATE only (organizer edited trip metadata)
  ///   • trip_members   — INSERT (new member added), UPDATE (full row sync),
  ///                      DELETE (hard-remove by organizer)
  ///   • trip_stops     — INSERT / UPDATE / DELETE (itinerary changes)
  ///
  /// REPLICA IDENTITY FULL is required on trip_members and trip_stops so that
  /// DELETE payloads include trip_id (not just the PK).
  void _subscribeRealtime() {
    if (_userId == null) return;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _db
        .channel('trip_sync_$_userId')

        // ── trips UPDATE ────────────────────────────────────────────────────
        // Supabase Realtime only sends the scalar trips columns — no nested
        // trip_members or trip_stops.  Reconstruct the Trip using the new row
        // values and preserve the current in-memory members + stops.
        //
        // ⚠  If a new column is added to the trips table it MUST be added here.
        // Stops and member handlers use fromJson and are automatically complete.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          callback: (payload) {
            final row = payload.newRecord;
            final tripId = row['id'] as String?;
            if (tripId == null) return;

            final tripIdx = _trips.indexWhere((t) => t.id == tripId);
            if (tripIdx < 0) return;

            final existing = _trips[tripIdx];
            _trips[tripIdx] = Trip(
              id: existing.id,
              createdBy: existing.createdBy,
              title: row['title'] as String? ?? existing.title,
              startLocation: row['start_location'] as String?,
              startLat: (row['start_lat'] as num?)?.toDouble(),
              startLng: (row['start_lng'] as num?)?.toDouble(),
              destination: row['destination'] as String? ?? existing.destination,
              notes: row['notes'] as String? ?? '',
              destinationLat: (row['destination_lat'] as num?)?.toDouble(),
              destinationLng: (row['destination_lng'] as num?)?.toDouble(),
              startAt: row['start_at'] != null
                  ? DateTime.parse(row['start_at'] as String)
                  : null,
              endAt: row['end_at'] != null
                  ? DateTime.parse(row['end_at'] as String)
                  : null,
              createdAt: existing.createdAt,
              updatedAt: row['updated_at'] != null
                  ? DateTime.parse(row['updated_at'] as String)
                  : existing.updatedAt,
              members: existing.members, // always preserved from in-memory
              stops: existing.stops,     // always preserved from in-memory
            );
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── trip_members INSERT ─────────────────────────────────────────────
        // A new member was added to a trip the current user is part of.
        // Dedup guard prevents double-append when the local device did the add
        // (optimistic in-memory update already ran in addMember()).
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_members',
          callback: (payload) {
            final row = payload.newRecord;
            final tripId = row['trip_id'] as String?;
            if (tripId == null) return;

            final tripIdx = _trips.indexWhere((t) => t.id == tripId);
            if (tripIdx < 0) return;

            final member = TripMember.fromJson(row);
            final trip = _trips[tripIdx];
            if (trip.members.any((m) => m.id == member.id)) return; // dedup
            _trips[tripIdx] = trip.copyWith(
              members: [...trip.members, member],
            );
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── trip_members UPDATE ─────────────────────────────────────────────
        // Full row sync — covers status, display_name, email, phone,
        // invited_by, block_reinvite, etc.  Previously only status was patched.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trip_members',
          callback: (payload) {
            final row = payload.newRecord;
            final memberId = row['id'] as String?;
            final tripId = row['trip_id'] as String?;
            if (memberId == null || tripId == null) return;

            final tripIdx = _trips.indexWhere((t) => t.id == tripId);
            if (tripIdx < 0) return;

            final trip = _trips[tripIdx];
            final memberIdx = trip.members.indexWhere((m) => m.id == memberId);
            if (memberIdx < 0) return;

            final updatedMember = TripMember.fromJson(row);
            final updatedMembers = List<TripMember>.of(trip.members)
              ..[memberIdx] = updatedMember;
            _trips[tripIdx] = trip.copyWith(members: updatedMembers);
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── trip_members DELETE ─────────────────────────────────────────────
        // Hard-remove by organizer.  Requires REPLICA IDENTITY FULL so that
        // oldRecord contains trip_id (not just the PK).
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'trip_members',
          callback: (payload) {
            final row = payload.oldRecord;
            final memberId = row['id'] as String?;
            final tripId = row['trip_id'] as String?;
            if (memberId == null || tripId == null) return;

            final tripIdx = _trips.indexWhere((t) => t.id == tripId);
            if (tripIdx < 0) return;

            final trip = _trips[tripIdx];
            _trips[tripIdx] = trip.copyWith(
              members: trip.members.where((m) => m.id != memberId).toList(),
            );
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── trip_stops INSERT ───────────────────────────────────────────────
        // A new stop was added.  Dedup guard prevents double-append when the
        // local device added the stop (addStop() already updated in-memory).
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_stops',
          callback: (payload) {
            final row = payload.newRecord;
            final tripId = row['trip_id'] as String?;
            if (tripId == null) return;

            final tripIdx = _trips.indexWhere((t) => t.id == tripId);
            if (tripIdx < 0) return;

            final stop = TripStop.fromJson(row);
            final trip = _trips[tripIdx];
            if (trip.stops.any((s) => s.id == stop.id)) return; // dedup
            final updatedStops = [...trip.stops, stop]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            _trips[tripIdx] = trip.copyWith(stops: updatedStops);
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── trip_stops UPDATE ───────────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trip_stops',
          callback: (payload) {
            final row = payload.newRecord;
            final tripId = row['trip_id'] as String?;
            if (tripId == null) return;

            final tripIdx = _trips.indexWhere((t) => t.id == tripId);
            if (tripIdx < 0) return;

            final stop = TripStop.fromJson(row);
            final trip = _trips[tripIdx];
            final stopIdx = trip.stops.indexWhere((s) => s.id == stop.id);
            if (stopIdx < 0) return;

            final updatedStops = List<TripStop>.of(trip.stops)
              ..[stopIdx] = stop;
            updatedStops.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            _trips[tripIdx] = trip.copyWith(stops: updatedStops);
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── trip_stops DELETE ───────────────────────────────────────────────
        // Requires REPLICA IDENTITY FULL on trip_stops (migration 001700) so
        // that oldRecord contains trip_id.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'trip_stops',
          callback: (payload) {
            final row = payload.oldRecord;
            final stopId = row['id'] as String?;
            final tripId = row['trip_id'] as String?;
            if (stopId == null || tripId == null) return;

            final tripIdx = _trips.indexWhere((t) => t.id == tripId);
            if (tripIdx < 0) return;

            final trip = _trips[tripIdx];
            _trips[tripIdx] = trip.copyWith(
              stops: trip.stops.where((s) => s.id != stopId).toList(),
            );
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        .subscribe();
  }

  void clear() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _trips = [];
    _loaded = false;
    _loadError = null;
    if (_userId != null) {
      unawaited(LocalCache.remove('${_cacheKey}_$_userId'));
      unawaited(LocalCache.remove('${_orderKey}_$_userId'));
    }
    _userId = null;
    notifyListeners();
  }

  @visibleForTesting
  void seedForTest(List<Trip> trips) {
    _trips = List.of(trips);
    notifyListeners();
  }

  // ─── Trips ────────────────────────────────────────────────────────────────

  Future<Trip> addTrip({
    required String title,
    String? startLocation,
    double? startLat,
    double? startLng,
    required String destination,
    DateTime? startAt,
    DateTime? endAt,
    String notes = '',
    double? destinationLat,
    double? destinationLng,
  }) async {
    final userId = _db.auth.currentUser!.id;

    // Prefer the profile name from user_profiles (bypasses RLS via SECURITY
    // DEFINER).  Falls back to auth metadata or email for offline / error cases.
    String userName;
    if (_isOnline) {
      try {
        final rows = await _db.rpc(
          'get_profile_names',
          params: {'p_user_ids': <String>[userId]},
        ) as List<dynamic>;
        final profileName = rows.isNotEmpty
            ? (rows.first as Map)['full_name'] as String? ?? ''
            : '';
        userName = profileName.isNotEmpty
            ? profileName
            : _db.auth.currentUser!.email ?? 'Me';
      } catch (_) {
        userName = _db.auth.currentUser!.userMetadata?['name'] as String? ??
            _db.auth.currentUser!.email ??
            'Me';
      }
    } else {
      userName = _db.auth.currentUser!.userMetadata?['name'] as String? ??
          _db.auth.currentUser!.email ??
          'Me';
    }
    final tripId = _uuid.v4();
    final memberId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final nowStr = now.toIso8601String();

    // Build payloads that work for both Supabase (upsert) and in-memory construction.
    final tripPayload = <String, dynamic>{
      'id': tripId,
      'created_by': userId,
      'title': title,
      'destination': destination,
      'notes': notes,
      'start_location': ?startLocation,
      'start_lat': ?startLat,
      'start_lng': ?startLng,
      'start_at': ?startAt?.toUtc().toIso8601String(),
      'end_at': ?endAt?.toUtc().toIso8601String(),
      'destination_lat': ?destinationLat,
      'destination_lng': ?destinationLng,
    };

    final memberPayload = <String, dynamic>{
      'id': memberId,
      'trip_id': tripId,
      'user_id': userId,
      'display_name': userName,
      'role': 'organizer',
    };

    late Trip trip;

    if (_isOnline) {
      final tripData = await _db
          .from('trips')
          .insert(tripPayload)
          .select()
          .single();
      final memberData = await _db
          .from('trip_members')
          .insert(memberPayload)
          .select()
          .single();
      trip = Trip.fromJson({
        ...tripData,
        'trip_members': [memberData],
        'trip_stops': <dynamic>[],
      });
    } else {
      // Offline: construct an optimistic Trip with client-generated timestamps.
      trip = Trip.fromJson({
        ...tripPayload,
        'created_at': nowStr,
        'updated_at': nowStr,
        'trip_members': [
          {...memberPayload, 'created_at': nowStr}
        ],
        'trip_stops': <dynamic>[],
      });
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trips',
        type: OfflineOperationType.insert,
        data: {...tripPayload, 'created_at': nowStr, 'updated_at': nowStr},
      ));
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trip_members',
        type: OfflineOperationType.insert,
        data: {...memberPayload, 'created_at': nowStr},
      ));
    }

    _trips.insert(0, trip);
    notifyListeners();
    unawaited(_saveCache());
    unawaited(_saveOrder());
    return trip;
  }

  Future<void> updateTrip(Trip updated) async {
    if (_isOnline) {
      await _db.from('trips').update(updated.toJson()).eq('id', updated.id);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trips',
        type: OfflineOperationType.update,
        data: updated.toJson(),
        filters: {'id': updated.id},
      ));
    }
    final idx = _trips.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _trips[idx] = updated;
      notifyListeners();
      unawaited(_saveCache());
    }
  }

  Future<void> deleteTrip(String id) async {
    if (_isOnline) {
      await _db.from('trips').delete().eq('id', id);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trips',
        type: OfflineOperationType.delete,
        data: const {},
        filters: {'id': id},
      ));
    }
    _trips.removeWhere((t) => t.id == id);
    notifyListeners();
    unawaited(_saveCache());
    unawaited(_saveOrder());
  }

  // ─── Members ──────────────────────────────────────────────────────────────

  Future<void> addMember(
    String tripId, {
    required String displayName,
    String? email,
    String? phone,
    String? userId,
  }) async {
    final memberId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    // Linked members (userId != null) start as pending until they accept.
    // Unlinked guests (no account) are immediately accepted.
    final status = userId != null ? 'pending' : 'accepted';
    // Record who sent this invite so the UI can show "Invited by …".
    final invitedBy = _db.auth.currentUser?.id;

    final payload = <String, dynamic>{
      'id': memberId,
      'trip_id': tripId,
      'display_name': displayName,
      'email': ?email,
      'phone': ?phone,
      'user_id': ?userId,
      'role': 'member',
      'status': status,
      'invited_by': ?invitedBy,
    };

    // Fast-reject if the in-memory row already has block_reinvite = true.
    // The DB trigger (migration 20260527001300) is the authoritative guard, but
    // this avoids an unnecessary network round-trip and gives an instant error.
    if (userId != null) {
      final cached = getById(tripId);
      if (cached != null) {
        for (final m in cached.members) {
          if (m.userId == userId && m.blockReinvite) {
            throw const ReinviteBlockedException();
          }
        }
      }
    }

    late TripMember member;

    if (_isOnline) {
      if (userId != null) {
        // Upsert: if this user already has a row for this trip (e.g. status='left'
        // after leaving, or 'declined'), reset it to 'pending' instead of inserting
        // a duplicate. The partial unique index on (trip_id, user_id) WHERE
        // user_id IS NOT NULL (migration 20260527001200) handles the conflict.
        // The extended trigger also fires on this UPDATE → sends FCM notification.
        try {
          final data = await _db
              .from('trip_members')
              .upsert(payload, onConflict: 'trip_id,user_id')
              .select()
              .single();
          member = TripMember.fromJson(data);
        } on PostgrestException catch (e) {
          // DB trigger raises 'blocked_reinvite' when the row has block_reinvite=true.
          if (e.message.contains('blocked_reinvite') ||
              (e.details ?? '').toString().contains('blocked_reinvite')) {
            throw const ReinviteBlockedException();
          }
          rethrow;
        }
      } else {
        // Guest members have no user_id — no unique constraint, always insert.
        final data =
            await _db.from('trip_members').insert(payload).select().single();
        member = TripMember.fromJson(data);
      }
    } else {
      // Offline: detect an existing row for this userId and queue update vs insert.
      final existingTrip = getById(tripId);
      TripMember? existingForUser;
      if (userId != null && existingTrip != null) {
        for (final m in existingTrip.members) {
          if (m.userId == userId) {
            existingForUser = m;
            break;
          }
        }
      }

      if (existingForUser != null) {
        // Re-invite: queue an update on the existing row.
        member = existingForUser.copyWith(
          displayName: displayName,
          status: 'pending',
          invitedBy: invitedBy,
        );
        await _enqueue(OfflineOperation(
          operationId: _uuid.v4(),
          table: 'trip_members',
          type: OfflineOperationType.update,
          data: <String, dynamic>{
            'display_name': displayName,
            'status': 'pending',
            'invited_by': ?invitedBy,
            'email': ?email,
            'phone': ?phone,
          },
          filters: {'id': existingForUser.id},
        ));
      } else {
        member = TripMember.fromJson({...payload, 'created_at': now});
        await _enqueue(OfflineOperation(
          operationId: _uuid.v4(),
          table: 'trip_members',
          type: OfflineOperationType.insert,
          data: {...payload, 'created_at': now},
        ));
      }
    }

    final trip = getById(tripId);
    if (trip == null) return;

    // Replace any existing row for this userId (e.g. after re-invite), or append.
    final List<TripMember> newMembers;
    if (userId != null) {
      final existingIdx = trip.members.indexWhere((m) => m.userId == userId);
      if (existingIdx >= 0) {
        final mutable = List.of(trip.members);
        mutable[existingIdx] = member;
        newMembers = mutable;
      } else {
        newMembers = [...trip.members, member];
      }
    } else {
      newMembers = [...trip.members, member];
    }

    final updated = trip.copyWith(members: newMembers);
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx >= 0) _trips[idx] = updated;
    notifyListeners();
    unawaited(_saveCache());
  }

  Future<void> removeMember(String memberId, String tripId) async {
    if (_isOnline) {
      await _db.from('trip_members').delete().eq('id', memberId);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trip_members',
        type: OfflineOperationType.delete,
        data: const {},
        filters: {'id': memberId},
      ));
    }
    final trip = getById(tripId);
    if (trip == null) return;
    final updated = trip.copyWith(
      members: trip.members.where((m) => m.id != memberId).toList(),
    );
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx >= 0) _trips[idx] = updated;
    notifyListeners();
    unawaited(_saveCache());
  }

  /// Marks the current user's member row as 'left' and removes the trip from
  /// the local list (they no longer have RLS access since
  /// auth_user_is_trip_member only counts 'accepted' rows).
  ///
  /// If [blockReinvite] is true, also sets block_reinvite = true so that no
  /// one can re-invite this user to the same trip in the future.
  ///
  /// Using UPDATE instead of DELETE preserves the row so that other members
  /// can see a "Left" chip on the member tile in real-time via the existing
  /// UPDATE realtime handler.
  Future<void> leaveTrip(String tripId, {bool blockReinvite = false}) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    final trip = getById(tripId);
    if (trip == null) return;

    TripMember? myMember;
    for (final m in trip.members) {
      if (m.userId == userId) {
        myMember = m;
        break;
      }
    }
    if (myMember == null) return;

    final update = <String, dynamic>{
      'status': 'left',
      if (blockReinvite) 'block_reinvite': true,
    };

    if (_isOnline) {
      await _db.from('trip_members').update(update).eq('id', myMember.id);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trip_members',
        type: OfflineOperationType.update,
        data: update,
        filters: {'id': myMember.id},
      ));
    }

    // Remove the trip from the local list — the user no longer has access.
    _trips.removeWhere((t) => t.id == tripId);
    notifyListeners();
    unawaited(_saveCache());
    unawaited(_saveOrder());
  }

  // ─── Stops ────────────────────────────────────────────────────────────────

  Future<void> addStop(
    String tripId, {
    required String title,
    required String address,
    String notes = '',
    DateTime? arriveAt,
    DateTime? departAt,
    int? sortOrder,
    double? addressLat,
    double? addressLng,
  }) async {
    final trip = getById(tripId);
    final order = sortOrder ?? (trip?.stops.length ?? 0);
    final stopId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'id': stopId,
      'trip_id': tripId,
      'title': title,
      'address': address,
      'notes': notes,
      'arrive_at': ?arriveAt?.toUtc().toIso8601String(),
      'depart_at': ?departAt?.toUtc().toIso8601String(),
      'sort_order': order,
      'address_lat': addressLat,
      'address_lng': addressLng,
    };

    late TripStop stop;

    if (_isOnline) {
      final data = await _db.from('trip_stops').insert(payload).select().single();
      stop = TripStop.fromJson(data);
    } else {
      stop = TripStop.fromJson({...payload, 'created_at': now});
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trip_stops',
        type: OfflineOperationType.insert,
        data: {...payload, 'created_at': now},
      ));
    }

    if (trip == null) return;
    final updatedStops = [...trip.stops, stop]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx >= 0) _trips[idx] = trip.copyWith(stops: updatedStops);
    notifyListeners();
    unawaited(_saveCache());
  }

  Future<void> updateStop(TripStop updated) async {
    if (_isOnline) {
      await _db.from('trip_stops').update(updated.toJson()).eq('id', updated.id);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trip_stops',
        type: OfflineOperationType.update,
        data: updated.toJson(),
        filters: {'id': updated.id},
      ));
    }
    final trip = getById(updated.tripId);
    if (trip == null) return;
    final stopIdx = trip.stops.indexWhere((s) => s.id == updated.id);
    if (stopIdx < 0) return;
    final newStops = List<TripStop>.of(trip.stops)..[stopIdx] = updated;
    newStops.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = _trips.indexWhere((t) => t.id == updated.tripId);
    if (idx >= 0) _trips[idx] = trip.copyWith(stops: newStops);
    notifyListeners();
    unawaited(_saveCache());
  }

  Future<void> deleteStop(String stopId, String tripId) async {
    if (_isOnline) {
      await _db.from('trip_stops').delete().eq('id', stopId);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trip_stops',
        type: OfflineOperationType.delete,
        data: const {},
        filters: {'id': stopId},
      ));
    }
    final trip = getById(tripId);
    if (trip == null) return;
    final updated = trip.copyWith(
      stops: trip.stops.where((s) => s.id != stopId).toList(),
    );
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx >= 0) _trips[idx] = updated;
    notifyListeners();
    unawaited(_saveCache());
  }

  // ─── Resend invite ─────────────────────────────────────────────────────────

  Future<void> resendInvite(String memberId) async {
    await _db.rpc('resend_invite', params: {'p_member_id': memberId});
  }
}
