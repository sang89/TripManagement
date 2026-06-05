import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/event_poll.dart';

void main() {
  const pollId = 'poll-1';
  const eventId = 'event-1';
  const createdBy = 'user-1';
  const createdAt = '2026-06-04T10:00:00Z';

  final baseOption = {
    'id': 'opt-1',
    'poll_id': pollId,
    'text': 'Option A',
    'sort_order': 0,
  };

  final baseVote = {
    'id': 'vote-1',
    'poll_id': pollId,
    'option_id': 'opt-1',
    'user_id': 'user-2',
    'created_at': createdAt,
  };

  group('EventPollOption', () {
    test('fromJson parses all fields', () {
      final option = EventPollOption.fromJson(baseOption);
      expect(option.id, 'opt-1');
      expect(option.pollId, pollId);
      expect(option.text, 'Option A');
      expect(option.sortOrder, 0);
    });

    test('fromJson defaults sortOrder to 0 when absent', () {
      final json = Map<String, dynamic>.from(baseOption)..remove('sort_order');
      final option = EventPollOption.fromJson(json);
      expect(option.sortOrder, 0);
    });
  });

  group('EventPollVote', () {
    test('fromJson parses all fields', () {
      final vote = EventPollVote.fromJson(baseVote);
      expect(vote.id, 'vote-1');
      expect(vote.pollId, pollId);
      expect(vote.optionId, 'opt-1');
      expect(vote.userId, 'user-2');
      expect(vote.createdAt, DateTime.parse(createdAt));
    });
  });

  group('EventPoll', () {
    Map<String, dynamic> buildPollJson({
      List<Map<String, dynamic>>? options,
      List<Map<String, dynamic>>? votes,
    }) =>
        {
          'id': pollId,
          'event_id': eventId,
          'question': 'Where should we eat?',
          'created_by': createdBy,
          'created_at': createdAt,
          'event_poll_options': options ?? [],
          'event_poll_votes': votes ?? [],
        };

    test('fromJson parses all fields with no options or votes', () {
      final poll = EventPoll.fromJson(buildPollJson());
      expect(poll.id, pollId);
      expect(poll.eventId, eventId);
      expect(poll.question, 'Where should we eat?');
      expect(poll.createdBy, createdBy);
      expect(poll.options, isEmpty);
      expect(poll.votes, isEmpty);
    });

    test('fromJson parses nested options sorted by sortOrder', () {
      final options = [
        {'id': 'opt-2', 'poll_id': pollId, 'text': 'B', 'sort_order': 1},
        {'id': 'opt-1', 'poll_id': pollId, 'text': 'A', 'sort_order': 0},
      ];
      final poll = EventPoll.fromJson(buildPollJson(options: options));
      expect(poll.options.length, 2);
      expect(poll.options[0].text, 'A');
      expect(poll.options[1].text, 'B');
    });

    test('fromJson parses nested votes', () {
      final poll = EventPoll.fromJson(
          buildPollJson(options: [baseOption], votes: [baseVote]));
      expect(poll.votes.length, 1);
      expect(poll.votes.first.userId, 'user-2');
    });

    test('totalVotes returns count of all votes', () {
      final votes = [
        baseVote,
        {
          'id': 'vote-2',
          'poll_id': pollId,
          'option_id': 'opt-1',
          'user_id': 'user-3',
          'created_at': createdAt,
        },
      ];
      final poll = EventPoll.fromJson(buildPollJson(votes: votes));
      expect(poll.totalVotes, 2);
    });

    test('votesFor counts votes for a specific option', () {
      final votes = [
        baseVote,
        {
          'id': 'vote-2',
          'poll_id': pollId,
          'option_id': 'opt-2',
          'user_id': 'user-3',
          'created_at': createdAt,
        },
      ];
      final poll = EventPoll.fromJson(buildPollJson(votes: votes));
      expect(poll.votesFor('opt-1'), 1);
      expect(poll.votesFor('opt-2'), 1);
      expect(poll.votesFor('opt-3'), 0);
    });

    test('myVoteOptionId returns optionId for given user', () {
      final poll =
          EventPoll.fromJson(buildPollJson(votes: [baseVote]));
      expect(poll.myVoteOptionId('user-2'), 'opt-1');
      expect(poll.myVoteOptionId('user-99'), isNull);
    });

    test('myVoteId returns vote id for given user', () {
      final poll =
          EventPoll.fromJson(buildPollJson(votes: [baseVote]));
      expect(poll.myVoteId('user-2'), 'vote-1');
      expect(poll.myVoteId('user-99'), isNull);
    });
  });
}
