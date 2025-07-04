import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/video_attachment_widget.dart'; // Import VideoAttachmentWidget
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

  List<Map<String, dynamic>> _replies = [];
  bool _isLoadingReplies = true;
  String? _fetchRepliesError;
  bool _isSubmittingReply = false;
  bool _showReplyField = true; // To toggle reply input field visibility

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
    _fetchPostReplies();

    if (widget.post['_id'] != null) {
      _dataController.viewPost(widget.post['_id'] as String);
    } else {
      print("Error: Post ID is null in ReplyPage. Cannot record view.");
    }
  }

  Future<void> _fetchPostReplies({bool showLoadingIndicator = true}) async {
    if (mounted) {
      setState(() {
        if (showLoadingIndicator) _isLoadingReplies = true;
        _fetchRepliesError = null;
      });
    }
    try {
      final fetchedReplies = await _dataController.fetchReplies(widget.post['id'] as String);
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
      case 'image': permission = sdkInt >= 33 ? Permission.photos : Permission.storage; permissionName = 'Photos'; break;
      case 'video': permission = sdkInt >= 33 ? Permission.videos : Permission.storage; permissionName = 'Videos'; break;
      case 'audio': permission = sdkInt >= 33 ? Permission.audio : Permission.storage; permissionName = 'Audio'; break;
      case 'pdf': permission = sdkInt < 33 ? Permission.storage : null; permissionName = 'Storage'; break;
      default: return false;
    }
    if (action == 'pdf' && sdkInt >= 33) return true;
    if (permission == null) return false;
    final status = await permission.request();
    if (status.isGranted) return true;
    _showSnackBar('$permissionName Permission Required', status.isPermanentlyDenied ? 'Please enable $permissionName permission in app settings.' : 'Please grant $permissionName permission to continue.', Colors.red[700]!);
    return false;
  }

  void _showSnackBar(String title, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title: $message', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: backgroundColor));
  }

  Widget _buildPostContent(Map<String, dynamic> post, {required bool isReply}) {
    final String username = post['username'] as String? ?? 'Unknown User';
    final String content = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    final String avatarInitial = post['avatarInitial'] as String? ?? (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = post['timestamp'] is String ? (DateTime.tryParse(post['timestamp'] as String) ?? DateTime.now()) : (post['timestamp'] is DateTime ? post['timestamp'] : DateTime.now());

    List<Map<String, dynamic>> correctlyTypedAttachments = [];
    final dynamic rawAttachments = post['attachments'];
    if (rawAttachments is List) {
      for (var item in rawAttachments) {
        if (item is Map<String, dynamic>) {
          correctlyTypedAttachments.add(item);
        } else if (item is Map) {
          try {
            correctlyTypedAttachments.add(Map<String, dynamic>.from(item));
          } catch (e) {
            print('Error converting attachment Map: $e');
          }
        }
      }
    }

    // Stats for original post
    final int likesCount = widget.post['likesCount'] as int? ?? (widget.post['likes'] as List?)?.length ?? 0;
    final int repostsCount = widget.post['repostsCount'] as int? ?? (widget.post['reposts'] as List?)?.length ?? 0;
    final int viewsCount = widget.post['viewsCount'] as int? ?? (widget.post['views'] as List?)?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 16 : 20,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
              child: userAvatar == null || userAvatar.isEmpty ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: isReply ? 14 : 16)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('@$username', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isReply ? 14 : 16, color: Colors.white)),
                      Text(DateFormat('h:mm a · MMM d').format(timestamp), style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(content, style: GoogleFonts.roboto(fontSize: isReply ? 13 : 14, color: Colors.white70, height: 1.5)),
                  if (correctlyTypedAttachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildReplyAttachmentGrid(correctlyTypedAttachments, post, username, userAvatar, timestamp, viewsCount, likesCount, repostsCount, content),
                  ],
                  if (!isReply) ...[ // Show stats only for the main post, not for replies in this context
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat(FeatherIcons.heart, '$likesCount Likes', Colors.pinkAccent),
                        _buildStat(FeatherIcons.repeat, '$repostsCount Reposts', Colors.greenAccent),
                        _buildStat(FeatherIcons.eye, '$viewsCount Views', Colors.blueAccent),
                        IconButton(icon: const Icon(FeatherIcons.share2, color: Colors.white70, size: 18), onPressed: () { /* TODO: Implement Share */ }),
                        IconButton(icon: const Icon(FeatherIcons.bookmark, color: Colors.white70, size: 18), onPressed: () { /* TODO: Implement Bookmark */ }),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12)),
      ],
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
        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: false);
        if (result != null && result.files.single.path != null) file = File(result.files.single.path!);
      } else if (type == "audio") {
        dialogTitle = 'Upload Audio';
        final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
        if (result != null && result.files.single.path != null) file = File(result.files.single.path!);
      }

      if (pickedFile != null) file = File(pickedFile.path);

      if (file != null) {
        final sizeInBytes = await file.length();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        if (sizeInMB <= 20) { // Increased limit
          setState(() {
            _replyAttachments.add({'file': file, 'type': type, 'filename': file?.path.split('/').last, 'size': sizeInBytes});
          });
          message = '${type[0].toUpperCase()}${type.substring(1)} selected: ${file.path.split('/').last}';
          _showSnackBar(dialogTitle, message, Colors.teal[700]!);
        } else {
          message = 'File must be under 20MB!';
          _showSnackBar(dialogTitle, message, Colors.red[700]!);
        }
      } else if (type == "pdf" || type == "audio") { // For FilePicker types if file is already set
        // This path might be redundant if `file` is already set from FilePicker result.
        // Keeping for safety, but can be simplified.
        if (file != null) {
             // Duplicated logic from above, ideally refactor
            final sizeInBytes = await file.length();
            final sizeInMB = sizeInBytes / (1024 * 1024);
             if (sizeInMB <= 20) {
                setState(() { _replyAttachments.add({'file': file, 'type': type, 'filename': file?.path.split('/').last, 'size': sizeInBytes}); });
                message = '${type[0].toUpperCase()}${type.substring(1)} selected: ${file.path.split('/').last}';
                _showSnackBar(dialogTitle, message, Colors.teal[700]!);
            } else {
                message = 'File must be under 20MB!';
                _showSnackBar(dialogTitle, message, Colors.red[700]!);
            }
        } else {
            message = 'No file selected.';
            _showSnackBar(dialogTitle, message, Colors.red[700]!);
        }
      }
      else {
        message = 'No file selected.';
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
                title: Text('Image', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("image");
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.video, color: Colors.tealAccent),
                title: Text('Video', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("video");
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.fileText, color: Colors.tealAccent),
                title: Text('PDF Document', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("pdf");
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.music, color: Colors.tealAccent),
                title: Text('Audio', style: GoogleFonts.roboto(color: Colors.white)),
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
      _showSnackBar('Input Error', 'Please enter text or add an attachment.', Colors.red[700]!);
      return;
    }
    setState(() { _isSubmittingReply = true; });
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
        setState(() { _isSubmittingReply = false; });
        return;
      }
      final result = await _dataController.replyToPost(postId: widget.post['id'] as String, content: _replyController.text.trim(), attachments: uploadedReplyAttachments);
      if (result['success'] == true && result['reply'] != null) {
        final newReply = result['reply'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _replies.insert(0, newReply);
            _replyController.clear();
            _replyAttachments.clear();
          });
        }
        _showSnackBar('Success', result['message'] ?? 'Reply posted!', Colors.teal[700]!);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context, true);
      } else if (result['success'] == true && result['reply'] == null) {
        _showSnackBar('Success', result['message'] ?? 'Reply posted! Refreshing...', Colors.teal[700]!);
        await _fetchPostReplies();
        _replyController.clear();
        if (mounted) setState(() { _replyAttachments.clear(); });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, true);
      } else {
        _showSnackBar('Error', result['message'] ?? 'Failed to post reply.', Colors.red[700]!);
      }
    } catch (e) {
      print('Error in _submitReply: $e');
      _showSnackBar('Error', 'An unexpected error occurred: ${e.toString()}', Colors.red[700]!);
    } finally {
      if (mounted) setState(() { _isSubmittingReply = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Post', style: GoogleFonts.poppins(color: Colors.white)), // Changed title
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column( // Use Column to manage Reply Input area separately
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
                    child: _buildPostContent(widget.post, isReply: false),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Text("Replies", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                       _isLoadingReplies && _fetchRepliesError == null // Show "Trying to refresh" only when actively loading without prior error
                        ? Row(
                            children: [
                               Text("Reloading Replies...", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[400])),
                               const SizedBox(width: 8),
                               const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent))),
                            ],
                          )
                        : Text("Replies", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.tealAccent),
                            tooltip: "Refresh Replies",
                            onPressed: () => _fetchPostReplies(showLoadingIndicator: true), // Explicitly show loader
                          ),
                          IconButton(
                            icon: Icon(_showReplyField ? FeatherIcons.messageCircle : FeatherIcons.edit3, color: Colors.tealAccent),
                            tooltip: _showReplyField ? "Hide Reply Field" : "Show Reply Field",
                            onPressed: () {
                              setState(() {
                                _showReplyField = !_showReplyField;
                              });
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isLoadingReplies && _fetchRepliesError == null
                      ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator(color: Colors.tealAccent)))
                      : _fetchRepliesError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20.0),
                                child: Text(
                                  "Couldn't load replies. Tap refresh to try again.",
                                  style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : _replies.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                                    child: Text(
                                      "No replies yet.",
                                      style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _replies.length,
                                  itemBuilder: (context, index) {
                                    final reply = _replies[index];
                                    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: _buildPostContent(reply, isReply: true));
                                  },
                                ),
                ],
              ),
            ),
          ),
          if (_showReplyField) _buildReplyInputArea(), // Conditionally display reply input
        ],
      ),
    );
  }

  Widget _buildReplyInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Slightly different background for input area
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyAttachments.isNotEmpty) ...[
             SizedBox(
              height: 60, // Fixed height for attachment previews in reply area
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _replyAttachments.map((attachment) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                      avatar: attachment['type'] == 'image' ? const Icon(FeatherIcons.image, size:16)
                            : attachment['type'] == 'video' ? const Icon(FeatherIcons.video, size:16)
                            : attachment['type'] == 'audio' ? const Icon(FeatherIcons.music, size:16)
                            : const Icon(FeatherIcons.file, size:16),
                      label: Text(
                        (attachment['filename'] ?? (attachment['file']?.path.split('/').last ?? 'Preview')),
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: Colors.grey[700],
                      deleteIcon: const Icon(FeatherIcons.x, size: 14, color: Colors.white70),
                      onDeleted: () {
                        setState(() {
                          _replyAttachments.remove(attachment);
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end, // Align items to the bottom
            children: [
              IconButton(
                icon: const Icon(FeatherIcons.paperclip, color: Colors.tealAccent, size: 22),
                onPressed: _showAttachmentPicker, // Updated to single picker
                tooltip: 'Add Media',
              ),
              Expanded(
                child: TextField(
                  controller: _replyController,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Post your reply...",
                    hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                    border: InputBorder.none, // Minimalist field
                    contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 0),
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 5, // Allow field to grow
                  maxLength: 280, // Keep char limit
                  buildCounter: (BuildContext context, {int? currentLength, int? maxLength, bool? isFocused}) => null, // Hide counter if desired
                ),
              ),
              _isSubmittingReply
                  ? const Padding(
                      padding: EdgeInsets.all(12.0), // Consistent padding with IconButton
                      child: SizedBox(
                        height: 24, width: 24, // Match IconButton tap target size
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(FeatherIcons.send, color: Colors.tealAccent, size: 22),
                      onPressed: _submitReply,
                      tooltip: 'Post Reply',
                    ),
            ],
          ),
        ],
      ),
    );
  }
}