import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/home-feed-screen.dart'; // Used for navigation context in example, keep for now
import 'package:chatter/pages/media_view_page.dart'; // Used for navigation
// import 'package:chatter/widgets/video_attachment_widget.dart'; // Moved to ReplyAttachmentDisplayWidget
// import 'package:chatter/widgets/reply/stat_button.dart'; // No longer directly used in reply_page
import 'package:chatter/widgets/reply/reply_input_area.dart';
import 'package:chatter/widgets/reply/post_content.dart';
import 'package:chatter/widgets/reply/actions_bottom_sheet.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Keep for potential direct use or if PostContent usage implies a general need.
// import 'package:file_picker/file_picker.dart'; // Now handled by ReplyInputArea
import 'dart:io'; // Used by File operations, _downloadFile
// import 'dart:convert'; // Moved to PostContent
import 'package:flutter/services.dart'; // Used by Clipboard
import 'package:feather_icons/feather_icons.dart'; // Used for icons in AppBar and reply area toggle
import 'package:google_fonts/google_fonts.dart'; // Used for text styles
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; // Used by _sharePost
// import 'package:image_picker/image_picker.dart'; // Now handled by ReplyInputArea
// import 'package:pdfrx/pdfrx.dart'; // Moved to ReplyAttachmentDisplayWidget
// import 'package:permission_handler/permission_handler.dart'; // Now handled by ReplyInputArea
// import 'package:device_info_plus/device_info_plus.dart'; // Now handled by ReplyInputArea
// import 'package:chatter/widgets/audio_attachment_widget.dart'; // Moved to ReplyAttachmentDisplayWidget
import 'package:http/http.dart' as http; // Used by _downloadFile
import 'package:path_provider/path_provider.dart'; // Used by _downloadFile
import 'package:path/path.dart' as path; // Used by _downloadFile

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
    // final String postUsername = widget.post['username'] as String? ?? 'User'; // No longer needed here directly
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C), // Or pass color to ActionsBottomSheetContent if you want it configurable there
      builder: (BuildContext context) {
        return ActionsBottomSheetContent(
          post: _mainPostData, // Use _mainPostData which is the mutable version of widget.post
          showSnackBar: _showSnackBar,
        );
      },
    );
  }

// Widget _buildPostContent(Map<String, dynamic> postData, {required bool isReply, int indentLevel = 0}) { // Renamed post to postData
// Removed the large block of code that was the old _buildPostContent method and its helpers.
// Also removed _buildReplyAttachmentWidget, _buildReplyAttachmentGrid, _parseAspectRatio.
// Methods like _pickAndAddAttachment and _showAttachmentPicker were moved to ReplyInputArea.
// _getAndroidSdkVersion and _requestMediaPermissions were also part of ReplyInputArea's context.

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
      final currentItemPostId = widget.post['_id'] as String?; // ID of the item this page is currently focused on
      if (currentItemPostId == null) {
        _showSnackBar('Error', 'Cannot post reply: Current item ID is missing.', Colors.red[700]!);
        if (mounted) setState(() { _isSubmittingReply = false; });
        return;
      }

      // Determine the true original post ID of the thread.
      // If widget.originalPostId is set, this ReplyPage is for a reply, so that's the root.
      // Otherwise, this ReplyPage is for an original post, so widget.post['_id'] is the root.
      final String threadOriginalPostId = widget.originalPostId ?? currentItemPostId;

      Map<String, dynamic> result;
      // Determine if it's a reply to the main item of this page or a reply to another reply listed on this page
      if (_parentReplyId != null && _parentReplyId != currentItemPostId) { // Replying to a listed reply
        final replyToReplyData = {
          // This 'postId' for the backend API call must be the ultimate original post ID of the thread.
          'postId': threadOriginalPostId,
          'parentReplyId': _parentReplyId, // This is the ID of the reply we are directly replying to
          'content': _replyController.text.trim(),
          'attachments': uploadedReplyAttachments,
        };
        result = await _dataController.replyToReply(replyToReplyData);
      } else { // Replying to the main item displayed on this ReplyPage
        final replyToPostData = {
          // If replying to the main item of the page:
          // - If this page is for an original post (widget.originalPostId == null), then currentItemPostId is the original post's ID.
          // - If this page is for a reply (widget.originalPostId != null), then currentItemPostId is that reply's ID,
          //   and threadOriginalPostId is the original post's ID.
          // The backend's replyToPost expects 'postId' to be the ID of the item being directly replied to.
          // If that item is itself a reply, the backend might handle nesting it under the originalPostId.
          // Let's assume replyToPost is for replying to a root post,
          // and replyToReply is for replying to a reply (which needs originalPostId and parentReplyId).

          // If _parentReplyId is null OR _parentReplyId is the same as currentItemPostId,
          // it means we are replying to the main item this page is about.
          // If this main item is an original post:
          'postId': currentItemPostId, // The ID of the item we are directly replying to on this page.
                                      // If this item is an original post, this is fine.
                                      // If this item is a reply (i.e., widget.originalPostId != null),
                                      // then this call should technically be a replyToReply.
                                      // The existing logic for setting _parentReplyId might simplify this:
                                      // - onReplyToItem for the main post sets _parentReplyId = mainPostId
                                      // - onReplyToItem for a listed reply sets _parentReplyId = replyId
                                      // So, if _parentReplyId == currentItemPostId, we're replying to the main item.

          // Correct logic:
          // If _parentReplyId is set and is *not* the currentItemPostId, it's a reply to a listed reply (handled above).
          // Otherwise, we're replying to the main item of the page (currentItemPostId).
          // If this currentItemPostId is actually a reply (i.e., widget.originalPostId is not null),
          // then we should use the replyToReply endpoint.
          'content': _replyController.text.trim(),
          'attachments': uploadedReplyAttachments,
        };

        if (widget.originalPostId != null) { // The main item of this page is already a reply
          // We are replying to widget.post (which is a reply). So use replyToReply.
          // _parentReplyId would be currentItemPostId in this case if "reply" on main post was hit.
          final actualParentReplyId = _parentReplyId ?? currentItemPostId;
          result = await _dataController.replyToReply({
            'postId': threadOriginalPostId, // Ultimate root post
            'parentReplyId': actualParentReplyId, // The reply we are replying to
            'content': _replyController.text.trim(),
            'attachments': uploadedReplyAttachments,
          });
        } else { // The main item of this page is an original post.
          // We are replying to widget.post (which is an original post). So use replyToPost.
          // _parentReplyId would be currentItemPostId here.
          result = await _dataController.replyToPost({
            'postId': currentItemPostId, // The original post we are replying to
            'content': _replyController.text.trim(),
            'attachments': uploadedReplyAttachments,
          });
        }
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
           // currentItemPostId is the ID of the main post/reply this page is for.
           if (_parentReplyId != null && _parentReplyId != currentItemPostId) { // If we replied to a listed reply (not the main item)
            await _fetchPostReplies(showLoadingIndicator: false); // Refresh to get nested replies updated
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
    // final String postUsername = widget.post['username'] as String? ?? 'User'; // No longer directly used here for AppBar title logic
    // final DateTime parsedTimestamp = widget.post['createdAt'] is String // No longer directly used here
    //     ? (DateTime.tryParse(widget.post['createdAt'] as String) ??
    //         DateTime.now())
    //     : (widget.post['createdAt'] is DateTime
    //         ? widget.post['createdAt']
    //         : DateTime.now());

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
                      // child: _buildPostContent(widget.post, isReply: false), // Old way
                      child: PostContent(
                        postData: _mainPostData, // Use the mutable _mainPostData
                        isReply: false,
                        pageOriginalPostId: widget.originalPostId, // Pass the page's original post ID
                        showSnackBar: _showSnackBar,
                        onSharePost: _sharePost,
                        onReplyToItem: (String itemId) {
                          setState(() {
                            _parentReplyId = itemId; // This will be the main post's ID
                            _showReplyField = true;
                            FocusScope.of(context).requestFocus(_replyFocusNode);
                          });
                          _showSnackBar('Reply', 'Replying to main post...', Colors.teal[700]!);
                        },
                        refreshReplies: () => _fetchPostReplies(showLoadingIndicator: false),
                        onReplyDataUpdated: (updatedPost) {
                          // This callback is for when the main post's data (likes, reposts) is changed by PostContent actions
                          if (mounted) {
                            setState(() {
                              _mainPostData = updatedPost;
                            });
                          }
                        },
                      ),
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
                                            padding: const EdgeInsets.symmetric(vertical: 1.0),
                                            // child: _buildPostContent(reply, isReply: true), // Old way
                                            child: PostContent(
                                              postData: reply,
                                              isReply: true,
                                              pageOriginalPostId: widget.originalPostId ?? widget.post['_id'] as String, // Root post ID of the thread
                                              showSnackBar: _showSnackBar,
                                              onSharePost: _sharePost,
                                              onReplyToItem: (String itemId) {
                                                setState(() {
                                                  _parentReplyId = itemId; // This is the ID of the reply being replied to
                                                  _showReplyField = true;
                                                  FocusScope.of(context).requestFocus(_replyFocusNode);
                                                });
                                                final replyingToUser = reply['username'] ?? 'user';
                                                _showSnackBar('Reply', 'Replying to @$replyingToUser...', Colors.teal[700]!);
                                              },
                                              refreshReplies: () => _fetchPostReplies(showLoadingIndicator: false),
                                              onReplyDataUpdated: (updatedReply) {
                                                // This callback is for when a reply's data (likes, reposts) is changed
                                                if (mounted) {
                                                  setState(() {
                                                    final replyIndex = _replies.indexWhere((r) => r['_id'] == updatedReply['_id']);
                                                    if (replyIndex != -1) {
                                                      _replies[replyIndex] = updatedReply;
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                          );
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
          if (_showReplyField)
            ReplyInputArea(
              replyFocusNode: _replyFocusNode,
              parentReplyId: _parentReplyId,
              mainPost: widget.post,
              currentReplies: _replies,
              showSnackBar: _showSnackBar,
              onSubmitReply: ({
                required String content,
                required List<Map<String, dynamic>> attachments,
                required String? parentId,
              }) {
                // Update controller and attachments from the child widget if necessary,
                // though the child now manages its own controller and attachments.
                // For this handoff, we'll use the values it passes up.
                _replyController.text = content; // Keep it in sync if needed elsewhere, or remove if not.
                _replyAttachments.clear();
                _replyAttachments.addAll(attachments);
                // _parentReplyId is already set by the UI interaction that shows the ReplyInputArea or by tapping reply on a post/reply
                _submitReply(); // Call the existing submit logic
              },
              isSubmittingReply: _isSubmittingReply, // Pass the state here
            ),
        ],
      ),
    );
  }

// Removed _buildReplyInputArea, _pickAndAddAttachment, _showAttachmentPicker,
// _getAndroidSdkVersion, _requestMediaPermissions as they are now part of ReplyInputArea widget or handled there.
// The _submitReply method in ReplyPage will now be called by the callback from ReplyInputArea.
// _replyController and _replyAttachments in ReplyPage state might still be used by _submitReply,
// or _submitReply can be refactored to take content and attachments directly.
// For now, _submitReply will use the state variables which are updated by the callback.

// Removed _buildPostContent, _buildReplyAttachmentWidget, _buildReplyAttachmentGrid,
// and _parseAspectRatio methods as they are now part of their respective new widget files.
// Helper methods like _sharePost, _downloadFile are kept in ReplyPage if they are general utilities
// or called by multiple parts of the page. _showSnackBar is also kept.
// _showActionsBottomSheet is still here, will be handled in the next step.

}