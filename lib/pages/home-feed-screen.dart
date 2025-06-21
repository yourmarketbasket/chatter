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
    List<Map<String, dynamic>> uploadedAttachments = [];
    if (attachments.isNotEmpty) {
      List<Map<String, dynamic>> uploadResults = await dataController.uploadFiles(attachments);
      for (var result in uploadResults) {
        if (result['success'] == true) {
          uploadedAttachments.add({
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload ${result['filename'] ?? 'attachment'}: ${result['message']}',
                style: GoogleFonts.roboto(color: Colors.white),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }

    if (content.trim().isEmpty && uploadedAttachments.isEmpty) {
      return;
    }

    Map<String, dynamic> postData = {
      'username': dataController.user.value['user']['name'] ?? 'YourName',
      'content': content.trim(),
      'useravatar': dataController.user.value['avatar'] ?? '',
      'attachments': uploadedAttachments.map((att) => {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fantastic! Your chatter is live!', style: GoogleFonts.roboto(color: Colors.white)),
            backgroundColor: Colors.teal[700],
          ),
        );
      } else {
        dataController.fetchFeeds(); // Fallback if post object isn't returned
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chatter posted! Refreshing feed.', style: GoogleFonts.roboto(color: Colors.white)),
            backgroundColor: Colors.orange[700],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Could not create post.', style: GoogleFonts.roboto(color: Colors.white)),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<void> _navigateToReplyPage(Map<String, dynamic> post) async {
    final newReply = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyPage(post: post),
      ),
    );

    if (newReply != null && newReply is Map<String, dynamic>) {
      Map<String, dynamic> replyData = {
        'username': newReply['username'] ?? 'YourName',
        'content': newReply['content']?.trim() ?? '',
        'useravatar': newReply['useravatar'] ?? '',
        'attachments': (newReply['attachments'] as List<Map<String, dynamic>>?)?.map((att) {
              return {
                'filename': att['filename'] ?? (att['file'] as File?)?.path.split('/').last ?? 'unknown',
                'url': att['url'],
                'size': att['size'] ?? ((att['file'] as File?)?.lengthSync() ?? 0),
                'type': att['type'],
                'thumbnailUrl': att['thumbnailUrl'],
                'aspectRatio': att['aspectRatio'],
                'width': att['width'],
                'height': att['height'],
                'orientation': att['orientation'],
                'duration': att['duration'],
              };
            }).toList() ?? [],
      };

      final postId = post['_id'] as String?;
      if (postId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Original post ID is missing.', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: Colors.red[700]),
        );
        return;
      }

      final result = await dataController.replyToPost(
        postId: postId,
        content: replyData['content'] as String,
        attachments: replyData['attachments'] as List<Map<String, dynamic>>,
      );

      if (result['success'] == true) {
        final postIndex = dataController.posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          final postMap = dataController.posts[postIndex];
          postMap['replyCount'] = (postMap['replyCount'] ?? 0) + 1;
          dataController.posts[postIndex] = postMap; // This might not trigger Obx update if not careful
          dataController.posts.refresh(); // Force refresh Obx
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reply added!', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: Colors.teal[700]),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add reply: ${result['message'] ?? 'Unknown error'}', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: Colors.red[700]),
        );
      }
    }
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
        Row(
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
                  Text(content, style: GoogleFonts.roboto(fontSize: isReply ? 13 : 14, color: const Color.fromARGB(255, 255, 255, 255), height: 1.5)),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildAttachmentGrid(attachments, post, postId), // Pass postId
                  ],
                  const SizedBox(height: 12),
                  // Action buttons (Likes, Replies, Reposts, Views)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionButton(FeatherIcons.heart, '$likes', () => setState(() => post['likes'] = (post['likes'] as int? ?? 0) + 1)),
                      _buildActionButton(FeatherIcons.messageCircle, '$replyCount', () => _navigateToReplyPage(post)),
                      _buildActionButton(FeatherIcons.repeat, '$reposts', () => _navigateToRepostPage(post)),
                      _buildActionButton(FeatherIcons.eye, '$views', () {}),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
        imageContent = CachedNetworkImage(imageUrl: displayUrl, fit: BoxFit.cover, placeholder: (context, url) => Container(color: Colors.grey[900]), errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
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
              transitionVideoId: (attachmentType == "video" && dataController.isTransitioningVideo.value && dataController.activeFeedPlayerVideoId.value == attachmentMap['url'])
                  ? dataController.activeFeedPlayerVideoId.value
                  : null,
              transitionControllerType: (attachmentType == "video" && dataController.isTransitioningVideo.value && dataController.activeFeedPlayerVideoId.value == attachmentMap['url'])
                  ? (dataController.activeFeedPlayerController.value is BetterPlayerController ? 'better_player' : 'video_player')
                  : null,
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