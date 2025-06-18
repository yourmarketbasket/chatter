import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/feed_models.dart';
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
  final ChatterPost post;

  const ReplyPage({Key? key, required this.post}) : super(key: key);

  @override
  _ReplyPageState createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  final TextEditingController _replyController = TextEditingController();
  final List<Attachment> _replyAttachments = [];
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
            const SizedBox(width: 12),
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
                  const SizedBox(height: 6),
                  Text(
                    post.content,
                    style: GoogleFonts.roboto(
                      fontSize: isReply ? 13 : 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (post.attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: post.attachments.length > 1 ? 2 : 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: post.attachments.length,
                      itemBuilder: (context, idx) {
                        final attachment = post.attachments[idx];
                        final displayUrl = attachment.url ?? attachment.file?.path ?? 'Unknown attachment';
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MediaViewPage(
                                  attachments: post.attachments, // The full list of attachments from the original post
                                  initialIndex: idx,            // The index of the tapped attachment in the GridView
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
                            borderRadius: BorderRadius.circular(12),
                            child: attachment.type == "image"
                                ? attachment.url != null
                                    ? Image.network(
                                        attachment.url!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[900],
                                          child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40),
                                        ),
                                      )
                                    : attachment.file != null
                                        ? Image.file(
                                            attachment.file!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey[900],
                                              child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey[900],
                                            child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40),
                                          )
                                : attachment.type == "pdf"
                                    ? (attachment.url != null || attachment.file != null)
                                        ? PdfViewer.uri(
                                            attachment.url != null ? Uri.parse(attachment.url!) : Uri.file(attachment.file!.path),
                                            params: const PdfViewerParams(maxScale: 1.0),
                                          )
                                        : Container(
                                            color: Colors.grey[900],
                                            child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40),
                                          )
                                    : Container(
                                        color: Colors.grey[900],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              attachment.type == "audio" ? FeatherIcons.music : FeatherIcons.video,
                                              color: Colors.tealAccent,
                                              size: 40,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              attachment.filename ?? displayUrl.split('/').last,
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
            _replyAttachments.add(Attachment(
              file: file,
              type: type,
              filename: file?.path.split('/').last,
              size: sizeInBytes,
            ));
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
    if (_replyController.text.trim().isEmpty && _replyAttachments.isEmpty) {
      _showSnackBar('Input Error', 'Please enter text or add an attachment.', Colors.red[700]!);
      return;
    }

    List<Attachment> uploadedReplyAttachments = [];
    if (_replyAttachments.isNotEmpty) {
      final filesToUpload = _replyAttachments.map((a) => a.file!).toList();
      try {
        final uploadResults = await _dataController.uploadFilesToCloudinary(filesToUpload);
        for (int i = 0; i < _replyAttachments.length; i++) {
          final result = uploadResults[i];
          if (result['success'] == true) {
            uploadedReplyAttachments.add(Attachment(
              file: _replyAttachments[i].file,
              type: _replyAttachments[i].type,
              filename: _replyAttachments[i].filename,
              size: _replyAttachments[i].size,
              url: result['url'] as String,
            ));
          } else {
            _showSnackBar(
              'Upload Error',
              'Failed to upload ${_replyAttachments[i].filename}: ${result['message']}',
              Colors.red[700]!,
            );
          }
        }
      } catch (e) {
        _showSnackBar('Upload Error', 'Error during file upload: $e', Colors.red[700]!);
        return;
      }
    }

    if (_replyController.text.trim().isEmpty && uploadedReplyAttachments.isEmpty && _replyAttachments.isNotEmpty) {
      _showSnackBar('Upload Error', 'Failed to upload all attachments. Reply not sent.', Colors.red[700]!);
      return;
    }

    final replyData = {
      'username': _dataController.user.value['name'] ?? 'YourName',
      'content': _replyController.text.trim(),
      'useravatar': _dataController.user.value['avatar'] ?? '',
      'attachments': uploadedReplyAttachments.map((att) => {
        'filename': att.filename,
        'url': att.url,
        'size': att.size,
        'type': att.type,
      }).toList(),
      'avatarInitial': (_dataController.user.value['name']?.isNotEmpty ?? false)
          ? _dataController.user.value['name'][0].toUpperCase()
          : 'Y',
    };

    Navigator.pop(context, replyData);
    _showSnackBar('Success', 'Poa! Reply posted!', Colors.teal[700]!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Reply to @${widget.post.username}', style: GoogleFonts.poppins(color: Colors.white)),
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
            Text(
              "Replies are not displayed here. They will appear in the main feed.",
              style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
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
                      attachment.filename ?? attachment.file!.path.split('/').last,
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
                onPressed: _submitReply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
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