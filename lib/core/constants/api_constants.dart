class ApiConstants {
  ApiConstants._();

  // ── Base URLs ──────────────────────────────────────────────
  static const String baseUrl = 'https://api-city-group.codexkw.co/api/v1';
  static const String adminBaseUrl = 'https://city-group.codexkw.co';

  // ── Timeouts ───────────────────────────────────────────────
  static const int connectTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 60;

  // ── Auth endpoints ─────────────────────────────────────────
  static const String login = '/auth/login';
  static const String adminLogin = '/auth/admin-login';
  static const String refresh = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String logout = '/auth/logout';

  // ── Attendance endpoints ───────────────────────────────────
  static const String checkIn = '/attendance/check-in';
  static const String checkOut = '/attendance/check-out';
  static const String attendanceHistory = '/attendance/history';
  static const String attendanceToday = '/attendance/today';

  // ── Task endpoints ─────────────────────────────────────────
  static const String tasksToday = '/tasks/today';
  static const String tasks = '/tasks';
  static String taskById(String id) => '/tasks/$id';
  static String taskStart(String id) => '/tasks/$id/start';
  static String taskPause(String id) => '/tasks/$id/pause';
  static String taskResume(String id) => '/tasks/$id/resume';
  static String taskComplete(String id) => '/tasks/$id/complete';
  static String taskHistory(String id) => '/tasks/$id/history';

  // ── Employee endpoints ─────────────────────────────────────
  static const String employees = '/employees';
  static String employeeById(String id) => '/employees/$id';

  // ── Location endpoints ─────────────────────────────────────
  static const String locations = '/locations';

  // ── Speed monitoring endpoints ─────────────────────────────
  static const String speedLogsBatch = '/speed-logs/batch';

  // ── Notification endpoints ─────────────────────────────────
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';

  // ── Profile endpoints ──────────────────────────────────────
  static const String profile = '/profile';
  static const String profileLanguage = '/profile/language';
  static const String profilePassword = '/profile/password';
  static const String profileFcmToken = '/profile/fcm-token';
  static const String profileLocation = '/profile/location';
}
