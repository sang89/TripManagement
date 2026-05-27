import 'trip_member.dart';
import 'trip_stop.dart';

class Trip {
  final String id;
  final String createdBy;
  final String title;
  final String destination;
  final String notes;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TripMember> members;
  final List<TripStop> stops;

  const Trip({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.destination,
    required this.notes,
    this.destinationLat,
    this.destinationLng,
    this.startAt,
    this.endAt,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
    required this.stops,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final rawStops = (json['trip_stops'] as List<dynamic>? ?? [])
        .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Trip(
      id: json['id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      startAt: json['start_at'] != null
          ? DateTime.parse(json['start_at'] as String)
          : null,
      endAt: json['end_at'] != null
          ? DateTime.parse(json['end_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      members: (json['trip_members'] as List<dynamic>? ?? [])
          .map((m) => TripMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      stops: rawStops,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'destination': destination,
        'notes': notes,
        'destination_lat': ?destinationLat,
        'destination_lng': ?destinationLng,
        'start_at': startAt?.toUtc().toIso8601String(),
        'end_at': endAt?.toUtc().toIso8601String(),
      };

  Trip copyWith({
    String? title,
    String? destination,
    String? notes,
    double? destinationLat,
    double? destinationLng,
    DateTime? startAt,
    DateTime? endAt,
    bool clearStartAt = false,
    bool clearEndAt = false,
    List<TripMember>? members,
    List<TripStop>? stops,
  }) =>
      Trip(
        id: id,
        createdBy: createdBy,
        title: title ?? this.title,
        destination: destination ?? this.destination,
        notes: notes ?? this.notes,
        destinationLat: destinationLat ?? this.destinationLat,
        destinationLng: destinationLng ?? this.destinationLng,
        startAt: clearStartAt ? null : (startAt ?? this.startAt),
        endAt: clearEndAt ? null : (endAt ?? this.endAt),
        createdAt: createdAt,
        updatedAt: updatedAt,
        members: members ?? this.members,
        stops: stops ?? this.stops,
      );
}
