import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blocked_user.dart';

class BlockedUsersProvider extends ChangeNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  List<BlockedUser> _blocked = [];
  bool _loading = false;

  List<BlockedUser> get blocked => List.unmodifiable(_blocked);
  bool get loading => _loading;

  bool isBlocked(String userId) => _blocked.any((b) => b.userId == userId);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final myId = _db.auth.currentUser?.id;
      if (myId == null) {
        _blocked = [];
        _loading = false;
        notifyListeners();
        return;
      }
      final blocks = await _db
          .from('user_blocks')
          .select('blocked_id, created_at')
          .eq('blocker_id', myId)
          .order('created_at', ascending: false) as List<dynamic>;

      if (blocks.isEmpty) {
        _blocked = [];
        _loading = false;
        notifyListeners();
        return;
      }

      final blockedIds =
          blocks.map((b) => b['blocked_id'] as String).toList();

      // get_profile_names is SECURITY DEFINER — bypasses user_profiles RLS
      // and returns a meaningful name (email prefix fallback, then UUID).
      final profiles = await _db.rpc(
        'get_trip_profile_names',
        params: {'p_user_ids': blockedIds},
      ) as List<dynamic>;

      final profileMap = {
        for (final p in profiles) p['user_id'] as String: p,
      };

      _blocked = blocks.map((b) {
        final id = b['blocked_id'] as String;
        final p = profileMap[id] ?? {};
        return BlockedUser(
          userId: id,
          fullName: p['full_name'] as String? ?? '',
          avatarUrl: p['avatar_url'] as String? ?? '',
          blockedAt: DateTime.parse(b['created_at'] as String),
        );
      }).toList();
    } catch (e, st) {
      debugPrint('BlockedUsersProvider.load error: $e\n$st');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> blockUser(String userId) async {
    // Optimistic insert so the blocked users screen updates immediately.
    final optimistic = BlockedUser(
      userId: userId,
      fullName: '',
      avatarUrl: '',
      blockedAt: DateTime.now().toUtc(),
    );
    _blocked = [optimistic, ..._blocked];
    notifyListeners();

    try {
      await _db.rpc('block_user', params: {'p_blocked_id': userId});
      // Reload to get the full display name / avatar from the RPC.
      await load();
    } catch (e, st) {
      debugPrint('BlockedUsersProvider.blockUser error: $e\n$st');
      // Revert optimistic update.
      _blocked = _blocked.where((b) => b.userId != userId).toList();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    final previous = List<BlockedUser>.from(_blocked);
    _blocked = _blocked.where((b) => b.userId != userId).toList();
    notifyListeners();

    try {
      await _db
          .from('user_blocks')
          .delete()
          .eq('blocker_id', _db.auth.currentUser!.id)
          .eq('blocked_id', userId);
    } catch (e, st) {
      debugPrint('BlockedUsersProvider.unblockUser error: $e\n$st');
      _blocked = previous;
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _blocked = [];
    _loading = false;
    notifyListeners();
  }
}
