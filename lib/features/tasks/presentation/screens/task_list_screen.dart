import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/task_provider.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return AppColors.danger;
      case 'High':
        return const Color(0xFFEA580C);
      case 'Medium':
        return AppColors.warning;
      case 'Low':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  String _priorityLabel(String priority, AppLocalizations l10n) {
    switch (priority) {
      case 'Urgent':
        return l10n.priorityUrgent;
      case 'High':
        return l10n.priorityHigh;
      case 'Medium':
        return l10n.priorityMedium;
      case 'Low':
        return l10n.priorityLow;
      default:
        return priority;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'InProgress':
        return AppColors.info;
      case 'Paused':
        return AppColors.warning;
      case 'Completed':
        return AppColors.success;
      case 'Cancelled':
        return AppColors.textSecondary;
      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'Pending':
        return l10n.pending;
      case 'InProgress':
        return l10n.inProgress;
      case 'Paused':
        return l10n.paused;
      case 'Completed':
        return l10n.completed;
      case 'Cancelled':
        return l10n.cancelled;
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'InProgress':
        return Icons.play_circle_fill;
      case 'Paused':
        return Icons.pause_circle_filled;
      case 'Completed':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(todayTasksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.todaysTasks)),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.errorOccurred),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(todayTasksProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.task_alt, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(l10n.noData, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          // Sort: InProgress first, then Paused, then Pending, then by priority
          final priorityOrder = {'Urgent': 0, 'High': 1, 'Medium': 2, 'Low': 3};
          final statusOrder = {'InProgress': 0, 'Paused': 1, 'Pending': 2, 'Completed': 3, 'Cancelled': 4};
          final sorted = List<Map<String, dynamic>>.from(tasks)
            ..sort((a, b) {
              final sa = statusOrder[a['status'] ?? ''] ?? 9;
              final sb = statusOrder[b['status'] ?? ''] ?? 9;
              if (sa != sb) return sa.compareTo(sb);
              final pa = priorityOrder[a['priority'] ?? ''] ?? 9;
              final pb = priorityOrder[b['priority'] ?? ''] ?? 9;
              return pa.compareTo(pb);
            });

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todayTasksProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = sorted[index];
                final status = task['status'] ?? 'Pending';
                final priority = task['priority'] ?? 'Medium';
                final estimatedMin = task['estimatedMinutes'] as int? ?? 0;

                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push('/tasks/${task['id']}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(_statusIcon(status), color: _statusColor(status), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['title'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        task['locationName'] ?? '-',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (estimatedMin > 0) ...[
                                      const SizedBox(width: 12),
                                      const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$estimatedMin ${l10n.minutes}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _priorityColor(priority).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _priorityLabel(priority, l10n),
                                  style: TextStyle(
                                    color: _priorityColor(priority),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _statusLabel(status, l10n),
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
