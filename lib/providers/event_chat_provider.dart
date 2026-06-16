import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
      const select =
          'id, event_id, user_id, content, message_type, created_at, event_message_reactions(*)';
      if (!initial && _messages.isNotEmpty) {
        final raw = await _db
            .from('event_messages')
            .select(select)
            .eq('event_id', eventId)
            .lt('created_at', _messages.first.createdAt.toIso8601String())
            .order('created_at', ascending: false)
            .limit(_pageSize);
        data = List<Map<String, dynamic>>.from(raw as List);
      } else {
        final raw = await _db
            .from('event_messages')
            .select(select)
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
            if (id == null) return;
            // Dedup: already present from pagination or a prior Realtime event.
            if (_messages.any((m) => m.id == id)) return;

            try {
              final msg = EventMessage.fromJson(Map<String, dynamic>.from(row));
              // Add the message immediately (no async wait) so concurrent
              // Realtime events don't overwrite each other's state.
              // Only remove the single temp whose content matches — not all temps.
              _messages = [
                ..._messages.where(
                  (m) => !m.id.startsWith('temp_') || m.content != msg.content,
                ),
                msg,
              ];
              notifyListeners();

              // Enrich sender name/avatar asynchronously and patch in place.
              final enriched = await _enrichNames([msg]);
              final idx = _messages.indexWhere((m) => m.id == id);
              if (idx >= 0) {
                _messages = List.of(_messages)..[idx] = enriched.first;
                notifyListeners();
              }
            } catch (e, st) {
              debugPrint('EventChatProvider Realtime INSERT error: $e\n$st');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_message_reactions',
          callback: (payload) {
            final messageId = payload.newRecord['message_id'] as String?;
            if (messageId == null) return;
            _refreshMessageReactions(messageId);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_message_reactions',
          callback: (payload) {
            final messageId = payload.oldRecord['message_id'] as String?;
            if (messageId == null) return;
            _refreshMessageReactions(messageId);
          },
        )
        .subscribe();
  }

  Future<void> _refreshMessageReactions(String messageId) async {
    try {
      final raw = await _db
          .from('event_message_reactions')
          .select()
          .eq('message_id', messageId);
      final reactions = (raw as List)
          .map((r) =>
              EventMessageReaction.fromJson(r as Map<String, dynamic>))
          .toList();
      _messages = _messages
          .map((m) => m.id == messageId ? m.copyWith(reactions: reactions) : m)
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('EventChatProvider._refreshMessageReactions error: $e');
    }
  }

  // Regex that matches mention tokens inserted by the UI: @[userId:displayName]
  static final _mentionRegex = RegExp(r'@\[([^:]+):([^\]]+)\]');

  /// Extracts all mentioned user IDs from a message content string.
  static List<String> parseMentionedIds(String content) =>
      _mentionRegex.allMatches(content).map((m) => m.group(1)!).toList();

  /// Strips mention tokens down to plain @Name for the notification preview.
  static String plainPreview(String content) =>
      content.replaceAllMapped(_mentionRegex, (m) => '@${m.group(2)}');

  Future<void> sendMessage(String content, {String messageType = 'text'}) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = EventMessage(
      id: tempId,
      eventId: eventId,
      userId: userId,
      content: trimmed,
      messageType: messageType,
      createdAt: DateTime.now().toUtc(),
    );
    _messages = [..._messages, optimistic];
    notifyListeners();

    try {
      await _db.from('event_messages').insert({
        'event_id': eventId,
        'user_id': userId,
        'content': trimmed,
        'message_type': messageType,
      });

      // Fire mention notifications after the message is persisted.
      if (messageType == 'text') {
        final mentionedIds = parseMentionedIds(trimmed);
        if (mentionedIds.isNotEmpty) {
          _sendMentionNotifications(trimmed, mentionedIds);
        }
      }
    } catch (e, st) {
      debugPrint('EventChatProvider.sendMessage error: $e\n$st');
      _messages = _messages.where((m) => m.id != tempId).toList();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendGif(String gifUrl) => sendMessage(gifUrl, messageType: 'gif');

  /// Uploads [file] to the event-photos bucket and sends it as an image message.
  Future<void> sendImage(XFile file) async {
    final ext = file.name.split('.').last.toLowerCase();
    final fileName = '${const Uuid().v4()}.$ext';
    final storagePath = '$eventId/chat/$fileName';

    final bytes = kIsWeb
        ? await file.readAsBytes()
        : await File(file.path).readAsBytes();

    await _db.storage.from('event-photos').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
        );

    final publicUrl =
        _db.storage.from('event-photos').getPublicUrl(storagePath);
    await sendMessage(publicUrl, messageType: 'image');
  }

  void _sendMentionNotifications(String content, List<String> mentionedIds) {
    _db.functions
        .invoke(
          'send-mention-notification',
          body: {
            'event_id': eventId,
            'mentioned_user_ids': mentionedIds,
            'message_preview': plainPreview(content),
          },
        )
        .then((_) {})
        .catchError((Object e) {
          debugPrint('EventChatProvider._sendMentionNotifications error: $e');
        });
  }

  Future<void> reactToMessage(String messageId, String emoji) async {
    final tempId = const Uuid().v4();
    final optimistic = EventMessageReaction(
      id: tempId,
      messageId: messageId,
      userId: userId,
      emoji: emoji,
      createdAt: DateTime.now().toUtc(),
    );
    _messages = _messages
        .map((m) => m.id == messageId
            ? m.copyWith(reactions: [...m.reactions, optimistic])
            : m)
        .toList();
    notifyListeners();

    try {
      await _db.from('event_message_reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });
    } catch (e, st) {
      debugPrint('EventChatProvider.reactToMessage error: $e\n$st');
      _messages = _messages
          .map((m) => m.id == messageId
              ? m.copyWith(
                  reactions: m.reactions.where((r) => r.id != tempId).toList())
              : m)
          .toList();
      notifyListeners();
    }
  }

  Future<void> unreactToMessage(String messageId, String reactionId) async {
    _messages = _messages
        .map((m) => m.id == messageId
            ? m.copyWith(
                reactions: m.reactions.where((r) => r.id != reactionId).toList())
            : m)
        .toList();
    notifyListeners();

    try {
      await _db
          .from('event_message_reactions')
          .delete()
          .eq('id', reactionId);
    } catch (e, st) {
      debugPrint('EventChatProvider.unreactToMessage error: $e\n$st');
      await _refreshMessageReactions(messageId);
    }
  }

  Future<void> loadMore() => _fetchPage();

  // ── Test hooks ────────────────────────────────────────────────────────────

  /// Seed the in-memory message list without touching Supabase.
  @visibleForTesting
  void setMessagesForTest(List<EventMessage> msgs) {
    _messages = List.of(msgs);
  }

  /// Simulate the state-mutation portion of the Realtime INSERT callback —
  /// dedup check + temp removal + append — without any Supabase calls.
  /// Used to regression-test the two sync bugs fixed in June 2026:
  ///   1. Concurrent events overwrote each other due to `await _enrichNames`.
  ///   2. All temps were removed instead of only the matching one.
  @visibleForTesting
  void simulateIncomingForTest(EventMessage msg) {
    if (_messages.any((m) => m.id == msg.id)) return;
    _messages = [
      ..._messages.where(
        (m) => !m.id.startsWith('temp_') || m.content != msg.content,
      ),
      msg,
    ];
    notifyListeners();
  }
}
