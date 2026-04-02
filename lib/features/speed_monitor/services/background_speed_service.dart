import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_client.dart';
import 'speed_settings.dart';

/// Background service that tracks GPS speed when app is backgrounded/locked.
///
/// - Starts when employee logs in
/// - Runs as Android foreground service (survives background/lock)
/// - Sends location + speed via PUT /profile/location every 30 seconds
/// - Emits speed violation events to UI
class BackgroundSpeedService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static String? _activeTaskId;

  /// Initialize the background service (call once at app startup).
  static Future<void> initialize() async {
    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'speed_monitor',
        initialNotificationTitle: 'City Group',
        initialNotificationContent: 'Monitoring your speed...',
        foregroundServiceNotificationId: 888,
      ),
    );
  }

  /// Start background monitoring (call after login).
  static Future<void> startMonitoring() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
      await Future.delayed(const Duration(seconds: 2));
    }
    _service.invoke('start', {'taskId': _activeTaskId ?? ''});
  }

  /// Stop background monitoring (call on logout).
  static Future<void> stopMonitoring() async {
    _activeTaskId = null;
    _service.invoke('stop');
  }

  /// Set the active task (speed readings will be tagged).
  static void setActiveTask(String taskId) {
    _activeTaskId = taskId;
    _service.invoke('set_task', {'taskId': taskId});
  }

  /// Clear the active task.
  static void clearActiveTask() {
    _activeTaskId = null;
    _service.invoke('set_task', {'taskId': ''});
  }

  /// Stream of speed updates for UI display.
  static Stream<Map<String, dynamic>?> get speedStream {
    return _service.on('speed_update');
  }

  /// Stream of speed violation alerts.
  static Stream<Map<String, dynamic>?> get violationStream {
    return _service.on('speed_violation');
  }
}

// Background service entry point — runs in a separate isolate
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  String? currentTaskId;
  Timer? speedTimer;
  bool isMonitoring = false;

  void startTimer() {
    speedTimer?.cancel();

    speedTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!isMonitoring) return;

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

        // Send location + speed to API (same endpoint as foreground)
        try {
          final client = ApiClient(secureStorage);
          await client.dio.put('/profile/location', data: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speedKmh': speedKmh,
            if (currentTaskId != null) 'taskId': int.tryParse(currentTaskId!),
          });
        } catch (_) {}

        // Emit speed update to UI
        service.invoke('speed_update', {
          'speedKmh': speedKmh,
          'latitude': position.latitude,
          'longitude': position.longitude,
        });

        // Check for violation (client-side alert)
        final speedLimit = await SpeedSettings.getSpeedLimit();
        if (speedKmh > speedLimit) {
          service.invoke('speed_violation', {
            'speedKmh': speedKmh,
            'speedLimit': speedLimit,
          });
        }
      } catch (_) {
        // GPS unavailable — skip
      }
    });
  }

  service.on('start').listen((event) {
    final taskId = event?['taskId'] as String?;
    currentTaskId = (taskId != null && taskId.isNotEmpty) ? taskId : null;
    isMonitoring = true;
    startTimer();
  });

  service.on('set_task').listen((event) {
    final taskId = event?['taskId'] as String?;
    currentTaskId = (taskId != null && taskId.isNotEmpty) ? taskId : null;
  });

  service.on('stop').listen((event) {
    isMonitoring = false;
    currentTaskId = null;
    speedTimer?.cancel();
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
