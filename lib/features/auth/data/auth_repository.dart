import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';

class AuthRepository {
  final ApiClient _client;
  AuthRepository(this._client);

  Future<Map<String, dynamic>> login(String phoneNumber, String password) async {
    final response = await _client.dio.post(
      ApiConstants.login,
      data: {
        'phoneNumber': phoneNumber,
        'password': password,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _client.getRefreshToken();
      await _client.dio.post(
        ApiConstants.logout,
        data: {'refreshToken': refreshToken},
      );
    } finally {
      await _client.clearTokens();
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String phoneNumber) async {
    final response = await _client.dio.post(
      ApiConstants.forgotPassword,
      data: {'phoneNumber': phoneNumber},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> resetPassword({
    required String phoneNumber,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _client.dio.post(
      ApiConstants.resetPassword,
      data: {
        'phoneNumber': phoneNumber,
        'otp': otp,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }
}
