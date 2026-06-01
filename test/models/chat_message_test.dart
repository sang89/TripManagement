import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/chat_message.dart';

void main() {
  group('ChatMessage.fromJson', () {
    final json = {
      'id': 'm1',
      'trip_id': 't1',
      'user_id': 'u1',
      'content': 'Hello!',
      'created_at': '2026-05-30T10:00:00.000Z',
    };

    test('parses all fields', () {
      final m = ChatMessage.fromJson(json);
      expect(m.id, 'm1');
      expect(m.tripId, 't1');
      expect(m.userId, 'u1');
      expect(m.content, 'Hello!');
      expect(m.createdAt, DateTime.utc(2026, 5, 30, 10));
      expect(m.senderName, isNull);
    });
  });

  group('ChatMessage.copyWith', () {
    final original = ChatMessage(
      id: 'm1',
      tripId: 't1',
      userId: 'u1',
      content: 'Hello!',
      createdAt: DateTime(2026, 5, 30),
    );

    test('enriches senderName', () {
      final enriched = original.copyWith(senderName: 'Alice');
      expect(enriched.senderName, 'Alice');
      expect(enriched.senderAvatarUrl, isNull);
    });

    test('preserves unchanged fields', () {
      final copy = original.copyWith();
      expect(copy.id, original.id);
      expect(copy.content, original.content);
    });
  });

  group('ChatMessage.toJson', () {
    final msg = ChatMessage(
      id: 'm1',
      tripId: 't1',
      userId: 'u1',
      content: 'Hello!',
      createdAt: DateTime(2026, 5, 30),
    );

    test('only includes insert fields', () {
      final j = msg.toJson();
      expect(j['trip_id'], 't1');
      expect(j['user_id'], 'u1');
      expect(j['content'], 'Hello!');
      expect(j.containsKey('id'), isFalse);
      expect(j.containsKey('created_at'), isFalse);
    });
  });
}
