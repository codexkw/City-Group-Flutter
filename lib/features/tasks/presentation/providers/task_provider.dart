import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.read(apiClientProvider));
});

final todayTasksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(taskRepositoryProvider);
  return repo.getToday();
});

final taskDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.read(taskRepositoryProvider);
  return repo.getById(id);
});
