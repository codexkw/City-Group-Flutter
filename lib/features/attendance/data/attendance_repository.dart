import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';

class AttendanceRepository {
  final ApiClient _client;
  AttendanceRepository(this._client);

  Future<Map<String, dynamic>> checkIn({
    int? locationId,
    required double latitude,
    required double longitude,
    required double accuracy,
    String? photoBase64,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.checkIn,
      data: {
        if (locationId != null) 'locationId': locationId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        if (photoBase64 != null) 'photoBase64': photoBase64,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    required double accuracy,
    String? photoBase64,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.checkOut,
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        if (photoBase64 != null) 'photoBase64': photoBase64,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getToday() async {
    final response = await _client.dio.get(ApiConstants.attendanceToday);
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int pageSize = 20,
    String? from,
    String? to,
    String? status,
  }) async {
    final response = await _client.dio.get(
      ApiConstants.attendanceHistory,
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (status != null) 'status': status,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getLocations() async {
    final response = await _client.dio.get(ApiConstants.locations);
    final data = response.data['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
