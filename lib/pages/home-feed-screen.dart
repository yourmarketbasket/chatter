import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/new-posts-page.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/pages/repost_page.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/pages/search_page.dart';
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
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class Attachment {
  final File? file;
  final String type;
  final String? filename;
  final int? size;
  final String? url;
  final String? thumbnailUrl;

  Attachment({
    this.file,
    required this.type,
    this.filename,
    this.size,
    this.url,
    this.thumbnailUrl,
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
  final String? useravatar;
  List<String> replies;

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
  int? androidVersion;
  bool isLoadingAndroidVersion = true;
  bool _isFabMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _loadAndroidVersion();
    // The fetchFeeds call is now primarily handled by DataController.init()
    // However, we might want to show a snackbar if posts are empty after DataController init.
    // For now, we rely on DataController's init. If it fails, posts will be empty,
    // and the Obx in build method will show the loading indicator.
    // A more robust solution would involve listening to an error state from DataController.

    // Optional: If DataController's fetchFeeds fails, posts will be empty.
    // We can check this after a short delay or listen to an error stream from DataController
    // to show a SnackBar, but this adds complexity. The current plan is to verify and ensure loading.
    // The DataController.init() already tries to fetch feeds.
    // If an error occurs there, it's logged, and posts are cleared.
    // The UI in HomeFeedScreen shows a loading spinner if posts are empty.
  }

  Future<void> _loadAndroidVersion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? storedVersion = prefs.getInt('android_version');
    if (storedVersion != null) {
      setState(() {
        androidVersion = storedVersion;
        isLoadingAndroidVersion = false;
      });
    } else {
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int sdkInt = androidInfo.version.sdkInt;
        await prefs.setInt('android_version', sdkInt);
        setState(() {
          androidVersion = sdkInt;
          isLoadingAndroidVersion = false;
        });
      } else {
        setState(() {
          androidVersion = 33; // Default to use video_player for non-Android platforms
          isLoadingAndroidVersion = false;
        });
      }
    }
  }

  void _navigateToPostScreen() async {
    // Close the FAB menu if it's open
    if (_isFabMenuOpen) {
      setState(() {
        _isFabMenuOpen = false;
      });
    }

    final result = await Get.bottomSheet<Map<String, dynamic>>(
      // NewPostScreen is already a Scaffold with its own background color.
      // Wrap it if specific bottom sheet styling (like rounded top corners) is needed.
      Container(
        // Optional: Add padding or margin if NewPostScreen doesn't handle it well for bottom sheet form
        // padding: EdgeInsets.only(top: 20),
        child: NewPostScreen(), // NewPostScreen itself is a Scaffold
        // Apply rounded corners to the container shown as bottom sheet
        // decoration: BoxDecoration(
        //   color: Color(0xFF000000), // Match NewPostScreen's Scaffold background
        //   borderRadius: BorderRadius.only(
        //     topLeft: Radius.circular(16.0),
        //     topRight: Radius.circular(16.0),
        //   ),
        // ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Make Get.bottomSheet background transparent if NewPostScreen provides its own
      // elevation: // Optional: set elevation
    );

    if (result != null && result is Map<String, dynamic>) {
      // Ensure content and attachments keys exist, providing defaults if not.
      final String content = result['content'] as String? ?? '';
      final List<Attachment> attachments = (result['attachments'] as List?)?.whereType<Attachment>().toList() ?? <Attachment>[];

      if (content.isNotEmpty || attachments.isNotEmpty) {
        _addPost(content, attachments);
      }
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
          String originalUrl = result['url'] as String;
          String? thumbnailUrl = attachments[i].type == 'video'
              ? originalUrl.replaceAll('/upload/', '/upload/so_0,q_auto:low/')
              : null;
          uploadedAttachments.add(Attachment(
            file: attachments[i].file,
            type: attachments[i].type,
            filename: attachments[i].file?.path.split('/').last ?? 'unknown',
            size: attachments[i].file != null ? await attachments[i].file!.length() : 0,
            url: originalUrl,
            thumbnailUrl: thumbnailUrl,
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
      'username':  dataController.user.value['user']['name'] ?? 'YourName',
      'content': content.trim(),
      'useravatar': dataController.user.value['avatar'] ?? '',
      'attachments': uploadedAttachments.map((att) => {
        'filename': att.filename,
        'url': att.url,
        'size': att.size,
        'type': att.type,
        'thumbnailUrl': att.thumbnailUrl,
      }).toList(),
    };


    final result = await dataController.createPost(postData);
    

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Fantastic! Your chatter is live!',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.teal[700],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create post, please try again later',
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
      Map<String, dynamic> replyData = {
        'username': newReply['username'] ?? 'YourName',
        'content': newReply['content']?.trim() ?? '',
        'useravatar': newReply['useravatar'] ?? '',
        'attachments': newReply['attachments']?.map((att) => {
          'filename': att.file?.path.split('/').last ?? 'unknown',
          'url': att.url,
          'size': att.file != null ? att.file.lengthSync() : 0,
          'type': att.type,
          'thumbnailUrl': att.thumbnailUrl,
        }).toList() ?? [],
      };

      final result = await dataController.createPost(replyData);
      if (result['success'] == true) {
        final postIndex = dataController.posts.indexWhere((p) => p['createdAt'] == post.timestamp.toIso8601String());
        if (postIndex != -1) {
          final postMap = dataController.posts[postIndex];
          List<String> replies = List.from(postMap['replies'] ?? []);
          replies.add(result['postId']);
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
                      Flexible( // Added Flexible to prevent overflow if username is long
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
                          children: [
                            Text(
                              post.username, // Displaying only the username here
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: isReply ? 14 : 16,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis, // Prevent overflow
                            ),
                            SizedBox(width: 4.0),
                            Icon(
                              Icons.verified,
                              color: Colors.amber,
                              size: isReply ? 13 : 15, // Adjusted size slightly
                            ),
                            SizedBox(width: 4.0),
                            Text( // The handle part, now separate
                              ' · @${post.username}',
                              style: GoogleFonts.poppins(
                                fontSize: isReply ? 10 : 12,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis, // Prevent overflow
                            ),
                          ],
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
                      color: const Color.fromARGB(255, 255, 255, 255),
                      height: 1.5,
                    ),
                  ),
                  if (post.attachments.isNotEmpty) ...[
                    SizedBox(height: 12),
                    _buildAttachmentGrid(post.attachments, post),
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

  Widget _buildAttachmentGrid(List<Attachment> attachments, ChatterPost post) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: attachments.length == 1 ? 1 : 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 4 / 3,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        final displayUrl = attachment.url ?? '';
        BorderRadius borderRadius;
        if (attachments.length == 1) {
          borderRadius = BorderRadius.circular(12);
        } else {
          if (attachments.length == 2) {
            borderRadius = index == 0
                ? BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  )
                : BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  );
          } else {
            if (index % 2 == 0) {
              borderRadius = index == 0
                  ? BorderRadius.only(topLeft: Radius.circular(12))
                  : index == attachments.length - 1 && attachments.length % 2 == 1
                      ? BorderRadius.only(bottomLeft: Radius.circular(12))
                      : BorderRadius.zero;
            } else {
              borderRadius = index == 1
                  ? BorderRadius.only(topRight: Radius.circular(12))
                  : index == attachments.length - 1
                      ? BorderRadius.only(bottomRight: Radius.circular(12))
                      : BorderRadius.zero;
            }
          }
        }
        return _buildAttachmentWidget(attachment, index, displayUrl, post, borderRadius);
      },
    );
  }

  Widget _buildAttachmentWidget(Attachment attachment, int idx, String displayUrl, ChatterPost post, BorderRadius borderRadius) {
    if (attachment.type == "video") {
      return VideoAttachmentWidget(
        key: Key('video_${attachment.url ?? idx}'),
        attachment: attachment,
        post: post,
        borderRadius: borderRadius,
        androidVersion: androidVersion,
        isLoadingAndroidVersion: isLoadingAndroidVersion,
      );
    } else if (attachment.type == "audio") {
      return AudioAttachmentWidget(
        key: Key('audio_${attachment.url ?? idx}'),
        attachment: attachment,
        post: post, // Add this
        borderRadius: borderRadius,
      );
    } else if (attachment.type == "image") {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: post.attachments,
                initialIndex: idx,
                message: post.content,
                userName: post.username,
                userAvatarUrl: post.useravatar,
                timestamp: post.timestamp,
                viewsCount: post.views,
                likesCount: post.likes,
                repostsCount: post.reposts,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: attachment.url != null
                ? CachedNetworkImage(
                    imageUrl: displayUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
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
                      ),
          ),
        ),
      );
    } else if (attachment.type == "pdf") {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: post.attachments,
                initialIndex: idx,
                message: post.content,
                userName: post.username,
                userAvatarUrl: post.useravatar,
                timestamp: post.timestamp,
                viewsCount: post.views,
                likesCount: post.likes,
                repostsCount: post.reposts,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PdfViewer.uri(
              Uri.parse(displayUrl),
              params: PdfViewerParams(
                margin: 0,
                maxScale: 1.0,
              ),
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: post.attachments,
                initialIndex: idx,
                message: post.content,
                userName: post.username,
                userAvatarUrl: post.useravatar,
                timestamp: post.timestamp,
                viewsCount: post.views,
                likesCount: post.likes,
                repostsCount: post.reposts,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              color: Colors.grey[900],
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    attachment.type == "audio" ? FeatherIcons.music : FeatherIcons.file,
                    color: Colors.tealAccent,
                    size: 20,
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    }
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
        // The leading hamburger icon to open the drawer will be automatically added
        // by Flutter when a drawer is present on the Scaffold.
        // No explicit leading button is needed here unless custom behavior is desired.
      ),
      drawer: const AppDrawer(), // <-- ADD THIS LINE
      body: Stack(
        children: [
          Obx(() {
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
                      thumbnailUrl: att['thumbnailUrl'] as String?,
                    );
                  }).toList() ?? [],
                  replies: (postMap['replies'] as List<dynamic>?)?.cast<String>() ?? [],
                );
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1, vertical: 5),
                  child: _buildPostContent(post, isReply: false),
                );
              },
            );
          }),
          if (_isFabMenuOpen)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isFabMenuOpen = false;
                });
              },
              child: Container(
                color: Colors.black.withOpacity(0.5), // Semi-transparent black
              ),
            ),
        ],
      ),
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomRight,
        children: [
          if (_isFabMenuOpen)
            Positioned(
              bottom: 205.0,
              right: 8.0,
              child: AnimatedOpacity(
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                duration: Duration(milliseconds: 200),
                child: FloatingActionButton.small(
                  heroTag: 'fab_add_post',
                  onPressed: _navigateToPostScreen,
                  backgroundColor: Colors.black,
                  child: Icon(FeatherIcons.plusCircle, color: Colors.tealAccent),
                  tooltip: 'Add Post',
                ),
              ),
            ),
          if (_isFabMenuOpen)
            Positioned(
              bottom: 140.0,
              right: 8.0,
              child: AnimatedOpacity(
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                duration: Duration(milliseconds: 200),
                child: FloatingActionButton.small(
                  heroTag: 'fab_home',
                  onPressed: () { setState(() { _isFabMenuOpen = false; }); },
                  backgroundColor: Colors.black,
                  child: Icon(FeatherIcons.home, color: Colors.tealAccent),
                  tooltip: 'Home',
                ),
              ),
            ),
          if (_isFabMenuOpen)
            Positioned(
              bottom: 75.0,
              right: 8.0,
              child: AnimatedOpacity(
                opacity: _isFabMenuOpen ? 1.0 : 0.0,
                duration: Duration(milliseconds: 200),
                child: FloatingActionButton.small(
                  heroTag: 'fab_search',
                  onPressed: () { setState(() { _isFabMenuOpen = false; }); Get.to(() => const SearchPage()); },
                  backgroundColor: Colors.black,
                  child: Icon(FeatherIcons.search, color: Colors.tealAccent),
                  tooltip: 'Search',
                ),
              ),
            ),
          FloatingActionButton(
            heroTag: 'fab_main',
            onPressed: () {
              setState(() {
                _isFabMenuOpen = !_isFabMenuOpen;
              });
            },
            backgroundColor: Colors.tealAccent,
            child: Icon(_isFabMenuOpen ? FeatherIcons.x : FeatherIcons.menu, color: Colors.black),
          ),
        ],
      )
    );
  }
}

class VideoAttachmentWidget extends StatefulWidget {
  final Attachment attachment;
  final ChatterPost post;
  final BorderRadius borderRadius;
  final int? androidVersion;
  final bool isLoadingAndroidVersion;

  const VideoAttachmentWidget({
    required Key key,
    required this.attachment,
    required this.post,
    required this.borderRadius,
    required this.androidVersion,
    required this.isLoadingAndroidVersion,
  }) : super(key: key);

  @override
  _VideoAttachmentWidgetState createState() => _VideoAttachmentWidgetState();
}

class _VideoAttachmentWidgetState extends State<VideoAttachmentWidget> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  BetterPlayerController? _betterPlayerController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  bool _isMuted = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    _pulseAnimationController.repeat(reverse: true);
  }

  void _initializeVideoPlayer() {
    if (widget.isLoadingAndroidVersion || widget.androidVersion == null) {
      return;
    }

    final optimizedUrl = widget.attachment.url!.replaceAll(
      '/upload/',
      '/upload/q_auto:good,w_1280,h_960,c_fill/',
    );

    if (Platform.isAndroid && widget.androidVersion! < 33) {
      // Use BetterPlayer for Android SDK < 33 (Android 13)
      _betterPlayerController = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: false,
          looping: true,
          fit: BoxFit.contain, // Ensure video fits within the aspect ratio
          aspectRatio: 4 / 3, // Explicitly set 4/3 aspect ratio
          controlsConfiguration: BetterPlayerControlsConfiguration(
            showControls: false, // Hide controls as requested
            enablePlayPause: true,
            enableMute: true,
            muteIcon: FeatherIcons.volumeX,
            unMuteIcon: FeatherIcons.volume2,
          ),
          handleLifecycle: false,
        ),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          optimizedUrl,
          videoFormat: BetterPlayerVideoFormat.other,
        ),
      )..addEventsListener((event) {
          if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
            setState(() {
              _isInitialized = true;
            });
            _betterPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
            widget.post.views++;
          } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
            print('BetterPlayer error: ${event.parameters}');
            setState(() {
              _isInitialized = false;
            });
          }
        });
    } else {
      // Use VideoPlayer for Android SDK >= 33 or non-Android platforms
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl))
        ..initialize().then((_) {
          setState(() {
            _isInitialized = true;
          });
          _videoPlayerController!.setVolume(_isMuted ? 0.0 : 1.0);
          _videoPlayerController!.setLooping(true);
          widget.post.views++;
        }).catchError((error) {
          print('VideoPlayer initialization error: $error');
          setState(() {
            _isInitialized = false;
          });
        });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _betterPlayerController?.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoadingAndroidVersion || widget.androidVersion == null) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            color: Colors.grey[900],
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.tealAccent,
              ),
            ),
          ),
        ),
      );
    }

    return VisibilityDetector(
      key: Key(widget.attachment.url ?? widget.key.toString()), // Ensure a stable, unique key
      onVisibilityChanged: (info) {
        if (!_isInitialized) return;
        bool useBetterPlayer = Platform.isAndroid && widget.androidVersion! < 33;

        if (useBetterPlayer) {
          if (_betterPlayerController != null && _betterPlayerController!.videoPlayerController != null && _betterPlayerController!.videoPlayerController!.value.initialized) {
            if (info.visibleFraction > 0.5 && !_betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.play();
            } else if (info.visibleFraction <= 0.5 && _betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.pause();
            }
          }
        } else {
          if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
            if (info.visibleFraction > 0.5 && !_videoPlayerController!.value.isPlaying) {
              _videoPlayerController!.play().catchError((error) {
                print('VideoPlayer playback error in VisibilityDetector: $error');
              });
            } else if (info.visibleFraction <= 0.5 && _videoPlayerController!.value.isPlaying) {
              _videoPlayerController!.pause();
            }
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: widget.post.attachments,
                initialIndex: widget.post.attachments.indexOf(widget.attachment),
                message: widget.post.content,
                userName: widget.post.username,
                userAvatarUrl: widget.post.useravatar,
                timestamp: widget.post.timestamp,
                viewsCount: widget.post.views,
                likesCount: widget.post.likes,
                repostsCount: widget.post.reposts,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Layer 1: Thumbnail
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: widget.attachment.thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container( // This container will pulse
                        color: Colors.grey[850], // Base color of the pulsing area
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: Icon(
                          FeatherIcons.image,
                          color: Colors.white.withOpacity(0.6),
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),

                // Layer 2: Video Player
                if (_isInitialized)
                  (Platform.isAndroid && widget.androidVersion! < 33)
                      ? (_betterPlayerController != null && _betterPlayerController!.videoPlayerController != null && _betterPlayerController!.videoPlayerController!.value.initialized
                          ? BetterPlayer(controller: _betterPlayerController!)
                          : SizedBox.shrink())
                      : (_videoPlayerController != null && _videoPlayerController!.value.isInitialized
                          ? VideoPlayer(_videoPlayerController!)
                          : SizedBox.shrink()),

                // Layer 3: Loading indicator for video (on top of thumbnail, when video is not yet initialized)
                if (!_isInitialized)
                  Center(
                    child: CircularProgressIndicator(
                      color: Colors.tealAccent,
                    ),
                  ),

                // Layer 4: Mute/Unmute button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        if (Platform.isAndroid && widget.androidVersion! < 33) {
                          _betterPlayerController?.setVolume(_isMuted ? 0.0 : 1.0);
                        } else {
                          _videoPlayerController?.setVolume(_isMuted ? 0.0 : 1.0);
                        }
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted ? FeatherIcons.volumeX : FeatherIcons.volume2,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AudioAttachmentWidget extends StatefulWidget {
  final Attachment attachment;
  final ChatterPost post; // Add this
  final BorderRadius borderRadius;

  const AudioAttachmentWidget({
    required Key key,
    required this.attachment,
    required this.post, // Add this
    required this.borderRadius,
  }) : super(key: key);

  @override
  _AudioAttachmentWidgetState createState() => _AudioAttachmentWidgetState();
}

class _AudioAttachmentWidgetState extends State<AudioAttachmentWidget> {
  late AudioPlayer _audioPlayer;
  bool _isMuted = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    final audioUrl = widget.attachment.url!.replaceAll(
      '/upload/',
      '/upload/f_mp3/',
    );
    _audioPlayer.setSourceUrl(audioUrl).catchError((error) {
      print('Audio initialization error: $error');
    });
    _audioPlayer.setVolume(0.0);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.attachment.url!),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5 && !_isPlaying) {
          _audioPlayer.resume();
          setState(() {
            _isPlaying = true;
          });
        } else if (info.visibleFraction <= 0.5 && _isPlaying) {
          _audioPlayer.pause();
          setState(() {
            _isPlaying = false;
          });
        }
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: widget.post.attachments,
                initialIndex: widget.post.attachments.indexOf(widget.attachment),
                message: widget.post.content,
                userName: widget.post.username,
                userAvatarUrl: widget.post.useravatar,
                timestamp: widget.post.timestamp,
                viewsCount: widget.post.views,
                likesCount: widget.post.likes,
                repostsCount: widget.post.reposts,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 200,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[900],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FeatherIcons.music,
                    color: Colors.tealAccent,
                    size: 20,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_isPlaying) {
                              _audioPlayer.pause();
                              _isPlaying = false;
                            } else {
                              _audioPlayer.resume();
                              _isPlaying = true;
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying ? FeatherIcons.pause : FeatherIcons.play,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isMuted ? FeatherIcons.volumeX : FeatherIcons.volume2,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}