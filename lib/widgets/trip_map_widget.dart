import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_ui/shared_ui.dart';

import '../services/directions_service.dart';

class TripMapPin {
  final String id;
  final LatLng position;
  final String title;
  final String? subtitle;
  // Start pin → green marker; destination pin → blue/azure marker;
  // everything else → numbered circle.
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

  // App-level caches — survive widget disposal so work is only done once per
  // session regardless of how many times the widget is created.
  static final Map<int, BitmapDescriptor> _iconCache = {};
  // Key: pipe-separated "lat,lng" of each waypoint in order.
  static final Map<String, List<LatLng>?> _routeCache = {};

  static String _routeKey(List<LatLng> waypoints) =>
      waypoints.map((p) => '${p.latitude},${p.longitude}').join('|');

  /// Pre-warm the route cache for [waypoints] in the background.
  /// Safe to call repeatedly — no-op if the route is already cached.
  /// Call this as soon as the trip data is available so the Map tab opens
  /// with a real road route rather than a straight-line fallback.
  static void prefetchRoute(List<LatLng> waypoints) {
    if (waypoints.length < 2) return;
    final key = _routeKey(waypoints);
    if (_routeCache.containsKey(key)) return;
    DirectionsService.getRoute(waypoints).then((points) {
      if (points != null) _routeCache[key] = points;
      // Don't cache failures — allow a retry on the next Map tab open.
    });
  }

  /// Pre-render stop-pin icons for numbers 1..[stopCount] in the background.
  /// Safe to call repeatedly — skips numbers already in the cache.
  /// Call this alongside [prefetchRoute] so icon rendering is done before
  /// the user opens the Map tab.
  static void prefetchIcons(int stopCount) {
    for (int i = 1; i <= stopCount; i++) {
      if (!_iconCache.containsKey(i)) {
        final n = i;
        _makeStopIcon(n).then((icon) => _iconCache[n] = icon);
      }
    }
  }

  static Future<BitmapDescriptor> _makeStopIcon(int n) async {
    const sz = 44.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2,
      Paint()..color = AppTheme.primary,
    );
    canvas.drawCircle(
      const Offset(sz / 2, sz / 2),
      sz / 2 - 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: n < 10 ? 20.0 : 15.0,
        fontWeight: ui.FontWeight.w700,
      ))
      ..addText('$n');
    final para = pb.build()
      ..layout(ui.ParagraphConstraints(width: sz));
    canvas.drawParagraph(para, Offset(0, (sz - para.height) / 2));

    final img = await recorder.endRecording().toImage(sz.toInt(), sz.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// Test-only: wipe static caches so tests don't bleed into each other.
  @visibleForTesting
  static void clearCachesForTest() {
    _iconCache.clear();
    _routeCache.clear();
  }

  /// Test-only: pre-populate the route cache for a given waypoint list.
  @visibleForTesting
  static void seedRouteCacheForTest(List<LatLng> waypoints, List<LatLng>? points) {
    _routeCache[_routeKey(waypoints)] = points;
  }

  @override
  State<TripMapWidget> createState() => _TripMapWidgetState();
}

class _TripMapWidgetState extends State<TripMapWidget>
    with WidgetsBindingObserver {
  // NOTE: AutomaticKeepAliveClientMixin is intentionally NOT used.
  //
  // With it, the GoogleMap platform view (GMSMapView) stays in the iOS view
  // hierarchy even when the user is on a different tab.  When the app is then
  // backgrounded and foregrounded, the Maps SDK re-validates its Metal
  // resources synchronously on the main thread — blocking Flutter and making
  // the whole app feel frozen.  Flutter's setState in AppLifecycleState.paused
  // is queued and only processed on foreground, so a Dart-side teardown
  // always runs *after* the freeze, not before it.
  //
  // Without the mixin the view is disposed the moment the user switches away
  // from the Map tab.  There is nothing in the iOS hierarchy to re-validate
  // when the app backgrounds from any other tab.  The route and icon caches
  // (static fields below) make subsequent tab visits instant.
  GoogleMapController? _controller;

  bool _iconsLoaded = false;

  // Phase 1: defer platform-view creation past the tab-switch animation.
  // _mapMountTimerFired: the 300 ms delay has elapsed.
  // _mapMounted: all three prereqs met — timer fired, icons ready, route done.
  bool _mapMounted = false;
  bool _mapMountTimerFired = false;
  bool _mapMountTimerStarted = false;

  // Phase 2: native SDK onMapCreated has fired and the view is ready.
  bool _mapReady = false;

  // False while the app is backgrounded.  _checkMount() will not set
  // _mapMounted = true while inactive, so the GMSMapView is never created
  // during the foreground-restore transition (the most disruptive moment).
  bool _appActive = true;

  List<TripMapPin> _lastPins = [];
  List<LatLng>? _routePoints;

  List<TripMapPin> get _stopPins =>
      widget.pins.where((p) => !p.isStart && !p.isDestination).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastPins = widget.pins;
    _loadIcons();
    _loadRoute();
    _scheduleMountTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appActive = false;
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() { _appActive = true; _checkMount(); });
    }
  }

  void _checkMount() {
    // Route loading is intentionally excluded: the map shows as soon as the
    // timer fires and icons are ready. The polyline updates from straight-line
    // to real road when the Directions API responds — no blocking wait.
    if (!_mapMounted &&
        _mapMountTimerFired &&
        _iconsLoaded &&
        _appActive) {
      _mapMounted = true;
    }
  }

  void _scheduleMountTimer() {
    if (_mapMountTimerStarted || widget.pins.isEmpty) return;
    _mapMountTimerStarted = true;
    // 50 ms lets the tab-switch animation's first frame render before the
    // platform view is created.  Metal shaders are pre-compiled by the
    // AppDelegate warmup, so GMSMapView creation is near-instant.
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() { _mapMountTimerFired = true; _checkMount(); });
    });
  }

  @override
  void didUpdateWidget(TripMapWidget old) {
    super.didUpdateWidget(old);
    if (!_pinsEqual(widget.pins, _lastPins)) {
      _lastPins = widget.pins;
      _iconsLoaded = false;
      _routePoints = null;
      _loadIcons();
      _loadRoute();
      if (_mapMounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
      } else {
        _scheduleMountTimer();
      }
    }
  }

  static bool _pinsEqual(List<TripMapPin> a, List<TripMapPin> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].position.latitude != b[i].position.latitude ||
          a[i].position.longitude != b[i].position.longitude) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadIcons() async {
    final count = _stopPins.length;
    final futures = <int, Future<BitmapDescriptor>>{};
    for (int i = 1; i <= count; i++) {
      if (!TripMapWidget._iconCache.containsKey(i)) {
        futures[i] = TripMapWidget._makeStopIcon(i);
      }
    }
    if (futures.isEmpty) {
      if (mounted) setState(() { _iconsLoaded = true; _checkMount(); });
      return;
    }
    final results = await Future.wait(
      futures.entries.map((e) async => MapEntry(e.key, await e.value)),
    );
    if (!mounted) return;
    setState(() {
      for (final r in results) {
        TripMapWidget._iconCache[r.key] = r.value;
      }
      _iconsLoaded = true;
      _checkMount();
    });
  }

  Future<void> _loadRoute() async {
    if (widget.pins.length < 2) return;
    final waypoints = widget.pins.map((p) => p.position).toList();
    final key = TripMapWidget._routeKey(waypoints);

    // Return immediately if we already fetched this route this session.
    if (TripMapWidget._routeCache.containsKey(key)) {
      if (mounted) {
        setState(() => _routePoints = TripMapWidget._routeCache[key]);
      }
      return;
    }

    final points = await DirectionsService.getRoute(waypoints);
    if (points != null) TripMapWidget._routeCache[key] = points;
    // Don't cache failures — the next Map tab visit will retry automatically.
    if (!mounted) return;
    setState(() => _routePoints = points);
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    int stopIdx = 0;
    for (final pin in widget.pins) {
      if (pin.isStart) {
        markers.add(Marker(
          markerId: MarkerId(pin.id),
          position: pin.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: pin.title, snippet: pin.subtitle),
        ));
      } else if (pin.isDestination) {
        markers.add(Marker(
          markerId: MarkerId(pin.id),
          position: pin.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: pin.title, snippet: pin.subtitle),
        ));
      } else {
        stopIdx++;
        final icon = TripMapWidget._iconCache[stopIdx];
        if (icon != null) {
          markers.add(Marker(
            markerId: MarkerId(pin.id),
            position: pin.position,
            icon: icon,
            infoWindow: InfoWindow(title: pin.title, snippet: pin.subtitle),
          ));
        }
      }
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (widget.pins.length < 2) return {};
    final points = _routePoints ?? widget.pins.map((p) => p.position).toList();
    final isRealRoute = _routePoints != null;
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppTheme.primary,
        width: isRealRoute ? 4 : 3,
        geodesic: !isRealRoute,
        patterns: isRealRoute
            ? []
            : [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  void _fitBounds() {
    if (_controller == null || widget.pins.isEmpty) return;
    final pts = widget.pins.map((p) => p.position).toList();
    if (pts.length == 1) {
      _controller!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 13));
      return;
    }
    var minLat = pts.first.latitude;
    var maxLat = pts.first.latitude;
    var minLng = pts.first.longitude;
    var maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        widget.compact ? 40 : 64,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pins.isEmpty) {
      return _EmptyPlaceholder(compact: widget.compact);
    }

    if (!_mapMounted) {
      return _LoadingPlaceholder(compact: widget.compact);
    }

    final map = GoogleMap(
      initialCameraPosition:
          CameraPosition(target: widget.pins.first.position, zoom: 10),
      markers: _buildMarkers(),
      polylines: _buildPolylines(),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: !widget.compact,
      scrollGesturesEnabled: !widget.compact,
      zoomGesturesEnabled: !widget.compact,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        if (mounted) setState(() => _mapReady = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
      },
    );

    final Widget mapWidget = widget.compact
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(height: 220, child: map),
          )
        : map;

    return RepaintBoundary(
      child: Stack(
        children: [
          IgnorePointer(ignoring: !_mapReady, child: mapWidget),
          if (!_mapReady)
            Positioned.fill(
              child: _LoadingPlaceholder(compact: widget.compact, opaque: true),
            ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  final bool compact;
  final bool opaque;

  const _LoadingPlaceholder({required this.compact, this.opaque = false});

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppTheme.primaryLight,
          ),
          const SizedBox(height: 12),
          Text(
            'Loading map…',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
    if (compact) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: content,
      );
    }
    if (opaque) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: content,
      );
    }
    return content;
  }
}

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
            const Icon(Icons.map_outlined,
                size: 64, color: AppTheme.primaryLight),
            const SizedBox(height: 16),
            const Text('No mapped locations yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Use the   search button when adding a destination or stop to pin it on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
