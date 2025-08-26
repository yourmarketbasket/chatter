import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
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
  late AudioPlayer _audioPlayer;
  bool _isMuted = false;
  bool _isPlaying = false;
  PlayerState _playerState = PlayerState.stopped;

  final DataController _dataController = Get.find<DataController>();
  final MediaVisibilityService _mediaVisibilityService = Get.find<MediaVisibilityService>();
  String _audioId = ""; // Ensure initialized
  StreamSubscription? _playerStateSubscription;
  Worker? _currentlyPlayingMediaSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    // Ensure _audioId is definitively set
    _audioId = widget.attachment['url'] as String? ??
               (widget.key?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());

    final String? audioUrlString = widget.attachment['url'] as String?;

    if (audioUrlString != null && audioUrlString.isNotEmpty) {
      String finalAudioUrl = audioUrlString;
      if (audioUrlString.contains('res.cloudinary.com') &&
          audioUrlString.contains('/upload/') &&
          !audioUrlString.toLowerCase().endsWith('.mp3') &&
          !audioUrlString.toLowerCase().endsWith('.m4a') &&
          !audioUrlString.toLowerCase().endsWith('.wav') &&
          !audioUrlString.toLowerCase().endsWith('.ogg') &&
          !audioUrlString.contains('/f_')) {
        finalAudioUrl = audioUrlString.replaceAll('/upload/', '/upload/f_mp3/');
        print('[AudioAttachmentWidget-$_audioId] Applied Cloudinary f_mp3 transformation. New URL: $finalAudioUrl');
      } else {
        print('[AudioAttachmentWidget-$_audioId] Using audio URL as is: $finalAudioUrl');
      }

      _audioPlayer.setSourceUrl(finalAudioUrl).then((_) {
        print('[AudioAttachmentWidget-$_audioId] Source set successfully.');
      }).catchError((error) {
        print('[AudioAttachmentWidget-$_audioId] Error setting source: $error');
      });
      _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
    } else {
      print('[AudioAttachmentWidget-$_audioId] Audio attachment URL is null or empty.');
    }

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      bool newIsPlaying = (state == PlayerState.playing);
      if (_isPlaying != newIsPlaying) {
        setState(() { // Update local _isPlaying for UI
          _isPlaying = newIsPlaying;
        });
        if (newIsPlaying) {
          _dataController.mediaDidStartPlaying(_audioId, 'audio', _audioPlayer);
        } else {
          _dataController.mediaDidStopPlaying(_audioId, 'audio');
        }
      }
       // Also update _playerState if needed for other logic, though _isPlaying is primary for UI
      if (_playerState != state) {
        setState(() {
          _playerState = state;
        });
      }
    });

    _currentlyPlayingMediaSubscription = ever(_dataController.currentlyPlayingMediaId, (String? playingId) {
      if (!mounted) return;
      if (_isPlaying && playingId != null && playingId != _audioId) {
        print('[AudioAttachmentWidget-$_audioId] Another media ($playingId) started. Pausing this audio.');
        _audioPlayer.pause();
      }
    });
  }

  @override
  void dispose() {
    _mediaVisibilityService.unregisterItem(_audioId);
    if (_isPlaying) { // If disposing while playing, ensure DataController is notified
      _dataController.mediaDidStopPlaying(_audioId, 'audio');
    }
    _playerStateSubscription?.cancel();
    _currentlyPlayingMediaSubscription?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudio() {
    // Check with DataController before playing, only if not already playing this media
    if (_dataController.currentlyPlayingMediaId.value != _audioId || _playerState != PlayerState.playing) {
        print("[AudioAttachmentWidget-$_audioId] Play callback executed by MediaVisibilityService.");
        _audioPlayer.resume();
        // DataController update will happen via onPlayerStateChanged listener
    }
  }

  void _pauseAudio() {
     if (_playerState == PlayerState.playing) {
        print("[AudioAttachmentWidget-$_audioId] Pause callback executed by MediaVisibilityService.");
        _audioPlayer.pause();
        // DataController update will happen via onPlayerStateChanged listener
     }
  }

  void _togglePlayPauseByUser() { // Renamed to clarify it's a direct user action
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      // If user explicitly taps play, it should attempt to play,
      // potentially interrupting other media if MediaVisibilityService rules allow.
      // The currentlyPlayingMediaSubscription will handle pausing other players if this one starts.
      print('[AudioAttachmentWidget-$_audioId] User tapped play. Requesting to play.');
      _audioPlayer.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String visibilityDetectorKey = _audioId;

    return VisibilityDetector(
      key: Key(visibilityDetectorKey),
      onVisibilityChanged: (visibilityInfo) {
        final visibleFraction = visibilityInfo.visibleFraction;
        _mediaVisibilityService.itemVisibilityChanged(
          mediaId: _audioId,
          mediaType: 'audio',
          visibleFraction: visibleFraction,
          playCallback: _playAudio,
          pauseCallback: _pauseAudio,
          context: context,
        );
      },
      child: GestureDetector(
        onTap: () {
          List<Map<String, dynamic>> correctlyTypedPostAttachments = [];
          final dynamic rawPostAttachments = widget.post['attachments'];
          if (rawPostAttachments is List) {
            for (var item in rawPostAttachments) {
              if (item is Map<String, dynamic>) {
                correctlyTypedPostAttachments.add(item);
              } else if (item is Map) {
                try {
                  correctlyTypedPostAttachments.add(Map<String, dynamic>.from(item));
                } catch (e) {
                  print('[AudioAttachmentWidget-$_audioId] Error converting attachment item Map: $e');
                }
              } else {
                print('[AudioAttachmentWidget-$_audioId] Skipping non-map attachment item: $item');
              }
            }
          }

          int initialIndex = -1;
          if (widget.attachment['url'] != null) {
              initialIndex = correctlyTypedPostAttachments.indexWhere((att) => att['url'] == widget.attachment['url']);
          } else if (widget.attachment['_id'] != null) {
              initialIndex = correctlyTypedPostAttachments.indexWhere((att) => att['_id'] == widget.attachment['_id']);
          }
          if (initialIndex == -1) {
              initialIndex = correctlyTypedPostAttachments.indexOf(widget.attachment);
              if (initialIndex == -1) initialIndex = 0;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: correctlyTypedPostAttachments,
                initialIndex: initialIndex,
                message: widget.post['content'] as String? ?? '',
                userName: widget.post['username'] as String? ?? 'Unknown User',
                userAvatarUrl: widget.post['useravatar'] as String?,
                timestamp: widget.post['timestamp'] is String
                    ? (DateTime.tryParse(widget.post['timestamp'] as String) ?? DateTime.now())
                    : (widget.post['timestamp'] is DateTime ? widget.post['timestamp'] : DateTime.now()),
                viewsCount: widget.post['viewsCount'] as int? ?? (widget.post['views'] as List?)?.length ?? 0,
                likesCount: widget.post['likesCount'] as int? ?? (widget.post['likes'] as List?)?.length ?? 0,
                repostsCount: widget.post['repostsCount'] as int? ?? (widget.post['reposts'] as List?)?.length ?? 0,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 200,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[900],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    FeatherIcons.music,
                    color: Colors.tealAccent,
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _togglePlayPauseByUser, // User direct interaction
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying ? FeatherIcons.pause : FeatherIcons.play, // Uses local _isPlaying for UI
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isMuted ? FeatherIcons.volumeX : FeatherIcons.volume2,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
