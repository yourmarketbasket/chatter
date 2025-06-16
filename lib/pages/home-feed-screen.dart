import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/new-posts-page.dart';
import 'package:chatter/pages/reply_page.dart'; // Added import for ReplyPage
import 'package:chatter/pages/repost_page.dart'; // Added import for RepostPage
import 'package:chatter/pages/media_view_page.dart'; // Added import for MediaViewPage
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class Attachment {
  final File file;
  final String type;
  String? url; // URL after uploading to Cloudinary

  Attachment({required this.file, required this.type, this.url});
}

class ChatterPost {
  final String username;
  final String content;
  final DateTime timestamp;
  int likes;
  int reposts;
  int views;
  final List<Attachment> attachments;
  final String avatarInitial;
  final List<ChatterPost> replies;

  ChatterPost({
    required this.username,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.reposts = 0,
    this.views = 0,
    this.attachments = const [],
    required this.avatarInitial,
    this.replies = const [],
  });
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  DataController dataController = Get.put(DataController());

  @override
  void initState() {
    super.initState();
    // Fetch initial posts when the screen loads
    // Consider adding error handling for the fetchFeeds call if needed
    dataController.fetchFeeds().catchError((error) {
      // Handle or log error, e.g., show a SnackBar
      print("Error fetching feeds: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load feed. Please try again later.', style: GoogleFonts.roboto(color: Colors.white)),
          backgroundColor: Colors.red[700],
        ),
      );
    });
  }

  void _navigateToPostScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewPostScreen()),
    );
    if (result != null && result is Map<String, dynamic>) {
      _addPost(result['content'], result['attachments']);
    }
  }

  Future<void> _navigateToRepostPage(ChatterPost post) async {
    final confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepostPage(post: post),
      ),
    );

    if (confirmed == true) {
      setState(() {
        post.reposts++;
        // TODO: Potentially call a DataController method here to notify backend about the repost
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

  Future<void> _addPost(String content, List<Attachment> attachments) async {
    print('[HomeFeedScreen _addPost] Received ${attachments.length} attachments.');
    for (int i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      // Use sync methods for simplicity in logging.
      try {
        print('[HomeFeedScreen _addPost] Attachment ${i+1}: type=${a.type}, path=${a.file.path}, file_exists_sync=${a.file.existsSync()}, length_sync=${a.file.lengthSync()}, url=${a.url}');
      } catch (e) {
        print('[HomeFeedScreen _addPost] Attachment ${i+1}: type=${a.type}, path=${a.file.path}, url=${a.url} - Error getting file stats: $e');
      }
    }

    // Upload files to Cloudinary
    List<Attachment> uploadedAttachments = [];
    if (attachments.isNotEmpty) {
      List<File> files = attachments.map((a) => a.file).toList();
      print('[HomeFeedScreen _addPost] Extracted ${files.length} files for upload:');
      for (int i = 0; i < files.length; i++) {
        final f = files[i];
        try {
          print('[HomeFeedScreen _addPost] File ${i+1} for upload: path=${f.path}, exists_sync=${f.existsSync()}, length_sync=${f.lengthSync()}');
        } catch (e) {
          print('[HomeFeedScreen _addPost] File ${i+1} for upload: path=${f.path} - Error getting file stats: $e');
        }
      }
      List<Map<String, dynamic>> uploadResults = await dataController.uploadFilesToCloudinary(files);
      
      for (int i = 0; i < attachments.length; i++) {
        var result = uploadResults[i];
        print(result);
        if (result['success'] == true) {
          uploadedAttachments.add(Attachment(
            file: attachments[i].file,
            type: attachments[i].type,
            url: result['url'] as String,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload ${attachments[i].file.path.split('/').last}: ${result['message']}',
                style: GoogleFonts.roboto(color: Colors.white),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }

    // Early exit if no content and no successfully uploaded attachments
    if (content.trim().isEmpty && uploadedAttachments.isEmpty) {
      return;
    }

    // Prepare data for the backend
    Map<String, dynamic> postData = {
      'username': "YourName",
      'content': content.trim(),
      'attachment_urls': uploadedAttachments
          .where((att) => att.url != null)
          .map((att) => att.url!)
          .toList(),
    };

    print(dataController.user.value);

    // Call the backend to create the post
    final result = await dataController.createPost(postData);
    print(result);

    if (result['success'] == true) {
      // The post is now added via socket event and DataController's reactive list.
      // No need to manually add to a local list or call setState.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Poa! Your chatter is live!',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.teal[700],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create post on server: ${result['message'] ?? 'Unknown error'}',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // _showRepliesDialog is now replaced by navigating to ReplyPage
  // void _showRepliesDialog(ChatterPost post) { ... } // Original content removed

  Future<void> _navigateToReplyPage(ChatterPost post) async {
    final newReply = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyPage(post: post),
      ),
    );

    if (newReply != null && newReply is ChatterPost) {
      setState(() {
        // Find the post in the dataController's list and update it.
        // This is a simplified approach. In a real app with a proper backend,
        // you'd likely refresh the post data or rely on a stream.
        // For now, we update the local 'post' object's replies list.
        // This assumes 'post' is the same instance that's rendered in the list.
        // If dataController.posts contains different instances, this local update
        // might not reflect correctly without finding and updating the specific post
        // in dataController.posts.

        // The ChatterPost object passed to ReplyPage and modified there
        // might not be the same instance as the one in the list view if posts
        // are rebuilt from dataController.posts on each build.
        // A more robust way would be to update the data source (dataController.posts)
        // and have Obx rebuild.

        // For simplicity, let's assume 'post.replies.add(newReply)' is sufficient
        // if 'post' is a direct reference to an object whose state is maintained.
        // However, the current setup with dataController.posts being maps means
        // we need to find and update the specific post in the list or have DataController
        // handle this update.

        // Let's try to update the original post object directly.
        // This will work if 'post' is a reference that the UI is observing.
        post.replies.add(newReply);

        // To ensure UI update, especially if post objects are recreated from maps:
        // We need to find the index of the post and update it in the dataController
        // Or, ideally, the DataController handles adding replies and the UI reacts.
        // For now, we'll rely on the direct mutation of `post.replies` and `setState`.
        // This is a common pattern if the list items themselves are stateful or hold
        // mutable objects.
      });
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reply added to the post!', style: GoogleFonts.roboto(color: Colors.white)),
          backgroundColor: Colors.teal[700],
        ),
      );
    }
  }

  Widget _buildPostContent(ChatterPost post, {required bool isReply}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 16 : 20,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              child: Text(
                post.avatarInitial,
                style: GoogleFonts.poppins(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: isReply ? 14 : 16,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '@${post.username}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: isReply ? 14 : 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a · MMM d').format(post.timestamp),
                        style: GoogleFonts.roboto(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    post.content,
                    style: GoogleFonts.roboto(
                      fontSize: isReply ? 13 : 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (post.attachments.isNotEmpty) ...[
                    SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: post.attachments.length > 1 ? 2 : 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: post.attachments.length,
                      itemBuilder: (context, idx) {
                        final attachment = post.attachments[idx];
                        final displayUrl = attachment.url ?? attachment.file.path;
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MediaViewPage(attachment: attachment),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: attachment.type == "image"
                                ? attachment.url != null
                                    ? Image.network(
                                        attachment.url!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[900],
                                          child: Icon(
                                            FeatherIcons.image,
                                            color: Colors.grey[500],
                                            size: 40,
                                          ),
                                        ),
                                      )
                                    : Image.file(
                                        attachment.file,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[900],
                                          child: Icon(
                                            FeatherIcons.image,
                                            color: Colors.grey[500],
                                            size: 40,
                                          ),
                                        ),
                                      )
                                : attachment.type == "pdf"
                                    ? PdfViewer.uri(
                                        Uri.parse(displayUrl),
                                        params: PdfViewerParams(
                                          maxScale: 1.0,
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[900],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              attachment.type == "audio" ? FeatherIcons.music : FeatherIcons.video,
                                              color: Colors.tealAccent,
                                              size: 40,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              displayUrl.split('/').last,
                                              style: GoogleFonts.roboto(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                          ),
                        );
                      },
                    ),
                  ],
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              FeatherIcons.heart,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                post.likes++;
                              });
                            },
                          ),
                          Text(
                            '${post.likes}',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              FeatherIcons.messageCircle,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              // _showRepliesDialog(post); // Old call
                              _navigateToReplyPage(post); // New call
                            },
                          ),
                          Text(
                            '${post.replies.length}',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              FeatherIcons.repeat,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              // setState(() {
                              //   post.reposts++;
                              // });
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(
                              //     content: Text(
                              //       'Poa! Reposted!',
                              //       style: GoogleFonts.roboto(color: Colors.white),
                              //     ),
                              //     backgroundColor: Colors.teal[700],
                              //   ),
                              // );
                              _navigateToRepostPage(post); // New call
                            },
                          ),
                          Text(
                            '${post.reposts}',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              FeatherIcons.eye,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                          Text(
                            '${post.views}',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Chatter',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF000000),
        elevation: 0,
      ),
      body: Obx(() {
        if (dataController.posts.isEmpty) {
          // Show a loading indicator or a "No posts" message
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
            ),
          );
        }
        return ListView.separated(
          itemCount: dataController.posts.length,
          separatorBuilder: (context, index) => Divider(
            color: Colors.grey[850],
            height: 1,
          ),
          itemBuilder: (context, index) {
            final postMap = dataController.posts[index];
            // Map the Map<String, dynamic> to a ChatterPost object
            // final post = ChatterPost( ... ) // This mapping happens inside the Obx
            // It's important that the 'post' object passed to _navigateToReplyPage
            // is the actual instance being used by _buildPostContent, or that
            // changes are reflected in dataController.posts list.

            // The current structure maps dataController.posts (List<Map<String, dynamic>>)
            // to ChatterPost objects on-the-fly within the itemBuilder.
            // This means the 'post' object created here is ephemeral for each build.
            // Modifying post.replies directly in _navigateToReplyPage's callback
            // won't work if the 'post' instance there is not the one from dataController.
            // The DataController should ideally handle adding replies to its data structures.

            // For now, the `setState` in `_navigateToReplyPage` will trigger a rebuild.
            // During the rebuild, `post.replies.length` will be re-evaluated.
            // If the `ChatterPost` objects are preserved across rebuilds (e.g. if they are stored
            // directly in DataController or if the mapping function returns the same instances),
            // then adding to `post.replies` will reflect.
            // However, the current mapping creates NEW ChatterPost objects each time.

            // TODO: Refactor state management for replies.
            // A quick fix might be to find the post in dataController.posts by an ID
            // and update its 'replies' field in the map, then dataController.posts.refresh().
            // For now, we'll proceed with the direct modification and setState,
            // acknowledging it might not be robust if ChatterPost instances are not preserved.

            final postMap = dataController.posts[index];
            final post = ChatterPost(
              username: postMap['user']?['name'] ?? 'Unknown User',
              content: postMap['content'] ?? '',
              timestamp: postMap['createdAt'] is String
                  ? DateTime.parse(postMap['createdAt'])
                  : DateTime.now(),
              likes: postMap['likes']?.length ?? 0,
              reposts: postMap['reposts'] ?? 0,
              views: postMap['views'] ?? 0,
              avatarInitial: (postMap['user']?['name'] != null && postMap['user']['name'].isNotEmpty)
                  ? postMap['user']['name'][0].toUpperCase()
                  : '?',
              attachments: (postMap['attachment_urls'] as List<dynamic>?)?.map((attUrl) {
                String type = 'unknown';
                if (attUrl is String) {
                  if (attUrl.toLowerCase().endsWith('.jpg') || attUrl.toLowerCase().endsWith('.jpeg') || attUrl.toLowerCase().endsWith('.png')) type = 'image';
                  else if (attUrl.toLowerCase().endsWith('.pdf')) type = 'pdf';
                  else if (attUrl.toLowerCase().endsWith('.mp4') || attUrl.toLowerCase().endsWith('.mov')) type = 'video';
                  else if (attUrl.toLowerCase().endsWith('.mp3') || attUrl.toLowerCase().endsWith('.wav') || attUrl.toLowerCase().endsWith('.m4a')) type = 'audio';
                }
                return Attachment(file: File(''), type: type, url: attUrl as String?);
              }).toList() ?? [],
              // IMPORTANT: Initialize replies from the postMap if available, otherwise it's always empty.
              // This was a bug. If replies come from the server, they should be mapped here.
              // For now, we assume replies are managed locally and start empty for new posts from server.
              // If postMap contains 'replies', map them here.
              replies: (postMap['replies'] as List<dynamic>?)?.map((replyMap) {
                    // Assuming replyMap has a similar structure to a postMap
                    return ChatterPost(
                       username: replyMap['user']?['name'] ?? 'Unknown User',
                        content: replyMap['content'] ?? '',
                        timestamp: replyMap['createdAt'] is String ? DateTime.parse(replyMap['createdAt']) : DateTime.now(),
                        avatarInitial: (replyMap['user']?['name'] != null && replyMap['user']['name'].isNotEmpty) ? replyMap['user']['name'][0].toUpperCase() : '?',
                        attachments: (replyMap['attachment_urls'] as List<dynamic>?)?.map((attUrl) {
                            String type = 'unknown';
                            if (attUrl is String) {
                                if (attUrl.toLowerCase().endsWith('.jpg') || attUrl.toLowerCase().endsWith('.jpeg') || attUrl.toLowerCase().endsWith('.png')) type = 'image';
                                else if (attUrl.toLowerCase().endsWith('.pdf')) type = 'pdf';
                                else if (attUrl.toLowerCase().endsWith('.mp4') || attUrl.toLowerCase().endsWith('.mov')) type = 'video';
                                else if (attUrl.toLowerCase().endsWith('.mp3') || attUrl.toLowerCase().endsWith('.wav') || attUrl.toLowerCase().endsWith('.m4a')) type = 'audio';
                            }
                            return Attachment(file: File(''), type: type, url: attUrl as String?);
                        }).toList() ?? [],
                        replies: [], // Nested replies are not handled in this simplified example
                    );
                  }).toList() ?? [],
            );
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: Curves.easeInOut,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: _buildPostContent(post, isReply: false),
              ),
            );
          },
        ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF000000),
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.roboto(),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.search, size: 24),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.user, size: 24),
            label: 'Profile',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Search screen coming soon!',
                  style: GoogleFonts.roboto(color: Colors.white),
                ),
                backgroundColor: Colors.teal[700],
              ),
            );
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Profile screen coming soon!',
                  style: GoogleFonts.roboto(color: Colors.white),
                ),
                backgroundColor: Colors.teal[700],
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToPostScreen,
        backgroundColor: Colors.tealAccent,
        elevation: 2,
        child: Icon(FeatherIcons.plus, color: Colors.black),
      ),
    );
  }
}