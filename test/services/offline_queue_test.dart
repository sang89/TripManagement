import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_management/services/connectivity_service.dart';
import 'package:trip_management/services/offline_queue.dart';

// ── Minimal stub that lets us control isOnline without real network I/O ──────

class _FakeConnectivity extends ConnectivityService {
  bool _online;
  _FakeConnectivity({bool online = true}) : _online = online; // ignore: prefer_initializing_formals

  @override
  bool get isOnline => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }

  // Skip real platform channel init.
  @override
  Future<void> init() async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

OfflineOperation _insertOp({String table = 'trips', Map<String, dynamic>? data}) =>
    OfflineOperation(
      operationId: OfflineQueue.newOperationId(),
      table: table,
      type: OfflineOperationType.insert,
      data: data ?? {'id': 'abc', 'title': 'Test'},
    );

OfflineOperation _updateOp({Map<String, dynamic>? data, Map<String, dynamic>? filters}) =>
    OfflineOperation(
      operationId: OfflineQueue.newOperationId(),
      table: 'trips',
      type: OfflineOperationType.update,
      data: data ?? {'title': 'Updated'},
      filters: filters ?? {'id': 'abc'},
    );

OfflineOperation _deleteOp({Map<String, dynamic>? filters}) =>
    OfflineOperation(
      operationId: OfflineQueue.newOperationId(),
      table: 'trips',
      type: OfflineOperationType.delete,
      data: const {},
      filters: filters ?? {'id': 'abc'},
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // Use in-memory SharedPreferences for every test.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── OfflineOperation model ────────────────────────────────────────────────
  group('OfflineOperation JSON round-trip', () {
    test('insert op survives toJson / fromJson', () {
      final op = _insertOp(data: {'id': 't1', 'title': 'Paris'});
      final roundTripped = OfflineOperation.fromJson(op.toJson());
      expect(roundTripped.operationId, op.operationId);
      expect(roundTripped.table, 'trips');
      expect(roundTripped.type, OfflineOperationType.insert);
      expect(roundTripped.data['title'], 'Paris');
    });

    test('update op survives toJson / fromJson', () {
      final op = _updateOp(
        data: {'title': 'New Title'},
        filters: {'id': 't1'},
      );
      final rt = OfflineOperation.fromJson(op.toJson());
      expect(rt.type, OfflineOperationType.update);
      expect(rt.filters['id'], 't1');
    });

    test('delete op survives toJson / fromJson', () {
      final op = _deleteOp(filters: {'id': 't2'});
      final rt = OfflineOperation.fromJson(op.toJson());
      expect(rt.type, OfflineOperationType.delete);
      expect(rt.data, isEmpty);
    });

    test('enqueuedAt is preserved', () {
      final t = DateTime(2026, 1, 15, 10, 30);
      final op = OfflineOperation(
        operationId: OfflineQueue.newOperationId(),
        table: 'trips',
        type: OfflineOperationType.insert,
        data: const {},
        enqueuedAt: t,
      );
      final rt = OfflineOperation.fromJson(op.toJson());
      expect(rt.enqueuedAt, t);
    });
  });

  // ── OfflineQueue state ────────────────────────────────────────────────────
  group('OfflineQueue state', () {
    late _FakeConnectivity connectivity;
    late OfflineQueue queue;

    setUp(() async {
      connectivity = _FakeConnectivity(online: false);
      queue = OfflineQueue(connectivity);
      await queue.init();
    });

    tearDown(() => queue.dispose());

    test('starts empty', () {
      expect(queue.pendingCount, 0);
      expect(queue.hasPending, isFalse);
    });

    test('enqueue increases pendingCount', () async {
      await queue.enqueue(_insertOp());
      expect(queue.pendingCount, 1);
      expect(queue.hasPending, isTrue);
    });

    test('operations are ordered (FIFO)', () async {
      final a = _insertOp(data: {'id': 'a'});
      final b = _updateOp(data: {'id': 'b'});
      await queue.enqueue(a);
      await queue.enqueue(b);
      expect(queue.operations[0].operationId, a.operationId);
      expect(queue.operations[1].operationId, b.operationId);
    });

    test('seedForTest populates the queue', () {
      queue.seedForTest([_insertOp(), _deleteOp()]);
      expect(queue.pendingCount, 2);
    });

    test('clearForTest empties the queue', () {
      queue.seedForTest([_insertOp()]);
      queue.clearForTest();
      expect(queue.pendingCount, 0);
    });
  });

  // ── Persistence ───────────────────────────────────────────────────────────
  group('OfflineQueue persistence', () {
    test('persists queue and reloads it on next init', () async {
      final connectivity = _FakeConnectivity(online: false);

      // Session 1: enqueue two ops.
      final q1 = OfflineQueue(connectivity);
      await q1.init();
      await q1.enqueue(_insertOp(data: {'id': 't1', 'title': 'Paris'}));
      await q1.enqueue(_updateOp(data: {'title': 'Updated'}));
      q1.dispose();

      // Session 2: reload from prefs.
      final q2 = OfflineQueue(connectivity);
      await q2.init();
      expect(q2.pendingCount, 2);
      expect(q2.operations[0].data['title'], 'Paris');
      expect(q2.operations[1].data['title'], 'Updated');
      q2.dispose();
    });
  });

  // ── newOperationId ────────────────────────────────────────────────────────
  group('newOperationId', () {
    test('returns a valid UUID v4 string', () {
      final id = OfflineQueue.newOperationId();
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuidPattern.hasMatch(id), isTrue);
    });

    test('returns unique IDs on successive calls', () {
      final ids = List.generate(100, (_) => OfflineQueue.newOperationId());
      expect(ids.toSet().length, 100);
    });
  });
}
