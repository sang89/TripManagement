enum ActivityPlatform { viator, getYourGuide, klook }

class ActivitySuggestion {
  final ActivityPlatform platform;
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final double? rating;
  final int? reviewCount;
  final double? priceFrom;
  final String currency;
  final int? durationMinutes;
  final String affiliateUrl;

  const ActivitySuggestion({
    required this.platform,
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.rating,
    this.reviewCount,
    this.priceFrom,
    this.currency = 'USD',
    this.durationMinutes,
    required this.affiliateUrl,
  });
}
