import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/services/custom_cache_manager.dart';
import 'package:chatter/widgets/video_player_widget.dart'; // Import VideoPlayerWidget
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart'; // For VideoPlayerController type check if needed

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
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  bool _isMuted = true;
  // _isInitialized now refers to whether we should *attempt* to show the VideoPlayerWidget,
  // not whether the underlying controller is initialized.
  bool _shouldShowVideoPlayer = false;
  String? _videoUniqueId;
  final DataController _dataController = Get.put(DataController());
  StreamSubscription? _isTransitioningVideoSubscription;

  // Key to access VideoPlayerWidgetState
  final GlobalKey<_VideoPlayerWidgetState> _videoPlayerWidgetKey = GlobalKey<_VideoPlayerWidgetState>();

  VideoPlayerController? get _activeVideoPlayerController {
    // Safely access the controller from VideoPlayerWidget's state
    // This might be null if the VideoPlayerWidget is not yet built or its controller is not initialized
    try {
      // This is a conceptual way; direct access to _controller is not possible.
      // We rely on DataController to hold the active controller during transitions.
      // For direct manipulation like play/pause, we use methods exposed by _VideoPlayerWidgetState.
      if (_dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
          _dataController.activeFeedPlayerController.value is VideoPlayerController) {
        return _dataController.activeFeedPlayerController.value as VideoPlayerController?;
      }
      // Fallback or direct check if VideoPlayerWidget exposes its controller (not ideal)
      // return _videoPlayerWidgetKey.currentState?._controller; // Avoid direct access if possible
    } catch (e) {
      // print("Error accessing internal controller: $e");
    }
    return null;
  }


  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ?? widget.key.toString();

    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    // Initial state for showing player: if it's the one returning from transition.
    if (widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
        _dataController.activeFeedPlayerController.value is VideoPlayerController) {
      _shouldShowVideoPlayer = true;
      // VideoPlayerWidget's initState will handle reclaiming the controller from DataController.
      // We might need to ensure volume/looping is reapplied if VideoPlayerWidget doesn't persist these from DataController.
      // For now, assuming VideoPlayerWidget handles its state restoration well.
      // If _isMuted state here needs to affect the resumed player, we'd call:
      // Future.microtask(() => _videoPlayerWidgetKey.currentState?.setVolume(_isMuted ? 0.0 : 1.0));
    } else {
       // Default: don't show player until visible. VisibilityDetector will handle it.
      _shouldShowVideoPlayer = false;
    }


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
          // VideoPlayerWidget's internal listener for isTransitioningVideo should handle pausing
          // and updating DataController with its state if it's the one being transitioned.
          // So, direct pause from here might be redundant if VideoPlayerWidget handles it.
          // However, VideoPlayerWidget's listener updates DC *if it's playing*.
          // If VideoAttachmentWidget initiated the transition, it might need to ensure player is paused.
           _videoPlayerWidgetKey.currentState?.pause();
        }
      });
    }
  }

  void _precacheThumbnail(String thumbnailUrl) async {
    try {
      await CustomCacheManager.instance.getSingleFile(thumbnailUrl);
      // print('[VideoAttachmentWidget] Pre-cached thumbnail for $_videoUniqueId: $thumbnailUrl');
    } catch (e) {
      // print('[VideoAttachmentWidget] Error pre-caching thumbnail for $_videoUniqueId: $e');
    }
  }

  // This method's role changes. VideoPlayerWidget handles its own DataController updates internally.
  // This might be needed if VideoAttachmentWidget needs to *trigger* a state save before transition.
  void _prepareForTransitionToMediaView() {
    if (!widget.isFeedContext || _videoUniqueId == null) return;

    final vpwState = _videoPlayerWidgetKey.currentState;
    if (vpwState != null && vpwState.isVideoInitialized && vpwState.isPlaying) {
      // VideoPlayerWidget's internal listeners should already keep DataController updated
      // with activeFeedPlayerController, activeFeedPlayerVideoId, and activeFeedPlayerPosition.
      // Setting isTransitioningVideo to true here signals that this video is the one being pushed.
      _dataController.isTransitioningVideo.value = true;
       print("[VideoAttachmentWidget] Preparing for transition. Video: $_videoUniqueId. DC.isTransitioningVideo set to true.");
    } else {
      // If player isn't active or playing, clear transition state for this video in DataController
      // to avoid MediaViewPage trying to pick up a non-existent or stale state.
      if (_dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
        _dataController.activeFeedPlayerController.value = null;
        _dataController.activeFeedPlayerVideoId.value = null;
        _dataController.activeFeedPlayerPosition.value = null;
      }
      _dataController.isTransitioningVideo.value = false; // Ensure it's false if this video isn't playing
      print("[VideoAttachmentWidget] Preparing for transition. Video: $_videoUniqueId. Not playing or not initialized. DC.isTransitioningVideo set to false.");
    }
  }


  @override
  void dispose() {
    _isTransitioningVideoSubscription?.cancel();
    _pulseAnimationController.dispose();
    // VideoPlayerWidget handles its own controller's disposal, including transition logic.
    // We don't need to manually manage _dataController.activeFeedPlayerController here for disposal.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    final String? videoUrl = widget.attachment['url'] as String?;
    final String displayKey = thumbnailUrl ?? videoUrl ?? _videoUniqueId!;

    // Optimized URL construction should ideally happen once, maybe in initState or passed in.
    // For now, keeping it here for simplicity, assuming widget.attachment['url'] is the original.
    String? optimizedUrl = videoUrl;
    if (videoUrl != null && videoUrl.contains('/upload/')) {
        optimizedUrl = videoUrl.replaceAll(
        '/upload/',
        '/upload/q_auto:good,w_1280,h_960,c_fill/', // Consider making quality/res params configurable
      );
    }


    return VisibilityDetector(
      key: Key(displayKey + "_visibility"), // Ensure unique key for VisibilityDetector
      onVisibilityChanged: (info) {
        if (!mounted) return;

        bool isCurrentlyTransitioningThisVideo = widget.isFeedContext &&
            _dataController.isTransitioningVideo.value &&
            _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

        if (isCurrentlyTransitioningThisVideo) {
          // If this video is part of an active transition (e.g., returning to feed and VideoPlayerWidget
          // is handling its re-initialization from DataController), let VideoPlayerWidget manage itself.
          return;
        }

        if (info.visibleFraction == 0) { // Not visible
          if (_shouldShowVideoPlayer) {
            _videoPlayerWidgetKey.currentState?.pause();
            // Consider if we should set _shouldShowVideoPlayer = false here to force re-init.
            // This depends on whether VideoPlayerWidget correctly disposes its controller
            // when paused for a long time or if we want to aggressively free resources.
            // For now, let VideoPlayerWidget manage its internal controller's lifecycle.
            // If VideoPlayerWidget doesn't auto-dispose, we might need to tell it to.
             setState(() {
              _shouldShowVideoPlayer = false; // Force thumbnail view and VP re-init on next visibility
            });
          }
        } else { // Visible
          if (!_shouldShowVideoPlayer) {
            setState(() {
              _shouldShowVideoPlayer = true; // Build VideoPlayerWidget
            });
            // VideoPlayerWidget will initialize. Autoplay is false by default in VPW.
            // Play command needs to be issued after it's built and initialized.
            // We can use a microtask to wait for the build.
            Future.microtask(() async {
              if (mounted && info.visibleFraction > 0.5) {
                 await _videoPlayerWidgetKey.currentState?.play();
                 if (mounted) {
                    _videoPlayerWidgetKey.currentState?.setVolume(_isMuted ? 0.0 : 1.0);
                 }
              }
            });

          } else if (_videoPlayerWidgetKey.currentState?.isVideoInitialized ?? false) {
            final vpwState = _videoPlayerWidgetKey.currentState!;
            if (info.visibleFraction > 0.5 && !vpwState.isPlaying) {
              vpwState.play();
              vpwState.setVolume(_isMuted ? 0.0 : 1.0); // Re-apply mute status
            } else if (info.visibleFraction <= 0.5 && vpwState.isPlaying) {
              vpwState.pause();
            }
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (widget.isFeedContext) {
            // This call ensures DataController has the latest state from VideoPlayerWidget
            // before we set isTransitioningVideo to true.
            // VideoPlayerWidget itself updates DC on play/pause/progress.
            // This call here is more of a "just before navigating, ensure DC is absolutely current".
            // _videoPlayerWidgetKey.currentState?.updateDataControllerWithCurrentState(); // VPW does this internally
            _prepareForTransitionToMediaView();
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
                  // print('[VideoAttachmentWidget] Error converting attachment item Map to Map<String, dynamic>: $e for item $item');
                }
              } else {
                // print('[VideoAttachmentWidget] Skipping non-map attachment item: $item');
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
            aspectRatio: 4 / 3, // Enforced by AspectRatio
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Thumbnail as background
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    cacheManager: CustomCacheManager.instance,
                    cacheKey: displayKey,
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
                          FeatherIcons.videoOff, // Changed to videoOff for error
                          color: Colors.white.withOpacity(0.6),
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                // Video player overlay
                if (_shouldShowVideoPlayer && optimizedUrl != null)
                  VideoPlayerWidget(
                    key: _videoPlayerWidgetKey, // Use the GlobalKey
                    url: optimizedUrl,
                    displayPath: optimizedUrl, // Or some other meaningful path/ID
                    thumbnailUrl: thumbnailUrl, // Pass thumbnail for VPW's own loading phase
                    isFeedContext: widget.isFeedContext,
                    loop: true,
                    showPlayerControls: false, // Crucial for VideoAttachmentWidget's UI
                    fit: BoxFit.cover, // VideoPlayerWidget will use this
                    // aspectRatio: 4 / 3, // VideoPlayerWidget will use this if provided, else intrinsic
                                          // Since parent AspectRatio enforces 4/3, VPW's aspectRatio prop might not be strictly needed here
                                          // if its internal FittedBox scales correctly within the parent AspectRatio.
                                          // For safety, we can pass it.
                  )
                else if (optimizedUrl == null && _shouldShowVideoPlayer)
                   Center(child: Text("Video URL is missing.", style: TextStyle(color: Colors.white, backgroundColor: Colors.black54))),

                // Mute button - always visible if player is supposed to be active
                if (_shouldShowVideoPlayer && optimizedUrl != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                        _videoPlayerWidgetKey.currentState?.setVolume(_isMuted ? 0.0 : 1.0);
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