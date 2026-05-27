import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors device network connectivity and exposes [isOnline].
///
/// Integrates with [OfflineQueue]: when the device comes back online, the
/// queue listens to this service and flushes pending operations automatically.
class ConnectivityService extends ChangeNotifier {
  bool _isOnline = true;

  /// Whether the device currently has a usable network connection.
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Call once at startup (before [runApp]).
  Future<void> init() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = _hasNetwork(results);

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = _hasNetwork(results);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
  }

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.isNotEmpty &&
      results.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
