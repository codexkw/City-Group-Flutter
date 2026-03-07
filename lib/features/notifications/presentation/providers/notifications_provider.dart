import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(apiClientProvider));
});

final notificationsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, page) async {
  final repo = ref.read(notificationsRepositoryProvider);
  return repo.getAll(page: page);
});
