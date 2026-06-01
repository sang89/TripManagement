import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_ui/shared_ui.dart';

import '../config/api_keys.dart';
import '../services/directions_service.dart';

export 'package:latlong2/latlong.dart' show LatLng;

class TripMapPin {
  final String id;
  final LatLng position;
  final String title;
  final String? subtitle;
  final bool isStart;
  final bool isDestination;

  const TripMapPin({
    required this.id,
    required this.position,
    required this.title,
    this.subtitle,
    this.isStart = false,
    this.isDestination = false,
  });
}

/// Renders an ordered route: polyline + destination marker (blue) +
/// numbered stop markers. Pass [compact] to embed in a form card
/// (fixed 220px, gestures disabled so ListView can still scroll).
class TripMapWidget extends StatefulWidget {
  final List<TripMapPin> pins;
  final bool compact;

  const TripMapWidget({
    super.key,
    required this.pins,
    this.compact = false,
  });

  // Session-level route cache — keyed by pipe-separated waypoints.
  static final Map<String, List<LatLng>?> _routeCache = {};

  static String _routeKey(List<LatLng> waypoints) =>
      waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');

  static void prefetchRoute(List<LatLng> waypoints) {
    if (waypoints.length < 2) return;
    final key = _routeKey(waypoints);
    if (_routeCache.containsKey(key)) return;
    DirectionsService.getRoute(waypoints).then((points) {
      if (points != null) _routeCache[key] = points;
    });
  }

  // No-op — flutter_map uses Flutter widgets for markers, no pre-rendering.
  static void prefetchIcons(int stopCount) {}

  @visibleForTesting
  static void clearCachesForTest() => _routeCache.clear();

  @visibleForTesting
  static void seedRouteCacheForTest(List<LatLng> waypoints, List<LatLng>? points) {
    _routeCache[_routeKey(waypoints)] = points;
  }

  @override
  State<TripMapWidget> createState() => _TripMapWidgetState();
}

class _TripMapWidgetState extends State<TripMapWidget> {
  final _mapController = MapController();
  List<LatLng>? _routePoints;
  List<TripMapPin> _lastPins = [];

  @override
  void initState() {
    super.initState();
    _lastPins = widget.pins;
    _loadRoute();
  }

  @override
  void didUpdateWidget(TripMapWidget old) {
    super.didUpdateWidget(old);
    if (!_pinsEqual(widget.pins, _lastPins)) {
      _lastPins = widget.pins;
      _routePoints = null;
      _loadRoute();
    }
  }

  static bool _pinsEqual(List<TripMapPin> a, List<TripMapPin> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].position.latitude != b[i].position.latitude ||
          a[i].position.longitude != b[i].position.longitude) { return false; }
    }
    return true;
  }

  Future<void> _loadRoute() async {
    if (widget.pins.length < 2) return;
    final waypoints = widget.pins.map((p) => p.position).toList();
    final key = TripMapWidget._routeKey(waypoints);
    if (TripMapWidget._routeCache.containsKey(key)) {
      if (mounted) { setState(() => _routePoints = TripMapWidget._routeCache[key]); }
      return;
    }
    final points = await DirectionsService.getRoute(waypoints);
    if (points != null) TripMapWidget._routeCache[key] = points;
    if (mounted) setState(() => _routePoints = points);
  }

  LatLng get _center {
    if (widget.pins.isEmpty) return const LatLng(0, 0);
    final lats = widget.pins.map((p) => p.position.latitude);
    final lngs = widget.pins.map((p) => p.position.longitude);
    return LatLng(
      (lats.reduce((a, b) => a + b)) / widget.pins.length,
      (lngs.reduce((a, b) => a + b)) / widget.pins.length,
    );
  }

  double get _initialZoom {
    if (widget.pins.length < 2) return 13;
    final lats = widget.pins.map((p) => p.position.latitude);
    final lngs = widget.pins.map((p) => p.position.longitude);
    final latSpan = lats.reduce((a, b) => a > b ? a : b) -
        lats.reduce((a, b) => a < b ? a : b);
    final lngSpan = lngs.reduce((a, b) => a > b ? a : b) -
        lngs.reduce((a, b) => a < b ? a : b);
    final span = latSpan > lngSpan ? latSpan : lngSpan;
    if (span > 50) return 3;
    if (span > 20) return 4;
    if (span > 10) return 5;
    if (span > 5) return 7;
    if (span > 1) return 9;
    return 12;
  }

  String _tileUrl(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = isDark ? 'alidade_smooth_dark' : 'alidade_smooth';
    return 'https://tiles.stadiamaps.com/tiles/$style/{z}/{x}/{y}.png?api_key=$kStadiaMapsApiKey';
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    int stopIdx = 0;
    for (final pin in widget.pins) {
      if (pin.isStart) {
        markers.add(Marker(
          point: pin.position,
          width: 36,
          height: 36,
          child: _PinDot(color: Colors.green, icon: Icons.trip_origin),
        ));
      } else if (pin.isDestination) {
        markers.add(Marker(
          point: pin.position,
          width: 36,
          height: 36,
          child: _PinDot(color: AppTheme.primaryLight, icon: Icons.location_on),
        ));
      } else {
        stopIdx++;
        markers.add(Marker(
          point: pin.position,
          width: 32,
          height: 32,
          child: _StopNumberPin(number: stopIdx),
        ));
      }
    }
    return markers;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pins.isEmpty) {
      return _EmptyPlaceholder(compact: widget.compact);
    }

    final routePoints = _routePoints ??
        widget.pins.map((p) => p.position).toList();
    final isRealRoute = _routePoints != null;

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: _initialZoom,
        interactionOptions: InteractionOptions(
          flags: widget.compact
              ? InteractiveFlag.none
              : InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _tileUrl(context),
          userAgentPackageName: 'com.sang89.trip_management',
          retinaMode: MediaQuery.devicePixelRatioOf(context) > 1.0,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: routePoints,
              color: AppTheme.primary,
              strokeWidth: isRealRoute ? 4 : 3,
              pattern: isRealRoute
                ? const StrokePattern.solid()
                : StrokePattern.dashed(segments: [10, 6]),
            ),
          ],
        ),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );

    if (widget.compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(height: 220, child: map),
      );
    }
    return map;
  }
}

// ─── Marker widgets ────────────────────────────────────────────────────────────

class _PinDot extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _PinDot({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _StopNumberPin extends StatelessWidget {
  final int number;

  const _StopNumberPin({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: number < 10 ? 13 : 10,
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  final bool compact;
  const _EmptyPlaceholder({required this.compact});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'Search a destination or stop\nto see it on the map',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: AppTheme.primaryLight),
            const SizedBox(height: 16),
            const Text('No mapped locations yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Use the search button when adding a destination or stop to pin it on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
