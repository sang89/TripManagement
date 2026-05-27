import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_logging/shared_logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'connectivity_service.dart';

// ─── Operation model ──────────────────────────────────────────────────────────

enum OfflineOperationType { insert, update, delete }

/// A single Supabase database operation that could not be executed because the
/// device was offline. The operation is serialised to JSON and persisted in
/// [SharedPreferences] so it survives app restarts.
class OfflineOperation {
  final String operationId; // UUID that uniquely identifies this queued op
  final String table;
  final OfflineOperationType type;

  /// Row data for [insert] / [update]. Must be JSON-serialisable (no Uint8List).
  final Map<String, dynamic> data;

  /// Column → value conditions used in `.eq()` chains for [update] / [delete].
  final Map<String, dynamic> filters;

  final DateTime enqueuedAt;

  OfflineOperation({
    required this.operationId,
    required this.table,
    required this.type,
    required this.data,
    Map<String, dynamic>? filters,
    DateTime? enqueuedAt,
  })  : filters = filters ?? const {},
        enqueuedAt = enqueuedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'operationId': operationId,
        'table': table,
        'type': type.name,
        'data': data,
        'filters': filters,
        'enqueuedAt': enqueuedAt.toIso8601String(),
      };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) =>
      OfflineOperation(
        operationId: json['operationId'] as String,
        table: json['table'] as String,
        type: OfflineOperationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => OfflineOperationType.insert,
        ),
        data: Map<String, dynamic>.from(json['data'] as Map),
        filters: Map<String, dynamic>.from(
            json['filters'] as Map? ?? <String, dynamic>{}),
        enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      );
}

// ─── Queue service ────────────────────────────────────────────────────────────

/// Persists write operations that failed because the device was offline, then
/// replays them (in order) when connectivity is restored.
///
/// **Usage in providers:**
/// ```dart
/// if (_isOnline) {
///   await _db.from('table').insert(payload);
/// } else {
///   <optimistic in-memory update>
///   await _queue?.enqueue(OfflineOperation(...));
/// }
/// ```
///
/// The queue is stored under [_prefsKey] in [SharedPreferences] so pending
/// operations survive app restarts. On the next launch (or the moment the
/// device reconnects), [flush] replays every pending operation against Supabase.
class OfflineQueue extends ChangeNotifier {
  static const String _prefsKey = 'trip_offline_queue_v1';
  static const _uuid = Uuid();

  final ConnectivityService _connectivity;
  List<OfflineOperation> _queue = [];
  bool _isFlushing = false;
  bool _lastFlushHadErrors = false;

  OfflineQueue(this._connectivity);

  // ─── Getters ───────────────────────────────────────────────────────────────

  int get pendingCount => _queue.length;
  bool get hasPending => _queue.isNotEmpty;
  bool get isFlushing => _isFlushing;
  bool get lastFlushHadErrors => _lastFlushHadErrors;

  /// Read-only snapshot of pending operations (useful for diagnostics / tests).
  List<OfflineOperation> get operations => List.unmodifiable(_queue);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Load persisted queue from storage and subscribe to connectivity changes.
  /// Call once in [main] after [ConnectivityService.init].
  Future<void> init() async {
    await _loadFromPrefs();
    _connectivity.addListener(_onConnectivityChanged);
    // If we're already online at startup and have pending ops, flush now.
    if (_connectivity.isOnline && _queue.isNotEmpty) {
      unawaited(flush());
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _queue.isNotEmpty && !_isFlushing) {
      unawaited(flush());
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Add an operation to the end of the queue and persist it to storage.
  Future<void> enqueue(OfflineOperation op) async {
    _queue.add(op);
    await _persistToPrefs();
    notifyListeners();
  }

  /// Replay all pending operations against Supabase in the order they were
  /// enqueued. Each successful operation is removed from the queue immediately.
  /// Failed operations stay in the queue for the next flush attempt.
  Future<void> flush() async {
    if (_isFlushing || _queue.isEmpty) return;
    _isFlushing = true;
    _lastFlushHadErrors = false;
    notifyListeners();

    final db = Supabase.instance.client;
    // Copy so we can iterate while modifying _queue.
    final snapshot = List<OfflineOperation>.from(_queue);

    for (final op in snapshot) {
      try {
        await _execute(db, op);
        _queue.removeWhere((o) => o.operationId == op.operationId);
        await _persistToPrefs();
      } catch (e, st) {
        AppLogger.logError(e, st);
        _lastFlushHadErrors = true;
        // Keep op in queue; it will be retried on next flush.
      }
    }

    _isFlushing = false;
    notifyListeners();
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _execute(SupabaseClient db, OfflineOperation op) async {
    switch (op.type) {
      case OfflineOperationType.insert:
        // upsert is idempotent — safe to replay if the op was partially applied.
        await db.from(op.table).upsert(op.data);

      case OfflineOperationType.update:
        var q = db.from(op.table).update(op.data);
        for (final e in op.filters.entries) {
          q = q.eq(e.key, e.value);
        }
        await q;

      case OfflineOperationType.delete:
        var q = db.from(op.table).delete();
        for (final e in op.filters.entries) {
          q = q.eq(e.key, e.value);
        }
        await q;
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json == null) return;
      final list = jsonDecode(json) as List<dynamic>;
      _queue = list
          .map((e) => OfflineOperation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.logError(e, st);
      _queue = [];
    }
  }

  Future<void> _persistToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_queue.map((op) => op.toJson()).toList()),
      );
    } catch (e, st) {
      AppLogger.logError(e, st);
    }
  }

  // ─── Testing helpers ───────────────────────────────────────────────────────

  @visibleForTesting
  void seedForTest(List<OfflineOperation> ops) {
    _queue = List.of(ops);
    notifyListeners();
  }

  @visibleForTesting
  void clearForTest() {
    _queue.clear();
    notifyListeners();
  }

  /// Generates a new operation-level UUID (exposed for test convenience).
  static String newOperationId() => _uuid.v4();

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
