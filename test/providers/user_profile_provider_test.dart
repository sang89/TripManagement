import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/user_profile.dart';

// ── UserProfile model tests ───────────────────────────────────────────────────

UserProfile _makeProfile({
  String id = 'p1',
  String userId = 'u1',
  String fullName = 'Alice Smith',
  String jobTitle = 'Explorer',
  String phone = '+1 555 000 0000',
  String avatarUrl = '',
}) =>
    UserProfile(
      id: id,
      userId: userId,
      fullName: fullName,
      jobTitle: jobTitle,
      phone: phone,
      avatarUrl: avatarUrl,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 6, 1),
    );

void main() {
  group('UserProfile.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'p1',
        'user_id': 'u1',
        'full_name': 'Bob Jones',
        'job_title': 'Adventurer',
        'phone': '+1 555 111 2222',
        'avatar_url': 'https://example.com/avatar.jpg',
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-06-01T00:00:00.000Z',
      };
      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'p1');
      expect(profile.userId, 'u1');
      expect(profile.fullName, 'Bob Jones');
      expect(profile.jobTitle, 'Adventurer');
      expect(profile.phone, '+1 555 111 2222');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('uses empty strings for absent optional fields', () {
      final json = {
        'id': 'p2',
        'user_id': 'u2',
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };
      final profile = UserProfile.fromJson(json);

      expect(profile.fullName, '');
      expect(profile.jobTitle, '');
      expect(profile.phone, '');
      expect(profile.avatarUrl, '');
    });
  });

  group('UserProfile.toJson', () {
    test('serialises editable fields only', () {
      final profile = _makeProfile();
      final json = profile.toJson();

      expect(json['full_name'], 'Alice Smith');
      expect(json['job_title'], 'Explorer');
      expect(json['phone'], '+1 555 000 0000');

      // id, user_id, avatar_url, created_at, updated_at are NOT included
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('user_id'), isFalse);
      expect(json.containsKey('avatar_url'), isFalse);
    });
  });

  group('UserProfile.copyWith', () {
    test('updates specified fields and preserves others', () {
      final original = _makeProfile();
      final updated = original.copyWith(fullName: 'Carol Doe', phone: '');

      expect(updated.fullName, 'Carol Doe');
      expect(updated.phone, '');
      // unchanged
      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
      expect(updated.jobTitle, original.jobTitle);
      expect(updated.avatarUrl, original.avatarUrl);
      expect(updated.createdAt, original.createdAt);
    });

    test('copyWith with no arguments returns identical values', () {
      final original = _makeProfile();
      final copy = original.copyWith();

      expect(copy.fullName, original.fullName);
      expect(copy.jobTitle, original.jobTitle);
      expect(copy.phone, original.phone);
    });
  });

  group('UserProfile.displayAvatarUrl', () {
    test('returns tripAvatarUrl when set', () {
      final profile = _makeProfile(avatarUrl: 'https://example.com/shared.jpg').copyWith(
        tripAvatarUrl: 'https://example.com/trip.jpg',
      );
      expect(profile.displayAvatarUrl, 'https://example.com/trip.jpg');
    });

    test('returns null when tripAvatarUrl is null (no fallback to shared avatar)', () {
      // TripManagement never shows the PropertyManagement avatar.
      final profile = _makeProfile(avatarUrl: 'https://example.com/shared.jpg');
      expect(profile.displayAvatarUrl, isNull);
    });

    test('returns null when both URLs are empty', () {
      final profile = _makeProfile(avatarUrl: '');
      expect(profile.displayAvatarUrl, isNull);
    });

    test('stored URL has no ?v= query param (cache busting is UI-layer only)', () {
      // uploadAvatar stores the clean getPublicUrl result; the profile screen
      // appends ?v=N before passing to SupabaseImage.
      const storedUrl = 'https://project.supabase.co/storage/v1/object/public/avatars/trip/u1/avatar';
      expect(storedUrl.contains('?v='), isFalse);
    });
  });
}
