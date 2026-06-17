enum QueueStatus {
  waiting,
  active,
  ended;

  static QueueStatus fromString(String s) => switch (s) {
        'active' => active,
        'ended'  => ended,
        _        => waiting,
      };

  String get dbValue => name;
}

enum QueueEntryStatus {
  playing,
  waiting;

  static QueueEntryStatus fromString(String s) =>
      s == 'playing' ? playing : waiting;
}

class SessionQueueActivity {
  final String id;
  final String eventId;
  final String sessionId;
  final String name;
  final int playersPerRound;
  final int? maxRounds;
  final int currentRound;
  final QueueStatus status;
  final int waitingCount;
  final int playingCount;
  final int sortOrder;
  final bool allowDuplicates;
  final String? createdBy;
  final DateTime createdAt;

  const SessionQueueActivity({
    required this.id,
    required this.eventId,
    required this.sessionId,
    required this.name,
    required this.playersPerRound,
    this.maxRounds,
    required this.currentRound,
    required this.status,
    this.waitingCount = 0,
    this.playingCount = 0,
    this.sortOrder = 0,
    this.allowDuplicates = false,
    this.createdBy,
    required this.createdAt,
  });

  bool get isActive  => status == QueueStatus.active;
  bool get isWaiting => status == QueueStatus.waiting;
  bool get isEnded   => status == QueueStatus.ended;

  factory SessionQueueActivity.fromJson(Map<String, dynamic> json) =>
      SessionQueueActivity(
        id:               json['id'] as String,
        eventId:          json['event_id'] as String,
        sessionId:        json['session_id'] as String? ?? '',
        name:             json['name'] as String? ?? 'Queue',
        playersPerRound:  json['players_per_round'] as int,
        maxRounds:        json['max_rounds'] as int?,
        currentRound:     json['current_round'] as int? ?? 0,
        status:           QueueStatus.fromString(json['status'] as String? ?? 'waiting'),
        waitingCount:     json['waiting_count'] as int? ?? 0,
        playingCount:     json['playing_count'] as int? ?? 0,
        sortOrder:        json['sort_order'] as int? ?? 0,
        allowDuplicates:  json['allow_duplicates'] as bool? ?? false,
        createdBy:        json['created_by'] as String?,
        createdAt:        DateTime.parse(json['created_at'] as String),
      );

  SessionQueueActivity copyWith({
    int? waitingCount,
    int? playingCount,
    int? currentRound,
    QueueStatus? status,
    int? sortOrder,
  }) =>
      SessionQueueActivity(
        id:              id,
        eventId:         eventId,
        sessionId:       sessionId,
        name:            name,
        playersPerRound: playersPerRound,
        maxRounds:       maxRounds,
        currentRound:    currentRound ?? this.currentRound,
        status:          status ?? this.status,
        waitingCount:    waitingCount ?? this.waitingCount,
        playingCount:    playingCount ?? this.playingCount,
        sortOrder:       sortOrder ?? this.sortOrder,
        allowDuplicates: allowDuplicates,
        createdBy:       createdBy,
        createdAt:       createdAt,
      );
}

class SessionQueueEntry {
  final String id;
  final String activityId;
  final String? userId;
  final String displayName;
  final String? avatarUrl;
  final QueueEntryStatus status;
  final int queuePosition;
  final int roundsPlayed;
  final DateTime joinedAt;

  const SessionQueueEntry({
    required this.id,
    required this.activityId,
    this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.status,
    required this.queuePosition,
    this.roundsPlayed = 0,
    required this.joinedAt,
  });

  bool get isPlaying => status == QueueEntryStatus.playing;
  bool get isWaiting => status == QueueEntryStatus.waiting;

  factory SessionQueueEntry.fromJson(Map<String, dynamic> json) =>
      SessionQueueEntry(
        id:            json['id'] as String,
        activityId:    json['activity_id'] as String,
        userId:        json['user_id'] as String?,
        displayName:   json['display_name'] as String? ?? '',
        avatarUrl:     json['avatar_url'] as String?,
        status:        QueueEntryStatus.fromString(json['status'] as String? ?? 'waiting'),
        queuePosition: json['queue_position'] as int? ?? 0,
        roundsPlayed:  json['rounds_played'] as int? ?? 0,
        joinedAt:      json['joined_at'] != null
            ? DateTime.parse(json['joined_at'] as String)
            : DateTime.now(),
      );

  SessionQueueEntry copyWith({QueueEntryStatus? status, int? queuePosition}) =>
      SessionQueueEntry(
        id:            id,
        activityId:    activityId,
        userId:        userId,
        displayName:   displayName,
        avatarUrl:     avatarUrl,
        status:        status ?? this.status,
        queuePosition: queuePosition ?? this.queuePosition,
        roundsPlayed:  roundsPlayed,
        joinedAt:      joinedAt,
      );
}

class SessionFreePoolEntry {
  final String id;
  final String eventId;
  final String sessionId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime checkedInAt;

  const SessionFreePoolEntry({
    required this.id,
    required this.eventId,
    required this.sessionId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.checkedInAt,
  });

  factory SessionFreePoolEntry.fromJson(Map<String, dynamic> json) =>
      SessionFreePoolEntry(
        id:          json['id'] as String,
        eventId:     json['event_id'] as String,
        sessionId:   json['session_id'] as String? ?? '',
        userId:      json['user_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        avatarUrl:   json['avatar_url'] as String?,
        checkedInAt: json['checked_in_at'] != null
            ? DateTime.parse(json['checked_in_at'] as String)
            : DateTime.now(),
      );
}
