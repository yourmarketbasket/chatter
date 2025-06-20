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
    if (audioUrlString != null) {
      final audioUrl = audioUrlString.replaceAll(
        '/upload/',
        '/upload/f_mp3/',
      );
      _audioPlayer.setSourceUrl(audioUrl).catchError((error) {
        print('Audio initialization error: $error');
      });
      _audioPlayer.setVolume(0.0);
    } else {
      // Handle case where URL is null, perhaps log an error or set a default state
      print('Audio attachment URL is null.');
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: widget.post['attachments'] as List<Map<String, dynamic>>,
                initialIndex: (widget.post['attachments'] as List<Map<String, dynamic>>).indexOf(widget.attachment),
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
