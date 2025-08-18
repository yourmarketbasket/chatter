import 'package:timeago/timeago.dart' as timeago;

class EnShortHrAgoMessages implements timeago.LookupMessages {
  @override String prefixAgo() => '';
  @override String prefixFromNow() => '';
  @override String suffixAgo() => '';
  @override String suffixFromNow() => '';
  @override String lessThanOneMinute(int seconds) => 'just now';
  @override String aboutAMinute(int minutes) => '1m ago';
  @override String minutes(int minutes) => '${minutes}m ago';
  @override String aboutAnHour(int minutes) => '~1hr ago';
  @override String hours(int hours) => '${hours}hr ago';
  @override String aDay(int hours) => '~1d ago';
  @override String days(int days) => '${days}d ago';
  @override String aboutAMonth(int days) => '~1mo ago';
  @override String months(int months) => '${months}mo ago';
  @override String aboutAYear(int year) => '~1y ago';
  @override String years(int years) => '${years}y ago';
  @override String wordSeparator() => ' ';
}
