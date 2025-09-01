import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/helpers/verification_helper.dart';
import 'package:chatter/pages/main_chats.dart';
import 'package:chatter/pages/new-posts-page.dart';
import 'package:chatter/pages/reply_page.dart' hide Padding; // Attempt to resolve conflict
// import 'package:chatter/pages/repost_page.dart'; // Removed
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/pages/search_page.dart';
import 'package:chatter/services/media_visibility_service.dart'; // Import MediaVisibilityService
import 'package:chatter/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
// import 'package:record/record.dart'; // Not used
// import 'package:audioplayers/audioplayers.dart'; // Not used directly here
// import 'package:video_player/video_player.dart'; // Not used directly here
// import 'package:visibility_detector/visibility_detector.dart'; // Not used directly here
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:path_provider/path_provider.dart'; // Not used
// import 'package:permission_handler/permission_handler.dart'; // Not used
// import 'package:shared_preferences/shared_preferences.dart'; // Not used
// import 'package:device_info_plus/device_info_plus.dart'; // Not used
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:chatter/widgets/post/post_card.dart';
import 'package:chatter/widgets/realtime_timeago_text.dart'; // Import the new widget
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatter/pages/profile_page.dart'; // Import ProfilePage
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:chatter/main.dart'; // Import for routeObserver
import 'package:share_handler/share_handler.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with RouteAware {
  final DataController dataController = Get.find<DataController>();
  final MediaVisibilityService mediaVisibilityService = Get.find<MediaVisibilityService>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>(); // Declare the key

  // For managing video queues within posts
  final Map<String, int> _postVideoQueueIndex = {};
  final Map<String, List<String>> _postVideoIds = {}; // Stores video IDs for each post's grid
  final RxString _processingFollowForPostId = ''.obs; // To track loading state for follow/unfollow buttons

  @override
  void initState() {
    super.initState();
    dataController.fetchFeeds(isRefresh: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        dataController.fetchFeeds();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.arguments != null && Get.arguments['sharedMedia'] != null) {
        final sharedMedia = Get.arguments['sharedMedia'] as SharedMedia;
        _handleSharedPost(sharedMedia);
        // Clear arguments after handling
        Get.arguments.remove('sharedMedia');
      }
    });
  }

  Future<void> _handleSharedPost(SharedMedia sharedMedia) async {
    final String content = sharedMedia.content ?? '';
    final List<Map<String, dynamic>> attachments = [];

    if (sharedMedia.attachments != null && sharedMedia.attachments!.isNotEmpty) {
      for (var attachment in sharedMedia.attachments!) {
        if (attachment?.path != null) {
          final file = File(attachment!.path);
          final fileType = dataController.getMediaType(attachment.path.split('.').last);
          attachments.add({
            'file': file,
            'type': fileType,
            'filename': attachment.path.split('/').last,
            'size': await file.length(),
          });
        }
      }
    }

    if (content.isNotEmpty || attachments.isNotEmpty) {
      _addPost(content, attachments);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    // This method is called when a new route is pushed, and the current route is no longer visible.
    dataController.pauseCurrentMedia();
    super.didPushNext();
  }

  void _navigateToPostScreen() async {
    final result = await Get.bottomSheet<Map<String, dynamic>>(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: const NewPostScreen(),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (result != null && result is Map<String, dynamic>) {
      final String content = result['content'] as String? ?? '';
      final List<Map<String, dynamic>> attachments =
          (result['attachments'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? <Map<String, dynamic>>[];

      if (content.isNotEmpty || attachments.isNotEmpty) {
        _addPost(content, attachments);
      }
    }
  }

  Future<void> _addPost(String content, List<Map<String, dynamic>> attachments) async {
    // Reset progress at the very beginning of the process
    dataController.uploadProgress.value = 0.0;

    // Show persistent snackbar for progress and errors only
    Get.showSnackbar(
      GetSnackBar(
        titleText: Obx(() {
          String title = "Creating Post...";
          if (dataController.uploadProgress.value < 0) { // Error state
            title = "Error";
          } else if (dataController.uploadProgress.value >= 1.0) { // Success state
            title = "Success!";
          }
          // For in-progress states, title remains "Creating Post..."
          return Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold));
        }),
        messageText: Obx(() {
          double progress = dataController.uploadProgress.value;
          String message = "";
          if (progress < 0) { // Error state
             message = "Failed to create post. Please try again.";
          } else if (progress == 0) {
            message = "Preparing...";
          } else if (progress < 0.8) { // Upload phase (using literal 0.8)
            double uploadPhaseProgress = progress / 0.8;
            message = "Uploading attachments: ${(uploadPhaseProgress * 100).toStringAsFixed(0)}%";
          } else if (progress < 1.0) { // Save phase (using literal 0.2 for calculation)
            // Calculate progress within the save phase
            double savePhaseProgress = (progress - 0.8) / 0.2; // (currentProgress - uploadPortion) / savePortion
            message = "Saving post: ${(savePhaseProgress * 100).toStringAsFixed(0)}%";
          } else { // Success state (progress >= 1.0)
            message = "Your chatter is live!";
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: GoogleFonts.roboto(color: Colors.white70)),
              if (progress >= 0 && progress < 1.0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              ]
            ],
          );
        }),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black.withOpacity(0.85),
        borderColor: Colors.tealAccent,
        borderWidth: 1,
        borderRadius: 8,
        margin: const EdgeInsets.all(10),
        isDismissible: dataController.uploadProgress.value < 0 || dataController.uploadProgress.value >=1.0, // Dismissible on error or completion
        duration: dataController.uploadProgress.value >= 0 && dataController.uploadProgress.value < 1.0
                  ? null // Indefinite while processing
                  : const Duration(seconds: 3), // Auto-dismiss after 3s for error/completion messages
        showProgressIndicator: false,
      ),
    );

    // Watch for completion or error to dismiss the snackbar programmatically
    // Only auto-dismiss for errors. Success message will persist for the GetSnackBar's duration.
    ever(dataController.uploadProgress, (double progress) {
      if (progress < 0) { // Error
        // Snackbar duration is already set to 3s for error, so it will auto-dismiss.
        // If we wanted immediate dismissal on error:
        // Future.delayed(const Duration(milliseconds: 100), () {
        //   if (Get.isSnackbarOpen) Get.back();
        // });
      } else if (progress >= 1.0) { // Success
        // The snackbar's own duration (3 seconds) will handle dismissal for success.
        // No need to programmatically Get.back() here unless we want to override that.
      }
    });


    List<Map<String, dynamic>> uploadedAttachmentsInfo = [];
    bool anyUploadFailed = false;

    if (attachments.isNotEmpty) {
      List<Map<String, dynamic>> uploadResults = await dataController.uploadFiles(attachments);
      for (var result in uploadResults) {
        if (result['success'] == true) {
          uploadedAttachmentsInfo.add({
            'type': result['type'],
            'filename': result['filename'],
            'size': result['size'],
            'url': result['url'],
            'thumbnailUrl': result['thumbnailUrl'],
            'width': result['width'],
            'height': result['height'],
            'orientation': result['orientation'],
            'duration': result['duration'],
            'aspectRatio': (result['width'] != null && result['height'] != null && result['height'] > 0)
                           ? (result['width'] / result['height']).toStringAsFixed(2)
                           : (16/9).toStringAsFixed(2),
          });
        } else {
          anyUploadFailed = true;
          // Individual file upload failure message (optional, as main snackbar will show general error)
          print('Failed to upload ${result['filename'] ?? 'attachment'}: ${result['message']}');
        }
      }
    }

    if (anyUploadFailed) {
      dataController.uploadProgress.value = -1; // Indicate error
      await Future.delayed(const Duration(seconds: 3)); // Keep error snackbar for a bit
      if (Get.isSnackbarOpen) Get.back(); // Dismiss snackbar
      return;
    }

    // If no content AND no attachments (e.g., user cleared everything after picking)
    // Or if attachments were picked but all failed to upload, and no content.
    if (content.trim().isEmpty && uploadedAttachmentsInfo.isEmpty) {
       dataController.uploadProgress.value = -1; // Indicate error (e.g. "Nothing to post")
       // It's possible Get.back() might be called too soon if createPost is not awaited or if it's very fast.
       // Add a small delay or ensure the snackbar is managed correctly based on final progress.
       await Future.delayed(const Duration(seconds: 3));
       if(Get.isSnackbarOpen) Get.back(); // Dismiss snackbar
       return;
    }


    Map<String, dynamic> postData = {
      'username': dataController.user.value['user']['name'] ?? 'YourName',
      'content': content.trim(),
      'useravatar': dataController.user.value['user']?['avatar'] ?? '', // Ensure correct path to avatar
      'attachments': uploadedAttachmentsInfo.map((att) => { // Use uploadedAttachmentsInfo
            'filename': att['filename'],
            'url': att['url'],
            'size': att['size'],
            'type': att['type'],
            'thumbnailUrl': att['thumbnailUrl'],
            'aspectRatio': att['aspectRatio'],
            'width': att['width'],
            'height': att['height'],
            'orientation': att['orientation'],
            'duration': att['duration'],
          }).toList(),
    };

    final result = await dataController.createPost(postData);

    if (result['success'] == true) {
      if (result['post'] != null) {
        dataController.addNewPost(result['post'] as Map<String, dynamic>);
      } else {
        // If post data isn't returned, refresh feeds as a fallback
        await dataController.fetchFeeds();
      }
      // Progress should be 1.0 from createPost on success. Snackbar will update.
      await Future.delayed(const Duration(seconds: 2)); // Keep success message for a bit
    } else {
      // Create post failed
      dataController.uploadProgress.value = -1; // Indicate error
      await Future.delayed(const Duration(seconds: 3)); // Keep error snackbar for a bit
    }

    if (Get.isSnackbarOpen) {
      Get.back(); // Dismiss snackbar
    }
  }

  void _handleVideoCompletionInGrid(String completedVideoId, String postId, List<Map<String, dynamic>> gridVideos) {
    if (!_postVideoIds.containsKey(postId) || !_postVideoQueueIndex.containsKey(postId)) {
        
        _postVideoIds[postId] = gridVideos.map((v) => v['url'] as String? ?? v['tempId'] as String? ?? v.hashCode.toString()).toList();
        _postVideoQueueIndex[postId] = _postVideoIds[postId]!.indexOf(completedVideoId);
    }

    int currentQueueIndex = _postVideoQueueIndex[postId]!;
    currentQueueIndex++;

    if (currentQueueIndex < _postVideoIds[postId]!.length) {
        _postVideoQueueIndex[postId] = currentQueueIndex;
        String nextVideoIdToPlay = _postVideoIds[postId]![currentQueueIndex];
        print("[HomeFeedScreen] Video $completedVideoId in post $postId completed. Requesting next video in queue: $nextVideoIdToPlay");
        mediaVisibilityService.playItem(nextVideoIdToPlay);
    } else {
        print("[HomeFeedScreen] Video queue for post $postId finished.");
        // Optionally reset queue or mark as finished
        _postVideoQueueIndex.remove(postId);
        _postVideoIds.remove(postId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Image.asset(
          'images/logo.png',
          height: 60,
          width: 60,  
        ),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 255, 255, 255)), // Set AppDrawer icon color to white
      ),
      drawer: const AppDrawer(),
      body: Obx(() {
        if (dataController.posts.isEmpty && dataController.isLoading.value) { // Check isLoading as well
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent), strokeWidth: 1, backgroundColor: Colors.grey,));
        }
        if (dataController.posts.isEmpty && !dataController.isLoading.value) {
             return Center(
                child: Text(
                    "No posts yet. Start chattering!",
                    style: GoogleFonts.roboto(color: Colors.white54, fontSize: 16),
                ),
            );
        }
        return RefreshIndicator(
          onRefresh: () => dataController.fetchFeeds(isRefresh: true),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            controller: _scrollController,
            itemCount: dataController.posts.length + 1,
            separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1),
            itemBuilder: (context, index) {
              if (index < dataController.posts.length) {
                final postMap = dataController.posts[index] as Map<String, dynamic>;
                return PostCard(post: postMap);
              } else {
                return Obx(() => dataController.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : const SizedBox.shrink());
              }
            },
          ),
        );
      }),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        key: _fabKey, // Assign the key here
        distance: 65.0,
        type: ExpandableFabType.up,
        overlayStyle: ExpandableFabOverlayStyle(color: Colors.black.withOpacity(0.5)),
        openButtonBuilder: RotateFloatingActionButtonBuilder(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, child: const Icon(FeatherIcons.menu)),
        closeButtonBuilder: RotateFloatingActionButtonBuilder(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, child: const Icon(Icons.close)),
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_add_post',
            backgroundColor: Colors.black,
            shape: const CircleBorder(side: BorderSide(color: Colors.tealAccent, width: 1)),
            onPressed: () {
              _navigateToPostScreen();
              final fabState = _fabKey.currentState;
              if (fabState != null && fabState.isOpen) {
                fabState.toggle();
              }
            },
            tooltip: 'Add Post',
            child: const Icon(FeatherIcons.plusCircle, color: Colors.tealAccent),
          ),
          // main chats page
          FloatingActionButton.small(
            heroTag: 'fab_chats',
            backgroundColor: Colors.black,
            shape: const CircleBorder(side: BorderSide(color: Colors.tealAccent, width: 1)),
            onPressed: () {
              // Navigate to main chats page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainChatsPage()),
              );
            },
            child: const Icon(FeatherIcons.messageSquare, color: Colors.tealAccent),
          ),
          FloatingActionButton.small(
            heroTag: 'fab_home',
            backgroundColor: Colors.black,
            shape: const CircleBorder(side: BorderSide(color: Colors.tealAccent, width: 1)),
            onPressed: () {
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              dataController.fetchFeeds();
              final fabState = _fabKey.currentState;
              if (fabState != null && fabState.isOpen) {
                fabState.toggle();
              }
            },
            tooltip: 'Home',
            child: const Icon(FeatherIcons.home, color: Colors.tealAccent),
          ),
          FloatingActionButton.small(
            heroTag: 'fab_search',
            backgroundColor: Colors.black,
            shape: const CircleBorder(side: BorderSide(color: Colors.tealAccent, width: 1)),
            onPressed: () {
              Get.to(() => const SearchPage(), transition: Transition.rightToLeft);
              final fabState = _fabKey.currentState;
              if (fabState != null && fabState.isOpen) {
                fabState.toggle();
              }
            },
            tooltip: 'Search',
            child: const Icon(FeatherIcons.search, color: Colors.tealAccent),
          ),
          FloatingActionButton.small(
            heroTag: 'fab_buy_me_a_coffee',
            backgroundColor: Colors.black,
            shape: const CircleBorder(side: BorderSide(color: Colors.tealAccent, width: 1)),
            onPressed: () {
              Get.toNamed('/buy-me-a-coffee');
              final fabState = _fabKey.currentState;
              if (fabState != null && fabState.isOpen) {
                fabState.toggle();
              }
            },
            tooltip: 'Buy Me a Coffee',
            child: const Icon(FeatherIcons.coffee, color: Colors.tealAccent),
          ),
        ],
      ),
    );
  }
}

class PdfThumbnailWidget extends StatefulWidget {
  final String pdfUrl;
  final double aspectRatio;
  final VoidCallback onTap;

  const PdfThumbnailWidget({
    Key? key,
    required this.pdfUrl,
    required this.aspectRatio,
    required this.onTap,
  }) : super(key: key);

  @override
  _PdfThumbnailWidgetState createState() => _PdfThumbnailWidgetState();
}

class _PdfThumbnailWidgetState extends State<PdfThumbnailWidget> {
  Future<Widget>? _pdfViewerFuture;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  void _loadPdf() {
    // We're trying to see if PdfViewer.uri can render.
    // The challenge is that PdfViewer.uri itself doesn't return a future
    // that resolves on successful render or errors out in a way FutureBuilder can easily consume
    // for "thumbnail preview" purposes. It's designed to be a full viewer.
    // For a "thumbnail", we want a quick attempt. If it's slow or errors, we show fallback.

    // Let's try a slightly different approach: build PdfViewer.uri directly.
    // If it throws an exception during its build/layout phase, we want to catch that.
    // However, internal errors within PdfViewer might not be catchable this way easily
    // without modifying PdfViewer or having more complex error listening.

    // A pragmatic approach:
    // Try to load it. If it takes too long (via a timeout outside this widget, if needed, or assume it's quick enough for now)
    // or if an immediate structural error occurs, we'd want the fallback.
    // For now, we'll assume PdfViewer.uri() is relatively well-behaved for valid URLs
    // and the main issue is a timeout or a totally bogus URL.

    // Let's simulate a "load attempt" by creating the widget.
    // The actual rendering and potential errors happen when this widget is put in the tree.
    // We can't easily use FutureBuilder here to "preview" PdfViewer.uri itself
    // unless PdfViewer.uri was async and returned its content or error.

    // Given the constraints, the current structure in _buildAttachmentWidget
    // which directly uses PdfViewer.uri is okay, but it doesn't have timeout/error *for the thumbnail specifically*.
    // The new requirement is to show a *fallback* if the thumbnail fails, not if the main view fails.

    // Simpler approach for this widget: It will *always* try to display PdfViewer.uri.
    // The "error" part will be tricky. Let's assume for now that if the URL is invalid,
    // PdfViewer.uri might show an error state internally or throw an exception during build.
    // We'll wrap it in a try-catch in the build method for robustness.

    // No async operation needed in initState for this simplified model.
    // The build method will construct the PdfViewer.
  }

  Widget _buildFallback() {
    // This is the fallback UI for this specific widget
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FeatherIcons.fileText,
                color: Colors.white.withOpacity(0.7),
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                "Open PDF",
                style: GoogleFonts.roboto(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Attempt to build the PdfViewer widget.
      // Note: PdfViewer.uri might have its own internal error display.
      // This try-catch is for structural errors during widget creation/layout.
      final pdfWidget = PdfViewer.uri(
        Uri.parse(widget.pdfUrl),
        params: PdfViewerParams(
          margin: 0,
          maxScale: 0.8, // Changed: For a thumbnail, allow slight zoom out
          minScale: 0.5, // Changed: Allow more zoom out
          // viewerOverlayBuilder: (context, pageSize, viewRect, document, pageNumber) => [], // Removed due to signature mismatch
          loadingBannerBuilder: (context, bytesLoaded, totalBytes) {
            // Show a simple loading indicator if it takes time
            return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent.withOpacity(0.5)), strokeWidth: 2,));
          },
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            // This is an error *within* PdfViewer. We return our fallback.
            print("PdfViewer errorBannerBuilder: $error");
            return _buildFallback();
          },
          backgroundColor: Colors.grey[800] ?? Colors.grey, // Background for the PDF view area
        ),
      );

      // The PdfViewer itself might not be tappable if it's displaying content.
      // Wrap with GestureDetector to ensure onTap always works.
      return GestureDetector(
        onTap: widget.onTap,
        child: pdfWidget,
      );
    } catch (e, s) {
      // If creating PdfViewer.uri threw an exception (e.g., invalid URI format)
      print("Error creating PdfViewer.uri for thumbnail: $e\n$s");
      return _buildFallback(); // Show fallback on error
    }
  }
}