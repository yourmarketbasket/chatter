import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
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
  final String? originalPostId; // ID of the ultimate root post of the thread

  const ReplyPage({Key? key, required this.post, this.originalPostId}) : super(key: key);

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

    // View the main item of this page (could be a post or a reply acting as a post)
    final String currentPostId = _mainPostData['_id'] as String? ?? "";
    if (currentPostId.isNotEmpty) {
      if (widget.originalPostId == null) { // This is a top-level post
        _dataController.viewPost(currentPostId);
      } else { // This is a reply being viewed as a main post, so call viewReply
             // We need the originalPostId of the thread, and currentPostId is the replyId
        _dataController.viewReply(widget.originalPostId!, currentPostId);
      }
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
      final String currentPostItemId = widget.post['_id'] as String? ?? "";
      if (currentPostItemId.isEmpty) {
        print("Error: Current post item ID is null/empty in _fetchPostReplies. Cannot fetch replies.");
        if (mounted) {
          setState(() {
            _fetchRepliesError = 'Cannot load replies: Current item ID is missing.';
            _isLoadingReplies = false;
          });
        }
        return;
      }

      List<Map<String, dynamic>> fetchedReplies;
      if (widget.originalPostId == null) {
        // This ReplyPage instance is for a top-level post. Fetch its direct replies.
        print("[ReplyPage] Fetching replies for top-level post: $currentPostItemId");
        fetchedReplies = await _dataController.fetchReplies(currentPostItemId);
      } else {
        // This ReplyPage instance is for a reply (widget.post is a reply).
        // Fetch replies for this reply using originalPostId and currentPostItemId (which is the parentReplyId).
        print("[ReplyPage] Fetching replies for reply: $currentPostItemId (original post: ${widget.originalPostId})");
        fetchedReplies = await _dataController.fetchRepliesForReply(widget.originalPostId!, currentPostItemId);
      }

      // print(fetchedReplies); // Already printed inside DataController methods
      if (mounted) {
        setState(() {
          _replies = fetchedReplies;
          if (showLoadingIndicator) _isLoadingReplies = false;
        });
      }
    } catch (e) {
      print('Error fetching replies in ReplyPage: $e');
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

 Widget _buildPostContent(Map<String, dynamic> postData, {required bool isReply, int indentLevel = 0}) { // Renamed post to postData
  // If this ReplyPage is showing a reply as its main item, widget.originalPostId will be non-null.
  // If it's showing a top-level post, widget.originalPostId will be null.
  // `postId` should refer to the ID of the item being currently processed by _buildPostContent (postData['_id'])
  // `threadOriginalPostId` is the ID of the ultimate root post of the entire thread.
  final String currentEntryId = postData['_id'] as String; // ID of the current post or reply item being built
  final String username = postData['username'] as String? ?? 'Unknown User';
  // Determine the ultimate root post ID for API calls, regardless of current nesting level
  final String rootPostId = widget.originalPostId ?? (isReply ? (postData['originalPostId'] ?? widget.post['_id']) : widget.post['_id']) as String;
  // ^ If widget.originalPostId is set, use it. Else, if it's a reply, try to get its originalPostId,
  //   fallback to the current page's main post ID. If not a reply, it's the current page's main post ID.
  // This logic for `rootPostId` might need refinement based on exactly how `originalPostId` is stored/passed for replies.
  // For now, simplifying to what was used for actions:
  final String threadOriginalPostId = widget.originalPostId ?? widget.post['_id'] as String;

  // Decode content if it's in buffer format
  String content = postData['content'] as String? ?? '';
  if (postData['buffer'] != null && postData['buffer']['data'] is List) {
    try {
      final List<int> data = List<int>.from(postData['buffer']['data'] as List);
      content = utf8.decode(data); // Assuming UTF-8 encoding
    } catch (e) {
      print('Error decoding buffer content for ${currentEntryId}: $e');
      content = 'Error displaying content.';
    }
  }

  final String? userAvatar = postData['useravatar'] as String?;
  final String avatarInitial = postData['avatarInitial'] as String? ?? (username.isNotEmpty ? username[0].toUpperCase() : '?');
  final DateTime timestamp = postData['createdAt'] is String
      ? (DateTime.tryParse(postData['createdAt'] as String) ?? DateTime.now())
      : (postData['createdAt'] is DateTime ? postData['createdAt'] as DateTime : DateTime.now());

  List<Map<String, dynamic>> correctlyTypedAttachments = [];
  final dynamic rawAttachments = postData['attachments'];
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

  // Determine if the current user has liked this specific post/reply
  final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';
  final List<dynamic> likesList = postData['likes'] is List ? postData['likes'] as List<dynamic> : [];
  final bool isLikedByCurrentUser = likesList.any((like) =>
      (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId)
  );

  final int likesCount = postData['likesCount'] as int? ?? likesList.length;
  final int repostsCount = postData['repostsCount'] as int? ?? (postData['reposts'] is List ? (postData['reposts'] as List).length : 0);
  final int viewsCount = postData['viewsCount'] as int? ?? (postData['views'] is List ? (postData['views'] as List).length : 0);
  // Ensure repliesCount is accurately derived, especially for replies which might have their own replies.
  // If postData['replies'] contains actual reply objects, count them. If it contains IDs, it's more complex without fetching.
  // For now, assume 'repliesCount' is provided or direct children count is sufficient.
  final int repliesCount = postData['repliesCount'] as int? ?? (postData['replies'] is List ? (postData['replies'] as List).length : 0);


  final EdgeInsets postItemPadding = isReply
      ? EdgeInsets.only(left: 16.0 * indentLevel + 4.0, right: 4.0) // Apply indentation for replies
      : const EdgeInsets.only(right: 4.0); // No specific left indent for main post

  // Call viewReply if this is a reply and it's being built
  // This is a simplistic way to track views. A more robust way would be VisibilityDetector.
  if (isReply) {
    // When building a reply item, view it.
    // threadOriginalPostId is the ID of the root post.
    // currentEntryId is the ID of the reply being viewed.
    _dataController.viewReply(threadOriginalPostId, currentEntryId);
  }
  // Note: The viewing of the main post/item for the page is handled in initState.


  // return Padding(
  //   padding: postItemPadding, // This was the duplicated line
  //     : const EdgeInsets.only(right: 4.0);

  return Padding(
    padding: postItemPadding, // Corrected: This is the single, correct Padding widget call
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row( // This is the top-level Row for a post/reply item: Avatar + Main Content Column
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TODO: Consider if CircleAvatar should be outside the Expanded for consistent left alignment,
            // or if the current structure (where content and actions are indented relative to it) is preferred.
            // For now, keeping it as part of the main content block.
            Expanded(
              child: Column( // Main column for the item: User/Content Details + Action Buttons
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info + Tappable Content Area
                  Row( // Row for Avatar and the rest of the content (user info, text, attachments)
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Padding( // Padding for the avatar
                         padding: const EdgeInsets.only(top: 8.0, right: 12.0, left:8.0), // Adjust left padding if avatar is here
                         child: CircleAvatar(
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
                       ),
                      Expanded(
                        child: GestureDetector(
                          onTap: isReply ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReplyPage(
                                  post: postData,
                                  originalPostId: threadOriginalPostId,
                                ),
                              ),
                            );
                          } : null,
                          child: Column( // Column for username/timestamp row, content text, and attachments
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row( // Username, timestamp, views
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
                                  Expanded(
                                    child: Text(
                                      '${DateFormat('h:mm a').format(timestamp)} · ${DateFormat('MMM d, yyyy').format(timestamp)} · $viewsCount views',
                                      style: GoogleFonts.roboto(
                                        fontSize: isReply ? 11 : 12,
                                        color: Colors.grey[400],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text( // Content text
                                content,
                                style: GoogleFonts.roboto(
                                  fontSize: isReply ? 13 : 14,
                                  color: const Color.fromARGB(255, 255, 255, 255),
                                  height: 1.5,
                                ),
                              ),
                              if (correctlyTypedAttachments.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildReplyAttachmentGrid( // Attachments grid
                                  correctlyTypedAttachments,
                                  postData,
                                  username,
                                  userAvatar,
                                  timestamp,
                                  viewsCount,
                                  likesCount,
                                  repostsCount,
                                  content,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8), // Space before action buttons
                  // Action Buttons Row
                  Padding(
                    // Adjust left padding to align with content (after avatar)
                    padding: EdgeInsets.only(left: (isReply ? 14 : 18) * 2 + 12 + 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         _buildStatButton(
                          icon: FeatherIcons.messageCircle,
                          text: '$repliesCount',
                          color: Colors.tealAccent,
                          onPressed: () {
                            setState(() {
                              _parentReplyId = currentEntryId;
                              _showReplyField = true;
                              FocusScope.of(context).requestFocus(_replyFocusNode);
                            });
                            _showSnackBar('Reply', 'Replying to @$username...', Colors.teal[700]!);
                          },
                        ),
                        _buildStatButton(
                          icon: FeatherIcons.repeat,
                          text: '$repostsCount',
                          color: Colors.greenAccent,
                          onPressed: () async {
                            if (isReply) {
                              final result = await _dataController.repostReply(threadOriginalPostId, currentEntryId);
                              if (result['success'] == true) {
                                _showSnackBar('Success', result['message'] ?? 'Reply reposted!', Colors.green[700]!);
                                setState(() {
                                  int replyIndex = _replies.indexWhere((r) => r['_id'] == currentEntryId);
                                  if (replyIndex != -1) {
                                    var originalReply = _replies[replyIndex];
                                    var newRepostsList = List<dynamic>.from(originalReply['reposts'] ?? []);
                                    if (!newRepostsList.contains(currentUserId)) {
                                       newRepostsList.add(currentUserId);
                                    }
                                    _replies[replyIndex] = {
                                      ...originalReply,
                                      'reposts': newRepostsList,
                                      'repostsCount': newRepostsList.length
                                    };
                                  }
                                });
                              } else {
                                _showSnackBar('Error', result['message'] ?? 'Failed to repost reply.', Colors.red[700]!);
                              }
                            } else {
                               _showSnackBar(
                                'Repost Post',
                                'Repost post by @$username (original functionality).', Colors.orange);
                            }
                          },
                        ),
                        _buildStatButton(
                          icon: isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart,
                          text: '$likesCount',
                          color: isLikedByCurrentUser ? Colors.pinkAccent : Colors.pinkAccent.withOpacity(0.7),
                          onPressed: () async {
                            if (isReply) {
                              if (isLikedByCurrentUser) {
                                final result = await _dataController.unlikeReply(threadOriginalPostId, currentEntryId);
                                if (result['success'] == true) {
                                  _showSnackBar('Success', result['message'] ?? 'Reply unliked!', Colors.grey[700]!);
                                  setState(() {
                                    int replyIndex = _replies.indexWhere((r) => r['_id'] == currentEntryId);
                                    if (replyIndex != -1) {
                                      var originalReply = _replies[replyIndex];
                                      var newLikesList = List<dynamic>.from(originalReply['likes'] ?? []);
                                      newLikesList.removeWhere((id) => (id is Map ? id['_id'] == currentUserId : id.toString() == currentUserId));
                                      _replies[replyIndex] = {
                                        ...originalReply,
                                        'likes': newLikesList,
                                        'likesCount': newLikesList.length
                                      };
                                    }
                                  });
                                } else {
                                  _showSnackBar('Error', result['message'] ?? 'Failed to unlike reply.', Colors.red[700]!);
                                }
                              } else {
                                final result = await _dataController.likeReply(threadOriginalPostId, currentEntryId);
                                if (result['success'] == true) {
                                  _showSnackBar('Success', result['message'] ?? 'Reply liked!', Colors.pink[700]!);
                                   setState(() {
                                    int replyIndex = _replies.indexWhere((r) => r['_id'] == currentEntryId);
                                    if (replyIndex != -1) {
                                      var originalReply = _replies[replyIndex];
                                      var newLikesList = List<dynamic>.from(originalReply['likes'] ?? []);
                                      if (!newLikesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId))) {
                                        newLikesList.add(currentUserId);
                                      }
                                      _replies[replyIndex] = {
                                        ...originalReply,
                                        'likes': newLikesList,
                                        'likesCount': newLikesList.length,
                                      };
                                    }
                                  });
                                } else {
                                  _showSnackBar('Error', result['message'] ?? 'Failed to like reply.', Colors.red[700]!);
                                }
                              }
                            } else {
                               _showSnackBar(
                                'Like Post',
                                'Like post by @$username (original functionality).', Colors.orange);
                            }
                          },
                        ),
                        if (!isReply)
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
                         if (isReply)
                           const SizedBox(width: 24),
                        _buildStatButton(
                          icon: FeatherIcons.share2,
                          text: '',
                          color: Colors.white70,
                          onPressed: () => _sharePost(postData),
                        ),
                      ],
                    ),
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
      ],
    ),
  );
}
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Reply Button
                        _buildStatButton(
                          icon: FeatherIcons.messageCircle,
                          text: '$repliesCount',
                          color: Colors.tealAccent,
                          onPressed: () {
                            setState(() {
                              // If it's the main post, _parentReplyId is null (or widget.post['_id'] if we decide so)
                              // If it's a reply, _parentReplyId is currentEntryId (the ID of this reply)
                              _parentReplyId = currentEntryId; // Replying to the current item (post or reply)
                              _showReplyField = true;
                               // Focus the text field when reply button is tapped
                              FocusScope.of(context).requestFocus(_replyFocusNode);
                            });
                            _showSnackBar('Reply', 'Replying to @$username...', Colors.teal[700]!);
                          },
                        ),
                        // Repost Button
                        _buildStatButton(
                          icon: FeatherIcons.repeat,
                          text: '$repostsCount',
                          color: Colors.greenAccent,
                          onPressed: () async {
                            if (isReply) {
                              final result = await _dataController.repostReply(postId, currentEntryId);
                              if (result['success'] == true) {
                                _showSnackBar('Success', result['message'] ?? 'Reply reposted!', Colors.green[700]!);
                                setState(() {
                                  int replyIndex = _replies.indexWhere((r) => r['_id'] == currentEntryId);
                                  if (replyIndex != -1) {
                                    var originalReply = _replies[replyIndex];
                                    var newRepostsList = List<dynamic>.from(originalReply['reposts'] ?? []);
                                    if (!newRepostsList.contains(currentUserId)) {
                                       newRepostsList.add(currentUserId);
                                    }
                                    _replies[replyIndex] = {
                                      ...originalReply,
                                      'reposts': newRepostsList,
                                      'repostsCount': newRepostsList.length
                                    };
                                  }
                                });
                              } else {
                                _showSnackBar('Error', result['message'] ?? 'Failed to repost reply.', Colors.red[700]!);
                              }
                            } else { // It's the main post -  Keep original behavior or make it non-interactive as per clarification
                               _showSnackBar(
                                'Repost Post',
                                'Repost post by @$username (original functionality).', Colors.orange);
                              // Original/Placeholder action for main post repost
                              // final result = await _dataController.repostPost(currentEntryId);
                              // if (result['success'] == true) {
                              //   _showSnackBar('Success', result['message'] ?? 'Post reposted!', Colors.green[700]!);
                              //   setState(() {
                              //      _mainPostData['repostsCount'] = (_mainPostData['repostsCount'] ?? 0) + 1;
                              //      if (_mainPostData['reposts'] is List) {
                              //         (_mainPostData['reposts'] as List).add(currentUserId);
                              //      } else {
                              //         _mainPostData['reposts'] = [currentUserId];
                              //      }
                              //    });
                              //  } else {
                              //   _showSnackBar('Error', result['message'] ?? 'Failed to repost post.', Colors.red[700]!);
                              //  }
                            }
                          },
                        ),
                        // Like Button
                        _buildStatButton(
                          icon: isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart,
                          text: '$likesCount',
                          color: isLikedByCurrentUser ? Colors.pinkAccent : Colors.pinkAccent.withOpacity(0.7),
                          onPressed: () async {
                            if (isReply) { // Current item is a reply
                              if (isLikedByCurrentUser) {
                                final result = await _dataController.unlikeReply(postId, currentEntryId);
                                if (result['success'] == true) {
                                  _showSnackBar('Success', result['message'] ?? 'Reply unliked!', Colors.grey[700]!);
                                  setState(() {
                                    int replyIndex = _replies.indexWhere((r) => r['_id'] == currentEntryId);
                                    if (replyIndex != -1) {
                                      var originalReply = _replies[replyIndex];
                                      var newLikesList = List<dynamic>.from(originalReply['likes'] ?? []);
                                      newLikesList.removeWhere((id) => (id is Map ? id['_id'] == currentUserId : id.toString() == currentUserId));
                                      _replies[replyIndex] = {
                                        ...originalReply,
                                        'likes': newLikesList,
                                        'likesCount': newLikesList.length
                                      };
                                    }
                                  });
                                } else {
                                  _showSnackBar('Error', result['message'] ?? 'Failed to unlike reply.', Colors.red[700]!);
                                }
                              } else { // Not liked yet, so like it
                                final result = await _dataController.likeReply(postId, currentEntryId);
                                if (result['success'] == true) {
                                  _showSnackBar('Success', result['message'] ?? 'Reply liked!', Colors.pink[700]!);
                                   setState(() {
                                    int replyIndex = _replies.indexWhere((r) => r['_id'] == currentEntryId);
                                    if (replyIndex != -1) {
                                      var originalReply = _replies[replyIndex];
                                      var newLikesList = List<dynamic>.from(originalReply['likes'] ?? []);
                                      if (!newLikesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId))) {
                                        newLikesList.add(currentUserId); // Or the like object if backend sends it
                                      }
                                      _replies[replyIndex] = {
                                        ...originalReply,
                                        'likes': newLikesList,
                                        'likesCount': newLikesList.length,
                                      };
                                    }
                                  });
                                } else {
                                  _showSnackBar('Error', result['message'] ?? 'Failed to like reply.', Colors.red[700]!);
                                }
                              }
                            } else { // It's the main post - Keep original behavior or make it non-interactive
                               _showSnackBar(
                                'Like Post',
                                'Like post by @$username (original functionality).', Colors.orange);
                              // Original/Placeholder action for main post like
                              // if (isLikedByCurrentUser) {
                              //   final result = await _dataController.unlikePost(currentEntryId);
                              //    if (result['success'] == true) {
                              //     _showSnackBar('Success', result['message'] ?? 'Post unliked!', Colors.grey[700]!);
                              //     setState(() {
                              //       _mainPostData['likesCount'] = (_mainPostData['likesCount'] ?? 1) - 1;
                              //       if (_mainPostData['likes'] is List) {
                              //         (_mainPostData['likes'] as List).removeWhere((id) => id == currentUserId);
                              //       }
                              //     });
                              //   } else {
                              //     _showSnackBar('Error', result['message'] ?? 'Failed to unlike post.', Colors.red[700]!);
                              //   }
                              // } else {
                              //   final result = await _dataController.likePost(currentEntryId);
                              //   if (result['success'] == true) {
                              //     _showSnackBar('Success', result['message'] ?? 'Post liked!', Colors.pink[700]!);
                              //     setState(() {
                              //       _mainPostData['likesCount'] = (_mainPostData['likesCount'] ?? 0) + 1;
                              //       if (_mainPostData['likes'] is List) {
                              //         (_mainPostData['likes'] as List).add(currentUserId);
                              //       } else {
                              //         _mainPostData['likes'] = [currentUserId];
                              //       }
                              //     });
                              //   } else {
                              //     _showSnackBar('Error', result['message'] ?? 'Failed to like post.', Colors.red[700]!);
                              //   }
                              // }
                            }
                          },
                        ),
                        if (!isReply) // Bookmark only for original post (currentEntryId == postId), not replies
                          _buildStatButton(
                            icon: FeatherIcons.bookmark, // Bookmark
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
                         if (isReply) // Empty SizedBox to maintain spacing for replies if no bookmark
                           const SizedBox(width: 24), // Adjust width as needed for alignment if no bookmark
                    
                        _buildStatButton(
                          icon: FeatherIcons.share2,
                          text: '',
                          color: Colors.white70,
                          onPressed: () => _sharePost(postData), // Pass postData
                        ),
                      ],
                    ),
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
        _showSnackBar('Error', 'Cannot post reply: Original post ID is missing.', Colors.red[700]!);
        if (mounted) setState(() { _isSubmittingReply = false; });
        return;
      }

      Map<String, dynamic> result;
      // Determine if it's a reply to the main post or a reply to another reply
      if (_parentReplyId != null && _parentReplyId != postId) { // Replying to a reply
        final replyToReplyData = {
          'postId': postId, // This is the ID of the original root post
          'parentReplyId': _parentReplyId, // This is the ID of the reply we are replying to
          'content': _replyController.text.trim(),
          'attachments': uploadedReplyAttachments,
        };
        result = await _dataController.replyToReply(replyToReplyData);
      } else { // Replying to the main post
        final replyToPostData = {
          'postId': postId, // ID of the main post
          // 'parentReplyId' is not included or is null
          'content': _replyController.text.trim(),
          'attachments': uploadedReplyAttachments,
        };
        result = await _dataController.replyToPost(replyToPostData);
      }

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackBar('Success', result['message'] ?? 'Reply posted!', Colors.teal[700]!);
        _replyController.clear();
        _replyAttachments.clear();

        // If a new reply object is returned by the backend, add it.
        // Otherwise, refresh all replies for the main post to see the new reply.
        // This is crucial for replies to replies, as they might be nested.
        final newReplyData = result['reply'] as Map<String, dynamic>?;
        if (newReplyData != null) {
           // TODO: This needs to be smarter for nested replies.
           // If it's a reply to a reply, we need to find the parent reply in _replies
           // and add this newReplyData to its 'replies' list, or trigger a refresh.
           // For simplicity now, always refreshing if it was a reply to a reply,
           // or if newReplyData is null.
           if (_parentReplyId != null && _parentReplyId != postId) {
            await _fetchPostReplies(showLoadingIndicator: false); // Refresh to get nested
           } else {
             setState(() {
               _replies.insert(0, newReplyData); // Add to top for direct replies to main post
             });
           }
        } else {
          await _fetchPostReplies(showLoadingIndicator: false); // Refresh replies list
        }

        setState(() {
           _parentReplyId = null; // Reset parent reply ID
           _showReplyField = false; // Optionally hide reply field after successful submission
        });

      } else {
        _showSnackBar('Error', result['message'] ?? 'Failed to post reply.', Colors.red[700]!);
      }
    } catch (e) {
      print('Error in _submitReply: $e');
      // Ensure _isSubmittingReply is reset even if an error occurs before the finally block
      // (though finally should cover it)
      if (mounted) {
         _showSnackBar('Error', 'An unexpected error occurred: ${e.toString()}', Colors.red[700]!);
      }
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
        title: Text('Post', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        iconTheme: const IconThemeData(color: Colors.white),
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
                  Container(
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: _buildPostContent(widget.post, isReply: false),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 0.0), // No top padding for the list itself
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _isLoadingReplies && _fetchRepliesError == null
                                ? Row(
                                    children: [
                                      Text("Reloading Replies...",
                                          style: GoogleFonts.poppins(
                                              fontSize: 16, color: Colors.grey[400])),
                                      const SizedBox(width: 8),
                                      const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.tealAccent))),
                                    ],
                                  )
                                : Text("Replies",
                                    style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.tealAccent),
                                  tooltip: "Refresh Replies",
                                  onPressed: () =>
                                      _fetchPostReplies(showLoadingIndicator: true),
                                ),
                                IconButton(
                                  icon: Icon(
                                      _showReplyField
                                          ? FeatherIcons.messageCircle
                                          : FeatherIcons.edit3,
                                      color: Colors.tealAccent),
                                  tooltip: _showReplyField
                                      ? "Hide Reply Field"
                                      : "Show Reply Field",
                                  onPressed: () {
                                    setState(() {
                                      _showReplyField = !_showReplyField;
                                      if (!_showReplyField) _parentReplyId = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _isLoadingReplies && _fetchRepliesError == null
                            ? const Center(
                                child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.tealAccent)))
                            : _fetchRepliesError != null
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                                      child: Text(
                                        "Couldn't load replies. Tap refresh to try again.",
                                        style: GoogleFonts.roboto(
                                            color: Colors.redAccent, fontSize: 14),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                : _replies.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.symmetric(vertical: 20.0),
                                          child: Text(
                                            "No replies yet.",
                                            style: GoogleFonts.roboto(
                                                color: Colors.grey[500], fontSize: 14),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        separatorBuilder: (context, index) =>
                                             Divider(color: Colors.grey[800]),
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _replies.length,
                                        itemBuilder: (context, index) {
                                          final reply = _replies[index];
                                          return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(vertical: 1.0),
                                              child: _buildPostContent(reply, isReply: true));
                                        },
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
    ));
  }
}