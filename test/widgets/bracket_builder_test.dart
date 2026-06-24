import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trip_management/models/tournament.dart';
import 'package:trip_management/providers/event_provider.dart';
import 'package:trip_management/widgets/tournament/bracket_builder_screen.dart';

// Fake provider that captures createDivisionBundle calls without Supabase.
class _FakeEventProvider extends EventProvider {
  List<BracketSegmentConfig>? capturedSegments;

  @override
  Future<List<TournamentDivision>> createDivisionBundle({
    required String eventId,
    required List<BracketSegmentConfig> segments,
    required String sport,
    required Discipline discipline,
    required String skillLevel,
    EntrantKind entrantKind = EntrantKind.individual,
  }) async {
    capturedSegments = segments;
    return [];
  }

  @override
  List<TournamentTemplate> get templates => [];

  @override
  Future<void> fetchTemplates() async {}
}

// Use a narrow, tall viewport so the simpler vertical layout is exercised
// and all content (banner + pool + 2 lanes) fits without scrolling.
Widget _wrapBuilder(String eventId, _FakeEventProvider provider) {
  return ChangeNotifierProvider<EventProvider>.value(
    value: provider,
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(500, 2400)),
        child: BracketBuilderScreen(eventId: eventId),
      ),
    ),
  );
}

void main() {
  group('BracketBuilderScreen', () {
    testWidgets('renders AppBar title and Generate All button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      await tester.pumpWidget(_wrapBuilder('event-1', _FakeEventProvider()));
      await tester.pumpAndSettle();
      expect(find.text('Build Structure'), findsOneWidget);
      expect(find.text('Generate All'), findsOneWidget);
    });

    testWidgets('renders two default lane cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      await tester.pumpWidget(_wrapBuilder('event-1', _FakeEventProvider()));
      await tester.pumpAndSettle();
      // Each lane card has a delete icon button — 2 lanes → 2 delete buttons.
      expect(
        find.byIcon(Icons.delete_outline),
        findsNWidgets(2),
      );
    });

    testWidgets('Add to pool button adds a chip to the pool', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      await tester.pumpWidget(_wrapBuilder('event-1', _FakeEventProvider()));
      await tester.pumpAndSettle();
      // Find the first TextField (name input in the pool panel).
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Team Alpha');
      await tester.tap(find.text('Add to pool'));
      await tester.pumpAndSettle();
      // Chip text appears.
      expect(find.text('Team Alpha'), findsOneWidget);
    });

    testWidgets(
        'Generate All shows validation error when lanes have <2 entrants',
        (tester) async {
      final provider = _FakeEventProvider();
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      await tester.pumpWidget(_wrapBuilder('event-1', provider));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate All'));
      await tester.pumpAndSettle();
      expect(find.textContaining('needs at least 2'), findsOneWidget);
      expect(provider.capturedSegments, isNull);
    });

    testWidgets('Add Division Lane button adds a third lane card', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      await tester.pumpWidget(_wrapBuilder('event-1', _FakeEventProvider()));
      await tester.pumpAndSettle();
      // Initially 2 delete buttons (2 lanes).
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
      await tester.tap(find.text('Add Division Lane'));
      await tester.pumpAndSettle();
      // Now 3 delete buttons (3 lanes).
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(3));
    });
  });
}
