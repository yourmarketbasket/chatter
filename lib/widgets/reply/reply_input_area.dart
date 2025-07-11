import 'dart:io';
import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ReplyInputArea extends StatefulWidget {
  final FocusNode replyFocusNode;
  final String? parentReplyId; // ID of the post/reply being replied to
  final Map<String, dynamic> mainPost; // The main post of the page
  final List<Map<String, dynamic>> currentReplies; // List of current replies on the page
  final Function(String title, String message, Color backgroundColor) showSnackBar;
  final Function({
    required String content,
    required List<Map<String, dynamic>> attachments,
    required String? parentId, // This will be parentReplyId or mainPostId
  }) onSubmitReply; // Callback to submit the reply
  final bool isSubmittingReply; // To show loading indicator

  const ReplyInputArea({
    Key? key,
    required this.replyFocusNode,
    this.parentReplyId,
    required this.mainPost,
    required this.currentReplies,
    required this.showSnackBar,
    required this.onSubmitReply,
    required this.isSubmittingReply,
  }) : super(key: key);

  @override
  _ReplyInputAreaState createState() => _ReplyInputAreaState();
}

class _ReplyInputAreaState extends State<ReplyInputArea> {
  final TextEditingController _replyController = TextEditingController();
  final List<Map<String, dynamic>> _replyAttachments = [];
  // bool _isSubmittingReply = false; // This state is now passed from the parent
  late DataController _dataController;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();


  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
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
      widget.showSnackBar('Error', 'Unable to determine Android version. Check permissions in settings.', Colors.red[700]!);
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
        // For PDF, MANAGE_EXTERNAL_STORAGE might be needed for broader access on Android 11+ (API 30+),
        // but standard storage permission is used for < API 30.
        // For API 33+, no specific permission for PDF if accessed via FilePicker.
        // Let's assume FilePicker handles its own permission needs for PDF on API 33+.
        permission = sdkInt < 33 ? Permission.storage : null; // Only request storage for older SDKs for PDF
        permissionName = 'Storage';
        break;
      default:
        return false;
    }

    // If permission is null (e.g., PDF on SDK 33+), assume FilePicker handles it or no direct permission needed.
    if (permission == null) return true;

    final status = await permission.request();
    if (status.isGranted) return true;

    widget.showSnackBar('$permissionName Permission Required',
        status.isPermanentlyDenied
            ? 'Please enable $permissionName permission in app settings.'
            : 'Please grant $permissionName permission to continue.',
        Colors.red[700]!);
    return false;
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
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
        }
      } else if (type == "audio") {
        dialogTitle = 'Upload Audio';
        final result = await FilePicker.platform
            .pickFiles(type: FileType.audio, allowMultiple: false);
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
        }
      }

      if (pickedFile != null) file = File(pickedFile.path);

      if (file != null) {
        final sizeInBytes = await file.length();
        final double sizeInMB = sizeInBytes / (1024 * 1024);

        if (sizeInMB > 20) { // Example size limit
          message =
              'File "${file.path.split('/').last}" is too large (${sizeInMB.toStringAsFixed(1)}MB). Must be under 20MB.';
          widget.showSnackBar(dialogTitle, message, Colors.red[700]!);
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
        // Success message for selection removed
        // message =
        //     '${type[0].toUpperCase()}${type.substring(1)} selected: ${file.path.split('/').last}';
        // widget.showSnackBar(dialogTitle, message, Colors.teal[700]!);
        print('${type[0].toUpperCase()}${type.substring(1)} selected: ${file.path.split('/').last}');
      } else {
        // message = 'No file selected for $type.'; // User might cancel, not always an error
        // Non-error snackbar for 'no file selected' also removed.
        // widget.showSnackBar(dialogTitle, message, Colors.orange);
      }
    } catch (e) {
      message = 'Error picking $type: $e';
      widget.showSnackBar('Error', message, Colors.red[700]!);
    }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E), // Dark background for the sheet
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

  void _handleInternalSubmit() async {
    if (_replyController.text.trim().isEmpty && _replyAttachments.isEmpty) {
      widget.showSnackBar('Input Error', 'Please enter text or add an attachment.', Colors.red[700]!);
      return;
    }
    // Call the passed onSubmitReply callback
    // The actual submission logic (uploading, API call) will be handled by the parent (ReplyPage)
    // to keep this widget focused on UI and input gathering.
    widget.onSubmitReply(
      content: _replyController.text.trim(),
      attachments: List<Map<String, dynamic>>.from(_replyAttachments), // Pass a copy
      parentId: widget.parentReplyId ?? widget.mainPost['_id'] as String?,
    );

    // Clear fields after initiating submission via callback
    // The parent will handle the _isSubmittingReply state and actual clearing/refreshing based on API response.
    _replyController.clear();
    if (mounted) {
      setState(() {
        _replyAttachments.clear();
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final currentUserData = _dataController.user.value['user'] as Map<String, dynamic>?;
    final String? currentUserAvatar = currentUserData?['avatar'] as String?;
    final String currentUserInitial = currentUserData?['name'] != null && (currentUserData!['name'] as String).isNotEmpty
        ? (currentUserData['name'] as String)[0].toUpperCase()
        : '?';

    String hintText = "Post your reply...";
    if (widget.parentReplyId != null) {
      // Find the user we are replying to
      final parentReply = widget.currentReplies.firstWhere(
        (r) => r['_id'] == widget.parentReplyId,
        orElse: () => widget.mainPost['_id'] == widget.parentReplyId ? widget.mainPost : {}, // Check if replying to main post
      );
      if (parentReply.isNotEmpty && parentReply['username'] != null) {
        hintText = "Reply to @${parentReply['username']}...";
      } else if (widget.mainPost['_id'] == widget.parentReplyId && widget.mainPost['username'] != null){
        hintText = "Reply to @${widget.mainPost['username']}...";
      }
       else {
        hintText = "Reply to selected message...";
      }
    }


    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.transparent, // Blends with Scaffold background
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_replyAttachments.isNotEmpty) ...[
              SizedBox(
                height: 45,
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
                          (attachment['filename'] ?? (attachment['file'] as File?)?.path.split('/').last ?? 'Preview'),
                          style: GoogleFonts.roboto(color: Colors.white, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                        backgroundColor: Colors.grey[800],
                        deleteIcon: const Icon(FeatherIcons.xCircle, size: 16, color: Colors.white70),
                        onDeleted: () {
                          if(mounted) {
                            setState(() { _replyAttachments.remove(attachment); });
                          }
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                    focusNode: widget.replyFocusNode,
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    ),
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 280, // Standard character limit
                    buildCounter: (BuildContext context, {int? currentLength, int? maxLength, bool? isFocused}) => null, // Hide counter
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(FeatherIcons.paperclip, color: Colors.tealAccent, size: 22),
                  onPressed: _showAttachmentPicker,
                  tooltip: 'Add Media',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                // Use the passed-in isSubmittingReply to show loading indicator
                widget.isSubmittingReply
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.tealAccent),
                      ),
                    )
                  : TextButton(
                  onPressed: _handleInternalSubmit,
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
      ),
    );
  }
}
