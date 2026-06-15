// Regression tests that guard against cross-app notification contamination.
//
// Root cause (June 2026): TripManagement wrote to the shared `notifications`
// table. PropertyManagement reads that table without a type filter, so every
// TM notification appeared in the PM notification centre.
//
// Fix: TM now exclusively uses `trip_notifications`. PM exclusively uses
// `notifications`. They must NEVER cross.
//
// HOW TO READ A FAILURE HERE
//   If any test below fails, stop. Do NOT ship. Fix the isolation first.
//   The failure message explains exactly what was found and what rule it breaks.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/providers/notifications_provider.dart';

void main() {
  // ── Source-level guard ─────────────────────────────────────────────────────
  //
  // These tests read actual source files. They catch regressions that slip
  // past the model-layer tests — e.g. a developer copy-pastes an old query
  // that targets the shared table.

  group('Source scanner — no shared notifications table in lib/', () {
    late List<File> dartFiles;

    setUpAll(() {
      dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    });

    test('no lib/ file queries the shared notifications table', () {
      // .from('notifications') or .from("notifications") targets the PM table.
      // TripManagement must always use trip_notifications.
      final violations = <String>[];
      for (final file in dartFiles) {
        final src = file.readAsStringSync();
        if (src.contains(".from('notifications')") ||
            src.contains('.from("notifications")')) {
          violations.add(file.path);
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'These files query the shared `notifications` table, which belongs '
            'to PropertyManagement. Use `trip_notifications` instead:\n'
            '  ${violations.join('\n  ')}',
      );
    });

    test('Realtime channel prefix matches the DB broadcast trigger topic', () {
      // The DB trigger publishes to:
      //   realtime:trip_notifications_{user_id}
      // The provider must subscribe to the same channel name (Supabase
      // prepends "realtime:" automatically, so the Dart string is
      // trip_notifications_{user_id}).
      //
      // If these drift, Realtime push works on the DB side but the client
      // never receives it, causing stale bell counts.
      final providerSrc = File('lib/providers/notifications_provider.dart')
          .readAsStringSync();

      expect(
        providerSrc.contains("'trip_notifications_\$_userId'"),
        isTrue,
        reason:
            "NotificationsProvider._subscribe() must use the channel name "
            "'trip_notifications_\$_userId' to match the DB trigger topic. "
            "Check broadcast_trip_notification() in the migration.",
      );
    });
  });

  // ── Migration guard ────────────────────────────────────────────────────────
  //
  // Verifies that the isolation migration is present and intact. If someone
  // deletes or reverts it, these tests fail loudly before any DB push.

  group('Migration guard — trip_notifications isolation', () {
    late List<File> sqlFiles;

    setUpAll(() {
      sqlFiles = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .toList();
    });

    test('a migration creates the trip_notifications table', () {
      final found = sqlFiles.any((f) =>
          f.readAsStringSync().contains('CREATE TABLE public.trip_notifications'));
      expect(
        found,
        isTrue,
        reason:
            'No migration found that creates trip_notifications. The table '
            'isolation fix may have been reverted. Check supabase/migrations/.',
      );
    });

    test('a migration drops the old broadcast trigger from notifications', () {
      // on_notification_inserted was TM's trigger on the shared table.
      // It must be dropped so TM stops broadcasting from the PM table.
      final found = sqlFiles.any((f) => f
          .readAsStringSync()
          .contains('DROP TRIGGER IF EXISTS on_notification_inserted ON public.notifications'));
      expect(
        found,
        isTrue,
        reason:
            'No migration drops on_notification_inserted from public.notifications. '
            'TripManagement may still be broadcasting via the shared PM table.',
      );
    });

    test('a migration migrates existing TM rows out of the shared table', () {
      final found = sqlFiles.any((f) =>
          f.readAsStringSync().contains('INSERT INTO public.trip_notifications'));
      expect(
        found,
        isTrue,
        reason:
            'No migration moves existing TM rows into trip_notifications. '
            'Historical notifications would remain in the PM table.',
      );
    });
  });

  // ── Type classification completeness ───────────────────────────────────────
  //
  // Every notification type that exists in either app must be explicitly
  // classified as TM or PM. An unclassified type is a silent contamination
  // risk — it could end up in the wrong table or get filtered out entirely.

  group('Type classification completeness', () {
    // Update this set whenever a new notification type is added to either app.
    // Do NOT remove types — comment them out with a note if deprecated so
    // future developers know the history.
    const allKnownTypes = {
      // ── TripManagement ────────────────────────────────────────────────────
      'event_invite',
      'event_invite_accepted',
      'event_invite_declined',
      'event_kicked',
      'session_join_request',
      'session_approved',
      'session_rejected',
      'session_demoted',
      'session_promoted',
      'session_removed',
      'friend_request',
      'friend_accepted',
      'system',
      // ── PropertyManagement ────────────────────────────────────────────────
      'lease_expiry',
      'monthly_summary',
      'rent_reminder',
      'maintenance_update',
      'payment_received',
    };

    test('every known type is classified as TM or PM', () {
      final classified = {
        ...NotificationsProvider.tripTypes,
        ...NotificationsProvider.propertyManagementTypes,
      };
      final unclassified = allKnownTypes.difference(classified);
      expect(
        unclassified,
        isEmpty,
        reason:
            'These types are in allKnownTypes but missing from tripTypes and '
            'propertyManagementTypes: $unclassified. '
            'Add them to the correct list in NotificationsProvider.',
      );
    });

    test('no type in tripTypes or propertyManagementTypes is unknown', () {
      // Catches a type being added to the provider lists without updating
      // allKnownTypes here — keeps this file and the provider in sync.
      final classified = {
        ...NotificationsProvider.tripTypes,
        ...NotificationsProvider.propertyManagementTypes,
      };
      final unknown = classified.difference(allKnownTypes);
      expect(
        unknown,
        isEmpty,
        reason:
            'These types are in the provider lists but not in allKnownTypes '
            'in this test: $unknown. '
            "Add them to allKnownTypes so they're reviewed and classified.",
      );
    });

    test('tripTypes has no duplicates', () {
      final list = NotificationsProvider.tripTypes;
      final unique = list.toSet();
      expect(list.length, unique.length,
          reason: 'Duplicate entries in tripTypes: $list');
    });

    test('propertyManagementTypes has no duplicates', () {
      final list = NotificationsProvider.propertyManagementTypes;
      final unique = list.toSet();
      expect(list.length, unique.length,
          reason: 'Duplicate entries in propertyManagementTypes: $list');
    });
  });
}
