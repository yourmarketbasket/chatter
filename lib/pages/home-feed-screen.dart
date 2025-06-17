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

  @override
  void initState() {
    super.initState();
    _loadAndroidVersion();
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
      'username': "YourName",
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
                  thumbnailUrl: att['thumbnailUrl'] as String?,
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
        backgroundColor: const Color(0xFF000000),
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.roboto(),
        elevation: 0,
        iconSize: 22, // Reduced icon size (was 24)
        type: BottomNavigationBarType.fixed, // Good practice for 2-3 items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.home), // size is now controlled by iconSize above
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.search), // size is now controlled by iconSize above
            label: 'Search',
          ),
        ],
        currentIndex: 0, // Set to 0 as this is the HomeFeedScreen
        onTap: (index) {
          if (index == 0) {
            // Already on Home, or navigate to Home if somehow accessed from a different context
            // This primarily handles the visual selection of the tab.
            // If HomeFeedScreen is part of a larger navigation stack (e.g. if other pages push on top of it),
            // ensure Get.offAll or similar is used when appropriate from other pages to return "home".
            // For now, if we are on HomeFeedScreen, tapping "Home" does nothing new.
          } else if (index == 1) {
            // Navigate to SearchPage
            Get.to(() => const SearchPage());
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

class _VideoAttachmentWidgetState extends State<VideoAttachmentWidget> {
  VideoPlayerController? _videoPlayerController;
  BetterPlayerController? _betterPlayerController;
  bool _isMuted = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoadingAndroidVersion || widget.androidVersion == null) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          color: Colors.grey[900],
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.tealAccent,
            ),
          ),
        ),
      );
    }

    return VisibilityDetector(
      key: Key(widget.attachment.url!),
      onVisibilityChanged: (info) {
        if (!_isInitialized) return;
        if (Platform.isAndroid && widget.androidVersion! < 33) {
          if (_betterPlayerController != null) {
            if (info.visibleFraction > 0.5 && !_betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.play();
            } else if (info.visibleFraction <= 0.5 && _betterPlayerController!.isPlaying()!) {
              _betterPlayerController!.pause();
            }
          }
        } else {
          if (_videoPlayerController != null) {
            if (info.visibleFraction > 0.5 && !_videoPlayerController!.value.isPlaying) {
              _videoPlayerController!.play().catchError((error) {
                print('Video playback error: $error');
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
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[800]!, width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3, // Enforce 4/3 aspect ratio for the container
                  child: _isInitialized
                      ? (Platform.isAndroid && widget.androidVersion! < 33
                          ? BetterPlayer(controller: _betterPlayerController!)
                          : VideoPlayer(_videoPlayerController!))
                      : CachedNetworkImage(
                          imageUrl: widget.attachment.thumbnailUrl ?? '',
                          fit: BoxFit.cover, // Ensure thumbnail respects 4/3
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: Icon(
                                FeatherIcons.play,
                                color: Colors.white.withOpacity(0.8),
                                size: 48,
                              ),
                            ),
                          ),
                          placeholder: (context, url) => Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.tealAccent,
                              ),
                            ),
                          ),
                        ),
                ),
                if (!_isInitialized)
                  Center(
                    child: Icon(
                      FeatherIcons.play,
                      color: Colors.white.withOpacity(0.8),
                      size: 48,
                    ),
                  ),
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
                        border: Border.all(color: Colors.grey[400]!, width: 1),
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
                border: Border.all(color: Colors.grey[800]!, width: 1),
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
                            border: Border.all(color: Colors.grey[400]!, width: 1),
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
                            border: Border.all(color: Colors.grey[400]!, width: 1),
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