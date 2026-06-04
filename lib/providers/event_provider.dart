import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import '../models/event_expense.dart';
import '../models/event_guest.dart';
import '../models/event_photo.dart';
import '../services/local_cache.dart';

class EventProvider extends ChangeNotifier {
  static const _cacheKey = 'cache_events_v1';

  SupabaseClient get _db => Supabase.instance.client;

  List<Event> _events = [];
  bool _loaded = false;
  String? _loadError;
  String? _userId;
  RealtimeChannel? _realtimeChannel;

  // Per-event caches for photos and expenses (fetched on demand).
  final Map<String, List<EventPhoto>> _photos = {};
  final Map<String, List<EventExpense>> _expenses = {};

  List<Event> get events => List.unmodifiable(_events);
  bool get loaded => _loaded;
  String? get loadError => _loadError;

  /// Events organised by the current user.
  List<Event> get myEvents =>
      _events.where((e) => e.createdBy == _userId).toList();

  /// Events where the user is a guest (but did not create).
  List<Event> get invitedEvents =>
      _events.where((e) => e.createdBy != _userId).toList();

  /// Count of events where user has been added as a guest but hasn't explicitly
  /// changed their RSVP from the default — used for the badge.
  int get pendingRsvpCount => 0; // Guests start as 'going'; no pending state.

  Event? getById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<EventPhoto> photosFor(String eventId) => _photos[eventId] ?? [];
  List<EventExpense> expensesFor(String eventId) => _expenses[eventId] ?? [];

  // ─── Cache ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _eventToCacheJson(Event e) => {
        'id': e.id,
        'created_by': e.createdBy,
        'title': e.title,
        'description': e.description,
        'location': e.location,
        'location_lat': e.locationLat,
        'location_lng': e.locationLng,
        'start_at': e.startAt.toUtc().toIso8601String(),
        'end_at': e.endAt?.toUtc().toIso8601String(),
        'capacity': e.capacity,
        'invite_code': e.inviteCode,
        'created_at': e.createdAt.toIso8601String(),
        'updated_at': e.updatedAt.toIso8601String(),
        'event_guests': e.guests
            .map((g) => {
                  'id': g.id,
                  'event_id': g.eventId,
                  'user_id': g.userId,
                  'display_name': g.displayName,
                  'email': g.email,
                  'phone': g.phone,
                  'rsvp_status': g.rsvpStatus,
                  'rsvp_at': g.rsvpAt.toIso8601String(),
                  'created_at': g.createdAt.toIso8601String(),
                  'avatar_url': g.avatarUrl,
                })
            .toList(),
      };

  Future<void> _saveCache() async {
    if (_userId == null) return;
    final rows = _events.map(_eventToCacheJson).toList();
    unawaited(LocalCache.saveList('${_cacheKey}_$_userId', rows));
  }

  // ─── Load / clear ──────────────────────────────────────────────────────────

  Future<void> load() async {
    _userId = _db.auth.currentUser?.id;
    if (_userId == null) return;

    // Serve cached data immediately.
    final cached = await LocalCache.loadList('${_cacheKey}_$_userId');
    if (cached != null && _events.isEmpty) {
      _events = cached.map((e) => Event.fromJson(e)).toList();
      _loaded = true;
      notifyListeners();
    }

    try {
      final data = await _db
          .from('events')
          .select('*, event_guests(*)')
          .order('start_at', ascending: true);
      final rows = List<Map<String, dynamic>>.from(data);
      _events = rows.map(Event.fromJson).toList();
      await _enrichOrganizerNames();
      _loadError = null;
      unawaited(_saveCache());
    } catch (e, st) {
      _loadError = e.toString();
      debugPrint('EventProvider.load error: $e\n$st');
    }
    _loaded = true;
    notifyListeners();
    _subscribeRealtime();
  }

  void clear() {
    _events = [];
    _photos.clear();
    _expenses.clear();
    _loaded = false;
    _loadError = null;
    _userId = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    notifyListeners();
  }

  // ─── Name enrichment ───────────────────────────────────────────────────────

  Future<void> _enrichOrganizerNames() async {
    if (_events.isEmpty) return;
    final ids = _events.map((e) => e.createdBy).toSet().toList();
    try {
      final profiles = await _db.rpc(
        'get_profile_names',
        params: {'p_user_ids': ids},
      ) as List<dynamic>;

      final nameMap = <String, String>{};
      for (final p in profiles) {
        final m = p as Map<String, dynamic>;
        nameMap[m['user_id'] as String] = m['full_name'] as String? ?? '';
      }
      _events = _events
          .map((e) => e.copyWith(organizerName: nameMap[e.createdBy]))
          .toList();
    } catch (_) {}
  }

  // ─── Realtime ──────────────────────────────────────────────────────────────

  void _subscribeRealtime() {
    if (_userId == null) return;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _db
        .channel('event_sync_$_userId')

        // events UPDATE — event metadata changed (title, dates, etc.)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'events',
          callback: (payload) {
            final row = payload.newRecord;
            final id = row['id'] as String?;
            if (id == null) return;
            final idx = _events.indexWhere((e) => e.id == id);
            if (idx < 0) return;
            final existing = _events[idx];
            _events[idx] = Event(
              id: existing.id,
              createdBy: existing.createdBy,
              title: row['title'] as String? ?? existing.title,
              description: row['description'] as String? ?? existing.description,
              location: row['location'] as String? ?? existing.location,
              locationLat: (row['location_lat'] as num?)?.toDouble(),
              locationLng: (row['location_lng'] as num?)?.toDouble(),
              startAt: row['start_at'] != null
                  ? DateTime.parse(row['start_at'] as String)
                  : existing.startAt,
              endAt: row['end_at'] != null
                  ? DateTime.parse(row['end_at'] as String)
                  : null,
              capacity: row['capacity'] as int?,
              inviteCode: existing.inviteCode,
              createdAt: existing.createdAt,
              updatedAt: row['updated_at'] != null
                  ? DateTime.parse(row['updated_at'] as String)
                  : existing.updatedAt,
              guests: existing.guests,
              organizerName: existing.organizerName,
            );
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // event_guests INSERT — someone was added to (or RSVP'd for) an event
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_guests',
          callback: (payload) async {
            final row = payload.newRecord;
            final eventId = row['event_id'] as String?;
            if (eventId == null) return;

            final idx = _events.indexWhere((e) => e.id == eventId);
            if (idx < 0) {
              // New event invitation — re-fetch full list.
              if ((row['user_id'] as String?) == _userId) {
                unawaited(_reloadEvent(eventId));
              }
              return;
            }
            final guest = EventGuest.fromJson(Map<String, dynamic>.from(row));
            final existing = _events[idx];
            if (existing.guests.any((g) => g.id == guest.id)) return;
            _events[idx] = existing.copyWith(guests: [...existing.guests, guest]);
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // event_guests UPDATE — RSVP status changed
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_guests',
          callback: (payload) {
            final row = payload.newRecord;
            final eventId = row['event_id'] as String?;
            if (eventId == null) return;
            final idx = _events.indexWhere((e) => e.id == eventId);
            if (idx < 0) return;
            final existing = _events[idx];
            final guestId = row['id'] as String?;
            final updatedGuests = existing.guests.map((g) {
              if (g.id != guestId) return g;
              return EventGuest.fromJson(Map<String, dynamic>.from(row));
            }).toList();
            _events[idx] = existing.copyWith(guests: updatedGuests);
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // event_guests DELETE — guest removed
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_guests',
          callback: (payload) {
            final row = payload.oldRecord;
            final eventId = row['event_id'] as String?;
            if (eventId == null) return;
            final idx = _events.indexWhere((e) => e.id == eventId);
            if (idx < 0) return;
            final guestId = row['id'] as String?;
            if (guestId == null) return;
            final existing = _events[idx];
            _events[idx] = existing.copyWith(
              guests: existing.guests.where((g) => g.id != guestId).toList(),
            );
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        .subscribe();
  }

  Future<void> _reloadEvent(String eventId) async {
    try {
      final data = await _db
          .from('events')
          .select('*, event_guests(*)')
          .eq('id', eventId)
          .single();
      final event = Event.fromJson(data);
      final idx = _events.indexWhere((e) => e.id == eventId);
      if (idx >= 0) {
        _events[idx] = event;
      } else {
        _events = [..._events, event];
      }
      notifyListeners();
      unawaited(_saveCache());
    } catch (e) {
      debugPrint('EventProvider._reloadEvent error: $e');
    }
  }

  // ─── CRUD ──────────────────────────────────────────────────────────────────

  Future<Event> addEvent({
    required String title,
    required String description,
    required String location,
    double? locationLat,
    double? locationLng,
    required DateTime startAt,
    DateTime? endAt,
    int? capacity,
  }) async {
    final session = _db.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    if (session.expiresAt != null) {
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      if (DateTime.now()
          .isAfter(expiresAt.subtract(const Duration(seconds: 60)))) {
        try {
          await _db.auth.refreshSession();
        } catch (_) {}
      }
    }

    final rows = await _db.rpc('create_event', params: {
      'p_title': title,
      'p_description': description,
      'p_location': location,
      'p_location_lat': ?locationLat,
      'p_location_lng': ?locationLng,
      'p_start_at': startAt.toUtc().toIso8601String(),
      'p_end_at': ?endAt?.toUtc().toIso8601String(),
      'p_capacity': ?capacity,
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Event creation returned no data.');
    final row = Map<String, dynamic>.from(rows.first as Map)
      ..['event_guests'] = <dynamic>[];

    final event = Event.fromJson(row);
    _events = [event, ..._events];
    notifyListeners();
    unawaited(_saveCache());
    return event;
  }

  Future<void> updateEvent(Event updated) async {
    await _db.from('events').update({
      'title': updated.title,
      'description': updated.description,
      'location': updated.location,
      'location_lat': updated.locationLat,
      'location_lng': updated.locationLng,
      'start_at': updated.startAt.toUtc().toIso8601String(),
      'end_at': updated.endAt?.toUtc().toIso8601String(),
      'capacity': updated.capacity,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', updated.id);

    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      _events[idx] = updated;
      notifyListeners();
      unawaited(_saveCache());
    }
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.from('events').delete().eq('id', eventId);
    _events = _events.where((e) => e.id != eventId).toList();
    _photos.remove(eventId);
    _expenses.remove(eventId);
    notifyListeners();
    unawaited(_saveCache());
  }

  // ─── RSVP ──────────────────────────────────────────────────────────────────

  /// Set or update the current user's RSVP for an event.
  Future<void> rsvp(String eventId, String status) async {
    final event = getById(eventId);
    if (event == null) return;
    final existingGuest = event.guests.firstWhere(
      (g) => g.userId == _userId,
      orElse: () => EventGuest(
        id: '',
        eventId: eventId,
        userId: _userId,
        displayName: '',
        rsvpStatus: status,
        rsvpAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    if (existingGuest.id.isEmpty) {
      // Insert new guest row.
      await _db.from('event_guests').insert({
        'event_id': eventId,
        'user_id': _userId,
        'display_name': existingGuest.displayName,
        'rsvp_status': status,
        'rsvp_at': DateTime.now().toUtc().toIso8601String(),
      });
    } else {
      await _db.from('event_guests').update({
        'rsvp_status': status,
        'rsvp_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', existingGuest.id);

      // Optimistic in-memory update.
      final idx = _events.indexWhere((e) => e.id == eventId);
      if (idx >= 0) {
        final updatedGuests = _events[idx].guests.map((g) {
          return g.id == existingGuest.id ? g.copyWith(rsvpStatus: status) : g;
        }).toList();
        _events[idx] = _events[idx].copyWith(guests: updatedGuests);
        notifyListeners();
        unawaited(_saveCache());
      }
    }
  }

  // ─── Photos ────────────────────────────────────────────────────────────────

  Future<List<EventPhoto>> fetchPhotos(String eventId) async {
    try {
      final data = await _db
          .from('event_photos')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(data);
      final photos = rows.map((r) {
        final photo = EventPhoto.fromJson(r);
        final url = _db.storage
            .from('event-photos')
            .getPublicUrl(photo.storagePath);
        return photo.withPublicUrl(url);
      }).toList();
      _photos[eventId] = photos;
      notifyListeners();
      return photos;
    } catch (e) {
      debugPrint('EventProvider.fetchPhotos error: $e');
      return [];
    }
  }

  Future<EventPhoto?> addPhoto({
    required String eventId,
    required String storagePath,
    String caption = '',
  }) async {
    try {
      final data = await _db.from('event_photos').insert({
        'event_id': eventId,
        'uploaded_by': _userId,
        'storage_path': storagePath,
        'caption': caption,
      }).select().single();
      final photo = EventPhoto.fromJson(data);
      final url =
          _db.storage.from('event-photos').getPublicUrl(photo.storagePath);
      final withUrl = photo.withPublicUrl(url);
      _photos[eventId] = [withUrl, ...(_photos[eventId] ?? [])];
      notifyListeners();
      return withUrl;
    } catch (e) {
      debugPrint('EventProvider.addPhoto error: $e');
      return null;
    }
  }

  Future<void> deletePhoto(EventPhoto photo) async {
    await _db.storage.from('event-photos').remove([photo.storagePath]);
    await _db.from('event_photos').delete().eq('id', photo.id);
    _photos[photo.eventId] =
        (_photos[photo.eventId] ?? []).where((p) => p.id != photo.id).toList();
    notifyListeners();
  }

  // ─── Expenses ──────────────────────────────────────────────────────────────

  Future<List<EventExpense>> fetchExpenses(String eventId) async {
    try {
      final data = await _db
          .from('event_expenses')
          .select('*, event_expense_splits(*)')
          .eq('event_id', eventId)
          .order('created_at', ascending: true);
      final rows = List<Map<String, dynamic>>.from(data);
      final expenses = rows.map(EventExpense.fromJson).toList();
      _expenses[eventId] = expenses;
      notifyListeners();
      return expenses;
    } catch (e) {
      debugPrint('EventProvider.fetchExpenses error: $e');
      return [];
    }
  }

  Future<void> addExpense({
    required String eventId,
    required double amount,
    required String description,
    required List<String> splitGuestIds,
  }) async {
    final profile = await _db
        .from('user_profiles')
        .select('full_name')
        .eq('user_id', _userId!)
        .maybeSingle();
    final paidByName =
        (profile?['full_name'] as String?)?.trim().isNotEmpty == true
            ? profile!['full_name'] as String
            : 'Unknown';

    final expenseData = await _db.from('event_expenses').insert({
      'event_id': eventId,
      'paid_by_user_id': _userId,
      'paid_by_name': paidByName,
      'amount': amount,
      'description': description,
    }).select().single();

    final expenseId = expenseData['id'] as String;
    final splitAmount = splitGuestIds.isEmpty
        ? amount
        : (amount / splitGuestIds.length * 100).round() / 100;

    for (final guestId in splitGuestIds) {
      await _db.from('event_expense_splits').insert({
        'event_id': eventId,
        'expense_id': expenseId,
        'guest_id': guestId,
        'amount': splitAmount,
      });
    }

    unawaited(fetchExpenses(eventId));
  }

  // ─── Guests ────────────────────────────────────────────────────────────────

  Future<void> addGuest({
    required String eventId,
    required String displayName,
    String? email,
    String? phone,
    String? userId,
  }) async {
    final data = await _db.from('event_guests').insert({
      'event_id': eventId,
      'user_id': ?userId,
      'display_name': displayName,
      'email': ?(email?.isNotEmpty == true ? email : null),
      'phone': ?(phone?.isNotEmpty == true ? phone : null),
      'rsvp_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();

    final guest = EventGuest.fromJson(data);
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) {
      final existing = _events[idx];
      _events[idx] = existing.copyWith(guests: [...existing.guests, guest]);
      notifyListeners();
      unawaited(_saveCache());
    }
  }

  Future<void> settleSplit(String splitId, String eventId) async {
    await _db.from('event_expense_splits').update({
      'settled': true,
      'settled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', splitId);
    unawaited(fetchExpenses(eventId));
  }
}
