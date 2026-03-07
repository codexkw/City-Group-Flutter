import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';

class TaskRepository {
  final ApiClient _client;
  TaskRepository(this._client);

  Future<List<Map<String, dynamic>>> getToday() async {
    final response = await _client.dio.get(ApiConstants.tasksToday);
    final data = response.data['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final response = await _client.dio.get(ApiConstants.taskById(id));
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> start(String id, {
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.taskStart(id),
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pause(String id, {
    required String pauseReason,
    String? pauseReasonText,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.taskPause(id),
      data: {
        'pauseReason': pauseReason,
        if (pauseReasonText != null) 'pauseReasonText': pauseReasonText,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resume(String id) async {
    final response = await _client.dio.post(ApiConstants.taskResume(id));
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> complete(String id, {
    required double latitude,
    required double longitude,
    required double accuracy,
    String? completionNotes,
    List<String>? photos,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.taskComplete(id),
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        if (completionNotes != null) 'completionNotes': completionNotes,
        if (photos != null) 'photos': photos,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }
}
