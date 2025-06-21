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

    // Pre-cache the thumbnail
    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    // Initialize video player (unchanged)
    if (widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
      Object? controllerFromDataController = _dataController.activeFeedPlayerController.value;
      if (controllerFromDataController is BetterPlayerController) {
        _betterPlayerController = controllerFromDataController;
        _isInitialized = true;
        _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
        _betterPlayerController!.setLooping(true);
        if (_dataController.activeFeedPlayerPosition.value != null) {
          _betterPlayerController!.seekTo(_dataController.activeFeedPlayerPosition.value!);
        }
        _betterPlayerController!.play();
        _dataController.isTransitioningVideo.value = false;
      } else {
        _initializeVideoPlayer();
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
          if (_betterPlayerController != null && _betterPlayerController!.isPlaying()!) {
            _betterPlayerController!.pause();
          }
        }
      });
    }
  }

  // New method to pre-cache thumbnail
  void _precacheThumbnail(String thumbnailUrl) async {
    try {
      await CustomCacheManager.instance.getSingleFile(thumbnailUrl);
      print('[VideoAttachmentWidget] Pre-cached thumbnail for $_videoUniqueId: $thumbnailUrl');
    } catch (e) {
      print('[VideoAttachmentWidget] Error pre-caching thumbnail for $_videoUniqueId: $e');
    }
  }

  void _updateDataControllerWithCurrentState() {
    if (!widget.isFeedContext || _videoUniqueId == null) return;

    bool isCurrentlyPlaying = _betterPlayerController != null && _betterPlayerController!.isPlaying()!;
    if (isCurrentlyPlaying) {
      _dataController.activeFeedPlayerController.value = _betterPlayerController;
      _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
      if (_betterPlayerController!.videoPlayerController != null &&
          _betterPlayerController!.videoPlayerController!.value.initialized) {
        _dataController.activeFeedPlayerPosition.value = _betterPlayerController!.videoPlayerController!.value.position;
      }
    } else {
      if (_dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
          !_dataController.isTransitioningVideo.value) {
        _dataController.activeFeedPlayerController.value = null;
        _dataController.activeFeedPlayerVideoId.value = null;
        _dataController.activeFeedPlayerPosition.value = null;
      }
    }
  }

  void _initializeVideoPlayer() {
    if (_isInitialized) return;

    _betterPlayerController?.dispose();
    _betterPlayerController = null;

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

    _betterPlayerController = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: false,
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
        handleLifecycle: false,
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
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
            widget.post['views'] = (widget.post['views'] as int? ?? 0) + 1;
            _updateDataControllerWithCurrentState();
          }
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          print('BetterPlayer error for $_videoUniqueId: ${event.parameters}');
          if (mounted) setState(() => _isInitialized = false);
        } else if (event.betterPlayerEventType == BetterPlayerEventType.play ||
            event.betterPlayerEventType == BetterPlayerEventType.pause) {
          _updateDataControllerWithCurrentState();
        } else if (event.betterPlayerEventType == BetterPlayerEventType.progress &&
            _betterPlayerController!.isPlaying()!) {
          if (widget.isFeedContext) {
            _dataController.activeFeedPlayerPosition.value = event.parameters!['progress'] as Duration;
          }
        }
      });
  }

  @override
  void dispose() {
    _isTransitioningVideoSubscription?.cancel();
    bool isTransitioningThisVideo = widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

    if (isTransitioningThisVideo) {
      print("VideoAttachmentWidget ($_videoUniqueId) NOT disposing BetterPlayerController due to transition.");
    } else {
      _betterPlayerController?.dispose();
      print("VideoAttachmentWidget ($_videoUniqueId) normally disposing BetterPlayerController.");
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
    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    final String thumbnailKey = thumbnailUrl ?? _videoUniqueId!;

    return VisibilityDetector(
      key: Key(thumbnailKey),
      onVisibilityChanged: (info) {
        bool isCurrentlyTransitioningThisVideo = widget.isFeedContext &&
            _dataController.isTransitioningVideo.value &&
            _dataController.activeFeedPlayerVideoId.value == _videoUniqueId;

        if (isCurrentlyTransitioningThisVideo) {
          return;
        }

        if (info.visibleFraction == 0) {
          if (_betterPlayerController != null) {
            if (_dataController.activeFeedPlayerVideoId.value != _videoUniqueId ||
                !_dataController.isTransitioningVideo.value) {
              _betterPlayerController!.pause();
              _betterPlayerController!.dispose();
              _betterPlayerController = null;
            }
          }
          if (_isInitialized && mounted) {
            if (_dataController.activeFeedPlayerVideoId.value != _videoUniqueId ||
                !_dataController.isTransitioningVideo.value) {
              setState(() => _isInitialized = false);
            }
          }
          _updateDataControllerWithCurrentState();
        } else {
          if (!_isInitialized && mounted) {
            _initializeVideoPlayer();
          } else if (_isInitialized && _betterPlayerController != null) {
            if (info.visibleFraction > 0.5 && !_betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.play();
            } else if (info.visibleFraction <= 0.5 && _betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.pause();
            }
            _updateDataControllerWithCurrentState();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (widget.isFeedContext) {
            _updateDataControllerWithCurrentState();
            bool isPlayingInFeed = _betterPlayerController != null && _betterPlayerController!.isPlaying()!;
            if (isPlayingInFeed) {
              _dataController.isTransitioningVideo.value = true;
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