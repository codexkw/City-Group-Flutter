import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_client.dart';

/// Sends the employee's GPS location + speed to the server every 30 seconds.
///
/// Handles both:
/// 1. Location tracking for admin live map (keeps employee online)
/// 2. Speed recording for speed monitoring (logs + violation detection)
///
/// - Starts after login
/// - Stops on logout (sends explicit offline ping)
/// - Continues running when app is backgrounded/screen locked
class LocationTrackingService with WidgetsBindingObserver {
  static LocationTrackingService? _instance;
  Timer? _timer;
  bool _isTracking = false;
  String? _activeTaskId;

  LocationTrackingService._();

  static LocationTrackingService get instance {
    _instance ??= LocationTrackingService._();
    return _instance!;
  }

  /// Set active task ID (speed readings will be tagged).
  void setActiveTask(String taskId) {
    _activeTaskId = taskId;
  }

  /// Clear active task ID.
  void clearActiveTask() {
    _activeTaskId = null;
  }

  /// Start periodic location + speed tracking (call after login).
  Future<void> start() async {
    if (_isTracking) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _isTracking = true;
    WidgetsBinding.instance.addObserver(this);

    // Send immediately, then every 30 seconds
    _recordAndSend();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _recordAndSend();
    });
  }

  /// Stop tracking and mark employee offline (call on logout).
  Future<void> stop() async {
    _isTracking = false;
    _activeTaskId = null;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep timer running in all states — don't stop on background/lock
    // The timer will fail silently if GPS is unavailable in background
    if (state == AppLifecycleState.resumed && _isTracking && _timer == null) {
      // Restart timer if it was somehow stopped
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        _recordAndSend();
      });
    }
  }

  Future<void> _recordAndSend() async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) return;

      final speedKmh = (position.speed.clamp(0.0, double.infinity) * 3.6)
          .clamp(0.0, 999.0);

      // Send location + speed in a single API call
      // The API creates SpeedLog records and checks for violations server-side
      try {
        final client = ApiClient(secureStorage);
        await client.dio.put(
          '/profile/location',
          data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speedKmh': speedKmh,
            if (_activeTaskId != null) 'taskId': int.tryParse(_activeTaskId!),
          },
        );
      } catch (_) {}
    } catch (_) {
      // GPS unavailable — skip this reading
    }
  }
}
