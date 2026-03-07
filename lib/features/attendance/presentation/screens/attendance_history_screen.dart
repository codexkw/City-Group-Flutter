import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/attendance_provider.dart';

final attendanceHistoryProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, page) async {
  final repo = ref.read(attendanceRepositoryProvider);
  return repo.getHistory(page: page);
});

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final historyAsync = ref.watch(attendanceHistoryProvider(1));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.attendanceHistory)),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.errorOccurred),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: () => ref.invalidate(attendanceHistoryProvider(1)), child: Text(l10n.retry)),
            ],
          ),
        ),
        data: (data) {
          final records = (data['data']?['records'] ?? data['data'] ?? []) as List;
          if (records.isEmpty) {
            return EmptyState(icon: Icons.calendar_today, message: l10n.noData);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final record = records[index] as Map<String, dynamic>;
              final status = record['status'] ?? '';
              final statusColor = status == 'OnTime'
                  ? AppColors.success
                  : status == 'Late'
                      ? AppColors.warning
                      : AppColors.danger;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 56,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record['date'] ?? record['checkInTime']?.toString().substring(0, 10) ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record['locationName'] ?? '-',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (record['totalHours'] != null)
                            Text(
                              '${(record['totalHours'] as num).toStringAsFixed(1)}h',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
