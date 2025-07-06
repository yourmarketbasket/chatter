import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/home-feed-screen.dart'; // Used for navigation context in example, keep for now
import 'package:chatter/pages/media_view_page.dart'; // Used for navigation
import 'package:chatter/widgets/reply/reply_input_area.dart';
import 'package:chatter/widgets/reply/post_content.dart';
import 'package:chatter/widgets/reply/actions_bottom_sheet.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'package:intl/intl.dart'; // No longer directly used here
import 'dart:io'; // Used by File operations, _downloadFile
import 'package:flutter/services.dart'; // Used by Clipboard
import 'package:feather_icons/feather_icons.dart'; // Used for icons in AppBar and reply area toggle
import 'package:google_fonts/google_fonts.dart'; // Used for text styles
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; // Used by _sharePost
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

  late Map<String, dynamic> _mainPostData;
  List<Map<String, dynamic>> _replies = []; // This will store replies hierarchically
  bool _isLoadingReplies = true;
  String? _fetchRepliesError;
  bool _isSubmittingReply = false;
  bool _showReplyField = false;
  String? _parentReplyId; // ID of the item (post or reply) we are directly replying to
  final FocusNode _replyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
    _mainPostData = Map<String, dynamic>.from(widget.post);
    if (_mainPostData['likes'] != null && _mainPostData['likes'] is List) {
      _mainPostData['likes'] = List<dynamic>.from(_mainPostData['likes'] as List);
    }
    if (_mainPostData['reposts'] != null && _mainPostData['reposts'] is List) {
      _mainPostData['reposts'] = List<dynamic>.from(_mainPostData['reposts'] as List);
    }

    _fetchPostReplies();

    final String currentPostId = _mainPostData['_id'] as String? ?? "";
    if (currentPostId.isNotEmpty) {
      if (widget.originalPostId == null) {
        _dataController.viewPost(currentPostId);
      } else {
        _dataController.viewReply(widget.originalPostId!, currentPostId);
      }
    } else {
      print("Error: Post ID is null in ReplyPage. Cannot record view.");
    }
  }

  // Recursive function to process fetched replies and their children
  Future<List<Map<String, dynamic>>> _processFetchedReplies(
      List<Map<String, dynamic>> fetchedReplies,
      String currentOriginalPostId,
      int currentDepth) async {

    // Define max depth for initial recursive fetching, e.g., 1 level deep from direct replies
    const int maxRecursiveFetchDepth = 1;

    List<Map<String, dynamic>> processed = [];
    for (var reply in fetchedReplies) {
      Map<String, dynamic> processedReply = Map<String, dynamic>.from(reply);
      processedReply['indentationLevel'] = currentDepth; // Set indent based on current depth

      // Check if this reply itself has children replies and we are within fetch depth
      bool hasChildren = (reply['repliesCount'] as int? ?? 0) > 0 || (reply['replies'] as List?)?.isNotEmpty == true;

      if (hasChildren && currentDepth < maxRecursiveFetchDepth) {
        try {
          print("[ReplyPage] Recursively fetching replies for reply ID: ${reply['_id']} at depth $currentDepth");
          List<Map<String, dynamic>> children = await _dataController.fetchRepliesForReply(
            currentOriginalPostId, // originalPostId of the root post of the thread
            reply['_id'] as String,  // parentReplyId for this fetch is the current reply's ID
          );
          // Recursively process these children, incrementing depth
          processedReply['children_replies'] = await _processFetchedReplies(children, currentOriginalPostId, currentDepth + 1);
        } catch (e) {
          print("Error fetching children for reply ${reply['_id']}: $e");
          processedReply['children_replies'] = []; // Default to empty on error
        }
      } else {
        processedReply['children_replies'] = []; // No children or max depth reached
      }
      processed.add(processedReply);
    }
    return processed;
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
        if (mounted) setState(() { _fetchRepliesError = 'Cannot load replies: Current item ID is missing.'; _isLoadingReplies = false; });
        return;
      }

      List<Map<String, dynamic>> fetchedRootReplies;
      // Determine the original post ID for the entire thread for recursive calls.
      // If widget.originalPostId is null, it means widget.post is the root post.
      // Otherwise, widget.originalPostId is the root post ID.
      final String threadOriginalPostId = widget.originalPostId ?? currentPostItemId;

      if (widget.originalPostId == null) { // This page is for a top-level post
        fetchedRootReplies = await _dataController.fetchReplies(currentPostItemId);
      } else { // This page is for a reply (widget.post is a reply)
        fetchedRootReplies = await _dataController.fetchRepliesForReply(widget.originalPostId!, currentPostItemId);
      }

      // Process replies and their children recursively, starting at depth 0 for direct replies
      _replies = await _processFetchedReplies(fetchedRootReplies, threadOriginalPostId, 0);

      if (mounted) {
        setState(() {
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
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<File?> _downloadFile(String url, String filename, String type) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        String extension;
        switch (type) {
          case 'image': extension = path.extension(url).isNotEmpty ? path.extension(url) : '.jpg'; break;
          case 'video': extension = path.extension(url).isNotEmpty ? path.extension(url) : '.mp4'; break;
          case 'pdf': extension = '.pdf'; break;
          case 'audio': extension = path.extension(url).isNotEmpty ? path.extension(url) : '.mp3'; break;
          default: extension = path.extension(url).isNotEmpty ? path.extension(url) : '.bin';
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
      attachments = rawAttachments.whereType<Map>().map((item) => Map<String, dynamic>.from(item.map((key, value) => MapEntry(key.toString(), value)))).toList();
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
        file = await _downloadFile(url!, filename!, type!);
        if (file != null) {
          filePaths.add(file.path);
        } else {
          _showSnackBar('Error', 'Failed to download $type: $filename', Colors.red[700]!);
        }
      }
    }

    if (filePaths.isNotEmpty) {
      final xFiles = filePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(xFiles, text: content.isNotEmpty ? content : null, subject: 'Shared from Chatter');
    } else {
      await Share.share(content.isNotEmpty ? content : 'Check out this post from Chatter!', subject: 'Shared from Chatter');
    }
  }

  void _showSnackBar(String title, String message, Color backgroundColor, {bool isSuccess = false}) {
    if (isSuccess) return; // Skip success snackbars

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$title: $message', style: GoogleFonts.roboto(color: Colors.white)),
        backgroundColor: backgroundColor));
  }

  void _showActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      builder: (BuildContext context) {
        return ActionsBottomSheetContent(
          post: _mainPostData,
          showSnackBar: (title, message, color) => _showSnackBar(title, message, color), // Pass non-success version
        );
      },
    );
  }

  void _submitReply() async {
    if (_isSubmittingReply) return;
    if (_replyController.text.trim().isEmpty && _replyAttachments.isEmpty) {
      _showSnackBar('Input Error', 'Please enter text or add an attachment.', Colors.red[700]!);
      return;
    }
    if (mounted) setState(() { _isSubmittingReply = true; }); else return;

    List<Map<String, dynamic>> uploadedReplyAttachments = [];
    try {
      if (_replyAttachments.isNotEmpty) {
        final filesToUpload = _replyAttachments.where((a) => a['file'] != null && a['file'] is File).map((a) => {'file': a['file'], 'type': a['type'], 'filename': a['filename'], 'size': a['size']}).toList();
        if (filesToUpload.isNotEmpty) {
          final uploadResults = await _dataController.uploadFiles(filesToUpload);
          int uploadResultIndex = 0;
          for (var originalAttachment in _replyAttachments) {
            if (originalAttachment['file'] != null && originalAttachment['file'] is File) {
              if (uploadResultIndex < uploadResults.length) {
                final result = uploadResults[uploadResultIndex];
                if (result['success'] == true && result['url'] != null) {
                  uploadedReplyAttachments.add({'type': originalAttachment['type'], 'filename': originalAttachment['filename'] ?? result['filename'] ?? 'unknown', 'size': originalAttachment['size'] ?? result['size'] ?? 0, 'url': result['url'] as String, 'thumbnailUrl': result['thumbnailUrl'] as String?});
                } else {
                  _showSnackBar('Upload Error', 'Failed to upload ${originalAttachment['filename'] ?? 'a file'}: ${result['message'] ?? 'Unknown error'}', Colors.red[700]!);
                }
                uploadResultIndex++;
              }
            } else if (originalAttachment['url'] != null) {
              uploadedReplyAttachments.add(originalAttachment);
            }
          }
        }
      }
      if (_replyController.text.trim().isEmpty && uploadedReplyAttachments.isEmpty && _replyAttachments.isNotEmpty) {
        _showSnackBar('Upload Error', 'Failed to upload attachments. Reply not sent.', Colors.red[700]!);
        if (mounted) setState(() { _isSubmittingReply = false; });
        return;
      }

      final String ultimateRootPostId = widget.originalPostId ?? widget.post['_id']!;
      Map<String, dynamic> result;

      if (_parentReplyId == null) {
        // This implies the reply is to the main content of the page (widget.post)
        // This case should ideally be covered by onReplyToItem setting _parentReplyId = widget.post['_id']
        // However, as a fallback or if the "Show Reply Field" button is used without a specific target:
        _parentReplyId = widget.post['_id']!;
        print("Warning: _parentReplyId was null in _submitReply. Defaulting to widget.post._id: ${_parentReplyId}");
      }

      // Now, _parentReplyId is the ID of the item being directly replied to.

      // Check if the item we are replying to (_parentReplyId) is the actual root post of the entire thread.
      if (_parentReplyId == ultimateRootPostId) {
        // We are making a direct reply to the root post of the thread.
        final replyToPostData = {
          'postId': _parentReplyId, // The ID of the root post.
          'content': _replyController.text.trim(),
          'attachments': uploadedReplyAttachments,
        };
        print("[ReplyPage] Submitting reply to ROOT post: $replyToPostData");
        result = await _dataController.replyToPost(replyToPostData);
      } else {
        // We are replying to another reply.
        // The item we are replying to is _parentReplyId.
        // The root of its thread is ultimateRootPostId.
        final replyToReplyData = {
          'postId': ultimateRootPostId,    // ID of the original root post of the thread.
          'parentReplyId': _parentReplyId!, // ID of the reply we are directly replying to.
          'content': _replyController.text.trim(),
          'attachments': uploadedReplyAttachments,
        };
        print("[ReplyPage] Submitting reply to REPLY: $replyToReplyData");
        result = await _dataController.replyToReply(replyToReplyData);
      }

      if (!mounted) return;

      if (result['success'] == true) {
        // _showSnackBar('Success', result['message'] ?? 'Reply posted!', Colors.teal[700]!, isSuccess: true);
        _replyController.clear();
        if(mounted) setState(() { _replyAttachments.clear(); });

        await _fetchPostReplies(showLoadingIndicator: false); // Refresh replies list

        if(mounted) {
          setState(() {
            _parentReplyId = null;
            _showReplyField = false;
          });
        }
      } else {
        _showSnackBar('Error', result['message'] ?? 'Failed to post reply.', Colors.red[700]!);
      }
    } catch (e) {
      print('Error in _submitReply: $e');
      if (mounted) {
         _showSnackBar('Error', 'An unexpected error occurred: ${e.toString()}', Colors.red[700]!);
      }
    } finally {
      if (mounted) {
        setState(() { _isSubmittingReply = false; });
      }
    }
  }


  // Builds the list of replies, including first-level replies and previews of their sub-replies.
  List<Widget> _buildRepliesListWidgets() {
    List<Widget> widgets = [];
    if (_replies == null) return widgets;

    // Define constants for avatar and padding to calculate line positions
    const double firstLevelAvatarRadius = 14.0; // From PostContent for isReply=true
    const double avatarRightPadding = 12.0; // Padding to the right of avatar in PostContent
    // Space allocated for the main vertical line and visual separation before content starts
    const double lineAndAvatarAreaTotalWidth = 20.0; // Matches PostContent's internal line area (avatarRadius + 6 for line)
    // Indentation for the content of first-level replies, after the line/avatar area
    const double firstLevelContentIndent = firstLevelAvatarRadius * 2 + avatarRightPadding; // Standard content start after avatar

    for (int i = 0; i < _replies.length; i++) {
      final firstLevelReply = _replies[i];
      final bool isLastFirstLevelReplyInList = i == _replies.length - 1;

      List<Widget> subReplyWidgets = [];
      final List<Map<String, dynamic>> childrenReplies = List<Map<String, dynamic>>.from(firstLevelReply['children_replies'] ?? []);

      if (childrenReplies.isNotEmpty) {
        int subRepliesToShow = childrenReplies.length > 3 ? 3 : childrenReplies.length;
        for (int j = 0; j < subRepliesToShow; j++) {
          final subReply = childrenReplies[j];
          subReplyWidgets.add(
            PostContent(
              postData: subReply,
              isReply: true,
              indentationLevel: 1,
              isPreview: true,
              pageOriginalPostId: widget.originalPostId ?? widget.post['_id'] as String,
              showSnackBar: (title, message, color) => _showSnackBar(title, message, color),
              onSharePost: _sharePost,
              onReplyToItem: (String itemId) { setState(() { _parentReplyId = itemId; _showReplyField = true; FocusScope.of(context).requestFocus(_replyFocusNode); }); },
              refreshReplies: () => _fetchPostReplies(showLoadingIndicator: false),
              onReplyDataUpdated: (updatedReply) {
                if (mounted) {
                  setState(() {
                    final parentIndex = _replies.indexWhere((r) => r['_id'] == firstLevelReply['_id']);
                    if (parentIndex != -1) {
                      final childrenList = _replies[parentIndex]['children_replies'] as List<Map<String,dynamic>>?;
                      if (childrenList != null) {
                        final childIndex = childrenList.indexWhere((c) => c['_id'] == updatedReply['_id']);
                        if (childIndex != -1) childrenList[childIndex] = updatedReply;
                      }
                    }
                  });
                }
              },
            ),
          );
        }
        if (childrenReplies.length > 3) {
          subReplyWidgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 4.0, bottom: 8.0), // Indent "show more" slightly more
              child: TextButton(
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => ReplyPage(post: firstLevelReply, originalPostId: widget.originalPostId ?? widget.post['_id'] as String)));
                },
                child: Text('Show ${childrenReplies.length - 3} more replies', style: GoogleFonts.poppins(color: Colors.tealAccent, fontSize: 13)),
              ),
            ),
          );
        }
      }

      // Group first-level reply and its sub-replies for line painting
      Widget contentGroup = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostContent( // First-level reply
            postData: firstLevelReply,
            isReply: true,
            indentationLevel: 0,
            isPreview: false,
            drawInternalVerticalLine: false, // Main line is handled by _MainReplyLinePainter
            pageOriginalPostId: widget.originalPostId ?? widget.post['_id'] as String,
            showSnackBar: (title, message, color) => _showSnackBar(title, message, color),
            onSharePost: _sharePost,
            onReplyToItem: (String itemId) { setState(() { _parentReplyId = itemId; _showReplyField = true; FocusScope.of(context).requestFocus(_replyFocusNode); }); },
            refreshReplies: () => _fetchPostReplies(showLoadingIndicator: false),
            onReplyDataUpdated: (updatedReply) { if (mounted) setState(() => _updateNestedReply(_replies, updatedReply)); },
          ),
          if (subReplyWidgets.isNotEmpty)
            Padding(
              // Sub-replies content should be indented relative to the start of the first-level reply's content area.
              // The first-level reply's PostContent itself will handle its internal padding for its text.
              // This padding here is for the *block* of sub-replies.
              // It should be indented by `indentationLevel: 1`'s offset (20.0) from where the parent content begins.
              // The parent content begins after `lineAndAvatarAreaTotalWidth`.
              // So, this should effectively be `20.0` to align with PostContent's level 1 indent.
              padding: const EdgeInsets.only(left: 20.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: subReplyWidgets),
            ),
        ],
      );

      widgets.add(
        IntrinsicHeight( // Ensure Stack children can be measured if needed, though painter might not need it.
          child: Stack(
            children: [
              // The CustomPaint for the main vertical line.
              // It's positioned at the start of the Stack, and contentGroup is padded left.
              Positioned.fill(
                child: CustomPaint(
                  painter: _MainReplyLinePainter(
                    lineX: lineAndAvatarAreaTotalWidth / 2, // Centered in the allocated space
                    avatarRadius: firstLevelAvatarRadius,
                    hasNextSibling: !isLastFirstLevelReplyInList,
                    // hasChildren is not strictly needed by the painter if we don't draw a horizontal connector yet
                    // but keeping it doesn't harm and might be useful for future enhancements.
                    hasChildren: childrenReplies.isNotEmpty,
                  ),
                ),
              ),
              Padding(
                // Shift contentGroup to the right to make space for the line drawing area
                padding: const EdgeInsets.only(left: lineAndAvatarAreaTotalWidth),
                child: contentGroup,
              ),
            ],
          ),
        )
      );

      if (!isLastFirstLevelReplyInList) {
        // Divider's indent should align with the start of the content of first-level replies
        // which is after lineAndAvatarAreaTotalWidth + PostContent's internal avatar area (left padding of PostContent for avatar + avatar width + right padding of avatar)
        // PostContent for level 0 has effective avatar area start at 0, avatar radius 14, right padding 12.
        // So content starts after 0 + 14*2 + 12 = 40 from its own left edge.
        // The left edge of PostContent is already lineAndAvatarAreaTotalWidth from the Stack's left.
        // So, indent = lineAndAvatarAreaTotalWidth. (No, this is where the content *starts*, PostContent handles its own avatar padding)
        // The divider should start where the text content of the PostContent starts.
        // PostContent's padding logic: left: widget.isReply ? indentOffset : 8.0. For level 0 reply, indentOffset is 0.
        // Then avatar area. Avatar: CircleAvatar(radius: 14). Padding around avatar: right: 12.0.
        // So text starts roughly at lineAndAvatarAreaTotalWidth + (isReply ? 0 : 8.0) + 14 (avatar radius, for center) + 12 (avatar right padding).
        // Let's use the previously defined firstLevelContentIndent which is from very left.
        // The contentGroup is already padded by lineAndAvatarAreaTotalWidth.
        // PostContent's internal padding for its content (after avatar) is what matters here.
        // For a level 0 reply, PostContent's avatar is at left:0 (within its box), radius 14, right padding 12. Content starts after that.
        // So, the indent for the divider should be: lineAndAvatarAreaTotalWidth + (avatarRadius + avatarRightPadding)
        // No, it's simpler: lineAndAvatarAreaTotalWidth + (firstLevelAvatarRadius + avatarRightPadding + firstLevelAvatarRadius (other side of avatar))
        // Let's use: lineAndAvatarAreaTotalWidth + firstLevelAvatarRadius (center of avatar) + avatarRightPadding (space after avatar)
        // Or more simply, align with the start of PostContent's main text body.
        // PostContent's text is inside an Expanded Column, which is sibling to avatar's Padding.
        // Avatar padding: EdgeInsets.only(left: widget.isReply ? indentOffset : 8.0, right: 12.0). For level 0 reply, left is 0.
        // So, the space for avatar is radius + right padding.
        // The text starts after the avatar. So the divider indent from the edge of the contentGroup is radius + right padding.
        // The contentGroup itself is padded by lineAndAvatarAreaTotalWidth.
        // So, total indent: lineAndAvatarAreaTotalWidth + firstLevelAvatarRadius + avatarRightPadding.
        widgets.add(Divider(color: Colors.grey[800], height: 1, indent: lineAndAvatarAreaTotalWidth + firstLevelAvatarRadius + avatarRightPadding, endIndent: 10));
      }
    }
    return widgets;
  }

  // Helper to find and update a reply in a nested list (can be simplified if only one level of children is managed in state)
  bool _updateNestedReply(List<Map<String, dynamic>> listToSearch, Map<String, dynamic> updatedReply) {
    for (int i = 0; i < listToSearch.length; i++) {
      if (listToSearch[i]['_id'] == updatedReply['_id']) {
        listToSearch[i] = updatedReply;
        return true;
      }
      if (listToSearch[i]['children_replies'] != null && (listToSearch[i]['children_replies'] as List).isNotEmpty) {
        if (_updateNestedReply(List<Map<String, dynamic>>.from(listToSearch[i]['children_replies'] as List), updatedReply)) {
          return true;
        }
      }
    }
    return false;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Post', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.moreVertical, color: Colors.white),
            onPressed: _showActionsBottomSheet,
            tooltip: 'More Actions',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container( // Main Post Display
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: PostContent(
                        postData: _mainPostData,
                        isReply: false, // Main post is not a reply in its own context
                        isPreview: false, // Main post is not a preview
                        indentationLevel: 0,
                        pageOriginalPostId: widget.originalPostId,
                        showSnackBar: (title, message, color) => _showSnackBar(title, message, color),
                        onSharePost: _sharePost,
                        onReplyToItem: (String itemId) { // itemId here is _mainPostData['_id']
                          setState(() {
                            _parentReplyId = itemId;
                            _showReplyField = true;
                            FocusScope.of(context).requestFocus(_replyFocusNode);
                          });
                          // _showSnackBar('Reply', 'Replying to main post...', Colors.teal[700]!, isSuccess: true); // Removed
                        },
                        refreshReplies: () => _fetchPostReplies(showLoadingIndicator: false),
                        onReplyDataUpdated: (updatedPost) {
                          if (mounted) setState(() { _mainPostData = updatedPost; });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding( // Replies Section
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0, top:0.0), // Added horizontal padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row( // "Replies" title and action buttons
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _isLoadingReplies && _fetchRepliesError == null
                                ? Row(children: [ Text("Reloading Replies...", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[400])), const SizedBox(width: 8), const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent)))])
                                : Text("Replies", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                            Row(children: [
                              IconButton(icon: const Icon(Icons.refresh, color: Colors.tealAccent), tooltip: "Refresh Replies", onPressed: () => _fetchPostReplies(showLoadingIndicator: true)),
                              IconButton(icon: Icon(_showReplyField ? FeatherIcons.messageCircle : FeatherIcons.edit3, color: Colors.tealAccent), tooltip: _showReplyField ? "Hide Reply Field" : "Show Reply Field", onPressed: () { setState(() { _showReplyField = !_showReplyField; if (!_showReplyField) _parentReplyId = null;}); }),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _isLoadingReplies && _fetchRepliesError == null
                            ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator(color: Colors.tealAccent)))
                            : _fetchRepliesError != null
                                ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Text("Couldn't load replies. Tap refresh to try again.", style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center)))
                                : _replies.isEmpty
                                    ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Text("No replies yet.", style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14))))
                                    : Column(children: _buildRepliesList(_replies, 0)), // Use recursive builder
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showReplyField)
            ReplyInputArea(
              replyFocusNode: _replyFocusNode,
              parentReplyId: _parentReplyId, // This is the ID of the item being replied to
              mainPost: widget.post, // The main post of the page, for context
              currentReplies: _replies, // Pass current replies for context if needed by input area
              showSnackBar: (title, message, color) => _showSnackBar(title, message, color),
              onSubmitReply: ({ required String content, required List<Map<String, dynamic>> attachments, required String? parentId /* This parentId is the one from ReplyInputArea, which is _parentReplyId */}) {
                _replyController.text = content;
                _replyAttachments.clear();
                _replyAttachments.addAll(attachments);
                // _parentReplyId is already set correctly by onReplyToItem
                _submitReply();
              },
              isSubmittingReply: _isSubmittingReply,
            ),
        ],
      ),
    );
  }
}