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

class TripProvider extends ChangeNotifier {
  static const _uuid = Uuid();
  static const _cacheKey = 'cache_trips_v1';

  SupabaseClient get _db => Supabase.instance.client;
  List<Trip> _trips = [];
  bool _loaded = false;
  String? _loadError;
  String? _userId;

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

  // ─── Load / clear ──────────────────────────────────────────────────────────

  Future<void> load() async {
    _userId = _db.auth.currentUser?.id;
    if (_userId == null) return;

    // ── Offline: serve from local cache ───────────────────────────────────────
    if (!_isOnline) {
      final cached = await LocalCache.loadList('${_cacheKey}_$_userId');
      if (cached != null) {
        _trips = cached.map((t) => Trip.fromJson(t)).toList();
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
      _trips = rows.map((t) => Trip.fromJson(t)).toList();
      _loadError = null;
      unawaited(LocalCache.saveList('${_cacheKey}_$_userId', rows));
    } catch (e, st) {
      _loadError = e.toString();
      debugPrint('TripProvider.load error: $e\n$st');
      // Fallback: serve stale cache rather than showing nothing.
      if (_trips.isEmpty) {
        final cached = await LocalCache.loadList('${_cacheKey}_$_userId');
        if (cached != null) {
          _trips = cached.map((t) => Trip.fromJson(t)).toList();
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void clear() {
    _trips = [];
    _loaded = false;
    _loadError = null;
    if (_userId != null) {
      unawaited(LocalCache.remove('${_cacheKey}_$_userId'));
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
    final userName = _db.auth.currentUser!.userMetadata?['name'] as String? ??
        _db.auth.currentUser!.email ??
        'Me';
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

    final payload = <String, dynamic>{
      'id': memberId,
      'trip_id': tripId,
      'display_name': displayName,
      'email': ?email,
      'phone': ?phone,
      'user_id': ?userId,
      'role': 'member',
    };

    late TripMember member;

    if (_isOnline) {
      final data = await _db.from('trip_members').insert(payload).select().single();
      member = TripMember.fromJson(data);
    } else {
      member = TripMember.fromJson({...payload, 'created_at': now});
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'trip_members',
        type: OfflineOperationType.insert,
        data: {...payload, 'created_at': now},
      ));
    }

    final trip = getById(tripId);
    if (trip == null) return;
    final updated = trip.copyWith(members: [...trip.members, member]);
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
}
