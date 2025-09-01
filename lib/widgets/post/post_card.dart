import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/helpers/verification_helper.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/services/media_visibility_service.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:chatter/widgets/realtime_timeago_text.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;


class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isReply;
  final bool showAdminActions;

  const PostCard({
    Key? key,
    required this.post,
    this.isReply = false,
    this.showAdminActions = false,
  }) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final DataController dataController = Get.find<DataController>();
  final MediaVisibilityService mediaVisibilityService = Get.find<MediaVisibilityService>();

  @override
  Widget build(BuildContext context) {
    return _buildPostContent(context, widget.post, isReply: widget.isReply);
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
    void _navigateToProfilePage(BuildContext context, String userId, String username, String? userAvatarUrl) {
    Get.to(() => ProfilePage(userId: userId, username: username, userAvatarUrl: userAvatarUrl));
  }


  Widget _buildPostContent(BuildContext context, Map<String, dynamic> post, {required bool isReply}) {
    final String postId = widget.post['_id'] as String? ?? widget.post.hashCode.toString();
    final String username = widget.post['user']?['name'] as String? ?? 'Unknown User';
    final String contentTextData = widget.post['content'] as String? ?? '';
    final String? userAvatar = widget.post['user']?['avatar'] as String?;
    final String avatarInitial = (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = widget.post['createdAt'] is String
        ? DateTime.parse(widget.post['createdAt'] as String).toUtc()
        : DateTime.now().toUtc();

    final String currentUserId = dataController.user.value['user']?['_id'] ?? '';

    final List<dynamic> likesList = widget.post['likes'] as List<dynamic>? ?? [];
    final int likesCount = likesList.length;
    final bool isLikedByCurrentUser = likesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId));

    final List<dynamic> repostsDynamicList = widget.post['reposts'] as List<dynamic>? ?? [];
    final List<String> repostsList = repostsDynamicList.map((e) => e.toString()).toList();
    final int repostsCount = repostsList.length;
    final bool isRepostedByCurrentUser = repostsList.contains(currentUserId);

    final List<dynamic> bookmarksList = widget.post['bookmarks'] as List<dynamic>? ?? [];
    final bool isBookmarkedByCurrentUser = bookmarksList.any((bookmark) => (bookmark is Map ? bookmark['_id'] == currentUserId : bookmark.toString() == currentUserId));
    final int bookmarksCount = widget.post['bookmarksCount'] as int? ?? bookmarksList.length;

    int views;
    if (widget.post.containsKey('viewsCount') && widget.post['viewsCount'] is int) {
      views = widget.post['viewsCount'] as int;
    } else if (widget.post.containsKey('views') && widget.post['views'] is List) {
      views = (widget.post['views'] as List<dynamic>).length;
    } else {
      views = 0;
    }

    List<Map<String, dynamic>> attachments = (widget.post['attachments'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    int replyCount = (widget.post['replies'] as List<dynamic>?)?.length ?? widget.post['replyCount'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _navigateToReplyPage(context, widget.post),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  String? authorUserId = widget.post['user']?['_id'];
                  _navigateToProfilePage(context, authorUserId ?? postId, username, userAvatar);
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
                          '$username',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isReply ? 11 : 13, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Icon(Icons.verified,
                            color: getVerificationBadgeColor(
                                widget.post['user']?['verification']?['entityType'],
                                widget.post['user']?['verification']?['level']),
                            size: isReply ? 13 : 15),
                        Text(
                          ' @$username ',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isReply ? 10 : 10, color: const Color.fromARGB(255, 143, 143, 143)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '· ${timeago.format(timestamp)} · ${DateFormat('MMM d, yy').format(timestamp.toLocal())}',
                          style: GoogleFonts.poppins(fontSize: isReply ? 10 : 10, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
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
                      _buildAttachmentGrid(context, attachments, widget.post, postId),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildActionButton(context, FeatherIcons.messageCircle, '$replyCount', () => _navigateToReplyPage(context, widget.post)),
                        const SizedBox(width: 12),
                        _buildActionButton(context, FeatherIcons.eye, '$views', () { print("View action triggered for post $postId"); }),
                        const SizedBox(width: 12),
                        _buildActionButton(context, FeatherIcons.repeat, '$repostsCount', () => _handleRepostAction(widget.post), isReposted: isRepostedByCurrentUser),
                        const SizedBox(width: 12),
                        _buildActionButton(context, isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart, '$likesCount', () => _toggleLikeStatus(postId, isLikedByCurrentUser), isLiked: isLikedByCurrentUser),
                        const SizedBox(width: 12),
                        _buildActionButton(context, isBookmarkedByCurrentUser ? Icons.bookmark : FeatherIcons.bookmark, '$bookmarksCount', () => _handleBookmark(postId, isBookmarkedByCurrentUser), isBookmarked: isBookmarkedByCurrentUser),
                        const SizedBox(width: 12),
                        _buildActionButton(context, Icons.share_outlined, '', () => _sharePost(context, widget.post)),
                      ],
                    ),
                     if (widget.showAdminActions)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.post['isFlagged'] ?? false ? 'Flagged' : 'Not Flagged',
                                style: GoogleFonts.roboto(
                                  color: widget.post['isFlagged'] ?? false ? Colors.orange : Colors.grey,
                                ),
                              ),
                              Switch(
                                value: widget.post['isFlagged'] ?? false,
                                onChanged: (value) async {
                                  final result = value
                                      ? await dataController.flagPostForReview(widget.post['_id'])
                                      : await dataController.unflagPost(widget.post['_id']);
                                  if (result['success']) {
                                    setState(() {
                                      widget.post['isFlagged'] = value;
                                    });
                                  }
                                  Get.snackbar(
                                    result['success'] ? 'Success' : 'Error',
                                    result['message'],
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                },
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Get.dialog(
                                AlertDialog(
                                  title: const Text('Delete Post'),
                                  content: const Text('Are you sure you want to delete this post?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Get.back(),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Get.back();
                                        final result = await dataController.deletePostByAdmin(widget.post['_id']);
                                        Get.snackbar(
                                          result['success'] ? 'Success' : 'Error',
                                          result['message'],
                                          snackPosition: SnackPosition.BOTTOM,
                                        );
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      )
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToReplyPage(BuildContext context, Map<String, dynamic> post) async {
    final newReply = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyPage(post: post, postDepth: 0),
      ),
    );

    if (newReply == true) {
      final postId = post['_id'] as String?;
      if (postId != null) {
        dataController.fetchSinglePost(postId);
      }
    }
  }

  Future<void> _handleRepostAction(Map<String, dynamic> post) async {
    final String? postId = post['_id'];
    if (postId == null) return;
    await dataController.repostPost(postId);
  }

  void _toggleLikeStatus(String postId, bool isCurrentlyLiked) async {
    if (isCurrentlyLiked) {
      await dataController.unlikePost(postId);
    } else {
      await dataController.likePost(postId);
    }
  }

  void _handleBookmark(String postId, bool isCurrentlyBookmarked) async {
    if (isCurrentlyBookmarked) {
      await dataController.unbookmarkPost(postId);
    } else {
      await dataController.bookmarkPost(postId);
    }
  }

  Future<void> _sharePost(BuildContext context, Map<String, dynamic> post) async {
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

  Widget _buildActionButton(BuildContext context, IconData icon, String text, VoidCallback onPressed, {bool isLiked = false, bool isReposted = false, bool isBookmarked = false}) {
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
        margin: const EdgeInsets.only(right: 15.0, top: 15.0, bottom: 12.0),
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

  Widget _buildAttachmentGrid(BuildContext context, List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post, String postId) {
    // This is a simplified version of the attachment grid logic.
    // For a full implementation, you would need the complex grid layout logic from the home feed.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: attachmentsArg.length,
      itemBuilder: (context, index) {
        return _buildAttachmentWidget(context, attachmentsArg[index], index, post, BorderRadius.circular(8.0), postId: postId);
      },
    );
  }

  Widget _buildAttachmentWidget(BuildContext context, Map<String, dynamic> attachmentMap, int idx, Map<String, dynamic> post, BorderRadius borderRadius, {BoxFit fit = BoxFit.contain, required String postId}) {
    final String attachmentType = attachmentMap['type'] as String? ?? 'unknown';
    final String? displayUrl = attachmentMap['url'] as String?;

    Widget contentWidget;

    if (attachmentType == "video") {
      contentWidget = VideoAttachmentWidget(
        key: Key('video_${attachmentMap['_id']}'),
        attachment: attachmentMap,
        post: post,
        borderRadius: borderRadius,
        isFeedContext: true,
        enforceFeedConstraints: true,
        startMuted: false,
      );
    } else if (attachmentType == "audio") {
      contentWidget = AudioAttachmentWidget(
        key: Key('audio_${attachmentMap['_id']}'),
        attachment: attachmentMap,
        post: post,
        borderRadius: borderRadius,
      );
    } else if (attachmentType == "image") {
      contentWidget = CachedNetworkImage(
        imageUrl: displayUrl ?? '',
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[900]),
        errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)),
      );
    } else if (attachmentType == "pdf") {
      contentWidget = PdfViewer.uri(
        Uri.parse(displayUrl ?? ''),
        params: const PdfViewerParams(
          maxScale: 1.0,
        ),
      );
    } else {
      contentWidget = Container(color: Colors.grey[900], child: const Icon(FeatherIcons.fileText, color: Colors.grey, size: 40));
    }

    return GestureDetector(
      onTap: () {
        _navigateToMediaViewPage(context, post['attachments'], attachmentMap, post, idx);
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
  }
}
