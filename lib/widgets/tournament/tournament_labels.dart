import 'package:flutter/material.dart';

import '../../models/tournament.dart';

// Human-readable display helpers for tournament enums. Hardcoded English to
// match the existing signup/quick-bites tab convention.

/// Icon for a free-form sport label (best-effort; falls back to a trophy).
IconData sportIcon(String sport) {
  final s = sport.trim().toLowerCase();
  if (s.contains('badminton') || s.contains('tennis') || s.contains('pickle') ||
      s.contains('squash') || s.contains('paddle')) {
    return Icons.sports_tennis_rounded;
  }
  if (s.contains('soccer') || s.contains('football')) {
    return Icons.sports_soccer_rounded;
  }
  if (s.contains('basket')) return Icons.sports_basketball_rounded;
  if (s.contains('volley')) return Icons.sports_volleyball_rounded;
  if (s.contains('table')) return Icons.sports_tennis_outlined;
  return Icons.emoji_events_rounded;
}

extension DisciplineDisplay on Discipline {
  String get label => switch (this) {
        Discipline.singles => 'Singles',
        Discipline.doubles => 'Doubles',
        Discipline.mixed => 'Mixed Doubles',
      };
}

extension DivisionFormatDisplay on DivisionFormat {
  String get label => switch (this) {
        DivisionFormat.roundRobin => 'Round Robin',
        DivisionFormat.singleElimination => 'Single Elimination',
        DivisionFormat.poolsPlayoff => 'Pools → Playoffs',
        DivisionFormat.custom => 'Custom (manual)',
      };
}

extension CourtStatusDisplay on CourtStatus {
  String get label => switch (this) {
        CourtStatus.available => 'Available',
        CourtStatus.inUse => 'In use',
        CourtStatus.closed => 'Closed',
      };
}

extension MatchStatusDisplay on MatchStatus {
  String get label => switch (this) {
        MatchStatus.pending => 'Pending',
        MatchStatus.scheduled => 'Scheduled',
        MatchStatus.inProgress => 'In progress',
        MatchStatus.completed => 'Completed',
        MatchStatus.bye => 'Bye',
        MatchStatus.walkover => 'Walkover',
      };
}
