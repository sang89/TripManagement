import 'dart:async';

import 'package:flutter/material.dart';

/// Ticking elapsed-time display for a live match. Updates every second.
class LiveElapsedTimer extends StatefulWidget {
  final DateTime startedAt;
  final TextStyle? style;
  const LiveElapsedTimer({super.key, required this.startedAt, this.style});

  @override
  State<LiveElapsedTimer> createState() => _LiveElapsedTimerState();
}

class _LiveElapsedTimerState extends State<LiveElapsedTimer> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final m = elapsed.inMinutes;
    final s = elapsed.inSeconds % 60;
    return Text(
      '🔴 Live · ${m}m ${s.toString().padLeft(2, '0')}s',
      style: widget.style ??
          const TextStyle(
            color: Colors.green,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
