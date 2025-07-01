import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/new-posts-page.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/pages/repost_page.dart';
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
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final DataController dataController = Get.find<DataController>();
  final MediaVisibilityService mediaVisibilityService = Get.find<MediaVisibilityService>();
  final ScrollController _scrollController = ScrollController();

  // For managing video queues within posts
  final Map<String, int> _postVideoQueueIndex = {};
  final Map<String, List<String>> _postVideoIds = {}; // Stores video IDs for each post's grid

  @override
  void initState() {
    super.initState();
    // Potentially initialize _postVideoQueueIndex if posts are already loaded
    // and any of them have video grids. Or do it in buildPostContent.
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

  Future<void> _navigateToRepostPage(Map<String, dynamic> post) async {
    final confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepostPage(post: post),
      ),
    );

    if (confirmed == true) {
      setState(() {
        post['reposts'] = (post['reposts'] ?? 0) + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Poa! Reposted!',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.teal[700],
        ),
      );
    }
  }

  Future<void> _addPost(String content, List<Map<String, dynamic>> attachments) async {
    // Reset progress at the very beginning of the process
    dataController.uploadProgress.value = 0.0;

    // Show persistent snackbar
    Get.showSnackbar(
      GetSnackBar(
        titleText: Obx(() {
          String title = "Creating Post...";
          if (dataController.uploadProgress.value >= 1.0) {
            title = "Success!";
          } else if (dataController.uploadProgress.value < 0) { // Using negative to indicate error
            title = "Error";
          }
          return Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold));
        }),
        messageText: Obx(() {
          double progress = dataController.uploadProgress.value;
          String message = "";
          if (progress < 0) { // Error state
             message = "Failed to create post. Please try again.";
          } else if (progress == 0) {
            message = "Preparing...";
          } else if (progress < 0.8) { // Assuming 0.0 to <0.8 is upload phase
            // Calculate percentage of the upload phase itself
            double uploadPhaseProgress = progress / 0.8;
            message = "Uploading attachments: ${(uploadPhaseProgress * 100).toStringAsFixed(0)}%";
          } else if (progress < 1.0) { // Assuming 0.8 to <1.0 is save phase
            message = "Saving post...";
          } else {
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
        isDismissible: false, // User cannot dismiss it manually initially
        duration: null, // Stays indefinitely until programmatically closed or progress completes
        showProgressIndicator: false, // We use our own LinearProgressIndicator
      ),
    );

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
        builder: (context) => ReplyPage(post: post),
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
    final String postId = post['_id'] as String? ?? post.hashCode.toString(); // Ensure postId is unique
    final String username = post['username'] as String? ?? 'Unknown User';
    final String content = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    final String avatarInitial = (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = post['createdAt'] is String ? DateTime.parse(post['createdAt'] as String) : DateTime.now();
    int likes = post['likes'] as int? ?? 0;
    int reposts = post['reposts'] as int? ?? 0;
    int views = post['views'] as int? ?? 0;
    List<Map<String, dynamic>> attachments = (post['attachments'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    int replyCount = (post['replies'] as List<dynamic>?)?.length ?? post['replyCount'] as int? ?? 0;

    // Initialize queue for this post if it's a new grid of videos
    List<Map<String, dynamic>> videoAttachmentsInGrid = attachments.where((att) => att['type'] == 'video').toList();
    if (videoAttachmentsInGrid.length > 1 && !_postVideoIds.containsKey(postId)) {
        _postVideoIds[postId] = videoAttachmentsInGrid.map((v) => v['url'] as String? ?? v.hashCode.toString()).toList();
        _postVideoQueueIndex[postId] = 0; // Start with the first video
        print("[HomeFeedScreen] Initialized video queue for post $postId with ${_postVideoIds[postId]!.length} videos.");
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _navigateToReplyPage(post),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 16 : 20,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                child: userAvatar == null || userAvatar.isEmpty
                    ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: isReply ? 14 : 16))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info Row (username, timestamp)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(username, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isReply ? 14 : 16, color: Colors.white), overflow: TextOverflow.ellipsis),
                              const SizedBox(width: 4.0),
                              Icon(Icons.verified, color: Colors.amber, size: isReply ? 13 : 15),
                              const SizedBox(width: 4.0),
                              Text(' · @$username', style: GoogleFonts.poppins(fontSize: isReply ? 10 : 12, color: Colors.white70), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Text(DateFormat('h:mm a · MMM d').format(timestamp), style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Text for post content
                    if (content.isNotEmpty)
                      Text(content, style: GoogleFonts.roboto(fontSize: isReply ? 13 : 14, color: const Color.fromARGB(255, 255, 255, 255), height: 1.5)),
                    // Spacer if content is empty but attachments exist, to maintain some tappable area
                    if (content.isEmpty && attachments.isNotEmpty)
                       const SizedBox(height: 6),

                    // Attachment Grid - Taps on individual attachments are handled by _buildAttachmentWidget
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      // Need to ensure _buildAttachmentGrid does not absorb taps meant for the parent ReplyPage navigation
                      // if the tap is on grid padding. Individual items *should* capture their own taps.
                      _buildAttachmentGrid(attachments, post, postId),
                    ],
                    const SizedBox(height: 12),
                    // Action buttons - These have their own tap handlers and should take precedence.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(FeatherIcons.heart, '$likes', () => setState(() => post['likes'] = (post['likes'] as int? ?? 0) + 1)),
                        _buildActionButton(FeatherIcons.messageCircle, '$replyCount', () => _navigateToReplyPage(post)), // This is fine, specific button
                        _buildActionButton(FeatherIcons.repeat, '$reposts', () => _navigateToRepostPage(post)),
                        _buildActionButton(FeatherIcons.eye, '$views', () {}),
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

  Widget _buildActionButton(IconData icon, String text, VoidCallback onPressed) {
    return Row(
      children: [
        IconButton(icon: Icon(icon, color: Colors.grey, size: 20), onPressed: onPressed),
        Text(text, style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14)),
      ],
    );
  }


  Widget _buildAttachmentGrid(List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post, String postId) {
    const double itemSpacing = 4.0;
    List<Map<String, dynamic>> videoAttachmentsInGrid = attachmentsArg.where((att) => att['type'] == 'video').toList();
    bool isVideoGrid = videoAttachmentsInGrid.length > 1;

    if (attachmentsArg.isEmpty) return const SizedBox.shrink();

    if (attachmentsArg.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9, // Default for single items, or use attachment's aspect ratio
        child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.circular(12.0), fit: BoxFit.cover, postId: postId, isVideoGrid: false),
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
    final String attachmentKeyId = attachmentMap['url'] as String? ??
                                   attachmentMap['_id'] as String? ??
                                   (attachmentMap.hashCode.toString() + idx.toString());


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
        isFeedContext: true,
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
      contentWidget = AspectRatio(
        aspectRatio: calculatedAspectRatio > 0 ? calculatedAspectRatio : 3/4, // PDFs often portrait
        child: (displayUrl != null && displayUrl.isNotEmpty)
          ? PdfViewer.uri(Uri.parse(displayUrl), params: const PdfViewerParams(margin: 0, maxScale: 1.0, backgroundColor: Colors.grey))
          : Container(color: Colors.grey[900], child: const Icon(FeatherIcons.fileText, color: Colors.grey, size: 40)),
      );
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
              timestamp: post['createdAt'] is String ? DateTime.parse(post['createdAt'] as String) : DateTime.now(),
              viewsCount: post['views'] as int? ?? 0,
              likesCount: post['likes'] as int? ?? 0,
              repostsCount: post['reposts'] as int? ?? 0,
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
        title: Text('Chatter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 24, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Obx(() {
        if (dataController.posts.isEmpty && dataController.isLoading.value) { // Check isLoading as well
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent)));
        }
        if (dataController.posts.isEmpty && !dataController.isLoading.value) {
             return Center(
                child: Text(
                    "No posts yet. Start chattering!",
                    style: GoogleFonts.roboto(color: Colors.white54, fontSize: 16),
                ),
            );
        }
        return ListView.separated(
          controller: _scrollController,
          itemCount: dataController.posts.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1),
          itemBuilder: (context, index) {
            final postMap = dataController.posts[index] as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
              child: _buildPostContent(postMap, isReply: false),
            );
          },
        );
      }),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        key: GlobalKey<ExpandableFabState>(), // Consider making this a member of _HomeFeedScreenState if needed elsewhere
        distance: 65.0,
        type: ExpandableFabType.up,
        overlayStyle: ExpandableFabOverlayStyle(color: Colors.black.withOpacity(0.5)),
        openButtonBuilder: RotateFloatingActionButtonBuilder(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, child: const Icon(FeatherIcons.menu)),
        closeButtonBuilder: RotateFloatingActionButtonBuilder(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, child: const Icon(Icons.close)),
        children: [
          FloatingActionButton.small(heroTag: 'fab_add_post', backgroundColor: Colors.black, shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.tealAccent, width: 1), borderRadius: BorderRadius.circular(10)), onPressed: _navigateToPostScreen, tooltip: 'Add Post', child: const Icon(FeatherIcons.plusCircle, color: Colors.tealAccent)),
          FloatingActionButton.small(heroTag: 'fab_home', backgroundColor: Colors.black, shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.tealAccent, width: 1), borderRadius: BorderRadius.circular(10)), onPressed: () { _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); dataController.fetchFeeds(); }, tooltip: 'Home', child: const Icon(FeatherIcons.home, color: Colors.tealAccent)),
          FloatingActionButton.small(heroTag: 'fab_search', backgroundColor: Colors.black, shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.tealAccent, width: 1), borderRadius: BorderRadius.circular(10)), onPressed: () { Get.to(() => const SearchPage(), transition: Transition.rightToLeft); }, tooltip: 'Search', child: const Icon(FeatherIcons.search, color: Colors.tealAccent)),
        ],
      ),
    );
  }
}