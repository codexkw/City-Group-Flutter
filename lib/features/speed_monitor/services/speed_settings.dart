import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores company speed limit settings locally.
/// Read by the background service without making API calls.
class SpeedSettings {
  static const _storage = FlutterSecureStorage();
  static const _speedLimitKey = 'company_speed_limit_kmh';
  static const _speedWarningKey = 'company_speed_warning_kmh';

  /// Save speed settings (called after login from profile/company data).
  static Future<void> save({
    required double speedLimitKmh,
    double? speedWarningKmh,
  }) async {
    await _storage.write(key: _speedLimitKey, value: speedLimitKmh.toString());
    if (speedWarningKmh != null) {
      await _storage.write(key: _speedWarningKey, value: speedWarningKmh.toString());
    }
  }

  /// Get the speed limit in km/h. Returns 120 as default if not set.
  static Future<double> getSpeedLimit() async {
    final value = await _storage.read(key: _speedLimitKey);
    return value != null ? double.tryParse(value) ?? 120.0 : 120.0;
  }

  /// Get the warning threshold in km/h. Returns speedLimit - 10 if not set.
  static Future<double> getWarningThreshold() async {
    final warning = await _storage.read(key: _speedWarningKey);
    if (warning != null) return double.tryParse(warning) ?? 110.0;
    final limit = await getSpeedLimit();
    return limit - 10;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _speedLimitKey);
    await _storage.delete(key: _speedWarningKey);
  }
}
