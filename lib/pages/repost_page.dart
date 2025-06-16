import 'package:chatter/pages/home-feed-screen.dart'; // For ChatterPost, Attachment, and potentially _buildPostContent if not refactored
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart'; // For icons if needed in _buildPostContent
import 'package:intl/intl.dart'; // For date formatting in _buildPostContent
import 'package:pdfrx/pdfrx.dart'; // If used by _buildPostContent

// It's generally better if ChatterPost and Attachment models are in their own files.
// Assuming they are still accessible via home-feed-screen.dart for now.

class RepostPage extends StatefulWidget {
  final ChatterPost post;

  const RepostPage({Key? key, required this.post}) : super(key: key);

  @override
  _RepostPageState createState() => _RepostPageState();
}

class _RepostPageState extends State<RepostPage> {

  // Reusing _buildPostContent from home-feed-screen.dart or reply_page.dart
  // For this subtask, let's assume we'll define a version of _buildPostContent here.
  // Ideally, _buildPostContent should be refactored into a shared widget if used in 3+ places.
  Widget _buildPostContent(ChatterPost post) {
    // This is a simplified version for displaying the post content.
    // It omits interactive elements like like/comment/repost buttons for the embedded view.
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
        color: Color(0xFF1A1A1A), // Slightly different background for emphasis
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                child: Text(
                  post.avatarInitial,
                  style: GoogleFonts.poppins(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
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
                            fontSize: 16,
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
                        fontSize: 14,
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
                          childAspectRatio: 1, // Keep aspect ratio 1 for simplicity
                        ),
                        itemCount: post.attachments.length,
                        itemBuilder: (context, idx) {
                          final attachment = post.attachments[idx];
                          final displayUrl = attachment.url ?? attachment.file.path;
                          // Media tapping will be handled by a navigation to MediaViewPage later
                          return ClipRRect(
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
                                        params: PdfViewerParams(maxScale: 1.0, ), // Simplified params
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
      ),
    );
  }

  void _confirmRepost() {
    // For now, we'll just pop and indicate success.
    // The home-feed-screen will handle the repost increment and SnackBar.
    Navigator.pop(context, true); // Pass true to indicate repost confirmed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000000),
      appBar: AppBar(
        title: Text('Repost', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Color(0xFF121212),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "You are about to repost this chatter:",
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            _buildPostContent(widget.post), // Display the post that will be reposted
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(FeatherIcons.repeat, color: Colors.black),
              label: Text(
                'Confirm Repost',
                style: GoogleFonts.roboto(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16),
              ),
              onPressed: _confirmRepost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Pass false to indicate cancellation
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 16),
              ),
              style: TextButton.styleFrom(
                 padding: EdgeInsets.symmetric(vertical: 15),
              )
            ),
          ],
        ),
      ),
    );
  }
}
