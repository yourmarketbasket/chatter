import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/home-feed-screen.dart'; // For ChatterPost, Attachment
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart'; // If needed for displaying attachments in original post

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

  // Adapted from _buildPostContent in home-feed-screen.dart
  Widget _buildPostContent(ChatterPost post, {required bool isReply}) {
    // This function needs to be adapted.
    // For simplicity, we'll copy the relevant parts from home-feed-screen.dart's _buildPostContent.
    // Note: This might need further adjustments if _buildPostContent relies on _HomeFeedScreenState methods directly.
    // For now, we assume it can be mostly self-contained or can access what it needs via the 'post' object.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 16 : 20,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              child: Text(
                post.avatarInitial,
                style: GoogleFonts.poppins(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: isReply ? 14 : 16,
                ),
              ),
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
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: post.attachments.length > 1 ? 2 : 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: post.attachments.length,
                      itemBuilder: (context, idx) {
                        final attachment = post.attachments[idx];
                        final displayUrl = attachment.url ?? attachment.file.path;
                        // Media tapping will be handled by a navigation to MediaViewPage later
                        return GestureDetector(
                          onTap: () {
                            // TODO: Navigate to MediaViewPage
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Media tap placeholder: Opening ${attachment.type}',
                                  style: GoogleFonts.roboto(color: Colors.white)
                                ),
                                backgroundColor: Colors.blueGrey,
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
                                          child: Icon(FeatherIcons.image, color: Colors.grey[500], size: 40),
                                        ),
                                      )
                                    : Image.file(
                                        attachment.file,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[900],
                                          child: Icon(FeatherIcons.image, color: Colors.grey[500], size: 40),
                                        ),
                                      )
                                : attachment.type == "pdf"
                                    ? PdfViewer.uri( // Assuming PdfViewer can take a file URI too if not uploaded
                                        attachment.url != null ? Uri.parse(attachment.url!) : Uri.file(attachment.file.path),
                                        params: PdfViewerParams(maxScale: 1.0),
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
                                            SizedBox(height: 8),
                                            Text(
                                              displayUrl.split('/').last,
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
                  // Action buttons (like, comment, repost, views) are not shown for the main post on this page,
                  // but they would be for replies if we were nesting further.
                  // For simplicity, we'll omit them for the main post display here.
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
    String successMessage = '';

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
      final sizeInMB = file.lengthSync() / (1024 * 1024);
      if (sizeInMB <= 10) {
        setState(() {
          _replyAttachments.add(Attachment(file: file, type: type));
        });
        successMessage = '${type[0].toUpperCase()}${type.substring(1)} selected: ${file.path.split('/').last}';
      } else {
        successMessage = 'File must be under 10MB!';
      }
    } else {
      successMessage = 'No file selected.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage, style: GoogleFonts.roboto(color: Colors.white)),
        backgroundColor: file != null && (file.lengthSync() / (1024*1024) <=10) ? Colors.teal[700] : Colors.red[700],
      ),
    );
  }

  void _submitReply() async {
    if (_replyController.text.trim().isEmpty && _replyAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter text or add an attachment.', style: GoogleFonts.roboto(color: Colors.white)),
        backgroundColor: Colors.red[700],
      ));
      return;
    }

    // Simulate file upload and post creation (adapted from _showRepliesDialog)
    List<Attachment> uploadedReplyAttachments = [];
    if (_replyAttachments.isNotEmpty) {
        List<File> filesToUpload = _replyAttachments.map((a) => a.file).toList();
        try {
            List<Map<String, dynamic>> uploadResults = await _dataController.uploadFilesToCloudinary(filesToUpload);
            for (int i = 0; i < _replyAttachments.length; i++) {
                var result = uploadResults[i];
                if (result['success'] == true) {
                    uploadedReplyAttachments.add(Attachment(
                        file: _replyAttachments[i].file, // Keep original file for local display if needed, though URL is primary
                        type: _replyAttachments[i].type,
                        url: result['url'] as String,
                    ));
                } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Failed to upload ${_replyAttachments[i].file.path.split('/').last}: ${result['message']}', style: GoogleFonts.roboto(color: Colors.white)),
                        backgroundColor: Colors.red[700],
                    ));
                }
            }
        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Error during file upload: $e', style: GoogleFonts.roboto(color: Colors.white)),
                backgroundColor: Colors.red[700],
            ));
            return; // Stop if upload fails
        }
    }

    if (_replyController.text.trim().isEmpty && uploadedReplyAttachments.isEmpty && _replyAttachments.isNotEmpty) {
        // This case means initial attachments were there, but all failed to upload.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to upload all attachments. Reply not sent.', style: GoogleFonts.roboto(color: Colors.white)),
            backgroundColor: Colors.red[700],
        ));
        return;
    }


    // TODO: Replace with actual backend call to add reply
    // For now, we'll add it to the local list and pop.
    // In a real app, this would involve sending data to DataController/backend
    // and then likely refreshing the post's replies or getting updated data.

    final newReply = ChatterPost(
      username: "YourName", // Replace with actual username
      content: _replyController.text.trim(),
      timestamp: DateTime.now(),
      attachments: uploadedReplyAttachments,
      avatarInitial: "Y", // Replace with actual avatar initial
      // likes, reposts, views for a new reply would be 0
    );

    // This is a local update. The actual update should happen via DataController and backend.
    // For now, we'll pass this new reply back if the previous screen wants to update its state.
    Navigator.pop(context, newReply);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Poa! Reply posted!', style: GoogleFonts.roboto(color: Colors.white)),
      backgroundColor: Colors.teal[700],
    ));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000000),
      appBar: AppBar(
        title: Text('Reply to @${widget.post.username}', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Color(0xFF121212),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display the original post
            Container(
              padding: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
              ),
              child: _buildPostContent(widget.post, isReply: false),
            ),
            SizedBox(height: 20),

            // Display existing replies (if any)
            if (widget.post.replies.isNotEmpty)
              Text(
                "Replies",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            if (widget.post.replies.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: widget.post.replies.length,
                separatorBuilder: (context, index) => Divider(color: Colors.grey[800], height: 1),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16.0), // Indent replies
                    child: _buildPostContent(widget.post.replies[index], isReply: true),
                  );
                },
              ),
            SizedBox(height: 20),

            // Reply input section (similar to _showRepliesDialog)
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
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
                filled: true,
                fillColor: Color(0xFF252525),
              ),
            ),
            SizedBox(height: 12),
            // Attachment buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(FeatherIcons.image, color: Colors.tealAccent),
                  onPressed: () => _pickAndAddAttachment("image"),
                  tooltip: 'Add Image',
                ),
                IconButton(
                  icon: Icon(FeatherIcons.fileText, color: Colors.tealAccent),
                  onPressed: () => _pickAndAddAttachment("pdf"),
                  tooltip: 'Add Document',
                ),
                IconButton(
                  icon: Icon(FeatherIcons.music, color: Colors.tealAccent),
                  onPressed: () => _pickAndAddAttachment("audio"),
                  tooltip: 'Add Audio',
                ),
                IconButton(
                  icon: Icon(FeatherIcons.video, color: Colors.tealAccent),
                  onPressed: () => _pickAndAddAttachment("video"),
                  tooltip: 'Add Video',
                ),
              ],
            ),
            // Display selected attachments
            if (_replyAttachments.isNotEmpty) ...[
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _replyAttachments.map((attachment) {
                  return Chip(
                    label: Text(
                      attachment.file.path.split('/').last,
                      style: GoogleFonts.roboto(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: Colors.grey[800],
                    deleteIcon: Icon(FeatherIcons.x, size: 16, color: Colors.white),
                    onDeleted: () {
                      setState(() {
                        _replyAttachments.remove(attachment);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: 20),
            // Submit button
            Center(
              child: ElevatedButton(
                onPressed: _submitReply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
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
