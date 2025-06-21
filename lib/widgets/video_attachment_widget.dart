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

    // Simplified initialization: always initialize its own player.
    // VisibilityDetector will handle play/pause/creation/disposal.
    // No direct adoption of controller from DataController here.
    // _initializeVideoPlayer(); // Will be called by VisibilityDetector if visible

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    _pulseAnimationController.repeat(reverse: true);

    // This subscription is to pause this feed player if MediaViewPage starts playing *this* video.
    // This is more of a "pause if another view takes over this specific video"
    if (widget.isFeedContext) {
      _isTransitioningVideoSubscription = _dataController.isTransitioningVideo.listen((isTransitioning) {
        if (isTransitioning && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
          // If this video is the one being transitioned TO MediaViewPage,
          // this feed instance should pause.
          if (_betterPlayerController != null && _betterPlayerController!.isPlaying()!) {
            _betterPlayerController!.pause();
            print("VideoAttachmentWidget ($_videoUniqueId) paused because it's transitioning to MediaViewPage.");
          }
        }
      });
    }
  }

  void _precacheThumbnail(String thumbnailUrl) async {
    try {
      await CustomCacheManager.instance.getSingleFile(thumbnailUrl);
      print('[VideoAttachmentWidget] Pre-cached thumbnail for $_videoUniqueId: $thumbnailUrl');
    } catch (e) {
      print('[VideoAttachmentWidget] Error pre-caching thumbnail for $_videoUniqueId: $e');
    }
  }

  // _updateDataControllerWithCurrentState is primarily for when this feed player *is* the active one.
  // With controller passing removed, this is less about setting activeFeedPlayerController.
  // It's more about updating position if it's playing, for potential future transitions.
  void _updateDataControllerWithPlayingState() {
    if (!widget.isFeedContext || _videoUniqueId == null || _betterPlayerController == null) return;

    bool isCurrentlyPlaying = _betterPlayerController!.isPlaying() ?? false;
    if (isCurrentlyPlaying) {
      // If this video starts playing, it becomes the "active" one in terms of ID and position for transition purposes.
      _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
      if (_betterPlayerController!.videoPlayerController != null &&
          _betterPlayerController!.videoPlayerController!.value.initialized) {
        _dataController.activeFeedPlayerPosition.value = _betterPlayerController!.videoPlayerController!.value.position;
      }
    } else {
      // If it stops, and it was the active one, clear its status *unless* it's currently transitioning.
      if (_dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
          !(_dataController.isTransitioningVideo.value && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) ) {
        // _dataController.activeFeedPlayerVideoId.value = null; // Don't null out ID, MediaView might need it briefly
        // _dataController.activeFeedPlayerPosition.value = null; // Position is stale if not playing
      }
    }
  }


  void _initializeVideoPlayer() {
    // if (_isInitialized) return; // Allow re-initialization if disposed and then made visible again

    if (_betterPlayerController != null) {
        // If a controller exists, ensure it's disposed before creating a new one.
        // This can happen if VisibilityDetector quickly toggles visibility.
        _betterPlayerController!.dispose();
        _betterPlayerController = null;
        _isInitialized = false; // Reset initialization state
        print("VideoAttachmentWidget ($_videoUniqueId) disposed existing controller before re-initializing.");
    }

    final String? attachmentUrl = widget.attachment['url'] as String?;
    if (attachmentUrl == null) {
      print("Video attachment URL is null for ID: $_videoUniqueId");
      if (mounted) setState(() => _isInitialized = false); // Keep UI reflecting no player
      return;
    }

    final optimizedUrl = attachmentUrl.replaceAll(
      '/upload/',
      '/upload/q_auto:good,w_1280,h_960,c_fill/',
    );
    print("VideoAttachmentWidget ($_videoUniqueId) initializing player.");

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false, // VisibilityDetector will handle play
        looping: true,
        aspectRatio: 4 / 3,
        fit: BoxFit.cover,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
          enablePlayPause: true,
          enableMute: true,
          muteIcon: FeatherIcons.volumeX,
          unMuteIcon: FeatherIcons.volume2,
          loadingWidget: const SizedBox.shrink(),
        ),
        handleLifecycle: false, // We handle with VisibilityDetector
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        optimizedUrl,
        videoFormat: BetterPlayerVideoFormat.other,
        cacheConfiguration: BetterPlayerCacheConfiguration(
          useCache: true,
          preCacheSize: 10 * 1024 * 1024, // 10MB
          maxCacheSize: 100 * 1024 * 1024, // 100MB
          maxCacheFileSize: 10 * 1024 * 1024, // 10MB per file
        ),
      ),
    )..addEventsListener((event) {
        if (!mounted) return; // Widget might have been disposed while event was pending

        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          setState(() => _isInitialized = true);
          _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
          // widget.post['views'] = (widget.post['views'] as int? ?? 0) + 1; // View count can be handled differently, e.g., on first play or visibility
           _updateDataControllerWithPlayingState();
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          print('BetterPlayer error for $_videoUniqueId: ${event.parameters}');
          setState(() => _isInitialized = false); // Reflect error state
          // Consider disposing the controller on exception to free resources
           _betterPlayerController?.dispose();
           _betterPlayerController = null;
        } else if (event.betterPlayerEventType == BetterPlayerEventType.play ||
            event.betterPlayerEventType == BetterPlayerEventType.pause) {
           _updateDataControllerWithPlayingState();
        } else if (event.betterPlayerEventType == BetterPlayerEventType.progress &&
            (_betterPlayerController?.isPlaying() ?? false)) {
          if (widget.isFeedContext) {
            // Update position in DataController if this video is considered the active one for transition
            if(_dataController.activeFeedPlayerVideoId.value == _videoUniqueId){
                 _dataController.activeFeedPlayerPosition.value = event.parameters!['progress'] as Duration;
            }
          }
        }
      });
  }

  @override
  void dispose() {
    _isTransitioningVideoSubscription?.cancel();

    // If this video is currently marked as transitioning in DataController,
    // it means MediaViewPage *might* be about to use its details (URL, last position).
    // However, this feed widget instance is being disposed.
    // The controller itself should be disposed. MediaViewPage will create its own.
    // The main concern is if DataController.isTransitioningVideo is not cleared
    // after MediaViewPage is done. That's outside this widget's direct control post-disposal.

    _betterPlayerController?.dispose();
    print("VideoAttachmentWidget ($_videoUniqueId) disposed BetterPlayerController in main dispose method.");

    // If this widget was the one whose details are in DataController for a potential transition,
    // and now it's being disposed (e.g. scrolled far away, feed cleared),
    // we should clear these details if they are specific to *this instance* preparing to transition.
    // However, if MediaViewPage is already open using this video's ID/pos, clearing here might be too soon.
    // This highlights the need for MediaViewPage to signal when it's done.
    // For now, let's assume DataController.isTransitioningVideo will be managed externally (e.g., by MediaViewPage closing).
    // if (_dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
    //     !_dataController.isTransitioningVideo.value) { // Only clear if NOT currently in an active transition state
    //   _dataController.activeFeedPlayerVideoId.value = null;
    //   _dataController.activeFeedPlayerPosition.value = null;
    // }

    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    final String thumbnailKey = thumbnailUrl ?? _videoUniqueId!;

    return VisibilityDetector(
      key: Key(thumbnailKey),
      onVisibilityChanged: (info) {
        // If this video is currently flagged for transition TO MediaViewPage,
        // its state in the feed should be managed carefully (e.g. stay paused).
        // The primary concern is disposing it if it scrolls out of view *while* flagged.
        bool isThisVideoTransitioningOut = _dataController.isTransitioningVideo.value &&
                                        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

        if (info.visibleFraction == 0) {
          // Video is not visible
          if (_betterPlayerController != null) {
            print("VideoAttachmentWidget ($_videoUniqueId) became not visible. Pausing and disposing controller.");
            _betterPlayerController!.pause();
            _betterPlayerController!.dispose();
            _betterPlayerController = null;
          }
          if (mounted) {
            setState(() => _isInitialized = false);
          }
          // If it became non-visible and it was the one transitioning, this is tricky.
          // MediaViewPage should ideally have already launched or is about to.
          // The isTransitioningVideo flag should be reset by MediaViewPage's lifecycle.
        } else {
          // Video is visible
          if (!_isInitialized && mounted) {
            print("VideoAttachmentWidget ($_videoUniqueId) became visible. Initializing player.");
            _initializeVideoPlayer();
          } else if (_isInitialized && _betterPlayerController != null) {
            // If it's visible and initialized:
            // Play if more than 50% visible and not currently transitioning out to MediaViewPage.
            // Pause if less than 50% visible (and was playing).
            if (info.visibleFraction > 0.5 && !_betterPlayerController!.isPlaying()! && !isThisVideoTransitioningOut) {
              print("VideoAttachmentWidget ($_videoUniqueId) >50% visible. Playing.");
              _betterPlayerController!.play();
            } else if (info.visibleFraction <= 0.5 && _betterPlayerController!.isPlaying()!) {
              print("VideoAttachmentWidget ($_videoUniqueId) <50% visible. Pausing.");
              _betterPlayerController!.pause();
            }
          }
        }
        _updateDataControllerWithPlayingState(); // Update position if playing
      },
      child: GestureDetector(
        onTap: () {
          Duration currentPosition = Duration.zero;
          if (_betterPlayerController != null && _betterPlayerController!.videoPlayerController != null && _betterPlayerController!.videoPlayerController!.value.initialized) {
            currentPosition = _betterPlayerController!.videoPlayerController!.value.position;
            // Pause the feed player before navigating
            if (_betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.pause();
            }
          }

          // Set transition state in DataController
          // This signals to MediaViewPage which video and from what position to potentially start.
          _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
          _dataController.activeFeedPlayerPosition.value = currentPosition;
          _dataController.isTransitioningVideo.value = true; // Signal that a transition is starting

          print("VideoAttachmentWidget ($_videoUniqueId) tapped. Transitioning to MediaViewPage. Position: $currentPosition");

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