import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';

class NotificationsRepository {
  final ApiClient _client;
  NotificationsRepository(this._client);

  Future<Map<String, dynamic>> getAll({int page = 1, int pageSize = 20}) async {
    final response = await _client.dio.get(
      ApiConstants.notifications,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> markAsRead(String id) async {
    await _client.dio.put(ApiConstants.notificationRead(id));
  }

  Future<void> markAllAsRead() async {
    await _client.dio.put(ApiConstants.notificationsReadAll);
  }
}
