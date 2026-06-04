class EventStop {
  final String id;
  final String eventId;
  final String title;
  final String address;
  final String notes;
  final DateTime? arriveAt;
  final DateTime? departAt;
  final int sortOrder;
  final DateTime createdAt;
  final double? addressLat;
  final double? addressLng;

  const EventStop({
    required this.id,
    required this.eventId,
    required this.title,
    required this.address,
    required this.notes,
    this.arriveAt,
    this.departAt,
    required this.sortOrder,
    required this.createdAt,
    this.addressLat,
    this.addressLng,
  });

  factory EventStop.fromJson(Map<String, dynamic> json) => EventStop(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        title: json['title'] as String? ?? '',
        address: json['address'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        arriveAt: json['arrive_at'] != null
            ? DateTime.parse(json['arrive_at'] as String)
            : null,
        departAt: json['depart_at'] != null
            ? DateTime.parse(json['depart_at'] as String)
            : null,
        sortOrder: json['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        addressLat: (json['address_lat'] as num?)?.toDouble(),
        addressLng: (json['address_lng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'address': address,
        'notes': notes,
        'arrive_at': arriveAt?.toUtc().toIso8601String(),
        'depart_at': departAt?.toUtc().toIso8601String(),
        'sort_order': sortOrder,
        'address_lat': addressLat,
        'address_lng': addressLng,
      };

  EventStop copyWith({
    String? title,
    String? address,
    String? notes,
    DateTime? arriveAt,
    DateTime? departAt,
    bool clearArriveAt = false,
    bool clearDepartAt = false,
    int? sortOrder,
    double? addressLat,
    double? addressLng,
    bool clearAddressLat = false,
    bool clearAddressLng = false,
  }) =>
      EventStop(
        id: id,
        eventId: eventId,
        title: title ?? this.title,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        arriveAt: clearArriveAt ? null : (arriveAt ?? this.arriveAt),
        departAt: clearDepartAt ? null : (departAt ?? this.departAt),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        addressLat: clearAddressLat ? null : (addressLat ?? this.addressLat),
        addressLng: clearAddressLng ? null : (addressLng ?? this.addressLng),
      );
}
