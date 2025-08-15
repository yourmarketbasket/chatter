import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class AudioWaveformWidget extends StatefulWidget {
  final String audioPath;
  final bool isLocal;

  const AudioWaveformWidget({super.key, required this.audioPath, this.isLocal = true});

  @override
  _AudioWaveformWidgetState createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget> {
  final PlayerController _playerController = PlayerController();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _preparePlayer();
    _playerController.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  Future<void> _preparePlayer() async {
    if (widget.isLocal) {
      await _playerController.preparePlayer(
        path: widget.audioPath,
        shouldExtractWaveform: true,
      );
    } else {
      // TODO: Handle network audio. This requires downloading the file first.
      // For now, this will not work for network audio.
      // We can use dio to download to a temp path and then prepare.
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () {
              if (_isPlaying) {
                _playerController.pausePlayer();
              } else {
                _playerController.startPlayer();
              }
            },
          ),
          Expanded(
            child: AudioFileWaveforms(
              size: Size(MediaQuery.of(context).size.width * 0.5, 50),
              playerController: _playerController,
              enableSeekGesture: true,
              playerWaveStyle: const PlayerWaveStyle(
                fixedWaveColor: Colors.white54,
                liveWaveColor: Colors.tealAccent,
                spacing: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
