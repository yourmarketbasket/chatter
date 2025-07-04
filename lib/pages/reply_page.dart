import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ReplyPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const ReplyPage({Key? key, required this.post}) : super(key: key);

  @override
  _ReplyPageState createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  final TextEditingController _replyController = TextEditingController();
  final List<Map<String, dynamic>> _replyAttachments = [];
  late DataController _dataController;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // State variable for the main post to allow modifications (likes, etc.)
  late Map<String, dynamic> _mainPostData;

  List<Map<String, dynamic>> _replies = [];
  bool _isLoadingReplies = true;
  String? _fetchRepliesError;
  bool _isSubmittingReply = false;
  bool _showReplyField = false; // Default to false to hide reply field initially
  String? _parentReplyId;
  final FocusNode _replyFocusNode = FocusNode(); // For focusing the reply text field

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
    // Initialize _mainPostData with a deep copy of widget.post
    _mainPostData = Map<String, dynamic>.from(widget.post);
    // Ensure nested lists like 'likes' or 'reposts' are also copied if they exist, to avoid modifying the original widget.post's lists.
    // For simplicity, we'll assume top-level copy is enough for now, but deep copy is safer.
    // A more robust deep copy: _mainPostData = jsonDecode(jsonEncode(widget.post));
    // However, jsonEncode/Decode won't work if widget.post contains non-JSON serializable types (like File objects if any were there).
    // For this app's structure, Map.from should be okay for fields like 'likes', 'reposts' if they are lists of strings/basic types.
    // Let's ensure 'likes' and 'reposts' are new lists if they exist.
    if (_mainPostData['likes'] != null && _mainPostData['likes'] is List) {
      _mainPostData['likes'] = List<dynamic>.from(_mainPostData['likes'] as List);
    }
    if (_mainPostData['reposts'] != null && _mainPostData['reposts'] is List) {
      _mainPostData['reposts'] = List<dynamic>.from(_mainPostData['reposts'] as List);
    }


    _fetchPostReplies();

    if (_mainPostData['_id'] != null) {
      _dataController.viewPost(_mainPostData['_id'] as String);
    } else {
      print("Error: Post ID is null in ReplyPage. Cannot record view.");
    }
  }

  Future<void> _fetchPostReplies({bool showLoadingIndicator = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoadingIndicator) _isLoadingReplies = true;
      _fetchRepliesError = null;
    });

    try {
      final postId = widget.post['_id'] as String?;
      if (postId == null) {
        print("Error: Post ID is null in _fetchPostReplies. Cannot fetch replies.");
        if (mounted) {
          setState(() {
            _fetchRepliesError = 'Cannot load replies: Original post ID is missing.';
            _isLoadingReplies = false;
          });
        }
        return;
      }
      final fetchedReplies = await _dataController.fetchReplies(postId);
      if (mounted) {
        setState(() {
          _replies = fetchedReplies;
          if (showLoadingIndicator) _isLoadingReplies = false;
        });
      }
    } catch (e) {
      print('Error fetching replies: $e');
      if (mounted) {
        setState(() {
          _fetchRepliesError = 'Failed to load replies. Please try again.';
          if (showLoadingIndicator) _isLoadingReplies = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<File?> _downloadFile(String url, String filename, String type) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        String extension;
        switch (type) {
          case 'image':
            extension = path.extension(url).isNotEmpty ? path.extension(url) : '.jpg';
            break;
          case 'video':
            extension = path.extension(url).isNotEmpty ? path.extension(url) : '.mp4';
            break;
          case 'pdf':
            extension = '.pdf';
            break;
          case 'audio':
            extension = path.extension(url).isNotEmpty ? path.extension(url) : '.mp3';
            break;
          default:
            extension = path.extension(url).isNotEmpty ? path.extension(url) : '.bin';
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

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final String content = post['content'] as String? ?? "";
    final List<String> filePaths = [];
    List<Map<String, dynamic>> attachments = [];

    final dynamic rawAttachments = post['attachments'];
    if (rawAttachments is List && rawAttachments.isNotEmpty) {
      attachments = rawAttachments
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(
              item.map((key, value) => MapEntry(key.toString(), value))))
          .toList();
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
        file = await _downloadFile(
          url ?? '',
          filename ?? 'attachment_${DateTime.now().millisecondsSinceEpoch}',
          type ?? 'unknown',
        );
        if (file != null) {
          filePaths.add(file.path);
        } else {
          _showSnackBar('Error', 'Failed to download $type: $filename', Colors.red[700]!);
        }
      }
    }

    if (filePaths.isNotEmpty) {
      final xFiles = filePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(
        xFiles,
        text: content.isNotEmpty ? content : null,
        subject: 'Shared from Chatter',
      );
    } else {
      await Share.share(
        content.isNotEmpty ? content : 'Check out this post from Chatter!',
        subject: 'Shared from Chatter',
      );
    }
  }

  Future<int?> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.version.sdkInt;
      } catch (e) {
        print('Error getting Android SDK version: $e');
        return null;
      }
    }
    return null;
  }

  Future<bool> _requestMediaPermissions(String action) async {
    if (!Platform.isAndroid) return true;
    final int? sdkInt = await _getAndroidSdkVersion();
    if (sdkInt == null) {
      _showSnackBar('Error', 'Unable to determine Android version. Check permissions in settings.', Colors.red[700]!);
      return false;
    }
    Permission? permission;
    String permissionName = '';
    switch (action) {
      case 'image':
        permission = sdkInt >= 33 ? Permission.photos : Permission.storage;
        permissionName = 'Photos';
        break;
      case 'video':
        permission = sdkInt >= 33 ? Permission.videos : Permission.storage;
        permissionName = 'Videos';
        break;
      case 'audio':
        permission = sdkInt >= 33 ? Permission.audio : Permission.storage;
        permissionName = 'Audio';
        break;
      case 'pdf':
        permission = sdkInt < 33 ? Permission.storage : null;
        permissionName = 'Storage';
        break;
      default:
        return false;
    }
    if (action == 'pdf' && sdkInt >= 33) return true;
    if (permission == null) return false;
    final status = await permission.request();
    if (status.isGranted) return true;
    _showSnackBar('$permissionName Permission Required',
        status.isPermanentlyDenied
            ? 'Please enable $permissionName permission in app settings.'
            : 'Please grant $permissionName permission to continue.',
        Colors.red[700]!);
    return false;
  }

  void _showSnackBar(String title, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$title: $message',
            style: GoogleFonts.roboto(color: Colors.white)),
        backgroundColor: backgroundColor));
  }

  void _showActionsBottomSheet() {
    final String postUsername = widget.post['username'] as String? ?? 'User';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(FeatherIcons.userX,
                    color: Colors.tealAccent, size: 24),
                title: Text('Block @$postUsername',
                    style: GoogleFonts.roboto(
                        color: Colors.white, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  print('Block @$postUsername');
                  _showSnackBar('Block User',
                      'Block @$postUsername (not implemented yet).',
                      Colors.orange);
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.alertTriangle,
                    color: Colors.tealAccent, size: 24),
                title: Text('Report Post',
                    style: GoogleFonts.roboto(
                        color: Colors.white, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  print('Report post by @$postUsername');
                  _showSnackBar('Report Post',
                      'Report post by @$postUsername (not implemented yet).',
                      Colors.orange);
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.link,
                    color: Colors.tealAccent, size: 24),
                title: Text('Copy link to post',
                    style: GoogleFonts.roboto(
                        color: Colors.white, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  final String postId =
                      widget.post['_id'] as String? ?? "unknown_post_id";
                  final String postLink =
                      "https://chatter.yourdomain.com/post/$postId";
                  Clipboard.setData(ClipboardData(text: postLink)).then((_) {
                    _showSnackBar('Link Copied', 'Post link copied to clipboard!',
                        Colors.green[700]!);
                  }).catchError((error) {
                    _showSnackBar('Error', 'Could not copy link: $error',
                        Colors.red[700]!);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

 Widget _buildPostContent(Map<String, dynamic> post, {required bool isReply, int indentLevel = 0}) {
  final String username = post['username'] as String? ?? 'Unknown User';
  final String content = post['content'] as String? ?? '';
  final String? userAvatar = post['useravatar'] as String?;
  final String avatarInitial = post['avatarInitial'] as String? ?? (username.isNotEmpty ? username[0].toUpperCase() : '?');
  final DateTime timestamp = post['createdAt'] is String
      ? (DateTime.tryParse(post['createdAt'] as String) ?? DateTime.now())
      : (post['createdAt'] is DateTime ? post['createdAt'] as DateTime : DateTime.now());

  // Safely handle attachments
  List<Map<String, dynamic>> correctlyTypedAttachments = [];
  final dynamic rawAttachments = post['attachments'];
  if (rawAttachments is List && rawAttachments.isNotEmpty) {
    for (final item in rawAttachments) {
      if (item is Map<String, dynamic>) {
        correctlyTypedAttachments.add(item);
      } else if (item is Map) {
        try {
          correctlyTypedAttachments.add(Map<String, dynamic>.from(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ));
        } catch (e) {
          print('Error converting attachment Map to Map<String, dynamic>: $e. Attachment: $item');
        }
      } else {
        print('Skipping invalid attachment item: $item');
      }
    }
  }

  // Safely handle stats
  final int likesCount = post['likesCount'] as int? ?? (post['likes'] is List ? (post['likes'] as List).length : 0);
  final int repostsCount = post['repostsCount'] as int? ?? (post['reposts'] is List ? (post['reposts'] as List).length : 0);
  final int viewsCount = post['viewsCount'] as int? ?? (post['views'] is List ? (post['views'] as List).length : 0);
  final int repliesCount = post['repliesCount'] as int? ?? (post['replies'] is List ? (post['replies'] as List).length : 0);

  final EdgeInsets postItemPadding = isReply
      ? EdgeInsets.only(left: 16.0 * indentLevel + 4.0, right: 4.0)
      : const EdgeInsets.only(right: 4.0);

  return Padding(
    padding: postItemPadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 14 : 18,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
              child: userAvatar == null || userAvatar.isEmpty
                  ? Text(
                      avatarInitial,
                      style: GoogleFonts.poppins(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: isReply ? 12 : 14,
                      ),
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
                      Text(
                        '@$username',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isReply ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('h:mm a · MMM d, yyyy').format(timestamp),
                        style: GoogleFonts.roboto(
                          fontSize: isReply ? 11 : 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: GoogleFonts.roboto(
                      fontSize: isReply ? 13 : 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (correctlyTypedAttachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildReplyAttachmentGrid(
                      correctlyTypedAttachments,
                      post,
                      username,
                      userAvatar,
                      timestamp,
                      viewsCount,
                      likesCount,
                      repostsCount,
                      content,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatButton(
                        icon: FeatherIcons.heart,
                        text: '$likesCount',
                        color: Colors.pinkAccent,
                        onPressed: () {
                          _showSnackBar(
                            'Like ${isReply ? "Reply" : "Post"}',
                            'Like ${isReply ? "reply" : "post"} by @$username (not implemented yet).',
                            Colors.pinkAccent,
                          );
                        },
                      ),
                      _buildStatButton(
                        icon: FeatherIcons.repeat,
                        text: '$repostsCount',
                        color: Colors.greenAccent,
                        onPressed: () {
                          _showSnackBar(
                            'Repost ${isReply ? "Reply" : "Post"}',
                            'Repost ${isReply ? "reply" : "post"} by @$username (not implemented yet).',
                            Colors.greenAccent,
                          );
                        },
                      ),
                      _buildStatButton(
                        icon: FeatherIcons.messageCircle,
                        text: '$repliesCount',
                        color: Colors.tealAccent,
                        onPressed: () {
                          setState(() {
                            _parentReplyId = post['_id'] as String?;
                            _showReplyField = true;
                          });
                          _showSnackBar(
                            'Reply',
                            'Replying to @$username.',
                            Colors.teal[700]!,
                          );
                        },
                      ),
                      _buildStatButton(
                        icon: FeatherIcons.eye,
                        text: '$viewsCount',
                        color: Colors.blueAccent,
                        onPressed: () {
                          _showSnackBar(
                            'View ${isReply ? "Reply" : "Post"}',
                            'View ${isReply ? "reply" : "post"} by @$username (not implemented yet).',
                            Colors.blueAccent,
                          );
                        },
                      ),
                      _buildStatButton(
                        icon: FeatherIcons.share2,
                        text: '',
                        color: Colors.white70,
                        onPressed: () => _sharePost(post),
                      ),
                      if (!isReply) ...[
                        _buildStatButton(
                          icon: FeatherIcons.bookmark,
                          text: '',
                          color: Colors.white70,
                          onPressed: () {
                            _showSnackBar(
                              'Bookmark Post',
                              'Bookmark post by @$username (not implemented yet).',
                              Colors.teal[700]!,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  // Refactored widget to display posts in a Twitter-like style.
  // Can be used for the main post and for replies.
  Widget _buildTweetStylePostItem(Map<String, dynamic> post, {required bool isMainPost}) {
    final String username = post['username'] as String? ?? 'Unknown User';
    final String? userAvatar = post['useravatar'] as String?;
    final String avatarInitial = post['avatarInitial'] as String? ?? (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final String content = post['content'] as String? ?? '';
    final DateTime timestamp = post['createdAt'] is String
        ? (DateTime.tryParse(post['createdAt'] as String) ?? DateTime.now())
        : (post['createdAt'] is DateTime ? post['createdAt'] as DateTime : DateTime.now());

    // Determine if this reply is the last one in the list for line drawing
    // This is a placeholder, actual check needs to be passed or determined from context
    final bool isLastReplyInList = post['isLastReplyInList'] ?? false;


    List<Map<String, dynamic>> attachments = [];
    final dynamic rawAttachments = post['attachments'];
    if (rawAttachments is List && rawAttachments.isNotEmpty) {
      attachments = rawAttachments
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item.map((key, value) => MapEntry(key.toString(), value))))
          .toList();
    }

    final int likesCount = post['likesCount'] as int? ?? (post['likes'] is List ? (post['likes'] as List).length : 0);
    final int repostsCount = post['repostsCount'] as int? ?? (post['reposts'] is List ? (post['reposts'] as List).length : 0);
    final int viewsCount = post['viewsCount'] as int? ?? (post['views'] is List ? (post['views'] as List).length : 0);
    // final int repliesCount = post['repliesCount'] as int? ?? (post['replies'] is List ? (post['replies'] as List).length : 0);


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar, Username, More Options icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                child: userAvatar == null || userAvatar.isEmpty
                    ? Text(
                        avatarInitial,
                        style: GoogleFonts.poppins(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username, // Display name
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@$username', // Handle
                      style: GoogleFonts.roboto(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              // IconButton( // This was for the individual post more options, AppBar has one now
              //   icon: Icon(FeatherIcons.moreHorizontal, color: Colors.grey[500], size: 20),
              //   onPressed: () { /* TODO: Implement post specific actions if needed */ },
              // ),
            ],
          ),
          const SizedBox(height: 12),

          // Post Content
          if (content.isNotEmpty)
            Text(
              content,
              style: GoogleFonts.roboto(
                fontSize: 16, // Made text slightly larger for main post
                color: Colors.white,
                height: 1.4,
              ),
            ),

          // Attachments
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildReplyAttachmentGrid( // Re-using existing attachment grid, might need styling adjustments
              attachments,
              post,
              username,
              userAvatar,
              timestamp,
              viewsCount,
              likesCount,
              repostsCount,
              content,
            ),
          ],
          const SizedBox(height: 12),

          // Timestamp
          Text(
            DateFormat('h:mm a · MMM d, yyyy').format(timestamp) + ' · $viewsCount Views', // Added views here
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF2F3336), height: 1),
          const SizedBox(height: 8),

          // Engagement Stats (e.g., Reposts, Likes)
          Row(
            children: [
              if (repostsCount > 0) ...[
                Text(
                  '$repostsCount',
                  style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  'Reposts',
                  style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(width: 16),
              ],
              if (likesCount > 0) ...[
                 Text(
                  '$likesCount',
                  style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  'Likes',
                  style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
                ),
              ]
              // Add Quotes and Bookmarks if available
            ],
          ),
          if (repostsCount > 0 || likesCount > 0) ... [
            const SizedBox(height: 8),
            const Divider(color: Color(0xFF2F3336), height: 1),
            const SizedBox(height: 4),
          ],


          // Action Buttons (Reply, Repost, Like, Share)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // Space them out like Twitter
            children: [
              _buildStatButton( // Re-using _buildStatButton, might need icon/style adjustments
                icon: FeatherIcons.messageCircle, // Reply
                text: '', // No text for icon-only buttons in this style
                color: Colors.grey[500]!,
                onPressed: () {
                  // TODO: Implement reply action - focus input field
                  _showSnackBar('Reply', 'Reply action triggered (main post).', Colors.teal[700]!);
                },
              ),
              _buildStatButton(
                icon: FeatherIcons.repeat, // Repost
                text: '',
                color: Colors.grey[500]!,
                onPressed: () {
                  // TODO: Implement repost action
                   _showSnackBar('Repost', 'Repost action triggered (main post).', Colors.greenAccent);
                },
              ),
              _buildStatButton(
                icon: FeatherIcons.heart, // Like
                text: '',
                color: Colors.grey[500]!, // Default, change if liked
                onPressed: () {
                  // TODO: Implement like action
                  _showSnackBar('Like', 'Like action triggered (main post).', Colors.pinkAccent);
                },
              ),
               _buildStatButton( // X uses a bookmark icon here sometimes, or views icon
                icon: FeatherIcons.bookmark, // Bookmark as a placeholder for "Views" or other action
                text: '',
                color: Colors.grey[500]!,
                onPressed: () {
                     _showSnackBar('Bookmark', 'Bookmark action triggered (main post).', Colors.blueAccent);
                },
              ),
              _buildStatButton(
                icon: FeatherIcons.share2, // Share
                text: '',
                color: Colors.grey[500]!,
                onPressed: () => _sharePost(post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          if (text.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              text,
              style: GoogleFonts.roboto(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  double? _parseAspectRatio(dynamic aspectRatio) {
    if (aspectRatio == null) return null;
    try {
      if (aspectRatio is double) {
        return (aspectRatio > 0) ? aspectRatio : 1.0;
      }
      if (aspectRatio is String) {
        if (aspectRatio.contains(':')) {
          final parts = aspectRatio.split(':');
          if (parts.length == 2) {
            final width = double.tryParse(parts[0].trim());
            final height = double.tryParse(parts[1].trim());
            if (width != null && height != null && width > 0 && height > 0) {
              return width / height;
            }
          }
        } else {
          final value = double.tryParse(aspectRatio);
          if (value != null && value > 0) {
            return value;
          }
        }
      }
    } catch (e) {
      print('Error parsing aspect ratio: $e');
    }
    return 1.0;
  }

  Widget _buildReplyAttachmentWidget(
    Map<String, dynamic> attachmentMap,
    int idx,
    List<Map<String, dynamic>> allAttachmentsInThisPost,
    Map<String, dynamic> postOrReplyData,
    BorderRadius borderRadius,
  ) {
    final String attachmentType = attachmentMap['type'] as String? ?? 'unknown';
    final String? displayUrl = attachmentMap['url'] as String?;
    final String? thumbnailUrl = attachmentMap['thumbnailUrl'] as String?;
    final String? attachmentFilename = attachmentMap['filename'] as String?;
    final File? localFile =
        attachmentMap['file'] is File ? attachmentMap['file'] as File? : null;

    final String messageContent = postOrReplyData['content'] as String? ?? '';
    final String userName = postOrReplyData['username'] as String? ?? 'Unknown User';
    final String? userAvatarUrl = postOrReplyData['useravatar'] as String?;
    final DateTime timestamp = postOrReplyData['createdAt'] is String
        ? (DateTime.tryParse(postOrReplyData['createdAt'] as String) ??
            DateTime.now())
        : (postOrReplyData['createdAt'] is DateTime
            ? postOrReplyData['createdAt']
            : DateTime.now());

    final int viewsCount =
        postOrReplyData['viewsCount'] as int? ??
            (postOrReplyData['views'] as List?)?.length ??
            0;
    final int likesCount =
        postOrReplyData['likesCount'] as int? ??
            (postOrReplyData['likes'] as List?)?.length ??
            0;
    final int repostsCount =
        postOrReplyData['repostsCount'] as int? ??
            (postOrReplyData['reposts'] as List?)?.length ??
            0;

    Widget contentWidget;

    final String attachmentKeySuffix;
    if (attachmentMap['_id'] != null && (attachmentMap['_id'] as String).isNotEmpty) {
      attachmentKeySuffix = attachmentMap['_id'] as String;
    } else if (attachmentMap['url'] != null &&
        (attachmentMap['url'] as String).isNotEmpty) {
      attachmentKeySuffix = attachmentMap['url'] as String;
    } else {
      attachmentKeySuffix = idx.toString();
      print(
          "Warning: Reply attachment for post/reply ${postOrReplyData['_id']} at index $idx is using an index-based key suffix. Data: $attachmentMap");
    }

    if (attachmentType == "video") {
      contentWidget = VideoAttachmentWidget(
        key: Key('video_reply_$attachmentKeySuffix'),
        attachment: attachmentMap,
        post: postOrReplyData,
        borderRadius: borderRadius,
        enforceFeedConstraints: false,
      );
    } else if (attachmentType == "image") {
      if (displayUrl != null && displayUrl.isNotEmpty) {
        contentWidget = Image.network(
          displayUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[900],
              child: const Icon(FeatherIcons.image,
                  color: Colors.grey, size: 40)),
        );
      } else if (localFile != null) {
        contentWidget = Image.file(
          localFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[900],
              child: const Icon(FeatherIcons.image,
                  color: Colors.grey, size: 40)),
        );
      } else {
        contentWidget = Container(
            color: Colors.grey[900],
            child: const Icon(FeatherIcons.alertTriangle,
                color: Colors.redAccent, size: 40));
      }
    } else if (attachmentType == "pdf") {
      final uri = displayUrl != null
          ? Uri.tryParse(displayUrl)
          : (localFile != null ? Uri.file(localFile.path) : null);
      if (uri != null) {
        contentWidget = PdfThumbnailWidget(
          pdfUrl: uri.toString(),
          aspectRatio: 4 / 3,
          onTap: () {
            int initialIndex = allAttachmentsInThisPost.indexWhere((att) =>
                (att['url'] != null && att['url'] == attachmentMap['url']) ||
                (att.hashCode == attachmentMap.hashCode));
            if (initialIndex == -1) initialIndex = idx;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaViewPage(
                  attachments: allAttachmentsInThisPost,
                  initialIndex: initialIndex,
                  message: messageContent,
                  userName: userName,
                  userAvatarUrl: userAvatarUrl,
                  timestamp: timestamp,
                  viewsCount: viewsCount,
                  likesCount: likesCount,
                  repostsCount: repostsCount,
                ),
              ),
            );
          },
        );
      } else {
        contentWidget = Container(
            color: Colors.grey[900],
            child: const Icon(FeatherIcons.alertTriangle,
                color: Colors.redAccent, size: 40));
      }
    } else if (attachmentType == "audio") {
      contentWidget = AudioAttachmentWidget(
        key: Key('audio_reply_$attachmentKeySuffix'),
        attachment: attachmentMap,
        post: postOrReplyData,
        borderRadius: borderRadius,
      );
    } else {
      contentWidget = Container(
        color: Colors.grey[900],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FeatherIcons.film, color: Colors.tealAccent, size: 40),
            const SizedBox(height: 8),
            Text(
                attachmentFilename ??
                    (displayUrl ?? 'unknown').split('/').last,
                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        int initialIndex = allAttachmentsInThisPost.indexWhere((att) =>
            (att['url'] != null && att['url'] == attachmentMap['url']) ||
            (att.hashCode == attachmentMap.hashCode));
        if (initialIndex == -1) initialIndex = idx;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaViewPage(
              attachments: allAttachmentsInThisPost,
              initialIndex: initialIndex,
              message: messageContent,
              userName: userName,
              userAvatarUrl: userAvatarUrl,
              timestamp: timestamp,
              viewsCount: viewsCount,
              likesCount: likesCount,
              repostsCount: repostsCount,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
  }

  Widget _buildReplyAttachmentGrid(
      List<Map<String, dynamic>> attachmentsArg,
      Map<String, dynamic> postOrReplyData,
      String userName,
      String? userAvatar,
      DateTime timestamp,
      int viewsCount,
      int likesCount,
      int repostsCount,
      String messageContent) {
    const double itemSpacing = 4.0;
    if (attachmentsArg.isEmpty) return const SizedBox.shrink();

    final List<Map<String, dynamic>> allAttachmentsForMediaView;
    final dynamic rawPostAttachments = postOrReplyData['attachments'];
    if (rawPostAttachments is List) {
      allAttachmentsForMediaView =
          rawPostAttachments.whereType<Map<String, dynamic>>().toList();
    } else {
      allAttachmentsForMediaView = [];
    }

    Widget gridContent;

    if (attachmentsArg.length == 1) {
      final attachment = attachmentsArg[0];
      double aspectRatioToUse = _parseAspectRatio(attachment['aspectRatio']) ??
          (attachment['type'] == 'video' ? 16 / 9 : 1.0);
      if (aspectRatioToUse <= 0) {
        aspectRatioToUse = (attachment['type'] == 'video' ? 16 / 9 : 1.0);
      }

      gridContent = AspectRatio(
        aspectRatio: aspectRatioToUse,
        child: _buildReplyAttachmentWidget(
            attachment, 0, allAttachmentsForMediaView, postOrReplyData, BorderRadius.circular(12.0)),
      );
    } else if (attachmentsArg.length == 2) {
      gridContent = AspectRatio(
        aspectRatio: 2 * (4 / 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: _buildReplyAttachmentWidget(attachmentsArg[0], 0,
                    allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
            const SizedBox(width: itemSpacing),
            Expanded(
                child: _buildReplyAttachmentWidget(attachmentsArg[1], 1,
                    allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
          ],
        ),
      );
    } else if (attachmentsArg.length == 3) {
      gridContent = LayoutBuilder(builder: (context, constraints) {
        double width = constraints.maxWidth;
        double leftItemWidth = (width - itemSpacing) * (2 / 3);
        double rightColumnWidth = (width - itemSpacing) * (1 / 3);
        double totalHeight = width *
            ((attachmentsArg[0]['type'] == 'video' ||
                    attachmentsArg[1]['type'] == 'video' ||
                    attachmentsArg[2]['type'] == 'video')
                ? (9 / 16)
                : (3 / 4));
        if (attachmentsArg
            .any((att) => (_parseAspectRatio(att['aspectRatio']) ?? 1.0) < 1)) {
          totalHeight = width * (4 / 3);
        }

        return SizedBox(
          height: totalHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                  width: leftItemWidth,
                  child: _buildReplyAttachmentWidget(attachmentsArg[0], 0,
                      allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
              const SizedBox(width: itemSpacing),
              SizedBox(
                width: rightColumnWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: _buildReplyAttachmentWidget(attachmentsArg[1], 1,
                            allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
                    const SizedBox(height: itemSpacing),
                    Expanded(
                        child: _buildReplyAttachmentWidget(attachmentsArg[2], 2,
                            allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
                  ],
                ),
              ),
            ],
          ),
        );
      });
    } else if (attachmentsArg.length == 4) {
      gridContent = AspectRatio(
        aspectRatio: 1.0,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: itemSpacing,
              mainAxisSpacing: itemSpacing,
              childAspectRatio: 1),
          itemCount: 4,
          itemBuilder: (context, index) => _buildReplyAttachmentWidget(
              attachmentsArg[index],
              index,
              allAttachmentsForMediaView,
              postOrReplyData,
              BorderRadius.zero),
        ),
      );
    } else if (attachmentsArg.length == 5) {
      gridContent = LayoutBuilder(builder: (context, constraints) {
        double containerWidth = constraints.maxWidth;
        double h1 = (containerWidth - itemSpacing) / 2;
        double h2 = (containerWidth - 2 * itemSpacing) / 3;
        double totalHeight = h1 + itemSpacing + h2;
        return SizedBox(
          height: totalHeight,
          child: Column(
            children: [
              SizedBox(
                  height: h1,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: _buildReplyAttachmentWidget(
                                attachmentsArg[0],
                                0,
                                allAttachmentsForMediaView,
                                postOrReplyData,
                                BorderRadius.zero)),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                            child: _buildReplyAttachmentWidget(
                                attachmentsArg[1],
                                1,
                                allAttachmentsForMediaView,
                                postOrReplyData,
                                BorderRadius.zero)),
                      ])),
              const SizedBox(height: itemSpacing),
              SizedBox(
                  height: h2,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: _buildReplyAttachmentWidget(
                                attachmentsArg[2],
                                2,
                                allAttachmentsForMediaView,
                                postOrReplyData,
                                BorderRadius.zero)),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                            child: _buildReplyAttachmentWidget(
                                attachmentsArg[3],
                                3,
                                allAttachmentsForMediaView,
                                postOrReplyData,
                                BorderRadius.zero)),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                            child: _buildReplyAttachmentWidget(
                                attachmentsArg[4],
                                4,
                                allAttachmentsForMediaView,
                                postOrReplyData,
                                BorderRadius.zero)),
                      ])),
            ],
          ),
        );
      });
    } else {
      const int crossAxisCount = 3;
      const double childAspectRatio = 1.0;
      gridContent = LayoutBuilder(builder: (context, constraints) {
        double itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * itemSpacing) /
                crossAxisCount;
        double itemHeight = itemWidth / childAspectRatio;
        int numRows = (attachmentsArg.length / crossAxisCount).ceil();
        double totalHeight = numRows * itemHeight + (numRows - 1) * itemSpacing;
        return SizedBox(
          height: totalHeight,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: itemSpacing,
                mainAxisSpacing: itemSpacing,
                childAspectRatio: childAspectRatio),
            itemCount: attachmentsArg.length,
            itemBuilder: (context, index) => _buildReplyAttachmentWidget(
                attachmentsArg[index],
                index,
                allAttachmentsForMediaView,
                postOrReplyData,
                BorderRadius.zero),
          ),
        );
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: gridContent,
    );
  }

  Future<void> _pickAndAddAttachment(String type) async {
    File? file;
    String dialogTitle = '';
    String message = '';
    XFile? pickedFile;

    try {
      if (!await _requestMediaPermissions(type)) return;

      final picker = ImagePicker();
      if (type == "image") {
        dialogTitle = 'Upload Image';
        pickedFile = await picker.pickImage(source: ImageSource.gallery);
      } else if (type == "video") {
        dialogTitle = 'Upload Video';
        pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      } else if (type == "pdf") {
        dialogTitle = 'Upload Document';
        final result = await FilePicker.platform
            .pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: false);
        if (result != null && result.files.single.path != null)
          file = File(result.files.single.path!);
      } else if (type == "audio") {
        dialogTitle = 'Upload Audio';
        final result = await FilePicker.platform
            .pickFiles(type: FileType.audio, allowMultiple: false);
        if (result != null && result.files.single.path != null)
          file = File(result.files.single.path!);
      }

      if (pickedFile != null) file = File(pickedFile.path);

      if (file != null) {
        final sizeInBytes = await file.length();
        final double sizeInMB = sizeInBytes / (1024 * 1024);

        if (sizeInMB > 20) {
          message =
              'File "${file.path.split('/').last}" is too large (${sizeInMB.toStringAsFixed(1)}MB). Must be under 20MB.';
          _showSnackBar(dialogTitle, message, Colors.red[700]!);
          return;
        }

        if (mounted) {
          setState(() {
            _replyAttachments.add({
              'file': file,
              'type': type,
              'filename': file?.path.split('/').last,
              'size': sizeInBytes,
            });
          });
        }
        message =
            '${type[0].toUpperCase()}${type.substring(1)} selected: ${file.path.split('/').last}';
        _showSnackBar(dialogTitle, message, Colors.teal[700]!);
      } else {
        message = 'No file selected for $type.';
        _showSnackBar(dialogTitle, message, Colors.red[700]!);
      }
    } catch (e) {
      message = 'Error picking $type: $e';
      _showSnackBar('Error', message, Colors.red[700]!);
    }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(FeatherIcons.image, color: Colors.tealAccent),
                title:
                    Text('Image', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("image");
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.video, color: Colors.tealAccent),
                title:
                    Text('Video', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("video");
                },
              ),
              ListTile(
                leading:
                    const Icon(FeatherIcons.fileText, color: Colors.tealAccent),
                title: Text('PDF Document',
                    style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("pdf");
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.music, color: Colors.tealAccent),
                title:
                    Text('Audio', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("audio");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _submitReply() async {
    if (_isSubmittingReply) return;
    if (_replyController.text.trim().isEmpty && _replyAttachments.isEmpty) {
      _showSnackBar('Input Error', 'Please enter text or add an attachment.',
          Colors.red[700]!);
      return;
    }
    if (mounted) setState(() { _isSubmittingReply = true; });
    else return;

    List<Map<String, dynamic>> uploadedReplyAttachments = [];
    try {
      if (_replyAttachments.isNotEmpty) {
        final filesToUpload = _replyAttachments
            .where((a) => a['file'] != null && a['file'] is File)
            .map((a) => {
                  'file': a['file'],
                  'type': a['type'],
                  'filename': a['filename'],
                  'size': a['size']
                })
            .toList();
        if (filesToUpload.isNotEmpty) {
          final uploadResults = await _dataController.uploadFiles(filesToUpload);
          int uploadResultIndex = 0;
          for (var originalAttachment in _replyAttachments) {
            if (originalAttachment['file'] != null &&
                originalAttachment['file'] is File) {
              if (uploadResultIndex < uploadResults.length) {
                final result = uploadResults[uploadResultIndex];
                if (result['success'] == true && result['url'] != null) {
                  uploadedReplyAttachments.add({
                    'type': originalAttachment['type'],
                    'filename': originalAttachment['filename'] ??
                        result['filename'] ??
                        'unknown',
                    'size': originalAttachment['size'] ?? result['size'] ?? 0,
                    'url': result['url'] as String,
                    'thumbnailUrl': result['thumbnailUrl'] as String?
                  });
                } else {
                  _showSnackBar(
                      'Upload Error',
                      'Failed to upload ${originalAttachment['filename'] ?? 'a file'}: ${result['message'] ?? 'Unknown error'}',
                      Colors.red[700]!);
                }
                uploadResultIndex++;
              }
            } else if (originalAttachment['url'] != null) {
              uploadedReplyAttachments.add(originalAttachment);
            }
          }
        }
      }
      if (_replyController.text.trim().isEmpty &&
          uploadedReplyAttachments.isEmpty &&
          _replyAttachments.isNotEmpty) {
        _showSnackBar('Upload Error',
            'Failed to upload attachments. Reply not sent.', Colors.red[700]!);
        if (mounted) setState(() { _isSubmittingReply = false; });
        return;
      }
      final postId = widget.post['_id'] as String?;
      if (postId == null) {
        _showSnackBar('Error', 'Cannot post reply: Original post ID is missing.',
            Colors.red[700]!);
        if (mounted) setState(() { _isSubmittingReply = false; });
        return;
      }

      final replyData = {
        'postId': postId,
        'content': _replyController.text.trim(),
        'attachments': uploadedReplyAttachments,
        if (_parentReplyId != null) 'parentReplyId': _parentReplyId,
      };

      final result = await _dataController.replyToPost(replyData);

      if (!mounted) return;

      if (result['success'] == true && result['reply'] != null) {
        final newReply = result['reply'] as Map<String, dynamic>;
        // New reply successfully posted and data is available
        _showSnackBar('Success', result['message'] ?? 'Reply posted!', Colors.teal[700]!);
        setState(() {
          _replies.insert(0, newReply); // Add to the top of the list
          _replyController.clear();
          _replyAttachments.clear();
          _parentReplyId = null;
          // No navigation, stay on the page. User sees their reply.
        });
      } else if (result['success'] == true && result['reply'] == null) {
        // This case implies success but no immediate reply data, so we refresh.
        _showSnackBar('Success', result['message'] ?? 'Reply posted! Refreshing replies...', Colors.teal[700]!);
        _replyController.clear();
        if (mounted) setState(() { // Clear attachments and parent ID optimistically
          _replyAttachments.clear();
          _parentReplyId = null;
        });
        await _fetchPostReplies(showLoadingIndicator: false); // Refresh replies list
        // No navigation, stay on page.
      } else {
        _showSnackBar('Error', result['message'] ?? 'Failed to post reply.', Colors.red[700]!);
      }
    } catch (e) {
      print('Error in _submitReply: $e');
      if (mounted) {
        _showSnackBar('Error', 'An unexpected error occurred: ${e.toString()}',
            Colors.red[700]!);
      }
    } finally {
      if (mounted) {
        setState(() { _isSubmittingReply = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String postUsername = widget.post['username'] as String? ?? 'User';
    final DateTime parsedTimestamp = widget.post['createdAt'] is String
        ? (DateTime.tryParse(widget.post['createdAt'] as String) ??
            DateTime.now())
        : (widget.post['createdAt'] is DateTime
            ? widget.post['createdAt']
            : DateTime.now());

    // final String? appBarUserAvatar = widget.post['useravatar'] as String?;
    // final String appBarAvatarInitial = widget.post['avatarInitial'] as String? ??
    //     (postUsername.isNotEmpty ? postUsername[0].toUpperCase() : '?');

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(FeatherIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Post', // X/Twitter uses "Post" as title
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF000000), // Twitter-like black background
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.moreVertical, color: Colors.white), // Using Feather icon for consistency
            onPressed: _showActionsBottomSheet,
            tooltip: 'More Actions',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(0), // Will be handled by items
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Post Display Area
                  _buildTweetStylePostItem(_mainPostData, isMainPost: true),
                  // The Divider after the main post is good.

                  // Reply Input Area - Placed here, before the list of replies.
                  // It will only be shown if _showReplyField is true, which is handled by its own build method.
                  // No explicit if needed here, as _buildReplyInputArea handles its visibility.
                  // The _buildReplyInputArea itself returns a Container or SizedBox.shrink.
                  // However, to ensure it's part of the scrollable content and correctly positioned:
                  // We ensure _buildReplyInputArea is called within the SingleChildScrollView's Column.
                  // The visibility of the input area is controlled by the _showReplyField state variable
                  // and the _buildReplyInputArea returns an empty SizedBox if not shown.
                  // For clarity in structure, it's better to conditionally add it or ensure it returns SizedBox.shrink().
                  // The current _buildReplyInputArea is outside the SingleChildScrollView, which is not ideal.
                  // Let's move its call or a wrapper into the SingleChildScrollView.

                  // The reply input should be sticky at the bottom if not part of scroll.
                  // For X style, the reply input for the *main post* is typically part of the scrollable content, below the post.
                  // Let's ensure _buildReplyInputArea is called *within* the SingleChildScrollView's main Column.
                  // The if (_showReplyField) _buildReplyInputArea() is at the very bottom of the outer Column,
                  // which makes it sticky. This is fine for a reply bar.
                  // For X, the "Post your reply" is often more integrated.
                  // Let's move it into the scroll view for now.

                  const Divider(color: Color(0xFF2F3336), height: 1), // Divider after main post
                  // Reply input area is now removed from the scrollable view.

                  // Replies List
                  Padding(
                    padding: const EdgeInsets.only(top: 0.0), // No top padding for the list itself
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Replies",
                                  style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.tealAccent, size: 22),
                                tooltip: "Refresh Replies",
                                onPressed: () =>
                                    _fetchPostReplies(showLoadingIndicator: true),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoadingReplies && _fetchRepliesError == null)
                          const Center(
                              child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child: CircularProgressIndicator(
                                      color: Colors.tealAccent)))
                        else if (_fetchRepliesError != null)
                          Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                                child: Text(
                                  "Couldn't load replies. Tap refresh to try again.",
                                  style: GoogleFonts.roboto(
                                      color: Colors.redAccent, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                        else if (_replies.isEmpty)
                          Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                                child: Text(
                                  "No replies yet. Be the first to reply!",
                                  style: GoogleFonts.roboto(
                                      color: Colors.grey[500], fontSize: 14),
                                ),
                              ),
                            )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _replies.length,
                            itemBuilder: (context, index) {
                              final reply = _replies[index];
                              bool isLast = index == _replies.length - 1;
                              return _buildTweetStylePostItem(reply, isMainPost: false, isLastReply: isLast);
                            },
                            separatorBuilder: (context, index) =>
                              const Divider(color: Color(0xFF2F3336), height: 1, indent: 58, endIndent: 16), // Adjusted indent
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Conditionally display the reply input area at the bottom
          if (_showReplyField) _buildReplyInputArea(),
        ],
      ),
    );
  }

  Widget _buildReplyInputArea() {
    if (!_showReplyField) {
      return const SizedBox.shrink(); // Don't show anything if not active
    }

    final currentUserData = _dataController.user.value['user'] as Map<String, dynamic>?;
    final String? currentUserAvatar = currentUserData?['avatar'] as String?;
    final String currentUserInitial = currentUserData?['username'] != null && (currentUserData!['username'] as String).isNotEmpty
        ? (currentUserData['username'] as String)[0].toUpperCase()
        : '?';

    String hintText = "Post your reply...";
    if (_parentReplyId != null) {
      final parentReplyUser = _replies.firstWhere((r) => r['_id'] == _parentReplyId, orElse: () => {});
      if (parentReplyUser.isNotEmpty && parentReplyUser['username'] != null) {
        hintText = "Reply to @${parentReplyUser['username']}...";
      } else {
         // Fallback if parent reply user not found in _replies (e.g. replying to main post, which isn't in _replies)
         // Or if replying to a reply that's somehow not in the loaded list.
         // A more robust way would be to pass the parent post/reply object or username directly.
         // For now, let's check if we are replying to the main post.
         if (widget.post['_id'] == _parentReplyId) { // This check is flawed as _parentReplyId is for replies, not main post.
            hintText = "Reply to @${widget.post['username']}...";
         } else {
           hintText = "Reply to selected message..."; // Generic fallback
         }
      }
    }


    return Container(
      padding: const EdgeInsets.all(12.0), // Use symmetric padding for X-like feel
      // No border here, it's part of the feed items with dividers around it.
      // Background color should match the page background or be slightly different if desired for emphasis.
      // Using Colors.transparent to blend with the page's black background.
      color: Colors.transparent,
      child: Padding( // Added padding around the entire input area
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attachment Previews (Chips) - Placed above the input row
            if (_replyAttachments.isNotEmpty) ...[
              SizedBox(
                height: 45, // Adjusted height for chips
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _replyAttachments.map((attachment) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Chip(
                        avatar: Icon(
                          attachment['type'] == 'image' ? FeatherIcons.image :
                          attachment['type'] == 'video' ? FeatherIcons.video :
                          attachment['type'] == 'audio' ? FeatherIcons.music : FeatherIcons.file,
                          size: 16, color: Colors.white70
                        ),
                        label: Text(
                          (attachment['filename'] ?? (attachment['file']?.path.split('/').last ?? 'Preview')),
                          style: GoogleFonts.roboto(color: Colors.white, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        backgroundColor: Colors.grey[800],
                        deleteIcon: const Icon(FeatherIcons.xCircle, size: 16, color: Colors.white70),
                        onDeleted: () {
                          setState(() { _replyAttachments.remove(attachment); });
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0), // Compact padding
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Main Input Row: Avatar, TextField, Attach, Send
            Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically in the center
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: currentUserAvatar != null && currentUserAvatar.isNotEmpty
                    ? NetworkImage(currentUserAvatar)
                    : null,
                child: currentUserAvatar == null || currentUserAvatar.isEmpty
                    ? Text(currentUserInitial,
                        style: GoogleFonts.poppins(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 16))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _replyController,
                  focusNode: _replyFocusNode, // Assign the FocusNode
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16), // Slightly larger font
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 16), // Adjusted hint color
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), // Adjusted padding
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 1, // Will start as single line
                  maxLines: 5, // Can expand up to 5 lines
                  maxLength: 280,
                  buildCounter: (BuildContext context, {int? currentLength, int? maxLength, bool? isFocused}) => null,
                ),
              ),
              const SizedBox(width: 8), // Spacing before attach icon
              IconButton(
                icon: const Icon(FeatherIcons.paperclip, color: Colors.tealAccent, size: 22),
                onPressed: _showAttachmentPicker,
                tooltip: 'Add Media',
                padding: EdgeInsets.zero, // Reduce padding for compact row
                constraints: const BoxConstraints(), // Reduce constraints
              ),
              const SizedBox(width: 4), // Spacing before send button
              _isSubmittingReply
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.tealAccent), // Slightly thicker stroke
                      ),
                    )
                  : TextButton( // X uses a button for "Reply" or "Post"
                      onPressed: _submitReply,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                      ),
                      child: Text(
                        'Reply',
                         style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    )
            ],
          ),
        ],
      ),
    );
  }
}