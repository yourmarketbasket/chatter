import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:chatter/services/media_visibility_service.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

class _UserPostsPageState extends State<UserPostsPage> {
  final DataController _dataController = Get.find<DataController>();
  final MediaVisibilityService mediaVisibilityService = Get.find<MediaVisibilityService>();

  final Map<String, int> _postVideoQueueIndex = {};
  final Map<String, List<String>> _postVideoIds = {};
  final RxString _processingFollowForPostId = ''.obs;

  void _navigateToProfilePage(BuildContext context, String userId, String username, String? userAvatarUrl) {
    Get.to(() => ProfilePage(userId: userId, username: username, userAvatarUrl: userAvatarUrl));
  }

  List<TextSpan> _buildTextSpans(String text, {required bool isReply}) {
    final List<TextSpan> spans = [];
    final RegExp hashtagRegExp = RegExp(r"(#\w+)");
    final TextStyle defaultStyle = GoogleFonts.roboto(
      fontSize: isReply ? 13 : 14,
      color: const Color.fromARGB(255, 255, 255, 255),
      height: 1.5
    );
    final TextStyle hashtagStyle = GoogleFonts.roboto(
      fontSize: isReply ? 13 : 14,
      color: Colors.tealAccent,
      fontWeight: FontWeight.bold,
      height: 1.5
    );

    text.splitMapJoin(
      hashtagRegExp,
      onMatch: (Match match) {
        spans.add(TextSpan(text: match.group(0), style: hashtagStyle));
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: defaultStyle));
        return '';
      },
    );
    return spans;
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

  Future<void> _handleRepostAction(Map<String, dynamic> post) async {
    final String? postId = post['_id'] as String?;
    if (postId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Post ID is missing.', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final result = await _dataController.repostPost(postId);
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to repost.', style: GoogleFonts.roboto(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _toggleLikeStatus(String postId, bool isCurrentlyLiked) async {
    if (isCurrentlyLiked) {
      await _dataController.unlikePost(postId);
    } else {
      await _dataController.likePost(postId);
    }
  }

  void _handleBookmark(String postId, bool isCurrentlyBookmarked) async {
    if (isCurrentlyBookmarked) {
      await _dataController.unbookmarkPost(postId);
    } else {
      await _dataController.bookmarkPost(postId);
    }
  }

  Widget _buildActionButton(IconData icon, String text, VoidCallback onPressed, {bool isLiked = false, bool isReposted = false, bool isBookmarked = false}) {
    Color iconColor = const Color.fromARGB(255, 255, 255, 255);
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
              size: 14,
            ),
            if (text.isNotEmpty)
              Text(
                text,
                style: GoogleFonts.roboto(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  fontSize: 10,
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
        return aspectRatio;
      } else if (aspectRatio is String) {
        if (aspectRatio.contains(':')) {
          final parts = aspectRatio.split(':');
          if (parts.length == 2) {
            final width = double.tryParse(parts[0].trim());
            final height = double.tryParse(parts[1].trim());
            if (width != null && height != null && height != 0) {
              return width / height;
            }
          }
        } else {
          final value = double.tryParse(aspectRatio);
          if (value != null) {
            return value;
          }
        }
      }
    } catch (e) {
      print('Error parsing aspect ratio: $e');
    }
    return null;
  }

  Widget _buildAttachmentGrid(List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post, String postId) {
    double itemSpacing = 4.0;
    List<Map<String, dynamic>> videoAttachmentsInGrid = attachmentsArg.where((att) => att['type'] == 'video').toList();
    bool isVideoGrid = videoAttachmentsInGrid.length > 1;

    if (attachmentsArg.isEmpty) return const SizedBox.shrink();

    if (attachmentsArg.length == 1) {
      final attachment = attachmentsArg[0];
      final String attachmentType = attachment['type'] as String? ?? 'unknown';
      double aspectRatioToUse;

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
          SizedBox(width: itemSpacing),
          Expanded(child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[1]['type'] == 'video')),
        ],
      );
    } else if (attachmentsArg.length == 3) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[0]['type'] == 'video')),
          SizedBox(width: itemSpacing),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[1]['type'] == 'video')),
                SizedBox(height: itemSpacing),
                Expanded(child: _buildAttachmentWidget(attachmentsArg[2], 2, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[2]['type'] == 'video')),
              ],
            ),
          ),
        ],
      );
    } else if (attachmentsArg.length == 4) {
      return GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: itemSpacing, mainAxisSpacing: itemSpacing, childAspectRatio: 1),
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
                SizedBox(height: itemSpacing),
                Expanded(child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[1]['type'] == 'video')),
              ],
            )
          ),
          SizedBox(width: itemSpacing),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildAttachmentWidget(attachmentsArg[2], 2, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[2]['type'] == 'video')),
                SizedBox(height: itemSpacing),
                Expanded(child: _buildAttachmentWidget(attachmentsArg[3], 3, post, BorderRadius.zero, fit: BoxFit.cover, postId: postId, isVideoGrid: isVideoGrid && attachmentsArg[3]['type'] == 'video')),
                SizedBox(height: itemSpacing),
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
    final num? attWidth = attachmentMap['width'] as num?;
    final num? attHeight = attachmentMap['height'] as num?;
    final String? attAspectRatioString = attachmentMap['aspectRatio'] as String?;
    double calculatedAspectRatio = 16/9;
    if (attAspectRatioString != null) {
      calculatedAspectRatio = double.tryParse(attAspectRatioString) ?? calculatedAspectRatio;
    } else if (attWidth != null && attHeight != null && attHeight > 0) {
      calculatedAspectRatio = attWidth / attHeight;
    }

    final String attachmentKeyId;
    if (attachmentMap['_id'] != null && (attachmentMap['_id'] as String).isNotEmpty) {
      attachmentKeyId = attachmentMap['_id'] as String;
    } else if (attachmentMap['url'] != null && (attachmentMap['url'] as String).isNotEmpty) {
      attachmentKeyId = attachmentMap['url'] as String;
    } else {
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
        key: Key('video_$attachmentKeyId'),
        attachment: attachmentMap,
        post: post,
        borderRadius: BorderRadius.zero,
        isFeedContext: true,
        enforceFeedConstraints: true,
        onVideoCompletedInGrid: isVideoGrid
            ? (completedVideoId) => _handleVideoCompletionInGrid(
                completedVideoId,
                postId,
                (_postVideoIds[postId] as List?)?.cast<Map<String, dynamic>>() ?? [])
            : null,
      );
    } else if (attachmentType == "audio") {
      contentWidget = AudioAttachmentWidget(
        key: Key('audio_$attachmentKeyId'),
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
          memCacheWidth: 600,
          placeholder: (context, url) => Container(color: Colors.grey[900]),
          errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
      } else if ((attachmentMap['file'] as File?) != null) {
        imageContent = Image.file(attachmentMap['file'] as File, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
      } else {
        imageContent = Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40));
      }
      contentWidget = AspectRatio(aspectRatio: calculatedAspectRatio > 0 ? calculatedAspectRatio : 4/3, child: imageContent);
    } else if (attachmentType == "pdf" || attachmentType == "application/pdf") {
      final pdfAspectRatio = calculatedAspectRatio > 0 ? calculatedAspectRatio : 3/4;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        contentWidget = AspectRatio(
          aspectRatio: pdfAspectRatio,
          child: PdfThumbnailWidget(
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
        int currentIdxInAllAttachments = correctlyTypedPostAttachments.indexWhere((att) =>
            (att['url'] != null && att['url'] == attachmentMap['url']) ||
            (att['_id'] != null && att['_id'] == attachmentMap['_id']) ||
            (att.hashCode == attachmentMap.hashCode)
        );
        if (currentIdxInAllAttachments == -1) currentIdxInAllAttachments = idx;

        _navigateToMediaViewPage(context, correctlyTypedPostAttachments, attachmentMap, post, idx);
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
  }

  void _navigateToReplyPage(Map<String, dynamic> post) {
    Get.to(() => ReplyPage(post: post, postDepth: 0));
  }

  @override
  void initState() {
    super.initState();
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

  Widget _buildPostContent(Map<String, dynamic> post, {required bool isReply}) {
    final String postId = post['_id'] as String? ?? post.hashCode.toString();
    final String username = post['username'] as String? ?? 'Unknown User';
    final String contentTextData = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    final String avatarInitial = (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = post['createdAt'] is String
        ? DateTime.parse(post['createdAt'] as String).toUtc()
        : DateTime.now().toUtc();

    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';

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
                        Text(
                          '@$username',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isReply ? 10 : 12, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Icon(Icons.verified, color: Colors.amber, size: isReply ? 13 : 15),

                        Text(
                          '· ${DateFormat('h:mm a').format(timestamp.toLocal())} · ${timeago.format(timestamp)} · ${DateFormat('MMM d, yy').format(timestamp.toLocal())}',
                          style: GoogleFonts.poppins(fontSize: isReply ? 10 : 10, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),

                        Obx(() {
                          final loggedInUserId = _dataController.user.value['user']?['_id'];
                          String? extractAuthorId(Map<String, dynamic> postMap) {
                            if (postMap['user'] is Map && (postMap['user'] as Map).containsKey('_id')) { return postMap['user']['_id'] as String?; }
                            if (postMap['userId'] is String) { return postMap['userId'] as String?; }
                            if (postMap['userId'] is Map && (postMap['userId'] as Map).containsKey('_id')) { return postMap['userId']['_id'] as String?; }
                            return null;
                          }
                          final String? postAuthorUserId = extractAuthorId(post);

                          if (loggedInUserId != null && postAuthorUserId != null && loggedInUserId != postAuthorUserId) {
                            final List<dynamic> followingListRaw = _dataController.user.value['user']?['following'] as List<dynamic>? ?? [];
                            final List<String> followingList = followingListRaw.map((e) => e.toString()).toList();
                            final bool isFollowing = followingList.contains(postAuthorUserId);
                            final bool isProcessing = _processingFollowForPostId.value == postId;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: TextButton(
                                onPressed: isProcessing ? null : () async {
                                  _processingFollowForPostId.value = postId;
                                  if (isFollowing) { await _dataController.unfollowUser(postAuthorUserId); } else { await _dataController.followUser(postAuthorUserId); }
                                  _processingFollowForPostId.value = '';
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                      style: GoogleFonts.roboto(color: isFollowing ? Colors.grey[300] : Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w500),
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
                    Row(
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
                        const SizedBox(width: 12),
                        _buildActionButton(Icons.share_outlined, '', () {}),
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
            return _buildPostContent(post, isReply: false);
          },
        );
      }),
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
  }

  Widget _buildFallback() {
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
      final pdfWidget = PdfViewer.uri(
        Uri.parse(widget.pdfUrl),
        params: PdfViewerParams(
          margin: 0,
          maxScale: 0.8,
          minScale: 0.5,
          loadingBannerBuilder: (context, bytesLoaded, totalBytes) {
            return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent.withOpacity(0.5)), strokeWidth: 2,));
          },
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            print("PdfViewer errorBannerBuilder: $error");
            return _buildFallback();
          },
          backgroundColor: Colors.grey[800] ?? Colors.grey,
        ),
      );

      return GestureDetector(
        onTap: widget.onTap,
        child: pdfWidget,
      );
    } catch (e, s) {
      print("Error creating PdfViewer.uri for thumbnail: $e\n$s");
      return _buildFallback();
    }
  }
}
