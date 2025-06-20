import 'dart:io';

import 'package:better_player_enhanced/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/pages/media_view_page.dart'; // For MediaViewPage
import 'package:chatter/services/custom_cache_manager.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Removed import for feed_models.dart


class VideoAttachmentWidget extends StatefulWidget {
  final Map<String, dynamic> attachment; // Changed to Map<String, dynamic>
  final Map<String, dynamic> post; // Changed to Map<String, dynamic>
  final BorderRadius borderRadius;
  final int? androidVersion;
  final bool isLoadingAndroidVersion;

  const VideoAttachmentWidget({
    required Key key,
    required this.attachment,
    required this.post,
    required this.borderRadius,
    required this.androidVersion,
    required this.isLoadingAndroidVersion,
  }) : super(key: key);

  @override
  _VideoAttachmentWidgetState createState() => _VideoAttachmentWidgetState();
}

class _VideoAttachmentWidgetState extends State<VideoAttachmentWidget> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  BetterPlayerController? _betterPlayerController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  bool _isMuted = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    _pulseAnimationController.repeat(reverse: true);
  }

  void _initializeVideoPlayer() {
    if (widget.isLoadingAndroidVersion || widget.androidVersion == null) {
      return;
    }

    final String? attachmentUrl = widget.attachment['url'] as String?;
    if (attachmentUrl == null) {
      // Handle null URL case, perhaps show an error or placeholder
      print("Video attachment URL is null.");
      setState(() {
        _isInitialized = false;
      });
      return;
    }

    final optimizedUrl = attachmentUrl.replaceAll(
      '/upload/',
      '/upload/q_auto:good,w_1280,h_960,c_fill/',
    );

    if (Platform.isAndroid && widget.androidVersion! < 33) {
      _betterPlayerController = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: false,
          looping: true,
          fit: BoxFit.contain,
          aspectRatio: 4 / 3,
          controlsConfiguration: BetterPlayerControlsConfiguration(
            showControls: false,
            enablePlayPause: true,
            enableMute: true,
            muteIcon: FeatherIcons.volumeX,
            unMuteIcon: FeatherIcons.volume2,
          ),
          handleLifecycle: false,
        ),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          optimizedUrl,
          videoFormat: BetterPlayerVideoFormat.other,
        ),
      )..addEventsListener((event) {
          if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
            setState(() {
              _isInitialized = true;
            });
            _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
            // Safely increment views
            widget.post['views'] = (widget.post['views'] as int? ?? 0) + 1;
          } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
            print('BetterPlayer error: ${event.parameters}');
            setState(() {
              _isInitialized = false;
            });
          }
        });
    } else {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl))
        ..initialize().then((_) {
          setState(() {
            _isInitialized = true;
          });
          _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
          _videoPlayerController!.setLooping(true);
          // Safely increment views
          widget.post['views'] = (widget.post['views'] as int? ?? 0) + 1;
        }).catchError((error) {
          print('VideoPlayer initialization error: $error');
          setState(() {
            _isInitialized = false;
          });
        });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _betterPlayerController?.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoadingAndroidVersion || widget.androidVersion == null) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            color: Colors.grey[900],
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.tealAccent,
              ),
            ),
          ),
        ),
      );
    }

    final String? attachmentUrlForKey = widget.attachment['url'] as String?;
    return VisibilityDetector(
      key: Key(attachmentUrlForKey ?? widget.key.toString()),
      onVisibilityChanged: (info) {
        // bool useBetterPlayer = Platform.isAndroid && widget.androidVersion! < 33; // This line is moved down
        if (info.visibleFraction == 0) {
          if (_betterPlayerController != null) {
            _betterPlayerController!.dispose();
            _betterPlayerController = null;
          }
          if (_videoPlayerController != null) {
            _videoPlayerController!.dispose();
            _videoPlayerController = null;
          }
          if (_isInitialized) { // Only update state if it was initialized
            setState(() {
              _isInitialized = false;
            });
          }
        } else if (info.visibleFraction > 0) {
          // Moved useBetterPlayer here as it's only relevant when visibleFraction > 0
          bool useBetterPlayer = Platform.isAndroid && widget.androidVersion! < 33;
          if (!_isInitialized) {
            _initializeVideoPlayer();
          }
          // Only proceed with play/pause logic if initialized
          if (_isInitialized) {
            if (useBetterPlayer) {
              if (_betterPlayerController != null &&
                  _betterPlayerController!.videoPlayerController != null &&
                  _betterPlayerController!.videoPlayerController!.value.initialized) {
                if (info.visibleFraction > 0.5 && !_betterPlayerController!.isPlaying()!) {
                  _betterPlayerController!.play();
                } else if (info.visibleFraction <= 0.5 && _betterPlayerController!.isPlaying()!) {
                  _betterPlayerController!.pause();
                }
              }
            } else {
              if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
                if (info.visibleFraction > 0.5 && !_videoPlayerController!.value.isPlaying) {
                  _videoPlayerController!.play().catchError((error) {
                    print('VideoPlayer playback error in VisibilityDetector: $error');
                  });
                } else if (info.visibleFraction <= 0.5 && _videoPlayerController!.value.isPlaying) {
                  _videoPlayerController!.pause();
                }
              }
            }
          }
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
            aspectRatio: 4 / 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: widget.attachment['thumbnailUrl'] as String? ?? '',
                    fit: BoxFit.cover,
                    cacheManager: CustomCacheManager.instance,
                    placeholder: (context, url) => ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        color: Colors.grey[850],
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Icon(
                          FeatherIcons.image,
                          color: Colors.white.withOpacity(0.6),
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isInitialized)
                  (Platform.isAndroid && widget.androidVersion! < 33)
                      ? (_betterPlayerController != null && _betterPlayerController!.videoPlayerController != null && _betterPlayerController!.videoPlayerController!.value.initialized
                          ? BetterPlayer(controller: _betterPlayerController!)
                          : SizedBox.shrink())
                      : (_videoPlayerController != null && _videoPlayerController!.value.isInitialized
                          ? VideoPlayer(_videoPlayerController!)
                          : SizedBox.shrink()),
                if (!_isInitialized)
                  Center(
                    child: CircularProgressIndicator(
                      color: Colors.tealAccent,
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        if (Platform.isAndroid && widget.androidVersion! < 33) {
                          _betterPlayerController?.setVolume(_isMuted ? 0.0 : 1.0);
                        } else {
                          _videoPlayerController?.setVolume(_isMuted ? 0.0 : 1.0);
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
                        _isMuted ? FeatherIcons.volumeX : FeatherIcons.volume2,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
