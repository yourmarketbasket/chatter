import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class VoiceNotePreviewDialog extends StatefulWidget {
  final String audioPath;
  final Function(Duration) onSend;

  const VoiceNotePreviewDialog({
    super.key,
    required this.audioPath,
    required this.onSend,
  });

  @override
  State<VoiceNotePreviewDialog> createState() => _VoiceNotePreviewDialogState();
}

class _VoiceNotePreviewDialogState extends State<VoiceNotePreviewDialog> {
  final PlayerController _playerController = PlayerController();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _playerController.preparePlayer(
      path: widget.audioPath,
      shouldExtractWaveform: true,
    ).then((_) {
      _playerController.getDuration(DurationType.max).then((duration) {
        if (mounted) {
          setState(() {
            _duration = Duration(milliseconds: duration);
          });
        }
      });
    });

    _playerController.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Voice Note?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AudioFileWaveforms(
            size: Size(MediaQuery.of(context).size.width * 0.5, 50),
            playerController: _playerController,
            enableSeekGesture: true,
            playerWaveStyle: const PlayerWaveStyle(
              fixedWaveColor: Colors.white54,
              liveWaveColor: Colors.white,
              spacing: 6,
            ),
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (_isPlaying) {
                _playerController.pausePlayer();
              } else {
                _playerController.startPlayer();
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => widget.onSend(_duration),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
