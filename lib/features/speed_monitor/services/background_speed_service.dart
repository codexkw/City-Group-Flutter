import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../data/speed_log_db.dart';
import '../data/speed_log_repository.dart';
import 'speed_settings.dart';
import '../../../core/api/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Background service that tracks GPS speed during active tasks.
///
/// - Starts when employee taps "Start Task"
/// - Stops when task is completed or paused
/// - Records GPS speed every 30 seconds into local SQLite
/// - Batch uploads every 5 readings or on task end
/// - Emits speed violation events when speed exceeds limit
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
        initialNotificationTitle: 'Speed Monitor',
        initialNotificationContent: 'Monitoring speed...',
        foregroundServiceNotificationId: 888,
      ),
    );
  }

  /// Start speed monitoring for a task.
  static Future<void> startMonitoring(String taskId) async {
    _activeTaskId = taskId;
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
    _service.invoke('start', {'taskId': taskId});
  }

  /// Stop speed monitoring (on task pause/complete).
  static Future<void> stopMonitoring() async {
    // Flush remaining readings before stopping
    if (_activeTaskId != null) {
      await _flushReadings(_activeTaskId!);
    }
    _activeTaskId = null;
    _service.invoke('stop');
  }

  /// Get the current active task ID.
  static String? get activeTaskId => _activeTaskId;

  /// Flush all unsynced readings for a task to the server.
  static Future<void> _flushReadings(String taskId) async {
    try {
      final readings = await SpeedLogDb.getUnsyncedReadings(taskId: taskId, limit: 100);
      if (readings.isEmpty) return;

      final client = ApiClient(const FlutterSecureStorage());
      final repo = SpeedLogRepository(client);
      await repo.uploadBatch(taskId: taskId, readings: readings);

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

  service.on('start').listen((event) {
    currentTaskId = event?['taskId'] as String?;
    speedTimer?.cancel();

    // Record speed every 30 seconds
    speedTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (currentTaskId == null) return;

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final speedKmh = (position.speed * 3.6).clamp(0.0, 999.0); // m/s to km/h

        // Store in local DB
        await SpeedLogDb.insertReading(
          taskId: currentTaskId!,
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

        // Check for violation
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
          await _uploadBatch(currentTaskId!);
        }
      } catch (_) {
        // GPS unavailable — skip this reading
      }
    });
  });

  service.on('stop').listen((event) {
    currentTaskId = null;
    speedTimer?.cancel();
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

Future<void> _uploadBatch(String taskId) async {
  try {
    final readings = await SpeedLogDb.getUnsyncedReadings(taskId: taskId, limit: 5);
    if (readings.isEmpty) return;

    final client = ApiClient(const FlutterSecureStorage());
    final repo = SpeedLogRepository(client);
    await repo.uploadBatch(taskId: taskId, readings: readings);

    final ids = readings.map((r) => r['id'] as int).toList();
    await SpeedLogDb.markSynced(ids);
  } catch (_) {
    // Offline — keep buffered, retry next batch
  }
}
