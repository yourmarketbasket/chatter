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
  final bool isFeedContext; // Remains for other feed-specific logic if any
  final Function(String videoId)? onVideoCompletedInGrid;
  final bool enforceFeedConstraints; // New parameter

  const VideoAttachmentWidget({
    required Key key,
    required this.attachment,
    required this.post,
    required this.borderRadius,
    this.isFeedContext = false,
    this.onVideoCompletedInGrid,
    this.enforceFeedConstraints = false, // Default to false (native aspect ratio)
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
  double _currentAspectRatio = 16 / 9; // Holds the dynamically determined aspect ratio
  BoxFit _currentBoxFit = BoxFit.contain; // Holds the dynamically determined BoxFit

  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ??
                     (widget.key?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());

    _updateAspectAndFit(); // Initial determination

    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    _currentlyPlayingMediaSubscription = ever(_dataController.currentlyPlayingMediaId, (String? playingId) {
      if (!mounted || _betterPlayerController == null || !_isInitialized) return;

      if (widget.isFeedContext) { // This specific logic might still be relevant for feed
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

  void _updateAspectAndFit() {
    if (widget.enforceFeedConstraints) {
      _currentAspectRatio = 4 / 3;
      _currentBoxFit = BoxFit.cover; // For feed: cover the 4:3 frame
    } else {
      // Calculate native aspect ratio
      final num? videoWidth = widget.attachment['width'] as num?;
      final num? videoHeight = widget.attachment['height'] as num?;
      if (videoWidth != null && videoHeight != null && videoHeight > 0) {
        _currentAspectRatio = videoWidth / videoHeight;
      } else {
        final String? aspectRatioString = widget.attachment['aspectRatio'] as String?;
        if (aspectRatioString != null) {
          final parts = aspectRatioString.split(':');
          if (parts.length == 2) {
            final double? w = double.tryParse(parts[0]);
            final double? h = double.tryParse(parts[1]);
            if (w != null && h != null && h > 0) {
              _currentAspectRatio = w / h;
            } else {
              _currentAspectRatio = 16/9; // Fallback
            }
          } else {
            final double? val = double.tryParse(aspectRatioString);
            if (val != null && val > 0) {
              _currentAspectRatio = val;
            } else {
              _currentAspectRatio = 16/9; // Fallback
            }
          }
        } else {
            _currentAspectRatio = 16/9; // Default fallback
        }
      }
      if (_currentAspectRatio <= 0) _currentAspectRatio = 16/9;
      _currentBoxFit = BoxFit.contain; // For native: contain within its aspect ratio
    }

    // No direct update to BetterPlayerController configuration here after initialization.
    // This method now primarily sets _currentAspectRatio and _currentBoxFit for initialization
    // and for the outer AspectRatio widget.
    if(mounted) setState(() {}); // Ensure UI rebuilds if aspect ratio changed for the wrapper
  }


  @override
  void didUpdateWidget(covariant VideoAttachmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enforceFeedConstraints != oldWidget.enforceFeedConstraints ||
        (widget.enforceFeedConstraints == false &&
         (widget.attachment['width'] != oldWidget.attachment['width'] ||
          widget.attachment['height'] != oldWidget.attachment['height'] ||
          widget.attachment['aspectRatio'] != oldWidget.attachment['aspectRatio'])
        )
       ) {
      _updateAspectAndFit();
      // If player is initialized and constraints change, might need to re-initialize player.
      // For simplicity, current setup relies on _initializeVideoPlayer to use updated values.
      // A more robust solution for live changes might involve disposing and recreating the player.
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
      // _updateAspectAndFit(); // Ensure aspect/fit are correct before initializing
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

    // Ensure aspect ratio and fit are determined before creating the controller
    _updateAspectAndFit();


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
        aspectRatio: _currentAspectRatio, // Use state variable set by _updateAspectAndFit
        autoPlay: false,
        looping: widget.onVideoCompletedInGrid == null,
        fit: _currentBoxFit, // Use state variable set by _updateAspectAndFit
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

          if (!widget.enforceFeedConstraints) {
            final videoPlayerAspectRatio = _betterPlayerController!.videoPlayerController?.value.aspectRatio;
            if (videoPlayerAspectRatio != null && videoPlayerAspectRatio > 0 && videoPlayerAspectRatio != _currentAspectRatio) {
              if (mounted) {
                 // Only update _currentAspectRatio for the parent AspectRatio widget via setState.
                 // Do not attempt to change the player's internal configuration here.
                 setState(() {
                    _currentAspectRatio = videoPlayerAspectRatio;
                 });
              }
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

    // Ensure _currentAspectRatio is up-to-date for the AspectRatio widget
    // This might be slightly redundant if _updateAspectAndFit also calls setState,
    // but ensures the AspectRatio widget uses the latest calculated value.
    // Consider if _updateAspectAndFit should always call setState if it changes _currentAspectRatio.
    // For now, explicit call in build might be safer if _updateAspectAndFit is complex.
    // However, _updateAspectAndFit already calls setState if mounted.

    return VisibilityDetector(
      key: Key(visibilityDetectorKey),
      onVisibilityChanged: (visibilityInfo) {
        final visibleFraction = visibilityInfo.visibleFraction;

        if (visibleFraction > 0 && !_isInitialized && _betterPlayerController == null) {
            print("[VideoAttachmentWidget-$_videoUniqueId] Becoming visible (fraction: $visibleFraction), ensuring player is initialized.");
            _initializeVideoPlayer(autoplay: false); // Autoplay decision is managed by MediaVisibilityService
        }

        _mediaVisibilityService.itemVisibilityChanged(
          mediaId: _videoUniqueId,
          mediaType: 'video',
          visibleFraction: visibleFraction,
          playCallback: _playVideo,
          pauseCallback: _pauseVideo,
          context: context,
        );

        if (visibleFraction == 0) { // Aggressive disposal
          if (mounted && _shouldRenderPlayer) {
            setState(() { _shouldRenderPlayer = false; });
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
            setState(() { _isInitialized = false; });
          } else {
            _isInitialized = false;
          }
        }
      },
      child: GestureDetector(
        onTap: () { // Navigation to MediaViewPage
          List<Map<String, dynamic>> correctlyTypedPostAttachments = [];
          final dynamic rawPostAttachments = widget.post['attachments'];
          if (rawPostAttachments is List) {
            for (var item in rawPostAttachments) {
              if (item is Map<String, dynamic>) {
                correctlyTypedPostAttachments.add(item);
              } else if (item is Map) {
                try { correctlyTypedPostAttachments.add(Map<String, dynamic>.from(item)); } catch (e) { print('[VideoAttachmentWidget-$_videoUniqueId] Error converting attachment item Map: $e');}
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
            aspectRatio: _currentAspectRatio, // Use the dynamically determined aspect ratio for the container
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill( // Thumbnail
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    cacheManager: CustomCacheManager.instance,
                    cacheKey: thumbnailUrl ?? _videoUniqueId,
                    placeholder: (context, url) => ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(color: Colors.grey[850], child: Center(child: Icon(FeatherIcons.video, color: Colors.white.withOpacity(0.6), size: 36))),
                    ),
                    errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: Center(child: Icon(FeatherIcons.video, color: Colors.white.withOpacity(0.6), size: 36))),
                  ),
                ),
                // Player, rendered conditionally
                if (_isInitialized && _shouldRenderPlayer && _betterPlayerController != null)
                  Positioned.fill( // Player should also fill the AspectRatio container
                    child: BetterPlayer(controller: _betterPlayerController!),
                  )
                else if (!_isInitialized && _shouldRenderPlayer) // Loading indicator
                  const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent))),

                // Mute/Unmute button
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
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                      child: Icon(_isMuted ? FeatherIcons.volumeX : FeatherIcons.volume2, color: Colors.white, size: 16),
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