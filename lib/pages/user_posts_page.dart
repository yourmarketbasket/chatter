import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:chatter/widgets/reply/post_content.dart'; // Assuming this can be reused/adapted
import 'package:chatter/widgets/reply/reply_attachment_grid.dart'; // For image grids
import 'package:chatter/widgets/reply/stat_button.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:chatter/widgets/realtime_timeago_text.dart';
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
  Widget _buildAttachmentView(Map<String, dynamic> attachment, Map<String, dynamic> postData) {
    String type = attachment['type'] ?? 'unknown';
    String url = attachment['url'] ?? '';
    final BorderRadius defaultBorderRadius = BorderRadius.circular(12.0);

    // Add more specific widgets as needed, mirroring home_feed_screen.dart
    if (type.startsWith('image/')) {
      // For single images, directly use CachedNetworkImage or similar.
      return ClipRRect( // Ensure images also respect border radius if they are standalone
        borderRadius: defaultBorderRadius,
        child: CachedNetworkImage(
          imageUrl: url,
          placeholder: (context, url) => Container(
            height: 150, // Example height, adjust as needed
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: defaultBorderRadius,
            ),
            child: Center(child: Icon(FeatherIcons.image, color: Colors.grey[600])),
          ),
          errorWidget: (context, url, error) => Container(
            height: 150, // Example height
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: defaultBorderRadius,
            ),
            child: Center(child: Icon(FeatherIcons.alertCircle, color: Colors.red[400])),
          ),
          fit: BoxFit.cover,
        ),
      );
    } else if (type.startsWith('video/')) {
      return VideoAttachmentWidget(
        key: ValueKey(attachment['url'] ?? attachment['_id'] ?? UniqueKey().toString()), // Unique key
        attachment: attachment,
        post: postData, // Use postData parameter
        borderRadius: defaultBorderRadius,
        // isFeedContext can be true if you want feed-like constraints, or false for native aspect ratio
        // enforceFeedConstraints might be relevant here if UserPostsPage should behave like a feed
      );
    } else if (type.startsWith('audio/')) {
      return AudioAttachmentWidget(
        key: ValueKey(attachment['url'] ?? attachment['_id'] ?? UniqueKey().toString()), // Unique key
        attachment: attachment,
        post: postData, // Use postData parameter
        borderRadius: defaultBorderRadius,
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
    final String createdAtString = post['createdAt']?.toString() ?? DateTime.now().toIso8601String();
    final DateTime createdAtDateTime = DateTime.tryParse(createdAtString) ?? DateTime.now();
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
        Get.to(() => ReplyPage(
          post: post,
          postDepth: 0, // This is a top-level post from UserPostsPage
          originalPostId: post['_id'] as String?, // The post itself is the original post in this context
        ));
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
                      RealtimeTimeagoText(timestamp: createdAtDateTime, style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                  if (postContent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                      child: PostContent(
                        postData: post, // Pass the full post map
                        isReply: false, // These are main posts, not replies
                        postDepth: 0,   // Top-level posts
                        showSnackBar: _showPostContentSnackBar,
                        onSharePost: _sharePostFromContent,
                        onReplyToItem: _handleReplyToItem, // Or a more specific handler if needed
                        refreshReplies: _handleRefreshReplies, // Or a more specific handler
                        onReplyDataUpdated: _handleReplyDataUpdated, // Or a more specific handler
                        // indentationLevel, isPreview, pageOriginalPostId, drawInternalVerticalLine can use defaults or be set if needed
                        // For UserPostsPage, these are main posts, so isReply=false, postDepth=0.
                        // Callbacks are stubbed or point to general handlers.
                      ),
                    ),

                  // Attachments display
                  if (attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: attachments.length == 1
                          ? _buildAttachmentView(attachments.first as Map<String, dynamic>, post)
                          : ReplyAttachmentGrid(
                              attachmentsArg: List<Map<String, dynamic>>.from(attachments.map((a) => a as Map<String, dynamic>)),
                              postOrReplyData: post, // Pass the full post map here
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
                          text: repliesCount.toString(),
                          onPressed: () => Get.to(() => ReplyPage(
                            post: post,
                            postDepth: 0, // This is a top-level post
                            originalPostId: postId, // Pass the current post's ID as originalPostId
                          )),
                          color: Colors.grey[600]!,
                        ),
                        StatButton(
                          icon: FeatherIcons.repeat,
                          text: repostsCount.toString(),
                          onPressed: () async {
                            final result = await _dataController.repostPost(postId);
                            if (mounted && result['success'] == false) {
                                Get.snackbar('Error', result['message'] ?? 'Could not repost.', snackPosition: SnackPosition.BOTTOM);
                            } else if (mounted && result['success'] == true) {
                                Get.snackbar('Success', 'Reposted!', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green);
                            }
                          },
                          color: Colors.grey[600]!,
                        ),
                        StatButton(
                          icon: isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart, // Conditional icon
                          text: likesCount.toString(),
                          onPressed: () async {
                            if (isLikedByCurrentUser) {
                                await _dataController.unlikePost(postId);
                            } else {
                                await _dataController.likePost(postId);
                            }
                            // DataController's fetchSinglePost (called by like/unlike) should trigger
                            // an update in the main 'posts' list. If UserPostsPage needs to reflect
                            // this change immediately without a full page reload, the specific post
                            // in '_dataController.userPosts' would need to be updated.
                            // For now, relying on DataController's existing refresh mechanisms.
                          },
                          color: isLikedByCurrentUser ? Colors.pinkAccent : Colors.grey[600]!, // Conditional color
                        ),
                        StatButton(
                          icon: FeatherIcons.barChart2, // Using bar chart for views as an example
                          text: viewsCount.toString(),
                          onPressed: () { /* Maybe do nothing on tap, or show who viewed */ },
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
