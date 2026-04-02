import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/api/api_client.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../location/services/location_tracking_service.dart';
import '../../../speed_monitor/services/background_speed_service.dart';
import '../../../speed_monitor/services/speed_settings.dart';
import '../../data/auth_repository.dart';

// Secure storage provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return secureStorage;
});

// API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.read(secureStorageProvider);
  return ApiClient(storage);
});

// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

// Locale provider
final localeProvider = StateProvider<Locale?>((ref) => const Locale('en'));

// User data model
class UserData {
  final int id;
  final String fullName;
  final String role;
  final String language;
  final String? profilePhotoUrl;
  final int companyId;
  final String companyName;
  final int speedLimitKmh;
  final int speedWarningThresholdKmh;
  final bool enableSpeedMonitoring;

  UserData({
    required this.id,
    required this.fullName,
    required this.role,
    required this.language,
    this.profilePhotoUrl,
    required this.companyId,
    required this.companyName,
    this.speedLimitKmh = 120,
    this.speedWarningThresholdKmh = 100,
    this.enableSpeedMonitoring = true,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>? ?? json;
    return UserData(
      id: employee['id'] is int ? employee['id'] : 0,
      fullName: employee['fullName'] ?? employee['fullNameEn'] ?? employee['fullName'] ?? '',
      role: employee['role'] ?? 'Employee',
      language: employee['language'] ?? employee['preferredLanguage'] ?? 'en',
      profilePhotoUrl: employee['profilePhotoUrl'],
      companyId: employee['companyId'] is int ? employee['companyId'] : 0,
      companyName: employee['companyName'] ?? employee['companyNameEn'] ?? '',
      speedLimitKmh: employee['speedLimitKmh'] is int ? employee['speedLimitKmh'] : 120,
      speedWarningThresholdKmh: employee['speedWarningThresholdKmh'] is int ? employee['speedWarningThresholdKmh'] : 100,
      enableSpeedMonitoring: employee['enableSpeedMonitoring'] ?? true,
    );
  }
}

// Auth state notifier
class AuthNotifier extends AsyncNotifier<UserData?> {
  @override
  Future<UserData?> build() async {
    final client = ref.read(apiClientProvider);
    final token = await client.getToken();
    if (token == null) return null;

    // Token exists — try to restore session by fetching profile
    try {
      final profileRepo = ProfileRepository(client);
      final profile = await profileRepo.getProfile();
      final userData = UserData.fromJson(profile);
      ref.read(localeProvider.notifier).state = Locale(userData.language);
      // Save speed settings locally for background service
      await SpeedSettings.save(
        speedLimitKmh: userData.speedLimitKmh.toDouble(),
        speedWarningKmh: userData.speedWarningThresholdKmh.toDouble(),
      );
      _registerFcmToken();
      LocationTrackingService.instance.start();
      try { await BackgroundSpeedService.startMonitoring(); } catch (_) {}
      return userData;
    } catch (_) {
      // Token expired — the interceptor will try refresh automatically
      // If refresh also fails, interceptor clears tokens
      // Return null to show login screen
      await client.clearTokens();
      return null;
    }
  }

  Future<void> login(String phoneNumber, String password) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final client = ref.read(apiClientProvider);

      final data = await repo.login(phoneNumber, password);

      // Save tokens
      await client.saveTokens(
        data['token'] as String,
        data['refreshToken'] as String,
      );

      // Parse user data
      final userData = UserData.fromJson(data);

      // Update locale based on user language preference
      ref.read(localeProvider.notifier).state = Locale(userData.language);

      // Save speed settings locally for background service
      await SpeedSettings.save(
        speedLimitKmh: userData.speedLimitKmh.toDouble(),
        speedWarningKmh: userData.speedWarningThresholdKmh.toDouble(),
      );

      state = AsyncValue.data(userData);

      // Start location + speed tracking (handles both admin map + speed monitoring)
      LocationTrackingService.instance.start();
      // Start background service for when app goes to background
      try { await BackgroundSpeedService.startMonitoring(); } catch (_) {}

      // Register FCM token (fire-and-forget — don't block login)
      _registerFcmToken();
    } catch (e, _) {
      // Set state back to data(null) instead of error to avoid triggering
      // a router rebuild that would recreate the LoginScreen and lose the
      // error message. The LoginScreen catches the rethrown error itself.
      state = const AsyncValue.data(null);
      rethrow;
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        final profileRepo = ProfileRepository(ref.read(apiClientProvider));
        await profileRepo.registerFcmToken(fcmToken);
      }
    } catch (_) {
      // Silently fail — FCM not configured or permission denied
    }
  }

  Future<void> logout() async {
    try {
      await LocationTrackingService.instance.stop();
      await BackgroundSpeedService.stopMonitoring();
      await SpeedSettings.clear();
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
    } catch (_) {
      // Clear tokens even if API call fails
      final client = ref.read(apiClientProvider);
      await client.clearTokens();
    }
    state = const AsyncValue.data(null);
  }

  void updateLocale(String languageCode) {
    ref.read(localeProvider.notifier).state = Locale(languageCode);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserData?>(() {
  return AuthNotifier();
});
