import 'package:chatter/controllers/data-controller.dart';
// import 'package:chatter/models/feed_models.dart'; // Removed import
import 'package:chatter/pages/home-feed-screen.dart';
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
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

// ReplyPage allows users to reply to a ChatterPost with text and attachments.
class ReplyPage extends StatefulWidget {
  final Map<String, dynamic> post; // Changed ChatterPost to Map<String, dynamic>

  const ReplyPage({Key? key, required this.post}) : super(key: key);

  @override
  _ReplyPageState createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  final TextEditingController _replyController = TextEditingController();
  final List<Map<String, dynamic>> _replyAttachments = []; // Changed List<Attachment> to List<Map<String, dynamic>>
  late DataController _dataController;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // State Variables for replies
  List<Map<String, dynamic>> _replies = []; // Changed List<ChatterPost> to List<Map<String, dynamic>>
  bool _isLoadingReplies = true;
  String? _fetchRepliesError;
  bool _isSubmittingReply = false; // Added state for reply submission

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
    _fetchPostReplies(); // Fetch replies when the page loads
  }

  // Method to fetch replies
  Future<void> _fetchPostReplies() async {
    if (mounted) {
      setState(() {
        _isLoadingReplies = true;
        _fetchRepliesError = null;
      });
    }
    try {
      final fetchedReplies = await _dataController.fetchReplies(widget.post['id'] as String); // Access 'id' via map key
      if (mounted) {
        setState(() {
          _replies = fetchedReplies; // Already List<Map<String, dynamic>> from DataController
          _isLoadingReplies = false;
        });
      }
    } catch (e) {
      print('Error fetching replies: $e');
      if (mounted) {
        setState(() {
          _fetchRepliesError = 'Failed to load replies. Please try again.';
          _isLoadingReplies = false;
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

    if (action == 'pdf' && sdkInt >= 33) {
      return true;
    }

    if (permission == null) return false;

    final status = await permission.request();
    if (status.isGranted) {
      return true;
    }

    _showSnackBar(
      '$permissionName Permission Required',
      status.isPermanentlyDenied
          ? 'Please enable $permissionName permission in app settings.'
          : 'Please grant $permissionName permission to continue.',
      Colors.red[700]!,
    );
    return false;
  }

  void _showSnackBar(String title, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message', style: GoogleFonts.roboto(color: Colors.white)),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Widget _buildPostContent(Map<String, dynamic> post, {required bool isReply}) {
    // Extract data using map keys, providing defaults or handling nulls
    final String username = post['username'] as String? ?? 'Unknown User';
    final String content = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    // Ensure avatarInitial is derived correctly or default
    final String avatarInitial = post['avatarInitial'] as String? ?? (username.isNotEmpty ? username[0].toUpperCase() : '?');
    // Handle timestamp parsing carefully
    final DateTime timestamp = post['timestamp'] is String
        ? (DateTime.tryParse(post['timestamp'] as String) ?? DateTime.now())
        : (post['timestamp'] is DateTime ? post['timestamp'] : DateTime.now());

    final List<Map<String, dynamic>> attachments = (post['attachments'] as List<dynamic>?)
        ?.map((att) => att as Map<String, dynamic>)
        .toList() ?? [];


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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '@$username', // Use extracted username
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: isReply ? 14 : 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a · MMM d').format(timestamp), // Use extracted timestamp
                        style: GoogleFonts.roboto(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content, // Use extracted content
                    style: GoogleFonts.roboto(
                      fontSize: isReply ? 13 : 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (attachments.isNotEmpty) ...[ // Use extracted attachments
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: attachments.length > 1 ? 2 : 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: attachments.length,
                      itemBuilder: (context, idx) {
                        final attachment = attachments[idx];
                        final displayUrl = attachment['url'] as String? ?? (attachment['file'] as File?)?.path ?? 'Unknown attachment';
                        final String attachmentType = attachment['type'] as String? ?? 'unknown';
                        final String? attachmentFilename = attachment['filename'] as String?;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MediaViewPage(
                                  attachments: attachments,
                                  initialIndex: idx,
                                  message: content,
                                  userName: username,
                                  userAvatarUrl: userAvatar,
                                  timestamp: timestamp,
                                  viewsCount: post['views'] as int? ?? 0, // Example, ensure these keys exist
                                  likesCount: post['likes'] as int? ?? 0,
                                  repostsCount: post['reposts'] as int? ?? 0,
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: attachmentType == "image"
                                ? (attachment['url'] != null
                                    ? Image.network(
                                        attachment['url'] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[900],
                                          child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40),
                                        ),
                                      )
                                    : (attachment['file'] as File?) != null
                                        ? Image.file(
                                            attachment['file'] as File,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey[900],
                                              child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40),
                                            ),
                                          )
                                        : Container( // Fallback if no URL and no file
                                            color: Colors.grey[900],
                                            child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40),
                                          ))
                                : attachmentType == "pdf"
                                    ? ((attachment['url'] != null || (attachment['file'] as File?) != null)
                                        ? PdfViewer.uri(
                                            attachment['url'] != null ? Uri.parse(attachment['url'] as String) : Uri.file((attachment['file'] as File).path),
                                            params: const PdfViewerParams(maxScale: 1.0),
                                          )
                                        : Container(
                                            color: Colors.grey[900],
                                            child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40),
                                          ))
                                    : Container( // Fallback for other types like video, audio
                                        color: Colors.grey[900],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              attachmentType == "audio" ? FeatherIcons.music : FeatherIcons.video, // Or other relevant icons
                                              color: Colors.tealAccent,
                                              size: 40,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              attachmentFilename ?? displayUrl.split('/').last,
                                              style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12),
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
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAndAddAttachment(String type) async {
    File? file;
    String dialogTitle = '';
    String message = '';

    try {
      if (!await _requestMediaPermissions(type)) return;

      if (type == "image") {
        dialogTitle = 'Upload Image';
        final picker = ImagePicker();
        final XFile? imageFile = await picker.pickImage(source: ImageSource.gallery);
        if (imageFile != null) file = File(imageFile.path);
      } else if (type == "video") {
        dialogTitle = 'Upload Video';
        final picker = ImagePicker();
        final XFile? videoFile = await picker.pickVideo(source: ImageSource.gallery);
        if (videoFile != null) file = File(videoFile.path);
      } else if (type == "pdf") {
        dialogTitle = 'Upload Document';
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) file = File(result.files.single.path!);
      } else if (type == "audio") {
        dialogTitle = 'Upload Audio';
        final result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) file = File(result.files.single.path!);
      }

      if (file != null) {
        final sizeInBytes = await file.length();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        if (sizeInMB <= 10) {
          setState(() {
            _replyAttachments.add({ // Add as Map<String, dynamic>
              'file': file,
              'type': type,
              'filename': file?.path.split('/').last,
              'size': sizeInBytes,
            });
          });
          message = '${type[0].toUpperCase()}${type.substring(1)} selected: ${file.path.split('/').last}';
          _showSnackBar(dialogTitle, message, Colors.teal[700]!);
        } else {
          message = 'File must be under 10MB!';
          _showSnackBar(dialogTitle, message, Colors.red[700]!);
        }
      } else {
        message = 'No file selected.';
        _showSnackBar(dialogTitle, message, Colors.red[700]!);
      }
    } catch (e) {
      message = 'Error picking $type: $e';
      _showSnackBar('Error', message, Colors.red[700]!);
    }
  }

  void _submitReply() async {
    if (_isSubmittingReply) return;

    if (_replyController.text.trim().isEmpty && _replyAttachments.isEmpty) {
      _showSnackBar('Input Error', 'Please enter text or add an attachment.', Colors.red[700]!);
      return;
    }

    setState(() {
      _isSubmittingReply = true;
    });

    List<Map<String, dynamic>> uploadedReplyAttachments = []; // Changed to List<Map<String, dynamic>>
    try {
      if (_replyAttachments.isNotEmpty) {
        // Filter for attachments that have a 'file' key and are not null
        final filesToUpload = _replyAttachments
            .where((a) => a['file'] != null && a['file'] is File)
            .map((a) => a['file'] as File)
            .toList();

        if (filesToUpload.isNotEmpty) {
          final uploadResults = await _dataController.uploadFiles(filesToUpload);

          // Correlate upload results with original attachments
          // This assumes uploadResults are in the same order as filesToUpload
          int uploadResultIndex = 0;
          for (var originalAttachment in _replyAttachments) {
            if (originalAttachment['file'] != null && originalAttachment['file'] is File) {
              // This attachment was intended for upload
              if (uploadResultIndex < uploadResults.length) {
                final result = uploadResults[uploadResultIndex];
                if (result['success'] == true && result['url'] != null) {
                  uploadedReplyAttachments.add({
                    'type': originalAttachment['type'],
                    'filename': originalAttachment['filename'] ?? result['filename'] ?? 'unknown',
                    'size': originalAttachment['size'] ?? result['size'] ?? 0,
                    'url': result['url'] as String,
                    'thumbnailUrl': result['thumbnailUrl'] as String?, // Ensure this is added
                  });
                } else {
                  _showSnackBar(
                    'Upload Error',
                    'Failed to upload ${originalAttachment['filename'] ?? 'a file'}: ${result['message'] ?? 'Unknown error'}',
                    Colors.red[700]!,
                  );
                }
                uploadResultIndex++;
              }
            } else if (originalAttachment['url'] != null) {
              // If an attachment already has a URL (e.g., pre-existing, though unlikely in this flow), pass it through
              uploadedReplyAttachments.add(originalAttachment);
            }
          }
        }
      }


      if (_replyController.text.trim().isEmpty &&
          uploadedReplyAttachments.isEmpty &&
          _replyAttachments.isNotEmpty) { // Check if original attachments were present but failed to upload
        _showSnackBar('Upload Error', 'Failed to upload attachments. Reply not sent.', Colors.red[700]!);
        setState(() { _isSubmittingReply = false; });
        return;
      }

      final result = await _dataController.replyToPost(
        postId: widget.post['id'] as String, // Access 'id' via map key
        content: _replyController.text.trim(),
        attachments: uploadedReplyAttachments, // Pass as List<Map<String, dynamic>>
      );

      if (result['success'] == true) {
        await _fetchPostReplies();
        _replyController.clear();
        if (mounted) {
          setState(() {
            _replyAttachments.clear();
          });
        }
        _showSnackBar('Success', result['message'] ?? 'Reply posted!', Colors.teal[700]!);

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _showSnackBar('Error', result['message'] ?? 'Failed to post reply.', Colors.red[700]!);
      }
    } catch (e) {
      print('Error in _submitReply: $e');
      _showSnackBar('Error', 'An unexpected error occurred: ${e.toString()}', Colors.red[700]!);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReply = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract username for AppBar title, providing a default
    final String postUsername = widget.post['username'] as String? ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Reply to @$postUsername', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
              ),
              child: _buildPostContent(widget.post, isReply: false),
            ),
            const SizedBox(height: 20),
            Text(
              "Replies",
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 8),
            // Display replies, loader, or error message
            _isLoadingReplies
                ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                : _fetchRepliesError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_fetchRepliesError!, style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 14)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _fetchPostReplies,
                              child: Text("Retry", style: GoogleFonts.roboto(color: Colors.black)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
                            )
                          ],
                        ),
                      )
                    : _replies.isEmpty
                        ? Center(
                            child: Text(
                              "No replies yet. Be the first to reply!",
                              style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true, // Important inside SingleChildScrollView
                            physics: const NeverScrollableScrollPhysics(), // Also important
                            itemCount: _replies.length,
                            itemBuilder: (context, index) {
                              final reply = _replies[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: _buildPostContent(reply, isReply: true), // Use existing method
                              );
                            },
                          ),
            const SizedBox(height: 20),
            TextField(
              controller: _replyController,
              maxLength: 280,
              maxLines: 3,
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Post your reply...",
                hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                counterStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.tealAccent),
                ),
                filled: true,
                fillColor: const Color(0xFF252525),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(FeatherIcons.image, color: Colors.tealAccent),
                  onPressed: () => _pickAndAddAttachment("image"),
                  tooltip: 'Add Image',
                ),
                IconButton(
                  icon: const Icon(FeatherIcons.fileText, color: Colors.tealAccent),
                  onPressed: () => _pickAndAddAttachment("pdf"),
                  tooltip: 'Add Document',
                ),
                IconButton(
                  icon: const Icon(FeatherIcons.music, color: Colors.tealAccent),
                  onPressed: () => _pickAndAddAttachment("audio"),
                  tooltip: 'Add Audio',
                ),
                IconButton(
                  icon: const Icon(FeatherIcons.video, color: Colors.tealAccent),
                  onPressed: () => _pickAndAddAttachment("video"),
                  tooltip: 'Add Video',
                ),
              ],
            ),
            if (_replyAttachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _replyAttachments.map((attachment) {
                  return Chip(
                    label: Text(
                      (attachment['filename'] ?? (attachment['file']?.path.split('/').last ?? '')) as String,
                      style: GoogleFonts.roboto(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: Colors.grey[800],
                    deleteIcon: const Icon(FeatherIcons.x, size: 16, color: Colors.white),
                    onDeleted: () {
                      setState(() {
                        _replyAttachments.remove(attachment);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isSubmittingReply ? null : _submitReply, // Disable if submitting
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey[600], // Optional: style for disabled state
                ),
                child: _isSubmittingReply
                    ? const SizedBox(
                        height: 20, // Adjust size as needed
                        width: 20,  // Adjust size as needed
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        'Post Reply',
                        style: GoogleFonts.roboto(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}