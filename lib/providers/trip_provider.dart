import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';
import '../models/trip_member.dart';
import '../models/trip_stop.dart';

class TripProvider extends ChangeNotifier {
  SupabaseClient get _db => Supabase.instance.client;
  List<Trip> _trips = [];
  bool _loaded = false;
  String? _loadError;

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

  Future<void> load() async {
    if (_db.auth.currentSession == null) return;
    try {
      final data = await _db
          .from('trips')
          .select('*, trip_members(*), trip_stops(*)')
          .order('created_at', ascending: false);
      _trips = (data as List<dynamic>)
          .map((t) => Trip.fromJson(t as Map<String, dynamic>))
          .toList();
      _loadError = null;
    } catch (e, st) {
      _loadError = e.toString();
      debugPrint('TripProvider.load error: $e\n$st');
    }
    _loaded = true;
    notifyListeners();
  }

  void clear() {
    _trips = [];
    _loaded = false;
    _loadError = null;
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

    final tripData = await _db.from('trips').insert({
      'created_by': userId,
      'title': title,
      'start_location': ?startLocation,
      'start_lat': ?startLat,
      'start_lng': ?startLng,
      'destination': destination,
      'start_at': startAt?.toUtc().toIso8601String(),
      'end_at': endAt?.toUtc().toIso8601String(),
      'notes': notes,
      'destination_lat': ?destinationLat,
      'destination_lng': ?destinationLng,
    }).select().single();

    final tripId = tripData['id'] as String;

    final memberData = await _db.from('trip_members').insert({
      'trip_id': tripId,
      'user_id': userId,
      'display_name': userName,
      'role': 'organizer',
    }).select().single();

    final trip = Trip.fromJson({
      ...tripData,
      'trip_members': [memberData],
      'trip_stops': <dynamic>[],
    });
    _trips.add(trip);
    notifyListeners();
    return trip;
  }

  Future<void> updateTrip(Trip updated) async {
    await _db.from('trips').update(updated.toJson()).eq('id', updated.id);
    final idx = _trips.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _trips[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteTrip(String id) async {
    await _db.from('trips').delete().eq('id', id);
    _trips.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ─── Members ──────────────────────────────────────────────────────────────

  Future<void> addMember(
    String tripId, {
    required String displayName,
    String? email,
    String? phone,
    String? userId,
  }) async {
    final data = await _db.from('trip_members').insert({
      'trip_id': tripId,
      'display_name': displayName,
      'email': ?email,
      'phone': ?phone,
      'user_id': ?userId,
      'role': 'member',
    }).select().single();

    final trip = getById(tripId);
    if (trip == null) return;
    final member = TripMember.fromJson(data);
    final updated = trip.copyWith(members: [...trip.members, member]);
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx >= 0) _trips[idx] = updated;
    notifyListeners();
  }

  Future<void> removeMember(String memberId, String tripId) async {
    await _db.from('trip_members').delete().eq('id', memberId);
    final trip = getById(tripId);
    if (trip == null) return;
    final updated = trip.copyWith(
      members: trip.members.where((m) => m.id != memberId).toList(),
    );
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx >= 0) _trips[idx] = updated;
    notifyListeners();
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

    final data = await _db.from('trip_stops').insert({
      'trip_id': tripId,
      'title': title,
      'address': address,
      'notes': notes,
      if (arriveAt != null) 'arrive_at': arriveAt.toUtc().toIso8601String(),
      if (departAt != null) 'depart_at': departAt.toUtc().toIso8601String(),
      'sort_order': order,
      'address_lat': addressLat,
      'address_lng': addressLng,
    }).select().single();

    if (trip == null) return;
    final stop = TripStop.fromJson(data);
    final updatedStops = [...trip.stops, stop]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx >= 0) _trips[idx] = trip.copyWith(stops: updatedStops);
    notifyListeners();
  }

  Future<void> updateStop(TripStop updated) async {
    await _db.from('trip_stops').update(updated.toJson()).eq('id', updated.id);
    final trip = getById(updated.tripId);
    if (trip == null) return;
    final stopIdx = trip.stops.indexWhere((s) => s.id == updated.id);
    if (stopIdx < 0) return;
    final newStops = List<TripStop>.of(trip.stops)..[stopIdx] = updated;
    newStops.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = _trips.indexWhere((t) => t.id == updated.tripId);
    if (idx >= 0) _trips[idx] = trip.copyWith(stops: newStops);
    notifyListeners();
  }

  Future<void> deleteStop(String stopId, String tripId) async {
    await _db.from('trip_stops').delete().eq('id', stopId);
    final trip = getById(tripId);
    if (trip == null) return;
    final updated = trip.copyWith(
      stops: trip.stops.where((s) => s.id != stopId).toList(),
    );
    final idx = _trips.indexWhere((t) => t.id == tripId);
    if (idx >= 0) _trips[idx] = updated;
    notifyListeners();
  }
}
