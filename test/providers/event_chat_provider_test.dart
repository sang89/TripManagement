// Tests for EventChatProvider state-management logic and EventMessage model.
//
// Two sync bugs were fixed in June 2026:
//
//   Bug 1 — Concurrent Realtime events overwrote each other:
//     The Realtime INSERT callback did `_messages = [..., await _enrichNames()]`.
//     If two messages arrived before either _enrichNames completed, whichever
//     finished last would set _messages to a snapshot that did not include the
//     other message — one silently disappeared.
//
//   Bug 2 — Overly broad temp removal:
//     `_messages.where((m) => !m.id.startsWith('temp_'))` removed ALL optimistic
//     messages when ANY Realtime INSERT confirmed. On rapid sends, the second
//     pending temp was wiped from the UI before its Realtime event arrived.
//
// These tests do not require Supabase. They call `simulateIncomingForTest` and
// `setMessagesForTest` — hooks that exercise only the state-mutation logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event_message.dart';
import 'package:trip_management/providers/event_chat_provider.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

EventMessage _msg(String id, String content, {String type = 'text'}) =>
    EventMessage(
      id: id,
      eventId: 'event-1',
      userId: 'user-1',
      content: content,
      messageType: type,
      createdAt: DateTime(2026, 6, 15),
    );

EventMessage _temp(String content) => _msg('temp_${content.hashCode}', content);

EventChatProvider _provider() =>
    EventChatProvider(eventId: 'event-1', userId: 'user-1');

// ── EventMessage.fromJson ─────────────────────────────────────────────────────

void main() {
  group('EventMessage.fromJson', () {
    test('parses all fields', () {
      final msg = EventMessage.fromJson({
        'id': 'msg-1',
        'event_id': 'ev-1',
        'user_id': 'u-1',
        'content': 'hello',
        'message_type': 'text',
        'created_at': '2026-06-15T10:00:00.000Z',
      });
      expect(msg.id, 'msg-1');
      expect(msg.content, 'hello');
      expect(msg.messageType, 'text');
      expect(msg.isGif, isFalse);
      expect(msg.isImage, isFalse);
      expect(msg.isMedia, isFalse);
    });

    test('message_type defaults to text when absent', () {
      final msg = EventMessage.fromJson({
        'id': 'msg-2',
        'event_id': 'ev-1',
        'user_id': 'u-1',
        'content': 'hi',
        'created_at': '2026-06-15T10:00:00.000Z',
      });
      expect(msg.messageType, 'text');
      expect(msg.isMedia, isFalse);
    });

    test('null content falls back to empty string (does not throw)', () {
      final msg = EventMessage.fromJson({
        'id': 'msg-3',
        'event_id': 'ev-1',
        'user_id': 'u-1',
        'content': null,
        'created_at': '2026-06-15T10:00:00.000Z',
      });
      expect(msg.content, '');
    });

    test('isGif true for gif type', () {
      final msg = EventMessage.fromJson({
        'id': 'msg-4',
        'event_id': 'ev-1',
        'user_id': 'u-1',
        'content': 'https://media.giphy.com/abc.gif',
        'message_type': 'gif',
        'created_at': '2026-06-15T10:00:00.000Z',
      });
      expect(msg.isGif, isTrue);
      expect(msg.isImage, isFalse);
      expect(msg.isMedia, isTrue);
    });

    test('isImage true for image type', () {
      final msg = EventMessage.fromJson({
        'id': 'msg-5',
        'event_id': 'ev-1',
        'user_id': 'u-1',
        'content': 'https://storage.example.com/photo.jpg',
        'message_type': 'image',
        'created_at': '2026-06-15T10:00:00.000Z',
      });
      expect(msg.isImage, isTrue);
      expect(msg.isGif, isFalse);
      expect(msg.isMedia, isTrue);
    });
  });

  // ── Static helpers ──────────────────────────────────────────────────────────

  group('EventChatProvider.parseMentionedIds', () {
    test('returns empty list when no mentions', () {
      expect(EventChatProvider.parseMentionedIds('hello world'), isEmpty);
    });

    test('extracts a single mention', () {
      const text = 'Hey @[uuid-123:Alice] how are you?';
      expect(EventChatProvider.parseMentionedIds(text), ['uuid-123']);
    });

    test('extracts multiple mentions', () {
      const text = '@[uid-1:Alice] and @[uid-2:Bob] come here';
      expect(EventChatProvider.parseMentionedIds(text), ['uid-1', 'uid-2']);
    });

    test('ignores plain @name text', () {
      expect(EventChatProvider.parseMentionedIds('hello @world'), isEmpty);
    });
  });

  group('EventChatProvider.plainPreview', () {
    test('strips token to @Name', () {
      const text = 'Hi @[uuid-1:Alice] and @[uuid-2:Bob]!';
      expect(EventChatProvider.plainPreview(text), 'Hi @Alice and @Bob!');
    });

    test('leaves plain text unchanged', () {
      const text = 'no mentions here';
      expect(EventChatProvider.plainPreview(text), text);
    });
  });

  // ── Realtime sync — Bug 1 regression ─────────────────────────────────────

  group('simulateIncomingForTest — Bug 1: concurrent messages both survive', () {
    // Before the fix: the Realtime callback awaited _enrichNames before writing
    // _messages. If two callbacks interleaved, the second would overwrite a
    // snapshot that didn't include the first message, losing it entirely.
    //
    // The fix: add the message synchronously (no await), then patch the name
    // enrichment in-place by index. Tests below verify that multiple calls to
    // simulateIncomingForTest (simulating two concurrent Realtime events) both
    // persist in the final message list.

    test('two messages arriving in sequence both end up in the list', () {
      final p = _provider();
      p.simulateIncomingForTest(_msg('real-1', 'first'));
      p.simulateIncomingForTest(_msg('real-2', 'second'));
      final ids = p.messages.map((m) => m.id).toList();
      expect(ids, containsAll(['real-1', 'real-2']));
      expect(ids.length, 2);
    });

    test('message content is preserved when added via simulateIncoming', () {
      final p = _provider();
      p.simulateIncomingForTest(_msg('real-1', 'yo, can we do this'));
      expect(p.messages.first.content, 'yo, can we do this');
    });

    test('three rapid messages all survive', () {
      final p = _provider();
      for (var i = 1; i <= 3; i++) {
        p.simulateIncomingForTest(_msg('real-$i', 'message $i'));
      }
      expect(p.messages.length, 3);
      expect(p.messages.map((m) => m.content),
          containsAll(['message 1', 'message 2', 'message 3']));
    });

    test('notifies listeners for each incoming message', () {
      final p = _provider();
      var notifyCount = 0;
      p.addListener(() => notifyCount++);
      p.simulateIncomingForTest(_msg('real-1', 'a'));
      p.simulateIncomingForTest(_msg('real-2', 'b'));
      expect(notifyCount, 2);
    });
  });

  // ── Realtime sync — Bug 2 regression ─────────────────────────────────────

  group('simulateIncomingForTest — Bug 2: only matching temp is removed', () {
    // Before the fix: `_messages.where((m) => !m.id.startsWith('temp_'))`
    // removed ALL optimistic temps whenever ANY Realtime INSERT confirmed.
    // On rapid sends, temp_B was wiped from the UI when temp_A's real message
    // arrived, leaving a blank gap until temp_B's Realtime event arrived.
    //
    // The fix: only remove the temp whose content matches the confirmed message.

    test('confirming message A leaves unrelated temp B in the list', () {
      final p = _provider();
      final tempA = _temp('hello');
      final tempB = _temp('world');
      p.setMessagesForTest([tempA, tempB]);

      // Realtime INSERT confirms 'hello' (was tempA).
      p.simulateIncomingForTest(_msg('real-A', 'hello'));

      final contents = p.messages.map((m) => m.content).toList();
      // real-A replaces tempA; tempB must still be present.
      expect(contents, contains('world'),
          reason: 'tempB should survive when tempA is confirmed');
      expect(contents, contains('hello'),
          reason: 'confirmed message should be present');
      // tempA should be gone (replaced by real-A).
      expect(p.messages.any((m) => m.id == tempA.id), isFalse,
          reason: 'the matching temp should be removed once confirmed');
    });

    test('confirming message B leaves unrelated temp A in the list', () {
      final p = _provider();
      final tempA = _temp('hello');
      final tempB = _temp('world');
      p.setMessagesForTest([tempA, tempB]);

      p.simulateIncomingForTest(_msg('real-B', 'world'));

      final contents = p.messages.map((m) => m.content).toList();
      expect(contents, contains('hello'),
          reason: 'tempA should survive when tempB is confirmed');
      expect(contents, contains('world'));
      expect(p.messages.any((m) => m.id == tempB.id), isFalse,
          reason: 'matching temp should be removed');
    });

    test('no temps in list — incoming message is simply appended', () {
      final p = _provider();
      p.setMessagesForTest([_msg('real-old', 'old message')]);
      p.simulateIncomingForTest(_msg('real-new', 'new message'));
      expect(p.messages.length, 2);
      expect(p.messages.last.content, 'new message');
    });
  });

  // ── Dedup guard ───────────────────────────────────────────────────────────

  group('simulateIncomingForTest — dedup', () {
    // If the same message ID arrives twice (e.g. once via pagination and once
    // via Realtime), it must not be added twice.

    test('same ID is not duplicated', () {
      final p = _provider();
      p.simulateIncomingForTest(_msg('real-1', 'hello'));
      p.simulateIncomingForTest(_msg('real-1', 'hello')); // duplicate
      expect(p.messages.length, 1);
    });

    test('same ID already loaded from pagination is not re-added', () {
      final p = _provider();
      // Simulate _fetchPage having already loaded this message.
      p.setMessagesForTest([_msg('real-1', 'from pagination')]);
      // Realtime INSERT fires for the same message.
      p.simulateIncomingForTest(_msg('real-1', 'from pagination'));
      expect(p.messages.length, 1);
    });

    test('different IDs are both kept even if content matches', () {
      // Two users sending the exact same text should produce two messages.
      final p = _provider();
      p.simulateIncomingForTest(_msg('real-1', 'same text'));
      p.simulateIncomingForTest(_msg('real-2', 'same text'));
      expect(p.messages.length, 2);
    });
  });

  // ── messages getter ────────────────────────────────────────────────────────

  group('EventChatProvider.messages', () {
    test('initial messages list is empty', () {
      expect(_provider().messages, isEmpty);
    });

    test('messages list is unmodifiable', () {
      final p = _provider();
      p.simulateIncomingForTest(_msg('r1', 'hi'));
      expect(
        () => (p.messages as List).add(_msg('r2', 'x')),
        throwsUnsupportedError,
      );
    });
  });
}
