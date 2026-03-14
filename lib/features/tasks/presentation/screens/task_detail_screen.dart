import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/kuwait_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/task_provider.dart';
import 'pause_reason_bottom_sheet.dart';
import 'task_complete_modal.dart';

String _localizedTaskTitle(Map<String, dynamic> task, String locale) {
  if (locale == 'ar' && task['titleAr'] != null && (task['titleAr'] as String).isNotEmpty) {
    return task['titleAr'];
  }
  if (locale == 'hi' && task['titleHi'] != null && (task['titleHi'] as String).isNotEmpty) {
    return task['titleHi'];
  }
  return task['titleEn'] ?? task['title'] ?? '-';
}

String _localizedTaskDesc(Map<String, dynamic> task, String locale) {
  if (locale == 'ar' && task['descriptionAr'] != null && (task['descriptionAr'] as String).isNotEmpty) {
    return task['descriptionAr'];
  }
  if (locale == 'hi' && task['descriptionHi'] != null && (task['descriptionHi'] as String).isNotEmpty) {
    return task['descriptionHi'];
  }
  return task['descriptionEn'] ?? task['description'] ?? '';
}

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isActioning = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int initialSeconds) {
    _elapsedSeconds = initialSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<Position?> _getPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleStart() async {
    setState(() { _isActioning = true; _error = null; });
    final pos = await _getPosition();
    if (pos == null) {
      setState(() { _error = AppLocalizations.of(context).failedToGetLocation; _isActioning = false; });
      return;
    }
    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.start(widget.taskId, latitude: pos.latitude, longitude: pos.longitude, accuracy: pos.accuracy);
      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(todayTasksProvider);
    } on DioException catch (e) {
      setState(() => _error = extractErrorMessage(e, AppLocalizations.of(context)));
    } catch (e) {
      setState(() => _error = extractErrorMessage(e, AppLocalizations.of(context)));
    }
    setState(() => _isActioning = false);
  }

  Future<void> _handlePause() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const PauseReasonBottomSheet(),
    );
    if (result == null) return;

    setState(() { _isActioning = true; _error = null; });
    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.pause(
        widget.taskId,
        pauseReason: result['pauseReason']!,
        pauseReasonText: result['pauseReasonText'],
      );
      _stopTimer();
      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(todayTasksProvider);
    } on DioException catch (e) {
      setState(() => _error = extractErrorMessage(e, AppLocalizations.of(context)));
    } catch (e) {
      setState(() => _error = extractErrorMessage(e, AppLocalizations.of(context)));
    }
    setState(() => _isActioning = false);
  }

  Future<void> _handleResume() async {
    setState(() { _isActioning = true; _error = null; });
    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.resume(widget.taskId);
      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(todayTasksProvider);
    } on DioException catch (e) {
      setState(() => _error = extractErrorMessage(e, AppLocalizations.of(context)));
    } catch (e) {
      setState(() => _error = extractErrorMessage(e, AppLocalizations.of(context)));
    }
    setState(() => _isActioning = false);
  }

  Future<void> _handleComplete(Map<String, dynamic> task) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskCompleteModal(requirePhoto: task['requirePhoto'] == true),
    );
    if (result == null) return;

    setState(() { _isActioning = true; _error = null; });
    final pos = await _getPosition();
    if (pos == null) {
      setState(() { _error = AppLocalizations.of(context).failedToGetLocation; _isActioning = false; });
      return;
    }
    try {
      final repo = ref.read(taskRepositoryProvider);
      await repo.complete(
        widget.taskId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        completionNotes: result['notes'] as String?,
        photos: (result['photos'] as List?)?.cast<String>(),
      );
      _stopTimer();
      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(todayTasksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).taskCompleted), backgroundColor: AppColors.success),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.pop();
      }
    } on DioException catch (e) {
      setState(() => _error = extractErrorMessage(e, AppLocalizations.of(context)));
    } catch (e) {
      setState(() => _error = extractErrorMessage(e, AppLocalizations.of(context)));
    }
    setState(() => _isActioning = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.taskDetails)),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.errorOccurred),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(taskDetailProvider(widget.taskId)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (task) {
          final status = task['status'] ?? 'Pending';
          final priority = task['priority'] ?? 'Medium';
          final elapsed = task['elapsedSeconds'] as int? ?? 0;

          // Start timer if in progress
          if (status == 'InProgress' && _timer == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer(elapsed));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title + Priority
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _localizedTaskTitle(task, Localizations.localeOf(context).languageCode),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            _PriorityBadge(priority: priority, l10n: l10n),
                          ],
                        ),
                        if (_localizedTaskDesc(task, Localizations.localeOf(context).languageCode).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(l10n.description, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(_localizedTaskDesc(task, Localizations.localeOf(context).languageCode), style: const TextStyle(fontSize: 14)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Timer card (visible when InProgress)
                if (status == 'InProgress') ...[
                  Card(
                    color: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Text(l10n.elapsed, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                            _formatElapsed(_elapsedSeconds),
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Info rows
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _InfoRow(label: l10n.status, value: _statusLabel(status, l10n)),
                        const Divider(height: 20),
                        _InfoRow(
                          label: l10n.location,
                          value: task['location']?['name'] ?? task['locationName'] ?? '-',
                        ),
                        if (task['estimatedDurationMinutes'] != null) ...[
                          const Divider(height: 20),
                          _InfoRow(label: l10n.estimated, value: '${task['estimatedDurationMinutes']} ${l10n.minutes}'),
                        ],
                        if (task['dueDate'] != null) ...[
                          const Divider(height: 20),
                          _InfoRow(
                            label: l10n.dueTime,
                            value: KuwaitTime.format(task['dueDate'] as String?),
                          ),
                        ],
                        if (task['pausedDurationMinutes'] != null && (task['pausedDurationMinutes'] as num) > 0) ...[
                          const Divider(height: 20),
                          _InfoRow(label: l10n.paused, value: '${task['pausedDurationMinutes']} ${l10n.minutes}'),
                        ],
                        if (task['requirePhoto'] == true) ...[
                          const Divider(height: 20),
                          _InfoRow(label: l10n.requiresPhoto, value: '', icon: Icons.camera_alt),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Error
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ),

                // Action buttons
                if (status == 'Pending')
                  ElevatedButton.icon(
                    onPressed: _isActioning ? null : _handleStart,
                    icon: _isActioning
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow),
                    label: Text(l10n.startTask),
                  ),

                if (status == 'InProgress') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActioning ? null : _handlePause,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                          icon: const Icon(Icons.pause),
                          label: Text(l10n.pauseTask),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActioning ? null : () => _handleComplete(task),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                          icon: const Icon(Icons.check),
                          label: Text(l10n.completeTask),
                        ),
                      ),
                    ],
                  ),
                ],

                if (status == 'Paused')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActioning ? null : _handleResume,
                          icon: _isActioning
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.play_arrow),
                          label: Text(l10n.resumeTask),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActioning ? null : () => _handleComplete(task),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                          icon: const Icon(Icons.check),
                          label: Text(l10n.completeTask),
                        ),
                      ),
                    ],
                  ),

                if (status == 'Completed')
                  Card(
                    color: AppColors.success.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success),
                          const SizedBox(width: 8),
                          Text(l10n.taskCompleted, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
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
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  final AppLocalizations l10n;
  const _PriorityBadge({required this.priority, required this.l10n});

  Color get _color {
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

  String get _label {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_label, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const _InfoRow({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        if (icon != null)
          Icon(icon, color: AppColors.primary, size: 20)
        else
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
