import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_ui/shared_ui.dart';

class TripMapPin {
  final String id;
  final LatLng position;
  final String title;
  final String? subtitle;
  // Destination pins render as a blue marker; stops get numbered circles.
  final bool isDestination;

  const TripMapPin({
    required this.id,
    required this.position,
    required this.title,
    this.subtitle,
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

  @override
  State<TripMapWidget> createState() => _TripMapWidgetState();
}

class _TripMapWidgetState extends State<TripMapWidget> {
  GoogleMapController? _controller;
  final Map<int, BitmapDescriptor> _stopIcons = {}; // 1-based
  bool _iconsLoaded = false;
  // Compact maps defer mounting so the parent form renders without blocking.
  bool _mapMounted = false;
  List<TripMapPin> _lastPins = [];

  List<TripMapPin> get _stopPins =>
      widget.pins.where((p) => !p.isDestination).toList();

  @override
  void initState() {
    super.initState();
    _lastPins = widget.pins;
    if (widget.compact) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _mapMounted = true);
        _loadIcons();
      });
    } else {
      _mapMounted = true;
      _loadIcons();
    }
  }

  @override
  void didUpdateWidget(TripMapWidget old) {
    super.didUpdateWidget(old);
    if (!_pinsEqual(widget.pins, _lastPins)) {
      _lastPins = widget.pins;
      _loadIcons();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
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
      if (!_stopIcons.containsKey(i)) {
        futures[i] = _makeStopIcon(i);
      }
    }
    if (futures.isEmpty) {
      if (mounted) setState(() => _iconsLoaded = true);
      return;
    }
    final results = await Future.wait(
      futures.entries.map((e) async => MapEntry(e.key, await e.value)),
    );
    if (!mounted) return;
    setState(() {
      for (final r in results) {
        _stopIcons[r.key] = r.value;
      }
      _iconsLoaded = true;
    });
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

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    int stopIdx = 0;
    for (final pin in widget.pins) {
      if (pin.isDestination) {
        markers.add(Marker(
          markerId: MarkerId(pin.id),
          position: pin.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
          infoWindow:
              InfoWindow(title: pin.title, snippet: pin.subtitle),
        ));
      } else {
        stopIdx++;
        final icon = _stopIcons[stopIdx];
        if (icon != null) {
          markers.add(Marker(
            markerId: MarkerId(pin.id),
            position: pin.position,
            icon: icon,
            infoWindow:
                InfoWindow(title: pin.title, snippet: pin.subtitle),
          ));
        }
      }
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (widget.pins.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: widget.pins.map((p) => p.position).toList(),
        color: AppTheme.primary,
        width: 3,
        geodesic: true,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mapMounted || widget.pins.isEmpty) {
      return _EmptyPlaceholder(compact: widget.compact);
    }

    final map = GoogleMap(
      initialCameraPosition:
          CameraPosition(target: widget.pins.first.position, zoom: 10),
      markers: _iconsLoaded ? _buildMarkers() : {},
      polylines: _buildPolylines(),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: !widget.compact,
      // Disable gestures in compact mode so the parent ListView can scroll.
      scrollGesturesEnabled: !widget.compact,
      zoomGesturesEnabled: !widget.compact,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
      },
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
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
