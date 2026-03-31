import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';

class SpeedLogRepository {
  final ApiClient _client;
  SpeedLogRepository(this._client);

  /// Batch upload speed readings to the server.
  /// taskId is included per reading if available.
  Future<Map<String, dynamic>> uploadBatch({
    required List<Map<String, dynamic>> readings,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.speedLogsBatch,
      data: {
        'readings': readings.map((r) => {
          'recordedAt': r['recordedAt'],
          'speedKmh': r['speedKmh'],
          'latitude': r['latitude'],
          'longitude': r['longitude'],
          if (r['taskId'] != null) 'taskId': int.tryParse(r['taskId'].toString()),
        }).toList(),
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }
}
