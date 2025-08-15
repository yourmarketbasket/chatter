import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final WaveformController _waveformController;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _waveformController = WaveformController(
      initialWaveform: [],
      sampleRate: 44100,
      waveformType: WaveformType.live,
    )..extractWaveformData(widget.audioPath).then((_) {
      if (mounted) setState(() {});
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Voice Note?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AudioWaveforms(
            size: Size(MediaQuery.of(context).size.width * 0.5, 50),
            controller: _waveformController,
            enableGesture: true,
            waveStyle: const WaveStyle(
              waveColor: Colors.white,
              showDurationLabel: true,
              spacing: 8.0,
              showBottom: false,
              extendWaveform: true,
              showMiddleLine: false,
            ),
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (_isPlaying) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play(DeviceFileSource(widget.audioPath));
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
