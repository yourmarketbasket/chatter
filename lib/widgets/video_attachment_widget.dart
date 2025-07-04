import 'dart:async';
import 'package:better_player_enhanced/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/services/custom_cache_manager.dart';
import 'package:chatter/services/media_visibility_service.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoAttachmentWidget extends StatefulWidget {
  final Map<String, dynamic> attachment;
  final Map<String, dynamic> post;
  final BorderRadius borderRadius;
  final bool isFeedContext;
  final Function(String videoId)? onVideoCompletedInGrid;

  const VideoAttachmentWidget({
    required Key key,
    required this.attachment,
    required this.post,
    required this.borderRadius,
    this.isFeedContext = false,
    this.onVideoCompletedInGrid,
  }) : super(key: key);

  @override
  _VideoAttachmentWidgetState createState() => _VideoAttachmentWidgetState();
}

class _VideoAttachmentWidgetState extends State<VideoAttachmentWidget> with SingleTickerProviderStateMixin {
  BetterPlayerController? _betterPlayerController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  bool _isMuted = true;
  bool _isInitialized = false;
  String _videoUniqueId = "";
  bool _shouldAutoplayAfterInit = false;
  bool _shouldRenderPlayer = false;
  final DataController _dataController = Get.find<DataController>();
  final MediaVisibilityService _mediaVisibilityService = Get.find<MediaVisibilityService>();
  StreamSubscription? _isTransitioningVideoSubscription;
  Worker? _currentlyPlayingMediaSubscription;
  double _aspectRatio = 16 / 9; // Default aspect ratio

  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ??
                     (widget.key?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());

    _updateAspectRatio();

    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    _currentlyPlayingMediaSubscription = ever(_dataController.currentlyPlayingMediaId, (String? playingId) {
      if (!mounted || _betterPlayerController == null || !_isInitialized) return;

      if (widget.isFeedContext) {
        final bool isThisVideoPlaying = _betterPlayerController!.isPlaying() ?? false;
        if (isThisVideoPlaying &&
            playingId != null &&
            playingId != _videoUniqueId &&
            _dataController.currentlyPlayingMediaType.value == 'video') {
          print('[VideoAttachmentWidget-$_videoUniqueId] Another video ($playingId) started in feed. Pausing this video.');
          if (mounted) {
            setState(() {
              _shouldRenderPlayer = false;
            });
          }
          _betterPlayerController!.pause();
        }
      }
    });

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    _pulseAnimationController.repeat(reverse: true);
  }

  void _updateAspectRatio() {
    final num? videoWidth = widget.attachment['width'] as num?;
    final num? videoHeight = widget.attachment['height'] as num?;
    if (videoWidth != null && videoHeight != null && videoHeight > 0) {
      _aspectRatio = videoWidth / videoHeight;
    } else {
      // Try to parse from 'aspectRatio' string if present
      final String? aspectRatioString = widget.attachment['aspectRatio'] as String?;
      if (aspectRatioString != null) {
        final parts = aspectRatioString.split(':');
        if (parts.length == 2) {
          final double? w = double.tryParse(parts[0]);
          final double? h = double.tryParse(parts[1]);
          if (w != null && h != null && h > 0) {
            _aspectRatio = w / h;
          }
        } else {
          final double? val = double.tryParse(aspectRatioString);
          if (val != null && val > 0) {
            _aspectRatio = val;
          }
        }
      }
    }
    // Ensure aspect ratio is positive, else default
    if (_aspectRatio <= 0) _aspectRatio = 16/9;

    if (mounted && _betterPlayerController != null && _isInitialized) {
      _betterPlayerController!.setBetterPlayerConfiguration(
        _betterPlayerController!.betterPlayerConfiguration.copyWith(
          aspectRatio: _aspectRatio,
        )
      );
    }
  }


  @override
  void didUpdateWidget(covariant VideoAttachmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachment['width'] != oldWidget.attachment['width'] ||
        widget.attachment['height'] != oldWidget.attachment['height'] ||
        widget.attachment['aspectRatio'] != oldWidget.attachment['aspectRatio']) {
      _updateAspectRatio();
    }
  }

  void _precacheThumbnail(String thumbnailUrl) async {
    try {
      await CustomCacheManager.instance.getSingleFile(thumbnailUrl);
      print('[VideoAttachmentWidget-$_videoUniqueId] Pre-cached thumbnail: $thumbnailUrl');
    } catch (e) {
      print('[VideoAttachmentWidget-$_videoUniqueId] Error pre-caching thumbnail: $e');
    }
  }

  void _playVideo() {
    print("[VideoAttachmentWidget-$_videoUniqueId] Play callback received.");
    if (!_isInitialized || _betterPlayerController == null) {
      print("[VideoAttachmentWidget-$_videoUniqueId] Player not ready, initializing to play.");
      _initializeVideoPlayer(autoplay: true);
    } else {
      if (mounted) {
        setState(() {
          _shouldRenderPlayer = true;
        });
      }
      _betterPlayerController!.play();
      print("[VideoAttachmentWidget-$_videoUniqueId] Player ready, playing.");
    }
  }

  void _pauseVideo() {
    print("[VideoAttachmentWidget-$_videoUniqueId] Pause callback received.");
    if (_betterPlayerController != null && _isInitialized) {
      _betterPlayerController!.pause();
       print("[VideoAttachmentWidget-$_videoUniqueId] Player paused.");
    }
    if (mounted) {
      setState(() {
        _shouldRenderPlayer = false;
      });
    }
  }

  void _initializeVideoPlayer({bool autoplay = false}) {
    if (_betterPlayerController != null) {
      print("[VideoAttachmentWidget-$_videoUniqueId] _initializeVideoPlayer: Disposing existing controller before creating new one.");
      _betterPlayerController!.removeEventsListener(_onPlayerEvent);
      _betterPlayerController!.dispose();
    }
    _betterPlayerController = null;
    _isInitialized = false;
    _shouldAutoplayAfterInit = autoplay;

    final String? attachmentUrl = widget.attachment['url'] as String?;
    if (attachmentUrl == null) {
      print("[VideoAttachmentWidget-$_videoUniqueId] Video attachment URL is null.");
      if (mounted) setState(() {});
      return;
    }

    final optimizedUrl = attachmentUrl.replaceAll(
      '/upload/',
      '/upload/q_auto:low,w_480,c_limit/',
    );

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        aspectRatio: _aspectRatio, // Use dynamic aspect ratio
        autoPlay: false,
        looping: widget.onVideoCompletedInGrid == null,
        fit: BoxFit.contain, // Changed to contain to respect aspect ratio
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
          enablePlayPause: true,
          enableMute: true,
          muteIcon: FeatherIcons.volumeX,
          unMuteIcon: FeatherIcons.volume2,
          loadingWidget: const SizedBox.shrink(),
        ),
        handleLifecycle: false,
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        optimizedUrl,
        videoFormat: BetterPlayerVideoFormat.other,
        cacheConfiguration: const BetterPlayerCacheConfiguration(useCache: false),
      ),
    )..addEventsListener(_onPlayerEvent);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted || _betterPlayerController == null) return;

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        if (mounted) {
          setState(() => _isInitialized = true);
           // Update aspect ratio again once initialized, as player might have more info
          final videoAspectRatio = _betterPlayerController!.videoPlayerController?.value.aspectRatio;
          if (videoAspectRatio != null && videoAspectRatio > 0 && videoAspectRatio != _aspectRatio) {
            if (mounted) {
               setState(() {
                  _aspectRatio = videoAspectRatio;
               });
              _betterPlayerController!.setBetterPlayerConfiguration(
                _betterPlayerController!.betterPlayerConfiguration.copyWith(aspectRatio: _aspectRatio)
              );
            }
          }
          _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
          if (_shouldAutoplayAfterInit && !(_betterPlayerController!.isPlaying() ?? true)) {
            _betterPlayerController!.play();
          } else if (_betterPlayerController!.isPlaying() == true) {
            _dataController.mediaDidStartPlaying(_videoUniqueId, 'video', _betterPlayerController!);
          }
        }
        break;
      case BetterPlayerEventType.exception:
        print('[VideoAttachmentWidget-$_videoUniqueId] BetterPlayer error: ${event.parameters}');
        if (mounted) setState(() => _isInitialized = false);
        _dataController.mediaDidStopPlaying(_videoUniqueId, 'video');
        break;
      case BetterPlayerEventType.play:
        _dataController.mediaDidStartPlaying(_videoUniqueId, 'video', _betterPlayerController!);
        break;
      case BetterPlayerEventType.pause:
        _dataController.mediaDidStopPlaying(_videoUniqueId, 'video');
        break;
      case BetterPlayerEventType.finished:
        _dataController.mediaDidStopPlaying(_videoUniqueId, 'video');
        widget.onVideoCompletedInGrid?.call(_videoUniqueId);
        break;
      case BetterPlayerEventType.progress:
      default:
        break;
    }
  }

  @override
  void dispose() {
    _mediaVisibilityService.unregisterItem(_videoUniqueId);
    _currentlyPlayingMediaSubscription?.dispose();

    if (_betterPlayerController != null) {
      print("[VideoAttachmentWidget-$_videoUniqueId] Widget dispose: Disposing BetterPlayerController.");
      _betterPlayerController!.removeEventsListener(_onPlayerEvent);
      _betterPlayerController!.dispose();
      _betterPlayerController = null;
    }
    _isInitialized = false;
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    final String visibilityDetectorKey = _videoUniqueId;

    return VisibilityDetector(
      key: Key(visibilityDetectorKey),
      onVisibilityChanged: (visibilityInfo) {
        final visibleFraction = visibilityInfo.visibleFraction;

        if (visibleFraction > 0 && !_isInitialized && _betterPlayerController == null) {
            print("[VideoAttachmentWidget-$_videoUniqueId] Becoming visible (fraction: $visibleFraction), ensuring player is initialized.");
            _initializeVideoPlayer(autoplay: false);
        }

        _mediaVisibilityService.itemVisibilityChanged(
          mediaId: _videoUniqueId,
          mediaType: 'video',
          visibleFraction: visibleFraction,
          playCallback: _playVideo,
          pauseCallback: _pauseVideo,
          context: context,
        );

        if (visibleFraction == 0) {
          if (mounted && _shouldRenderPlayer) {
            setState(() {
              _shouldRenderPlayer = false;
            });
          } else {
             _shouldRenderPlayer = false;
          }

          if (_betterPlayerController != null) {
            print("[VideoAttachmentWidget-$_videoUniqueId] Became completely invisible. Aggressively disposing player.");
            _betterPlayerController!.pause();
            _betterPlayerController!.removeEventsListener(_onPlayerEvent);
            _betterPlayerController!.dispose();
            _betterPlayerController = null;
          }
          if (_isInitialized && mounted) {
            setState(() {
              _isInitialized = false;
            });
          } else {
            _isInitialized = false;
          }
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
                  print('[VideoAttachmentWidget-$_videoUniqueId] Error converting attachment item Map: $e');
                }
              } else {
                print('[VideoAttachmentWidget-$_videoUniqueId] Skipping non-map attachment item: $item');
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
            aspectRatio: _aspectRatio, // Use dynamic aspect ratio here
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl ?? '',
                    fit: BoxFit.cover, // Cover for thumbnail
                    memCacheWidth: 480,
                    cacheManager: CustomCacheManager.instance,
                    cacheKey: thumbnailUrl ?? _videoUniqueId,
                    placeholder: (context, url) => ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        color: Colors.grey[850],
                        child: Center(
                          child: Icon(FeatherIcons.video, color: Colors.white.withOpacity(0.6), size: 36),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Icon(FeatherIcons.video, color: Colors.white.withOpacity(0.6), size: 36),
                      ),
                    ),
                  ),
                ),
                if (_isInitialized && _shouldRenderPlayer && _betterPlayerController != null)
                  Positioned.fill(
                    child: BetterPlayer(controller: _betterPlayerController!),
                  )
                else if (!_isInitialized && _shouldRenderPlayer)
                  const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent))),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        _betterPlayerController?.setVolume(_isMuted ? 0.0 : 1.0);
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}