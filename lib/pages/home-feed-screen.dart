import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/new-posts-page.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/pages/repost_page.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class Attachment {
  final File? file; // Nullable for server-fetched attachments
  final String type;
  final String? filename; // Added to match Mongoose schema
  final int? size; // Added to match Mongoose schema
  final String? url;

  Attachment({
    this.file,
    required this.type,
    this.filename,
    this.size,
    this.url,
  });
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
  final String? useravatar; // Added to match Mongoose schema
  List<String> replies; // Changed to List<String> for ObjectId references

  ChatterPost({
    required this.username,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.reposts = 0,
    this.views = 0,
    this.attachments = const [],
    required this.avatarInitial,
    this.useravatar,
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
    dataController.fetchFeeds().catchError((error) {
      print("Error fetching feeds: $error");
      print("Stack trace: ${error.stackTrace}");
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
      try {
        print('[HomeFeedScreen _addPost] Attachment ${i+1}: type=${a.type}, path=${a.file?.path}, file_exists_sync=${a.file?.existsSync()}, length_sync=${a.file?.lengthSync()}, filename=${a.filename}, size=${a.size}, url=${a.url}');
      } catch (e) {
        print('[HomeFeedScreen _addPost] Attachment ${i+1}: type=${a.type}, path=${a.file?.path}, url=${a.url} - Error getting file stats: $e');
      }
    }

    List<Attachment> uploadedAttachments = [];
    if (attachments.isNotEmpty) {
      List<File> files = attachments.where((a) => a.file != null).map((a) => a.file!).toList();
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
            filename: attachments[i].file?.path.split('/').last ?? 'unknown',
            size: attachments[i].file != null ? await attachments[i].file!.length() : 0,
            url: result['url'] as String,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload ${attachments[i].file?.path.split('/').last}: ${result['message']}',
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
      'username': "YourName",
      'content': content.trim(),
      'useravatar': dataController.user.value['avatar'] ?? '',
      'attachments': uploadedAttachments.map((att) => {
        'filename': att.filename,
        'url': att.url,
        'size': att.size,
        'type': att.type,
      }).toList(),
    };

    print(dataController.user.value);

    final result = await dataController.createPost(postData);
    print(result);

    if (result['success'] == true) {
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

  Future<void> _navigateToReplyPage(ChatterPost post) async {
    final newReply = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyPage(post: post),
      ),
    );

    if (newReply != null && newReply is Map<String, dynamic>) {
      // Assuming ReplyPage returns a Map with reply data
      Map<String, dynamic> replyData = {
        'username': newReply['username'] ?? 'YourName',
        'content': newReply['content']?.trim() ?? '',
        'useravatar': newReply['useravatar'] ?? '',
        'attachments': newReply['attachments']?.map((att) async => {
          'filename': att.file?.path.split('/').last ?? 'unknown',
          'url': att.url,
          'size': att.file != null ? await att.file.length() : 0,
          'type': att.type,
        }).toList() ?? [],
      };

      final result = await dataController.createPost(replyData);
      if (result['success'] == true) {
        // Add the reply's ObjectId to the parent post's replies
        final postIndex = dataController.posts.indexWhere((p) => p['createdAt'] == post.timestamp.toIso8601String());
        if (postIndex != -1) {
          final postMap = dataController.posts[postIndex];
          List<String> replies = List.from(postMap['replies'] ?? []);
          replies.add(result['postId']); // Assuming createPost returns the new post's ID
          postMap['replies'] = replies;
          dataController.posts[postIndex] = postMap;
          dataController.posts.refresh();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply added to the post!', style: GoogleFonts.roboto(color: Colors.white)),
            backgroundColor: Colors.teal[700],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add reply: ${result['message'] ?? 'Unknown error'}',
              style: GoogleFonts.roboto(color: Colors.white),
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
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
              backgroundImage: post.useravatar != null && post.useravatar!.isNotEmpty
                  ? NetworkImage(post.useravatar!)
                  : null,
              child: post.useravatar == null || post.useravatar!.isEmpty
                  ? Text(
                      post.avatarInitial,
                      style: GoogleFonts.poppins(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: isReply ? 14 : 16,
                      ),
                    )
                  : null,
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
                        final displayUrl = attachment.url ?? '';
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
                                    : attachment.file != null
                                        ? Image.file(
                                            attachment.file!,
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
                                        : Container(
                                            color: Colors.grey[900],
                                            child: Icon(
                                              FeatherIcons.image,
                                              color: Colors.grey[500],
                                              size: 40,
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
                                              attachment.filename ?? displayUrl.split('/').last,
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
                              _navigateToReplyPage(post);
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
                              _navigateToRepostPage(post);
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
            final post = ChatterPost(
              username: postMap['username'] ?? 'Unknown User',
              content: postMap['content'] ?? '',
              timestamp: postMap['createdAt'] is String
                  ? DateTime.parse(postMap['createdAt'])
                  : DateTime.now(),
              likes: postMap['likes'] ?? 0,
              reposts: postMap['reposts'] ?? 0,
              views: postMap['views'] ?? 0,
              useravatar: postMap['useravatar'] ?? '',
              avatarInitial: (postMap['username'] != null && postMap['username'].isNotEmpty)
                  ? postMap['username'][0].toUpperCase()
                  : '?',
              attachments: (postMap['attachments'] as List<dynamic>?)?.map((att) {
                return Attachment(
                  file: null,
                  type: att['type'] ?? 'unknown',
                  filename: att['filename'],
                  size: att['size'],
                  url: att['url'] as String?,
                );
              }).toList() ?? [],
              replies: (postMap['replies'] as List<dynamic>?)?.cast<String>() ?? [],
            );
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _buildPostContent(post, isReply: false),
            );
          },
        );
      }),
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