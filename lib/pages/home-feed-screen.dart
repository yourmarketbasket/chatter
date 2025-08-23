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
import 'package:chatter/widgets/realtime_timeago_text.dart'; // Import the new widget
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatter/pages/profile_page.dart'; // Import ProfilePage
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
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
  }

  void _navigateToProfilePage(BuildContext context, String userId, String username, String? userAvatarUrl) {
    Get.to(() => ProfilePage(userId: userId, username: username, userAvatarUrl: userAvatarUrl));
  }

  List<TextSpan> _buildTextSpans(String text, {required bool isReply}) {
    final List<TextSpan> spans = [];
    final RegExp hashtagRegExp = RegExp(r"(#\w+)");
    // Define default and hashtag-specific styles
    final TextStyle defaultStyle = GoogleFonts.roboto(
      fontSize: isReply ? 13 : 14,
      color: const Color.fromARGB(255, 255, 255, 255),
      height: 1.5
    );
    final TextStyle hashtagStyle = GoogleFonts.roboto(
      fontSize: isReply ? 13 : 14,
      color: Colors.tealAccent, // Teal color for hashtags
      fontWeight: FontWeight.bold,
      height: 1.5
    );

    text.splitMapJoin(
      hashtagRegExp,
      onMatch: (Match match) {
        spans.add(TextSpan(text: match.group(0), style: hashtagStyle));
        return ''; // Return empty string for matched part
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: defaultStyle));
        return ''; // Return empty string for non-matched part
      },
    );
    return spans;
  }

  // Helper method to navigate to MediaViewPage
  void _navigateToMediaViewPage(
      BuildContext context,
      List<Map<String, dynamic>> allAttachments,
      Map<String, dynamic> currentAttachmentMap,
      Map<String, dynamic> post,
      int fallbackIndex) {
    int initialIndex = allAttachments.indexWhere((att) =>
        (att['url'] != null && att['url'] == currentAttachmentMap['url']) ||
        (att['_id'] != null && att['_id'] == currentAttachmentMap['_id']) ||
        (att.hashCode == currentAttachmentMap.hashCode));
    if (initialIndex == -1) initialIndex = fallbackIndex;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewPage(
          attachments: allAttachments,
          initialIndex: initialIndex,
          message: post['content'] as String? ?? '',
          userName: post['username'] as String? ?? 'Unknown User',
          userAvatarUrl: post['useravatar'] as String?,
          timestamp: post['createdAt'] is String
              ? DateTime.parse(post['createdAt'] as String).toUtc()
              : DateTime.now().toUtc(),
          viewsCount: post['viewsCount'] as int? ?? (post['views'] as List?)?.length ?? 0,
          likesCount: post['likesCount'] as int? ?? (post['likes'] as List?)?.length ?? 0,
          repostsCount: post['repostsCount'] as int? ?? (post['reposts'] as List?)?.length ?? 0,
        ),
      ),
    );
  }

  Widget _buildPdfErrorFallback(double aspectRatio, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850], // Similar to other placeholders
          // borderRadius: BorderRadius.circular(12.0), // Handled by ClipRRect in _buildAttachmentWidget
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FeatherIcons.fileText, // Document icon
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

  void _showSnackBar(String title, String message, Color backgroundColor) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
    );
  }

  Future<File?> _downloadFile(String url, String filename, String type) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        String extension;
        switch (type) {
          case 'image': extension = path.extension(url).isNotEmpty ? path.extension(url) : '.jpg'; break;
          case 'video': extension = path.extension(url).isNotEmpty ? path.extension(url) : '.mp4'; break;
          case 'pdf': extension = '.pdf'; break;
          case 'audio': extension = path.extension(url).isNotEmpty ? path.extension(url) : '.mp3'; break;
          default: extension = path.extension(url).isNotEmpty ? path.extension(url) : '.bin';
        }
        final sanitizedFilename = filename.replaceAll(RegExp(r'[^\w\.]'), '_');
        final filePath = '${directory.path}/$sanitizedFilename$extension';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        print('Failed to download file: $url, Status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final String content = post['content'] as String? ?? "";
    final List<String> filePaths = [];
    List<Map<String, dynamic>> attachments = [];

    final dynamic rawAttachments = post['attachments'];
    if (rawAttachments is List && rawAttachments.isNotEmpty) {
      attachments = rawAttachments.whereType<Map>().map((item) => Map<String, dynamic>.from(item.map((key, value) => MapEntry(key.toString(), value)))).toList();
    }

    for (var attachment in attachments) {
      final String? url = attachment['url'] as String?;
      final String? filename = attachment['filename'] as String? ?? 'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final String? type = attachment['type'] as String?;
      File? file;

      if (attachment['file'] is File) {
        file = attachment['file'] as File;
        filePaths.add(file.path);
      } else if ((url ?? '').isNotEmpty && (type ?? '').isNotEmpty) {
        file = await _downloadFile(url!, filename!, type!);
        if (file != null) {
          filePaths.add(file.path);
        } else {
          _showSnackBar('Error', 'Failed to download $type: $filename', Colors.red[700]!);
        }
      }
    }

    if (filePaths.isNotEmpty) {
      final xFiles = filePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(xFiles, text: content.isNotEmpty ? content : null, subject: 'Shared from Chatter');
    } else {
      await Share.share(content.isNotEmpty ? content : 'Check out this post from Chatter!', subject: 'Shared from Chatter');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  // Future<void> _navigateToRepostPage(Map<String, dynamic> post) async {
  //   final String? postId = post['_id'] as String?;
  //   if (postId == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error: Post ID is missing.', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: Colors.redAccent),
  //     );
  //     return;
  //   }

  //   final confirmed = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => RepostPage(post: post), // RepostPage just confirms intent
  //     ),
  //   );

  //   if (confirmed == true) {
  //     final result = await dataController.repostPost(postId); // Actual repost call
  //     if (result['success'] == true) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(result['message'] ?? 'Reposted successfully!', style: GoogleFonts.roboto(color: Colors.white)),
  //           backgroundColor: Colors.teal[700],
  //         ),
  //       );
  //       // Optimistic update is now handled within dataController.repostPost
  //       // The Obx in the build method will react to changes in dataController.posts
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(result['message'] ?? 'Failed to repost.', style: GoogleFonts.roboto(color: Colors.white)),
  //           backgroundColor: Colors.redAccent,
  //         ),
  //       );
  //     }
  //   }
  // }

  Future<void> _handleRepostAction(Map<String, dynamic> post) async {
    final String? postId = post['_id'] as String?;
    if (postId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Post ID is missing.', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Optional: Add a confirmation dialog here if you still want a confirmation step
    // without a full page navigation.
    // For now, proceeding directly with the action as per the updated plan.

    final result = await dataController.repostPost(postId);
    if (result['success'] == true) {
      // Success snackbar removed
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(result['message'] ?? 'Reposted successfully!', style: GoogleFonts.roboto(color: Colors.white)),
      //     backgroundColor: Colors.teal[700],
      //   ),
      // );
      print("Post reposted successfully (no snackbar). Message: ${result['message']}");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to repost.', style: GoogleFonts.roboto(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
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

  Future<void> _navigateToReplyPage(Map<String, dynamic> post) async {
    // print(post);
    final newReply = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyPage(post: post, postDepth: 0), // Original posts are at depth 0
      ),
    );

    // ReplyPage now returns `true` if a reply was successfully posted.
    if (newReply == true) {
      final postId = post['_id'] as String?;
      if (postId != null) {
        final postIndex = dataController.posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          // Create a new map to ensure reactivity if postMap is not directly modifiable
          // or if modification doesn't trigger Obx update.
          Map<String, dynamic> updatedPost = Map<String, dynamic>.from(dataController.posts[postIndex]);

          // Increment reply count. Ensure 'replyCount' exists or initialize.
          // The field name in the post object from the backend might be 'replies' (a list) or 'replyCount'.
          // _buildPostContent uses `(post['replies'] as List<dynamic>?)?.length ?? post['replyCount'] as int? ?? 0;`
          // So, we should ideally update whatever field is authoritative or both if necessary.
          // For simplicity, let's assume 'replyCount' is a field we can directly increment.
          // If not, this logic might need to be more robust based on actual post object structure.
          int currentReplyCount = updatedPost['replyCount'] as int? ??
                                  (updatedPost['replies'] as List<dynamic>?)?.length ??
                                  0;
          updatedPost['replyCount'] = currentReplyCount + 1;

          dataController.posts[postIndex] = updatedPost;
          dataController.posts.refresh(); // Force refresh Obx

          // Optional: Show a generic success message or rely on ReplyPage's snackbar
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Reply count updated.', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: Colors.blue[700]),
          // );
        }
      }
    }
    // No need to call dataController.replyToPost() here anymore,
    // as ReplyPage is responsible for its own submission.
  }

  void _handleVideoCompletionInGrid(String completedVideoId, String postId, List<Map<String, dynamic>> gridVideos) {
    if (!_postVideoIds.containsKey(postId) || !_postVideoQueueIndex.containsKey(postId)) {
        // Initialize if not already (e.g. if first video completion triggers this)
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


  Widget _buildPostContent(Map<String, dynamic> post, {required bool isReply}) {
    final String postId = post['_id'] as String? ?? post.hashCode.toString();
    final String username = post['username'] as String? ?? 'Unknown User';
    final String contentTextData = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    final String avatarInitial = (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = post['createdAt'] is String
        ? DateTime.parse(post['createdAt'] as String).toUtc()
        : DateTime.now().toUtc();

    final String currentUserId = dataController.user.value['user']?['_id'] ?? '';

    final List<dynamic> likesList = post['likes'] as List<dynamic>? ?? [];
    final int likesCount = likesList.length;
    final bool isLikedByCurrentUser = likesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId));

    final List<dynamic> repostsDynamicList = post['reposts'] as List<dynamic>? ?? [];
    final List<String> repostsList = repostsDynamicList.map((e) => e.toString()).toList();
    final int repostsCount = repostsList.length;
    final bool isRepostedByCurrentUser = repostsList.contains(currentUserId);

    final List<dynamic> bookmarksList = post['bookmarks'] as List<dynamic>? ?? [];
    final bool isBookmarkedByCurrentUser = bookmarksList.any((bookmark) => (bookmark is Map ? bookmark['_id'] == currentUserId : bookmark.toString() == currentUserId));
    final int bookmarksCount = post['bookmarksCount'] as int? ?? bookmarksList.length;

    int views;
    if (post.containsKey('viewsCount') && post['viewsCount'] is int) {
      views = post['viewsCount'] as int;
    } else if (post.containsKey('views') && post['views'] is List) {
      views = (post['views'] as List<dynamic>).length;
    } else {
      views = 0;
    }

    List<Map<String, dynamic>> attachments = (post['attachments'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    int replyCount = (post['replies'] as List<dynamic>?)?.length ?? post['replyCount'] as int? ?? 0;

    List<Map<String, dynamic>> videoAttachmentsInGrid = attachments.where((att) => att['type'] == 'video').toList();
    if (videoAttachmentsInGrid.length > 1 && !_postVideoIds.containsKey(postId)) {
        _postVideoIds[postId] = videoAttachmentsInGrid.map((v) => v['url'] as String? ?? v.hashCode.toString()).toList();
        _postVideoQueueIndex[postId] = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // top spacing
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _navigateToReplyPage(post),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  String? authorUserId;
                  if (post['user'] is Map && (post['user'] as Map).containsKey('_id')) { authorUserId = post['user']['_id'] as String?; }
                  else if (post['userId'] is String) { authorUserId = post['userId'] as String?; }
                  else if (post['userId'] is Map && (post['userId'] as Map).containsKey('_id')) { authorUserId = post['userId']['_id'] as String?; }
                  authorUserId ??= postId;
                  _navigateToProfilePage(context, authorUserId, username, userAvatar);
                },
                child: CircleAvatar(
                  radius: isReply ? 16 : 20, backgroundColor: Colors.tealAccent.withOpacity(0.2),
                  backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                  child: userAvatar == null || userAvatar.isEmpty ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: isReply ? 14 : 16)) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Part 1: Display Name, Yellow Checkmark //
                        Text(
                          '$username', // This is the display name
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isReply ? 11 : 13, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.verified,
                              color: getVerificationBadgeColor(
                                  post['user']?['verification']?['entityType'],
                                  post['user']?['verification']?['level']),
                              size: isReply ? 13 : 15),
                        ),
                        Text(
                          ' @$username ', // This is the display name
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isReply ? 10 : 10, color: const Color.fromARGB(255, 143, 143, 143)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        

                        // Part 2: @username · Time · Time Ago · Date (dot separated)
                        // This part will no longer be Expanded.
                        Text(
                          '· ${timeago.format(timestamp)} · ${DateFormat('MMM d, yy').format(timestamp.toLocal())}',
                          style: GoogleFonts.poppins(fontSize: isReply ? 10 : 10, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false, // Try to keep it on one line
                        ),
                        // const Spacer(), // REMOVED: Spacer should not be here if follow button is not at far right

                        // Part 3: Follow/Unfollow Button
                        Obx(() {
                          final loggedInUserId = dataController.user.value['user']?['_id'];
                          String? extractAuthorId(Map<String, dynamic> postMap) {
                            if (postMap['user'] is Map && (postMap['user'] as Map).containsKey('_id')) { return postMap['user']['_id'] as String?; }
                            if (postMap['userId'] is String) { return postMap['userId'] as String?; }
                            if (postMap['userId'] is Map && (postMap['userId'] as Map).containsKey('_id')) { return postMap['userId']['_id'] as String?; }
                            return null;
                          }
                          final String? postAuthorUserId = extractAuthorId(post);

                          if (loggedInUserId != null && postAuthorUserId != null && loggedInUserId != postAuthorUserId) {
                            final List<dynamic> followingListRaw = dataController.user.value['user']?['following'] as List<dynamic>? ?? [];
                            final List<String> followingList = followingListRaw.map((e) => e.toString()).toList();
                            final bool isFollowing = followingList.contains(postAuthorUserId);
                            final bool isProcessing = _processingFollowForPostId.value == postId;
                            return Padding( // Changed Container to Padding for consistency
                              padding: const EdgeInsets.only(left: 8.0), // Keep some space from the timestamp block
                              child: TextButton(
                                onPressed: isProcessing ? null : () async {
                                  _processingFollowForPostId.value = postId;
                                  if (isFollowing) { await dataController.unfollowUser(postAuthorUserId); } else { await dataController.followUser(postAuthorUserId); }
                                  _processingFollowForPostId.value = '';
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10), // Increased padding
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(color: isFollowing ? Colors.grey[600]! : Colors.tealAccent, width: 1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  backgroundColor: isProcessing ? Colors.grey[700] : (isFollowing ? Colors.transparent : Colors.tealAccent.withOpacity(0.1)),
                                ),
                                child: isProcessing
                                  ? SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent)))
                                  : Text(
                                      isFollowing ? 'Unfollow' : 'Follow',
                                      style: GoogleFonts.roboto(color: isFollowing ? Colors.grey[300] : Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.w500),
                                    ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (contentTextData.isNotEmpty)
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.roboto(fontSize: isReply ? 13 : 14, color: const Color.fromARGB(255, 255, 255, 255), height: 1.5),
                          children: _buildTextSpans(contentTextData, isReply: isReply),
                        ),
                      ),
                    if (contentTextData.isEmpty && attachments.isNotEmpty) const SizedBox(height: 6),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildAttachmentGrid(attachments, post, postId),
                    ],
                    Row( // Action Buttons
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildActionButton(FeatherIcons.messageCircle, '$replyCount', () => _navigateToReplyPage(post)),
                        const SizedBox(width: 12),
                        _buildActionButton(FeatherIcons.eye, '$views', () { print("View action triggered for post $postId"); }),
                        const SizedBox(width: 12),
                        _buildActionButton(FeatherIcons.repeat, '$repostsCount', () => _handleRepostAction(post), isReposted: isRepostedByCurrentUser),
                        const SizedBox(width: 12),
                        _buildActionButton(isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart, '$likesCount', () => _toggleLikeStatus(postId, isLikedByCurrentUser), isLiked: isLikedByCurrentUser),
                        const SizedBox(width: 12),
                        _buildActionButton(isBookmarkedByCurrentUser ? Icons.bookmark : FeatherIcons.bookmark, '$bookmarksCount', () => _handleBookmark(postId, isBookmarkedByCurrentUser), isBookmarked: isBookmarkedByCurrentUser),
                        // share
                        const SizedBox(width: 12),
                        _buildActionButton(Icons.share_outlined, '', () => _sharePost(post)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleLikeStatus(String postId, bool isCurrentlyLiked) async {
    if (isCurrentlyLiked) {
      await dataController.unlikePost(postId);
    } else {
      await dataController.likePost(postId);
    }
    // The Obx in the main build method will rebuild the list,
    // and _buildPostContent will be called again with updated post data.
  }

  void _handleBookmark(String postId, bool isCurrentlyBookmarked) async {
    if (isCurrentlyBookmarked) {
      await dataController.unbookmarkPost(postId);
    } else {
      await dataController.bookmarkPost(postId);
    }
    // The Obx will rebuild the list with updated post data.
  }

  Widget _buildActionButton(IconData icon, String text, VoidCallback onPressed, {bool isLiked = false, bool isReposted = false, bool isBookmarked = false}) {
    Color iconColor = const Color.fromARGB(255, 255, 255, 255); // Default color
    if (isLiked) {
      iconColor = Colors.redAccent;
    } else if (isReposted) {
      iconColor = Colors.tealAccent;
    } else if (isBookmarked) {
      iconColor = Colors.amber;
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(

        margin: EdgeInsets.only(right: 15.0, top: 15.0, bottom: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 14, // Reduced icon size
            ),
            if (text.isNotEmpty) // Conditionally display text
              Text(
                text,
                style: GoogleFonts.roboto(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  fontSize: 10, // Reduced text size
                ),
              ),
          ],
        ),
      ),
    );
  }

  double? _parseAspectRatio(dynamic aspectRatio) {
    if (aspectRatio == null) return null;

    try {
      if (aspectRatio is double) {
        return aspectRatio; // If it's already a double, return it
      } else if (aspectRatio is String) {
        // Handle formats like "16:9" or "1.777"
        if (aspectRatio.contains(':')) {
          // Format is "width:height"
          final parts = aspectRatio.split(':');
          if (parts.length == 2) {
            final width = double.tryParse(parts[0].trim());
            final height = double.tryParse(parts[1].trim());
            if (width != null && height != null && height != 0) {
              return width / height;
            }
          }
        } else {
          // Format is a decimal string like "1.777"
          final value = double.tryParse(aspectRatio);
          if (value != null) {
            return value;
          }
        }
      }
    } catch (e) {
      print('Error parsing aspect ratio: $e');
    }
    return null; // Return null if parsing fails
  }


  Widget _buildAttachmentGrid(List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post, String postId) {
    const double itemSpacing = 4.0;
    List<Map<String, dynamic>> videoAttachmentsInGrid = attachmentsArg.where((att) => att['type'] == 'video').toList();
    bool isVideoGrid = videoAttachmentsInGrid.length > 1;

    if (attachmentsArg.isEmpty) return const SizedBox.shrink();

    if (attachmentsArg.length == 1) {
      final attachment = attachmentsArg[0];
      final String attachmentType = attachment['type'] as String? ?? 'unknown';
      double aspectRatioToUse;

      // For single attachments (video, image, pdf, etc.), enforce 4:3 aspect ratio in the feed.
      aspectRatioToUse = 4 / 3;

      return AspectRatio(
        aspectRatio: aspectRatioToUse,
        child: _buildAttachmentWidget(
          attachment,
          0,
          post,
          BorderRadius.circular(12.0),
          fit: BoxFit.fitWidth,
          postId: postId,
          isVideoGrid: false,
        ),
      );
    } else if (attachmentsArg.length == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: AspectRatio(
          aspectRatio: 2 * (4 / 3), // Example, adjust as needed
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[0]['type'] == 'video')),
              const SizedBox(width: itemSpacing),
              Expanded(child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[1]['type'] == 'video')),
            ],
          ),
        ),
      );
    } else if (attachmentsArg.length == 3) {
      return LayoutBuilder(builder: (context, constraints) {
        double width = constraints.maxWidth;
        double leftItemWidth = (width * 0.66) - (itemSpacing / 2);
        double rightColumnWidth = width * 0.33 - (itemSpacing / 2);
        double totalHeight = width * (9 / 16); // Example height
        return ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: SizedBox(
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: leftItemWidth, child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[0]['type'] == 'video')),
                const SizedBox(width: itemSpacing),
                SizedBox(
                  width: rightColumnWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[1]['type'] == 'video')),
                      const SizedBox(height: itemSpacing),
                      Expanded(child: _buildAttachmentWidget(attachmentsArg[2], 2, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[2]['type'] == 'video')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      });
    } else if (attachmentsArg.length == 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: AspectRatio(
          aspectRatio: 1 / 1, // Square grid for 4 items
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: itemSpacing, mainAxisSpacing: itemSpacing, childAspectRatio: 1),
            itemCount: 4,
            itemBuilder: (context, index) => _buildAttachmentWidget(attachmentsArg[index], index, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[index]['type'] == 'video'),
          ),
        ),
      );
    } else if (attachmentsArg.length == 5) {
       return LayoutBuilder(builder: (context, constraints) {
          double containerWidth = constraints.maxWidth;
          double h1 = (containerWidth - itemSpacing) / 2; // Height for top row items
          double h2 = (containerWidth - 2 * itemSpacing) / 3; // Height for bottom row items
          double totalHeight = h1 + itemSpacing + h2;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: SizedBox(
              height: totalHeight,
              child: Column(
                children: [
                  SizedBox(height: h1, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[0]['type'] == 'video')), const SizedBox(width: itemSpacing),
                    Expanded(child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[1]['type'] == 'video')),
                  ])),
                  const SizedBox(height: itemSpacing),
                  SizedBox(height: h2, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: _buildAttachmentWidget(attachmentsArg[2], 2, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[2]['type'] == 'video')), const SizedBox(width: itemSpacing),
                    Expanded(child: _buildAttachmentWidget(attachmentsArg[3], 3, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[3]['type'] == 'video')), const SizedBox(width: itemSpacing),
                    Expanded(child: _buildAttachmentWidget(attachmentsArg[4], 4, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[4]['type'] == 'video')),
                  ])),
                ],
              ),
            ),
          );
       });
    } else { // 6 or more items
      const int crossAxisCount = 3;
      const double childAspectRatio = 1.0;
      return LayoutBuilder(builder: (context, constraints) {
        double itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * itemSpacing) / crossAxisCount;
        double itemHeight = itemWidth / childAspectRatio;
        int numRows = (attachmentsArg.length / crossAxisCount).ceil();
        double totalHeight = numRows * itemHeight + (numRows - 1) * itemSpacing;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: SizedBox(
            height: totalHeight, // Constrain height
            child: GridView.builder(
              shrinkWrap: true, // Important for ListView parent
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: itemSpacing, mainAxisSpacing: itemSpacing, childAspectRatio: childAspectRatio),
              itemCount: attachmentsArg.length,
              itemBuilder: (context, index) => _buildAttachmentWidget(attachmentsArg[index], index, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[index]['type'] == 'video'),
            ),
          ),
        );
      });
    }
  }

  Widget _buildAttachmentWidget(
      Map<String, dynamic> attachmentMap, int idx, Map<String, dynamic> post, BorderRadius borderRadius,
      {BoxFit fit = BoxFit.contain, required String postId, required bool isVideoGrid}) {
    final String attachmentType = attachmentMap['type'] as String? ?? 'unknown';
    final String? displayUrl = attachmentMap['url'] as String?;
    // Aspect ratio calculation from attachmentMap (width, height, aspectRatio string)
    final num? attWidth = attachmentMap['width'] as num?;
    final num? attHeight = attachmentMap['height'] as num?;
    final String? attAspectRatioString = attachmentMap['aspectRatio'] as String?;
    double calculatedAspectRatio = 16/9; // Default
    if (attAspectRatioString != null) {
      calculatedAspectRatio = double.tryParse(attAspectRatioString) ?? calculatedAspectRatio;
    } else if (attWidth != null && attHeight != null && attHeight > 0) {
      calculatedAspectRatio = attWidth / attHeight;
    }

    // Make sure attachmentMap has a unique ID for key, fallback if URL is null
    final String attachmentKeyId;
    if (attachmentMap['_id'] != null && (attachmentMap['_id'] as String).isNotEmpty) {
      attachmentKeyId = attachmentMap['_id'] as String;
    } else if (attachmentMap['url'] != null && (attachmentMap['url'] as String).isNotEmpty) {
      attachmentKeyId = attachmentMap['url'] as String;
    } else {
      // Fallback for items that might not have _id or url (e.g. local files in preview before upload)
      // This is less ideal for feed items which should have stable IDs.
      attachmentKeyId = 'tempKey_${post['_id']}_${idx}';
      print("Warning: Attachment in post ${post['_id']} at index $idx is using a temporary key. Attachment data: $attachmentMap");
    }


    List<Map<String, dynamic>> correctlyTypedPostAttachments = [];
    if (post['attachments'] is List) {
      for (var item in (post['attachments'] as List)) {
        if (item is Map<String, dynamic>) {
          correctlyTypedPostAttachments.add(item);
        } else if (item is Map) {
          try { correctlyTypedPostAttachments.add(Map<String, dynamic>.from(item)); } catch (e) { print('[HomeFeedScreen] Error converting attachment item: $e'); }
        }
      }
    }

    Widget contentWidget;

    if (attachmentType == "video") {
      contentWidget = VideoAttachmentWidget(
        key: Key('video_$attachmentKeyId'), // Use a reliable unique key
        attachment: attachmentMap,
        post: post,
        borderRadius: BorderRadius.zero, // Border radius handled by ClipRRect wrapper usually
        isFeedContext: true, // This is the home feed context
        enforceFeedConstraints: true, // Enforce 4:3 for home feed
        onVideoCompletedInGrid: isVideoGrid
            ? (completedVideoId) => _handleVideoCompletionInGrid(
                completedVideoId,
                postId,
                (_postVideoIds[postId] as List?)?.cast<Map<String, dynamic>>() ?? [])
            : null,
      );
    } else if (attachmentType == "audio") {
      contentWidget = AudioAttachmentWidget(
        key: Key('audio_$attachmentKeyId'), // Use a reliable unique key
        attachment: attachmentMap,
        post: post,
        borderRadius: BorderRadius.zero,
      );
    } else if (attachmentType == "image") {
      Widget imageContent;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        imageContent = CachedNetworkImage(
          imageUrl: displayUrl,
          fit: BoxFit.cover,
          memCacheWidth: 600, // Optimize memory for image attachments
          placeholder: (context, url) => Container(color: Colors.grey[900]),
          errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
      } else if ((attachmentMap['file'] as File?) != null) {
        imageContent = Image.file(attachmentMap['file'] as File, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
      } else {
        imageContent = Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40));
      }
      contentWidget = AspectRatio(aspectRatio: calculatedAspectRatio > 0 ? calculatedAspectRatio : 4/3, child: imageContent);
    } else if (attachmentType == "pdf") {
      // Default aspect ratio for PDFs, often portrait
      final pdfAspectRatio = calculatedAspectRatio > 0 ? calculatedAspectRatio : 3/4;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        contentWidget = AspectRatio(
          aspectRatio: pdfAspectRatio,
          child: PdfThumbnailWidget( // Custom widget to handle PDF thumbnail loading and error
            pdfUrl: displayUrl,
            aspectRatio: pdfAspectRatio,
            onTap: () {
              _navigateToMediaViewPage(context, correctlyTypedPostAttachments, attachmentMap, post, idx);
            },
          ),
        );
      } else {
        contentWidget = AspectRatio(
          aspectRatio: pdfAspectRatio,
          child: _buildPdfErrorFallback(pdfAspectRatio, () {
             _navigateToMediaViewPage(context, correctlyTypedPostAttachments, attachmentMap, post, idx);
          }),
        );
      }
    } else {
      contentWidget = Container(color: Colors.grey[900], child: const Icon(FeatherIcons.fileText, color: Colors.grey, size: 40));
    }

    return GestureDetector(
      onTap: () {
        // Determine initial index for MediaViewPage
        int currentIdxInAllAttachments = correctlyTypedPostAttachments.indexWhere((att) =>
            (att['url'] != null && att['url'] == attachmentMap['url']) ||
            (att['_id'] != null && att['_id'] == attachmentMap['_id']) ||
            (att.hashCode == attachmentMap.hashCode) // Fallback, less reliable
        );
        if (currentIdxInAllAttachments == -1) currentIdxInAllAttachments = idx; // Use provided idx if not found by content

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaViewPage(
              attachments: correctlyTypedPostAttachments, // Pass all attachments of the post
              initialIndex: currentIdxInAllAttachments, // Index within all attachments of the post
              message: post['content'] as String? ?? '',
              userName: post['username'] as String? ?? 'Unknown User',
              userAvatarUrl: post['useravatar'] as String?,
              timestamp: post['createdAt'] is String
                ? DateTime.parse(post['createdAt'] as String).toUtc()
                : DateTime.now().toUtc(),
              viewsCount: post['viewsCount'] as int? ?? (post['views'] as List?)?.length ?? 0,
              likesCount: post['likesCount'] as int? ?? (post['likes'] as List?)?.length ?? 0,
              repostsCount: post['repostsCount'] as int? ?? (post['reposts'] as List?)?.length ?? 0,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
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
                return _buildPostContent(postMap, isReply: false);
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