import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.read(apiClientProvider));
});

final locationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(attendanceRepositoryProvider);
  return repo.getLocations();
});

final todayAttendanceProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.read(attendanceRepositoryProvider);
  try {
    return await repo.getToday();
  } catch (_) {
    return null;
  }
});
