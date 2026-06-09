class EventWishlistItem {
  final String id;
  final String eventId;
  final String label;
  final String? priceRange;
  final String? link;
  final String createdBy;
  final DateTime createdAt;
  final String? claimedBy;
  final String? claimedByName;
  final DateTime? claimedAt;
  final bool isReceived;

  const EventWishlistItem({
    required this.id,
    required this.eventId,
    required this.label,
    this.priceRange,
    this.link,
    required this.createdBy,
    required this.createdAt,
    this.claimedBy,
    this.claimedByName,
    this.claimedAt,
    this.isReceived = false,
  });

  bool get isClaimed => claimedBy != null;

  factory EventWishlistItem.fromJson(Map<String, dynamic> json) =>
      EventWishlistItem(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        label: json['label'] as String,
        priceRange: json['price_range'] as String?,
        link: json['link'] as String?,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        claimedBy: json['claimed_by'] as String?,
        claimedByName: json['claimed_by_name'] as String?,
        claimedAt: json['claimed_at'] != null
            ? DateTime.parse(json['claimed_at'] as String)
            : null,
        isReceived: json['is_received'] as bool? ?? false,
      );
}
