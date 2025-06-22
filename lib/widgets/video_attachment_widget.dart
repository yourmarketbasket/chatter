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
  final DataController _dataController = Get.find<DataController>();
  final MediaVisibilityService _mediaVisibilityService = Get.find<MediaVisibilityService>();
  StreamSubscription? _isTransitioningVideoSubscription;
  Worker? _currentlyPlayingMediaSubscription;

  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ??
                     (widget.key?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());

    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    // Standard initialization, don't autoplay, visibility service will decide
    _initializeVideoPlayer(autoplay: false);

    _currentlyPlayingMediaSubscription = ever(_dataController.currentlyPlayingMediaId, (String? playingId) {
      if (!mounted || _betterPlayerController == null || !_isInitialized) return;

      // Only act if this widget is part of the feed context
      if (widget.isFeedContext) {
        final bool isThisVideoPlaying = _betterPlayerController!.isPlaying() ?? false;
        if (isThisVideoPlaying &&
            playingId != null &&
            playingId != _videoUniqueId &&
            _dataController.currentlyPlayingMediaType.value == 'video') {
          print('[VideoAttachmentWidget-$_videoUniqueId] Another video ($playingId) started in feed. Pausing this video.');
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

  void _precacheThumbnail(String thumbnailUrl) async {
    try {
      await CustomCacheManager.instance.getSingleFile(thumbnailUrl);
      print('[VideoAttachmentWidget-$_videoUniqueId] Pre-cached thumbnail: $thumbnailUrl');
    } catch (e) {
      print('[VideoAttachmentWidget-$_videoUniqueId] Error pre-caching thumbnail: $e');
    }
  }

  void _playVideo() {
    if (!_isInitialized || _betterPlayerController == null) {
      print("[VideoAttachmentWidget-$_videoUniqueId] Play callback: Initializing player to play.");
      _initializeVideoPlayer(autoplay: true); // Initialize and tell it to play once ready
    } else {
      // Only play if not already playing this specific media or if it's paused
      if (_dataController.currentlyPlayingMediaId.value != _videoUniqueId || !_betterPlayerController!.isPlaying()!) {
        print("[VideoAttachmentWidget-$_videoUniqueId] Play callback executed.");
        _betterPlayerController!.play();
      }
    }
  }

  void _pauseVideo() {
    if (_betterPlayerController != null && _isInitialized && (_betterPlayerController!.isPlaying() ?? false)) {
      print("[VideoAttachmentWidget-$_videoUniqueId] Pause callback executed.");
      _betterPlayerController!.pause();
    }
  }

  void _initializeVideoPlayer({bool autoplay = false}) {
    // If already initialized and trying to initialize again with the same settings, can return.
    if (_isInitialized && _betterPlayerController != null) {
        // If autoplay is requested and it's not playing, play it.
        if (autoplay && !_betterPlayerController!.isPlaying()!) {
             _betterPlayerController!.play();
        }
        return;
    }

    // Dispose any existing controller before creating a new one.
    // This is important if configuration changes (e.g. autoplay flag).
    _betterPlayerController?.removeEventsListener(_onPlayerEvent); // Remove listener from old controller
    _betterPlayerController?.dispose();
    _betterPlayerController = null;
    _isInitialized = false; // Reset initialization state

    final String? attachmentUrl = widget.attachment['url'] as String?;
    if (attachmentUrl == null) {
      print("[VideoAttachmentWidget-$_videoUniqueId] Video attachment URL is null.");
      if (mounted) setState(() {}); // Update UI to reflect lack of player
      return;
    }

    final optimizedUrl = attachmentUrl.replaceAll(
      '/upload/',
      '/upload/q_auto:good,w_1280,h_960,c_fill/',
    );

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: autoplay,
        looping: widget.onVideoCompletedInGrid == null,
        fit: BoxFit.cover,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
          enablePlayPause: true, // These are for built-in controls, which are hidden
          enableMute: true,
          muteIcon: FeatherIcons.volumeX,
          unMuteIcon: FeatherIcons.volume2,
          loadingWidget: const SizedBox.shrink(),
        ),
        handleLifecycle: false, // We manage lifecycle explicitly
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        optimizedUrl,
        videoFormat: BetterPlayerVideoFormat.other,
        cacheConfiguration: const BetterPlayerCacheConfiguration( // Caching disabled
          useCache: false,
        ),
      ),
    )..addEventsListener(_onPlayerEvent);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted || _betterPlayerController == null) return; // Added null check for _betterPlayerController

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        if (mounted) {
          setState(() => _isInitialized = true);
          _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
           // If autoplay was requested during init and player is now ready
          if (_betterPlayerController!.betterPlayerConfiguration.autoPlay &&
              !(_betterPlayerController!.isPlaying() ?? true) ) { // Check if not already playing
            _betterPlayerController!.play();
          } else if (_betterPlayerController!.isPlaying() == true) {
             // If already playing (e.g. due to internal autoplay after init)
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
      // Progress event no longer updates DataController transition properties
      case BetterPlayerEventType.progress:
      default:
        break;
    }
  }

  @override
  void dispose() {
    _mediaVisibilityService.unregisterItem(_videoUniqueId);
    // _isTransitioningVideoSubscription?.cancel(); // Removed
    _currentlyPlayingMediaSubscription?.dispose();

    if (_betterPlayerController != null) {
      if (_betterPlayerController!.isPlaying() == true) {
          _dataController.mediaDidStopPlaying(_videoUniqueId, 'video');
      }
      _betterPlayerController!.removeEventsListener(_onPlayerEvent);
      _betterPlayerController!.dispose();
      print("[VideoAttachmentWidget-$_videoUniqueId] Disposed BetterPlayerController.");
    }
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

        // Removed isCurrentlyTransitioningThisVideo check as transition logic is removed

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

        // Refined disposal logic:
        // If it becomes completely invisible AND it's not transitioning AND a controller exists
        if (visibleFraction == 0 && _betterPlayerController != null) {
            print("[VideoAttachmentWidget-$_videoUniqueId] Became completely invisible. Disposing player.");
            // Pause should have been called by MediaVisibilityService.
            // If it was playing, the pause event would have updated DataController.
            // We just need to dispose the controller here.
            _betterPlayerController!.removeEventsListener(_onPlayerEvent);
            _betterPlayerController!.dispose();
            _betterPlayerController = null;
            if(mounted) {
              setState(() => _isInitialized = false);
            }
        }
      },
      child: GestureDetector(
        onTap: () {
          // Transition logic removed. Directly navigate.
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
                viewsCount: widget.post['views'] as int? ?? 0,
                likesCount: widget.post['likes'] as int? ?? 0,
                repostsCount: widget.post['reposts'] as int? ?? 0,
              ),
            ),
          );
          // Removed .then() block that handled post-transition logic
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
                    imageUrl: thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    cacheManager: CustomCacheManager.instance,
                    cacheKey: thumbnailUrl ?? _videoUniqueId,
                    placeholder: (context, url) => ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        color: Colors.grey[850],
                        child: Center(
                          child: Icon(
                            FeatherIcons.video,
                            color: Colors.white.withOpacity(0.6),
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Icon(
                          FeatherIcons.video,
                          color: Colors.white.withOpacity(0.6),
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isInitialized &&
                    _betterPlayerController != null &&
                    _betterPlayerController!.videoPlayerController != null &&
                    _betterPlayerController!.videoPlayerController!.value.initialized)
                  BetterPlayer(controller: _betterPlayerController!),
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