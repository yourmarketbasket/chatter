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
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final now = DateTime.now();
    final difference = now.difference(widget.timestamp);

    Duration period = const Duration(minutes: 1); // Default update interval
    if (difference.inSeconds < 60) {
      period = const Duration(seconds: 1);
    } else if (difference.inMinutes < 60) {
      period = const Duration(seconds: 30);
    }

    _timer = Timer.periodic(period, (Timer t) {
      if (mounted) {
        _updateTime();
        // Check if we need to adjust the timer interval
        final newDifference = DateTime.now().difference(widget.timestamp);
        if (newDifference.inSeconds >= 60 && period.inSeconds < 30) {
          _startTimer(); // Reschedule with a new interval
        } else if (newDifference.inMinutes >= 60 && period.inSeconds < 60) {
          _startTimer(); // Reschedule with a new interval
        }
      } else {
        t.cancel();
      }
    });
  }

  void _updateTime() {
    setState(() {
      _relativeTime = timeago.format(widget.timestamp);
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
