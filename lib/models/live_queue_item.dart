import 'event.dart';
import 'event_session.dart';

/// One entry in the bottom-nav "Live" cycle queue — either a currently-live
/// signup session (→ Activity tab) or a whole ongoing event that has no live
/// session (→ Info tab).
class LiveQueueItem {
  final String eventId;

  /// Non-null when this item is a live signup session (vs a whole event).
  final String? sessionId;
  final String title;

  /// Used only to order the queue deterministically.
  final DateTime startAt;

  const LiveQueueItem({
    required this.eventId,
    required this.sessionId,
    required this.title,
    required this.startAt,
  });

  bool get isSession => sessionId != null;

  /// GoRouter location to jump to. A session opens the detail screen's
  /// session/Activity tab with that specific session pre-selected; a plain
  /// ongoing event opens its Info → Details tab.
  String get route => isSession
      ? '/event/$eventId?tab=session&sessionId=$sessionId'
      : '/event/$eventId';
}

/// Builds the ordered queue of what's live right now:
///   - one item per live signup **session** (→ Activity tab), and
///   - each ongoing **event** that has NO live session (→ Info tab).
/// When an event has live session(s), only the session(s) represent it — the
/// whole-event entry is dropped (the session is the more specific target).
/// **Live sessions are prioritised first** in the cycle, then other live events;
/// within each group, ordered by start time so cycling is stable.
///
/// An event is "ongoing" when it is not past and its window includes [now]:
/// `startAt <= now && (endAt == null || endAt > now)`. [liveSessions] is already
/// filtered to live sessions by `EventProvider.fetchLiveSessions`.
List<LiveQueueItem> buildLiveQueue(
  List<Event> events,
  List<EventSession> liveSessions,
  String userId,
  DateTime now,
) {
  final eventsById = {for (final e in events) e.id: e};

  // Live sessions first; track which events they cover so we can de-dupe.
  final sessionEventIds = <String>{};
  final items = <LiveQueueItem>[];
  for (final s in liveSessions) {
    sessionEventIds.add(s.eventId);
    items.add(LiveQueueItem(
      eventId: s.eventId,
      sessionId: s.id,
      title: eventsById[s.eventId]?.title ?? 'Session',
      startAt: s.startAt,
    ));
  }

  // Ongoing events not already represented by a live session → Info tab.
  for (final e in events) {
    if (sessionEventIds.contains(e.id)) continue;
    final isOngoing = !e.isPastFor(userId) &&
        e.startAt.isBefore(now) &&
        (e.endAt == null || e.endAt!.isAfter(now));
    if (!isOngoing) continue;
    items.add(LiveQueueItem(
      eventId: e.id,
      sessionId: null,
      title: e.title,
      startAt: e.startAt,
    ));
  }

  // Sessions (Activity) before plain events (Info); then by start time.
  items.sort((a, b) {
    if (a.isSession != b.isSession) return a.isSession ? -1 : 1;
    return a.startAt.compareTo(b.startAt);
  });
  return items;
}
