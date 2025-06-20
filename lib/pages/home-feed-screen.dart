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
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
// import 'package:chatter/models/feed_models.dart'; Removed import
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  DataController dataController = Get.put(DataController());
  int? androidVersion;
  bool isLoadingAndroidVersion = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAndroidVersion();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          androidVersion = 33;
          isLoadingAndroidVersion = false;
        });
      }
    }
  }

  void _navigateToPostScreen() async {
    final result = await Get.bottomSheet<Map<String, dynamic>>(
      Container(
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E), // Dark grey background color
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: NewPostScreen(),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Important to keep this transparent
    );

    if (result != null && result is Map<String, dynamic>) {
      final String content = result['content'] as String? ?? '';
      final List<Map<String, dynamic>> attachments = (result['attachments'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? <Map<String, dynamic>>[];

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
    print('[HomeFeedScreen _addPost] Received ${attachments.length} attachments.');
    for (int i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      try {
        print('[HomeFeedScreen _addPost] Attachment ${i+1}: type=${a['type']}, path=${(a['file'] as File?)?.path}, file_exists_sync=${(a['file'] as File?)?.existsSync()}, length_sync=${(a['file'] as File?)?.lengthSync()}, filename=${a['filename']}, size=${a['size']}, url=${a['url']}');
      } catch (e) {
        print('[HomeFeedScreen _addPost] Attachment ${i+1}: type=${a['type']}, path=${(a['file'] as File?)?.path}, url=${a['url']} - Error getting file stats: $e');
      }
    }

    List<Map<String, dynamic>> uploadedAttachments = [];
    if (attachments.isNotEmpty) {
      List<File> files = attachments.where((a) => a['file'] != null).map((a) => a['file']! as File).toList();
      print('[HomeFeedScreen _addPost] Extracted ${files.length} files for upload:');
      for (int i = 0; i < files.length; i++) {
        final f = files[i];
        try {
          print('[HomeFeedScreen _addPost] File ${i+1} for upload: path=${f.path}, exists_sync=${f.existsSync()}, length_sync=${f.lengthSync()}');
        } catch (e) {
          print('[HomeFeedScreen _addPost] File ${i+1} for upload: path=${f.path} - Error getting file stats: $e');
        }
      }
      List<Map<String, dynamic>> uploadResults = await dataController.uploadFiles(files);

      for (int i = 0; i < attachments.length; i++) {
        var result = uploadResults[i]; // Assuming uploadResults corresponds to the order of files derived from attachments
        final originalAttachment = attachments.firstWhere((att) => (att['file'] as File?)?.path == result['filePath'], orElse: () => attachments[i]);

        print(result);
        if (result['success'] == true) {
          String originalUrl = result['url'] as String;
          // Use the thumbnailUrl directly from the upload result
          String? thumbnailUrl = result['thumbnailUrl'] as String?;
          uploadedAttachments.add({
            'file': originalAttachment['file'], // Keep the original file object if needed, or null
            'type': originalAttachment['type'],
            'filename': (originalAttachment['file'] as File?)?.path.split('/').last ?? result['filename'] ?? 'unknown',
            'size': result['size'] ?? ((originalAttachment['file'] as File?) != null ? await (originalAttachment['file'] as File)!.length() : 0),
            'url': originalUrl,
            'thumbnailUrl': thumbnailUrl, // Assign the new thumbnailUrl here
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload ${(originalAttachment['file'] as File?)?.path.split('/').last}: ${result['message']}',
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
        'attachments': (newReply['attachments'] as List<Map<String, dynamic>>?)?.map((att) => {
          'filename': (att['file'] as File?)?.path.split('/').last ?? att['filename'] ?? 'unknown',
          'url': att['url'],
          'size': (att['file'] as File?) != null ? (att['file'] as File).lengthSync() : att['size'] ?? 0,
          'type': att['type'],
          'thumbnailUrl': att['thumbnailUrl'],
        }).toList() ?? [],
      };

      // Assuming replyToPost is the correct method in DataController for replies
      // And it expects postId, content, and attachments.
      // The original post's ID is needed here.
      final postId = post['_id'] as String?;
      if (postId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Original post ID is missing.', style: GoogleFonts.roboto(color: Colors.white)),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      final result = await dataController.replyToPost(
        postId: postId,
        content: replyData['content'] as String,
        attachments: replyData['attachments'] as List<Map<String, dynamic>>,
      );

      if (result['success'] == true) {
        // Optionally, update the local post's reply count or add reply to a local list
        // This depends on how you want the UI to reflect the new reply immediately
        final postIndex = dataController.posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          final postMap = dataController.posts[postIndex];
          // Assuming the backend returns the new reply details and you want to add it
          // or simply increment a counter. For simplicity, let's assume a counter.
          // If 'replies' is a list of reply objects:
          // List<dynamic> repliesList = List.from(postMap['replies'] ?? []);
          // repliesList.add(result['reply']); // Assuming 'reply' contains the new reply data
          // postMap['replies'] = repliesList;

          // If 'replies' is just a count or you're managing it as a count in the UI:
          postMap['replyCount'] = (postMap['replyCount'] ?? 0) + 1; // Example if it's a count
          // Or if 'replies' is a list of IDs or full objects:
          // (postMap['replies'] as List<dynamic>).add(result['reply']['_id']); // If adding ID

          dataController.posts[postIndex] = postMap;
          dataController.posts.refresh();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply added!', style: GoogleFonts.roboto(color: Colors.white)),
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

  Widget _buildPostContent(Map<String, dynamic> post, {required bool isReply}) {
    final String username = post['username'] as String? ?? 'Unknown User';
    final String content = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    // Ensure 'username' is not null and not empty before accessing its first character.
    final String avatarInitial = (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = post['createdAt'] is String ? DateTime.parse(post['createdAt'] as String) : DateTime.now();
    int likes = post['likes'] as int? ?? 0;
    int reposts = post['reposts'] as int? ?? 0;
    int views = post['views'] as int? ?? 0;
    List<Map<String, dynamic>> attachments = (post['attachments'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    // Assuming 'replies' is a list of reply objects/IDs, its length is the count.
    // If your backend sends a specific count field like 'replyCount', use that instead.
    int replyCount = (post['replies'] as List<dynamic>?)?.length ?? post['replyCount'] as int? ?? 0;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 16 : 20,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                  ? NetworkImage(userAvatar)
                  : null,
              child: userAvatar == null || userAvatar.isEmpty
                  ? Text(
                      avatarInitial,
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
                      Flexible(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              username,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: isReply ? 14 : 16,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(width: 4.0),
                            Icon(
                              Icons.verified,
                              color: Colors.amber,
                              size: isReply ? 13 : 15,
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              ' · @$username',
                              style: GoogleFonts.poppins(
                                fontSize: isReply ? 10 : 12,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a · MMM d').format(timestamp),
                        style: GoogleFonts.roboto(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    content,
                    style: GoogleFonts.roboto(
                      fontSize: isReply ? 13 : 14,
                      color: const Color.fromARGB(255, 255, 255, 255),
                      height: 1.5,
                    ),
                  ),
                  if (attachments.isNotEmpty) ...[
                    SizedBox(height: 12),
                    _buildAttachmentGrid(attachments, post),
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
                              // Optimistically update UI and call backend
                              setState(() {
                                post['likes'] = (post['likes'] as int? ?? 0) + 1; // Use 'likes' here
                                // Add logic to reflect if the user has liked this post
                              });
                              // Example: dataController.likePost(post['_id']);
                            },
                          ),
                          Text(
                            '$likes',
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
                            '$replyCount', // Use the calculated replyCount
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
                            '$reposts',
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
                            onPressed: () {
                               // Optionally, increment views or handle view logic
                            },
                          ),
                          Text(
                            '$views',
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

  Widget _buildAttachmentGrid(List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post) {
    // Use attachmentsArg to avoid confusion with post['attachments']
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: attachmentsArg.length == 1 ? 1 : 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 4 / 3,
      ),
      itemCount: attachmentsArg.length,
      itemBuilder: (context, index) {
        final attachmentMap = attachmentsArg[index]; // Use attachmentMap for clarity
        final displayUrl = attachmentMap['url'] as String? ?? '';
        BorderRadius borderRadius;
        if (attachmentsArg.length == 1) {
          borderRadius = BorderRadius.circular(12);
        } else {
          if (attachmentsArg.length == 2) {
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
            if (index == 0) borderRadius = BorderRadius.only(topLeft: Radius.circular(12));
            else if (index == 1) borderRadius = BorderRadius.only(topRight: Radius.circular(12));
            else if (index == attachmentsArg.length - 2 && attachmentsArg.length % 2 == 0) borderRadius = BorderRadius.only(bottomLeft: Radius.circular(12));
            else if (index == attachmentsArg.length -1) {
                if (attachmentsArg.length % 2 == 1 && index == attachmentsArg.length -1) {
                    borderRadius = BorderRadius.only(bottomLeft: Radius.circular(12));
                } else {
                    borderRadius = BorderRadius.only(bottomRight: Radius.circular(12));
                }
            }
            else borderRadius = BorderRadius.zero;
          }
        }
        // Pass attachmentMap instead of individual fields where _buildAttachmentWidget expects a map
        return _buildAttachmentWidget(attachmentMap, index, post, borderRadius);
      },
    );
  }

  Widget _buildAttachmentWidget(Map<String, dynamic> attachmentMap, int idx, Map<String, dynamic> post, BorderRadius borderRadius) {
    final String attachmentType = attachmentMap['type'] as String? ?? 'unknown';
    final String? displayUrl = attachmentMap['url'] as String?; // Get URL from attachmentMap
    final List<Map<String, dynamic>> postAttachments = (post['attachments'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

    if (attachmentType == "video") {
      return VideoAttachmentWidget(
        key: Key('video_${attachmentMap['url'] ?? idx}'),
        attachment: attachmentMap, // Pass the map directly
        post: post,
        borderRadius: borderRadius,
        androidVersion: androidVersion,
        isLoadingAndroidVersion: isLoadingAndroidVersion,
      );
    } else if (attachmentType == "audio") {
      return AudioAttachmentWidget(
        key: Key('audio_${attachmentMap['url'] ?? idx}'),
        attachment: attachmentMap, // Pass the map directly
        post: post,
        borderRadius: borderRadius,
      );
    } else if (attachmentType == "image") {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: postAttachments,
                initialIndex: idx,
                message: post['content'] as String? ?? '',
                userName: post['username'] as String? ?? 'Unknown User',
                userAvatarUrl: post['useravatar'] as String?,
                timestamp: post['createdAt'] is String ? DateTime.parse(post['createdAt'] as String) : DateTime.now(),
                viewsCount: post['views'] as int? ?? 0, // Use 'views'
                likesCount: post['likes'] as int? ?? 0, // Use 'likes'
                repostsCount: post['reposts'] as int? ?? 0, // Use 'reposts'
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: displayUrl != null && displayUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: displayUrl, // Use the local displayUrl
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
                : (attachmentMap['file'] as File?) != null // Check for local file from attachmentMap
                    ? Image.file(
                        attachmentMap['file'] as File,
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
                    : Container( // Fallback for no URL and no file
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
    } else if (attachmentType == "pdf") {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: postAttachments,
                initialIndex: idx,
                message: post['content'] as String? ?? '',
                userName: post['username'] as String? ?? 'Unknown User',
                userAvatarUrl: post['useravatar'] as String?,
                timestamp: post['createdAt'] is String ? DateTime.parse(post['createdAt'] as String) : DateTime.now(),
                viewsCount: post['views'] as int? ?? 0, // Use 'views'
                likesCount: post['likes'] as int? ?? 0, // Use 'likes'
                repostsCount: post['reposts'] as int? ?? 0, // Use 'reposts'
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: displayUrl != null && displayUrl.isNotEmpty
                ? PdfViewer.uri(
                    Uri.parse(displayUrl), // Use the local displayUrl
                    params: PdfViewerParams(
                      margin: 0,
                      maxScale: 1.0, // Adjust as needed
                    ),
                  )
                : Container( // Fallback if URL is null
                    color: Colors.grey[900],
                    child: Icon(FeatherIcons.fileText, color: Colors.grey[500], size: 40),
                  ),
          ),
        ),
      );
    } else { // Fallback for other/unknown types
      return GestureDetector(
        onTap: () {
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaViewPage(
                attachments: postAttachments,
                initialIndex: idx,
                message: post['content'] as String? ?? '',
                userName: post['username'] as String? ?? 'Unknown User',
                userAvatarUrl: post['useravatar'] as String?,
                timestamp: post['createdAt'] is String ? DateTime.parse(post['createdAt'] as String) : DateTime.now(),
                viewsCount: post['views'] as int? ?? 0, // Use 'views'
                likesCount: post['likes'] as int? ?? 0, // Use 'likes'
                repostsCount: post['reposts'] as int? ?? 0, // Use 'reposts'
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
                    attachmentType == "audio" ? FeatherIcons.music : FeatherIcons.file,
                    color: Colors.tealAccent,
                    size: 20, // Reduced size
                  ),
                  SizedBox(height: 8),
                  // Optionally display filename if available
                  // Text(attachment['filename'] ?? 'File', style: TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
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
      ),
      drawer: const AppDrawer(),
      body: Obx(() {
        if (dataController.posts.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
            ),
          );
        }
        return ListView.separated(
          controller: _scrollController,
          itemCount: dataController.posts.length,
          separatorBuilder: (context, index) => Divider(
            color: Colors.grey[850],
            height: 1,
          ),
          itemBuilder: (context, index) {
            final postMap = dataController.posts[index] as Map<String, dynamic>; // Ensure it's a Map
            // Directly use postMap, no need to instantiate ChatterPost or Attachment
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 1, vertical: 5),
              child: _buildPostContent(postMap, isReply: false), // Pass postMap directly
            );
          },
        );
      }),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        key: GlobalKey<ExpandableFabState>(),
        distance: 65.0,
        type: ExpandableFabType.up,
        overlayStyle: ExpandableFabOverlayStyle(
          color: Colors.black.withOpacity(0.5),
        ),
        openButtonBuilder: RotateFloatingActionButtonBuilder(
          backgroundColor: Colors.tealAccent,
          foregroundColor: Colors.black,
          child: Icon(FeatherIcons.menu),
        ),
        closeButtonBuilder: RotateFloatingActionButtonBuilder(
          backgroundColor: Colors.tealAccent,
          foregroundColor: Colors.black,
          child: Icon(FeatherIcons.x),
        ),
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_add_post',
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(side: BorderSide(color: Colors.tealAccent, width: 1), borderRadius: BorderRadius.circular(10)),
            onPressed: _navigateToPostScreen,
            tooltip: 'Add Post',
            child: Icon(FeatherIcons.plusCircle, color: Colors.tealAccent),
          ),
          FloatingActionButton.small(
            heroTag: 'fab_home',
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(side: BorderSide(color: Colors.tealAccent, width: 1), borderRadius: BorderRadius.circular(10)),
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              dataController.fetchFeeds();
            },
            tooltip: 'Home',
            child: Icon(FeatherIcons.home, color: Colors.tealAccent),
          ),
          FloatingActionButton.small(
            heroTag: 'fab_search',
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(side: BorderSide(color: Colors.tealAccent, width: 1), borderRadius: BorderRadius.circular(10)),
            onPressed: () {
              Get.to(() => const SearchPage(), transition: Transition.rightToLeft);
            },
            tooltip: 'Search',
            child: Icon(FeatherIcons.search, color: Colors.tealAccent),
          ),
        ],
      ),
    );
  }
}