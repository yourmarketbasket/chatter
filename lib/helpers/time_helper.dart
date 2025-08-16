import 'package:intl/intl.dart';

class TimeHelper {
  static String getFormattedTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToFormat = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToFormat == today) {
      return DateFormat.jm().format(dateTime); // e.g., 5:08 PM
    } else if (dateToFormat == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yy').format(dateTime); // e.g., 23/07/24
    }
  }

  static String formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
