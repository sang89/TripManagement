import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/friendship.dart';

void main() {
  group('Friendship.fromJson', () {
    final json = {
      'id': 'f1',
      'requester_id': 'u1',
      'addressee_id': 'u2',
      'status': 'pending',
      'created_at': '2026-05-30T10:00:00.000Z',
    };

    test('parses all fields', () {
      final f = Friendship.fromJson(json);
      expect(f.id, 'f1');
      expect(f.requesterId, 'u1');
      expect(f.addresseeId, 'u2');
      expect(f.status, 'pending');
      expect(f.createdAt, DateTime.utc(2026, 5, 30, 10));
    });

    test('defaults status to pending when absent', () {
      final j = Map<String, dynamic>.from(json)..remove('status');
      final f = Friendship.fromJson(j);
      expect(f.status, 'pending');
    });

    test('otherUserId returns addressee when caller is requester', () {
      final f = Friendship.fromJson(json);
      expect(f.otherUserId('u1'), 'u2');
    });

    test('otherUserId returns requester when caller is addressee', () {
      final f = Friendship.fromJson(json);
      expect(f.otherUserId('u2'), 'u1');
    });
  });

  group('Friendship.copyWith', () {
    final original = Friendship(
      id: 'f1',
      requesterId: 'u1',
      addresseeId: 'u2',
      status: 'pending',
      createdAt: DateTime(2026, 5, 30),
    );

    test('updates status', () {
      final updated = original.copyWith(status: 'accepted');
      expect(updated.status, 'accepted');
      expect(updated.id, 'f1');
    });

    test('enriches displayName', () {
      final enriched = original.copyWith(otherDisplayName: 'Alice');
      expect(enriched.otherDisplayName, 'Alice');
      expect(enriched.otherAvatarUrl, isNull);
    });

    test('preserves unchanged fields', () {
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.requesterId, original.requesterId);
      expect(copy.status, original.status);
    });
  });
}
