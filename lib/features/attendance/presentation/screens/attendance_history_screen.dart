import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/attendance_provider.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends ConsumerState<AttendanceHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _records = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_isLoading || !_hasMore) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final data = await repo.getHistory(page: _currentPage, pageSize: 20);

      final rawData = data['data'];
      final List items;
      if (rawData is List) {
        items = rawData;
      } else if (rawData is Map) {
        items = (rawData['records'] ?? []) as List;
      } else {
        items = [];
      }

      final pagination = data['pagination'] as Map<String, dynamic>?;
      final totalPages = pagination?['totalPages'] as int? ?? 1;

      setState(() {
        _records.addAll(items.cast<Map<String, dynamic>>());
        _hasMore = _currentPage < totalPages;
        _currentPage++;
        _isLoading = false;
        _initialLoad = false;
      });
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).errorOccurred;
        _isLoading = false;
        _initialLoad = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _records.clear();
      _currentPage = 1;
      _hasMore = true;
      _error = null;
    });
    await _loadPage();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _localizeStatus(String status, AppLocalizations l10n) {
    switch (status) {
      case 'OnTime':
        return l10n.onTime;
      case 'Late':
        return l10n.late;
      case 'Absent':
        return l10n.absent;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.attendanceHistory)),
      body: _initialLoad && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty && _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.errorOccurred),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _refresh, child: Text(l10n.retry)),
                    ],
                  ),
                )
              : _records.isEmpty
                  ? EmptyState(icon: Icons.calendar_today, message: l10n.noData)
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == _records.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final record = _records[index];
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
                                          _formatDate(record['attendanceDate'] ?? record['date'] ?? record['checkInTime']?.toString()),
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
                                          _localizeStatus(status, l10n),
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
                      ),
                    ),
    );
  }
}
