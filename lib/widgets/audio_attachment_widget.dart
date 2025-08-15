import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/services/media_visibility_service.dart'; // Import MediaVisibilityService
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart'; // Import VisibilityDetector

class AudioAttachmentWidget extends StatefulWidget {
  final Map<String, dynamic> attachment;
  final Map<String, dynamic> post;
  final BorderRadius borderRadius;

  const AudioAttachmentWidget({
    required Key key,
    required this.attachment,
    required this.post,
    required this.borderRadius,
  }) : super(key: key);

  @override
  _AudioAttachmentWidgetState createState() => _AudioAttachmentWidgetState();
}

class _AudioAttachmentWidgetState extends State<AudioAttachmentWidget> {
  late PlayerController playerController;
  String? _localFilePath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    playerController = PlayerController();
    _downloadAndPreparePlayer();
  }

  Future<void> _downloadAndPreparePlayer() async {
    final String? audioUrlString = widget.attachment['url'] as String?;
    if (audioUrlString != null && audioUrlString.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final filename = audioUrlString.split('/').last;
        _localFilePath = '${tempDir.path}/$filename';
        final dio = Dio();
        await dio.download(audioUrlString, _localFilePath!);
        await playerController.preparePlayer(path: _localFilePath!);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error downloading or preparing audio: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_localFilePath == null) {
      return Container(
        height: 50,
        child: Center(
          child: Icon(Icons.error),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: playerController.onPlayerStateChanged,
            builder: (context, snapshot) {
              final playerState = snapshot.data ?? PlayerState.stopped;
              return IconButton(
                onPressed: () async {
                  if (playerState.isPlaying) {
                    await playerController.pausePlayer();
                  } else {
                    await playerController.startPlayer(finishMode: FinishMode.stop);
                  }
                },
                icon: Icon(
                  playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              );
            },
          ),
          Expanded(
            child: AudioFileWaveforms(
              size: Size(MediaQuery.of(context).size.width, 50.0),
              playerController: playerController,
              playerWaveStyle: const PlayerWaveStyle(
                fixedWaveColor: Colors.white54,
                liveWaveColor: Colors.white,
                spacing: 6.0,
                showSeekLine: false,
              ),
              waveformType: WaveformType.long,
              continuousWaveform: true,
            ),
          ),
        ],
      ),
    );
  }
}
