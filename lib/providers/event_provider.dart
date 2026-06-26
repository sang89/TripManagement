import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../models/event_bring_item.dart';
import '../models/event_session.dart';
import '../models/event_expense.dart';
import '../models/session_queue.dart';
import '../models/event_gift_pool.dart';
import '../models/event_poll.dart';
import '../models/event_guest.dart';
import '../models/event_photo.dart';
import '../models/event_prediction.dart';
import '../models/event_stop.dart';
import '../models/event_toast.dart';
import '../models/event_wish.dart';
import '../models/event_wishlist_item.dart';
import '../models/tournament.dart';
import '../utils/bracket_math.dart';
import '../utils/court_logic.dart';
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
  SupabaseClient get db => _db;

  List<Event> _events = [];
  bool _loaded = false;
  String? _loadError;
  String? _userId;
  RealtimeChannel? _realtimeChannel;

  // Debounce chat-background DB writes so rapid theme-picker taps don't spam
  // the database. Keyed by eventId so concurrent events don't interfere.
  final Map<String, Timer> _chatBgTimers = {};
  // Tracks the last value written to DB so we skip no-op writes.
  final Map<String, String?> _chatBgCommitted = {};

  // Emits sessionIds whenever the current user's roster entry is removed
  // (rejected, kicked, cancelled from another device). Widgets subscribe to
  // this stream and call setState directly so the rebuild is guaranteed — it
  // bypasses the notifyListeners → context.watch chain which can be swallowed
  // when Flutter considers the widget already clean.
  final _sessionStatusCleared = StreamController<String>.broadcast();
  Stream<String> get sessionStatusCleared => _sessionStatusCleared.stream;

  // Per-event caches for photos and expenses (fetched on demand).
  final Map<String, List<EventPhoto>> _photos = {};
  final Map<String, bool> _hasMorePhotos = {};
  static const _photoPageSize = 30;
  final Map<String, List<EventExpense>> _expenses = {};
  final Map<String, List<EventBringItem>> _bringItems = {};
  final Map<String, List<EventPoll>> _polls = {};

  // Session activity caches (fetched on demand for signup events only).
  final Map<String, List<SessionQueueActivity>> _sessionQueues = {};
  final Map<String, List<SessionQueueEntry>>    _queueEntries  = {}; // keyed by activityId
  final Map<String, List<SessionFreePoolEntry>> _freePool      = {}; // keyed by sessionId
  // O(1) index: activityId → (sessionId, eventId). Kept in sync with _sessionQueues
  // so entry-level Realtime handlers can always recompute the free pool even when
  // the activity was added via Realtime rather than fetchSessionQueues.
  final Map<String, ({String sessionId, String eventId})> _activityMeta = {};

  // Signup sessions that are happening right now (time window includes now),
  // across ALL of the user's events. Populated by fetchLiveSessions() — used by
  // the bottom-nav "Live" button to cycle through currently-live sessions.
  List<EventSession> _liveSessions = [];

  // Tournament caches (fetched on demand for tournament events only).
  final Map<String, List<TournamentDivision>> _divisions = {}; // by eventId
  final Map<String, List<TournamentEntrant>> _entrants = {};   // by divisionId
  final Map<String, List<TournamentMatch>> _matches = {};      // by divisionId
  final Map<String, List<Court>> _courts = {};                 // by eventId

  // Birthday-specific caches (fetched on demand for birthday events only).
  final Map<String, List<EventWishlistItem>> _wishlistItems = {};
  final Map<String, EventGiftPool?> _giftPools = {};
  final Map<String, List<EventPrediction>> _predictions = {};
  final Map<String, List<EventWish>> _wishes = {};
  final Map<String, List<EventToast>> _toasts = {};

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

  /// Count of pending invitations — mirrors the Invited tab filter exactly.
  int get pendingInviteCount => _events
      .where((e) => e.createdBy != _userId && !e.isPastFor(_userId))
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
  bool hasMorePhotos(String eventId) => _hasMorePhotos[eventId] ?? false;
  List<EventExpense> expensesFor(String eventId) => _expenses[eventId] ?? [];
  List<EventBringItem> bringItemsFor(String eventId) =>
      _bringItems[eventId] ?? [];
  List<EventPoll> pollsFor(String eventId) => _polls[eventId] ?? [];

  // Keyed by sessionId for both queues and free pool.
  List<SessionQueueActivity> queuesFor(String sessionId)   => _sessionQueues[sessionId] ?? [];
  List<SessionQueueEntry>    entriesFor(String activityId) => _queueEntries[activityId] ?? [];
  List<SessionFreePoolEntry> freePoolFor(String sessionId) => _freePool[sessionId] ?? [];

  /// Signup sessions whose time window includes now, across all the user's
  /// events. Refreshed by [fetchLiveSessions].
  List<EventSession> get liveSessions => List.unmodifiable(_liveSessions);

  List<EventWishlistItem> wishlistFor(String eventId) =>
      _wishlistItems[eventId] ?? [];
  EventGiftPool? giftPoolFor(String eventId) => _giftPools[eventId];
  List<EventPrediction> predictionsFor(String eventId) =>
      _predictions[eventId] ?? [];
  List<EventWish> wishesFor(String eventId) => _wishes[eventId] ?? [];
  List<EventToast> toastsFor(String eventId) => _toasts[eventId] ?? [];

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
        'honoree_name': e.honoreeDisplayName,
        'birth_year': e.birthYear,
        'predictions_revealed_at': e.predictionsRevealedAt?.toUtc().toIso8601String(),
        'wishes_revealed_at': e.wishesRevealedAt?.toUtc().toIso8601String(),
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
    unawaited(fetchLiveSessions());
  }

  void clear() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    for (final t in _chatBgTimers.values) {
      t.cancel();
    }
    _chatBgTimers.clear();
    for (final t in _divRefetchTimers.values) {
      t.cancel();
    }
    _divRefetchTimers.clear();
    for (final t in _entrantRefetchTimers.values) {
      t.cancel();
    }
    _entrantRefetchTimers.clear();
    _chatBgCommitted.clear();
    _events = [];
    _photos.clear();
    _hasMorePhotos.clear();
    _expenses.clear();
    _bringItems.clear();
    _polls.clear();
    _sessionQueues.clear();
    _queueEntries.clear();
    _freePool.clear();
    _activityMeta.clear();
    _liveSessions = [];
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
        'get_trip_profile_names',
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

  // Falls back to a DB query when the poll isn't in the in-memory cache.
  Future<String?> _resolveEventIdForPoll(String pollId) async {
    final cached = _eventIdForPoll(pollId);
    if (cached != null) return cached;
    try {
      final row = await _db
          .from('event_polls')
          .select('event_id')
          .eq('id', pollId)
          .maybeSingle();
      return row?['event_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  String? _eventIdForOption(String optionId) {
    for (final entry in _polls.entries) {
      for (final poll in entry.value) {
        if (poll.options.any((o) => o.id == optionId)) return entry.key;
      }
    }
    return null;
  }

  Future<String?> _resolveEventIdForOption(String optionId) async {
    final cached = _eventIdForOption(optionId);
    if (cached != null) return cached;
    try {
      final row = await _db
          .from('event_poll_options')
          .select('poll_id, event_polls(event_id)')
          .eq('id', optionId)
          .maybeSingle();
      final polls = row?['event_polls'] as Map<String, dynamic>?;
      return polls?['event_id'] as String?;
    } catch (_) {
      return null;
    }
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
              waitlistEnabled: row.containsKey('waitlist_enabled')
                  ? (row['waitlist_enabled'] as bool? ?? true)
                  : existing.waitlistEnabled,
              signupLockHours: row.containsKey('signup_lock_hours')
                  ? row['signup_lock_hours'] as int?
                  : existing.signupLockHours,
              chatBackground: row.containsKey('chat_background')
                  ? row['chat_background'] as String?
                  : existing.chatBackground,
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
            unawaited(_resolveEventIdForPoll(pollId).then((eventId) {
              if (eventId != null) unawaited(fetchPolls(eventId));
            }));
          },
        )

        // ── event_poll_options DELETE ───────────────────────────────────────
        // REPLICA IDENTITY FULL ensures poll_id is present in the old record.
        // Fires when a restaurant option is removed from the Cravings poll.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_poll_options',
          callback: (payload) {
            final row = payload.oldRecord;
            final pollId = row['poll_id'] as String?;
            final optionId = row['id'] as String?;
            if (pollId == null || optionId == null) return;
            // Evict the option from the in-memory cache immediately so
            // the Cravings tab "Added to group vote!" badge clears right away.
            for (final polls in _polls.values) {
              final idx = polls.indexWhere((p) => p.id == pollId);
              if (idx >= 0) {
                final poll = polls[idx];
                final newOptions = poll.options
                    .where((o) => o.id != optionId)
                    .toList();
                polls[idx] = poll.copyWithOptions(newOptions);
                notifyListeners();
                break;
              }
            }
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
            unawaited(_resolveEventIdForPoll(pollId).then((eventId) {
              if (eventId != null) unawaited(fetchPolls(eventId));
            }));
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
            unawaited(_resolveEventIdForPoll(pollId).then((eventId) {
              if (eventId != null) unawaited(fetchPolls(eventId));
            }));
          },
        )

        // ── event_poll_reactions INSERT ─────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_poll_reactions',
          callback: (payload) {
            final optionId = payload.newRecord['option_id'] as String?;
            if (optionId == null) return;
            unawaited(_resolveEventIdForOption(optionId).then((eventId) {
              if (eventId != null) unawaited(fetchPolls(eventId));
            }));
          },
        )

        // ── event_poll_reactions DELETE ──────────────────────────────────────
        // REPLICA IDENTITY FULL ensures option_id is present in the old record.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_poll_reactions',
          callback: (payload) {
            final optionId = payload.oldRecord['option_id'] as String?;
            if (optionId == null) return;
            unawaited(_resolveEventIdForOption(optionId).then((eventId) {
              if (eventId != null) unawaited(fetchPolls(eventId));
            }));
          },
        )

        // ── event_photos INSERT ─────────────────────────────────────────────
        // Patch in-place to preserve pagination offset and avoid re-fetching
        // the full list every time someone uploads.
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_photos',
          callback: (payload) {
            final eventId = payload.newRecord['event_id'] as String?;
            if (eventId == null || !_photos.containsKey(eventId)) return;
            try {
              final photo = _resolvePhotoUrls(
                  Map<String, dynamic>.from(payload.newRecord));
              // Skip if addPhoto() already prepended this row.
              if (_photos[eventId]!.any((p) => p.id == photo.id)) return;
              _photos[eventId] = [photo, ...(_photos[eventId]!)];
              notifyListeners();
            } catch (e) {
              debugPrint('EventProvider photos Realtime patch error: $e');
            }
          },
        )

        // ── event_photos DELETE ─────────────────────────────────────────────
        // REPLICA IDENTITY FULL ensures event_id is present in the old record.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_photos',
          callback: (payload) {
            final row = payload.oldRecord;
            final eventId = row['event_id'] as String?;
            final photoId = row['id'] as String?;
            if (eventId == null || photoId == null) return;
            _photos[eventId]?.removeWhere((p) => p.id == photoId);
            notifyListeners();
          },
        )

        // ── event_photos UPDATE (caption edits) ────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_photos',
          callback: (payload) {
            final eventId = payload.newRecord['event_id'] as String?;
            final photoId = payload.newRecord['id'] as String?;
            final caption = payload.newRecord['caption'] as String? ?? '';
            if (eventId == null || photoId == null) return;
            final list = _photos[eventId];
            if (list == null) return;
            final idx = list.indexWhere((p) => p.id == photoId);
            if (idx != -1) {
              list[idx] = list[idx].copyWith(caption: caption);
              notifyListeners();
            }
          },
        )

        // ── event_expenses INSERT / UPDATE / DELETE ─────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_expenses',
          callback: (payload) {
            final eventId = payload.newRecord['event_id'] as String?;
            if (eventId == null) return;
            unawaited(fetchExpenses(eventId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_expenses',
          callback: (payload) {
            final eventId = payload.newRecord['event_id'] as String?;
            if (eventId == null) return;
            unawaited(fetchExpenses(eventId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_expenses',
          callback: (payload) {
            // event_expenses uses REPLICA IDENTITY DEFAULT so event_id may be
            // absent on delete; fall back to a full refetch across loaded events.
            final eventId = payload.oldRecord['event_id'] as String?;
            if (eventId != null) {
              unawaited(fetchExpenses(eventId));
            } else {
              for (final id in _expenses.keys.toList()) {
                unawaited(fetchExpenses(id));
              }
            }
          },
        )

        // ── event_bring_list_items INSERT / UPDATE / DELETE ─────────────────
        // REPLICA IDENTITY FULL set in migration 20260605060000.
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_bring_list_items',
          callback: (payload) {
            final eventId = payload.newRecord['event_id'] as String?;
            if (eventId == null) return;
            unawaited(fetchBringList(eventId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_bring_list_items',
          callback: (payload) {
            final eventId = payload.newRecord['event_id'] as String?;
            if (eventId == null) return;
            unawaited(fetchBringList(eventId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_bring_list_items',
          callback: (payload) {
            final eventId = payload.oldRecord['event_id'] as String?;
            if (eventId != null) {
              unawaited(fetchBringList(eventId));
            }
          },
        )

        // ── event_sessions ─────────────────────────────────────────────────
        // INSERT: new session added by organizer on another device.
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_sessions',
          callback: (payload) {
            final row = payload.newRecord;
            final eventId = row['event_id'] as String?;
            if (eventId == null) return;
            unawaited(fetchUpcomingSessions(eventId));
            // Only reset past sessions if they haven't been loaded yet.
            // Resetting would discard pages the user already paginated through.
            if (!(_pastSessions.containsKey(eventId))) {
              unawaited(fetchPastSessions(eventId));
            }
          },
        )

        // DELETE: organizer deleted a session on another device.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_sessions',
          callback: (payload) {
            final sessionId = payload.oldRecord['id'] as String?;
            final eventId = payload.oldRecord['event_id'] as String?;
            if (sessionId == null || eventId == null) return;
            _upcomingSessions[eventId]
                ?.removeWhere((s) => s.id == sessionId);
            _pastSessions[eventId]
                ?.removeWhere((s) => s.id == sessionId);
            _sessionRosters.remove(sessionId);
            _mySessionStatuses.remove(sessionId);
            notifyListeners();
          },
        )

        // UPDATE: going_count / waitlist_count changed (trigger fires after
        //         every roster INSERT/UPDATE/DELETE), or session metadata edited.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_sessions',
          callback: (payload) {
            final row = payload.newRecord;
            final sessionId = row['id'] as String?;
            final eventId = row['event_id'] as String?;
            if (sessionId == null || eventId == null) return;
            // B9: skip rebuild for events the user isn't currently viewing.
            if (_watchedEventId != null && _watchedEventId != eventId) return;
            _patchSessionInCache(
              eventId,
              sessionId,
              (s) => EventSession.fromJson({
                'id': s.id,
                'event_id': s.eventId,
                'session_number': s.sessionNumber,
                'start_at': (row.containsKey('start_at') ? row['start_at'] : null) ?? s.startAt.toIso8601String(),
                'end_at': row.containsKey('end_at') ? row['end_at'] : s.endAt?.toIso8601String(),
                'invite_code': s.inviteCode,
                'created_at': s.createdAt.toIso8601String(),
                'going_count': row['going_count'] as int? ?? s.goingCount,
                'waitlist_count': row['waitlist_count'] as int? ?? s.waitlistCount,
                'pending_count': row['pending_count'] as int? ?? s.pendingCount,
                'capacity': row.containsKey('capacity') ? row['capacity'] : s.capacity,
                'waitlist_enabled': row.containsKey('waitlist_enabled') ? row['waitlist_enabled'] : s.waitlistEnabled,
                'signup_lock_hours': row.containsKey('signup_lock_hours') ? row['signup_lock_hours'] : s.signupLockHours,
                'is_public': row.containsKey('is_public') ? row['is_public'] : s.isPublic,
                'requires_approval': row.containsKey('requires_approval') ? row['requires_approval'] : s.requiresApproval,
                'is_active': row.containsKey('is_active') ? row['is_active'] : s.isActive,
                'is_active_override': row.containsKey('is_active_override') ? row['is_active_override'] : s.isActiveOverride,
                'notes': row.containsKey('notes') ? row['notes'] : s.notes,
              }),
            );
            notifyListeners();
            // The session count changed, meaning a roster entry was added,
            // removed, promoted, or demoted. Refresh the roster so the player
            // cards stay in sync for all members — this is the only Realtime
            // signal that reliably reaches every subscriber regardless of RLS.
            if (_sessionRosters.containsKey(sessionId)) {
              unawaited(refreshSessionRoster(sessionId));
            }
          },
        )

        // ── event_session_roster ────────────────────────────────────────────
        // INSERT: someone signed up (via QR scan or organizer-added).
        // Patch the cache directly from payload — no DB round-trip needed.
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_session_roster',
          callback: (payload) {
            final row = payload.newRecord;
            final sessionId = row['session_id'] as String?;
            if (sessionId == null) return;

            // Keep _mySessionStatuses in sync even when roster isn't expanded.
            final uid = _db.auth.currentUser?.id;
            final rowUserId = row['user_id'] as String?;
            if (uid != null && rowUserId == uid) {
              _mySessionStatuses[sessionId] = (
                status: row['status'] as String? ?? 'going',
                order: (row['signup_order'] as int?) ?? 0,
              );
            }

            // Append to cached roster; fall back to full refetch if parse fails.
            if (_sessionRosters.containsKey(sessionId)) {
              try {
                final entry = EventSessionRosterEntry.fromJson(row);
                final roster =
                    List<EventSessionRosterEntry>.from(_sessionRosters[sessionId]!);
                if (!roster.any((r) => r.id == entry.id)) {
                  roster.add(entry);
                  roster.sort(_rosterOrder);
                  _sessionRosters[sessionId] = roster;
                }
              } catch (_) {
                unawaited(refreshSessionRoster(sessionId));
              }
            }
            notifyListeners();
          },
        )

        // UPDATE: status change (promote/demote), attendance marked,
        //         or signup_confirmed toggled.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_session_roster',
          callback: (payload) {
            final row = payload.newRecord;
            final sessionId = row['session_id'] as String?;
            final rosterId = row['id'] as String?;
            if (sessionId == null || rosterId == null) return;

            final newStatus = row['status'] as String?;
            final uid = _db.auth.currentUser?.id;
            final rowUserId = row['user_id'] as String?;
            final isOwnRow = uid != null && rowUserId == uid;

            // 'rejected' / 'removed' are transient signals: the DB DELETEs the
            // row immediately after. Clear state eagerly, then do a full DB
            // refresh — the UPDATE and DELETE happen in the same transaction so
            // Realtime may only deliver one event; the DB fetch is authoritative.
            if (newStatus == 'rejected' || newStatus == 'removed') {
              if (isOwnRow) {
                _mySessionStatuses.remove(sessionId);
                _sessionStatusCleared.add(sessionId);
              }
              final roster = _sessionRosters[sessionId];
              if (roster != null) {
                _sessionRosters[sessionId] =
                    roster.where((r) => r.id != rosterId).toList();
              }
              notifyListeners();
              unawaited(refreshSessionRoster(sessionId));
              return;
            }

            // Keep the status chip in sync even when the roster isn't expanded.
            if (isOwnRow && newStatus != null) {
              final newOrder = row['signup_order'] as int?;
              _mySessionStatuses[sessionId] = (
                status: newStatus,
                order: newOrder ?? _mySessionStatuses[sessionId]?.order ?? 0,
              );
              notifyListeners();
            }

            if (!_sessionRosters.containsKey(sessionId)) return;
            _patchRosterEntry(
              sessionId,
              rosterId,
              (r) => EventSessionRosterEntry(
                id: r.id,
                sessionId: r.sessionId,
                userId: r.userId,
                displayName: r.displayName,
                email: r.email,
                phone: r.phone,
                status: newStatus ?? r.status,
                signupOrder: row['signup_order'] as int? ?? r.signupOrder,
                attended: row.containsKey('attended')
                    ? row['attended'] as bool?
                    : r.attended,
                signupConfirmed:
                    row['signup_confirmed'] as bool? ?? r.signupConfirmed,
                signedUpAt: r.signedUpAt,
              ),
              // signup_order may have changed (promote/demote/reorder) — keep
              // the list sorted so other devices see the correct visual order.
              resort: true,
            );
          },
        )

        // DELETE: cancelled or removed by organizer.
        // B8: own-row status clearing is handled exclusively by the filtered
        // subscription below — skip it here to avoid duplicate notifyListeners()
        // and double refreshSessionRoster() calls for the current user's entry.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_session_roster',
          callback: (payload) {
            final old = payload.oldRecord;
            final sessionId = old['session_id'] as String?;
            final rosterId = old['id'] as String?;
            if (sessionId == null || rosterId == null) return;

            // Remove from cached roster if loaded.
            final roster = _sessionRosters[sessionId];
            if (roster != null) {
              _sessionRosters[sessionId] =
                  roster.where((r) => r.id != rosterId).toList();
            }

            // B9: skip rebuild if the deleted row belongs to an event the user
            // isn't currently viewing (the filtered handler will fire for own rows).
            final uid = _db.auth.currentUser?.id;
            final rowUserId = old['user_id'] as String?;
            final isOwnEntry = uid != null && rowUserId == uid;
            if (isOwnEntry) return; // filtered handler owns this case

            notifyListeners();
          },
        )

        // ── Own-row subscriptions (filtered by user_id) ────────────────────
        // The unfiltered handlers above rely on Supabase applying RLS to decide
        // which events to deliver. For tables with restricted SELECT policies
        // (like "guest reads own entry"), Supabase requires an explicit filter
        // to reliably deliver events. These filtered subscriptions guarantee
        // that the current user always receives their own row's status changes
        // (approve, reject, demote, kick) regardless of RLS evaluation.
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'event_session_roster',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'user_id', value: _userId!),
          callback: (payload) {
            final row = payload.newRecord;
            final sessionId = row['session_id'] as String?;
            if (sessionId == null) return;
            final newStatus = row['status'] as String?;
            if (newStatus == null) return;

            if (newStatus == 'rejected' || newStatus == 'removed') {
              _mySessionStatuses.remove(sessionId);
              _sessionStatusCleared.add(sessionId);
              notifyListeners();
              unawaited(refreshSessionRoster(sessionId));
              return;
            }
            final newOrder = row['signup_order'] as int?;
            _mySessionStatuses[sessionId] = (
              status: newStatus,
              order: newOrder ?? _mySessionStatuses[sessionId]?.order ?? 0,
            );
            notifyListeners();
            unawaited(refreshSessionRoster(sessionId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_session_roster',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'user_id', value: _userId!),
          callback: (payload) {
            final old = payload.oldRecord;
            final sessionId = old['session_id'] as String?;
            if (sessionId == null) return;
            _mySessionStatuses.remove(sessionId);
            _sessionStatusCleared.add(sessionId);
            notifyListeners();
            unawaited(refreshSessionRoster(sessionId));
          },
        )

        // ── session_queue_activities ────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'session_queue_activities',
          callback: (p) => handleQueueActivityInsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'session_queue_activities',
          callback: (p) => handleQueueActivityUpdate(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'session_queue_activities',
          callback: (p) => handleQueueActivityDelete(p.oldRecord),
        )

        // ── session_queue_entries ───────────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'session_queue_entries',
          callback: (p) => handleQueueEntryInsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'session_queue_entries',
          callback: (p) => handleQueueEntryUpdate(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'session_queue_entries',
          callback: (p) => handleQueueEntryDelete(p.oldRecord),
        )

        // ── tournament_divisions (INSERT/UPDATE/DELETE) ─────────────────────
        // The count triggers fire an UPDATE on the division row after every
        // entrant/match change — the reliable signal all members can SELECT.
        // Reconstruct the full object via fromJson (never partial-patch).
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tournament_divisions',
          callback: (p) => _handleDivisionUpsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tournament_divisions',
          callback: (p) => _handleDivisionUpsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tournament_divisions',
          callback: (p) {
            final id = p.oldRecord['id'] as String?;
            final eventId = p.oldRecord['event_id'] as String?;
            if (id == null || eventId == null) return;
            final l = _divisions[eventId];
            if (l != null) _divisions[eventId] = l.where((d) => d.id != id).toList();
            _entrants.remove(id);
            _matches.remove(id);
            notifyListeners();
          },
        )

        // ── tournament_entrants (INSERT/UPDATE/DELETE) ──────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tournament_entrants',
          callback: (p) => _handleEntrantUpsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tournament_entrants',
          callback: (p) => _handleEntrantUpsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tournament_entrants',
          callback: (p) {
            final id = p.oldRecord['id'] as String?;
            final divisionId = p.oldRecord['division_id'] as String?;
            if (id == null || divisionId == null) return;
            final l = _entrants[divisionId];
            if (l != null) _entrants[divisionId] = l.where((e) => e.id != id).toList();
            notifyListeners();
          },
        )

        // ── tournament_entrant_players (roster changes) ─────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tournament_entrant_players',
          callback: (p) =>
              _handleEntrantPlayerChange(p.newRecord['entrant_id'] as String?),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tournament_entrant_players',
          callback: (p) =>
              _handleEntrantPlayerChange(p.newRecord['entrant_id'] as String?),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tournament_entrant_players',
          callback: (p) =>
              _handleEntrantPlayerChange(p.oldRecord['entrant_id'] as String?),
        )

        // ── tournament_tie_submatches (a tie's sub-matches) ─────────────────
        // A sub-match score recomputes the parent tie + auto-advances; refetch
        // the owning division's matches (which carry nested sub-matches).
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tournament_tie_submatches',
          callback: (p) =>
              _handleSubmatchChange(p.newRecord['tie_match_id'] as String?),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tournament_tie_submatches',
          callback: (p) =>
              _handleSubmatchChange(p.newRecord['tie_match_id'] as String?),
        )

        // ── tournament_matches (INSERT/UPDATE/DELETE) ───────────────────────
        // A score record / auto-advance mutates entrant + winner across rows;
        // refetch the division's matches (with nested games) when cached.
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tournament_matches',
          callback: (p) => _handleMatchChange(p.newRecord['division_id'] as String?),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tournament_matches',
          callback: (p) => _handleMatchChange(p.newRecord['division_id'] as String?),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tournament_matches',
          callback: (p) => _handleMatchChange(p.oldRecord['division_id'] as String?),
        )

        // ── tournament_match_games (INSERT/UPDATE/DELETE) ───────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tournament_match_games',
          callback: (p) => _handleGameChange(p.newRecord['match_id'] as String?),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tournament_match_games',
          callback: (p) => _handleGameChange(p.newRecord['match_id'] as String?),
        )

        // ── tournament_courts (INSERT/UPDATE/DELETE) ────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tournament_courts',
          callback: (p) => _handleCourtUpsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tournament_courts',
          callback: (p) => _handleCourtUpsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tournament_courts',
          callback: (p) {
            final id = p.oldRecord['id'] as String?;
            final eventId = p.oldRecord['event_id'] as String?;
            if (id == null || eventId == null) return;
            final l = _courts[eventId];
            if (l != null) _courts[eventId] = l.where((c) => c.id != id).toList();
            notifyListeners();
          },
        )

        .subscribe();
  }

  // ── Tournament Realtime handlers ────────────────────────────────────────────

  void _handleDivisionUpsert(Map<String, dynamic> row) {
    final eventId = row['event_id'] as String?;
    if (eventId == null) return;
    // Only patch caches we already hold (event has been opened).
    if (!_divisions.containsKey(eventId)) return;
    // Skip events not currently on screen (refreshed on open).
    if (_watchedEventId != null && _watchedEventId != eventId) return;
    final division = TournamentDivision.fromJson(row);
    final list = List<TournamentDivision>.from(_divisions[eventId]!);
    final idx = list.indexWhere((d) => d.id == division.id);
    if (idx >= 0) {
      list[idx] = division;
    } else {
      list.add(division);
    }
    _divisions[eventId] = list;
    notifyListeners();
  }

  void _handleEntrantUpsert(Map<String, dynamic> row) {
    final divisionId = row['division_id'] as String?;
    if (divisionId == null || !_entrants.containsKey(divisionId)) return;
    if (!_divisionIsWatched(divisionId)) return;
    final entrant = TournamentEntrant.fromJson(row);
    final list = List<TournamentEntrant>.from(_entrants[divisionId]!);
    final idx = list.indexWhere((e) => e.id == entrant.id);
    if (idx >= 0) {
      list[idx] = entrant;
    } else {
      list.add(entrant);
    }
    _entrants[divisionId] = list;
    notifyListeners();
  }

  // Debounce timers so a burst of match + game + sub-match + division Realtime
  // events from a single score entry collapses into ONE refetch per division
  // — critical at thousands of matches with many connected clients.
  final Map<String, Timer> _divRefetchTimers = {};
  final Map<String, Timer> _entrantRefetchTimers = {};
  static const _kTournamentRefetchDebounce = Duration(milliseconds: 350);

  /// True when the change for [divisionId] is for the tournament the user is
  /// currently viewing. Skips work for events not on screen (mirrors the
  /// session `_watchedEventId` scoping).
  bool _divisionIsWatched(String divisionId) {
    if (_watchedEventId == null) return true; // nothing scoped → allow
    final eventId = _eventIdForDivision(divisionId);
    // If we can't resolve the event (division not cached), fall back to the
    // cache-presence guard at the call site.
    return eventId == null || eventId == _watchedEventId;
  }

  void _scheduleMatchRefetch(String divisionId) {
    if (!_matches.containsKey(divisionId)) return; // only cached divisions
    if (!_divisionIsWatched(divisionId)) return;
    _divRefetchTimers[divisionId]?.cancel();
    _divRefetchTimers[divisionId] =
        Timer(_kTournamentRefetchDebounce, () => unawaited(fetchMatches(divisionId)));
  }

  void _scheduleEntrantRefetch(String divisionId) {
    if (!_entrants.containsKey(divisionId)) return;
    if (!_divisionIsWatched(divisionId)) return;
    _entrantRefetchTimers[divisionId]?.cancel();
    _entrantRefetchTimers[divisionId] =
        Timer(_kTournamentRefetchDebounce, () => unawaited(fetchEntrants(divisionId)));
  }

  String? _divisionIdForMatch(String matchId) {
    for (final entry in _matches.entries) {
      if (entry.value.any((m) => m.id == matchId)) return entry.key;
    }
    return null;
  }

  void _handleMatchChange(String? divisionId) {
    if (divisionId == null) return;
    _scheduleMatchRefetch(divisionId);
  }

  void _handleEntrantPlayerChange(String? entrantId) {
    if (entrantId == null) return;
    for (final entry in _entrants.entries) {
      if (entry.value.any((e) => e.id == entrantId)) {
        _scheduleEntrantRefetch(entry.key);
        return;
      }
    }
  }

  void _handleSubmatchChange(String? tieMatchId) {
    if (tieMatchId == null) return;
    final divisionId = _divisionIdForMatch(tieMatchId);
    if (divisionId != null) _scheduleMatchRefetch(divisionId);
  }

  void _handleGameChange(String? matchId) {
    if (matchId == null) return;
    final divisionId = _divisionIdForMatch(matchId);
    if (divisionId != null) _scheduleMatchRefetch(divisionId);
  }

  void _handleCourtUpsert(Map<String, dynamic> row) {
    final eventId = row['event_id'] as String?;
    if (eventId == null || !_courts.containsKey(eventId)) return;
    if (_watchedEventId != null && _watchedEventId != eventId) return;
    final court = Court.fromJson(row);
    final list = List<Court>.from(_courts[eventId]!);
    final idx = list.indexWhere((c) => c.id == court.id);
    if (idx >= 0) {
      list[idx] = court;
    } else {
      list.add(court);
    }
    _courts[eventId] = list;
    notifyListeners();
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
    EventType eventType = EventType.trip,
    String? startLocation,
    double? startLat,
    double? startLng,
    double? budgetPerHead,
    List<String> cuisineTags = const [],
    DateTime? rsvpDeadline,
    String? vibe,
    String? honoreeDisplayName,
    int? birthYear,
    bool waitlistEnabled = true,
    int? signupLockHours,
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
      'p_honoree_name': ?honoreeDisplayName,
      'p_birth_year': ?birthYear,
      'p_waitlist_enabled': waitlistEnabled,
      'p_signup_lock_hours': ?signupLockHours,
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
      'honoree_name': updated.honoreeDisplayName,
      'birth_year': updated.birthYear,
      'waitlist_enabled': updated.waitlistEnabled,
      'signup_lock_hours': updated.signupLockHours,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', updated.id);

    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      _events[idx] = updated;
      notifyListeners();
      unawaited(_saveCache());
    }
  }

  void updateChatBackground(String eventId, String? key) {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx < 0) return;

    // Optimistic update — immediate, no DB call yet.
    _events[idx] = _events[idx].copyWith(
      chatBackground: key,
      clearChatBackground: key == null,
    );
    notifyListeners();

    // Debounce: cancel any pending write for this event and schedule a new
    // one 600 ms later. Only fires if the value differs from last committed.
    _chatBgTimers[eventId]?.cancel();
    _chatBgTimers[eventId] = Timer(const Duration(milliseconds: 600), () async {
      _chatBgTimers.remove(eventId);

      // Skip write if value hasn't changed since last successful DB write.
      if (_chatBgCommitted[eventId] == key) return;

      try {
        await _db
            .from('events')
            .update({
              'chat_background': key,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', eventId);
        _chatBgCommitted[eventId] = key;
        unawaited(_saveCache());
      } catch (e, st) {
        debugPrint('EventProvider.updateChatBackground error: $e\n$st');
        unawaited(load());
      }
    });
  }

  Future<void> deleteEvent(String eventId) async {
    await _db.from('events').delete().eq('id', eventId);
    _events = _events.where((e) => e.id != eventId).toList();
    _photos.remove(eventId);
    _hasMorePhotos.remove(eventId);
    _expenses.remove(eventId);
    _bringItems.remove(eventId);
    _polls.remove(eventId);
    _wishlistItems.remove(eventId);
    _giftPools.remove(eventId);
    _predictions.remove(eventId);
    _wishes.remove(eventId);
    _toasts.remove(eventId);
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

  /// Per-user "Move to Past" / "Move to Upcoming".
  ///
  /// Sets `is_archived` on the current user's own `event_guests` row. The change
  /// is scoped to this user only — other members keep seeing the event in their
  /// own Upcoming tab. The existing event_guests Realtime UPDATE handler syncs
  /// the flag to this user's other devices automatically.
  Future<void> setEventArchived(String eventId, bool archived) async {
    final event = getById(eventId);
    if (event == null) return;

    EventGuest? myGuest;
    for (final g in event.guests) {
      if (g.userId == _userId) {
        myGuest = g;
        break;
      }
    }
    if (myGuest == null) return;

    await _db
        .from('event_guests')
        .update({'is_archived': archived}).eq('id', myGuest.id);

    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) {
      final updatedGuests = _events[idx].guests.map((g) {
        return g.id == myGuest!.id ? g.copyWith(isArchived: archived) : g;
      }).toList();
      _events[idx] = _events[idx].copyWith(guests: updatedGuests);
      notifyListeners();
      unawaited(_saveCache());
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
    // Linked users start as pending (they must accept); unlinked guests are accepted immediately.
    final status = userId != null ? 'pending' : 'accepted';
    final data = await _db.from('event_guests').insert({
      'event_id': eventId,
      'user_id': ?userId,
      'display_name': displayName,
      'email': ?(email?.isNotEmpty == true ? email : null),
      'phone': ?(phone?.isNotEmpty == true ? phone : null),
      'status': status,
      if (userId == null) 'rsvp_at': DateTime.now().toUtc().toIso8601String(),
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

  // ─── Session management (signup events) ──────────────────────────────────
  //
  // Design: sessions and rosters are paginated and cached separately.
  //
  // Session list:
  //   • _upcomingSessions[eventId] — start_at >= now, ORDER BY start_at ASC
  //   • _pastSessions[eventId]     — start_at < now,  ORDER BY start_at DESC
  //   • Each page is _kSessionsPageSize rows (no roster data, counts from DB columns)
  //
  // Roster (per session, loaded on demand):
  //   • _sessionRosters[sessionId] — ORDER BY signup_order ASC
  //   • Each page is _kRosterPageSize rows
  //   • hasMore tracked in _hasMoreRoster[sessionId]

  static const _kSessionsPageSize = 20;
  static const _kRosterPageSize = 100;

  final Map<String, List<EventSession>> _upcomingSessions = {};
  final Map<String, bool> _hasMoreUpcoming = {};
  final Map<String, List<EventSession>> _pastSessions = {};
  final Map<String, bool> _hasMorePast = {};
  final Map<String, bool> _loadingPast = {};

  final Map<String, List<EventSessionRosterEntry>> _sessionRosters = {};
  final Map<String, bool> _hasMoreRoster = {};

  // sessionId → ('going'|'waitlisted', signup_order) for the current user
  final Map<String, ({String status, int order})> _mySessionStatuses = {};

  // B9: event currently open in the detail screen; Realtime callbacks skip
  // notifyListeners() for unrelated events to avoid unnecessary rebuilds.
  String? _watchedEventId;

  // ── Public accessors ────────────────────────────────────────────────────

  List<EventSession> upcomingSessionsFor(String eventId) =>
      _upcomingSessions[eventId] ?? [];

  List<EventSession> pastSessionsFor(String eventId) =>
      _pastSessions[eventId] ?? [];

  bool hasMoreUpcomingFor(String eventId) => _hasMoreUpcoming[eventId] ?? false;

  bool hasMorePastFor(String eventId) => _hasMorePast[eventId] ?? false;

  List<EventSessionRosterEntry>? rosterFor(String sessionId) =>
      _sessionRosters[sessionId];

  bool hasMoreRosterFor(String sessionId) => _hasMoreRoster[sessionId] ?? false;

  /// Returns the current user's status for [sessionId], or null if not signed up.
  ({String status, int order})? myStatusFor(String sessionId) =>
      _mySessionStatuses[sessionId];

  // B9: Call from event detail screen initState/dispose to scope Realtime
  // notifyListeners() to the currently viewed event.
  void watchEvent(String? eventId) => _watchedEventId = eventId;

  // ═══════════════════════════════════════════════════════════════════════════
  // Tournament (divisions / entrants / matches / courts)
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Accessors ─────────────────────────────────────────────────────────────
  List<TournamentDivision> divisionsFor(String eventId) =>
      _divisions[eventId] ?? const [];

  List<TournamentEntrant> entrantsFor(String divisionId) =>
      _entrants[divisionId] ?? const [];

  /// Active (non-withdrawn) entrants for a division.
  List<TournamentEntrant> activeEntrantsFor(String divisionId) =>
      entrantsFor(divisionId).where((e) => !e.isWithdrawn).toList();

  List<TournamentMatch> matchesFor(String divisionId) =>
      _matches[divisionId] ?? const [];

  List<Court> courtsFor(String eventId) => _courts[eventId] ?? const [];

  // ── Fetching ──────────────────────────────────────────────────────────────

  /// Loads divisions + courts for a tournament event. Call when the Organize
  /// tab opens (lazy, like signup session queues).
  Future<void> fetchTournament(String eventId) async {
    await Future.wait([fetchDivisions(eventId), fetchCourts(eventId)]);
  }

  Future<void> fetchDivisions(String eventId) async {
    final rows = await _db
        .from('tournament_divisions')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: true) as List<dynamic>;
    _divisions[eventId] = rows
        .map((r) => TournamentDivision.fromJson(r as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> fetchEntrants(String divisionId) async {
    final rows = await _db
        .from('tournament_entrants')
        .select('*, tournament_entrant_players(*)')
        .eq('division_id', divisionId)
        .order('seed', ascending: true, nullsFirst: false)
        .order('registered_at', ascending: true) as List<dynamic>;
    _entrants[divisionId] = rows
        .map((r) => TournamentEntrant.fromJson(r as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> fetchMatches(String divisionId) async {
    final rows = await _db
        .from('tournament_matches')
        .select('*, tournament_match_games(*), tournament_tie_submatches(*)')
        .eq('division_id', divisionId)
        .order('round_number', ascending: true)
        .order('match_number', ascending: true) as List<dynamic>;
    _matches[divisionId] = rows
        .map((r) => TournamentMatch.fromJson(r as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> fetchCourts(String eventId) async {
    final rows = await _db
        .from('tournament_courts')
        .select()
        .eq('event_id', eventId)
        .order('sort_order', ascending: true) as List<dynamic>;
    _courts[eventId] = rows
        .map((r) => Court.fromJson(r as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  // ── Division mutations ──────────────────────────────────────────────────────

  Future<TournamentDivision> createDivision({
    required String eventId,
    required String name,
    required String sport,
    required Discipline discipline,
    required String skillLevel,
    required DivisionFormat format,
    required ScoringConfig scoringConfig,
    int? entrantCap,
    int? poolCount,
    int? advancePerPool,
    EntrantKind entrantKind = EntrantKind.individual,
    int? rosterSize,
    TieConfig? tieConfig,
  }) async {
    final rows = await _db.rpc('create_tournament_division', params: {
      'p_event_id': eventId,
      'p_name': name,
      'p_sport': sport,
      'p_discipline': discipline.dbValue,
      'p_skill_level': skillLevel,
      'p_format': format.dbValue,
      'p_scoring_config': scoringConfig.toJson(),
      'p_entrant_cap': entrantCap,
      'p_pool_count': poolCount,
      'p_advance_per_pool': advancePerPool,
      'p_entrant_kind': entrantKind.dbValue,
      'p_roster_size': rosterSize,
      'p_tie_config': tieConfig?.toJson(),
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Failed to create division');
    final division =
        TournamentDivision.fromJson(rows.first as Map<String, dynamic>);
    final list = List<TournamentDivision>.from(_divisions[eventId] ?? const []);
    list.add(division);
    _divisions[eventId] = list;
    notifyListeners();
    return division;
  }

  /// Creates multiple linked divisions in one shot from the bracket builder.
  ///
  /// For each segment: creates the division, registers its entrants, then
  /// generates the bracket. [sharedFields] provides sport/discipline/etc. shared
  /// across all lanes. Returns the list of created divisions.
  Future<List<TournamentDivision>> createDivisionBundle({
    required String eventId,
    required List<BracketSegmentConfig> segments,
    required String sport,
    required Discipline discipline,
    required String skillLevel,
    EntrantKind entrantKind = EntrantKind.individual,
  }) async {
    final created = <TournamentDivision>[];
    for (final seg in segments) {
      final division = await createDivision(
        eventId: eventId,
        name: seg.name,
        sport: sport,
        discipline: discipline,
        skillLevel: skillLevel,
        format: seg.format,
        scoringConfig: seg.scoringConfig,
        poolCount: seg.poolCount,
        advancePerPool: seg.advancePerPool,
        entrantKind: entrantKind,
      );
      for (final draft in seg.entrants) {
        await registerEntrant(
          divisionId: division.id,
          teamName: draft.teamName,
          player1Name: draft.player1Name,
          player2Name: draft.player2Name,
        );
      }
      // Only auto-generate if the format is not custom (custom = manual build).
      if (seg.format != DivisionFormat.custom) {
        await generateBracket(division);
      }
      created.add(division);
    }
    return created;
  }

  Future<TournamentDivision> updateDivision({
    required String divisionId,
    required String eventId,
    String? name,
    ScoringConfig? scoringConfig,
    int? entrantCap,
    bool clearEntrantCap = false,
    int? poolCount,
    int? advancePerPool,
  }) async {
    final rows = await _db.rpc('update_tournament_division', params: {
      'p_division_id': divisionId,
      'p_name': name,
      'p_scoring_config': scoringConfig?.toJson(),
      'p_entrant_cap': entrantCap,
      'p_clear_entrant_cap': clearEntrantCap,
      'p_pool_count': poolCount,
      'p_advance_per_pool': advancePerPool,
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Failed to update division');
    final division =
        TournamentDivision.fromJson(rows.first as Map<String, dynamic>);
    _replaceDivision(eventId, division);
    notifyListeners();
    return division;
  }

  /// Generates the bracket/schedule for a division. The plan (seeding,
  /// pairings, byes, next-match wiring) is computed in Dart and inserted by the
  /// generate_division_bracket RPC. Refetches matches + division afterwards.
  Future<void> generateBracket(TournamentDivision division) async {
    final entrants = activeEntrantsFor(division.id);
    if (entrants.length < 2) {
      throw Exception('Need at least 2 teams to generate a bracket');
    }
    // Seed by current order (seed then registration order from fetchEntrants).
    final seededIds = entrants.map((e) => e.id).toList();
    final plan = buildBracketPlan(division, seededIds);
    await _db.rpc('generate_division_bracket', params: {
      'p_division_id': division.id,
      'p_plan': plan.matches.map((m) => m.toJson()).toList(),
      'p_seeds': plan.seeds.map((k, v) => MapEntry(k, v)),
    });
    await Future.wait([
      fetchMatches(division.id),
      fetchDivisions(division.eventId),
      fetchEntrants(division.id),
    ]);
  }

  /// Records per-game scores for a match. The RPC derives winners, completes
  /// the match, auto-advances the winner into the next match, and frees the
  /// court. Refetches the division's matches (auto-advance mutates a second row)
  /// + the division (status/counts).
  Future<void> recordMatchScore(
    TournamentMatch match,
    List<(int score1, int score2)> games,
  ) async {
    final payload = [
      for (var i = 0; i < games.length; i++)
        {
          'game_number': i + 1,
          'entrant1_score': games[i].$1,
          'entrant2_score': games[i].$2,
        },
    ];
    await _db.rpc('record_match_score', params: {
      'p_match_id': match.id,
      'p_games': payload,
    });
    await fetchMatches(match.divisionId);
    final eventId = _eventIdForDivision(match.divisionId);
    if (eventId != null) await fetchDivisions(eventId);
  }

  /// Seeds the single-elimination playoff for a pools→playoff division from the
  /// completed pool standings. The plan is computed in Dart.
  Future<void> seedPlayoffs(TournamentDivision division) async {
    final entrants = activeEntrantsFor(division.id);
    final poolMatches = matchesFor(division.id)
        .where((m) => m.bracketType == BracketType.pool)
        .toList();

    // Guard: all pool matches must be decided (completed, walkover, or bye).
    final incomplete = poolMatches.where((m) => !m.isDecided);
    if (incomplete.isNotEmpty) {
      throw StateError(
          '${incomplete.length} pool match(es) are not yet decided.');
    }

    final plan = buildPlayoffFromPools(
        entrants, poolMatches, division.advancePerPool ?? 2,
        isTie: division.entrantKind == EntrantKind.team);
    await _db.rpc('seed_division_playoffs', params: {
      'p_division_id': division.id,
      'p_plan': plan.matches.map((m) => m.toJson()).toList(),
    });
    await fetchMatches(division.id);
    final eventId = _eventIdForDivision(division.id);
    if (eventId != null) await fetchDivisions(eventId);
  }

  /// Records the games of one tie sub-match. The RPC derives the sub-match
  /// winner, recomputes the tie, and auto-advances the tie winner — so refetch
  /// the whole division's matches.
  Future<void> recordSubmatchScore(
    String submatchId,
    String divisionId,
    List<(int side1, int side2)> games,
  ) async {
    final payload = [
      for (final g in games) {'side1_score': g.$1, 'side2_score': g.$2},
    ];
    await _db.rpc('record_submatch_score', params: {
      'p_submatch_id': submatchId,
      'p_games': payload,
    });
    await fetchMatches(divisionId);
  }

  /// Assigns a roster player to a manual-pairing sub-match slot ([side] 1 or 2).
  Future<void> setSubmatchPlayer(
    String submatchId,
    String divisionId,
    int side,
    String playerId,
  ) async {
    await _db.rpc('set_submatch_player', params: {
      'p_submatch_id': submatchId,
      'p_side': side,
      'p_player_id': playerId,
    });
    await fetchMatches(divisionId);
  }

  String? _eventIdForDivision(String divisionId) {
    for (final entry in _divisions.entries) {
      if (entry.value.any((d) => d.id == divisionId)) return entry.key;
    }
    return null;
  }

  // ── Rule templates (per-user, reusable division configs) ────────────────────

  List<TournamentTemplate> _templates = [];
  List<TournamentTemplate> get templates => _templates;

  Future<void> fetchTemplates() async {
    final rows = await _db
        .from('tournament_templates')
        .select()
        .order('created_at', ascending: true) as List<dynamic>;
    _templates = rows
        .map((r) => TournamentTemplate.fromJson(r as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> saveTemplate(String name, Map<String, dynamic> config) async {
    final rows = await _db.rpc('save_tournament_template', params: {
      'p_name': name,
      'p_config': config,
    }) as List<dynamic>;
    if (rows.isNotEmpty) {
      final t = TournamentTemplate.fromJson(rows.first as Map<String, dynamic>);
      final list = List<TournamentTemplate>.from(_templates)
        ..removeWhere((x) => x.id == t.id || x.name == t.name);
      list.add(t);
      _templates = list;
      notifyListeners();
    }
  }

  Future<void> deleteTemplate(String id) async {
    await _db.rpc('delete_tournament_template', params: {'p_id': id});
    _templates = _templates.where((t) => t.id != id).toList();
    notifyListeners();
  }

  // ── Manual builder (custom-format divisions) ────────────────────────────────

  Future<void> addManualMatch({
    required String divisionId,
    required int roundNumber,
    String? entrant1Id,
    String? entrant2Id,
    bool isTie = false,
  }) async {
    await _db.rpc('add_tournament_match', params: {
      'p_division_id': divisionId,
      'p_round_number': roundNumber,
      'p_entrant1_id': entrant1Id,
      'p_entrant2_id': entrant2Id,
      'p_is_tie': isTie,
    });
    await fetchMatches(divisionId);
    final eventId = _eventIdForDivision(divisionId);
    if (eventId != null) await fetchDivisions(eventId);
  }

  Future<void> updateManualMatch({
    required String matchId,
    required String divisionId,
    String? entrant1Id,
    String? entrant2Id,
    bool clear1 = false,
    bool clear2 = false,
  }) async {
    await _db.rpc('update_tournament_match', params: {
      'p_match_id': matchId,
      'p_entrant1_id': entrant1Id,
      'p_entrant2_id': entrant2Id,
      'p_clear1': clear1,
      'p_clear2': clear2,
    });
    await fetchMatches(divisionId);
  }

  Future<void> deleteManualMatch(String matchId, String divisionId) async {
    await _db.rpc('delete_tournament_match', params: {'p_match_id': matchId});
    await fetchMatches(divisionId);
  }

  Future<void> deleteDivision(String divisionId, String eventId) async {
    await _db.rpc('delete_tournament_division', params: {
      'p_division_id': divisionId,
    });
    final dl = _divisions[eventId];
    if (dl != null) _divisions[eventId] = dl.where((d) => d.id != divisionId).toList();
    _entrants.remove(divisionId);
    _matches.remove(divisionId);
    notifyListeners();
  }

  // ── Entrant mutations ───────────────────────────────────────────────────────

  Future<TournamentEntrant> registerEntrant({
    required String divisionId,
    required String teamName,
    required String player1Name,
    String? player1UserId,
    String? player2Name,
    String? player2UserId,
  }) async {
    final rows = await _db.rpc('register_tournament_entrant', params: {
      'p_division_id': divisionId,
      'p_team_name': teamName,
      'p_player1_name': player1Name,
      'p_player1_user_id': player1UserId,
      'p_player2_name': player2Name,
      'p_player2_user_id': player2UserId,
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Failed to register entrant');
    final entrant =
        TournamentEntrant.fromJson(rows.first as Map<String, dynamic>);
    final list = List<TournamentEntrant>.from(_entrants[divisionId] ?? const []);
    list.add(entrant);
    _entrants[divisionId] = list;
    notifyListeners();
    return entrant;
  }

  /// Registers a team entrant with a ranked roster. [players] is an ordered
  /// list of (name, rank) — order is the team's ranking.
  Future<TournamentEntrant> registerTeam({
    required String divisionId,
    required String teamName,
    required List<({String name, int rank, String? userId})> players,
  }) async {
    final payload = [
      for (final p in players)
        {'name': p.name, 'rank': p.rank, if (p.userId != null) 'user_id': p.userId},
    ];
    final rows = await _db.rpc('register_tournament_team', params: {
      'p_division_id': divisionId,
      'p_team_name': teamName,
      'p_players': payload,
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Failed to register team');
    // The RPC returns the entrant row without the nested roster; refetch so the
    // cache has the players.
    await fetchEntrants(divisionId);
    return TournamentEntrant.fromJson(rows.first as Map<String, dynamic>);
  }

  Future<void> withdrawEntrant(String entrantId, String divisionId) async {
    await _db.rpc('withdraw_tournament_entrant', params: {
      'p_entrant_id': entrantId,
    });
    final list = _entrants[divisionId];
    if (list != null) {
      final idx = list.indexWhere((e) => e.id == entrantId);
      if (idx >= 0) {
        final copy = List<TournamentEntrant>.from(list);
        copy[idx] = copy[idx].copyWith(status: EntrantStatus.withdrawn);
        _entrants[divisionId] = copy;
      }
    }
    notifyListeners();
  }

  Future<void> removeEntrant(String entrantId, String divisionId) async {
    await _db.rpc('remove_tournament_entrant', params: {
      'p_entrant_id': entrantId,
    });
    final list = _entrants[divisionId];
    if (list != null) {
      _entrants[divisionId] =
          list.where((e) => e.id != entrantId).toList();
    }
    notifyListeners();
  }

  // ── Court mutations ─────────────────────────────────────────────────────────

  Future<Court> addCourt(String eventId, String name) async {
    final rows = await _db.rpc('add_tournament_court', params: {
      'p_event_id': eventId,
      'p_name': name,
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Failed to add court');
    final court = Court.fromJson(rows.first as Map<String, dynamic>);
    final list = List<Court>.from(_courts[eventId] ?? const []);
    list.add(court);
    _courts[eventId] = list;
    notifyListeners();
    return court;
  }

  Future<Court> updateCourt(
    String courtId,
    String eventId, {
    String? name,
    CourtStatus? status,
  }) async {
    final rows = await _db.rpc('update_tournament_court', params: {
      'p_court_id': courtId,
      'p_name': name,
      'p_status': status?.dbValue,
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Failed to update court');
    final court = Court.fromJson(rows.first as Map<String, dynamic>);
    final list = _courts[eventId];
    if (list != null) {
      final idx = list.indexWhere((c) => c.id == courtId);
      if (idx >= 0) {
        final copy = List<Court>.from(list);
        copy[idx] = court;
        _courts[eventId] = copy;
      }
    }
    notifyListeners();
    return court;
  }

  Future<void> deleteCourt(String courtId, String eventId) async {
    await _db.rpc('delete_tournament_court', params: {
      'p_court_id': courtId,
    });
    final list = _courts[eventId];
    if (list != null) _courts[eventId] = list.where((c) => c.id != courtId).toList();
    notifyListeners();
  }

  // ── Court assignment (M5) ───────────────────────────────────────────────────

  /// All cached matches across every division of [eventId].
  List<TournamentMatch> _allMatchesForEvent(String eventId) => [
        for (final d in divisionsFor(eventId)) ...matchesFor(d.id),
      ];

  /// Loads divisions + every division's matches and entrants for an event (used
  /// by the Courts tab, which spans all divisions and needs team names).
  Future<void> fetchAllMatchesForEvent(String eventId) async {
    await fetchDivisions(eventId);
    await Future.wait([
      for (final d in divisionsFor(eventId)) ...[
        fetchMatches(d.id),
        fetchEntrants(d.id),
      ],
    ]);
  }

  /// Looks up an entrant across all cached divisions of an event.
  TournamentEntrant? entrantById(String eventId, String? entrantId) {
    if (entrantId == null) return null;
    for (final d in divisionsFor(eventId)) {
      for (final e in entrantsFor(d.id)) {
        if (e.id == entrantId) return e;
      }
    }
    return null;
  }

  /// Active (non-completed) matches assigned to [courtId], ordered by queue
  /// position — the first is "on court now".
  List<TournamentMatch> assignedMatchesForCourt(String eventId, String courtId) =>
      courtQueue(_allMatchesForEvent(eventId), courtId);

  /// Ready matches (both teams known, not a bye/completed) with no court yet —
  /// candidates to assign to a court.
  List<TournamentMatch> unassignedReadyMatches(String eventId) =>
      unassignedReady(_allMatchesForEvent(eventId));

  /// Entrant ids double-booked across more than one active court-assigned match.
  Set<String> doubleBookedEntrantIds(String eventId) =>
      doubleBookedEntrants(_allMatchesForEvent(eventId));

  Future<void> assignMatchToCourt(
      TournamentMatch match, String courtId, String eventId) async {
    await _db.rpc('assign_match_to_court', params: {
      'p_match_id': match.id,
      'p_court_id': courtId,
    });
    await fetchMatches(match.divisionId);
    await fetchCourts(eventId);
  }

  Future<void> unassignMatchFromCourt(
      TournamentMatch match, String eventId) async {
    await _db.rpc('unassign_match_from_court', params: {
      'p_match_id': match.id,
    });
    await fetchMatches(match.divisionId);
    await fetchCourts(eventId);
  }

  /// Marks a match as started and syncs the court to in_use.
  Future<void> startMatch(TournamentMatch match) async {
    await _db.rpc('start_match', params: {'p_match_id': match.id});
    await fetchMatches(match.divisionId);
    final eventId = _eventIdForDivision(match.divisionId);
    if (eventId != null) await fetchCourts(eventId);
  }

  /// Awards a walkover to [winnerEntrantId] — no scores entered, no-show/forfeit.
  Future<void> awardWalkover(
      TournamentMatch match, String winnerEntrantId) async {
    await _db.rpc('award_walkover', params: {
      'p_match_id': match.id,
      'p_winner_entrant_id': winnerEntrantId,
    });
    await fetchMatches(match.divisionId);
    final eventId = _eventIdForDivision(match.divisionId);
    if (eventId != null) {
      await fetchDivisions(eventId);
      await fetchCourts(eventId);
    }
  }

  /// Sets or clears the scheduled time and estimated duration for a match.
  Future<void> scheduleMatch(
    TournamentMatch match, {
    DateTime? scheduledAt,
    int? estimatedDurationMinutes,
  }) async {
    await _db.from('tournament_matches').update({
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'estimated_duration_minutes': estimatedDurationMinutes,
    }).eq('id', match.id);
    await fetchMatches(match.divisionId);
  }

  Future<void> reorderCourtQueue(
      String courtId, List<String> matchIds, String eventId) async {
    await _db.rpc('reorder_court_queue', params: {
      'p_court_id': courtId,
      'p_match_ids': matchIds,
    });
    await fetchAllMatchesForEvent(eventId);
    await fetchCourts(eventId);
  }

  void _replaceDivision(String eventId, TournamentDivision division) {
    final list = _divisions[eventId];
    if (list == null) return;
    final idx = list.indexWhere((d) => d.id == division.id);
    if (idx >= 0) {
      final copy = List<TournamentDivision>.from(list);
      copy[idx] = division;
      _divisions[eventId] = copy;
    }
  }

  // ── Session list fetching ───────────────────────────────────────────────

  /// Fetches the current user's session signup statuses for all sessions of
  /// [eventId] and caches them in [_mySessionStatuses].
  Future<void> _fetchMySessionStatuses(String eventId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await _db
          .from('event_session_roster')
          .select('session_id, status, signup_order')
          .eq('user_id', uid)
          .inFilter(
            'session_id',
            [
              ..._upcomingSessions[eventId]?.map((s) => s.id) ?? [],
              ..._pastSessions[eventId]?.map((s) => s.id) ?? [],
            ],
          ) as List<dynamic>;
      for (final r in rows) {
        final map = r as Map<String, dynamic>;
        _mySessionStatuses[map['session_id'] as String] = (
          status: map['status'] as String,
          order: (map['signup_order'] as int?) ?? 0,
        );
      }
    } catch (_) {}
  }

  /// Fetches upcoming sessions (start_at >= now). Replaces the cache.
  Future<void> fetchUpcomingSessions(String eventId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _db
        .from('event_sessions')
        .select(
            'id,event_id,session_number,start_at,end_at,invite_code,created_at,going_count,waitlist_count,pending_count,capacity,waitlist_enabled,signup_lock_hours,is_public,requires_approval,is_active,is_active_override,notes')
        .eq('event_id', eventId)
        .gte('start_at', now)
        .order('start_at', ascending: true)
        .limit(_kSessionsPageSize + 1) as List<dynamic>;
    _hasMoreUpcoming[eventId] = rows.length > _kSessionsPageSize;
    _upcomingSessions[eventId] = rows
        .take(_kSessionsPageSize)
        .map((r) => EventSession.fromJson(r as Map<String, dynamic>))
        .toList();
    await _fetchMySessionStatuses(eventId);
    notifyListeners();
  }

  /// Refreshes [liveSessions] — every session across the user's events that is
  /// "live right now", by the UNION of two definitions so it works whatever the
  /// data looks like:
  ///   (a) flagged active (`is_active = true`) — what the Activity tab shows; and
  ///   (b) within its time window (`start_at <= now AND (end_at IS NULL OR end_at > now)`)
  ///       — the same "should be active" window the auto-activate logic uses,
  ///       which catches sessions the organizer hasn't opened/activated yet.
  /// Two simple queries merged client-side (deduped by id) — avoids brittle nested
  /// PostgREST filters. RLS already restricts rows to the user's events, so no
  /// event_id filter is needed.
  Future<void> fetchLiveSessions() async {
    const cols =
        'id,event_id,session_number,start_at,end_at,invite_code,created_at,going_count,waitlist_count,pending_count,capacity,waitlist_enabled,signup_lock_hours,is_public,requires_approval,is_active,is_active_override,notes';
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final activeRows = await _db
          .from('event_sessions')
          .select(cols)
          .eq('is_active', true) as List<dynamic>;
      final windowRows = await _db
          .from('event_sessions')
          .select(cols)
          .lte('start_at', now)
          .or('end_at.is.null,end_at.gt.$now') as List<dynamic>;

      final byId = <String, EventSession>{};
      for (final r in [...activeRows, ...windowRows]) {
        final s = EventSession.fromJson(r as Map<String, dynamic>);
        byId[s.id] = s;
      }
      _liveSessions = byId.values.toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      notifyListeners();
    } catch (e, st) {
      debugPrint('EventProvider.fetchLiveSessions error: $e\n$st');
    }
  }

  /// Fetches the first page of past sessions (start_at < now, newest first).
  Future<void> fetchPastSessions(String eventId) async {
    if (_loadingPast[eventId] == true) return;
    _loadingPast[eventId] = true;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await _db
          .from('event_sessions')
          .select(
              'id,event_id,session_number,start_at,end_at,invite_code,created_at,going_count,waitlist_count,pending_count,capacity,waitlist_enabled,signup_lock_hours,is_public,requires_approval,is_active,is_active_override,notes')
          .eq('event_id', eventId)
          .lt('start_at', now)
          .order('start_at', ascending: false) // most recent first
          .limit(_kSessionsPageSize + 1) as List<dynamic>;
      final hasMore = rows.length > _kSessionsPageSize;
      _pastSessions[eventId] = rows
          .take(_kSessionsPageSize)
          .map((r) => EventSession.fromJson(r as Map<String, dynamic>))
          .toList();
      _hasMorePast[eventId] = hasMore;
    } finally {
      _loadingPast[eventId] = false;
      notifyListeners();
    }
  }

  /// Loads the next page of past sessions (older than the last loaded, descending).
  Future<void> loadMorePastSessions(String eventId) async {
    if (_loadingPast[eventId] == true) return;
    final existing = _pastSessions[eventId] ?? [];
    if (existing.isEmpty || !(_hasMorePast[eventId] ?? false)) return;
    _loadingPast[eventId] = true;
    try {
      final cursor = existing.last.startAt.toUtc().toIso8601String();
      final rows = await _db
          .from('event_sessions')
          .select(
              'id,event_id,session_number,start_at,end_at,invite_code,created_at,going_count,waitlist_count,pending_count,capacity,waitlist_enabled,signup_lock_hours,is_public,requires_approval,is_active,is_active_override,notes')
          .eq('event_id', eventId)
          .lt('start_at', cursor) // next batch of older past sessions
          .order('start_at', ascending: false)
          .limit(_kSessionsPageSize + 1) as List<dynamic>;
      final hasMore = rows.length > _kSessionsPageSize;
      final page = rows
          .take(_kSessionsPageSize)
          .map((r) => EventSession.fromJson(r as Map<String, dynamic>))
          .toList();
      _pastSessions[eventId] = [...existing, ...page];
      _hasMorePast[eventId] = hasMore;
      await _fetchMySessionStatuses(eventId);
    } finally {
      _loadingPast[eventId] = false;
      notifyListeners();
    }
  }

  // ── Roster fetching ─────────────────────────────────────────────────────

  /// Fetches the first page of roster entries for [sessionId]. No-op if already
  /// cached — call [refreshSessionRoster] to force a reload.
  Future<void> fetchSessionRoster(String sessionId) async {
    if (_sessionRosters.containsKey(sessionId)) return;
    await refreshSessionRoster(sessionId);
  }

  /// Always reloads from the first page, replacing the cache for [sessionId].
  Future<void> refreshSessionRoster(String sessionId) async {
    // B10: order by (signed_up_at, id) — stable even after reorder mutations.
    final rows = await _db
        .from('event_session_roster')
        .select()
        .eq('session_id', sessionId)
        .order('signed_up_at', ascending: true)
        .order('id', ascending: true)
        .limit(_kRosterPageSize + 1) as List<dynamic>;
    final hasMore = rows.length > _kRosterPageSize;
    final entries = rows
        .take(_kRosterPageSize)
        .map((r) => EventSessionRosterEntry.fromJson(r as Map<String, dynamic>))
        .toList();
    _sessionRosters[sessionId] = entries;
    _hasMoreRoster[sessionId] = hasMore;

    // Keep mySessionStatuses in sync — find the current user's entry if any.
    final uid = _db.auth.currentUser?.id;
    if (uid != null) {
      final mine = entries.where((e) => e.userId == uid).firstOrNull;
      if (mine != null) {
        _mySessionStatuses[sessionId] = (
          status: mine.status,
          order: mine.signupOrder ?? 0,
        );
      } else if (!hasMore) {
        // Only clear if we loaded ALL entries — the user might be on a later
        // page of a large session and simply wasn't in the first 100 rows.
        _mySessionStatuses.remove(sessionId);
      }
    }
    notifyListeners();
  }

  /// Appends the next page of roster entries for [sessionId].
  Future<void> loadMoreRoster(String sessionId) async {
    final existing = _sessionRosters[sessionId] ?? [];
    if (!(_hasMoreRoster[sessionId] ?? false)) return;
    // B10: use (signed_up_at, id) as the stable cursor — immune to reorder
    // mutations that change signup_order values after page 1 was fetched.
    final last = existing.isNotEmpty ? existing.last : null;
    final afterAt = last?.signedUpAt.toUtc().toIso8601String();
    final afterId = last?.id;
    final rows = await _db
        .from('event_session_roster')
        .select()
        .eq('session_id', sessionId)
        .or(afterAt == null || afterId == null
            ? 'id.neq.null'
            : 'signed_up_at.gt.$afterAt,and(signed_up_at.eq.$afterAt,id.gt.$afterId)')
        .order('signed_up_at', ascending: true)
        .order('id', ascending: true)
        .limit(_kRosterPageSize + 1) as List<dynamic>;
    final hasMore = rows.length > _kRosterPageSize;
    final page = rows
        .take(_kRosterPageSize)
        .map((r) => EventSessionRosterEntry.fromJson(r as Map<String, dynamic>))
        .toList();
    _sessionRosters[sessionId] = [...existing, ...page];
    _hasMoreRoster[sessionId] = hasMore;
    notifyListeners();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Reads going_count / waitlist_count from the DB (maintained by trigger) and
  /// updates both session caches. Called after any roster mutation.
  Future<void> _refreshSessionCounts(String sessionId, String eventId) async {
    final row = await _db
        .from('event_sessions')
        .select('id,going_count,waitlist_count')
        .eq('id', sessionId)
        .single();
    final going = row['going_count'] as int? ?? 0;
    final waitlist = row['waitlist_count'] as int? ?? 0;
    _patchSessionInCache(eventId, sessionId,
        (s) => s.copyWithCounts(goingCount: going, waitlistCount: waitlist));
  }

  void _patchSessionInCache(String eventId, String sessionId,
      EventSession Function(EventSession) fn) {
    void patch(Map<String, List<EventSession>> cache) {
      final list = cache[eventId];
      if (list == null) return;
      final i = list.indexWhere((s) => s.id == sessionId);
      if (i >= 0) {
        final updated = List<EventSession>.from(list);
        updated[i] = fn(updated[i]);
        cache[eventId] = updated;
      }
    }
    patch(_upcomingSessions);
    patch(_pastSessions);
  }

  // Canonical sort for in-memory rosters: ascending signup_order, nulls last.
  static int _rosterOrder(EventSessionRosterEntry a, EventSessionRosterEntry b) {
    if (a.signupOrder == null && b.signupOrder == null) return 0;
    if (a.signupOrder == null) return 1;
    if (b.signupOrder == null) return -1;
    return a.signupOrder!.compareTo(b.signupOrder!);
  }

  void _patchRosterEntry(String sessionId, String rosterId,
      EventSessionRosterEntry Function(EventSessionRosterEntry) fn,
      {bool resort = false}) {
    final roster = _sessionRosters[sessionId];
    if (roster == null) return;
    final i = roster.indexWhere((r) => r.id == rosterId);
    if (i >= 0) {
      final updated = List<EventSessionRosterEntry>.from(roster);
      updated[i] = fn(updated[i]);
      if (resort) updated.sort(_rosterOrder);
      _sessionRosters[sessionId] = updated;
      notifyListeners();
    }
  }

  // ── Session creation ────────────────────────────────────────────────────

  /// Organizer creates a new session. Inserted into the upcoming cache if its
  /// start_at is in the future, otherwise past cache.
  Future<EventSession> addSession(
    String eventId,
    DateTime startAt,
    DateTime? endAt, {
    int? capacity,
    bool waitlistEnabled = true,
    int? signupLockHours,
    bool isPublic = true,
    bool requiresApproval = false,
    String? notes,
  }) async {
    final rows = await _db.rpc('add_event_session', params: {
      'p_event_id': eventId,
      'p_start_at': startAt.toUtc().toIso8601String(),
      'p_end_at': endAt?.toUtc().toIso8601String(),
      'p_capacity': capacity,
      'p_waitlist_enabled': waitlistEnabled,
      'p_signup_lock_hours': signupLockHours,
      'p_is_public': isPublic,
      'p_requires_approval': requiresApproval,
      'p_notes': notes,
    }) as List<dynamic>;
    if (rows.isEmpty) throw Exception('Failed to create session');
    final session = EventSession.fromJson(rows.first as Map<String, dynamic>);
    if (session.isUpcoming) {
      final list = List<EventSession>.from(_upcomingSessions[eventId] ?? []);
      list.add(session);
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
      _upcomingSessions[eventId] = list;
    } else {
      final list = List<EventSession>.from(_pastSessions[eventId] ?? []);
      list.insert(0, session);
      _pastSessions[eventId] = list;
    }
    notifyListeners();
    return session;
  }

  Future<void> markSessionDone(String sessionId, String eventId) async {
    await _db.rpc('mark_session_done', params: {
      'p_session_id': sessionId,
      'p_event_id': eventId,
    });
    // Clear activity-tab data from the local cache.
    for (final a in _sessionQueues[sessionId] ?? []) {
      _queueEntries.remove(a.id);
      _activityMeta.remove(a.id);
    }
    _sessionQueues[sessionId] = [];
    // Free pool is computed from queues — recompute now that queues are empty.
    _recomputeFreePool(eventId, sessionId);
    // Move session from upcoming → past in local cache (end_at = now).
    final upcoming = List<EventSession>.from(_upcomingSessions[eventId] ?? []);
    final idx = upcoming.indexWhere((s) => s.id == sessionId);
    if (idx >= 0) {
      final s = upcoming[idx];
      final done = EventSession(
        id: s.id, eventId: s.eventId, sessionNumber: s.sessionNumber,
        startAt: s.startAt, endAt: DateTime.now(),
        inviteCode: s.inviteCode, createdAt: s.createdAt,
        goingCount: s.goingCount, waitlistCount: s.waitlistCount,
        pendingCount: s.pendingCount, capacity: s.capacity,
        waitlistEnabled: s.waitlistEnabled, signupLockHours: s.signupLockHours,
        isPublic: s.isPublic, requiresApproval: s.requiresApproval,
        isActive: false, isActiveOverride: true, notes: s.notes,
      );
      upcoming.removeAt(idx);
      _upcomingSessions[eventId] = upcoming;
      final past = List<EventSession>.from(_pastSessions[eventId] ?? []);
      past.insert(0, done);
      _pastSessions[eventId] = past;
    } else {
      // Already in past — just patch flags.
      _patchSessionInCache(eventId, sessionId, (s) => EventSession(
        id: s.id, eventId: s.eventId, sessionNumber: s.sessionNumber,
        startAt: s.startAt, endAt: s.endAt ?? DateTime.now(),
        inviteCode: s.inviteCode, createdAt: s.createdAt,
        goingCount: s.goingCount, waitlistCount: s.waitlistCount,
        pendingCount: s.pendingCount, capacity: s.capacity,
        waitlistEnabled: s.waitlistEnabled, signupLockHours: s.signupLockHours,
        isPublic: s.isPublic, requiresApproval: s.requiresApproval,
        isActive: false, isActiveOverride: true, notes: s.notes,
      ));
    }
    notifyListeners();
  }

  Future<void> updateSessionNotes(
      String sessionId, String eventId, String? notes) async {
    final value = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
    await _db.from('event_sessions').update({'notes': value}).eq('id', sessionId);
    _patchSessionInCache(eventId, sessionId, (s) => s.copyWithNotes(value));
    notifyListeners();
  }

  // ── Roster mutations ────────────────────────────────────────────────────

  /// Guest self-cancels from a session (auto-promotes waitlist).
  Future<void> cancelSessionSignup(
      String rosterId, String sessionId, String eventId) async {
    await _db.rpc('cancel_session_signup', params: {'p_roster_id': rosterId});
    final roster = _sessionRosters[sessionId];
    if (roster != null) {
      _sessionRosters[sessionId] =
          roster.where((r) => r.id != rosterId).toList();
    }
    _mySessionStatuses.remove(sessionId);
    notifyListeners();
    unawaited(_refreshSessionCounts(sessionId, eventId));
  }

  /// Organizer removes a roster entry (auto-promotes waitlist).
  Future<void> removeSessionRosterEntry(
      String rosterId, String sessionId, String eventId) async {
    await _db.rpc('session_remove_roster_entry', params: {'p_roster_id': rosterId});
    final roster = _sessionRosters[sessionId];
    if (roster != null) {
      _sessionRosters[sessionId] =
          roster.where((r) => r.id != rosterId).toList();
      notifyListeners();
    }
    unawaited(_refreshSessionCounts(sessionId, eventId));
  }

  /// Organizer manually promotes a waitlisted roster entry.
  Future<void> promoteSessionRosterEntry(
      String rosterId, String sessionId, String eventId) async {
    await _db.rpc('session_promote_roster_entry', params: {'p_roster_id': rosterId});
    _patchRosterEntry(sessionId, rosterId, (r) => r.copyWith(status: 'going'));
    unawaited(_refreshSessionCounts(sessionId, eventId));
  }

  /// Organizer demotes a confirmed roster entry to the waitlist.
  Future<void> demoteSessionRosterEntry(
      String rosterId, String sessionId, String eventId) async {
    await _db.rpc('session_demote_roster_entry', params: {'p_roster_id': rosterId});
    // Reload page 1 — demote changes signup_order so cursor positions shift.
    await refreshSessionRoster(sessionId);
    unawaited(_refreshSessionCounts(sessionId, eventId));
  }

  /// Organizer reorders roster entries within a status group.
  Future<void> reorderSessionRoster(
      String eventId, String sessionId, List<String> orderedIds,
      {int startOrder = 1}) async {
    final idToOrder = {
      for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: startOrder + i,
    };
    final roster = _sessionRosters[sessionId];
    if (roster != null) {
      _sessionRosters[sessionId] = (roster.map((r) {
        final o = idToOrder[r.id];
        return o != null ? r.copyWith(signupOrder: o) : r;
      }).toList())
        ..sort(_rosterOrder);
      notifyListeners();
    }
    for (var i = 0; i < orderedIds.length; i++) {
      unawaited(_db
          .from('event_session_roster')
          .update({'signup_order': startOrder + i}).eq('id', orderedIds[i]));
    }
  }

  /// Organizer marks attendance on a roster entry.
  Future<void> markSessionAttendance(
      String rosterId, String sessionId, String eventId, bool? attended) async {
    await _db.rpc('session_mark_attendance', params: {
      'p_roster_id': rosterId,
      'p_attended': attended,
    });
    _patchRosterEntry(sessionId, rosterId, (r) => r.copyWith(attended: attended, clearAttended: attended == null));
  }

  /// Organizer approves a pending_review request — entry moves to 'going'.
  Future<void> approveSessionRosterEntry(
      String rosterId, String sessionId, String eventId) async {
    await _db.rpc('session_approve_request', params: {'p_roster_id': rosterId});
    // The DB assigns the new signup_order in sequence — reload to get it.
    await refreshSessionRoster(sessionId);
    unawaited(_refreshSessionCounts(sessionId, eventId));
  }

  /// Organizer deletes a session entirely.
  Future<void> deleteSession(String sessionId, String eventId) async {
    await _db.rpc('delete_event_session', params: {'p_session_id': sessionId});
    _upcomingSessions[eventId]?.removeWhere((s) => s.id == sessionId);
    _pastSessions[eventId]?.removeWhere((s) => s.id == sessionId);
    _sessionRosters.remove(sessionId);
    _mySessionStatuses.remove(sessionId);
    notifyListeners();
  }

  /// Organizer rejects (deletes) a pending_review request.
  Future<void> rejectSessionRosterEntry(
      String rosterId, String sessionId, String eventId) async {
    await _db.rpc('session_reject_request', params: {'p_roster_id': rosterId});
    final roster = _sessionRosters[sessionId];
    if (roster != null) {
      _sessionRosters[sessionId] =
          roster.where((r) => r.id != rosterId).toList();
      notifyListeners();
    }
  }

  /// Toggle signup confirmation on a roster entry.
  Future<void> toggleSessionConfirmed(
      String rosterId, String sessionId, String eventId, bool confirmed) async {
    await _db.rpc('toggle_session_confirmed', params: {
      'p_roster_id': rosterId,
      'p_confirmed': confirmed,
    });
    _patchRosterEntry(
        sessionId, rosterId, (r) => r.copyWith(signupConfirmed: confirmed));
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
        // Reinvite path: UPDATE existing left/declined row first, then INSERT.
        // Avoids upsert (which mutates the PK and breaks the event_expense_splits FK).
        try {
          final reinviteUpdate = <String, dynamic>{
            'display_name': displayName,
            'email': email,
            'phone': phone,
            'status': 'pending',
            'invited_by': invitedBy,
            'rsvp_at': now,
          };
          final updated = await _db
              .from('event_guests')
              .update(reinviteUpdate)
              .eq('event_id', eventId)
              .eq('user_id', userId)
              .inFilter('status', ['left', 'declined'])
              .select()
              .maybeSingle();

          if (updated != null) {
            guest = EventGuest.fromJson(updated);
          } else {
            // No existing left/declined row — fresh invite.
            final data = await _db
                .from('event_guests')
                .insert(payload)
                .select()
                .single();
            guest = EventGuest.fromJson(data);
          }
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

  Future<List<EventPhoto>> fetchPhotos(String eventId, {int offset = 0}) async {
    try {
      final data = await _db
          .from('event_photos')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false)
          .range(offset, offset + _photoPageSize - 1);
      final rows = List<Map<String, dynamic>>.from(data as List);
      final photos = rows.map(_resolvePhotoUrls).toList();
      if (offset == 0) {
        _photos[eventId] = photos;
      } else {
        _photos[eventId] = [...(_photos[eventId] ?? []), ...photos];
      }
      _hasMorePhotos[eventId] = rows.length == _photoPageSize;
      notifyListeners();
      return photos;
    } catch (e) {
      debugPrint('EventProvider.fetchPhotos error: $e');
      // Prevent loadAllPhotos from looping forever when the network fails.
      _hasMorePhotos[eventId] = false;
      return [];
    }
  }

  Future<void> loadMorePhotos(String eventId) async {
    if (!hasMorePhotos(eventId)) return;
    await fetchPhotos(eventId, offset: _photos[eventId]?.length ?? 0);
  }

  Future<void> loadAllPhotos(String eventId) async {
    while (hasMorePhotos(eventId)) {
      await fetchPhotos(eventId, offset: _photos[eventId]?.length ?? 0);
    }
  }

  EventPhoto _resolvePhotoUrls(Map<String, dynamic> row) {
    final photo = EventPhoto.fromJson(row);
    final publicUrl =
        _db.storage.from('event-photos').getPublicUrl(photo.storagePath);
    final thumbnailUrl = _db.storage.from('event-photos').getPublicUrl(
      photo.storagePath,
      transform: const TransformOptions(width: 400, quality: 60),
    );
    return photo.withUrls(publicUrl: publicUrl, thumbnailUrl: thumbnailUrl);
  }

  Future<EventPhoto?> addPhoto({
    required String eventId,
    required String storagePath,
    String caption = '',
  }) async {
    // Rethrows PostgrestException so the UI can surface rate_limit_exceeded /
    // photo_cap_exceeded messages from the DB triggers.
    final data = await _db.from('event_photos').insert({
      'event_id': eventId,
      'uploaded_by': _userId,
      'storage_path': storagePath,
      'caption': caption,
    }).select().single();
    final photo = _resolvePhotoUrls(Map<String, dynamic>.from(data as Map));
    _photos[eventId] = [photo, ...(_photos[eventId] ?? [])];
    notifyListeners();
    return photo;
  }

  Future<void> deletePhoto(EventPhoto photo) async {
    // Delete the DB row first: if this fails (RLS, network), the storage file
    // is still intact and the photo remains accessible. Deleting storage first
    // would orphan the DB row if the DB delete subsequently failed.
    await _db.from('event_photos').delete().eq('id', photo.id);
    await _db.storage.from('event-photos').remove([photo.storagePath]);
    _photos[photo.eventId] =
        (_photos[photo.eventId] ?? []).where((p) => p.id != photo.id).toList();
    notifyListeners();
  }

  Future<void> updatePhotoCaption(String photoId, String caption) async {
    await _db
        .from('event_photos')
        .update({'caption': caption}).eq('id', photoId);
    for (final list in _photos.values) {
      final idx = list.indexWhere((p) => p.id == photoId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(caption: caption);
        break;
      }
    }
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
          .select('*, event_poll_options(*, event_poll_reactions(*)), event_poll_votes(*)')
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
    List<String> options, {
    String pollType = 'general',
  }) async {
    final pollData = await _db
        .from('event_polls')
        .insert({
          'event_id': eventId,
          'question': question.trim(),
          'created_by': _userId,
          'poll_type': pollType,
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

  Future<void> addPollOption(
    String pollId,
    String eventId,
    String text,
  ) async {
    final existing = (_polls[eventId] ?? []).where((p) => p.id == pollId).firstOrNull;
    final sortOrder = existing?.options.length ?? 0;
    await _db.from('event_poll_options').insert({
      'poll_id': pollId,
      'text': text.trim(),
      'sort_order': sortOrder,
    });
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

  Future<void> reactToPollOption(
      String optionId, String emoji, String userId, String eventId) async {
    final tempReaction = EventPollReaction(
      id: _uuid.v4(),
      optionId: optionId,
      userId: userId,
      emoji: emoji,
      createdAt: DateTime.now(),
    );
    _applyOptimisticReaction(eventId, optionId, tempReaction);
    try {
      await _db.from('event_poll_reactions').insert({
        'option_id': optionId,
        'user_id': userId,
        'emoji': emoji,
      });
      unawaited(fetchPolls(eventId));
    } catch (e) {
      _revertOptimisticReaction(eventId, optionId, tempReaction.id);
    }
  }

  Future<void> unreactToPollOption(
      String reactionId, String optionId, String eventId) async {
    _removeOptimisticReaction(eventId, optionId, reactionId);
    try {
      await _db.from('event_poll_reactions').delete().eq('id', reactionId);
      unawaited(fetchPolls(eventId));
    } catch (e) {
      unawaited(fetchPolls(eventId));
    }
  }

  void _applyOptimisticReaction(
      String eventId, String optionId, EventPollReaction reaction) {
    final polls = _polls[eventId];
    if (polls == null) return;
    final pollIdx = polls.indexWhere(
        (p) => p.options.any((o) => o.id == optionId));
    if (pollIdx < 0) return;
    final poll = polls[pollIdx];
    final option = poll.options.firstWhere((o) => o.id == optionId);
    final newReactions = [...option.reactions, reaction];
    _polls[eventId]![pollIdx] =
        poll.copyWithOptionReactions(optionId, newReactions);
    notifyListeners();
  }

  void _revertOptimisticReaction(
      String eventId, String optionId, String tempId) {
    final polls = _polls[eventId];
    if (polls == null) return;
    final pollIdx = polls.indexWhere(
        (p) => p.options.any((o) => o.id == optionId));
    if (pollIdx < 0) return;
    final poll = polls[pollIdx];
    final option = poll.options.firstWhere((o) => o.id == optionId);
    final newReactions =
        option.reactions.where((r) => r.id != tempId).toList();
    _polls[eventId]![pollIdx] =
        poll.copyWithOptionReactions(optionId, newReactions);
    notifyListeners();
  }

  void _removeOptimisticReaction(
      String eventId, String optionId, String reactionId) {
    _revertOptimisticReaction(eventId, optionId, reactionId);
  }

  // ─── Birthday: Wishlist ────────────────────────────────────────────────────

  Future<List<EventWishlistItem>> fetchWishlist(String eventId) async {
    try {
      final data = await _db
          .from('event_wishlist_items')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: true);
      final items = (data as List)
          .map((r) => EventWishlistItem.fromJson(r as Map<String, dynamic>))
          .toList();
      _wishlistItems[eventId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      debugPrint('EventProvider.fetchWishlist error: $e');
      return [];
    }
  }

  Future<void> addWishlistItem({
    required String eventId,
    required String label,
    String? priceRange,
    String? link,
  }) async {
    await _db.from('event_wishlist_items').insert({
      'event_id': eventId,
      'label': label.trim(),
      'price_range': priceRange?.trim().isEmpty == true ? null : priceRange?.trim(),
      'link': link?.trim().isEmpty == true ? null : link?.trim(),
      'created_by': _userId,
    });
    unawaited(fetchWishlist(eventId));
  }

  Future<void> claimWishlistItem(
      String itemId, String eventId, String claimerName) async {
    await _db.from('event_wishlist_items').update({
      'claimed_by': _userId,
      'claimed_by_name': claimerName,
      'claimed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', itemId);
    unawaited(fetchWishlist(eventId));
  }

  Future<void> unclaimWishlistItem(String itemId, String eventId) async {
    await _db.from('event_wishlist_items').update({
      'claimed_by': null,
      'claimed_by_name': null,
      'claimed_at': null,
    }).eq('id', itemId);
    unawaited(fetchWishlist(eventId));
  }

  Future<void> markWishlistItemReceived(
      String itemId, String eventId, bool received) async {
    await _db
        .from('event_wishlist_items')
        .update({'is_received': received}).eq('id', itemId);
    final items = _wishlistItems[eventId];
    if (items != null) {
      final idx = items.indexWhere((i) => i.id == itemId);
      if (idx >= 0) {
        _wishlistItems[eventId]![idx] = EventWishlistItem(
          id: items[idx].id,
          eventId: items[idx].eventId,
          label: items[idx].label,
          priceRange: items[idx].priceRange,
          link: items[idx].link,
          createdBy: items[idx].createdBy,
          createdAt: items[idx].createdAt,
          claimedBy: items[idx].claimedBy,
          claimedByName: items[idx].claimedByName,
          claimedAt: items[idx].claimedAt,
          isReceived: received,
        );
        notifyListeners();
      }
    }
  }

  Future<void> deleteWishlistItem(String itemId, String eventId) async {
    await _db.from('event_wishlist_items').delete().eq('id', itemId);
    _wishlistItems[eventId]?.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  // ─── Birthday: Gift Pool ───────────────────────────────────────────────────

  Future<void> fetchGiftPool(String eventId) async {
    try {
      final data = await _db
          .from('event_gift_pools')
          .select('*, event_gift_pledges(*)')
          .eq('event_id', eventId)
          .maybeSingle();
      if (data == null) {
        _giftPools[eventId] = null;
      } else {
        _giftPools[eventId] = EventGiftPool.fromJson(data);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('EventProvider.fetchGiftPool error: $e');
    }
  }

  Future<void> createGiftPool({
    required String eventId,
    required String giftName,
    required double targetAmount,
  }) async {
    await _db.from('event_gift_pools').insert({
      'event_id': eventId,
      'gift_name': giftName.trim(),
      'target_amount': targetAmount,
      'created_by': _userId,
    });
    unawaited(fetchGiftPool(eventId));
  }

  Future<void> addPledge({
    required String poolId,
    required String eventId,
    required double amount,
    required String pledgerName,
  }) async {
    await _db.from('event_gift_pledges').insert({
      'pool_id': poolId,
      'pledged_by': _userId,
      'pledged_by_name': pledgerName,
      'amount': amount,
    });
    unawaited(fetchGiftPool(eventId));
  }

  Future<void> deletePledge(String pledgeId, String eventId) async {
    await _db.from('event_gift_pledges').delete().eq('id', pledgeId);
    unawaited(fetchGiftPool(eventId));
  }

  Future<void> deleteGiftPool(String poolId, String eventId) async {
    await _db.from('event_gift_pools').delete().eq('id', poolId);
    _giftPools[eventId] = null;
    notifyListeners();
  }

  // ─── Birthday: Predictions ─────────────────────────────────────────────────

  Future<List<EventPrediction>> fetchPredictions(String eventId) async {
    try {
      final data = await _db
          .from('event_predictions')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: true);
      final items = (data as List)
          .map((r) => EventPrediction.fromJson(r as Map<String, dynamic>))
          .toList();
      _predictions[eventId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      debugPrint('EventProvider.fetchPredictions error: $e');
      return [];
    }
  }

  Future<void> addPrediction({
    required String eventId,
    required String predictionText,
    required String submitterName,
  }) async {
    await _db.from('event_predictions').insert({
      'event_id': eventId,
      'submitted_by': _userId,
      'submitted_by_name': submitterName,
      'prediction_text': predictionText.trim(),
    });
    unawaited(fetchPredictions(eventId));
  }

  Future<void> deletePrediction(String predictionId, String eventId) async {
    await _db.from('event_predictions').delete().eq('id', predictionId);
    _predictions[eventId]?.removeWhere((p) => p.id == predictionId);
    notifyListeners();
  }

  Future<void> revealPredictions(String eventId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.from('events').update({
      'predictions_revealed_at': now,
      'updated_at': now,
    }).eq('id', eventId);
    unawaited(fetchPredictions(eventId));
    unawaited(_reloadEvent(eventId));
  }

  // ─── Birthday: Wishes ─────────────────────────────────────────────────────

  Future<List<EventWish>> fetchWishes(String eventId) async {
    try {
      final data = await _db
          .from('event_wishes')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: true);
      final items = (data as List)
          .map((r) => EventWish.fromJson(r as Map<String, dynamic>))
          .toList();
      _wishes[eventId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      debugPrint('EventProvider.fetchWishes error: $e');
      return [];
    }
  }

  Future<void> addWish({
    required String eventId,
    required String wishText,
    required String submitterName,
  }) async {
    await _db.from('event_wishes').insert({
      'event_id': eventId,
      'submitted_by': _userId,
      'submitted_by_name': submitterName,
      'wish_text': wishText.trim(),
    });
    unawaited(fetchWishes(eventId));
  }

  Future<void> deleteWish(String wishId, String eventId) async {
    await _db.from('event_wishes').delete().eq('id', wishId);
    _wishes[eventId]?.removeWhere((w) => w.id == wishId);
    notifyListeners();
  }

  Future<void> revealWishes(String eventId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.from('events').update({
      'wishes_revealed_at': now,
      'updated_at': now,
    }).eq('id', eventId);
    unawaited(fetchWishes(eventId));
    unawaited(_reloadEvent(eventId));
  }

  // ─── Birthday: Toasts ─────────────────────────────────────────────────────

  Future<List<EventToast>> fetchToasts(String eventId) async {
    try {
      final data = await _db
          .from('event_toasts')
          .select()
          .eq('event_id', eventId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      final items = (data as List)
          .map((r) => EventToast.fromJson(r as Map<String, dynamic>))
          .toList();
      _toasts[eventId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      debugPrint('EventProvider.fetchToasts error: $e');
      return [];
    }
  }

  Future<void> addToast({
    required String eventId,
    required String toastText,
    required String toastType,
    required String submitterName,
  }) async {
    final existing = _toasts[eventId] ?? [];
    await _db.from('event_toasts').insert({
      'event_id': eventId,
      'submitted_by': _userId,
      'submitted_by_name': submitterName,
      'toast_text': toastText.trim(),
      'toast_type': toastType,
      'sort_order': existing.length,
    });
    unawaited(fetchToasts(eventId));
  }

  Future<void> deleteToast(String toastId, String eventId) async {
    await _db.from('event_toasts').delete().eq('id', toastId);
    _toasts[eventId]?.removeWhere((t) => t.id == toastId);
    notifyListeners();
  }

  Future<void> reorderToasts(String eventId, List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      unawaited(_db
          .from('event_toasts')
          .update({'sort_order': i}).eq('id', orderedIds[i]));
    }
    final current = _toasts[eventId] ?? [];
    final byId = {for (final t in current) t.id: t};
    _toasts[eventId] = orderedIds
        .where(byId.containsKey)
        .map((id) => byId[id]!)
        .toList();
    notifyListeners();
  }

  // ─── Session Queue Activities (scoped per event_session) ──────────────────

  // ── Realtime handler methods (extracted for testability) ─────────────────

  @visibleForTesting
  void handleQueueActivityInsert(Map<String, dynamic> row) {
    final sessionId = row['session_id'] as String?;
    final id = row['id'] as String?;
    if (sessionId == null || id == null) return;
    try {
      final activity = SessionQueueActivity.fromJson(row);
      final list = List<SessionQueueActivity>.from(_sessionQueues[sessionId] ?? []);
      if (!list.any((a) => a.id == id)) {
        list.add(activity);
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _sessionQueues[sessionId] = list;
        _activityMeta[id] = (sessionId: sessionId, eventId: activity.eventId);
        _queueEntries.putIfAbsent(id, () => []);
        _recomputeFreePool(activity.eventId, sessionId);
        notifyListeners();
      }
    } catch (_) {}
  }

  @visibleForTesting
  void handleQueueActivityUpdate(Map<String, dynamic> row) {
    final sessionId = row['session_id'] as String?;
    final id = row['id'] as String?;
    if (sessionId == null || id == null) return;
    final list = _sessionQueues[sessionId];
    if (list != null) {
      final idx = list.indexWhere((a) => a.id == id);
      if (idx >= 0) {
        final updated = SessionQueueActivity.fromJson(row);
        list[idx] = updated;
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _activityMeta[id] = (sessionId: sessionId, eventId: updated.eventId);

        // Server confirmed queue fully cleared — force local entry cache empty
        // so the shatter animation fires on non-organizer devices even when
        // entry DELETE Realtime events arrive out of order or are delayed.
        if (updated.playingCount == 0 && updated.waitingCount == 0) {
          final cached = _queueEntries[id];
          if (cached != null && cached.isNotEmpty) {
            _queueEntries[id] = [];
          }
        }
      }
    }
    // The DB trigger fires this UPDATE on every entry INSERT/DELETE
    // (playing_count changes). Use it as a secondary signal to recompute
    // the free pool even when the entry-level event arrives out of order.
    _recomputeFreePoolForActivity(id);
    notifyListeners();
  }

  @visibleForTesting
  void handleQueueActivityDelete(Map<String, dynamic> row) {
    final sessionId = row['session_id'] as String?;
    final id = row['id'] as String?;
    if (sessionId == null || id == null) return;
    final eventId = _activityMeta[id]?.eventId
        ?? _sessionQueues[sessionId]?.firstOrNull?.eventId;
    _sessionQueues[sessionId]?.removeWhere((a) => a.id == id);
    _queueEntries.remove(id);
    _activityMeta.remove(id);
    if (eventId != null) _recomputeFreePool(eventId, sessionId);
    notifyListeners();
  }

  @visibleForTesting
  void handleQueueEntryInsert(Map<String, dynamic> row) {
    final activityId = row['activity_id'] as String?;
    if (activityId == null) return;
    try {
      final entry = SessionQueueEntry.fromJson(row);
      final list = List<SessionQueueEntry>.from(_queueEntries[activityId] ?? []);
      if (!list.any((e) => e.id == entry.id)) {
        list.add(entry);
        list.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
        _queueEntries[activityId] = list;
      }
      _recomputeFreePoolForActivity(activityId);
      notifyListeners();
    } catch (_) {
      final meta = _activityMeta[activityId];
      if (meta != null) unawaited(fetchSessionQueues(meta.eventId, meta.sessionId));
    }
  }

  @visibleForTesting
  void handleQueueEntryUpdate(Map<String, dynamic> row) {
    final activityId = row['activity_id'] as String?;
    final id = row['id'] as String?;
    if (activityId == null || id == null) return;
    final list = _queueEntries[activityId];
    if (list == null) return;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      list[idx] = SessionQueueEntry.fromJson(row);
      list.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
      notifyListeners();
    }
  }

  @visibleForTesting
  void handleQueueEntryDelete(Map<String, dynamic> row) {
    final activityId = row['activity_id'] as String?;
    final id = row['id'] as String?;
    if (activityId == null || id == null) return;
    _queueEntries[activityId]?.removeWhere((e) => e.id == id);
    _recomputeFreePoolForActivity(activityId);
    notifyListeners();
  }

  /// Seeds events into the in-memory cache for unit tests.
  @visibleForTesting
  void seedEventsForTest(List<Event> events) {
    _events = [...events];
  }

  // Register all activities for a session in the O(1) index.
  void _indexActivities(String sessionId, List<SessionQueueActivity> activities) {
    for (final a in activities) {
      _activityMeta[a.id] = (sessionId: sessionId, eventId: a.eventId);
    }
  }

  // Recompute free pool for the session that owns [activityId].
  // Uses the O(1) _activityMeta index first; falls back to a linear scan of
  // _sessionQueues so a race condition (Realtime fires before _indexActivities)
  // never silently skips the recompute.
  void _recomputeFreePoolForActivity(String activityId) {
    final meta = _activityMeta[activityId];
    if (meta != null) {
      _recomputeFreePool(meta.eventId, meta.sessionId);
      return;
    }
    // Fallback: search _sessionQueues
    for (final entry in _sessionQueues.entries) {
      final act = entry.value.where((a) => a.id == activityId).firstOrNull;
      if (act != null) {
        _recomputeFreePool(act.eventId, entry.key);
        return;
      }
    }
  }

  void _recomputeFreePool(String eventId, String sessionId) {
    final activities = _sessionQueues[sessionId] ?? [];
    final allEntries = activities.expand((a) => _queueEntries[a.id] ?? []);
    final inQueueByUserId = allEntries
        .where((e) => e.userId != null)
        .map((e) => e.userId!)
        .toSet();
    final inQueueByName = allEntries
        .where((e) => e.userId == null)
        .map((e) => e.displayName.toLowerCase())
        .toSet();
    final event = _events.where((e) => e.id == eventId).firstOrNull;
    final guests = event?.guests ?? [];
    _freePool[sessionId] = guests
        .where((g) => !const {'left', 'declined'}.contains(g.status))
        .where((g) {
          if (g.userId != null) return !inQueueByUserId.contains(g.userId);
          return !inQueueByName.contains(g.displayName.toLowerCase());
        })
        .map((g) => SessionFreePoolEntry(
              id: g.id,
              eventId: eventId,
              sessionId: sessionId,
              // Anonymous guests (no account) use guest.id as placeholder;
              // they won't match any authUid so isSelf stays false.
              userId: g.userId ?? g.id,
              displayName: g.displayName,
              avatarUrl: g.avatarUrl,
              checkedInAt: g.rsvpAt,
            ))
        .toList();
  }

  /// Fetches all queue activities + entries + free pool for a specific session.
  /// Cache keyed by sessionId.
  Future<void> fetchSessionQueues(String eventId, String sessionId) async {
    try {
      // Single query with embedded entries — avoids N+1 round trips.
      // PostgREST returns session_queue_entries as a nested list inside each
      // activity row; SessionQueueActivity.fromJson ignores unknown keys safely.
      final actRows = await _db
          .from('session_queue_activities')
          .select('*, session_queue_entries(*)')
          .eq('session_id', sessionId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true) as List<dynamic>;

      final activities = <SessionQueueActivity>[];
      for (final row in actRows) {
        final rowMap = row as Map<String, dynamic>;
        final entryRows =
            (rowMap['session_queue_entries'] as List<dynamic>?) ?? [];

        activities.add(SessionQueueActivity.fromJson(rowMap));

        final actId = rowMap['id'] as String;
        _queueEntries[actId] = entryRows
            .map((e) => SessionQueueEntry.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
      }

      _sessionQueues[sessionId] = activities;
      _indexActivities(sessionId, activities);

      // Free pool = event members not currently in any queue (computed client-side).
      _recomputeFreePool(eventId, sessionId);

      notifyListeners();
    } catch (e) {
      debugPrint('EventProvider.fetchSessionQueues error: $e');
    }
  }

  /// Organizer bulk-creates [count] queues with [spots] spots each for the session.
  /// Deletes any existing queues first.
  Future<void> setupQueues(
    String eventId,
    String sessionId,
    int count,
    int spots, {
    bool allowDuplicates = false,
  }) async {
    await _db.rpc('setup_session_queues', params: {
      'p_session_id': sessionId,
      'p_count': count,
      'p_spots': spots,
      'p_allow_duplicates': allowDuplicates,
    });
    unawaited(fetchSessionQueues(eventId, sessionId));
  }

  Future<void> joinQueue(String activityId, String eventId, String sessionId) async {
    // Fire the RPC; the Realtime INSERT event delivers the new entry to all
    // clients (including the caller) without a separate fetch round-trip.
    // The 8-second poll in the Activity tab serves as a fallback if Realtime
    // misses the event.
    await _db.rpc('join_queue', params: {'p_activity_id': activityId});
  }

  Future<void> leaveQueue(String entryId, String activityId, String eventId, String sessionId) async {
    // Optimistic: remove immediately so the UI responds before the RPC completes.
    // If the entry isn't in cache (already removed by Realtime), skip the
    // optimistic step and just fire the RPC — the RPC is a no-op if already gone.
    final removed = _queueEntries[activityId]
        ?.where((e) => e.id == entryId)
        .firstOrNull;

    if (removed != null) {
      _queueEntries[activityId]!.removeWhere((e) => e.id == entryId);
      _recomputeFreePoolForActivity(activityId);
      notifyListeners();
    }

    try {
      await _db.rpc('leave_queue', params: {'p_entry_id': entryId});
      // Realtime DELETE confirms removal on all other clients.
    } catch (e) {
      // Revert optimistic removal and restore the entry.
      if (removed != null) {
        final list = _queueEntries[activityId] ??= [];
        if (!list.any((entry) => entry.id == entryId)) {
          list.add(removed);
          list.sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
        }
        _recomputeFreePoolForActivity(activityId);
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Atomically adds multiple members to a queue in one transaction.
  /// Raises 'queue_full' if there are not enough spots (race-condition safe).
  Future<void> addMultipleMembersToQueue(
    String activityId,
    String eventId,
    String sessionId,
    List<EventGuest> members,
  ) async {
    final payload = members.map((g) => {
      'user_id': g.userId,
      'display_name': g.displayName,
      'avatar_url': g.avatarUrl,
    }).toList();
    await _db.rpc('add_members_to_queue', params: {
      'p_activity_id': activityId,
      'p_members': payload,
    });
    // Realtime INSERT events deliver the new entries to all clients.
  }

  Future<void> addMemberToQueue(
    String activityId,
    String eventId,
    String sessionId, {
    String? userId,
    required String displayName,
    String? avatarUrl,
  }) async {
    await _db.rpc('add_member_to_queue', params: {
      'p_activity_id': activityId,
      'p_user_id': userId,
      'p_display_name': displayName,
      'p_avatar_url': avatarUrl,
    });
    // Realtime INSERT event delivers the new entry to all clients.
  }

  /// Sets the status of a queue row ('waiting' | 'active' | 'ended').
  /// Any event member can call this; Realtime propagates to all clients.
  Future<void> setQueueStatus(
      String activityId, String sessionId, String status) async {
    final list = _sessionQueues[sessionId];
    if (list != null) {
      final idx = list.indexWhere((q) => q.id == activityId);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(
          status: QueueStatus.fromString(status),
        );
        notifyListeners();
      }
    }
    await _db.rpc('set_queue_status', params: {
      'p_activity_id': activityId,
      'p_status': status,
    });
  }

  /// Reorders a queue row from [oldIndex] to [newIndex] within the session.
  /// Uses move_queue_to_position — O(range) DB updates, not O(N).
  Future<void> moveQueueByIndex(
      String sessionId, int oldIndex, int newIndex) async {
    final queues = List<SessionQueueActivity>.from(
        _sessionQueues[sessionId] ?? []);
    if (oldIndex == newIndex ||
        oldIndex >= queues.length ||
        newIndex >= queues.length) {
      return;
    }

    final targetSortOrder = queues[newIndex].sortOrder;
    final moved = queues.removeAt(oldIndex);
    queues.insert(newIndex, moved);
    _sessionQueues[sessionId] = queues;
    notifyListeners();

    await _db.rpc('move_queue_to_position', params: {
      'p_activity_id': moved.id,
      'p_session_id': sessionId,
      'p_new_position': targetSortOrder,
    });
  }

  /// Clears all spots from a queue row (game has started).
  Future<void> clearQueue(String activityId, String eventId, String sessionId) async {
    await _db.rpc('clear_queue', params: {'p_activity_id': activityId});
    unawaited(fetchSessionQueues(eventId, sessionId));
  }

  /// Clears all entries from a queue optimistically. Queue row stays — the
  /// queue structure is immutable until the organizer reconfigures it.
  Future<void> clearQueueForEvict(
      String activityId, String eventId, String sessionId) async {
    final previous = List<SessionQueueEntry>.from(
        _queueEntries[activityId] ?? []);
    _queueEntries[activityId] = [];
    _recomputeFreePool(eventId, sessionId);
    notifyListeners();
    try {
      await _db.rpc('clear_queue', params: {'p_activity_id': activityId});
    } catch (e) {
      _queueEntries[activityId] = previous;
      _recomputeFreePool(eventId, sessionId);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteQueueActivity(String activityId, String eventId, String sessionId) async {
    // Optimistic: remove the row and all its entries from local caches immediately.
    final removed = _sessionQueues[sessionId]
        ?.where((a) => a.id == activityId)
        .firstOrNull;
    _sessionQueues[sessionId]?.removeWhere((a) => a.id == activityId);
    _queueEntries.remove(activityId);
    _activityMeta.remove(activityId);
    _recomputeFreePool(eventId, sessionId);
    notifyListeners();

    try {
      await _db.rpc('delete_queue_activity', params: {'p_activity_id': activityId});
      // Realtime DELETE on session_queue_activities confirms removal on all clients.
    } catch (e) {
      if (removed != null) {
        // Revert via a full re-fetch — we lost both the activity and entries.
        unawaited(fetchSessionQueues(eventId, sessionId));
      }
      rethrow;
    }
  }

  /// Returns true when there is at least one empty queue anywhere after this
  /// queue — i.e. "Just Played! Back in Line" is a valid action.
  bool canMoveQueuePastEmpty(String activityId, String sessionId) {
    final queues = _sessionQueues[sessionId] ?? [];
    final currentIdx = queues.indexWhere((q) => q.id == activityId);
    if (currentIdx == -1) return false;
    return queues.skip(currentIdx + 1).any(
      (q) => (_queueEntries[q.id] ?? []).isEmpty,
    );
  }

  /// Moves this queue to the position of the first empty queue after it,
  /// shifting all intermediate queues up by one slot.
  ///
  /// Uses move_queue_to_position — only the affected range is updated in the
  /// DB (O(range) rows), not every queue in the session. Realtime UPDATE
  /// events propagate to all connected clients automatically.
  Future<void> moveQueuePastFirstEmpty(String activityId, String sessionId) async {
    final queues = List<SessionQueueActivity>.from(_sessionQueues[sessionId] ?? []);
    final currentIdx = queues.indexWhere((q) => q.id == activityId);
    if (currentIdx == -1) return;

    final firstEmptyIdx = queues.indexWhere(
      (q) => (_queueEntries[q.id] ?? []).isEmpty,
      currentIdx + 1,
    );
    if (firstEmptyIdx == -1) return;

    // Target is one position BEFORE the first empty slot so the played group
    // lands at that slot and the empty row stays just after them.
    final targetSortOrder = queues[firstEmptyIdx].sortOrder - 1;

    // Optimistic update: remove from current position and reinsert just before
    // the first empty slot so intermediate queues visually shift up immediately.
    // Also reset status to waiting locally so the playing animation stops instantly.
    final played = queues.removeAt(currentIdx);
    final resetPlayed = played.copyWith(status: QueueStatus.waiting);
    queues.insert(firstEmptyIdx - 1, resetPlayed);
    _sessionQueues[sessionId] = queues;
    notifyListeners();

    // Optimized RPC: 2 SQL statements (one bulk shift + one move), fires
    // Realtime events only for the rows that actually changed sort_order.
    await _db.rpc('move_queue_to_position', params: {
      'p_activity_id': activityId,
      'p_session_id': sessionId,
      'p_new_position': targetSortOrder,
    });
    // Reset status to waiting — they're back in line, not playing anymore.
    await _db.rpc('set_queue_status', params: {
      'p_activity_id': activityId,
      'p_status': 'waiting',
    });
  }

  // Free pool is now auto-computed from the session roster; no explicit join/leave needed.

  /// Organizer manually activates or deactivates a session.
  /// Sets is_active AND is_active_override = true so the auto-timer won't revert.
  Future<void> toggleSessionActive(String sessionId, String eventId, {required bool active}) async {
    await _db.rpc('toggle_session_active', params: {
      'p_session_id': sessionId,
      'p_active': active,
    });
    _patchSessionInCache(eventId, sessionId, (s) => EventSession(
      id: s.id, eventId: s.eventId, sessionNumber: s.sessionNumber,
      startAt: s.startAt, endAt: s.endAt, inviteCode: s.inviteCode,
      createdAt: s.createdAt, goingCount: s.goingCount,
      waitlistCount: s.waitlistCount, pendingCount: s.pendingCount,
      capacity: s.capacity, waitlistEnabled: s.waitlistEnabled,
      signupLockHours: s.signupLockHours, isPublic: s.isPublic,
      requiresApproval: s.requiresApproval, isActive: active,
      isActiveOverride: true,
    ));
    notifyListeners();
  }

  /// Called by the client-side auto-timer only.
  /// The DB-level RPC also enforces is_active_override as a safety net.
  Future<void> autoSessionActive(String sessionId, String eventId, {required bool active}) async {
    // Find session in either cache without throwing.
    final allSessions = [
      ...(_upcomingSessions[eventId] ?? []),
      ...(_pastSessions[eventId] ?? []),
    ];
    final session = allSessions.where((s) => s.id == sessionId).firstOrNull;

    // Skip if organizer has manual control or session not in cache yet.
    if (session == null || session.isActiveOverride) return;

    await _db.rpc('auto_session_active', params: {
      'p_session_id': sessionId,
      'p_active': active,
    });
    _patchSessionInCache(eventId, sessionId, (s) => EventSession(
      id: s.id, eventId: s.eventId, sessionNumber: s.sessionNumber,
      startAt: s.startAt, endAt: s.endAt, inviteCode: s.inviteCode,
      createdAt: s.createdAt, goingCount: s.goingCount,
      waitlistCount: s.waitlistCount, pendingCount: s.pendingCount,
      capacity: s.capacity, waitlistEnabled: s.waitlistEnabled,
      signupLockHours: s.signupLockHours, isPublic: s.isPublic,
      requiresApproval: s.requiresApproval, isActive: active,
      isActiveOverride: false,
    ));
    notifyListeners();
  }

}

