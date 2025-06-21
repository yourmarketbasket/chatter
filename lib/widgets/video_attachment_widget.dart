import 'dart:async';
import 'package:video_player/video_player.dart'; // Changed from better_player
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/widgets/video_player_widget.dart' as global_video_player; // Use the global player
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
  // We will now use the global_video_player.VideoPlayerWidget directly
  // No direct controller needed here as the global_video_player.VideoPlayerWidget manages its own.
  // BetterPlayerController? _betterPlayerController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  // bool _isMuted = true; // Mute state will be managed by VideoPlayerWidget or globally if needed
  // bool _isInitialized = false; // Initialization state managed by VideoPlayerWidget
  String? _videoUniqueId;
  final DataController _dataController = Get.find<DataController>(); // Get.put might be problematic if not first init
  // StreamSubscription? _isTransitioningVideoSubscription; // Handled by VideoPlayerWidget

  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.attachment['url'] as String? ?? widget.key.toString();

    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      _precacheThumbnail(thumbnailUrl);
    }

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    _pulseAnimationController.repeat(reverse: true);

    // No direct video player initialization here anymore.
    // The global_video_player.VideoPlayerWidget will handle its own lifecycle.
    // Transition listening specific to this widget context might be removed or adapted
    // if global_video_player.VideoPlayerWidget handles it based on its `isFeedContext` and `_videoUniqueId`.
  }

  void _precacheThumbnail(String thumbnailUrl) async {
    try {
      await CustomCacheManager.instance.getSingleFile(thumbnailUrl);
      print('[VideoAttachmentWidget] Pre-cached thumbnail for $_videoUniqueId: $thumbnailUrl');
    } catch (e) {
      print('[VideoAttachmentWidget] Error pre-caching thumbnail for $_videoUniqueId: $e');
    }
  }

  // _updateDataControllerWithCurrentState and _initializeVideoPlayer are removed
  // as these responsibilities are now within global_video_player.VideoPlayerWidget.

  @override
  void dispose() {
    // _isTransitioningVideoSubscription?.cancel(); // Handled by VideoPlayerWidget
    // Controller disposal is handled by VideoPlayerWidget.
    // Any specific cleanup for VideoAttachmentWidget itself.
    _pulseAnimationController.dispose();
    print("VideoAttachmentWidget ($_videoUniqueId) disposed.");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? thumbnailUrl = widget.attachment['thumbnailUrl'] as String?;
    final String? videoUrl = widget.attachment['url'] as String?;
    final String displayPath = videoUrl ?? _videoUniqueId ?? 'video_attachment';
    final String thumbnailKey = thumbnailUrl ?? _videoUniqueId!;

    // The VisibilityDetector logic for play/pause is largely handled by VideoPlayerWidget.
    // Here, we primarily use it to decide whether to show the player or just the thumbnail.
    // However, VideoPlayerWidget itself has thumbnail and placeholder logic.
    // This simplifies VideoAttachmentWidget significantly.

    return GestureDetector(
      onTap: () {
        // Logic for navigating to MediaViewPage
        // This needs to correctly set up transition state in DataController if this video is playing.
        // The VideoPlayerWidget instance for this attachment would have its controller.
        // We need a way to tell DataController that *this specific* VideoPlayerWidget's controller
        // is the one to transition. This might require VideoPlayerWidget to expose its controller or
        // for DataController to be updated by VideoPlayerWidget when it starts playing.

        // Current VideoPlayerWidget updates DataController on play/pause.
        // So, if it's playing, DataController.activeFeedPlayerController should be set.
        if (widget.isFeedContext && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
             // If this video is currently the active one in DataController (meaning it's likely playing or was last active)
            _dataController.isTransitioningVideo.value = true;
             print("[VideoAttachmentWidget] Tapped. Marking video $_videoUniqueId for transition. DC.isTransitioningVideo = true");
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
        } else if (widget.attachment['_id'] != null) { // Assuming attachments might have an _id
          initialIndex = correctlyTypedPostAttachments.indexWhere((att) => att['_id'] == widget.attachment['_id']);
        }
        if (initialIndex == -1) { // Fallback if URL or _id doesn't match, try object equality (less reliable for maps)
            initialIndex = correctlyTypedPostAttachments.indexWhere((att) => att['filename'] == widget.attachment['filename']); // Example fallback
            if(initialIndex == -1) initialIndex = 0; // Default to first if no match
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
              // Pass transition details for the *specific video* being opened
              transitionVideoId: _videoUniqueId, // The ID of the video in this attachment
              transitionControllerType: 'video_player', // Since we are standardizing on video_player
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: AspectRatio(
          aspectRatio: 4 / 3, // Or derive from widget.attachment if available and needed
          child: global_video_player.VideoPlayerWidget(
            key: ValueKey(_videoUniqueId), // Use a unique key for the player instance
            url: videoUrl,
            // file: widget.attachment['file'] as File?, // Assuming 'file' might exist for local videos
            displayPath: displayPath,
            thumbnailUrl: thumbnailUrl,
            isFeedContext: widget.isFeedContext,
          ),
        ),
      ),
    );
  }
}