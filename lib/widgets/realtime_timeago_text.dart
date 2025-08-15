import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class RealtimeTimeagoText extends StatefulWidget {
  final DateTime timestamp;
  final TextStyle? style;

  const RealtimeTimeagoText({
    Key? key,
    required this.timestamp,
    this.style,
  }) : super(key: key);

  @override
  _RealtimeTimeagoTextState createState() => _RealtimeTimeagoTextState();
}

class _RealtimeTimeagoTextState extends State<RealtimeTimeagoText> {
  Timer? _timer;
  late String _relativeTime;

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Update every 30 seconds. This can be optimized later.
    _timer = Timer.periodic(const Duration(seconds: 30), (Timer t) {
      if (mounted) { // Check if the widget is still in the tree
        _updateTime();
      }
    });
  }

  void _updateTime() {
    // Custom short messages for timeago
    timeago.setLocaleMessages('en_custom', CustomShortMessages());
    setState(() {
      _relativeTime = timeago.format(widget.timestamp, locale: 'en_custom');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _relativeTime,
      style: widget.style,
    );
  }
}

class CustomShortMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => '';
  @override
  String suffixFromNow() => '';
  @override
  String lessThanOneMinute(int seconds) => 'now';
  @override
  String aboutAMinute(int minutes) => '1min';
  @override
  String minutes(int minutes) => '${minutes}min';
  @override
  String aboutAnHour(int minutes) => '1hr';
  @override
  String hours(int hours) => '${hours}hr';
  @override
  String aDay(int hours) => '1d';
  @override
  String days(int days) => '${days}d';
  @override
  String aboutAMonth(int days) => '1mo';
  @override
  String months(int months) => '${months}mo';
  @override
  String aboutAYear(int year) => '1y';
  @override
  String years(int years) => '${years}y';
  @override
  String wordSeparator() => ' ';
}
