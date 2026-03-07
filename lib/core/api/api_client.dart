import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: Duration(seconds: ApiConstants.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: ApiConstants.receiveTimeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(_AuthInterceptor(_storage, _dio));
  }

  Dio get dio => _dio;

  Future<void> saveTokens(String token, String refreshToken) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;
  bool _isRefreshing = false;

  static const _tokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await _storage.read(key: _refreshTokenKey);
        if (refreshToken == null) {
          _isRefreshing = false;
          handler.next(err);
          return;
        }

        // Attempt token refresh
        final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
        final response = await refreshDio.post(
          ApiConstants.refresh,
          data: {'refreshToken': refreshToken},
        );

        final newToken = response.data['data']['token'] as String;
        final newRefreshToken = response.data['data']['refreshToken'] as String;

        await _storage.write(key: _tokenKey, value: newToken);
        await _storage.write(key: _refreshTokenKey, value: newRefreshToken);

        // Retry original request with new token
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newToken';
        final retryResponse = await _dio.fetch(retryOptions);

        _isRefreshing = false;
        handler.resolve(retryResponse);
      } catch (_) {
        _isRefreshing = false;
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _refreshTokenKey);
        // Signal app to navigate to login
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}
