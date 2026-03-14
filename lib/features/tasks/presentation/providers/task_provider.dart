import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.read(apiClientProvider));
});

/// Holds the current task filter state.
final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter());

class TaskFilter {
  final String? status;
  final DateTime? date;

  TaskFilter({this.status, this.date});

  TaskFilter copyWith({String? Function()? status, DateTime? Function()? date}) {
    return TaskFilter(
      status: status != null ? status() : this.status,
      date: date != null ? date() : this.date,
    );
  }
}

final todayTasksProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(taskRepositoryProvider);
  final filter = ref.watch(taskFilterProvider);
  return repo.getToday(status: filter.status, date: filter.date);
});

final taskDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.read(taskRepositoryProvider);
  return repo.getById(id);
});
