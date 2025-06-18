import 'dart:io';

import 'package:better_player_enhanced/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/pages/media_view_page.dart'; // For MediaViewPage
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

// TODO: Update this import when Attachment and ChatterPost are moved to models
import 'package:chatter/models/feed_models.dart';


class VideoAttachmentWidget extends StatefulWidget {
  final Attachment attachment;
  final ChatterPost post;
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

    final optimizedUrl = widget.attachment.url!.replaceAll(
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
            widget.post.views++;
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
          widget.post.views++;
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

    return VisibilityDetector(
      key: Key(widget.attachment.url ?? widget.key.toString()),
      onVisibilityChanged: (info) {
        if (!_isInitialized) return;
        bool useBetterPlayer = Platform.isAndroid && widget.androidVersion! < 33;

        if (useBetterPlayer) {
          if (_betterPlayerController != null && _betterPlayerController!.videoPlayerController != null && _betterPlayerController!.videoPlayerController!.value.initialized) {
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
            aspectRatio: 4 / 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: widget.attachment.thumbnailUrl ?? '',
                    fit: BoxFit.cover,
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
