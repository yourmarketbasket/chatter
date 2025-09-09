import 'package:intl/intl.dart';

String formatLastSeen(DateTime lastSeen) {
  final now = DateTime.now();
  final difference = now.difference(lastSeen);

  if (difference.inSeconds < 60) {
    return 'just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's'} ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hr${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inDays == 1) {
    return 'yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else {
    return DateFormat('MMM d, yyyy').format(lastSeen);
  }
}

String formatTime(DateTime time) {
  return DateFormat.Hm().format(time);
}