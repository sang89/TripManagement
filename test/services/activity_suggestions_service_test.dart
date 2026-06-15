import 'package:flutter_test/flutter_test.dart';
import 'package:trip_management/models/activity_suggestion.dart';
import 'package:trip_management/services/activity_suggestions_service.dart';

void main() {
  group('ActivitySuggestionsService', () {
    test('gygBrowseUrl encodes destination and includes partner_id', () {
      final url = ActivitySuggestionsService.gygBrowseUrl('Paris, France');
      expect(url.host, 'www.getyourguide.com');
      expect(url.queryParameters['q'], 'Paris, France');
      expect(url.queryParameters.containsKey('partner_id'), isTrue);
    });

    test('klookBrowseUrl encodes destination and includes aid', () {
      final url = ActivitySuggestionsService.klookBrowseUrl('Tokyo');
      expect(url.host, 'www.klook.com');
      expect(url.queryParameters['keyword'], 'Tokyo');
      expect(url.queryParameters.containsKey('aid'), isTrue);
    });

    test('gygBrowseUrl handles special characters in destination', () {
      final url = ActivitySuggestionsService.gygBrowseUrl('New York & Beyond');
      expect(url.queryParameters['q'], 'New York & Beyond');
    });

    test('searchViator returns empty result for empty destination', () async {
      final svc = ActivitySuggestionsService();
      final result = await svc.searchViator('');
      expect(result.items, isEmpty);
      expect(result.totalCount, 0);
    });

    group('_searchQuery destination extraction', () {
      test('strips street address prefix containing digits', () {
        final q = ActivitySuggestionsService.searchQueryForTest(
            '706 South Broadview Street, Anaheim, CA, USA');
        expect(q, 'Anaheim, CA');
      });

      test('keeps city name unchanged', () {
        final q = ActivitySuggestionsService.searchQueryForTest('Paris, France');
        expect(q, 'Paris, France');
      });

      test('keeps landmark + city', () {
        final q = ActivitySuggestionsService.searchQueryForTest(
            'Eiffel Tower, Paris, France');
        expect(q, 'Eiffel Tower, Paris');
      });

      test('handles single-part location', () {
        final q = ActivitySuggestionsService.searchQueryForTest('Tokyo');
        expect(q, 'Tokyo');
      });

      test('strips street with unit number', () {
        final q = ActivitySuggestionsService.searchQueryForTest(
            '100 Main St Suite 3, New York, NY, USA');
        expect(q, 'New York, NY');
      });
    });
  });

  group('ActivitySuggestion model', () {
    test('constructs with all fields', () {
      const s = ActivitySuggestion(
        platform: ActivityPlatform.viator,
        id: 'TOUR123',
        title: 'Eiffel Tower Skip-the-Line',
        imageUrl: 'https://example.com/img.jpg',
        rating: 4.8,
        reviewCount: 1234,
        priceFrom: 29.0,
        currency: 'USD',
        durationMinutes: 120,
        affiliateUrl: 'https://www.viator.com/tours/TOUR123?pid=X',
      );
      expect(s.platform, ActivityPlatform.viator);
      expect(s.title, 'Eiffel Tower Skip-the-Line');
      expect(s.priceFrom, 29.0);
      expect(s.rating, 4.8);
      expect(s.durationMinutes, 120);
    });

    test('defaults currency to USD', () {
      const s = ActivitySuggestion(
        platform: ActivityPlatform.getYourGuide,
        id: 'GYG1',
        title: 'City Tour',
        affiliateUrl: 'https://getyourguide.com',
      );
      expect(s.currency, 'USD');
    });
  });
}
