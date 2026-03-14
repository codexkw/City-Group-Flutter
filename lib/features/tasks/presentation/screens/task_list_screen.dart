import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/kuwait_time.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/task_provider.dart';

String _localizedTitle(Map<String, dynamic> task, String locale) {
  if (locale == 'ar' && task['titleAr'] != null && (task['titleAr'] as String).isNotEmpty) {
    return task['titleAr'];
  }
  if (locale == 'hi' && task['titleHi'] != null && (task['titleHi'] as String).isNotEmpty) {
    return task['titleHi'];
  }
  return task['titleEn'] ?? task['title'] ?? '-';
}

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
    final filter = ref.watch(taskFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todaysTasks),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: filter.date ?? DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                ref.read(taskFilterProvider.notifier).state = filter.copyWith(date: () => picked);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          _FilterBar(filter: filter, ref: ref, l10n: l10n),

          // Task list
          Expanded(
            child: tasksAsync.when(
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
                  return EmptyState(icon: Icons.task_alt, message: l10n.noData);
                }

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
                      final estimatedMin = task['estimatedDurationMinutes'] as int? ?? 0;
                      final locale = Localizations.localeOf(context).languageCode;
                      final dueDate = task['dueDate'] as String?;

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
                                        _localizedTitle(task, locale),
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
                                      if (dueDate != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              KuwaitTime.format(dueDate),
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
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
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TaskFilter filter;
  final WidgetRef ref;
  final AppLocalizations l10n;

  const _FilterBar({required this.filter, required this.ref, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final statuses = ['Pending', 'InProgress', 'Paused', 'Completed'];
    final statusLabels = {
      'Pending': l10n.pending,
      'InProgress': l10n.inProgress,
      'Paused': l10n.paused,
      'Completed': l10n.completed,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date display + clear
          if (filter.date != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEE, MMM d, yyyy').format(filter.date!),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      ref.read(taskFilterProvider.notifier).state = filter.copyWith(date: () => null);
                    },
                    child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(
                  label: l10n.all,
                  selected: filter.status == null,
                  onTap: () {
                    ref.read(taskFilterProvider.notifier).state = filter.copyWith(status: () => null);
                  },
                ),
                const SizedBox(width: 8),
                ...statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildChip(
                    label: statusLabels[s] ?? s,
                    selected: filter.status == s,
                    onTap: () {
                      ref.read(taskFilterProvider.notifier).state = filter.copyWith(
                        status: () => filter.status == s ? null : s,
                      );
                    },
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
