import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal data returned by the `find_user_by_contact` RPC function.
class LinkedUserInfo {
  final String userId;
  final String fullName;
  final String jobTitle;
  final String phone;
  final String avatarUrl;

  const LinkedUserInfo({
    required this.userId,
    required this.fullName,
    required this.jobTitle,
    required this.phone,
    required this.avatarUrl,
  });

  factory LinkedUserInfo.fromJson(Map<String, dynamic> json) {
    return LinkedUserInfo(
      userId: json['user_id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      jobTitle: (json['job_title'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      avatarUrl: (json['avatar_url'] as String?) ?? '',
    );
  }
}

/// Looks up a registered user by email or phone via the Supabase RPC function
/// `find_user_by_contact`.  Returns null if no match is found or if an error
/// occurs — callers should treat null as "no linked account" (graceful degradation).
class UserLookupService {
  Future<LinkedUserInfo?> findUserByContact({
    String? email,
    String? phone,
  }) async {
    final trimEmail = email?.trim();
    final trimPhone = phone?.trim();

    if ((trimEmail == null || trimEmail.isEmpty) &&
        (trimPhone == null || trimPhone.isEmpty)) {
      return null;
    }

    try {
      final result = await Supabase.instance.client.rpc(
        'find_user_by_contact',
        params: {
          'p_email': trimEmail ?? '',
          'p_phone': trimPhone ?? '',
        },
      );
      final list = result as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      return LinkedUserInfo.fromJson(list.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
