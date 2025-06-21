import 'dart:async';
// import 'dart:io'; // No longer needed for Platform checks related to player choice

import 'package:better_player_enhanced/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/media_view_page.dart'; // For MediaViewPage
import 'package:chatter/services/custom_cache_manager.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Removed import for feed_models.dart


class VideoAttachmentWidget extends StatefulWidget {
  final Map<String, dynamic> attachment; // Changed to Map<String, dynamic>
  final Map<String, dynamic> post; // Changed to Map<String, dynamic>
  final BorderRadius borderRadius;
  // final int? androidVersion; // Removed
  // final bool isLoadingAndroidVersion; // Removed
  final bool isFeedContext; // Added for seamless transition logic

  const VideoAttachmentWidget({
    required Key key,
    required this.attachment,
    required this.post,
    required this.borderRadius,
    // required this.androidVersion, // Removed
    // required this.isLoadingAndroidVersion, // Removed
    this.isFeedContext = false, // Default to false
  }) : super(key: key);

  @override
  _VideoAttachmentWidgetState createState() => _VideoAttachmentWidgetState();
}

class _VideoAttachmentWidgetState extends State<VideoAttachmentWidget> with SingleTickerProviderStateMixin {
  BetterPlayerController? _betterPlayerController; // VideoPlayerController removed
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  bool _isMuted = true;
  bool _isInitialized = false;
  String? _videoUniqueId; // To identify this video instance

  // Get DataController instance
  final DataController _dataController = Get.put(DataController());
  StreamSubscription? _isTransitioningVideoSubscription;


  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ?? widget.key.toString();

    // Use androidSDKVersion from DataController - No longer needed for player choice here
    // final int currentAndroidSDKVersion = _dataController.androidSDKVersion.value;

    if (widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
      // This feed player is returning from MediaViewPage
      Object? controllerFromDataController = _dataController.activeFeedPlayerController.value;
      // bool reclaimed = false; // Not needed, direct assignment or fallback
      // Always expect BetterPlayerController now
      if (controllerFromDataController is BetterPlayerController) {
        _betterPlayerController = controllerFromDataController;
        _isInitialized = true;
        // Restore mute state, volume, looping from how it was left, or apply defaults
        _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
        _betterPlayerController!.setLooping(true);
        if (_dataController.activeFeedPlayerPosition.value != null) {
            _betterPlayerController!.seekTo(_dataController.activeFeedPlayerPosition.value!);
        }
        _betterPlayerController!.play(); // Resume playing

        _dataController.isTransitioningVideo.value = false; // Reclaimed
        // videoDidStartPlaying is handled by BetterPlayerWidget's internal listeners
        // _dataController.videoDidStartPlaying(_videoUniqueId!);
      } else {
        _initializeVideoPlayer(); // Fallback if type mismatch or other issue
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

    if (widget.isFeedContext) {
      _isTransitioningVideoSubscription = _dataController.isTransitioningVideo.listen((isTransitioning) {
        if (isTransitioning && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
          // This video is being transitioned TO MediaViewPage. Pause it here.
          if (_betterPlayerController != null && _betterPlayerController!.isPlaying()!) {
            _betterPlayerController!.pause();
          }
          // Removed VideoPlayerController check
        }
      });
    }
  }

  void _updateDataControllerWithCurrentState() {
    if (!widget.isFeedContext || _videoUniqueId == null) return;

    // Only consider _betterPlayerController
    bool isCurrentlyPlaying = _betterPlayerController != null && _betterPlayerController!.isPlaying()!;

    if (isCurrentlyPlaying) {
      _dataController.activeFeedPlayerController.value = _betterPlayerController;
      _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
      if (_betterPlayerController!.videoPlayerController != null &&
          _betterPlayerController!.videoPlayerController!.value.initialized) {
        _dataController.activeFeedPlayerPosition.value = _betterPlayerController!.videoPlayerController!.value.position;
      }
    } else {
      // If not playing.
      // If this video was the active one in DataController and it's NOT currently being transitioned out,
      // then clear its active status in DataController.
      if (_dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
          !_dataController.isTransitioningVideo.value) {
        _dataController.activeFeedPlayerController.value = null;
        _dataController.activeFeedPlayerVideoId.value = null;
        _dataController.activeFeedPlayerPosition.value = null;
      }
    }
  }


  void _initializeVideoPlayer() {
    if (_isInitialized) return; // Already initialized or reclaimed

    // Defensive disposal of existing controllers before creating new ones
    _betterPlayerController?.dispose();
    _betterPlayerController = null;
    // _videoPlayerController?.dispose(); // Removed

    // AndroidSDKVersion check for player choice is removed.
    // final int currentAndroidSDKVersion = _dataController.androidSDKVersion.value;
    // if (currentAndroidSDKVersion == 0 && Platform.isAndroid) {
    //   print("VideoAttachmentWidget: Android SDK version not yet available from DataController. Cannot initialize player yet.");
    //   return;
    // }

    final String? attachmentUrl = widget.attachment['url'] as String?;
    if (attachmentUrl == null) {
      print("Video attachment URL is null for ID: $_videoUniqueId");
      if (mounted) setState(() => _isInitialized = false);
      return;
    }

    final optimizedUrl = attachmentUrl.replaceAll(
      '/upload/',
      '/upload/q_auto:good,w_1280,h_960,c_fill/',
    );

    // Use currentAndroidSDKVersion from DataController - Removed
    // final int currentAndroidSDKVersion = _dataController.androidSDKVersion.value;
    // SDK 31 is Android 12. Use better_player if SDK < 31. - Removed
    // bool useBetterPlayer = Platform.isAndroid && currentAndroidSDKVersion < 31; - Removed

    // Conditional logic for BetterPlayer vs VideoPlayerController removed.
    // Always initialize _betterPlayerController.
    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false,
        looping: true,
        aspectRatio: 4 / 3, // Enforce 4:3 aspect ratio in feed
        fit: BoxFit.cover,   // Cover the 4:3 area, cropping if necessary
        controlsConfiguration: BetterPlayerControlsConfiguration(showControls: false, enablePlayPause: true, enableMute: true, muteIcon: FeatherIcons.volumeX, unMuteIcon: FeatherIcons.volume2,),
        handleLifecycle: false, // We manage lifecycle via VisibilityDetector mostly
        bufferingConfiguration: BetterPlayerBufferingConfiguration(
          showBufferingSpinner: false, // Hide the default buffering spinner
        ),
      ),
      betterPlayerDataSource: BetterPlayerDataSource(BetterPlayerDataSourceType.network, optimizedUrl, videoFormat: BetterPlayerVideoFormat.other,),
    )..addEventsListener((event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
            widget.post['views'] = (widget.post['views'] as int? ?? 0) + 1;
            _updateDataControllerWithCurrentState(); // Update controller state after init
          }
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          print('BetterPlayer error for $_videoUniqueId: ${event.parameters}');
          if (mounted) setState(() => _isInitialized = false);
        } else if (event.betterPlayerEventType == BetterPlayerEventType.play || event.betterPlayerEventType == BetterPlayerEventType.pause) {
            _updateDataControllerWithCurrentState();
        } else if (event.betterPlayerEventType == BetterPlayerEventType.progress && _betterPlayerController!.isPlaying()!) {
            if (widget.isFeedContext) _dataController.activeFeedPlayerPosition.value = event.parameters!['progress'] as Duration;
        }
      });
    // Block for VideoPlayerController initialization removed.
  }

  // void _videoPlayerListener() { // Removed
  //   if (!mounted) return;
  //   // This listener is primarily for updating DataController on play/pause/progress for VideoPlayerController
  //   _updateDataControllerWithCurrentState();
  //   if (widget.isFeedContext && _videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
  //        _dataController.activeFeedPlayerPosition.value = _videoPlayerController!.value.position;
  //   }
  // }

  @override
  void dispose() {
    _isTransitioningVideoSubscription?.cancel();
    // _videoPlayerController?.removeListener(_videoPlayerListener); // Removed

    bool isTransitioningThisVideo = widget.isFeedContext &&
                                  _dataController.isTransitioningVideo.value &&
                                  _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

    if (isTransitioningThisVideo) {
      // Controller is being handed over. Do not dispose here.
      print("VideoAttachmentWidget ($_videoUniqueId) NOT disposing BetterPlayerController due to transition.");
    } else {
      // _videoPlayerController?.dispose(); // Removed
      _betterPlayerController?.dispose();
      print("VideoAttachmentWidget ($_videoUniqueId) normally disposing BetterPlayerController.");
      // If this was the active feed player and it's disposed normally (not transitioning)
      if (widget.isFeedContext && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
          _dataController.activeFeedPlayerController.value = null;
          _dataController.activeFeedPlayerVideoId.value = null;
          _dataController.activeFeedPlayerPosition.value = null;
      }
    }
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use androidSDKVersion from DataController - this check might become irrelevant
    // final int currentAndroidSDKVersion = _dataController.androidSDKVersion.value;
    // if (currentAndroidSDKVersion == 0 && Platform.isAndroid) { // Still loading or unknown for Android
    // This check can be simplified or removed if better_player is always used.
    // For now, keeping a simple loading state for _isInitialized is enough.
    if (!_isInitialized && _betterPlayerController == null) { // Show placeholder if not initialized
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
      key: Key(attachmentUrlForKey ?? _videoUniqueId!),
      onVisibilityChanged: (info) {
        bool isCurrentlyTransitioningThisVideo = widget.isFeedContext &&
                                               _dataController.isTransitioningVideo.value &&
                                               _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

        if (isCurrentlyTransitioningThisVideo) {
          // If transitioning, VisibilityDetector should not interfere with the controller's state.
          // The controller is being managed for hand-off.
          return;
        }

        // Use currentAndroidSDKVersion from DataController - Removed for player choice logic
        // final int currentAndroidSDKVersion = _dataController.androidSDKVersion.value;
        // bool useBetterPlayer = Platform.isAndroid && currentAndroidSDKVersion < 31; // SDK 31 is Android 12 - Removed

        // Always use BetterPlayer logic now
        if (info.visibleFraction == 0) { // Not visible
          if (_betterPlayerController != null) {
            if (_dataController.activeFeedPlayerVideoId.value != _videoUniqueId || !_dataController.isTransitioningVideo.value) {
              _betterPlayerController!.pause();
              _betterPlayerController!.dispose();
              _betterPlayerController = null;
            }
          }
          // Removed VideoPlayerController specific logic
          if (_isInitialized && mounted) {
            // Only set to false if not transitioning this specific video
            if (_dataController.activeFeedPlayerVideoId.value != _videoUniqueId || !_dataController.isTransitioningVideo.value) {
                 setState(() => _isInitialized = false);
            }
          }
           _updateDataControllerWithCurrentState(); // Update data controller that it stopped
        } else { // Visible
          if (!_isInitialized && mounted) {
            _initializeVideoPlayer(); // Initialize if not already
          } else if (_isInitialized && _betterPlayerController != null) { // Already initialized, handle play/pause based on visibility
            if (info.visibleFraction > 0.5 && !_betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.play();
            } else if (info.visibleFraction <= 0.5 && _betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.pause();
            }
            // Removed VideoPlayerController specific logic
             _updateDataControllerWithCurrentState(); // Update data controller on play/pause
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          // Ensure DataController has the latest state if this video is playing in feed
          if (widget.isFeedContext) {
            _updateDataControllerWithCurrentState(); // Capture current state before transition
            // Always use BetterPlayer logic now
             bool isPlayingInFeed = _betterPlayerController != null && _betterPlayerController!.isPlaying()!;
            if (isPlayingInFeed) {
                 _dataController.isTransitioningVideo.value = true;
                 // activeFeedPlayerController, videoId, position are already set by _updateDataControllerWithCurrentState
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
          } else if (widget.attachment['_id'] != null) { // Assuming an '_id' field might exist
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
                // Always display BetterPlayer if initialized
                if (_isInitialized && _betterPlayerController != null && _betterPlayerController!.videoPlayerController != null && _betterPlayerController!.videoPlayerController!.value.initialized)
                  BetterPlayer(controller: _betterPlayerController!)
                // else if (!_isInitialized) removed to keep showing thumbnail instead of progress indicator for video
                // The CachedNetworkImage below will act as the background/thumbnail until the BetterPlayer is ready.
                // The placeholder within CachedNetworkImage handles the thumbnail's own loading.
                ,
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        // Always use _betterPlayerController
                        _betterPlayerController?.setVolume(_isMuted ? 0.0 : 1.0);
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
