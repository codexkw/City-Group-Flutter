/// Kuwait timezone helper.
/// Note: The server clock is already set to Kuwait time (UTC+3),
/// so API dates are effectively in Kuwait local time. No offset needed.
class KuwaitTime {
  /// Returns the DateTime as-is (server already stores Kuwait time).
  static DateTime fromUtc(DateTime dt) => dt;

  /// Parses an ISO 8601 string from the API (already in Kuwait time).
  static DateTime? parse(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    return DateTime.tryParse(dateStr);
  }

  /// Gets the current time (effectively Kuwait time since server matches).
  static DateTime get now => DateTime.now();

  /// Formats a date string from the API to display format.
  static String format(String? dateStr) {
    final dt = parse(dateStr);
    if (dt == null) return '-';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} ${_pad(h)}:${_pad(dt.minute)} $ampm';
  }

  /// Formats just the date part.
  static String formatDate(String? dateStr) {
    final dt = parse(dateStr);
    if (dt == null) return '-';
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  }

  /// Formats just the time part.
  static String formatTime(String? dateStr) {
    final dt = parse(dateStr);
    if (dt == null) return '-';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_pad(h)}:${_pad(dt.minute)} $ampm';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
