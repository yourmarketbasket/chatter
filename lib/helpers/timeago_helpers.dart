import 'package:timeago/timeago.dart' as timeago;

class EnShortHrAgoMessages implements timeago.LookupMessages {
  @override String prefixAgo() => '';
  @override String prefixFromNow() => '';
  @override String suffixAgo() => ' ago';
  @override String suffixFromNow() => ' from now';
  @override String lessThanOneMinute(int seconds) => 'now';
  @override String aboutAMinute(int minutes) => '1m';
  @override String minutes(int minutes) => '${minutes}m';
  @override String aboutAnHour(int minutes) => '~1hr';
  @override String hours(int hours) => '${hours}hr';
  @override String aDay(int hours) => '~1d';
  @override String days(int days) => '${days}d';
  @override String aboutAMonth(int days) => '~1mo';
  @override String months(int months) => '${months}mo';
  @override String aboutAYear(int year) => '~1y';
  @override String years(int years) => '${years}y';
  @override String wordSeparator() => ' ';
}
