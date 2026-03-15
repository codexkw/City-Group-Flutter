import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';

class ProfileRepository {
  final ApiClient _client;
  ProfileRepository(this._client);

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.dio.get(ApiConstants.profile);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> updateProfile({String? email, String? profilePhotoBase64}) async {
    await _client.dio.put(
      ApiConstants.profile,
      data: {
        if (email != null) 'email': email,
        if (profilePhotoBase64 != null) 'photoBase64': profilePhotoBase64,
      },
    );
  }

  Future<void> updateLanguage(String language) async {
    await _client.dio.put(
      ApiConstants.profileLanguage,
      data: {'language': language},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _client.dio.put(
      ApiConstants.profilePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<void> registerFcmToken(String fcmToken) async {
    await _client.dio.put(
      ApiConstants.profileFcmToken,
      data: {'fcmToken': fcmToken},
    );
  }
}
