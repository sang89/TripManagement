// Tournament event-type models.
//
// A tournament Event contains multiple TournamentDivisions (draws), each with
// its own format + scoring config. Entrants (teams of 1 for singles, 2 for
// doubles/mixed) register into a division. Once registration closes the
// organizer generates a bracket of TournamentMatches (each with nested
// MatchGames). Courts are a shared resource across the event.
//
// Conventions mirror event_session.dart: final fields, named const ctor,
// fromJson with snake_case + `?? default`, denormalized int counts maintained
// by DB triggers, and narrow copyWith helpers with explicit clearX flags for
// tristate nullable fields (per the project copyWith invariant).

// ── Enums & free-form fields ───────────────────────────────────────────────
//
// `sport` and `skillLevel` are free-form strings so organizers can run any
// sport ("Tennis", "Squash", "Table Tennis") and any rating scheme ("A".."E",
// "DUPR 3.5", "Open", "Beginner"). Only `discipline` (team size) and `format`
// (bracket algorithm) stay constrained — the engine depends on them.

/// Well-known sports that ship with scoring presets. Free-form sport labels are
/// allowed too; these are just quick-pick convenience values.
const kSportPresets = ['Badminton', 'Pickleball'];

/// Common skill-level quick-picks (organizers can type anything instead).
const kSkillPresets = ['A', 'B', 'C', 'D', 'E', 'Open', '3.0', '3.5', '4.0'];

enum Discipline {
  singles,
  doubles,
  mixed;

  static Discipline fromString(String? s) => switch (s) {
        'doubles' => Discipline.doubles,
        'mixed' => Discipline.mixed,
        _ => Discipline.singles,
      };

  String get dbValue => name;

  /// Players per entrant for this discipline.
  int get teamSize => this == Discipline.singles ? 1 : 2;
}

/// Whether a division's entrants are individuals (1–2 players) or teams (a
/// ranked roster of N players that play "ties").
enum EntrantKind {
  individual,
  team;

  static EntrantKind fromString(String? s) =>
      s == 'team' ? EntrantKind.team : EntrantKind.individual;

  String get dbValue => name;
}

enum DivisionFormat {
  roundRobin,
  singleElimination,
  poolsPlayoff,
  custom; // manual builder — organizer hand-creates rounds/matches

  static DivisionFormat fromString(String? s) => switch (s) {
        'single_elimination' => DivisionFormat.singleElimination,
        'pools_playoff' => DivisionFormat.poolsPlayoff,
        'custom' => DivisionFormat.custom,
        _ => DivisionFormat.roundRobin,
      };

  String get dbValue => switch (this) {
        DivisionFormat.roundRobin => 'round_robin',
        DivisionFormat.singleElimination => 'single_elimination',
        DivisionFormat.poolsPlayoff => 'pools_playoff',
        DivisionFormat.custom => 'custom',
      };
}

/// How a tie's sub-matches pair the two teams' rostered players.
enum PairingRule {
  sameRank, // rank i vs rank i
  manual; // organizer assigns each sub-match's two players

  static PairingRule fromString(String? s) =>
      s == 'manual' ? PairingRule.manual : PairingRule.sameRank;

  String get dbValue => switch (this) {
        PairingRule.sameRank => 'same_rank',
        PairingRule.manual => 'manual',
      };
}

/// Configuration for team ties (stored as JSONB on the division).
class TieConfig {
  final int submatchCount; // sub-matches per tie
  final PairingRule pairingRule;
  final int winThreshold; // sub-match wins needed to take the tie

  const TieConfig({
    this.submatchCount = 3,
    this.pairingRule = PairingRule.sameRank,
    this.winThreshold = 2,
  });

  factory TieConfig.fromJson(Map<String, dynamic> json) => TieConfig(
        submatchCount: json['submatch_count'] as int? ?? 3,
        pairingRule: PairingRule.fromString(json['pairing_rule'] as String?),
        winThreshold: json['win_threshold'] as int? ?? 2,
      );

  Map<String, dynamic> toJson() => {
        'submatch_count': submatchCount,
        'pairing_rule': pairingRule.dbValue,
        'win_threshold': winThreshold,
      };

  TieConfig copyWith({
    int? submatchCount,
    PairingRule? pairingRule,
    int? winThreshold,
  }) =>
      TieConfig(
        submatchCount: submatchCount ?? this.submatchCount,
        pairingRule: pairingRule ?? this.pairingRule,
        winThreshold: winThreshold ?? this.winThreshold,
      );
}

enum ScoringSystem {
  rally,
  sideOut;

  static ScoringSystem fromString(String? s) => switch (s) {
        'side_out' => ScoringSystem.sideOut,
        _ => ScoringSystem.rally,
      };

  String get dbValue => switch (this) {
        ScoringSystem.rally => 'rally',
        ScoringSystem.sideOut => 'side_out',
      };
}

enum DivisionStatus {
  setup,
  registration,
  seeded,
  inProgress,
  completed;

  static DivisionStatus fromString(String? s) => switch (s) {
        'registration' => DivisionStatus.registration,
        'seeded' => DivisionStatus.seeded,
        'in_progress' => DivisionStatus.inProgress,
        'completed' => DivisionStatus.completed,
        _ => DivisionStatus.setup,
      };

  String get dbValue => switch (this) {
        DivisionStatus.setup => 'setup',
        DivisionStatus.registration => 'registration',
        DivisionStatus.seeded => 'seeded',
        DivisionStatus.inProgress => 'in_progress',
        DivisionStatus.completed => 'completed',
      };
}

enum EntrantStatus {
  registered,
  checkedIn,
  withdrawn;

  static EntrantStatus fromString(String? s) => switch (s) {
        'checked_in' => EntrantStatus.checkedIn,
        'withdrawn' => EntrantStatus.withdrawn,
        _ => EntrantStatus.registered,
      };

  String get dbValue => switch (this) {
        EntrantStatus.registered => 'registered',
        EntrantStatus.checkedIn => 'checked_in',
        EntrantStatus.withdrawn => 'withdrawn',
      };
}

enum MatchStatus {
  pending,
  scheduled,
  inProgress,
  completed,
  bye,
  walkover;

  static MatchStatus fromString(String? s) => switch (s) {
        'scheduled' => MatchStatus.scheduled,
        'in_progress' => MatchStatus.inProgress,
        'completed' => MatchStatus.completed,
        'bye' => MatchStatus.bye,
        'walkover' => MatchStatus.walkover,
        _ => MatchStatus.pending,
      };

  String get dbValue => switch (this) {
        MatchStatus.pending => 'pending',
        MatchStatus.scheduled => 'scheduled',
        MatchStatus.inProgress => 'in_progress',
        MatchStatus.completed => 'completed',
        MatchStatus.bye => 'bye',
        MatchStatus.walkover => 'walkover',
      };
}

enum BracketType {
  pool,
  winners;

  static BracketType fromString(String? s) => switch (s) {
        'pool' => BracketType.pool,
        _ => BracketType.winners,
      };

  String get dbValue => name;
}

enum CourtStatus {
  available,
  inUse,
  closed;

  static CourtStatus fromString(String? s) => switch (s) {
        'in_use' => CourtStatus.inUse,
        'closed' => CourtStatus.closed,
        _ => CourtStatus.available,
      };

  String get dbValue => switch (this) {
        CourtStatus.available => 'available',
        CourtStatus.inUse => 'in_use',
        CourtStatus.closed => 'closed',
      };
}

// ── ScoringConfig ───────────────────────────────────────────────────────────

/// Sport-agnostic scoring rules for a division. Stored as JSONB on
/// tournament_divisions.scoring_config so future sports plug in without schema
/// changes.
class ScoringConfig {
  final String sport; // free-form label, e.g. "Badminton", "Tennis"
  final ScoringSystem system; // rally or side-out
  final int pointsToWin; // 21 badminton; 11/15/21 pickleball
  final bool winByTwo;
  final int? cap; // badminton 30; null = uncapped
  final int bestOf; // games to play (1, 3, 5); win = (bestOf ~/ 2) + 1
  final Map<String, dynamic>? extra; // forward-compat (e.g. soccer halves)

  const ScoringConfig({
    required this.sport,
    required this.system,
    required this.pointsToWin,
    this.winByTwo = true,
    this.cap,
    this.bestOf = 3,
    this.extra,
  });

  /// Games one side must win to take the match.
  int get gamesToWin => (bestOf ~/ 2) + 1;

  factory ScoringConfig.fromJson(Map<String, dynamic> json) => ScoringConfig(
        sport: json['sport'] as String? ?? 'Custom',
        system: ScoringSystem.fromString(json['system'] as String?),
        pointsToWin: json['points_to_win'] as int? ?? 21,
        winByTwo: json['win_by_two'] as bool? ?? true,
        cap: json['cap'] as int?,
        bestOf: json['best_of'] as int? ?? 3,
        extra: (json['extra'] as Map?)?.cast<String, dynamic>(),
      );

  Map<String, dynamic> toJson() => {
        'sport': sport,
        'system': system.dbValue,
        'points_to_win': pointsToWin,
        'win_by_two': winByTwo,
        if (cap != null) 'cap': cap,
        'best_of': bestOf,
        if (extra != null) 'extra': extra,
      };

  /// Sensible scoring defaults for a (possibly free-form) sport label. Known
  /// sports get their real rules; anything else gets a generic rally-to-21.
  factory ScoringConfig.defaultFor(String sport) {
    switch (sport.trim().toLowerCase()) {
      case 'badminton':
        return const ScoringConfig(
          sport: 'Badminton',
          system: ScoringSystem.rally,
          pointsToWin: 21,
          winByTwo: true,
          cap: 30,
          bestOf: 3,
        );
      case 'pickleball':
        return const ScoringConfig(
          sport: 'Pickleball',
          system: ScoringSystem.sideOut,
          pointsToWin: 11,
          winByTwo: true,
          cap: null,
          bestOf: 3,
        );
      default:
        return ScoringConfig(
          sport: sport.trim().isEmpty ? 'Custom' : sport.trim(),
          system: ScoringSystem.rally,
          pointsToWin: 21,
          winByTwo: true,
          cap: null,
          bestOf: 3,
        );
    }
  }

  ScoringConfig copyWith({
    String? sport,
    ScoringSystem? system,
    int? pointsToWin,
    bool? winByTwo,
    int? cap,
    bool clearCap = false,
    int? bestOf,
  }) =>
      ScoringConfig(
        sport: sport ?? this.sport,
        system: system ?? this.system,
        pointsToWin: pointsToWin ?? this.pointsToWin,
        winByTwo: winByTwo ?? this.winByTwo,
        cap: clearCap ? null : (cap ?? this.cap),
        bestOf: bestOf ?? this.bestOf,
        extra: extra,
      );
}

// ── TournamentDivision ──────────────────────────────────────────────────────

class TournamentDivision {
  final String id;
  final String eventId;
  final String name;
  final String sport; // free-form label
  final Discipline discipline;
  final String skillLevel; // free-form, e.g. "B" or "DUPR 3.5"
  final DivisionFormat format;
  final ScoringConfig scoringConfig;
  final int teamSize;
  final EntrantKind entrantKind;
  final int? rosterSize; // team kind: target players per team
  final TieConfig? tieConfig; // team kind: how ties are played
  final int? entrantCap;
  final int? poolCount; // only for poolsPlayoff
  final int? advancePerPool; // only for poolsPlayoff
  final DivisionStatus status;
  final DateTime? bracketGeneratedAt; // null until bracket built
  // Denormalized by DB triggers.
  final int entrantCount;
  final int matchCount;
  final int completedMatchCount;
  final DateTime createdAt;

  const TournamentDivision({
    required this.id,
    required this.eventId,
    required this.name,
    required this.sport,
    required this.discipline,
    required this.skillLevel,
    required this.format,
    required this.scoringConfig,
    required this.teamSize,
    this.entrantKind = EntrantKind.individual,
    this.rosterSize,
    this.tieConfig,
    this.entrantCap,
    this.poolCount,
    this.advancePerPool,
    this.status = DivisionStatus.setup,
    this.bracketGeneratedAt,
    this.entrantCount = 0,
    this.matchCount = 0,
    this.completedMatchCount = 0,
    required this.createdAt,
  });

  factory TournamentDivision.fromJson(Map<String, dynamic> json) =>
      TournamentDivision(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        name: json['name'] as String? ?? '',
        sport: json['sport'] as String? ?? '',
        discipline: Discipline.fromString(json['discipline'] as String?),
        skillLevel: json['skill_level'] as String? ?? '',
        format: DivisionFormat.fromString(json['format'] as String?),
        scoringConfig: ScoringConfig.fromJson(
            (json['scoring_config'] as Map?)?.cast<String, dynamic>() ?? const {}),
        teamSize: json['team_size'] as int? ?? 1,
        entrantKind: EntrantKind.fromString(json['entrant_kind'] as String?),
        rosterSize: json['roster_size'] as int?,
        tieConfig: json['tie_config'] != null
            ? TieConfig.fromJson(
                (json['tie_config'] as Map).cast<String, dynamic>())
            : null,
        entrantCap: json['entrant_cap'] as int?,
        poolCount: json['pool_count'] as int?,
        advancePerPool: json['advance_per_pool'] as int?,
        status: DivisionStatus.fromString(json['status'] as String?),
        bracketGeneratedAt: json['bracket_generated_at'] != null
            ? DateTime.parse(json['bracket_generated_at'] as String)
            : null,
        entrantCount: json['entrant_count'] as int? ?? 0,
        matchCount: json['match_count'] as int? ?? 0,
        completedMatchCount: json['completed_match_count'] as int? ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  bool get bracketGenerated => bracketGeneratedAt != null;
  bool get registrationOpen =>
      bracketGeneratedAt == null && status != DivisionStatus.completed;
  bool get isPoolsPlayoff => format == DivisionFormat.poolsPlayoff;

  TournamentDivision copyWithCounts({
    int? entrantCount,
    int? matchCount,
    int? completedMatchCount,
  }) =>
      TournamentDivision(
        id: id,
        eventId: eventId,
        name: name,
        sport: sport,
        discipline: discipline,
        skillLevel: skillLevel,
        format: format,
        scoringConfig: scoringConfig,
        teamSize: teamSize,
        entrantKind: entrantKind,
        rosterSize: rosterSize,
        tieConfig: tieConfig,
        entrantCap: entrantCap,
        poolCount: poolCount,
        advancePerPool: advancePerPool,
        status: status,
        bracketGeneratedAt: bracketGeneratedAt,
        entrantCount: entrantCount ?? this.entrantCount,
        matchCount: matchCount ?? this.matchCount,
        completedMatchCount: completedMatchCount ?? this.completedMatchCount,
        createdAt: createdAt,
      );

  TournamentDivision copyWith({
    String? name,
    ScoringConfig? scoringConfig,
    int? entrantCap,
    bool clearEntrantCap = false,
    int? poolCount,
    int? advancePerPool,
    DivisionStatus? status,
    DateTime? bracketGeneratedAt,
    bool clearBracketGeneratedAt = false,
  }) =>
      TournamentDivision(
        id: id,
        eventId: eventId,
        name: name ?? this.name,
        sport: sport,
        discipline: discipline,
        skillLevel: skillLevel,
        format: format,
        scoringConfig: scoringConfig ?? this.scoringConfig,
        teamSize: teamSize,
        entrantKind: entrantKind,
        rosterSize: rosterSize,
        tieConfig: tieConfig,
        entrantCap: clearEntrantCap ? null : (entrantCap ?? this.entrantCap),
        poolCount: poolCount ?? this.poolCount,
        advancePerPool: advancePerPool ?? this.advancePerPool,
        status: status ?? this.status,
        bracketGeneratedAt: clearBracketGeneratedAt
            ? null
            : (bracketGeneratedAt ?? this.bracketGeneratedAt),
        entrantCount: entrantCount,
        matchCount: matchCount,
        completedMatchCount: completedMatchCount,
        createdAt: createdAt,
      );
}

// ── TournamentEntrant ───────────────────────────────────────────────────────

class TournamentEntrant {
  final String id;
  final String divisionId;
  final String teamName;
  final String? player1UserId;
  final String player1Name;
  final String? player2UserId;
  final String? player2Name; // null for singles
  final int? seed; // assigned at bracket generation
  final String? poolId; // pool label for pools format
  final EntrantStatus status;
  final DateTime registeredAt;
  // Team-kind divisions: the ranked roster (empty for individual entrants).
  final List<EntrantPlayer> players;

  const TournamentEntrant({
    required this.id,
    required this.divisionId,
    required this.teamName,
    this.player1UserId,
    required this.player1Name,
    this.player2UserId,
    this.player2Name,
    this.seed,
    this.poolId,
    this.status = EntrantStatus.registered,
    required this.registeredAt,
    this.players = const [],
  });

  factory TournamentEntrant.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['tournament_entrant_players'] as List? ??
        json['players'] as List? ??
        const [];
    final players = rawPlayers
        .map((p) => EntrantPlayer.fromJson((p as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return TournamentEntrant(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      teamName: json['team_name'] as String? ?? '',
      player1UserId: json['player1_user_id'] as String?,
      player1Name: json['player1_name'] as String? ?? '',
      player2UserId: json['player2_user_id'] as String?,
      player2Name: json['player2_name'] as String?,
      seed: json['seed'] as int?,
      poolId: json['pool_id'] as String?,
      status: EntrantStatus.fromString(json['status'] as String?),
      registeredAt: json['registered_at'] != null
          ? DateTime.parse(json['registered_at'] as String)
          : DateTime.now(),
      players: players,
    );
  }

  bool get isDoubles => player2Name != null;
  bool get isTeam => players.isNotEmpty;
  bool get isWithdrawn => status == EntrantStatus.withdrawn;

  /// All linked user ids (for schedule double-booking detection).
  List<String> get userIds => [
        player1UserId,
        player2UserId,
        ...players.map((p) => p.userId),
      ].whereType<String>().toList();

  TournamentEntrant copyWith({
    String? teamName,
    String? player1Name,
    String? player2Name,
    bool clearPlayer2 = false,
    int? seed,
    bool clearSeed = false,
    String? poolId,
    bool clearPoolId = false,
    EntrantStatus? status,
    List<EntrantPlayer>? players,
  }) =>
      TournamentEntrant(
        id: id,
        divisionId: divisionId,
        teamName: teamName ?? this.teamName,
        player1UserId: player1UserId,
        player1Name: player1Name ?? this.player1Name,
        player2UserId: clearPlayer2 ? null : player2UserId,
        player2Name: clearPlayer2 ? null : (player2Name ?? this.player2Name),
        seed: clearSeed ? null : (seed ?? this.seed),
        poolId: clearPoolId ? null : (poolId ?? this.poolId),
        status: status ?? this.status,
        registeredAt: registeredAt,
        players: players ?? this.players,
      );
}

// ── EntrantPlayer (team roster member) ───────────────────────────────────────

class EntrantPlayer {
  final String id;
  final String entrantId;
  final String? userId;
  final String name;
  final int? playerRank; // 1..N rank within the team
  final int sortOrder;

  const EntrantPlayer({
    required this.id,
    required this.entrantId,
    this.userId,
    required this.name,
    this.playerRank,
    this.sortOrder = 0,
  });

  factory EntrantPlayer.fromJson(Map<String, dynamic> json) => EntrantPlayer(
        id: json['id'] as String,
        entrantId: json['entrant_id'] as String,
        userId: json['user_id'] as String?,
        name: json['name'] as String? ?? '',
        playerRank: json['player_rank'] as int?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

// ── MatchGame ───────────────────────────────────────────────────────────────

class MatchGame {
  final String id;
  final String matchId;
  final int gameNumber;
  final int entrant1Score;
  final int entrant2Score;
  final String? winnerEntrantId;

  const MatchGame({
    required this.id,
    required this.matchId,
    required this.gameNumber,
    this.entrant1Score = 0,
    this.entrant2Score = 0,
    this.winnerEntrantId,
  });

  factory MatchGame.fromJson(Map<String, dynamic> json) => MatchGame(
        id: json['id'] as String,
        matchId: json['match_id'] as String,
        gameNumber: json['game_number'] as int? ?? 1,
        entrant1Score: json['entrant1_score'] as int? ?? 0,
        entrant2Score: json['entrant2_score'] as int? ?? 0,
        winnerEntrantId: json['winner_entrant_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'game_number': gameNumber,
        'entrant1_score': entrant1Score,
        'entrant2_score': entrant2Score,
      };
}

// ── TournamentMatch ─────────────────────────────────────────────────────────

class TournamentMatch {
  final String id;
  final String divisionId;
  final BracketType bracketType;
  final int roundNumber;
  final int matchNumber;
  final String? poolId;
  final String? entrant1Id;
  final String? entrant2Id;
  final String? winnerEntrantId;
  final String? nextMatchId; // winner advances here
  final int? nextMatchSlot; // 1 or 2
  final String? courtId;
  final MatchStatus status;
  final int? scheduledOrder; // per-court "next up" position
  final DateTime createdAt;
  final List<MatchGame> games;
  final bool isTie; // team-vs-team match made of sub-matches
  final List<TieSubmatch> submatches;

  const TournamentMatch({
    required this.id,
    required this.divisionId,
    this.bracketType = BracketType.winners,
    required this.roundNumber,
    required this.matchNumber,
    this.poolId,
    this.entrant1Id,
    this.entrant2Id,
    this.winnerEntrantId,
    this.nextMatchId,
    this.nextMatchSlot,
    this.courtId,
    this.status = MatchStatus.pending,
    this.scheduledOrder,
    required this.createdAt,
    this.games = const [],
    this.isTie = false,
    this.submatches = const [],
  });

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    final rawGames = json['tournament_match_games'] as List? ??
        json['games'] as List? ??
        const [];
    final games = rawGames
        .map((g) => MatchGame.fromJson((g as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.gameNumber.compareTo(b.gameNumber));
    final rawSubs = json['tournament_tie_submatches'] as List? ??
        json['submatches'] as List? ??
        const [];
    final submatches = rawSubs
        .map((s) => TieSubmatch.fromJson((s as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return TournamentMatch(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      bracketType: BracketType.fromString(json['bracket_type'] as String?),
      roundNumber: json['round_number'] as int? ?? 1,
      matchNumber: json['match_number'] as int? ?? 1,
      poolId: json['pool_id'] as String?,
      entrant1Id: json['entrant1_id'] as String?,
      entrant2Id: json['entrant2_id'] as String?,
      winnerEntrantId: json['winner_entrant_id'] as String?,
      nextMatchId: json['next_match_id'] as String?,
      nextMatchSlot: json['next_match_slot'] as int?,
      courtId: json['court_id'] as String?,
      status: MatchStatus.fromString(json['status'] as String?),
      scheduledOrder: json['scheduled_order'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      games: games,
      isTie: json['is_tie'] as bool? ?? false,
      submatches: submatches,
    );
  }

  bool get isBye => status == MatchStatus.bye;
  bool get isCompleted => status == MatchStatus.completed;
  bool get isReady =>
      entrant1Id != null && entrant2Id != null && !isCompleted && !isBye;

  TournamentMatch copyWith({
    String? entrant1Id,
    bool clearEntrant1 = false,
    String? entrant2Id,
    bool clearEntrant2 = false,
    String? winnerEntrantId,
    bool clearWinner = false,
    String? courtId,
    bool clearCourt = false,
    MatchStatus? status,
    int? scheduledOrder,
    bool clearScheduledOrder = false,
    List<MatchGame>? games,
    List<TieSubmatch>? submatches,
  }) =>
      TournamentMatch(
        id: id,
        divisionId: divisionId,
        bracketType: bracketType,
        roundNumber: roundNumber,
        matchNumber: matchNumber,
        poolId: poolId,
        entrant1Id: clearEntrant1 ? null : (entrant1Id ?? this.entrant1Id),
        entrant2Id: clearEntrant2 ? null : (entrant2Id ?? this.entrant2Id),
        winnerEntrantId:
            clearWinner ? null : (winnerEntrantId ?? this.winnerEntrantId),
        nextMatchId: nextMatchId,
        nextMatchSlot: nextMatchSlot,
        courtId: clearCourt ? null : (courtId ?? this.courtId),
        status: status ?? this.status,
        scheduledOrder:
            clearScheduledOrder ? null : (scheduledOrder ?? this.scheduledOrder),
        createdAt: createdAt,
        games: games ?? this.games,
        isTie: isTie,
        submatches: submatches ?? this.submatches,
      );
}

// ── TournamentTemplate (reusable division-config bundle) ─────────────────────

class TournamentTemplate {
  final String id;
  final String name;
  final Map<String, dynamic> config; // matches the create-division payload

  const TournamentTemplate({
    required this.id,
    required this.name,
    required this.config,
  });

  factory TournamentTemplate.fromJson(Map<String, dynamic> json) =>
      TournamentTemplate(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        config: (json['config'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

// ── TieSubmatch (a player-vs-player game within a team tie) ───────────────────

class TieSubmatch {
  final String id;
  final String tieMatchId;
  final int position;
  final String? side1PlayerId;
  final String? side2PlayerId;
  final List<({int side1, int side2})> games;
  final int? winnerSide; // 1 or 2
  final String status;

  const TieSubmatch({
    required this.id,
    required this.tieMatchId,
    required this.position,
    this.side1PlayerId,
    this.side2PlayerId,
    this.games = const [],
    this.winnerSide,
    this.status = 'scheduled',
  });

  factory TieSubmatch.fromJson(Map<String, dynamic> json) {
    final rawGames = (json['games'] as List?) ?? const [];
    final games = rawGames
        .map((g) {
          final m = (g as Map).cast<String, dynamic>();
          return (
            side1: (m['side1_score'] as num?)?.toInt() ?? 0,
            side2: (m['side2_score'] as num?)?.toInt() ?? 0,
          );
        })
        .toList();
    return TieSubmatch(
      id: json['id'] as String,
      tieMatchId: json['tie_match_id'] as String,
      position: json['position'] as int? ?? 1,
      side1PlayerId: json['side1_player_id'] as String?,
      side2PlayerId: json['side2_player_id'] as String?,
      games: games,
      winnerSide: json['winner_side'] as int?,
      status: json['status'] as String? ?? 'scheduled',
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isReady => side1PlayerId != null && side2PlayerId != null;
}

// ── Court ───────────────────────────────────────────────────────────────────

class Court {
  final String id;
  final String eventId;
  final String name;
  final CourtStatus status;
  final String? currentMatchId;
  final int sortOrder;

  const Court({
    required this.id,
    required this.eventId,
    required this.name,
    this.status = CourtStatus.available,
    this.currentMatchId,
    this.sortOrder = 0,
  });

  factory Court.fromJson(Map<String, dynamic> json) => Court(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        name: json['name'] as String? ?? '',
        status: CourtStatus.fromString(json['status'] as String?),
        currentMatchId: json['current_match_id'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  bool get isAvailable => status == CourtStatus.available;

  Court copyWith({
    String? name,
    CourtStatus? status,
    String? currentMatchId,
    bool clearCurrentMatch = false,
    int? sortOrder,
  }) =>
      Court(
        id: id,
        eventId: eventId,
        name: name ?? this.name,
        status: status ?? this.status,
        currentMatchId:
            clearCurrentMatch ? null : (currentMatchId ?? this.currentMatchId),
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
