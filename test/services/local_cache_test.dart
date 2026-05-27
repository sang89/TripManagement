import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_management/services/local_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── saveList / loadList ───────────────────────────────────────────────────
  group('saveList / loadList', () {
    test('round-trips a list of maps', () async {
      final rows = [
        {'id': '1', 'title': 'Paris', 'value': 42},
        {'id': '2', 'title': 'Berlin', 'value': null},
      ];
      await LocalCache.saveList('test_key', rows);
      final loaded = await LocalCache.loadList('test_key');
      expect(loaded, rows);
    });

    test('returns null when key is absent', () async {
      final result = await LocalCache.loadList('missing_key');
      expect(result, isNull);
    });

    test('overwrites an existing entry', () async {
      await LocalCache.saveList('key', [{'x': 1}]);
      await LocalCache.saveList('key', [{'x': 2}]);
      final loaded = await LocalCache.loadList('key');
      expect(loaded, [{'x': 2}]);
    });

    test('round-trips an empty list', () async {
      await LocalCache.saveList('empty', []);
      final loaded = await LocalCache.loadList('empty');
      expect(loaded, isEmpty);
    });

    test('returns null when stored value is corrupt JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bad_key', 'NOT_JSON{{{{');
      final result = await LocalCache.loadList('bad_key');
      expect(result, isNull);
    });

    test('returns null when stored value is a JSON object (not array)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('obj_key', '{"id":"1"}');
      final result = await LocalCache.loadList('obj_key');
      expect(result, isNull);
    });

    test('preserves nested maps (Supabase joined rows)', () async {
      final rows = [
        {
          'id': 't1',
          'title': 'Summer Trip',
          'trip_members': [
            {'id': 'm1', 'trip_id': 't1', 'display_name': 'Alice'}
          ],
          'trip_stops': <dynamic>[],
        }
      ];
      await LocalCache.saveList('trips', rows);
      final loaded = await LocalCache.loadList('trips');
      expect(loaded![0]['trip_members'], isA<List>());
      expect(
        (loaded[0]['trip_members'] as List).first['display_name'],
        'Alice',
      );
    });

    test('different keys are independent', () async {
      await LocalCache.saveList('key_a', [{'v': 1}]);
      await LocalCache.saveList('key_b', [{'v': 2}]);
      final a = await LocalCache.loadList('key_a');
      final b = await LocalCache.loadList('key_b');
      expect(a![0]['v'], 1);
      expect(b![0]['v'], 2);
    });
  });

  // ── saveObject / loadObject ───────────────────────────────────────────────
  group('saveObject / loadObject', () {
    test('round-trips a map', () async {
      final obj = {'user_id': 'u1', 'full_name': 'Alice', 'phone': null};
      await LocalCache.saveObject('profile', obj);
      final loaded = await LocalCache.loadObject('profile');
      expect(loaded, obj);
    });

    test('returns null when key is absent', () async {
      final result = await LocalCache.loadObject('missing');
      expect(result, isNull);
    });

    test('overwrites an existing entry', () async {
      await LocalCache.saveObject('p', {'name': 'old'});
      await LocalCache.saveObject('p', {'name': 'new'});
      final loaded = await LocalCache.loadObject('p');
      expect(loaded!['name'], 'new');
    });

    test('returns null when stored value is corrupt JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bad_obj', '}{bad');
      final result = await LocalCache.loadObject('bad_obj');
      expect(result, isNull);
    });

    test('returns null when stored value is a JSON array (not object)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('arr_key', '[1,2,3]');
      final result = await LocalCache.loadObject('arr_key');
      expect(result, isNull);
    });
  });

  // ── remove ────────────────────────────────────────────────────────────────
  group('remove', () {
    test('removes a list entry so loadList returns null', () async {
      await LocalCache.saveList('to_remove', [{'x': 1}]);
      await LocalCache.remove('to_remove');
      expect(await LocalCache.loadList('to_remove'), isNull);
    });

    test('removes an object entry so loadObject returns null', () async {
      await LocalCache.saveObject('obj', {'a': 1});
      await LocalCache.remove('obj');
      expect(await LocalCache.loadObject('obj'), isNull);
    });

    test('is a no-op when key is absent', () async {
      await LocalCache.remove('never_existed');
    });

    test('does not affect other keys', () async {
      await LocalCache.saveList('keep', [{'v': 99}]);
      await LocalCache.saveList('drop', [{'v': 0}]);
      await LocalCache.remove('drop');
      final kept = await LocalCache.loadList('keep');
      expect(kept, isNotNull);
      expect(kept![0]['v'], 99);
    });
  });
}
