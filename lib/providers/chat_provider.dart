import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

/// Manages the chat message list for a single trip.
///
/// Scoped to one trip — instantiate inside TripDetailScreen and dispose with
/// the screen. Call [init] once after construction.
class ChatProvider extends ChangeNotifier {
  final String tripId;
  final String userId;

  ChatProvider({required this.tripId, required this.userId});

  SupabaseClient get _db => Supabase.instance.client;

  static const _pageSize = 50;

  List<ChatMessage> _messages = []; // sorted oldest → newest
  bool _loading = false;
  bool _hasMore = true;
  RealtimeChannel? _channel;

  // ─── Public state ──────────────────────────────────────────────────────────

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get hasMore => _hasMore;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _fetchPage(initial: true);
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // ─── Fetch ─────────────────────────────────────────────────────────────────

  Future<void> _fetchPage({bool initial = false}) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      List<Map<String, dynamic>> data;
      if (!initial && _messages.isNotEmpty) {
        final raw = await _db
            .from('trip_messages')
            .select('id, trip_id, user_id, content, created_at')
            .eq('trip_id', tripId)
            .lt('created_at', _messages.first.createdAt.toIso8601String())
            .order('created_at', ascending: false)
            .limit(_pageSize);
        data = List<Map<String, dynamic>>.from(raw as List);
      } else {
        final raw = await _db
            .from('trip_messages')
            .select('id, trip_id, user_id, content, created_at')
            .eq('trip_id', tripId)
            .order('created_at', ascending: false)
            .limit(_pageSize);
        data = List<Map<String, dynamic>>.from(raw as List);
      }

      // DB returns newest-first; reverse so list is oldest → newest.
      final fetched =
          await _enrichNames(data.reversed.map(ChatMessage.fromJson).toList());

      if (initial) {
        _messages = fetched;
      } else {
        _messages = [...fetched, ..._messages];
      }
      _hasMore = data.length == _pageSize;
    } catch (e, st) {
      debugPrint('ChatProvider._fetchPage error: $e\n$st');
    }

    _loading = false;
    notifyListeners();
  }

  Future<List<ChatMessage>> _enrichNames(List<ChatMessage> msgs) async {
    if (msgs.isEmpty) return msgs;
    final ids = msgs.map((m) => m.userId).toSet().toList();
    try {
      final profiles = await _db.rpc(
        'get_profile_names',
        params: {'p_user_ids': ids},
      ) as List<dynamic>;

      final nameMap = <String, String>{};
      for (final p in profiles) {
        final m = p as Map<String, dynamic>;
        nameMap[m['user_id'] as String] = m['full_name'] as String? ?? '';
      }
      return msgs
          .map((m) => m.copyWith(senderName: nameMap[m.userId] ?? ''))
          .toList();
    } catch (_) {
      return msgs;
    }
  }

  // ─── Realtime ──────────────────────────────────────────────────────────────

  void _subscribe() {
    _channel?.unsubscribe();
    _channel = _db
        .channel('chat_$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            if (row.isEmpty) return;
            final id = row['id'] as String?;
            // Dedup guard: skip if we already have this message.
            if (id != null && _messages.any((m) => m.id == id)) return;
            final msg = ChatMessage.fromJson(Map<String, dynamic>.from(row));
            // Remove matching optimistic placeholder before appending.
            _messages = [
              ..._messages.where((m) => !m.id.startsWith('temp_')),
              (await _enrichNames([msg])).first,
            ];
            notifyListeners();
          },
        )
        .subscribe();
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    // Optimistic local append.
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      tripId: tripId,
      userId: userId,
      content: trimmed,
      createdAt: DateTime.now().toUtc(),
    );
    _messages = [..._messages, optimistic];
    notifyListeners();

    try {
      await _db.from('trip_messages').insert({
        'trip_id': tripId,
        'user_id': userId,
        'content': trimmed,
      });
      // The Realtime callback will remove temp_ entries and append the real row.
    } catch (e, st) {
      debugPrint('ChatProvider.sendMessage error: $e\n$st');
      _messages = _messages.where((m) => m.id != tempId).toList();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadMore() => _fetchPage();
}
