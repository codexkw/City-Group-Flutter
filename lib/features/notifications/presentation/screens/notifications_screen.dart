import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/kuwait_time.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'TaskAssigned':
        return Icons.assignment;
      case 'LateCheckIn':
        return Icons.access_time;
      case 'TaskOverdue':
        return Icons.warning_amber;
      case 'SpeedViolation':
        return Icons.speed;
      case 'System':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'TaskAssigned':
        return AppColors.primary;
      case 'LateCheckIn':
        return AppColors.warning;
      case 'TaskOverdue':
        return AppColors.danger;
      case 'SpeedViolation':
        return AppColors.danger;
      case 'System':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = KuwaitTime.parse(dateStr);
      if (dt == null) return '';
      final now = KuwaitTime.now;
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifAsync = ref.watch(notificationsProvider(1));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              final repo = ref.read(notificationsRepositoryProvider);
              await repo.markAllAsRead();
              ref.invalidate(notificationsProvider(1));
            },
            child: Text(l10n.markAllRead, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.errorOccurred),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(notificationsProvider(1)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (data) {
          final notifData = data['data'] as Map<String, dynamic>? ?? {};
          final notifications = (notifData['notifications'] ?? []) as List;

          if (notifications.isEmpty) {
            return EmptyState(icon: Icons.notifications_none, message: l10n.noNotifications);
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider(1)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final notif = notifications[index] as Map<String, dynamic>;
                final type = notif['type'] ?? 'System';
                final isRead = notif['isRead'] == true;

                return Card(
                  color: isRead ? null : AppColors.primary.withValues(alpha: 0.03),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      // Mark as read
                      if (!isRead && notif['id'] != null) {
                        final repo = ref.read(notificationsRepositoryProvider);
                        await repo.markAsRead(notif['id'].toString());
                        ref.invalidate(notificationsProvider(1));
                      }
                      // Deep link to task if applicable
                      if (type == 'TaskAssigned' || type == 'TaskOverdue') {
                        if (notif['referenceId'] != null && context.mounted) {
                          context.push('/tasks/${notif['referenceId']}');
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _typeColor(type).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_typeIcon(type), color: _typeColor(type), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['body'] ?? '',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(notif['createdAt']?.toString()),
                                  style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                                ),
                              ],
                            ),
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
