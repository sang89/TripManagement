import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/blocked_user.dart';
import 'package:trip_management/providers/blocked_users_provider.dart';

BlockedUser _makeUser(String id, {String name = ''}) => BlockedUser(
      userId: id,
      fullName: name.isEmpty ? 'User $id' : name,
      avatarUrl: '',
      blockedAt: DateTime(2025),
    );

void main() {
  group('BlockedUser.fromJson', () {
    test('parses all fields', () {
      final json = {
        'user_id': 'abc',
        'full_name': 'Alice',
        'avatar_url': 'https://example.com/a.jpg',
        'blocked_at': '2025-01-15T10:00:00.000Z',
      };
      final user = BlockedUser.fromJson(json);
      expect(user.userId, 'abc');
      expect(user.fullName, 'Alice');
      expect(user.avatarUrl, 'https://example.com/a.jpg');
      expect(user.blockedAt, DateTime.utc(2025, 1, 15, 10));
    });

    test('uses empty strings for absent optional fields', () {
      final json = {
        'user_id': 'xyz',
        'blocked_at': '2025-06-01T00:00:00.000Z',
      };
      final user = BlockedUser.fromJson(json);
      expect(user.fullName, '');
      expect(user.avatarUrl, '');
    });
  });

  group('BlockedUsersProvider', () {
    test('initial state is empty and not loading', () {
      final provider = BlockedUsersProvider();
      expect(provider.blocked, isEmpty);
      expect(provider.loading, isFalse);
    });

    test('isBlocked returns false for unknown userId', () {
      final provider = BlockedUsersProvider();
      expect(provider.isBlocked('some-user'), isFalse);
    });

    test('clear resets blocked list and loading flag', () {
      final provider = BlockedUsersProvider();
      provider.clear();
      expect(provider.blocked, isEmpty);
      expect(provider.loading, isFalse);
    });

    test('blocked list is unmodifiable', () {
      final provider = BlockedUsersProvider();
      expect(
        () => (provider.blocked as List).add(_makeUser('x')),
        throwsUnsupportedError,
      );
    });

    test('clear notifies listeners', () {
      final provider = BlockedUsersProvider();
      var notified = false;
      provider.addListener(() => notified = true);
      provider.clear();
      expect(notified, isTrue);
    });
  });
}
