import 'dart:async';
import 'package:better_player_enhanced/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/services/custom_cache_manager.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoAttachmentWidget extends StatefulWidget {
  final Map<String, dynamic> attachment;
  final Map<String, dynamic> post;
  final BorderRadius borderRadius;
  final bool isFeedContext;

  const VideoAttachmentWidget({
    required Key key,
    required this.attachment,
    required this.post,
    required this.borderRadius,
    this.isFeedContext = false,
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
  String? _videoUniqueId;
  final DataController _dataController = Get.put(DataController());
  StreamSubscription? _isTransitioningVideoSubscription;

  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ?? widget.key.toString();

    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    // Attempt to reclaim controller if returning from transition
    if (widget.isFeedContext &&
        _dataController.isTransitioningVideo.value == false && // Important: check if transition *just finished*
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
        _dataController.activeFeedPlayerController.value is BetterPlayerController) {

      print("[VideoAttachmentWidget initState] Reclaiming controller for $_videoUniqueId");
      _betterPlayerController = _dataController.activeFeedPlayerController.value as BetterPlayerController?;
      if (_betterPlayerController != null) {
        _isInitialized = true;
        _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
        _betterPlayerController!.setLooping(true); // Ensure looping is set for feed
        // Don't auto-play here, VisibilityDetector will handle it.
        // Clear the controller from DataController as it's now locally managed
        // _dataController.activeFeedPlayerController.value = null;
        // _dataController.activeFeedPlayerVideoId.value = null;
        // _dataController.activeFeedPlayerPosition.value = null;
        // No, let MediaViewPage's dispose handle clearing these when it's truly done.
      } else {
        _initializeVideoPlayer(); // Fallback if controller is somehow null
      }
    } else {
      _initializeVideoPlayer();
    }

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    _pulseAnimationController.repeat(reverse: true);

    // Listen for when this video *starts* a transition TO MediaViewPage
    if (widget.isFeedContext) {
      _isTransitioningVideoSubscription = _dataController.isTransitioningVideo.listen((isTransitioning) {
        if (isTransitioning && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
          // This video is about to be transitioned. Pause it if playing.
          if (_betterPlayerController != null && _betterPlayerController!.isPlaying()!) {
            print("[VideoAttachmentWidget] Transitioning out $_videoUniqueId, pausing.");
            _betterPlayerController!.pause();
            // The controller instance itself will be passed via DataController
          }
        }
      });
    }
  }

  void _precacheThumbnail(String thumbnailUrl) async {
    try {
      await CustomCacheManager.instance.getSingleFile(thumbnailUrl);
      // print('[VideoAttachmentWidget] Pre-cached thumbnail for $_videoUniqueId: $thumbnailUrl');
    } catch (e) {
      print('[VideoAttachmentWidget] Error pre-caching thumbnail for $_videoUniqueId: $e');
    }
  }

  void _updateDataControllerForTransition() {
    if (!widget.isFeedContext || _videoUniqueId == null || _betterPlayerController == null) return;

    print("[VideoAttachmentWidget] Preparing $_videoUniqueId for transition to MediaViewPage.");
    _dataController.activeFeedPlayerController.value = _betterPlayerController;
    _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
    if (_betterPlayerController!.videoPlayerController != null &&
        _betterPlayerController!.videoPlayerController!.value.initialized) {
      _dataController.activeFeedPlayerPosition.value = _betterPlayerController!.videoPlayerController!.value.position;
    }
    _dataController.isTransitioningVideo.value = true; // Signal that transition is starting
  }


  void _initializeVideoPlayer() {
    if (_isInitialized && _betterPlayerController != null) {
        // If already initialized and controller exists, ensure settings like volume are correct
        _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
        _betterPlayerController!.setLooping(true);
        return;
    }
    // If controller exists but not initialized, dispose it first
    _betterPlayerController?.dispose();
    _betterPlayerController = null;
    _isInitialized = false; // Reset initialization state

    final String? attachmentUrl = widget.attachment['url'] as String?;
    if (attachmentUrl == null) {
      print("[VideoAttachmentWidget initializeVideoPlayer] Video attachment URL is null for ID: $_videoUniqueId");
      if (mounted) setState(() {}); // Update UI to reflect no player
      return;
    }

    print("[VideoAttachmentWidget initializeVideoPlayer] Initializing for $_videoUniqueId");

    final optimizedUrl = attachmentUrl.replaceAll(
      '/upload/',
      '/upload/q_auto:good,w_1280,h_960,c_fill/', // Consider making dimensions dynamic or appropriate for 4:3
    );

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false, // VisibilityDetector will handle play
        looping: true,
        aspectRatio: 4 / 3, // Maintained for feed context
        fit: BoxFit.cover,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
          enablePlayPause: true, // Internal flags, not visible UI controls
          enableMute: true,
          muteIcon: FeatherIcons.volumeX,
          unMuteIcon: FeatherIcons.volume2,
          loadingWidget: const SizedBox.shrink(), // Minimal loading indicator
        ),
        handleLifecycle: true, // Changed to true
        autoDispose: false,    // Changed to false
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        optimizedUrl,
        videoFormat: BetterPlayerVideoFormat.other, // Let BetterPlayer determine
        cacheConfiguration: BetterPlayerCacheConfiguration(
          useCache: true,
          preCacheSize: 10 * 1024 * 1024,
          maxCacheSize: 100 * 1024 * 1024,
          maxCacheFileSize: 10 * 1024 * 1024,
        ),
      ),
    )..addEventsListener((event) {
        if (!mounted) return;

        switch (event.betterPlayerEventType) {
          case BetterPlayerEventType.initialized:
            print("[VideoAttachmentWidget] Initialized: $_videoUniqueId");
            setState(() => _isInitialized = true);
            _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
            // widget.post['views'] = (widget.post['views'] as int? ?? 0) + 1; // Consider moving view count logic
            // Playback will be handled by VisibilityDetector
            break;
          case BetterPlayerEventType.exception:
            print('[VideoAttachmentWidget] Error for $_videoUniqueId: ${event.parameters?['message']}');
            _disposePlayer(); // Dispose on exception
            break;
          case BetterPlayerEventType.play:
            // print("[VideoAttachmentWidget] Playing: $_videoUniqueId");
            if (_dataController.currentlyPlayingVideoId.value != _videoUniqueId) {
                 _dataController.videoDidStartPlaying(_videoUniqueId!); // Manage single active player
            }
            break;
          case BetterPlayerEventType.pause:
            // print("[VideoAttachmentWidget] Paused: $_videoUniqueId");
            break;
          case BetterPlayerEventType.progress:
            if (widget.isFeedContext && (_betterPlayerController?.isPlaying() ?? false) && _dataController.isTransitioningVideo.value && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
               _dataController.activeFeedPlayerPosition.value = event.parameters!['progress'] as Duration;
            }
            break;
          default:
            break;
        }
      });
  }

  void _disposePlayer({bool dueToTransition = false}) {
    if (_betterPlayerController == null) return;

    if (dueToTransition) {
      print("[VideoAttachmentWidget _disposePlayer] Preparing $_videoUniqueId for transition. Not disposing controller instance.");
      // State (position, etc.) should have been captured by _updateDataControllerForTransition()
      // The controller instance is passed to DataController.
    } else {
      print("[VideoAttachmentWidget _disposePlayer] Disposing controller for $_videoUniqueId.");
      _betterPlayerController!.dispose();
      _betterPlayerController = null;
    }
    if (mounted) {
      setState(() {
        _isInitialized = false;
      });
    }
  }


  @override
  void dispose() {
    _isTransitioningVideoSubscription?.cancel();
    _pulseAnimationController.dispose();

    // If this widget is disposed, and it was the one holding the controller that MediaViewPage might be using,
    // MediaViewPage's own dispose logic should handle clearing DataController's transition state.
    // Here, we only dispose if it's not part of an *active* transition *originating from this instance*.
    bool isCurrentlyTransitioningThisVideoOut = widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
        _dataController.activeFeedPlayerController.value == _betterPlayerController;

    if (!isCurrentlyTransitioningThisVideoOut) {
        _disposePlayer();
    } else {
        print("[VideoAttachmentWidget dispose] $_videoUniqueId is transitioning out. Controller not disposed here.");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    final String thumbnailKey = thumbnailUrl ?? _videoUniqueId!; // Unique key for VisibilityDetector and Cache

    return VisibilityDetector(
      key: Key("vis_${_videoUniqueId}_${widget.key.toString()}"), // More unique key for VisibilityDetector
      onVisibilityChanged: (visibilityInfo) {
        if (!mounted) return;

        final bool isVisible = visibilityInfo.visibleFraction > 0.5;
        final bool canPlay = _isInitialized && _betterPlayerController != null;

        // Check if this video is currently being transitioned to MediaViewPage
        bool isTransitioningThisVideoToMediaView = _dataController.isTransitioningVideo.value &&
                                                 _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
                                                 _dataController.activeFeedPlayerController.value == _betterPlayerController;
        if (isTransitioningThisVideoToMediaView) {
            // If it's being transitioned, don't interfere with its state from here.
            // MediaViewPage will take control.
            print("[VideoAttachmentWidget Visibility] $_videoUniqueId is transitioning. Visibility changes ignored.");
            return;
        }

        // Check if another video is transitioning from feed (which is not this one)
        bool anotherVideoIsTransitioning = _dataController.isTransitioningVideo.value &&
                                           _dataController.activeFeedPlayerVideoId.value != _videoUniqueId;
        if (anotherVideoIsTransitioning) {
            if (_betterPlayerController?.isPlaying() ?? false) {
                _betterPlayerController?.pause();
            }
            print("[VideoAttachmentWidget Visibility] Another video is transitioning. $_videoUniqueId paused if playing.");
            return; // Don't manage this player if another is actively transitioning
        }


        if (isVisible) {
          if (!_isInitialized) {
            _initializeVideoPlayer();
          } else if (canPlay && !(_betterPlayerController!.isPlaying()!)) {
            // Only play if this is the designated currentlyPlayingVideo or no video is playing
            if (_dataController.currentlyPlayingVideoId.value == null || _dataController.currentlyPlayingVideoId.value == _videoUniqueId) {
              _betterPlayerController!.play();
            } else {
               // Another video is supposed to be playing, so ensure this one is paused.
              _betterPlayerController!.pause();
            }
          }
        } else { // Not visible enough
          if (canPlay && _betterPlayerController!.isPlaying()!) {
            _betterPlayerController!.pause();
          }
          // More aggressive disposal: if completely off-screen (visibleFraction == 0)
          // and not part of any transition process.
          if (visibilityInfo.visibleFraction == 0 && _betterPlayerController != null) {
             bool isThisVideoInActiveTransition = _dataController.isTransitioningVideo.value &&
                                                 _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;
             if (!isThisVideoInActiveTransition) {
                print("[VideoAttachmentWidget Visibility] $_videoUniqueId is off-screen. Disposing player.");
                _disposePlayer();
             } else {
                print("[VideoAttachmentWidget Visibility] $_videoUniqueId is off-screen but in transition. Not disposing.");
             }
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (widget.isFeedContext && _betterPlayerController != null && _isInitialized) {
            // Prepare DataController for transition
            _updateDataControllerForTransition();
            }
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
                  print('[VideoAttachmentWidget] Error converting attachment item Map to Map<String, dynamic>: $e for item $item');
                }
              } else {
                print('[VideoAttachmentWidget] Skipping non-map attachment item: $item');
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
            aspectRatio: 4 / 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Thumbnail as background
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    cacheManager: CustomCacheManager.instance,
                    cacheKey: thumbnailKey, // Ensure unique cache key
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
                // Video player overlay
                if (_isInitialized &&
                    _betterPlayerController != null &&
                    _betterPlayerController!.videoPlayerController != null &&
                    _betterPlayerController!.videoPlayerController!.value.initialized)
                  BetterPlayer(controller: _betterPlayerController!),
                // Mute button
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