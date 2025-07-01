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
    setState(() {
      _relativeTime = timeago.format(widget.timestamp, locale: 'en_short');
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
