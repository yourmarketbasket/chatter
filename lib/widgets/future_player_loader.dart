import 'dart:io';
import 'package:flutter/material.dart';
import 'video_player_factory.dart';

class FuturePlayerLoader extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;
  final double? videoAspectRatioProp;

  const FuturePlayerLoader({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    this.videoAspectRatioProp,
  }) : super(key: key);

  @override
  _FuturePlayerLoaderState createState() => _FuturePlayerLoaderState();
}

class _FuturePlayerLoaderState extends State<FuturePlayerLoader> {
  Widget? _playerWidget;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() async {
    final player = await VideoPlayerFactory.createPlayer(
      url: widget.url,
      file: widget.file,
      displayPath: widget.displayPath,
      videoAspectRatioProp: widget.videoAspectRatioProp,
    );
    if (mounted) {
      setState(() {
        _playerWidget = player;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _playerWidget ?? const Center(child: CircularProgressIndicator());
  }
}
