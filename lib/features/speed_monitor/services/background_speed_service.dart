import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../data/speed_log_db.dart';
import '../data/speed_log_repository.dart';
import 'speed_settings.dart';
import '../../../core/api/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Background service that tracks GPS speed 24/7.
///
/// - Starts when employee logs in
/// - Stops when employee logs out
/// - Records GPS speed every 30 seconds (or 120 seconds when stationary)
/// - Batch uploads every 5 readings
/// - Emits speed violation events when speed exceeds limit
/// - Optionally tracks which task is active for task-specific readings
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

  /// Start always-on speed monitoring (call after login).
  static Future<void> startMonitoring([String? taskId]) async {
    _activeTaskId = taskId;
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
    _service.invoke('start', {'taskId': taskId ?? ''});
  }

  /// Stop speed monitoring completely (call on logout).
  static Future<void> stopMonitoring() async {
    // Flush remaining readings before stopping
    await _flushAllReadings();
    _activeTaskId = null;
    _service.invoke('stop');
  }

  /// Set the active task (speed readings will be tagged with this taskId).
  static void setActiveTask(String taskId) {
    _activeTaskId = taskId;
    _service.invoke('set_task', {'taskId': taskId});
  }

  /// Clear the active task (readings continue but without taskId).
  static void clearActiveTask() {
    if (_activeTaskId != null) {
      // Flush task-specific readings
      _flushReadings(taskId: _activeTaskId);
    }
    _activeTaskId = null;
    _service.invoke('set_task', {'taskId': ''});
  }

  /// Get the current active task ID.
  static String? get activeTaskId => _activeTaskId;

  /// Flush all unsynced readings to the server.
  static Future<void> _flushAllReadings() async {
    try {
      final readings = await SpeedLogDb.getUnsyncedReadings(limit: 100);
      if (readings.isEmpty) return;

      final client = ApiClient(const FlutterSecureStorage());
      final repo = SpeedLogRepository(client);
      await repo.uploadBatch(readings: readings);

      final ids = readings.map((r) => r['id'] as int).toList();
      await SpeedLogDb.markSynced(ids);
    } catch (_) {
      // Keep in local DB — will retry next time
    }
  }

  /// Flush readings optionally filtered by task.
  static Future<void> _flushReadings({String? taskId}) async {
    try {
      final readings = await SpeedLogDb.getUnsyncedReadings(taskId: taskId, limit: 100);
      if (readings.isEmpty) return;

      final client = ApiClient(const FlutterSecureStorage());
      final repo = SpeedLogRepository(client);
      await repo.uploadBatch(readings: readings);

      final ids = readings.map((r) => r['id'] as int).toList();
      await SpeedLogDb.markSynced(ids);
    } catch (_) {
      // Keep in local DB — will retry next time
    }
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

// Background service entry point
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  String? currentTaskId;
  Timer? speedTimer;
  bool isMonitoring = false;

  void startTimer() {
    speedTimer?.cancel();

    // Record speed every 30 seconds
    speedTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!isMonitoring) return;

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));

        final speedKmh = (position.speed * 3.6).clamp(0.0, 999.0); // m/s to km/h

        // Store in local DB (taskId is optional)
        await SpeedLogDb.insertReading(
          taskId: currentTaskId,
          recordedAt: DateTime.now(),
          speedKmh: speedKmh,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        // Emit speed update to UI
        service.invoke('speed_update', {
          'speedKmh': speedKmh,
          'latitude': position.latitude,
          'longitude': position.longitude,
        });

        // Check for violation against company speed limit
        final speedLimit = await SpeedSettings.getSpeedLimit();
        if (speedKmh > speedLimit) {
          service.invoke('speed_violation', {
            'speedKmh': speedKmh,
            'speedLimit': speedLimit,
          });
        }

        // Batch upload every 5 readings
        final unsyncedCount = await SpeedLogDb.unsyncedCount();
        if (unsyncedCount >= 5) {
          await _uploadBatch();
        }
      } catch (_) {
        // GPS unavailable — skip this reading
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

Future<void> _uploadBatch() async {
  try {
    final readings = await SpeedLogDb.getUnsyncedReadings(limit: 5);
    if (readings.isEmpty) return;

    final client = ApiClient(const FlutterSecureStorage());
    final repo = SpeedLogRepository(client);
    await repo.uploadBatch(readings: readings);

    final ids = readings.map((r) => r['id'] as int).toList();
    await SpeedLogDb.markSynced(ids);
  } catch (_) {
    // Offline — keep buffered, retry next batch
  }
}
