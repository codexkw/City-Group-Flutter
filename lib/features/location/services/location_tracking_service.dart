import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_client.dart';
import '../../profile/data/profile_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sends the employee's GPS location to the server every 60 seconds
/// so the admin dashboard can show real-time positions on the map.
///
/// - Starts after login
/// - Stops on logout or when the app is killed
/// - Observes AppLifecycleState to pause/resume automatically
class LocationTrackingService with WidgetsBindingObserver {
  static LocationTrackingService? _instance;
  Timer? _timer;
  bool _isTracking = false;

  LocationTrackingService._();

  static LocationTrackingService get instance {
    _instance ??= LocationTrackingService._();
    return _instance!;
  }

  /// Start periodic location pings (call after login).
  Future<void> start() async {
    if (_isTracking) return;

    // Check location permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return; // Can't track without permission
    }

    _isTracking = true;
    WidgetsBinding.instance.addObserver(this);

    // Send location immediately, then every 60 seconds
    _sendLocation();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendLocation();
    });
  }

  /// Stop tracking (call on logout).
  void stop() {
    _isTracking = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Handle app lifecycle changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App going to background or killed — send final location and stop timer
      _sendLocation();
      _timer?.cancel();
      _timer = null;
    } else if (state == AppLifecycleState.resumed && _isTracking) {
      // App resumed — restart timer
      _sendLocation();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        _sendLocation();
      });
    }
  }

  Future<void> _sendLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final client = ApiClient(const FlutterSecureStorage());
      final repo = ProfileRepository(client);
      await repo.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // GPS unavailable or network error — skip this ping
    }
  }
}
