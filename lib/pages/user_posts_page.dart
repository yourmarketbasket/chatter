import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:chatter/widgets/reply/post_content.dart'; // Assuming this can be reused/adapted
import 'package:chatter/widgets/reply/reply_attachment_grid.dart'; // For image grids
import 'package:chatter/widgets/reply/stat_button.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/realtime_timeago_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';

class UserPostsPage extends StatefulWidget {
  final String userId;
  final String username; // To display in AppBar

  const UserPostsPage({Key? key, required this.userId, required this.username}) : super(key: key);

  @override
  _UserPostsPageState createState() => _UserPostsPageState();
}

import 'package:chatter/services/media_visibility_service.dart';
import 'package:pdfrx/pdfrx.dart';

class _UserPostsPageState extends State<UserPostsPage> {
  final DataController _dataController = Get.find<DataController>();
  final MediaVisibilityService mediaVisibilityService = Get.find<MediaVisibilityService>();

  final Map<String, int> _postVideoQueueIndex = {};
  final Map<String, List<String>> _postVideoIds = {};

  // Define handlers for PostContent callbacks
  void _handleReplyToItem(String parentItemId) {
    // In UserPostsPage, tapping the post content or reply button navigates to ReplyPage
    // This specific callback might be more for when PostContent itself has a direct reply action.
    // For now, find the post and navigate.
    final postToNavigate = _dataController.userPosts.firstWhereOrNull((p) => p['_id'] == parentItemId);
    if (postToNavigate != null) {
      Get.to(() => ReplyPage(post: postToNavigate, postDepth: 0, originalPostId: postToNavigate['_id']));
    }
    print("UserPostsPage: _handleReplyToItem called for $parentItemId");
  }

  void _handleRefreshReplies() {
    // UserPostsPage doesn't display replies directly in a way that PostContent would refresh.
    // This could trigger a refetch for the specific post if detailed reply counts were critical to update.
    // For now, it's a no-op or could fetch all user posts again if necessary.
    // _dataController.fetchUserPosts(widget.userId); // Example: refetch all
    print("UserPostsPage: _handleRefreshReplies called. Currently a no-op in this context.");
  }

  void _handleReplyDataUpdated(Map<String, dynamic> updatedReplyData) {
    // This is for when a reply *within* PostContent (if it were displaying replies) gets updated.
    // In UserPostsPage, PostContent shows the main post. If the main post data (e.g. its own like count)
    // is updated, DataController's listeners should handle it.
    // This callback might be less relevant here unless PostContent is used for replies on this page.
     int index = _dataController.userPosts.indexWhere((p) => p['_id'] == updatedReplyData['_id']);
    if (index != -1) {
      _dataController.userPosts[index] = updatedReplyData;
      // _dataController.userPosts.refresh(); // If needed for Obx
    }
    print("UserPostsPage: _handleReplyDataUpdated called with data for ${updatedReplyData['_id']}");
  }

  void _showPostContentSnackBar(String title, String message, Color backgroundColor) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(8),
      borderRadius: 8,
    );
  }

  Future<void> _sharePostFromContent(Map<String, dynamic> postData) async {
    // This is a simplified share functionality.
    // For sharing files, you'd need to download them first if they are URLs.
    // Share_plus package can handle text and files.
    // For simplicity, sharing text content here.
    final String content = postData['content'] as String? ?? "Check out this post!";
    // In a real app, you might construct a URL to the post.
    // await Share.share(content, subject: 'Shared from Chatter');
     Get.snackbar("Share", "Share functionality for post ID: ${postData['_id']} (placeholder)", snackPosition: SnackPosition.BOTTOM);
  }

  void _handleVideoCompletionInGrid(String completedVideoId, String postId, List<Map<String, dynamic>> gridVideos) {
    if (!_postVideoIds.containsKey(postId) || !_postVideoQueueIndex.containsKey(postId)) {
        _postVideoIds[postId] = gridVideos.map((v) => v['url'] as String? ?? v.hashCode.toString()).toList();
        _postVideoQueueIndex[postId] = _postVideoIds[postId]!.indexOf(completedVideoId);
    }

    int currentQueueIndex = _postVideoQueueIndex[postId]!;
    currentQueueIndex++;

    if (currentQueueIndex < _postVideoIds[postId]!.length) {
        _postVideoQueueIndex[postId] = currentQueueIndex;
        String nextVideoIdToPlay = _postVideoIds[postId]![currentQueueIndex];
        mediaVisibilityService.playItem(nextVideoIdToPlay);
    } else {
        _postVideoQueueIndex.remove(postId);
        _postVideoIds.remove(postId);
    }
  }

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
  void initState() {
    super.initState();
    // Clear previous user posts if any, and fetch new ones.
    _dataController.clearUserPosts();
    _dataController.fetchUserPosts(widget.userId).catchError((error) {
      if (mounted) {
        Get.snackbar(
          'Error Loading Posts',
          'Failed to load posts for ${widget.username}. Please try again later.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    });
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
          try { correctlyTypedPostAttachments.add(Map<String, dynamic>.from(item)); } catch (e) { print('[UserPostsPage] Error converting attachment item: $e'); }
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
    } else if (attachmentType == "pdf" || attachmentType == "application/pdf") {
      // Default aspect ratio for PDFs, often portrait
      final pdfAspectRatio = calculatedAspectRatio > 0 ? calculatedAspectRatio : 3/4;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        contentWidget = AspectRatio(
          aspectRatio: pdfAspectRatio,
          child: PdfView( // Using PdfView directly as PdfThumbnailWidget is not defined here
            controller: PdfController(
              document: PdfDocument.openUri(Uri.parse(displayUrl)),
            ),
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

        _navigateToMediaViewPage(context, correctlyTypedPostAttachments, attachmentMap, post, idx);
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
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
    }

    // For multiple attachments, wrap the grid in a 4:3 aspect ratio container.
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: _buildAttachmentGridContent(attachmentsArg, post, postId, isVideoGrid, itemSpacing),
      ),
    );
  }

  Widget _buildAttachmentGridContent(List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post, String postId, bool isVideoGrid, double itemSpacing) {
    if (attachmentsArg.length == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[0]['type'] == 'video')),
          const SizedBox(width: itemSpacing),
          Expanded(child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[1]['type'] == 'video')),
        ],
      );
    } else if (attachmentsArg.length == 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[0]['type'] == 'video')),
          const SizedBox(width: itemSpacing),
          Expanded(
            flex: 1,
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
      );
    } else if (attachmentsArg.length == 4) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: itemSpacing, mainAxisSpacing: itemSpacing, childAspectRatio: 1),
        itemCount: 4,
        itemBuilder: (context, index) => _buildAttachmentWidget(attachmentsArg[index], index, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[index]['type'] == 'video'),
      );
    } else { // 5 or more
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[0]['type'] == 'video')),
                const SizedBox(height: itemSpacing),
                Expanded(child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[1]['type'] == 'video')),
              ],
            )
          ),
          const SizedBox(width: itemSpacing),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildAttachmentWidget(attachmentsArg[2], 2, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[2]['type'] == 'video')),
                const SizedBox(height: itemSpacing),
                Expanded(child: _buildAttachmentWidget(attachmentsArg[3], 3, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[3]['type'] == 'video')),
                const SizedBox(height: itemSpacing),
                Expanded(child: _buildAttachmentWidget(attachmentsArg[4], 4, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[4]['type'] == 'video')),
              ],
            )
          ),
        ],
      );
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
          try { correctlyTypedPostAttachments.add(Map<String, dynamic>.from(item)); } catch (e) { print('[UserPostsPage] Error converting attachment item: $e'); }
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
    } else if (attachmentType == "pdf" || attachmentType == "application/pdf") {
      // Default aspect ratio for PDFs, often portrait
      final pdfAspectRatio = calculatedAspectRatio > 0 ? calculatedAspectRatio : 3/4;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        contentWidget = AspectRatio(
          aspectRatio: pdfAspectRatio,
          child: PdfView( // Using PdfView directly as PdfThumbnailWidget is not defined here
            controller: PdfController(
              document: PdfDocument.openUri(Uri.parse(displayUrl)),
            ),
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

        _navigateToMediaViewPage(context, correctlyTypedPostAttachments, attachmentMap, post, idx);
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    final String postContentText = post['content'] ?? '';
    final List<dynamic> attachments = post['attachments'] as List<dynamic>? ?? [];
    final String postId = post['_id'] ?? '';

    final int likesCount = post['likesCount'] ?? 0;
    final int repliesCount = post['replyCount'] ?? 0;
    final int repostsCount = post['repostsCount'] ?? 0;
    final int viewsCount = post['viewsCount'] ?? 0;
    final List<dynamic> likes = post['likes'] as List<dynamic>? ?? [];
    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';
    final bool isLikedByCurrentUser = likes.any((like) => (like is String ? like : like?['_id']) == currentUserId);

    return InkWell(
      onTap: () {
        Get.to(() => ReplyPage(
          post: post,
          postDepth: 0,
          originalPostId: postId,
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[850]!, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[ // Explicitly typed for clarity
            // Main post content using PostContent widget  more changes
            if (postContentText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: PostContent(
                  postData: post,
                  isReply: false,
                  postDepth: 0,
                  showSnackBar: _showPostContentSnackBar,
                  onSharePost: _sharePostFromContent,
                  onReplyToItem: _handleReplyToItem,
                  refreshReplies: _handleRefreshReplies,
                  onReplyDataUpdated: _handleReplyDataUpdated,
                ),
              ),

            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: _buildAttachmentGrid(attachments.cast<Map<String, dynamic>>(), post, postId),
              ),

            // Action buttons (StatButtons)
            
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          "${widget.username}'s Posts",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // drawer: const AppDrawer(), // Drawer might not be relevant here or could be conditional
      body: Obx(() {
        if (_dataController.isLoadingUserPosts.value && _dataController.userPosts.isEmpty) {
          return Center(child: CircularProgressIndicator(color: Colors.tealAccent[400]));
        }
        if (!_dataController.isLoadingUserPosts.value && _dataController.userPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FeatherIcons.fileText, size: 48, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text(
                  '${widget.username} hasn\'t posted anything yet or posts failed to load.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
                ),
                const SizedBox(height: 10),
                 ElevatedButton.icon(
                  icon: const Icon(FeatherIcons.refreshCw, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent[700], foregroundColor: Colors.black),
                  onPressed: () => _dataController.fetchUserPosts(widget.userId),
                )
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: _dataController.userPosts.length,
          itemBuilder: (context, index) {
            final post = _dataController.userPosts[index];
            return _buildPostItem(post);
          },
        );
      }),
    );
  }
}
