import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/utils/invite_codec.dart';

void main() {
  const uuid = '25b282ec-8cfc-4a7b-b8e9-1234567890ab';

  group('InviteCodec.encode', () {
    test('produces a 22-char Base64url string', () {
      final result = InviteCodec.encode(uuid);
      expect(result.length, 22);
      expect(RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(result), isTrue);
    });

    test('is shorter than the raw UUID', () {
      expect(InviteCodec.encode(uuid).length, lessThan(uuid.length));
    });
  });

  group('InviteCodec round-trip', () {
    test('encode then decode returns the original UUID', () {
      expect(InviteCodec.decode(InviteCodec.encode(uuid)), uuid);
    });

    test('works for any valid UUID', () {
      const ids = [
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
        '00000000-0000-0000-0000-000000000000',
        'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      ];
      for (final id in ids) {
        expect(InviteCodec.decode(InviteCodec.encode(id)), id);
      }
    });
  });

  group('InviteCodec.decode', () {
    test('passes raw UUID through unchanged', () {
      expect(InviteCodec.decode(uuid), uuid);
    });

    test('handles surrounding whitespace', () {
      final encoded = InviteCodec.encode(uuid);
      expect(InviteCodec.decode('  $encoded  '), uuid);
      expect(InviteCodec.decode('  $uuid  '), uuid);
    });
  });

  group('InviteCodec.extract', () {
    late String encoded;
    setUp(() => encoded = InviteCodec.encode(uuid));

    test('extracts from session invite URL with encoded code', () {
      expect(
        InviteCodec.extract('https://tripmanagement.app/session/invite/$encoded'),
        uuid,
      );
    });

    test('extracts from event invite URL with encoded code', () {
      expect(
        InviteCodec.extract('https://tripmanagement.app/event/invite/$encoded'),
        uuid,
      );
    });

    test('extracts from URL with raw UUID', () {
      expect(
        InviteCodec.extract('https://tripmanagement.app/session/invite/$uuid'),
        uuid,
      );
    });

    test('extracts standalone encoded code', () {
      expect(InviteCodec.extract(encoded), uuid);
    });

    test('extracts standalone raw UUID', () {
      expect(InviteCodec.extract(uuid), uuid);
    });

    test('returns null for unrecognised input', () {
      expect(InviteCodec.extract('not-a-code'), isNull);
      expect(InviteCodec.extract(''), isNull);
    });
  });
}
