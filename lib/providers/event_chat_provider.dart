import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_message.dart';

/// Manages the chat message list for a single event.
///
/// Scoped to one event — instantiate inside EventDetailScreen and dispose with
/// the screen. Call [init] once after construction.
class EventChatProvider extends ChangeNotifier {
  final String eventId;
  final String userId;

  EventChatProvider({required this.eventId, required this.userId});

  SupabaseClient get _db => Supabase.instance.client;

  static const _pageSize = 50;

  List<EventMessage> _messages = []; // sorted oldest → newest
  bool _loading = false;
  bool _hasMore = true;
  RealtimeChannel? _channel;

  List<EventMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get hasMore => _hasMore;

  Future<void> init() async {
    await _fetchPage(initial: true);
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchPage({bool initial = false}) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      List<Map<String, dynamic>> data;
      if (!initial && _messages.isNotEmpty) {
        final raw = await _db
            .from('event_messages')
            .select('id, event_id, user_id, content, created_at')
            .eq('event_id', eventId)
            .lt('created_at', _messages.first.createdAt.toIso8601String())
            .order('created_at', ascending: false)
            .limit(_pageSize);
        data = List<Map<String, dynamic>>.from(raw as List);
      } else {
        final raw = await _db
            .from('event_messages')
            .select('id, event_id, user_id, content, created_at')
            .eq('event_id', eventId)
            .order('created_at', ascending: false)
            .limit(_pageSize);
        data = List<Map<String, dynamic>>.from(raw as List);
      }

      final fetched = await _enrichNames(
        data.reversed.map(EventMessage.fromJson).toList(),
      );

      if (initial) {
        _messages = fetched;
      } else {
        _messages = [...fetched, ..._messages];
      }
      _hasMore = data.length == _pageSize;
    } catch (e, st) {
      debugPrint('EventChatProvider._fetchPage error: $e\n$st');
    }

    _loading = false;
    notifyListeners();
  }

  Future<List<EventMessage>> _enrichNames(List<EventMessage> msgs) async {
    if (msgs.isEmpty) return msgs;
    final ids = msgs.map((m) => m.userId).toSet().toList();
    try {
      final profiles = await _db.rpc(
        'get_profile_names',
        params: {'p_user_ids': ids},
      ) as List<dynamic>;

      final nameMap = <String, String>{};
      final avatarMap = <String, String?>{};
      for (final p in profiles) {
        final m = p as Map<String, dynamic>;
        nameMap[m['user_id'] as String] = m['full_name'] as String? ?? '';
        avatarMap[m['user_id'] as String] = m['avatar_url'] as String?;
      }
      return msgs
          .map((m) => m.copyWith(
                senderName: nameMap[m.userId] ?? '',
                senderAvatarUrl: avatarMap[m.userId],
              ))
          .toList();
    } catch (_) {
      return msgs;
    }
  }

  void _subscribe() {
    _channel?.unsubscribe();
    _channel = _db
        .channel('event_chat_$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            if (row.isEmpty) return;
            final id = row['id'] as String?;
            if (id != null && _messages.any((m) => m.id == id)) return;
            final msg = EventMessage.fromJson(Map<String, dynamic>.from(row));
            _messages = [
              ..._messages.where((m) => !m.id.startsWith('temp_')),
              (await _enrichNames([msg])).first,
            ];
            notifyListeners();
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = EventMessage(
      id: tempId,
      eventId: eventId,
      userId: userId,
      content: trimmed,
      createdAt: DateTime.now().toUtc(),
    );
    _messages = [..._messages, optimistic];
    notifyListeners();

    try {
      await _db.from('event_messages').insert({
        'event_id': eventId,
        'user_id': userId,
        'content': trimmed,
      });
    } catch (e, st) {
      debugPrint('EventChatProvider.sendMessage error: $e\n$st');
      _messages = _messages.where((m) => m.id != tempId).toList();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadMore() => _fetchPage();
}
