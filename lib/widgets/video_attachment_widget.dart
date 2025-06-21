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
  StreamSubscription? _currentlyPlayingMediaSubscription;

  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ??
                     (widget.key?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());

    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    // Player initialization logic for when returning from MediaViewPage or initial setup
    if (widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
      Object? controllerFromDataController = _dataController.activeFeedPlayerController.value;
      if (controllerFromDataController is BetterPlayerController) {
        _betterPlayerController = controllerFromDataController;
        _isInitialized = true; // Assume it's initialized if we are getting it from DataController
        _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
        _betterPlayerController!.setLooping(widget.onVideoCompletedInGrid == null);
        if (_dataController.activeFeedPlayerPosition.value != null) {
          _betterPlayerController!.seekTo(_dataController.activeFeedPlayerPosition.value!);
        }
        _betterPlayerController!.play();
        _dataController.isTransitioningVideo.value = false;
        // Ensure DataController is updated with the playing state
        if (_betterPlayerController!.isPlaying() == true) {
            _dataController.mediaDidStartPlaying(_videoUniqueId, 'video', _betterPlayerController!);
        }
      } else {
        // Fallback if controller in DataController is not a BetterPlayerController or null
        _initializeVideoPlayer(autoplay: false);
      }
    } else {
      // Standard initialization, don't autoplay, visibility service will decide
      _initializeVideoPlayer(autoplay: false);
    }

    _currentlyPlayingMediaSubscription = ever(_dataController.currentlyPlayingMediaId, (String? playingId) {
      if (!mounted || _betterPlayerController == null || !_isInitialized) return;
      final bool isThisVideoPlaying = _betterPlayerController!.isPlaying() ?? false;

      if (isThisVideoPlaying && playingId != null && playingId != _videoUniqueId) {
        print('[VideoAttachmentWidget-$_videoUniqueId] Another media ($playingId) started. Pausing this video.');
        _betterPlayerController!.pause();
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

    if (widget.isFeedContext) {
      _isTransitioningVideoSubscription = _dataController.isTransitioningVideo.listen((isTransitioning) {
        if (isTransitioning && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
          // If this video is being transitioned, MediaViewPage will take control.
          // The MediaVisibilityService should ideally not interfere.
          // The check in onVisibilityChanged for isCurrentlyTransitioningThisVideo handles this.
        }
      });
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
    if (_isInitialized && _betterPlayerController != null && _betterPlayerController!.configuration.autoPlay == autoplay) {
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
        cacheConfiguration: BetterPlayerCacheConfiguration(
          useCache: true,
          preCacheSize: 10 * 1024 * 1024,
          maxCacheSize: 100 * 1024 * 1024,
          maxCacheFileSize: 10 * 1024 * 1024,
        ),
      ),
    )..addEventsListener(_onPlayerEvent);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        if (mounted) {
          setState(() => _isInitialized = true);
          _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
        }
        // If autoplay was true during init, BetterPlayer handles it.
        // The PLAY event will then notify DataController.
        // If it's already playing due to autoplay on init:
        if (_betterPlayerController!.isPlaying() == true) {
            _dataController.mediaDidStartPlaying(_videoUniqueId, 'video', _betterPlayerController!);
        }
        break;
      case BetterPlayerEventType.exception:
        print('[VideoAttachmentWidget-$_videoUniqueId] BetterPlayer error: ${event.parameters}');
        if (mounted) setState(() => _isInitialized = false);
        _dataController.mediaDidStopPlaying(_videoUniqueId, 'video');
        break;
      case BetterPlayerEventType.play:
        _dataController.mediaDidStartPlaying(_videoUniqueId, 'video', _betterPlayerController!);
        if (widget.isFeedContext) {
          _dataController.activeFeedPlayerController.value = _betterPlayerController;
          _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
        }
        break;
      case BetterPlayerEventType.pause:
        _dataController.mediaDidStopPlaying(_videoUniqueId, 'video');
          if (widget.isFeedContext && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId && !_dataController.isTransitioningVideo.value) {
            _dataController.activeFeedPlayerController.value = null;
            _dataController.activeFeedPlayerVideoId.value = null;
            _dataController.activeFeedPlayerPosition.value = null;
        }
        break;
      case BetterPlayerEventType.completed:
        _dataController.mediaDidStopPlaying(_videoUniqueId, 'video');
        if (widget.isFeedContext && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId && !_dataController.isTransitioningVideo.value) {
            _dataController.activeFeedPlayerController.value = null;
            _dataController.activeFeedPlayerVideoId.value = null;
            _dataController.activeFeedPlayerPosition.value = null;
        }
        widget.onVideoCompletedInGrid?.call(_videoUniqueId);
        break;
      case BetterPlayerEventType.progress:
        if (_betterPlayerController!.isPlaying()! && widget.isFeedContext) {
          _dataController.activeFeedPlayerPosition.value = event.parameters!['progress'] as Duration;
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _mediaVisibilityService.unregisterItem(_videoUniqueId);
    _isTransitioningVideoSubscription?.cancel();
    _currentlyPlayingMediaSubscription?.cancel();

    bool isTransitioningThisVideo = widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

    if (isTransitioningThisVideo) {
      print("[VideoAttachmentWidget-$_videoUniqueId] NOT disposing BetterPlayerController due to transition.");
      // Listener should still be removed if the controller is not ours anymore
      _betterPlayerController?.removeEventsListener(_onPlayerEvent);
    } else {
      if (_betterPlayerController != null) {
        if (_betterPlayerController!.isPlaying() == true) {
            _dataController.mediaDidStopPlaying(_videoUniqueId, 'video');
        }
        _betterPlayerController!.removeEventsListener(_onPlayerEvent);
        _betterPlayerController!.dispose();
         print("[VideoAttachmentWidget-$_videoUniqueId] normally disposing BetterPlayerController.");
      }
      if (widget.isFeedContext && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
         if (!_dataController.isTransitioningVideo.value) {
            _dataController.activeFeedPlayerController.value = null;
            _dataController.activeFeedPlayerVideoId.value = null;
            _dataController.activeFeedPlayerPosition.value = null;
         }
      }
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

        bool isCurrentlyTransitioningThisVideo = widget.isFeedContext &&
            _dataController.isTransitioningVideo.value &&
            _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

        if (isCurrentlyTransitioningThisVideo) {
          // If transitioning, don't let visibility changes interfere with the player
          // that MediaViewPage might be controlling.
          print("[VideoAttachmentWidget-$_videoUniqueId] Visibility changed during transition, ignoring for player control.");
          return;
        }

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
          // Prepare for transition to MediaViewPage
          if (widget.isFeedContext && _betterPlayerController != null && _isInitialized) {
             // Pass the current controller and its state to DataController
            _dataController.activeFeedPlayerController.value = _betterPlayerController;
            _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
            if (_betterPlayerController!.videoPlayerController?.value.position != null) {
                 _dataController.activeFeedPlayerPosition.value = _betterPlayerController!.videoPlayerController!.value.position;
            }
            // Signal that a transition is about to happen for THIS video.
            // This is crucial for dispose() and onVisibilityChanged() to not kill the player.
            _dataController.isTransitioningVideo.value = true;
             print("[VideoAttachmentWidget-$_videoUniqueId] Tapped. Setting isTransitioningVideo to true. Player isPlaying: ${_betterPlayerController?.isPlaying()}");

          } else if (widget.isFeedContext && (_betterPlayerController == null || !_isInitialized)) {
            // If player isn't ready but tapped, ensure transition state is clear
             _dataController.isTransitioningVideo.value = false;
             _dataController.activeFeedPlayerController.value = null;
             _dataController.activeFeedPlayerVideoId.value = null;
          }


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
          ).then((_) {
            // After returning from MediaViewPage
            print("[VideoAttachmentWidget-$_videoUniqueId] Returned from MediaViewPage. isTransitioningVideo was: ${_dataController.isTransitioningVideo.value}");
            // If this video was the one being transitioned, clear the global transition flag.
            if (_dataController.isTransitioningVideo.value && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
                _dataController.isTransitioningVideo.value = false;
                // The player state (_betterPlayerController) should have been updated by MediaViewPage or initState logic on return.
                // Re-check visibility to ensure MediaVisibilityService is up-to-date.
                // This might be implicitly handled by VisibilityDetector if the widget rebuilds or visibility changes.
                // For safety, one could manually trigger a re-evaluation if needed, but VisibilityDetector usually handles it.
            }
          });
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