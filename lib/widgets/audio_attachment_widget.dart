import 'package:audioplayers/audioplayers.dart';
import 'package:chatter/pages/media_view_page.dart'; // For MediaViewPage
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Removed import for feed_models.dart


class AudioAttachmentWidget extends StatefulWidget {
  final Map<String, dynamic> attachment; // Changed to Map<String, dynamic>
  final Map<String, dynamic> post; // Changed to Map<String, dynamic>
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
  bool _isMuted = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    final String? audioUrlString = widget.attachment['url'] as String?;

    if (audioUrlString != null && audioUrlString.isNotEmpty) {
      String finalAudioUrl = audioUrlString;
      // Apply Cloudinary transformation only if it seems like a generic Cloudinary URL
      // and doesn't already look like an mp3 or other audio format.
      if (audioUrlString.contains('res.cloudinary.com') &&
          audioUrlString.contains('/upload/') &&
          !audioUrlString.toLowerCase().endsWith('.mp3') &&
          !audioUrlString.toLowerCase().endsWith('.m4a') &&
          !audioUrlString.toLowerCase().endsWith('.wav') &&
          !audioUrlString.toLowerCase().endsWith('.ogg') &&
          !audioUrlString.contains('/f_')) { // Don't transform if format 'f_' is already specified
        finalAudioUrl = audioUrlString.replaceAll('/upload/', '/upload/f_mp3/');
        print('[AudioAttachmentWidget] Applied Cloudinary f_mp3 transformation to: $audioUrlString, new URL: $finalAudioUrl');
      } else {
        print('[AudioAttachmentWidget] Using audio URL as is (no Cloudinary f_mp3 transformation): $finalAudioUrl');
      }

      _audioPlayer.setSourceUrl(finalAudioUrl).then((_) {
        // Successfully set source
        print('[AudioAttachmentWidget] Source set successfully for $finalAudioUrl');
      }).catchError((error) {
        print('[AudioAttachmentWidget] Error setting source for $finalAudioUrl: $error');
        // Optionally, update UI to show an error state
      });
      _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0); // Set initial volume based on _isMuted state

    } else {
      print('[AudioAttachmentWidget] Audio attachment URL is null or empty.');
      // Optionally, update UI to show an error state or that audio is unavailable
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? attachmentUrl = widget.attachment['url'] as String?;
    return VisibilityDetector(
      key: Key(attachmentUrl ?? UniqueKey().toString()), // Use a unique key if URL is null
      onVisibilityChanged: (info) {
        // TODO: Consider if auto-play/pause on visibility is desired for audio.
        // For now, mirroring video's behavior.
        if (info.visibleFraction > 0.5 && !_isPlaying) {
          _audioPlayer.resume();
          setState(() {
            _isPlaying = true;
          });
        } else if (info.visibleFraction <= 0.5 && _isPlaying) {
          _audioPlayer.pause();
          setState(() {
            _isPlaying = false;
          });
        }
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
                  print('[AudioAttachmentWidget] Error converting attachment item Map to Map<String, dynamic>: $e for item $item');
                }
              } else {
                print('[AudioAttachmentWidget] Skipping non-map attachment item: $item');
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
                viewsCount: widget.post['views'] as int? ?? 0,
                likesCount: widget.post['likes'] as int? ?? 0,
                repostsCount: widget.post['reposts'] as int? ?? 0,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3, // Assuming same aspect ratio for consistency, can be adjusted
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 200, // From original code
              ),
              decoration: BoxDecoration(
                color: Colors.grey[900],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FeatherIcons.music,
                    color: Colors.tealAccent,
                    size: 20, // Consistent icon size
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_isPlaying) {
                              _audioPlayer.pause();
                              _isPlaying = false;
                            } else {
                              _audioPlayer.resume();
                              _isPlaying = true;
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying ? FeatherIcons.pause : FeatherIcons.play,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(6),
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
