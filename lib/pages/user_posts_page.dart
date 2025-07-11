import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:chatter/services/media_visibility_service.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:chatter/widgets/realtime_timeago_text.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:timeago/timeago.dart' as timeago;


class UserPostsPage extends StatefulWidget {
  final String userId;
  final String username;

  const UserPostsPage({Key? key, required this.userId, required this.username}) : super(key: key);

  @override
  _UserPostsPageState createState() => _UserPostsPageState();
}

class _UserPostsPageState extends State<UserPostsPage> {
  final DataController _dataController = Get.find<DataController>();
  final MediaVisibilityService _mediaVisibilityService = Get.find<MediaVisibilityService>();
  final ScrollController _scrollController = ScrollController();
   // For managing video queues within posts - similar to home-feed-screen
  final Map<String, int> _postVideoQueueIndex = {};
  final Map<String, List<String>> _postVideoIds = {};
  final RxString _processingFollowForPostId = ''.obs;


  @override
  void initState() {
    super.initState();
    // Clear previous user's posts if any, then fetch new ones.
    _dataController.userProfilePosts.clear();
    _dataController.fetchUserPosts(widget.userId).catchError((error) {
      print("Error fetching user posts for ${widget.userId}: $error");
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to load posts for ${widget.username}.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
    // No success snackbar, UI will update via Obx
  }

  Future<void> _navigateToReplyPage(Map<String, dynamic> post) async {
    final newReply = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyPage(post: post, postDepth: 0),
      ),
    );
    if (newReply == true) {
      final postId = post['_id'] as String?;
      if (postId != null) {
        // Refresh this user's posts to see reply count updates
         _dataController.fetchUserPosts(widget.userId);
      }
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
        _mediaVisibilityService.playItem(nextVideoIdToPlay);
    } else {
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

    final List<dynamic> likesList = post['likes'] as List<dynamic>? ?? [];
    final int likesCount = likesList.length;
    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';
    final bool isLikedByCurrentUser = likesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId));

    final List<dynamic> repostsDynamicList = post['reposts'] as List<dynamic>? ?? [];
    final List<String> repostsList = repostsDynamicList.map((e) => e.toString()).toList();
    final int repostsCount = repostsList.length;
    final bool isRepostedByCurrentUser = repostsList.contains(currentUserId);

    int views = post['viewsCount'] as int? ?? (post['views'] as List<dynamic>?)?.length ?? 0;
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
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _navigateToReplyPage(post),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  String? authorUserId = post['userId'] as String?;
                   if (post['user'] is Map && (post['user'] as Map).containsKey('_id')) { authorUserId = post['user']['_id'] as String?; }
                  else if (post['userId'] is String) { authorUserId = post['userId'] as String?; }
                  else if (post['userId'] is Map && (post['userId'] as Map).containsKey('_id')) { authorUserId = post['userId']['_id'] as String?; }
                  authorUserId ??= postId; // Fallback, though less ideal
                  _navigateToProfilePage(context, authorUserId, username, userAvatar);
                },
                child: CircleAvatar(
                  radius: isReply ? 16 : 20, backgroundColor: Colors.tealAccent.withOpacity(0.2),
                  backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? CachedNetworkImageProvider(userAvatar) : null,
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
                          '@'+username,
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
                          String? postAuthorUserId = post['userId'] as String?;
                           if (post['user'] is Map && (post['user'] as Map).containsKey('_id')) { postAuthorUserId = post['user']['_id'] as String?; }
                            else if (post['userId'] is Map && (post['userId'] as Map).containsKey('_id')) { postAuthorUserId = post['userId']['_id'] as String?; }

                          if (loggedInUserId != null && postAuthorUserId != null && loggedInUserId != postAuthorUserId) {
                            final List<dynamic> followingListRaw = _dataController.user.value['user']?['following'] as List<dynamic>? ?? [];
                            final List<String> followingListIds = followingListRaw.map((e) => e.toString()).toList();
                            final bool isFollowingAuthor = followingListIds.contains(postAuthorUserId);
                            final bool isProcessing = _processingFollowForPostId.value == postId; // Use postId for uniqueness
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: TextButton(
                                onPressed: isProcessing ? null : () async {
                                  _processingFollowForPostId.value = postId;
                                  if (isFollowingAuthor) { await _dataController.unfollowUser(postAuthorUserId!); }
                                  else { await _dataController.followUser(postAuthorUserId!); }
                                  _processingFollowForPostId.value = '';
                                  // Refresh user posts to reflect follow state changes if it affects this page
                                  // _dataController.fetchUserPosts(widget.userId); // Or more targeted update
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(color: isFollowingAuthor ? Colors.grey[600]! : Colors.tealAccent, width: 1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  backgroundColor: isProcessing ? Colors.grey[700] : (isFollowingAuthor ? Colors.transparent : Colors.tealAccent.withOpacity(0.1)),
                                ),
                                child: isProcessing
                                  ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent)))
                                  : Text(
                                      isFollowingAuthor ? 'Unfollow' : 'Follow',
                                      style: GoogleFonts.roboto(color: isFollowingAuthor ? Colors.grey[300] : Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w500),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart, '$likesCount', () => _toggleLikeStatus(postId, isLikedByCurrentUser), isLiked: isLikedByCurrentUser),
                        _buildActionButton(FeatherIcons.messageCircle, '$replyCount', () => _navigateToReplyPage(post)),
                        _buildActionButton(FeatherIcons.repeat, '$repostsCount', () => _handleRepostAction(post), isReposted: isRepostedByCurrentUser),
                        _buildActionButton(FeatherIcons.eye, '$views', () { /* View action might not be relevant here or just display */ }),
                        _buildActionButton(FeatherIcons.bookmark, '', () { /* Bookmark action */ }),
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
      await _dataController.unlikePost(postId);
    } else {
      await _dataController.likePost(postId);
    }
    // After like/unlike, refresh this user's posts to get updated counts
    _dataController.fetchUserPosts(widget.userId);
  }

  Widget _buildActionButton(IconData icon, String text, VoidCallback onPressed, {bool isLiked = false, bool isReposted = false}) {
    Color iconColor = const Color.fromARGB(255, 255, 255, 255);
    if (isLiked) iconColor = Colors.redAccent;
    else if (isReposted) iconColor = Colors.tealAccent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: iconColor, size: 14),
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.only(right: 2.0, left: 5.0),
          onPressed: onPressed,
        ),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: Text(text, style: GoogleFonts.roboto(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildAttachmentGrid(List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post, String postId) {
    // This is a simplified version. For full fidelity, copy from home-feed-screen.dart or create a shared widget.
    // For now, just displaying the first attachment if any.
    if (attachmentsArg.isEmpty) return const SizedBox.shrink();

    // Basic display for one attachment, can be expanded like in home-feed-screen
    final attachment = attachmentsArg[0];
    return _buildAttachmentWidget(attachment, 0, post, BorderRadius.circular(12.0), postId: postId, isVideoGrid: false);
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

    final String attachmentKeyId = attachmentMap['_id'] as String? ?? displayUrl ?? 'tempKey_${postId}_$idx';

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
            ? (completedVideoId) => _handleVideoCompletionInGrid(completedVideoId, postId, (_postVideoIds[postId] as List?)?.cast<Map<String, dynamic>>() ?? [])
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
          fit: BoxFit.cover, // Changed to cover for better grid appearance
          memCacheWidth: 600,
          placeholder: (context, url) => Container(color: Colors.grey[900]),
          errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
      } else {
        imageContent = Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40));
      }
      contentWidget = AspectRatio(aspectRatio: calculatedAspectRatio > 0 ? calculatedAspectRatio : 4/3, child: imageContent);
    } else if (attachmentType == "pdf") {
      final pdfAspectRatio = calculatedAspectRatio > 0 ? calculatedAspectRatio : 3/4;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        // Placeholder for PDF thumbnail for brevity, copy from home-feed if needed
        contentWidget = AspectRatio(
          aspectRatio: pdfAspectRatio,
          child: Container(color: Colors.blueGrey[800], child: Center(child: Icon(FeatherIcons.fileText, color: Colors.white, size: 50))),
        );
      } else {
        contentWidget = AspectRatio(aspectRatio: pdfAspectRatio, child: _buildPdfErrorFallback(pdfAspectRatio, () {
             _navigateToMediaViewPage(context, correctlyTypedPostAttachments, attachmentMap, post, idx);
          }));
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

        _navigateToMediaViewPage(context, correctlyTypedPostAttachments, attachmentMap, post, currentIdxInAllAttachments);
      },
      child: ClipRRect(
        borderRadius: borderRadius, // This should be BorderRadius.zero for items in a grid usually
        child: contentWidget,
      ),
    );
  }

  // A more complete _buildAttachmentGrid from home-feed-screen.dart should be used here for full functionality.
  // For this step, I'm keeping it simpler to focus on the page structure.
  // If full fidelity is needed, copy the _buildAttachmentGrid and its helper _parseAspectRatio
  // from home-feed-screen.dart here.


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          '${widget.username}\'s Posts',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (_dataController.isLoadingUserProfilePosts.value && _dataController.userProfilePosts.isEmpty) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent)));
        }
        if (!_dataController.isLoadingUserProfilePosts.value && _dataController.userProfilePosts.isEmpty) {
          return Center(
            child: Text(
              "${widget.username} hasn't posted anything yet.",
              style: GoogleFonts.roboto(color: Colors.white54, fontSize: 16),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _dataController.fetchUserPosts(widget.userId),
          color: Colors.tealAccent,
          backgroundColor: Colors.black,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            controller: _scrollController,
            itemCount: _dataController.userProfilePosts.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1),
            itemBuilder: (context, index) {
              final postMap = _dataController.userProfilePosts[index];
              return _buildPostContent(postMap, isReply: false); // Assuming these are top-level posts
            },
          ),
        );
      }),
    );
  }
}

// Placeholder for PdfThumbnailWidget if needed, or import from home-feed-screen if made shared.
// For now, UserPostsPage uses a simpler placeholder for PDF in _buildAttachmentWidget.
// class PdfThumbnailWidget extends StatelessWidget { ... }
