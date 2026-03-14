import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/api/api_client.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/auth_repository.dart';

// Secure storage provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
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

  UserData({
    required this.id,
    required this.fullName,
    required this.role,
    required this.language,
    this.profilePhotoUrl,
    required this.companyId,
    required this.companyName,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>? ?? json;
    return UserData(
      id: employee['id'] is int ? employee['id'] : 0,
      fullName: employee['fullName'] ?? employee['fullNameEn'] ?? '',
      role: employee['role'] ?? 'Employee',
      language: employee['language'] ?? 'en',
      profilePhotoUrl: employee['profilePhotoUrl'],
      companyId: employee['companyId'] is int ? employee['companyId'] : 0,
      companyName: employee['companyName'] ?? employee['companyNameEn'] ?? '',
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
    // Token exists — user was previously logged in
    // We don't have the user data cached, so return a minimal placeholder
    // A full profile fetch will happen on the home screen
    return null;
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

      state = AsyncValue.data(userData);

      // Register FCM token (fire-and-forget — don't block login)
      _registerFcmToken();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
