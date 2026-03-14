/// Kuwait timezone helper. Kuwait is UTC+3 with no daylight saving.
class KuwaitTime {
  static const Duration _offset = Duration(hours: 3);

  /// Converts a UTC DateTime to Kuwait time (UTC+3).
  static DateTime fromUtc(DateTime utc) => utc.add(_offset);

  /// Parses an ISO 8601 string from the API (assumed UTC) and converts to Kuwait time.
  static DateTime? parse(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return null;
    return fromUtc(dt.isUtc ? dt : dt.toUtc());
  }

  /// Gets the current time in Kuwait.
  static DateTime get now => DateTime.now().toUtc().add(_offset);

  /// Formats a UTC date string from the API to Kuwait time display.
  static String format(String? dateStr, {String pattern = 'yyyy-MM-dd hh:mm a'}) {
    final dt = parse(dateStr);
    if (dt == null) return '-';
    // Simple formatting without intl dependency
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
