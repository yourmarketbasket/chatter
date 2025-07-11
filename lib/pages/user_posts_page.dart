import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:chatter/widgets/reply/post_content.dart'; // Assuming this can be reused/adapted
import 'package:chatter/widgets/reply/reply_attachment_grid.dart'; // For image grids
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:chatter/widgets/realtime_timeago_text.dart';
import 'package:chatter/widgets/stat_button.dart'; // For like, reply, repost buttons
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

  // Helper to build attachment widgets based on type (simplified)
  Widget _buildAttachmentView(Map<String, dynamic> attachment) {
    String type = attachment['type'] ?? 'unknown';
    String url = attachment['url'] ?? '';
    // Add more specific widgets as needed, mirroring home_feed_screen.dart
    if (type.startsWith('image/')) {
      // For single images, directly use CachedNetworkImage or similar.
      // For multiple, ReplyAttachmentGrid might be used if it's adaptable.
      // This part needs to be expanded based on how home_feed_screen handles single vs multiple images.
      return CachedNetworkImage(
        imageUrl: url,
        placeholder: (context, url) => Container(
          height: 150,
          color: Colors.grey[800],
          child: Center(child: Icon(FeatherIcons.image, color: Colors.grey[600])),
        ),
        errorWidget: (context, url, error) => Container(
          height: 150,
          color: Colors.grey[800],
          child: Center(child: Icon(FeatherIcons.alertCircle, color: Colors.red[400])),
        ),
        fit: BoxFit.cover,
      );
    } else if (type.startsWith('video/')) {
      // Assuming VideoAttachmentWidget can be used similarly
      return VideoAttachmentWidget(
        attachmentData: attachment,
        postId: attachment['postIdForVideo'] ?? GlobalKey().toString(), // Requires postId if VideoAttachmentWidget needs it
      );
    } else if (type.startsWith('audio/')) {
      return AudioAttachmentWidget(
         attachmentData: attachment,
         postId: attachment['postIdForAudio'] ?? GlobalKey().toString(), // Requires postId if AudioAttachmentWidget needs it
      );
    } else if (type == 'application/pdf') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!)
        ),
        child: Row(
          children: [
            Icon(FeatherIcons.fileText, color: Colors.redAccent[100], size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                attachment['filename'] ?? 'PDF Document',
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Text('Unsupported attachment: ${attachment['filename'] ?? type}', style: GoogleFonts.roboto(color: Colors.grey[500]));
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    final String postUserAvatar = post['user']?['avatar'] ?? '';
    final String postUsername = post['user']?['username'] ?? 'Unknown';
    final String postUserDisplayName = post['user']?['name'] ?? 'User';
    final String postContent = post['content'] ?? '';
    final List<dynamic> attachments = post['attachments'] as List<dynamic>? ?? [];
    final String createdAt = post['createdAt']?.toString() ?? DateTime.now().toIso8601String();
    final String postId = post['_id'] ?? '';

    final int likesCount = post['likesCount'] ?? 0;
    final int repliesCount = post['replyCount'] ?? 0; // Assuming 'replyCount' from _processPostOrReply
    final int repostsCount = post['repostsCount'] ?? 0;
    final int viewsCount = post['viewsCount'] ?? 0;
    final List<dynamic> likes = post['likes'] as List<dynamic>? ?? [];
    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';
    final bool isLikedByCurrentUser = likes.any((like) => (like is String ? like : like?['_id']) == currentUserId);


    return InkWell(
      onTap: () {
        Get.to(() => ReplyPage(post: post));
      },
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[850]!, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: postUserAvatar.isNotEmpty ? CachedNetworkImageProvider(postUserAvatar) : null,
              child: postUserAvatar.isEmpty ? Text(postUserDisplayName.isNotEmpty ? postUserDisplayName[0].toUpperCase() : 'U', style: GoogleFonts.poppins(color: Colors.white)) : null,
              backgroundColor: Colors.grey[700],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(postUserDisplayName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                      const SizedBox(width: 4),
                      Text('@$postUsername', style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('·', style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 14)),
                      const SizedBox(width: 4),
                      RealtimeTimeagoText(isoTimeString: createdAt, textStyle: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                  if (postContent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                      // Using PostContent widget if it's suitable for displaying main post text
                      child: PostContent(content: postContent, buffer: post['buffer'], textStyle: GoogleFonts.roboto(color: Colors.white, fontSize: 15, height: 1.4)),
                    ),

                  // Attachments display
                  if (attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: attachments.length == 1
                          ? _buildAttachmentView(attachments.first as Map<String, dynamic>)
                          : ReplyAttachmentGrid( // This might need adaptation or a new PostAttachmentGrid
                              attachments: List<Map<String, dynamic>>.from(attachments.map((a) => a as Map<String, dynamic>)),
                              // onAttachmentTap: (index) { /* Handle tap if needed, e.g., open full screen */ }
                            ),
                    ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatButton(
                          icon: FeatherIcons.messageCircle,
                          count: repliesCount,
                          onTap: () => Get.to(() => ReplyPage(post: post)),
                          color: Colors.grey[600]!,
                        ),
                        StatButton(
                          icon: FeatherIcons.repeat,
                          count: repostsCount,
                          onTap: () async {
                            final result = await _dataController.repostPost(postId);
                            if (mounted && result['success'] == false) {
                                Get.snackbar('Error', result['message'] ?? 'Could not repost.', snackPosition: SnackPosition.BOTTOM);
                            } else if (mounted && result['success'] == true) {
                                Get.snackbar('Success', 'Reposted!', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green);
                            }
                          },
                          color: Colors.grey[600]!,
                          // isActivated: isRepostedByCurrentUser, // Add this logic if needed
                        ),
                        StatButton(
                          icon: FeatherIcons.heart,
                          count: likesCount,
                          isActivated: isLikedByCurrentUser,
                          activeColor: Colors.pinkAccent,
                          onTap: () async {
                            if (isLikedByCurrentUser) {
                                await _dataController.unlikePost(postId);
                            } else {
                                await _dataController.likePost(postId);
                            }
                            // DataController should update the post list, triggering Obx rebuild
                          },
                          color: Colors.grey[600]!,
                        ),
                        StatButton(
                          icon: FeatherIcons.barChart2, // Using bar chart for views as an example
                          count: viewsCount,
                          onTap: () { /* Maybe do nothing on tap, or show who viewed */ },
                          color: Colors.grey[600]!,
                        ),
                        // Share button (optional)
                        // IconButton(icon: Icon(FeatherIcons.share, color: Colors.grey[600], size: 18), onPressed: () {})
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
