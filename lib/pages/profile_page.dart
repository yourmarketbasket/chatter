import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:io';
// more 
class ProfilePage extends StatefulWidget {
  final String userId;
  final String username;
  final String? userAvatarUrl;

  const ProfilePage({
    Key? key,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DataController dataController = Get.find<DataController>();

  String? _extractAuthorId(Map<String, dynamic> post) {
    if (post['user'] is Map && (post['user'] as Map).containsKey('_id')) {
      return post['user']['_id'] as String?;
    }
    if (post['userId'] is String) {
      return post['userId'] as String?;
    }
    if (post['userId'] is Map && (post['userId'] as Map).containsKey('_id')) {
      return post['userId']['_id'] as String?;
    }
    return null;
  }

  List<TextSpan> _buildTextSpans(String text) {
    final List<TextSpan> spans = [];
    final RegExp hashtagRegExp = RegExp(r"(#\w+)");
    final TextStyle defaultStyle = GoogleFonts.roboto(fontSize: 14, color: Colors.white, height: 1.5);
    final TextStyle hashtagStyle = GoogleFonts.roboto(fontSize: 14, color: Colors.tealAccent, fontWeight: FontWeight.bold, height: 1.5);

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

  void _navigateToMediaViewPage(BuildContext context, List<Map<String, dynamic>> allAttachments, Map<String, dynamic> currentAttachmentMap, Map<String, dynamic> post, int fallbackIndex) {
    int initialIndex = allAttachments.indexWhere((att) =>
      (att['url'] != null && att['url'] == currentAttachmentMap['url']) ||
      (att['_id'] != null && att['_id'] == currentAttachmentMap['_id'])
    );
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

  Widget _buildAttachmentGrid(List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post, String postId) {
    const double itemSpacing = 4.0;
    List<Map<String, dynamic>> videoAttachmentsInGrid = attachmentsArg.where((att) => att['type'] == 'video').toList();
    bool isVideoGrid = videoAttachmentsInGrid.length > 1;

    if (attachmentsArg.isEmpty) return const SizedBox.shrink();

    if (attachmentsArg.length == 1) {
      final attachment = attachmentsArg[0];
      double aspectRatioToUse = 4 / 3;
      return AspectRatio(
        aspectRatio: aspectRatioToUse,
        child: _buildAttachmentWidget(attachment, 0, post, BorderRadius.circular(12.0), fit: BoxFit.fitWidth, postId: postId, isVideoGrid: false),
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
        physics: const NeverScrollableScrollPhysics(),
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
    final String attachmentType = (attachmentMap['type'] ?? '').toString();
    final String? displayUrl = attachmentMap['url'] as String?;

    Widget contentWidget;

    if (attachmentType.startsWith('video')) {
      contentWidget = VideoAttachmentWidget(
        key: Key('video_${displayUrl ?? idx}'),
        attachment: attachmentMap,
        post: post,
        borderRadius: BorderRadius.zero,
        isFeedContext: true,
        enforceFeedConstraints: true,
      );
    } else if (attachmentType.startsWith('audio') || attachmentType == 'voice') {
      contentWidget = AudioAttachmentWidget(
        key: Key('audio_${displayUrl ?? idx}'),
        attachment: attachmentMap,
        post: post,
        borderRadius: BorderRadius.zero,
      );
    } else if (attachmentType.startsWith('image')) {
      Widget imageContent;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        imageContent = CachedNetworkImage(
          imageUrl: displayUrl,
          fit: BoxFit.cover,
          memCacheWidth: 600,
          placeholder: (context, url) => Container(color: Colors.grey[900]),
          errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
      } else {
        imageContent = Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40));
      }
      contentWidget = imageContent;
    } else {
      contentWidget = Container(
        color: Colors.grey[900],
        child: const Icon(FeatherIcons.fileText, color: Colors.grey, size: 40),
      );
    }

    return GestureDetector(
      onTap: () {
        final List<Map<String, dynamic>> attachments = (post['attachments'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ?? [];
        _navigateToMediaViewPage(context, attachments, attachmentMap, post, idx);
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String text, VoidCallback onPressed, {bool isLiked = false, bool isReposted = false, bool isBookmarked = false}) {
    Color iconColor = Colors.white;
    if (isLiked) iconColor = Colors.redAccent;
    if (isReposted) iconColor = Colors.tealAccent;
    if (isBookmarked) iconColor = Colors.amber;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.only(right: 15.0, top: 15.0, bottom: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 14),
            if (text.isNotEmpty)
              Text(text, style: GoogleFonts.roboto(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final String content = post['content'] as String? ?? '';
    await Share.share(content.isNotEmpty ? content : 'Check out this post from Chatter!', subject: 'Shared from Chatter');
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final userData = dataController.allUsers.firstWhere(
        (user) => user['_id'] == widget.userId,
        orElse: () => {
          'name': widget.username,
          'avatar': widget.userAvatarUrl ?? '',
          'followersCount': 0,
          'followingCount': 0,
          'isVerified': false,
        },
      );

      final String name = userData['name'] ?? widget.username;
      final String avatarUrl = userData['avatar'] ?? widget.userAvatarUrl ?? '';
      final int followersCount = userData['followersCount'] ?? 0;
      final int followingCount = userData['followingCount'] ?? 0;
      final bool isVerified = userData['isVerified'] ?? false;
      final String avatarInitial = name.isNotEmpty ? name[0].toUpperCase() : '?';

      final bool isOwnProfile = (dataController.user.value['user']?['_id'] ?? '') == widget.userId;
      final bool isFollowing = dataController.following.any((u) => u['_id'] == widget.userId);

      // Filter posts authored by this user from the main posts stream
      final List<Map<String, dynamic>> userPosts = dataController.posts
          .where((p) => _extractAuthorId(p) == widget.userId)
          .toList();

      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(
            name,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.tealAccent.withOpacity(0.2),
                    backgroundImage:
                        avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            avatarInitial,
                            style: GoogleFonts.poppins(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 40,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Icon(
                          Icons.verified,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$followersCount',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Followers',
                            style: GoogleFonts.roboto(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                      Column(
                        children: [
                          Text(
                            '$followingCount',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Following',
                            style: GoogleFonts.roboto(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!isOwnProfile)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            final currentUserId = dataController.user.value['user']['_id'];
                            Map<String, dynamic>? existingChat;
                            try {
                              existingChat = dataController.chats.values.firstWhere(
                                (chat) {
                                  if (chat['type'] == 'group') return false;
                                  final participantIds = (chat['participants'] as List).map((p) {
                                    if (p is Map<String, dynamic>) return p['_id'] as String;
                                    return p as String;
                                  }).toSet();
                                  return participantIds.contains(currentUserId) &&
                                      participantIds.contains(widget.userId);
                                },
                              );
                            } catch (_) {
                              existingChat = null;
                            }

                            if (existingChat != null) {
                              dataController.currentChat.value = existingChat;
                              Get.to(() => const ChatScreen());
                            } else {
                              final tempChat = {
                                'participants': [dataController.user.value['user'], userData],
                                'type': 'dm',
                              };
                              dataController.currentChat.value = tempChat;
                              Get.to(() => const ChatScreen());
                            }
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Send DM'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final currentUserId = dataController.user.value['user']['_id'];
                            if (isFollowing) {
                              await dataController.unfollowUser(widget.userId);
                            } else {
                              await dataController.followUser(widget.userId);
                            }
                            await dataController.fetchFollowing(currentUserId);
                          },
                          icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add),
                          label: Text(isFollowing ? 'Unfollow' : 'Follow'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
            // User posts list
            Expanded(
              child: userPosts.isEmpty
                  ? Center(
                      child: Text(
                        'No posts yet.',
                        style: GoogleFonts.roboto(color: Colors.white),
                      ),
                    )
                  : ListView.builder(
                      itemCount: userPosts.length,
                      itemBuilder: (context, index) {
                        final post = userPosts[index];
                        final String postId = (post['_id'] ?? '').toString();
                        final String username = (post['username'] ?? 'Unknown User').toString();
                        final String contentText = (post['content'] ?? '').toString();
                        final String? userAvatar = (post['useravatar'] as String?);
                        final DateTime timestamp = post['createdAt'] is String
                            ? DateTime.parse(post['createdAt'] as String).toUtc()
                            : DateTime.now().toUtc();

                        final List<dynamic> likesList = post['likes'] as List<dynamic>? ?? [];
                        final int likesCount = likesList.length;
                        final bool isLikedByCurrentUser = likesList.any((like) {
                          final currentUserId = dataController.user.value['user']?['_id'] ?? '';
                          return (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId);
                        });

                        final List<dynamic> bookmarksList = post['bookmarks'] as List<dynamic>? ?? [];
                        final bool isBookmarkedByCurrentUser = bookmarksList.any((b) {
                          final currentUserId = dataController.user.value['user']?['_id'] ?? '';
                          return (b is Map ? b['_id'] == currentUserId : b.toString() == currentUserId);
                        });

                        final int views = post['viewsCount'] as int? ?? (post['views'] as List?)?.length ?? 0;
                        final int repostsCount = (post['reposts'] as List?)?.length ?? 0;
                        final List<Map<String, dynamic>> attachments = (post['attachments'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
                        final int replyCount = (post['replies'] as List?)?.length ?? (post['replyCount'] as int? ?? 0);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                                backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                                    ? NetworkImage(userAvatar)
                                    : null,
                                child: (userAvatar == null || userAvatar.isEmpty)
                                    ? Text(
                                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                                        style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: 16),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('$username', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                                        const Icon(Icons.verified, color: Colors.amber, size: 15),
                                        const SizedBox(width: 2),
                                        Text('@$username', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 10, color: const Color.fromARGB(255, 143, 143, 143))),

                                        const SizedBox(width: 6),
                                        Text(
                                          '· ${timeago.format(timestamp)} · ${DateFormat('MMM d, yy').format(timestamp.toLocal())}',
                                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (contentText.isNotEmpty)
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.roboto(fontSize: 14, color: Colors.white, height: 1.5),
                                          children: _buildTextSpans(contentText),
                                        ),
                                      ),
                                    if (attachments.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      _buildAttachmentGrid(attachments, post, postId),
                                    ],
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        _buildActionButton(FeatherIcons.messageCircle, '$replyCount', () {}),
                                        const SizedBox(width: 12),
                                        _buildActionButton(FeatherIcons.eye, '$views', () {}),
                                        const SizedBox(width: 12),
                                        _buildActionButton(FeatherIcons.repeat, '$repostsCount', () {}),
                                        const SizedBox(width: 12),
                                        _buildActionButton(isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart, '$likesCount', () {}, isLiked: isLikedByCurrentUser),
                                        const SizedBox(width: 12),
                                        _buildActionButton(isBookmarkedByCurrentUser ? Icons.bookmark : FeatherIcons.bookmark, '', () {}, isBookmarked: isBookmarkedByCurrentUser),
                                        const SizedBox(width: 12),
                                        _buildActionButton(Icons.share_outlined, '', () => _sharePost(post)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}