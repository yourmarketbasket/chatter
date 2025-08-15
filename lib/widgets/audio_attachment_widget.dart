import 'dart:async';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/services/media_visibility_service.dart'; // Import MediaVisibilityService
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String? _duration;

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
        final file = File(_localFilePath!);

        // Download only if the file doesn't exist
        if (!await file.exists()) {
          final dio = Dio();
          await dio.download(audioUrlString, _localFilePath!);
        }

        await playerController.preparePlayer(path: _localFilePath!);
        final durationMs = await playerController.getDuration();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _duration = _formatDuration(durationMs);
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

  String _formatDuration(int? milliseconds) {
    if (milliseconds == null) return "0:00";
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    if (_localFilePath == null) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: Icon(Icons.error, color: Colors.redAccent),
        ),
      );
    }

    final userAvatar = widget.post['useravatar'] as String?;
    final username = widget.post['username'] as String? ?? 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      constraints: const BoxConstraints(minHeight: 50),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: playerController.onPlayerStateChanged,
            builder: (context, snapshot) {
              final playerState = snapshot.data ?? PlayerState.stopped;
              final isPlaying = playerState.isPlaying;
              return Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                        ? CachedNetworkImageProvider(userAvatar)
                        : null,
                    backgroundColor: Colors.tealAccent.withOpacity(0.3),
                    child: (userAvatar == null || userAvatar.isEmpty)
                        ? Text(username[0].toUpperCase(), style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  // Play/Pause button overlay
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () async {
                        if (isPlaying) {
                          await playerController.pausePlayer();
                        } else {
                          await playerController.startPlayer(finishMode: FinishMode.stop);
                        }
                      },
                      icon: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AudioFileWaveforms(
                  size: Size(MediaQuery.of(context).size.width, 30.0),
                  playerController: playerController,
                  playerWaveStyle: const PlayerWaveStyle(
                    fixedWaveColor: Colors.white54,
                    liveWaveColor: Colors.tealAccent,
                    spacing: 5.0,
                    showSeekLine: true,
                    seekLineColor: Colors.tealAccent,
                  ),
                  waveformType: WaveformType.long,
                  continuousWaveform: true,
                ),
                const SizedBox(height: 4),
                 if (_duration != null)
                  Text(
                    _duration!,
                    style: GoogleFonts.roboto(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
