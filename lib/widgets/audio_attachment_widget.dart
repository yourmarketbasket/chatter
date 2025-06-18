import 'package:audioplayers/audioplayers.dart';
import 'package:chatter/pages/media_view_page.dart'; // For MediaViewPage
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

// TODO: Update this import when Attachment and ChatterPost are moved to models
import 'package:chatter/models/feed_models.dart';


class AudioAttachmentWidget extends StatefulWidget {
  final Attachment attachment;
  final ChatterPost post;
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
    final audioUrl = widget.attachment.url!.replaceAll(
      '/upload/',
      '/upload/f_mp3/',
    );
    _audioPlayer.setSourceUrl(audioUrl).catchError((error) {
      print('Audio initialization error: $error');
    });
    _audioPlayer.setVolume(0.0);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.attachment.url!),
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
                attachments: widget.post.attachments,
                initialIndex: widget.post.attachments.indexOf(widget.attachment),
                message: widget.post.content,
                userName: widget.post.username,
                userAvatarUrl: widget.post.useravatar,
                timestamp: widget.post.timestamp,
                viewsCount: widget.post.views,
                likesCount: widget.post.likes,
                repostsCount: widget.post.reposts,
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
