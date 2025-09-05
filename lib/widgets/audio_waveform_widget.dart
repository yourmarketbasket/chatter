import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _isPreparing = true;

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
     _playerController.onCompletion.listen((_) {
      if (mounted) {
        _playerController.seekTo(0);
        setState(() {
          _isPlaying = false;
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
      try {
        final dio = Dio();
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/${widget.audioPath.split('/').last}';
        await dio.download(widget.audioPath, tempPath);
        await _playerController.preparePlayer(
          path: tempPath,
          shouldExtractWaveform: true,
        );
      } catch (e) {
        print('Error preparing network audio: $e');
        // Handle error, e.g., show a snackbar
      }
    }
    if (mounted) {
      setState(() {
        _isPreparing = false;
      });
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
            icon: _isPreparing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: _isPreparing
                ? null
                : () async {
                    if (_isPlaying) {
                      await _playerController.pausePlayer();
                    } else {
                      await _playerController.startPlayer(finishMode: FinishMode.stop);
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
