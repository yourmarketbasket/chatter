import 'dart:async';
import 'package:video_player/video_player.dart';
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
  VideoPlayerController? _videoPlayerController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  bool _isMuted = true;
  // _isInitialized now refers to _videoPlayerController.value.isInitialized
  String? _videoUniqueId;
  final DataController _dataController = Get.find<DataController>(); // Use Get.find if already put
  StreamSubscription? _isTransitioningVideoSubscription;
  StreamSubscription? _currentlyPlayingVideoSubscription;
  bool _disposed = false;
  bool _isPlaying = false; // Local tracking for play/pause state

  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ?? widget.key.toString();

    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    if (widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
      Object? controllerFromDataController = _dataController.activeFeedPlayerController.value;
      if (controllerFromDataController is VideoPlayerController) {
        _videoPlayerController = controllerFromDataController;
        // _isInitialized = _videoPlayerController!.value.isInitialized; // Check controller's state
        _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
        _videoPlayerController!.setLooping(true);
        // Seek is handled by MediaViewPage before passing back, or should be.
        // If not, we might need to seek here using _dataController.activeFeedPlayerPosition.value
        if (_dataController.activeFeedPlayerPosition.value != null && _videoPlayerController!.value.isInitialized) {
            _videoPlayerController!.seekTo(_dataController.activeFeedPlayerPosition.value!);
        }
        _videoPlayerController!.play();
        _isPlaying = true;
        _dataController.isTransitioningVideo.value = false; // Transition complete
         _attachListenerToController();
      } else {
        // Fallback if the controller type is wrong or null
        _initializeVideoPlayer();
      }
    } else {
      // Standard initialization, will be triggered by VisibilityDetector
      // _initializeVideoPlayer(); // Let VisibilityDetector handle initial call
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
          if (_videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
            _videoPlayerController!.pause();
            _isPlaying = false;
          }
        }
      });
    }

    _currentlyPlayingVideoSubscription = _dataController.currentlyPlayingVideoId.listen((playingId) {
      if (_disposed) return;
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized && _videoPlayerController!.value.isPlaying) {
        if (playingId != null && playingId != _videoUniqueId) {
          _videoPlayerController!.pause();
          _isPlaying = false;
          if (mounted) setState(() {});
        }
      }
    });
  }

  void _attachListenerToController() {
    _videoPlayerController?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (_disposed || !mounted || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return;
    }

    final bool newIsPlayingState = _videoPlayerController!.value.isPlaying;
    if (_isPlaying != newIsPlayingState) {
      _isPlaying = newIsPlayingState;
      if (_isPlaying) {
        _dataController.videoDidStartPlaying(_videoUniqueId!);
        if (widget.isFeedContext) {
          _dataController.activeFeedPlayerController.value = _videoPlayerController;
          _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
        }
      } else {
        _dataController.videoDidStopPlaying(_videoUniqueId!);
         if (widget.isFeedContext &&
            _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
            !_dataController.isTransitioningVideo.value) {
            // Consider if clearing active player here is always correct,
            // or if it should only happen on dispose or when another video starts.
         }
      }
      setState(() {}); // Update UI based on play/pause
    }

    if (widget.isFeedContext && _isPlaying) {
        _dataController.activeFeedPlayerPosition.value = _videoPlayerController!.value.position;
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

  void _updateDataControllerWithCurrentState() {
    if (_disposed || !widget.isFeedContext || _videoUniqueId == null || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    bool isCurrentlyPlaying = _videoPlayerController!.value.isPlaying;
    if (isCurrentlyPlaying) {
      // This instance is now the one playing
      _dataController.activeFeedPlayerController.value = _videoPlayerController;
      _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
      _dataController.activeFeedPlayerPosition.value = _videoPlayerController!.value.position;
      _dataController.videoDidStartPlaying(_videoUniqueId!); // Notify global state
    } else {
      // If this video stops, and it was the active one, and we are not transitioning
      if (_dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
          !_dataController.isTransitioningVideo.value) {
        // Potentially clear, but be careful: another video might have already taken over.
        // DataController's videoDidStopPlaying might be a better place to manage this.
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_disposed || (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)) {
      // If already initialized or widget is disposed, do nothing.
      // If controller exists, ensure it's playing if it should be (e.g. after returning from off-screen)
       if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized && !_videoPlayerController!.value.isPlaying && _dataController.currentlyPlayingVideoId.value == _videoUniqueId) {
          // This check might be too aggressive, visibility detector should handle play/pause
       }
      return;
    }

    // Dispose existing controller if any, before creating a new one
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;

    final String? attachmentUrl = widget.attachment['url'] as String?;
    if (attachmentUrl == null) {
      print("Video attachment URL is null for ID: $_videoUniqueId");
      if (mounted) setState(() {}); // Update state to reflect no player
      return;
    }

    final optimizedUrl = attachmentUrl.replaceAll(
      '/upload/',
      '/upload/q_auto:good,w_1280,h_960,c_fill/', // Consider if this optimization is still needed/compatible
    );

    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(optimizedUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: false),
    );

    try {
      await _videoPlayerController!.initialize();
      if (_disposed) { // Check if disposed while initializing
          _videoPlayerController?.dispose();
          _videoPlayerController = null;
          return;
      }
      if (mounted) {
        _videoPlayerController!.setLooping(true);
        _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
        _attachListenerToController(); // Add listener after initialization
        setState(() {}); // Update UI now that controller is initialized
        // widget.post['views'] = (widget.post['views'] as int? ?? 0) + 1; // Consider when to count view
        _updateDataControllerWithCurrentState(); // Update controller state
      }
    } catch (e) {
      print('VideoPlayer error for $_videoUniqueId: $e');
      if (!_disposed && mounted) {
        setState(() {}); // Update UI to show error or placeholder
      }
      _videoPlayerController?.dispose(); // Dispose on error
      _videoPlayerController = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _isTransitioningVideoSubscription?.cancel();
    _currentlyPlayingVideoSubscription?.cancel();
    _videoPlayerController?.removeListener(_onControllerUpdate);

    bool isTransitioningThisVideo = widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

    if (isTransitioningThisVideo) {
      // print("VideoAttachmentWidget ($_videoUniqueId) NOT disposing VideoPlayerController due to transition.");
      // The controller is passed to DataController, MediaViewPage will manage it or pass it back.
    } else {
      _videoPlayerController?.dispose();
      // print("VideoAttachmentWidget ($_videoUniqueId) normally disposing VideoPlayerController.");
      if (widget.isFeedContext && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
        // If this video was the active one and it's being disposed (not transitioned)
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
    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    final String thumbnailKey = thumbnailUrl ?? _videoUniqueId!;
    final bool isControllerInitialized = _videoPlayerController?.value.isInitialized ?? false;

    return VisibilityDetector(
      key: Key(thumbnailKey + "_visibility"), // Ensure unique key for VisibilityDetector
      onVisibilityChanged: (visibilityInfo) {
        if (_disposed) return;

        final visibleFraction = visibilityInfo.visibleFraction;
        bool isCurrentlyTransitioningThisVideo = widget.isFeedContext &&
            _dataController.isTransitioningVideo.value &&
            _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

        if (isCurrentlyTransitioningThisVideo) {
          return; // Don't interfere if transitioning
        }

        if (visibleFraction < 0.8) { // Changed from 0 to < 0.8 for pausing sooner
          if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
            if (_videoPlayerController!.value.isPlaying) {
                _videoPlayerController!.pause();
                 _isPlaying = false;
            }
            // Consider disposing if not visible for a while, but 80% rule is for starting.
            // For now, just pause. If completely off-screen (visibleFraction == 0), then dispose.
            if (visibleFraction == 0) {
                 _videoPlayerController?.removeListener(_onControllerUpdate);
                 _videoPlayerController?.dispose();
                 _videoPlayerController = null;
                 if (mounted) setState((){}); // Update UI to show thumbnail
            }
          }
        } else { // visibleFraction >= 0.8
          if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
            if (mounted) {
               _initializeVideoPlayer().then((_) {
                 // After initialization, if still >80% visible, play.
                 if (!_disposed && mounted && (_videoPlayerController?.value.isInitialized ?? false) && visibilityInfo.visibleFraction >= 0.8) {
                    if (_dataController.currentlyPlayingVideoId.value == null || _dataController.currentlyPlayingVideoId.value == _videoUniqueId) {
                       _videoPlayerController!.play();
                       _isPlaying = true;
                       _dataController.videoDidStartPlaying(_videoUniqueId!); // Inform DataController
                    }
                 }
               });
            }
          } else if (_videoPlayerController!.value.isInitialized && !_videoPlayerController!.value.isPlaying) {
             // Only play if no other video is playing or if this video is the one designated to play
             if (_dataController.currentlyPlayingVideoId.value == null || _dataController.currentlyPlayingVideoId.value == _videoUniqueId) {
                _videoPlayerController!.play();
                _isPlaying = true;
                _dataController.videoDidStartPlaying(_videoUniqueId!); // Inform DataController
             }
          }
        }
         _updateDataControllerWithCurrentState(); // Ensure DataController is updated with the latest state
      },
      child: GestureDetector(
        onTap: () {
          if (widget.isFeedContext && _videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
            // Prepare for transition to MediaViewPage
            _dataController.activeFeedPlayerController.value = _videoPlayerController;
            _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
            _dataController.activeFeedPlayerPosition.value = _videoPlayerController!.value.position;
            // Set transitioning *before* navigating to ensure MediaViewPage picks up the controller
            _dataController.isTransitioningVideo.value = true;
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

          int initialIndex = correctlyTypedPostAttachments.indexWhere((att) => att['url'] == widget.attachment['url']);
          if (initialIndex == -1) initialIndex = 0;


          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: correctlyTypedPostAttachments,
                initialIndex: initialIndex,
                message: widget.post['content'] as String? ?? '',
                userName: widget.post['username'] as String? ?? 'Unknown User',
                userAvatarUrl: widget.post['useravatar'] as String?,
                timestamp: widget.post['createdAt'] is String // Assuming 'createdAt' from post
                    ? (DateTime.tryParse(widget.post['createdAt'] as String) ?? DateTime.now())
                    : DateTime.now(),
                viewsCount: widget.post['views'] as int? ?? 0,
                likesCount: widget.post['likes'] as int? ?? 0,
                repostsCount: widget.post['reposts'] as int? ?? 0,
                // Pass the video ID for potential transition
                transitionVideoId: (widget.isFeedContext && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
                                   ? _videoUniqueId : null,
                transitionControllerType: 'video_player', // Always video_player now
              ),
            ),
          ).then((_) {
              // When returning from MediaViewPage, if this video was transitioned,
              // DataController should have isTransitioningVideo = false.
              // The controller instance might have been passed back via DataController.
              // VisibilityDetector should re-evaluate and play if needed.
              if (widget.isFeedContext && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
                  Object? controllerFromDC = _dataController.activeFeedPlayerController.value;
                  if (controllerFromDC is VideoPlayerController && controllerFromDC != _videoPlayerController) {
                      // A new controller was assigned in DC, take it over.
                      _videoPlayerController?.removeListener(_onControllerUpdate);
                      _videoPlayerController?.dispose(); // Dispose old one
                      _videoPlayerController = controllerFromDC;
                       _attachListenerToController();
                      if (mounted) setState(() {});
                  }
                  // Ensure isTransitioningVideo is false if MediaViewPage didn't set it for some reason
                  if (_dataController.isTransitioningVideo.value && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
                      _dataController.isTransitioningVideo.value = false;
                  }
              }
          });
        },
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3, // Enforce 4:3 aspect ratio for the feed
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Thumbnail as background - always show if video not initialized or playing
                if (!isControllerInitialized || !_videoPlayerController!.value.isPlaying)
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: thumbnailUrl ?? '',
                      fit: BoxFit.cover,
                      cacheManager: CustomCacheManager.instance,
                      cacheKey: thumbnailKey,
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
                            FeatherIcons.videoOff, // Changed icon for error
                            color: Colors.white.withOpacity(0.6),
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Video player widget
                if (isControllerInitialized)
                  SizedBox.expand( // Ensure the FittedBox has a defined size to work against
                    child: FittedBox(
                      fit: BoxFit.cover, // Make the video cover the 4:3 AspectRatio
                      child: SizedBox( // Required by FittedBox: child must have a size
                        width: _videoPlayerController!.value.size.width,
                        height: _videoPlayerController!.value.size.height,
                        child: VideoPlayer(_videoPlayerController!),
                      ),
                    ),
                  ),

                // Mute button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      // Prevent tap from bubbling to the parent GestureDetector if needed
                      if (_disposed || _videoPlayerController == null) return;
                      setState(() {
                        _isMuted = !_isMuted;
                        _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
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
                 // Play icon overlay if paused and initialized
                if (isControllerInitialized && !_videoPlayerController!.value.isPlaying && thumbnailUrl != null)
                    Center(
                        child: Icon(
                        Icons.play_arrow,
                        color: Colors.white.withOpacity(0.7),
                        size: 50.0,
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