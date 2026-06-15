import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/activity_suggestion.dart';

class ViatorSearchResult {
  final List<ActivitySuggestion> items;
  final int totalCount;
  const ViatorSearchResult({required this.items, required this.totalCount});
}

class ActivitySuggestionsService {
  static String get _viatorBase => kViatorSandbox
      ? 'https://api.sandbox.viator.com/partner'
      : 'https://api.viator.com/partner';

  // In-memory cache: destination → (results, expiry)
  static final Map<
      String,
      ({List<ActivitySuggestion> results, DateTime expiry})> _cache = {};

  static Uri gygBrowseUrl(String destination) => Uri.parse(
        'https://www.getyourguide.com/s/'
        '?q=${Uri.encodeComponent(destination)}'
        '&partner_id=$kGYGAffiliateId',
      );

  static Uri klookBrowseUrl(String destination) => Uri.parse(
        'https://www.klook.com/search-result/'
        '?keyword=${Uri.encodeComponent(destination)}'
        '&aid=$kKlookAffiliateId',
      );

  // Test hook — exposes the private destination cleaner without making API calls.
  static String searchQueryForTest(String location) => _searchQuery(location);

  // Strips street-level detail from a Google Places address so Viator gets a
  // useful city/region query instead of a full street address.
  // "706 South Broadview St, Anaheim, CA, USA" → "Anaheim, CA"
  // "Paris, France" → "Paris, France"
  static String _searchQuery(String location) {
    final parts = location.split(',').map((s) => s.trim()).toList();
    if (parts.length <= 1) return location;
    // If the first segment contains digits it's a street address — skip it.
    final start = RegExp(r'\d').hasMatch(parts.first) ? 1 : 0;
    return parts.skip(start).take(2).join(', ');
  }

  static const int pageSize = 10;

  // [searchTerm] is sent directly to Viator — callers are responsible for
  // cleaning it up (strip street prefix, combine keyword + city, etc.).
  Future<ViatorSearchResult> searchViator(
    String searchTerm, {
    int start = 1,
  }) async {
    if (searchTerm.isEmpty) return const ViatorSearchResult(items: [], totalCount: 0);
    if (kViatorApiKey == 'REPLACE_ME') return const ViatorSearchResult(items: [], totalCount: 0);

    // Only cache the first page of the raw destination (no keyword).
    if (start == 1) {
      final cached = _cache[searchTerm];
      if (cached != null && cached.expiry.isAfter(DateTime.now())) {
        return ViatorSearchResult(
            items: cached.results, totalCount: cached.results.length);
      }
    }

    final query = searchTerm;
    final response = await http.post(
      Uri.parse('$_viatorBase/search/freetext'),
      headers: {
        'exp-api-key': kViatorApiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json;version=2.0',
        'Accept-Language': 'en-US',
      },
      body: jsonEncode({
        'searchTerm': query,
        'searchTypes': [
          {'searchType': 'PRODUCTS', 'pagination': {'start': start, 'count': pageSize}},
        ],
        'currency': 'USD',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Viator ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final productsMap = data['products'] as Map<String, dynamic>?;
    final totalCount = productsMap?['totalCount'] as int? ?? 0;
    final products = productsMap?['results'] as List? ?? [];

    final items = products
        .map((p) => _mapProduct(p as Map<String, dynamic>))
        .whereType<ActivitySuggestion>()
        .toList();

    if (start == 1) {
      _cache[searchTerm] = (
        results: items,
        expiry: DateTime.now().add(const Duration(minutes: 10)),
      );
    }

    return ViatorSearchResult(items: items, totalCount: totalCount);
  }

  static ActivitySuggestion? _mapProduct(Map<String, dynamic> p) {
    final code = p['productCode'] as String?;
    final title = p['title'] as String?;
    // productUrl already contains affiliate params (pid, mcid, medium) from the API.
    final productUrl = p['productUrl'] as String?;
    if (code == null || title == null || productUrl == null) return null;

    // Pick a mid-sized image variant (prefer ~480px wide for card thumbnails).
    String? imageUrl;
    final images = p['images'] as List?;
    if (images != null && images.isNotEmpty) {
      final variants = (images.first as Map)['variants'] as List?;
      if (variants != null && variants.isNotEmpty) {
        // Sort by width, pick one around 480px — good balance of quality vs load time.
        final sorted = List.of(variants)
          ..sort((a, b) =>
              ((a as Map)['width'] as int).compareTo((b as Map)['width'] as int));
        final preferred = sorted.cast<Map>().firstWhere(
              (v) => (v['width'] as int) >= 480,
              orElse: () => sorted.last as Map,
            );
        imageUrl = preferred['url'] as String?;
      }
    }

    final reviews = p['reviews'] as Map<String, dynamic>?;
    final rating = (reviews?['combinedAverageRating'] as num?)?.toDouble();
    final reviewCount = reviews?['totalReviews'] as int?;

    final pricing = p['pricing'] as Map<String, dynamic>?;
    final summary = pricing?['summary'] as Map<String, dynamic>?;
    final priceFrom = (summary?['fromPrice'] as num?)?.toDouble();

    // Duration can be fixed or variable — use fixed, fall back to variable min.
    final duration = p['duration'] as Map<String, dynamic>?;
    final durationMinutes = duration?['fixedDurationInMinutes'] as int? ??
        duration?['variableDurationFromMinutes'] as int?;

    return ActivitySuggestion(
      platform: ActivityPlatform.viator,
      id: code,
      title: title,
      description: p['description'] as String?,
      imageUrl: imageUrl,
      rating: rating,
      reviewCount: reviewCount,
      priceFrom: priceFrom,
      currency: 'USD',
      durationMinutes: durationMinutes,
      affiliateUrl: productUrl,
    );
  }
}
