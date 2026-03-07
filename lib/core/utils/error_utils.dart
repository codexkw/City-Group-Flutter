import 'package:dio/dio.dart';

import '../../../l10n/app_localizations.dart';

/// Extracts a user-friendly error message from any error object.
/// Handles DioException (API errors), connection errors, and generic errors.
String extractErrorMessage(Object error, AppLocalizations l10n) {
  if (error is DioException) {
    // Connection / timeout errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return l10n.noInternet;
    }

    // Server error response with standard envelope
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      // Standard API error: { "error": { "code": "...", "message": "..." } }
      final errorObj = data['error'];
      if (errorObj is Map<String, dynamic>) {
        final message = errorObj['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
      // Fallback: { "message": "..." }
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
    }

    // HTTP status code fallback
    final status = error.response?.statusCode;
    if (status != null) {
      if (status == 401) return l10n.loginError;
      if (status == 403) return l10n.errorOccurred;
      if (status == 404) return l10n.errorOccurred;
      if (status == 429) return 'Too many attempts. Please try again later.';
      if (status >= 500) return l10n.errorOccurred;
    }

    return l10n.errorOccurred;
  }

  // Non-Dio errors
  final msg = error.toString();
  if (msg.contains('SocketException') || msg.contains('NetworkError')) {
    return l10n.noInternet;
  }

  return l10n.errorOccurred;
}

/// Extracts the error code from a DioException response.
/// Returns null if not a DioException or no code present.
String? extractErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final errorObj = data['error'];
      if (errorObj is Map<String, dynamic>) {
        return errorObj['code'] as String?;
      }
    }
  }
  return null;
}
