import 'package:intl/intl.dart';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Chat list: "11:20", "Yesterday", "Mon", "6 Oct", "6 Oct 2025".
String listTime(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (_sameDay(t, n)) return DateFormat.Hm().format(t);
  if (_sameDay(t, n.subtract(const Duration(days: 1)))) return 'Yesterday';
  if (n.difference(t).inDays < 7) return DateFormat.E().format(t);
  if (t.year == n.year) return DateFormat('d MMM').format(t);
  return DateFormat('d MMM y').format(t);
}

/// Under a message: "11:20".
String messageTime(DateTime t) => DateFormat.Hm().format(t);

/// Date divider: "Today", "Yesterday", "Monday, 6 Oct", "6 Oct 2025".
String dayLabel(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (_sameDay(t, n)) return 'Today';
  if (_sameDay(t, n.subtract(const Duration(days: 1)))) return 'Yesterday';
  if (t.year == n.year) return DateFormat('EEEE, d MMM').format(t);
  return DateFormat('d MMM y').format(t);
}

bool isSameDay(DateTime a, DateTime b) => _sameDay(a, b);

/// "2.4 MB", "820 KB", "12 B".
String fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb < 10 ? mb.toStringAsFixed(1) : mb.round()} MB';
}

/// "0:07", "1:32".
String duration(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "last seen today at 11:20" / "last seen yesterday" / "last seen 6 Oct".
String lastSeen(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (_sameDay(t, n)) return 'last seen today at ${DateFormat.Hm().format(t)}';
  if (_sameDay(t, n.subtract(const Duration(days: 1)))) {
    return 'last seen yesterday';
  }
  return 'last seen ${DateFormat('d MMM').format(t)}';
}
