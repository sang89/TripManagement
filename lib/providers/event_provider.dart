import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../models/event_bring_item.dart';
import '../models/event_expense.dart';
import '../models/event_poll.dart';
import '../models/event_guest.dart';
import '../models/event_photo.dart';
import '../models/event_stop.dart';
import '../services/connectivity_service.dart';
import '../services/local_cache.dart';
import '../services/offline_queue.dart';

/// Thrown when [EventProvider.addMember] is called for a user who has opted out
/// of future invitations to a specific event (block_reinvite = true).
class ReinviteBlockedException implements Exception {
  const ReinviteBlockedException();
}

class EventProvider extends ChangeNotifier {
  static const _uuid = Uuid();
  static const _cacheKey = 'cache_events_v2';
  static const _orderKey = 'events_order_v1';

  SupabaseClient get _db => Supabase.instance.client;

  List<Event> _events = [];
  bool _loaded = false;
  String? _loadError;
  String? _userId;
  RealtimeChannel? _realtimeChannel;

  // Per-event caches for photos and expenses (fetched on demand).
  final Map<String, List<EventPhoto>> _photos = {};
  final Map<String, List<EventExpense>> _expenses = {};
  final Map<String, List<EventBringItem>> _bringItems = {};
  final Map<String, List<EventPoll>> _polls = {};

  final ConnectivityService? _connectivity;
  final OfflineQueue? _queue;

  EventProvider({this._connectivity, this._queue});

  bool get _isOnline => _connectivity?.isOnline ?? true;
  Future<void> _enqueue(OfflineOperation op) async => _queue?.enqueue(op);

  List<Event> get events => List.unmodifiable(_events);
  bool get loaded => _loaded;
  String? get loadError => _loadError;

  /// Events organised by the current user.
  List<Event> get myEvents =>
      _events.where((e) => e.createdBy == _userId).toList();

  /// Events where the user is a guest (but did not create).
  List<Event> get invitedEvents =>
      _events.where((e) => e.createdBy != _userId).toList();

  /// Count of pending invitations across all trip-type events.
  int get pendingInviteCount => _events
      .where((e) => e.createdBy != _userId)
      .expand((e) => e.guests)
      .where((g) => g.userId == _userId && g.isPending)
      .length;

  Event? getById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<EventPhoto> photosFor(String eventId) => _photos[eventId] ?? [];
  List<EventExpense> expensesFor(String eventId) => _expenses[eventId] ?? [];
  List<EventBringItem> bringItemsFor(String eventId) =>
      _bringItems[eventId] ?? [];
  List<EventPoll> pollsFor(String eventId) => _polls[eventId] ?? [];

  // ─── Cache serialization ───────────────────────────────────────────────────

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
        'event_type': e.eventType.dbValue,
        'start_location': e.startLocation,
        'start_lat': e.startLat,
        'start_lng': e.startLng,
        'budget_per_head': e.budgetPerHead,
        'cuisine_tags': e.cuisineTags,
        'rsvp_deadline': e.rsvpDeadline?.toUtc().toIso8601String(),
        'vibe': e.vibe,
        'event_guests': e.guests
            .map((g) => {
                  'id': g.id,
                  'event_id': g.eventId,
                  'user_id': g.userId,
                  'display_name': g.displayName,
                  'email': g.email,
                  'phone': g.phone,
                  'status': g.status,
                  'rsvp_at': g.rsvpAt.toIso8601String(),
                  'created_at': g.createdAt.toIso8601String(),
                  'invited_by': g.invitedBy,
                  'block_reinvite': g.blockReinvite,
                  'role': g.role,
                  'avatar_url': g.avatarUrl,
                })
            .toList(),
        'event_stops': e.stops
            .map((s) => {
                  'id': s.id,
                  'event_id': s.eventId,
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

  Future<void> _saveCache() async {
    if (_userId == null) return;
    final rows = _events.map(_eventToCacheJson).toList();
    unawaited(LocalCache.saveList('${_cacheKey}_$_userId', rows));
  }

  // ─── Custom order ──────────────────────────────────────────────────────────

  Future<void> _saveOrder() async {
    if (_userId == null) return;
    await LocalCache.saveObject(
      '${_orderKey}_$_userId',
      {'ids': _events.map((e) => e.id).toList()},
    );
  }

  Future<List<String>?> _loadOrder() async {
    if (_userId == null) return null;
    final obj = await LocalCache.loadObject('${_orderKey}_$_userId');
    if (obj == null) return null;
    final ids = obj['ids'];
    if (ids is! List) return null;
    return ids.cast<String>();
  }

  static List<Event> applyOrder(List<Event> events, List<String>? order) {
    if (order == null || order.isEmpty) return events;
    final byId = {for (final e in events) e.id: e};
    final result = <Event>[];
    for (final id in order) {
      final event = byId.remove(id);
      if (event != null) result.add(event);
    }
    result.addAll(byId.values);
    return result;
  }

  Future<void> reorderEvents(
    List<String> visibleIds,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    final movingId = visibleIds[oldIndex];
    final newVisible = List<String>.from(visibleIds);
    newVisible.removeAt(oldIndex);
    newVisible.insert(newIndex, movingId);

    final byId = {for (final e in _events) e.id: e};
    final visibleSet = visibleIds.toSet();
    var slot = 0;
    _events = _events.map((event) {
      if (visibleSet.contains(event.id)) {
        return byId[newVisible[slot++]]!;
      }
      return event;
    }).toList();

    notifyListeners();
    unawaited(_saveOrder());
  }

  // ─── Load / clear ──────────────────────────────────────────────────────────

  Future<void> load() async {
    _userId = _db.auth.currentUser?.id;
    if (_userId == null) return;

    // ── Offline: serve from local cache ──────────────────────────────────────
    if (!_isOnline) {
      final cached = await LocalCache.loadList('${_cacheKey}_$_userId');
      if (cached != null) {
        final order = await _loadOrder();
        _events = applyOrder(
          cached.map((e) => Event.fromJson(e)).toList(),
          order,
        );
        _loadError = null;
      }
      _loaded = true;
      notifyListeners();
      return;
    }

    // ── Serve cache while fetching ────────────────────────────────────────────
    final cached = await LocalCache.loadList('${_cacheKey}_$_userId');
    if (cached != null && _events.isEmpty) {
      final order = await _loadOrder();
      _events = applyOrder(
        cached.map((e) => Event.fromJson(e)).toList(),
        order,
      );
      _loaded = true;
      notifyListeners();
    }

    // ── Online: fetch from Supabase ───────────────────────────────────────────
    try {
      final data = await _db
          .from('events')
          .select('*, event_guests(*), event_stops(*)')
          .order('start_at', ascending: true);
      final rows = List<Map<String, dynamic>>.from(data as List);
      final order = await _loadOrder();
      _events = applyOrder(rows.map(Event.fromJson).toList(), order);
      await _enrichGuestNames();
      _loadError = null;
      unawaited(_saveCache());
    } catch (e, st) {
      if (e is PostgrestException && e.code == 'PGRST303') {
        _loadError = 'Your device clock appears to be out of sync. '
            'Go to Settings → Date & Time and enable "Set Automatically", then retry.';
      } else {
        _loadError = e.toString();
      }
      debugPrint('EventProvider.load error: $e\n$st');
      if (_events.isEmpty) {
        final fallback = await LocalCache.loadList('${_cacheKey}_$_userId');
        if (fallback != null) {
          final order = await _loadOrder();
          _events = applyOrder(
            fallback.map((e) => Event.fromJson(e)).toList(),
            order,
          );
        }
      }
    }
    _loaded = true;
    notifyListeners();
    _subscribeRealtime();
  }

  void clear() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _events = [];
    _photos.clear();
    _expenses.clear();
    _bringItems.clear();
    _polls.clear();
    _loaded = false;
    _loadError = null;
    if (_userId != null) {
      unawaited(LocalCache.remove('${_cacheKey}_$_userId'));
      unawaited(LocalCache.remove('${_orderKey}_$_userId'));
    }
    _userId = null;
    notifyListeners();
  }

  // ─── Name enrichment ───────────────────────────────────────────────────────

  /// Enriches organizer names AND linked guest display names / avatars using
  /// the get_profile_names SECURITY DEFINER RPC.
  Future<void> _enrichGuestNames() async {
    if (_events.isEmpty) return;

    // Collect all user IDs: organizers + linked guests.
    final userIds = <String>{};
    for (final e in _events) {
      userIds.add(e.createdBy);
      for (final g in e.guests) {
        if (g.userId != null) userIds.add(g.userId!);
      }
    }
    if (userIds.isEmpty) return;

    try {
      final profiles = await _db.rpc(
        'get_profile_names',
        params: {'p_user_ids': userIds.toList()},
      ) as List<dynamic>;

      final nameMap = <String, String>{};
      final avatarMap = <String, String?>{};
      for (final p in profiles) {
        final m = p as Map<String, dynamic>;
        final uid = m['user_id'] as String;
        nameMap[uid] = m['full_name'] as String? ?? '';
        avatarMap[uid] = m['avatar_url'] as String?;
      }

      _events = _events.map((e) {
        final enrichedGuests = e.guests.map((g) {
          if (g.userId == null) return g;
          final name = nameMap[g.userId!];
          final avatar = avatarMap[g.userId!];
          final nameChanged =
              name != null && name.isNotEmpty && name != g.displayName;
          final avatarChanged = avatar != g.avatarUrl;
          if (!nameChanged && !avatarChanged) return g;
          return g.copyWith(
            displayName: nameChanged ? name : null,
            avatarUrl: avatar ?? g.avatarUrl,
          );
        }).toList();
        return e.copyWith(
          organizerName: nameMap[e.createdBy],
          guests: enrichedGuests,
        );
      }).toList();
    } catch (e) {
      debugPrint('EventProvider._enrichGuestNames error: $e');
    }
  }

  // ─── Realtime ──────────────────────────────────────────────────────────────

  String? _eventIdForPoll(String pollId) {
    for (final entry in _polls.entries) {
      if (entry.value.any((p) => p.id == pollId)) return entry.key;
    }
    return null;
  }

  void _subscribeRealtime() {
    if (_userId == null) return;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _db
        .channel('event_sync_$_userId')

        // ── events UPDATE ───────────────────────────────────────────────────
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
              description:
                  row['description'] as String? ?? existing.description,
              location: row['location'] as String? ?? existing.location,
              locationLat: row.containsKey('location_lat')
                  ? (row['location_lat'] as num?)?.toDouble()
                  : existing.locationLat,
              locationLng: row.containsKey('location_lng')
                  ? (row['location_lng'] as num?)?.toDouble()
                  : existing.locationLng,
              startAt: row['start_at'] != null
                  ? DateTime.parse(row['start_at'] as String)
                  : existing.startAt,
              endAt: row.containsKey('end_at')
                  ? (row['end_at'] != null
                      ? DateTime.parse(row['end_at'] as String)
                      : null)
                  : existing.endAt,
              capacity: row.containsKey('capacity')
                  ? row['capacity'] as int?
                  : existing.capacity,
              inviteCode: existing.inviteCode,
              createdAt: existing.createdAt,
              updatedAt: row['updated_at'] != null
                  ? DateTime.parse(row['updated_at'] as String)
                  : existing.updatedAt,
              eventType: row.containsKey('event_type')
                  ? EventType.fromString(row['event_type'] as String?)
                  : existing.eventType,
              startLocation: row.containsKey('start_location')
                  ? row['start_location'] as String?
                  : existing.startLocation,
              startLat: row.containsKey('start_lat')
                  ? (row['start_lat'] as num?)?.toDouble()
                  : existing.startLat,
              startLng: row.containsKey('start_lng')
                  ? (row['start_lng'] as num?)?.toDouble()
                  : existing.startLng,
              budgetPerHead: row.containsKey('budget_per_head')
                  ? (row['budget_per_head'] as num?)?.toDouble()
                  : existing.budgetPerHead,
              cuisineTags: row.containsKey('cuisine_tags')
                  ? (row['cuisine_tags'] as List<dynamic>? ?? [])
                      .map((t) => t as String)
                      .toList()
                  : existing.cuisineTags,
              rsvpDeadline: row.containsKey('rsvp_deadline')
                  ? (row['rsvp_deadline'] != null
                      ? DateTime.parse(row['rsvp_deadline'] as String)
                      : null)
                  : existing.rsvpDeadline,
              vibe: row.containsKey('vibe')
                  ? row['vibe'] as String?
                  : existing.vibe,
              guests: existing.guests,
              stops: existing.stops,
              organizerName: existing.organizerName,
            );
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── event_guests INSERT ─────────────────────────────────────────────
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
              // New event invitation for current user — fetch the full event.
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

        // ── event_guests UPDATE ─────────────────────────────────────────────
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
            final updated = EventGuest.fromJson(Map<String, dynamic>.from(row));
            final updatedGuests = existing.guests.map((g) {
              return g.id == guestId ? updated : g;
            }).toList();
            _events[idx] = existing.copyWith(guests: updatedGuests);
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── event_guests DELETE ─────────────────────────────────────────────
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

        // ── event_stops INSERT ──────────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_stops',
          callback: (payload) {
            final row = payload.newRecord;
            final eventId = row['event_id'] as String?;
            if (eventId == null) return;
            final idx = _events.indexWhere((e) => e.id == eventId);
            if (idx < 0) return;
            final stop = EventStop.fromJson(row);
            final existing = _events[idx];
            if (existing.stops.any((s) => s.id == stop.id)) return;
            final updatedStops = [...existing.stops, stop]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            _events[idx] = existing.copyWith(stops: updatedStops);
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── event_stops UPDATE ──────────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_stops',
          callback: (payload) {
            final row = payload.newRecord;
            final eventId = row['event_id'] as String?;
            if (eventId == null) return;
            final idx = _events.indexWhere((e) => e.id == eventId);
            if (idx < 0) return;
            final stop = EventStop.fromJson(row);
            final existing = _events[idx];
            final stopIdx = existing.stops.indexWhere((s) => s.id == stop.id);
            if (stopIdx < 0) return;
            final updatedStops = List<EventStop>.of(existing.stops)
              ..[stopIdx] = stop;
            updatedStops.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            _events[idx] = existing.copyWith(stops: updatedStops);
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── event_stops DELETE ──────────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_stops',
          callback: (payload) {
            final row = payload.oldRecord;
            final stopId = row['id'] as String?;
            final eventId = row['event_id'] as String?;
            if (stopId == null || eventId == null) return;
            final idx = _events.indexWhere((e) => e.id == eventId);
            if (idx < 0) return;
            final existing = _events[idx];
            _events[idx] = existing.copyWith(
              stops: existing.stops.where((s) => s.id != stopId).toList(),
            );
            notifyListeners();
            unawaited(_saveCache());
          },
        )

        // ── event_polls INSERT ──────────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_polls',
          callback: (payload) {
            final eventId = payload.newRecord['event_id'] as String?;
            if (eventId != null) unawaited(fetchPolls(eventId));
          },
        )

        // ── event_polls DELETE ──────────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_polls',
          callback: (payload) {
            final row = payload.oldRecord;
            final pollId = row['id'] as String?;
            final eventId = row['event_id'] as String?;
            if (pollId == null) return;
            if (eventId != null) {
              _polls[eventId]?.removeWhere((p) => p.id == pollId);
              notifyListeners();
            } else {
              for (final entry in _polls.entries) {
                if (entry.value.any((p) => p.id == pollId)) {
                  entry.value.removeWhere((p) => p.id == pollId);
                  notifyListeners();
                  break;
                }
              }
            }
          },
        )

        // ── event_poll_options INSERT ───────────────────────────────────────
        // Fires when any member pitches a restaurant via the Cravings tab.
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_poll_options',
          callback: (payload) {
            final pollId = payload.newRecord['poll_id'] as String?;
            if (pollId == null) return;
            final eventId = _eventIdForPoll(pollId);
            if (eventId != null) unawaited(fetchPolls(eventId));
          },
        )

        // ── event_poll_votes INSERT ─────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_poll_votes',
          callback: (payload) {
            final pollId = payload.newRecord['poll_id'] as String?;
            if (pollId == null) return;
            final eventId = _eventIdForPoll(pollId);
            if (eventId != null) unawaited(fetchPolls(eventId));
          },
        )

        // ── event_poll_votes DELETE ─────────────────────────────────────────
        // REPLICA IDENTITY FULL ensures poll_id is present in the old record.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_poll_votes',
          callback: (payload) {
            final pollId = payload.oldRecord['poll_id'] as String?;
            if (pollId == null) return;
            final eventId = _eventIdForPoll(pollId);
            if (eventId != null) unawaited(fetchPolls(eventId));
          },
        )

        .subscribe();
  }

  Future<void> _reloadEvent(String eventId) async {
    try {
      final data = await _db
          .from('events')
          .select('*, event_guests(*), event_stops(*)')
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

  // ─── Event CRUD ────────────────────────────────────────────────────────────

  Future<Event> addEvent({
    required String title,
    required String description,
    required String location,
    double? locationLat,
    double? locationLng,
    required DateTime startAt,
    DateTime? endAt,
    int? capacity,
    EventType eventType = EventType.social,
    String? startLocation,
    double? startLat,
    double? startLng,
    double? budgetPerHead,
    List<String> cuisineTags = const [],
    DateTime? rsvpDeadline,
    String? vibe,
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
      'p_event_type': eventType.dbValue,
      'p_start_location': ?startLocation,
      'p_start_lat': ?startLat,
      'p_start_lng': ?startLng,
      'p_budget_per_head': ?budgetPerHead,
      'p_cuisine_tags': cuisineTags,
      'p_rsvp_deadline': ?rsvpDeadline?.toUtc().toIso8601String(),
      'p_vibe': ?vibe,
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Event creation returned no data.');
    final eventId = (rows.first as Map)['id'] as String;
    final guestsData = await _db
        .from('event_guests')
        .select()
        .eq('event_id', eventId);

    final row = Map<String, dynamic>.from(rows.first as Map)
      ..['event_guests'] = guestsData
      ..['event_stops'] = <dynamic>[];

    final event = Event.fromJson(row);
    _events = [event, ..._events];
    notifyListeners();
    unawaited(_saveCache());
    unawaited(_saveOrder());
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
      'event_type': updated.eventType.dbValue,
      'start_location': updated.startLocation,
      'start_lat': updated.startLat,
      'start_lng': updated.startLng,
      'budget_per_head': updated.budgetPerHead,
      'cuisine_tags': updated.cuisineTags,
      'rsvp_deadline': updated.rsvpDeadline?.toUtc().toIso8601String(),
      'vibe': updated.vibe,
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
    _bringItems.remove(eventId);
    _polls.remove(eventId);
    notifyListeners();
    unawaited(_saveCache());
    unawaited(_saveOrder());
  }

  // ─── RSVP (non-trip events) ────────────────────────────────────────────────

  Future<void> rsvp(String eventId, String status, {String? note}) async {
    final event = getById(eventId);
    if (event == null) return;
    final existingGuest = event.guests.firstWhere(
      (g) => g.userId == _userId,
      orElse: () => EventGuest(
        id: '',
        eventId: eventId,
        userId: _userId,
        displayName: '',
        status: status,
        rsvpAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    final trimmedNote = note?.trim();
    final noteValue = (trimmedNote != null && trimmedNote.isNotEmpty) ? trimmedNote : null;

    if (existingGuest.id.isEmpty) {
      await _db.from('event_guests').insert({
        'event_id': eventId,
        'user_id': _userId,
        'display_name': existingGuest.displayName,
        'status': status,
        'rsvp_at': DateTime.now().toUtc().toIso8601String(),
        'rsvp_note': noteValue,
      });
    } else {
      await _db.from('event_guests').update({
        'status': status,
        'rsvp_at': DateTime.now().toUtc().toIso8601String(),
        'rsvp_note': noteValue,
      }).eq('id', existingGuest.id);

      final idx = _events.indexWhere((e) => e.id == eventId);
      if (idx >= 0) {
        final updatedGuests = _events[idx].guests.map((g) {
          return g.id == existingGuest.id
              ? g.copyWith(
                  status: status,
                  rsvpNote: noteValue,
                  clearRsvpNote: noteValue == null,
                )
              : g;
        }).toList();
        _events[idx] = _events[idx].copyWith(guests: updatedGuests);
        notifyListeners();
        unawaited(_saveCache());
      }
    }
  }

  // ─── Guests ────────────────────────────────────────────────────────────────

  /// Add a casual guest to a non-trip event (immediate 'going' status).
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

  // ─── Members (trip-type invite flow) ──────────────────────────────────────

  /// Add or reinvite a member to a trip-type event.
  /// Linked users start as 'pending'; unlinked guests are immediately 'accepted'.
  Future<void> addMember(
    String eventId, {
    required String displayName,
    String? email,
    String? phone,
    String? userId,
  }) async {
    final guestId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final status = userId != null ? 'pending' : 'accepted';
    final invitedBy = _db.auth.currentUser?.id;

    final payload = <String, dynamic>{
      'id': guestId,
      'event_id': eventId,
      'display_name': displayName,
      'email': ?email,
      'phone': ?phone,
      'user_id': ?userId,
      'role': 'member',
      'status': status,
      'invited_by': ?invitedBy,
      'rsvp_at': now,
    };

    // Fast-reject for in-memory block_reinvite before hitting the DB.
    if (userId != null) {
      final cached = getById(eventId);
      if (cached != null) {
        for (final g in cached.guests) {
          if (g.userId == userId && g.blockReinvite) {
            throw const ReinviteBlockedException();
          }
        }
      }
    }

    late EventGuest guest;

    if (_isOnline) {
      if (userId != null) {
        try {
          final data = await _db
              .from('event_guests')
              .upsert(payload, onConflict: 'event_id,user_id')
              .select()
              .single();
          guest = EventGuest.fromJson(data);
        } on PostgrestException catch (e) {
          if (e.message.contains('blocked_reinvite') ||
              (e.details ?? '').toString().contains('blocked_reinvite')) {
            throw const ReinviteBlockedException();
          }
          rethrow;
        }
      } else {
        final data = await _db
            .from('event_guests')
            .insert(payload)
            .select()
            .single();
        guest = EventGuest.fromJson(data);
      }
    } else {
      final existingEvent = getById(eventId);
      EventGuest? existingForUser;
      if (userId != null && existingEvent != null) {
        for (final g in existingEvent.guests) {
          if (g.userId == userId) {
            existingForUser = g;
            break;
          }
        }
      }

      if (existingForUser != null) {
        guest = existingForUser.copyWith(
          displayName: displayName,
          status: 'pending',
          invitedBy: invitedBy,
        );
        await _enqueue(OfflineOperation(
          operationId: _uuid.v4(),
          table: 'event_guests',
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
        guest = EventGuest.fromJson({...payload, 'created_at': now});
        await _enqueue(OfflineOperation(
          operationId: _uuid.v4(),
          table: 'event_guests',
          type: OfflineOperationType.insert,
          data: {...payload, 'created_at': now},
        ));
      }
    }

    final event = getById(eventId);
    if (event == null) return;

    final List<EventGuest> newGuests;
    if (userId != null) {
      final existingIdx = event.guests.indexWhere((g) => g.userId == userId);
      if (existingIdx >= 0) {
        final mutable = List.of(event.guests);
        mutable[existingIdx] = guest;
        newGuests = mutable;
      } else {
        newGuests = [...event.guests, guest];
      }
    } else {
      newGuests = [...event.guests, guest];
    }

    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) _events[idx] = event.copyWith(guests: newGuests);
    notifyListeners();
    unawaited(_saveCache());
  }

  Future<void> removeMember(String guestId, String eventId) async {
    if (_isOnline) {
      await _db.from('event_guests').delete().eq('id', guestId);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'event_guests',
        type: OfflineOperationType.delete,
        data: const {},
        filters: {'id': guestId},
      ));
    }
    final event = getById(eventId);
    if (event == null) return;
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) {
      _events[idx] = event.copyWith(
        guests: event.guests.where((g) => g.id != guestId).toList(),
      );
    }
    notifyListeners();
    unawaited(_saveCache());
  }

  /// Marks the current user's guest row as 'left' and removes the event from
  /// the local list (they no longer have RLS access).
  Future<void> leaveEvent(String eventId, {bool blockReinvite = false}) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    final event = getById(eventId);
    if (event == null) return;

    EventGuest? myGuest;
    for (final g in event.guests) {
      if (g.userId == userId) {
        myGuest = g;
        break;
      }
    }
    if (myGuest == null) return;

    final update = <String, dynamic>{
      'status': 'left',
      if (blockReinvite) 'block_reinvite': true,
    };

    if (_isOnline) {
      await _db.from('event_guests').update(update).eq('id', myGuest.id);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'event_guests',
        type: OfflineOperationType.update,
        data: update,
        filters: {'id': myGuest.id},
      ));
    }

    _events.removeWhere((e) => e.id == eventId);
    notifyListeners();
    unawaited(_saveCache());
    unawaited(_saveOrder());
  }

  Future<void> resendInvite(String guestId) async {
    await _db.rpc('resend_event_invite', params: {'p_guest_id': guestId});
  }

  // ─── Stops ────────────────────────────────────────────────────────────────

  Future<void> addStop(
    String eventId, {
    required String title,
    required String address,
    String notes = '',
    DateTime? arriveAt,
    DateTime? departAt,
    int? sortOrder,
    double? addressLat,
    double? addressLng,
  }) async {
    final event = getById(eventId);
    final order = sortOrder ?? (event?.stops.length ?? 0);
    final stopId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'id': stopId,
      'event_id': eventId,
      'title': title,
      'address': address,
      'notes': notes,
      'arrive_at': ?arriveAt?.toUtc().toIso8601String(),
      'depart_at': ?departAt?.toUtc().toIso8601String(),
      'sort_order': order,
      'address_lat': addressLat,
      'address_lng': addressLng,
    };

    late EventStop stop;

    if (_isOnline) {
      final data =
          await _db.from('event_stops').insert(payload).select().single();
      stop = EventStop.fromJson(data);
    } else {
      stop = EventStop.fromJson({...payload, 'created_at': now});
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'event_stops',
        type: OfflineOperationType.insert,
        data: {...payload, 'created_at': now},
      ));
    }

    if (event == null) return;
    final updatedStops = [...event.stops, stop]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) _events[idx] = event.copyWith(stops: updatedStops);
    notifyListeners();
    unawaited(_saveCache());
  }

  Future<void> updateStop(EventStop updated) async {
    if (_isOnline) {
      await _db
          .from('event_stops')
          .update(updated.toJson())
          .eq('id', updated.id);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'event_stops',
        type: OfflineOperationType.update,
        data: updated.toJson(),
        filters: {'id': updated.id},
      ));
    }
    final event = getById(updated.eventId);
    if (event == null) return;
    final stopIdx = event.stops.indexWhere((s) => s.id == updated.id);
    if (stopIdx < 0) return;
    final newStops = List<EventStop>.of(event.stops)..[stopIdx] = updated;
    newStops.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx = _events.indexWhere((e) => e.id == updated.eventId);
    if (idx >= 0) _events[idx] = event.copyWith(stops: newStops);
    notifyListeners();
    unawaited(_saveCache());
  }

  Future<void> deleteStop(String stopId, String eventId) async {
    if (_isOnline) {
      await _db.from('event_stops').delete().eq('id', stopId);
    } else {
      await _enqueue(OfflineOperation(
        operationId: _uuid.v4(),
        table: 'event_stops',
        type: OfflineOperationType.delete,
        data: const {},
        filters: {'id': stopId},
      ));
    }
    final event = getById(eventId);
    if (event == null) return;
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) {
      _events[idx] = event.copyWith(
        stops: event.stops.where((s) => s.id != stopId).toList(),
      );
    }
    notifyListeners();
    unawaited(_saveCache());
  }

  // ─── Photos ────────────────────────────────────────────────────────────────

  Future<List<EventPhoto>> fetchPhotos(String eventId) async {
    try {
      final data = await _db
          .from('event_photos')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(data as List);
      final photos = rows.map((r) {
        final photo = EventPhoto.fromJson(r);
        final url =
            _db.storage.from('event-photos').getPublicUrl(photo.storagePath);
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
      final rows = List<Map<String, dynamic>>.from(data as List);
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
    Map<String, double>? customSplitAmounts,
    String? paidByUserId,
    String? paidByName,
  }) async {
    String resolvedPaidByName = paidByName ?? '';
    String resolvedPaidByUserId = paidByUserId ?? _userId ?? '';

    if (resolvedPaidByName.isEmpty) {
      final profile = await _db
          .from('user_profiles')
          .select('full_name')
          .eq('user_id', _userId!)
          .maybeSingle();
      resolvedPaidByName =
          (profile?['full_name'] as String?)?.trim().isNotEmpty == true
              ? profile!['full_name'] as String
              : 'Unknown';
    }

    final expenseData = await _db.from('event_expenses').insert({
      'event_id': eventId,
      'paid_by_user_id': resolvedPaidByUserId,
      'paid_by_name': resolvedPaidByName,
      'amount': amount,
      'description': description,
    }).select().single();

    final expenseId = expenseData['id'] as String;

    for (final guestId in splitGuestIds) {
      final splitAmount = customSplitAmounts != null
          ? (customSplitAmounts[guestId] ?? 0.0)
          : (amount / splitGuestIds.length * 100).round() / 100;
      await _db.from('event_expense_splits').insert({
        'event_id': eventId,
        'expense_id': expenseId,
        'guest_id': guestId,
        'amount': splitAmount,
      });
    }

    unawaited(fetchExpenses(eventId));
  }

  Future<void> deleteExpense(String expenseId, String eventId) async {
    await _db.from('event_expenses').delete().eq('id', expenseId);
    unawaited(fetchExpenses(eventId));
  }

  Future<void> updateExpense({
    required String expenseId,
    required String eventId,
    required double amount,
    required String description,
    required List<String> splitGuestIds,
    Map<String, double>? customSplitAmounts,
    String? paidByUserId,
    String? paidByName,
  }) async {
    await _db.from('event_expenses').update({
      'paid_by_user_id': paidByUserId ?? _userId ?? '',
      'paid_by_name': paidByName ?? '',
      'amount': amount,
      'description': description,
    }).eq('id', expenseId);

    await _db
        .from('event_expense_splits')
        .delete()
        .eq('expense_id', expenseId);

    for (final guestId in splitGuestIds) {
      final splitAmount = customSplitAmounts != null
          ? (customSplitAmounts[guestId] ?? 0.0)
          : (amount / splitGuestIds.length * 100).round() / 100;
      await _db.from('event_expense_splits').insert({
        'event_id': eventId,
        'expense_id': expenseId,
        'guest_id': guestId,
        'amount': splitAmount,
      });
    }

    unawaited(fetchExpenses(eventId));
  }

  // ─── Bring list ────────────────────────────────────────────────────────────

  Future<List<EventBringItem>> fetchBringList(String eventId) async {
    try {
      final data = await _db
          .from('event_bring_list_items')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: true);
      final rows = List<Map<String, dynamic>>.from(data as List);
      final items = rows.map(EventBringItem.fromJson).toList();
      _bringItems[eventId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      debugPrint('EventProvider.fetchBringList error: $e');
      return [];
    }
  }

  Future<void> addBringItem({
    required String eventId,
    required String label,
    String? note,
    String? assignedToName,
  }) async {
    await _db.from('event_bring_list_items').insert({
      'event_id': eventId,
      'label': label.trim(),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'assigned_to_name': assignedToName,
      'created_by': _userId,
    });
    unawaited(fetchBringList(eventId));
  }

  Future<void> updateBringItem({
    required String itemId,
    required String eventId,
    required String label,
    String? note,
    String? assignedToName,
    bool clearAssignedToName = false,
  }) async {
    await _db.from('event_bring_list_items').update({
      'label': label.trim(),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'assigned_to_name': clearAssignedToName ? null : assignedToName,
    }).eq('id', itemId);

    final idx = _bringItems[eventId]?.indexWhere((i) => i.id == itemId) ?? -1;
    if (idx >= 0) {
      final existing = _bringItems[eventId]![idx];
      _bringItems[eventId]![idx] = EventBringItem(
        id: existing.id,
        eventId: existing.eventId,
        label: label.trim(),
        note: note?.trim().isEmpty == true ? null : note?.trim(),
        assignedToName: clearAssignedToName ? null : assignedToName,
        isDone: existing.isDone,
        createdBy: existing.createdBy,
        createdAt: existing.createdAt,
      );
      notifyListeners();
    }
  }

  Future<void> deleteBringItem(String itemId, String eventId) async {
    await _db
        .from('event_bring_list_items')
        .delete()
        .eq('id', itemId);
    _bringItems[eventId]?.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  Future<void> assignBringItem(
      String itemId, String eventId, String name) async {
    await _db.from('event_bring_list_items').update({
      'assigned_to_name': name,
    }).eq('id', itemId);

    final idx = _bringItems[eventId]?.indexWhere((i) => i.id == itemId) ?? -1;
    if (idx >= 0) {
      _bringItems[eventId]![idx] =
          _bringItems[eventId]![idx].copyWith(assignedToName: name);
      notifyListeners();
    }
  }

  Future<void> unassignBringItem(String itemId, String eventId) async {
    await _db.from('event_bring_list_items').update({
      'assigned_to_name': null,
    }).eq('id', itemId);

    final idx = _bringItems[eventId]?.indexWhere((i) => i.id == itemId) ?? -1;
    if (idx >= 0) {
      _bringItems[eventId]![idx] = _bringItems[eventId]![idx]
          .copyWith(clearAssignedToName: true);
      notifyListeners();
    }
  }

  Future<void> markBringItemDone(
      String itemId, String eventId, bool done) async {
    await _db.from('event_bring_list_items').update({
      'is_done': done,
    }).eq('id', itemId);

    final idx = _bringItems[eventId]?.indexWhere((i) => i.id == itemId) ?? -1;
    if (idx >= 0) {
      _bringItems[eventId]![idx] =
          _bringItems[eventId]![idx].copyWith(isDone: done);
      notifyListeners();
    }
  }

  // ─── Polls ─────────────────────────────────────────────────────────────────

  Future<List<EventPoll>> fetchPolls(String eventId) async {
    try {
      final data = await _db
          .from('event_polls')
          .select('*, event_poll_options(*), event_poll_votes(*)')
          .eq('event_id', eventId)
          .order('created_at', ascending: true);
      final rows = List<Map<String, dynamic>>.from(data as List);
      final polls = rows.map(EventPoll.fromJson).toList();
      _polls[eventId] = polls;
      notifyListeners();
      return polls;
    } catch (e) {
      debugPrint('EventProvider.fetchPolls error: $e');
      return [];
    }
  }

  Future<void> createPoll(
    String eventId,
    String question,
    List<String> options,
  ) async {
    final pollData = await _db
        .from('event_polls')
        .insert({
          'event_id': eventId,
          'question': question.trim(),
          'created_by': _userId,
          'poll_type': 'general',
        })
        .select()
        .single();
    final pollId = pollData['id'] as String;
    for (var i = 0; i < options.length; i++) {
      await _db.from('event_poll_options').insert({
        'poll_id': pollId,
        'text': options[i].trim(),
        'sort_order': i,
      });
    }
    unawaited(fetchPolls(eventId));
  }

  Future<void> createRestaurantPoll(
    String eventId,
    String question,
    List<Map<String, dynamic>> options,
  ) async {
    final pollData = await _db
        .from('event_polls')
        .insert({
          'event_id': eventId,
          'question': question.trim(),
          'created_by': _userId,
          'poll_type': 'restaurant',
        })
        .select()
        .single();
    final pollId = pollData['id'] as String;
    for (var i = 0; i < options.length; i++) {
      await _db.from('event_poll_options').insert({
        'poll_id': pollId,
        'text': (options[i]['text'] as String).trim(),
        'sort_order': i,
        'place_metadata': options[i]['placeMetadata'],
      });
    }
    unawaited(fetchPolls(eventId));
  }

  /// Adds a restaurant option to the shared restaurant poll for [eventId],
  /// creating the poll if [existingPollId] is null, then auto-votes for the option.
  /// Returns the poll ID so callers can pass it back on the next pitch.
  Future<String> pitchRestaurantOption(
    String eventId,
    String optionText,
    Map<String, dynamic> placeMetadata,
    String pollQuestion, {
    String? existingPollId,
  }) async {
    String pollId;
    if (existingPollId != null) {
      pollId = existingPollId;
    } else {
      // Check local cache first (covers rapid sequential pitches).
      final cached = (_polls[eventId] ?? [])
          .where((p) => p.isRestaurantPoll)
          .firstOrNull;
      if (cached != null) {
        pollId = cached.id;
      } else {
        try {
          final pollData = await _db
              .from('event_polls')
              .insert({
                'event_id': eventId,
                'question': pollQuestion,
                'created_by': _userId,
                'poll_type': 'restaurant',
              })
              .select()
              .single();
          pollId = pollData['id'] as String;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            // Race: another member just created the restaurant poll simultaneously.
            final existing = await _db
                .from('event_polls')
                .select('id')
                .eq('event_id', eventId)
                .eq('poll_type', 'restaurant')
                .single();
            pollId = existing['id'] as String;
          } else {
            rethrow;
          }
        }
      }
    }

    // Guard against duplicate restaurant options (same place_id already in poll).
    final existingPlaceIds = (_polls[eventId] ?? [])
        .where((p) => p.id == pollId)
        .firstOrNull
        ?.options
        .map((o) => o.placeMetadata?['place_id'] as String?)
        .whereType<String>()
        .toSet() ?? {};
    if (placeMetadata['place_id'] != null &&
        existingPlaceIds.contains(placeMetadata['place_id'])) {
      // Already pitched — return poll ID without inserting a duplicate.
      return pollId;
    }

    final currentOptions = (_polls[eventId] ?? [])
        .where((p) => p.id == pollId)
        .firstOrNull
        ?.options
        .length ?? 0;

    final optionData = await _db
        .from('event_poll_options')
        .insert({
          'poll_id': pollId,
          'text': optionText.trim(),
          'sort_order': currentOptions,
          'place_metadata': placeMetadata,
        })
        .select()
        .single();
    final optionId = optionData['id'] as String;

    // With UNIQUE(poll_id, option_id, user_id), each pitch auto-votes for its own option.
    await _db.from('event_poll_votes').insert({
      'poll_id': pollId,
      'option_id': optionId,
      'user_id': _userId,
    });

    unawaited(fetchPolls(eventId));
    return pollId;
  }

  Future<void> unvote(String pollId, String optionId, String eventId) async {
    _applyOptimisticUnvote(eventId, pollId, optionId);
    await _db
        .from('event_poll_votes')
        .delete()
        .eq('poll_id', pollId)
        .eq('option_id', optionId)
        .eq('user_id', _userId!);
    unawaited(fetchPolls(eventId));
  }

  void _applyOptimisticUnvote(
      String eventId, String pollId, String optionId) {
    final polls = _polls[eventId];
    if (polls == null) return;
    final idx = polls.indexWhere((p) => p.id == pollId);
    if (idx < 0) return;
    final poll = polls[idx];
    final newVotes = poll.votes
        .where((v) => !(v.optionId == optionId && v.userId == _userId))
        .toList();
    _polls[eventId]![idx] = poll.copyWithVotes(newVotes);
    notifyListeners();
  }

  Future<void> deletePoll(String pollId, String eventId) async {
    await _db.from('event_polls').delete().eq('id', pollId);
    _polls[eventId]?.removeWhere((p) => p.id == pollId);
    notifyListeners();
  }

  void _applyOptimisticVote(
      String eventId, String pollId, String optionId, String? replaceVoteId) {
    final polls = _polls[eventId];
    if (polls == null) return;
    final idx = polls.indexWhere((p) => p.id == pollId);
    if (idx < 0) return;
    final poll = polls[idx];
    final newVotes = [
      ...poll.votes.where((v) => v.id != replaceVoteId),
      EventPollVote(
        id: replaceVoteId ?? _uuid.v4(),
        pollId: pollId,
        optionId: optionId,
        userId: _userId!,
        createdAt: DateTime.now(),
      ),
    ];
    _polls[eventId]![idx] = poll.copyWithVotes(newVotes);
    notifyListeners();
  }

  Future<void> vote(String pollId, String optionId, String eventId) async {
    _applyOptimisticVote(eventId, pollId, optionId, null);
    await _db.from('event_poll_votes').insert({
      'poll_id': pollId,
      'option_id': optionId,
      'user_id': _userId,
    });
    unawaited(fetchPolls(eventId));
  }

  Future<void> changeVote(
      String pollId, String newOptionId, String eventId) async {
    final existingVoteId = _polls[eventId]
        ?.firstWhere((p) => p.id == pollId,
            orElse: () => throw StateError('poll not found'))
        .myVoteId(_userId!);
    _applyOptimisticVote(eventId, pollId, newOptionId, existingVoteId);
    await _db
        .from('event_poll_votes')
        .delete()
        .eq('poll_id', pollId)
        .eq('user_id', _userId!);
    await _db.from('event_poll_votes').insert({
      'poll_id': pollId,
      'option_id': newOptionId,
      'user_id': _userId,
    });
    unawaited(fetchPolls(eventId));
  }
}
