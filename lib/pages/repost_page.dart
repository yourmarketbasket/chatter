import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';

// RepostPage allows users to confirm reposting a ChatterPost.
class RepostPage extends StatefulWidget {
  final ChatterPost post;

  const RepostPage({Key? key, required this.post}) : super(key: key);

  @override
  _RepostPageState createState() => _RepostPageState();
}

class _RepostPageState extends State<RepostPage> {
  Widget _buildPostContent(ChatterPost post) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
        color: const Color(0xFF1A1A1A),
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
                    const SizedBox(height: 6),
                    Text(
                      post.content,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
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
                                  builder: (context) => MediaViewPage(attachment: attachment),
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
    Navigator.pop(context, true); // Indicate repost confirmed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Repost', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
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
            const SizedBox(height: 20),
            _buildPostContent(widget.post),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(FeatherIcons.repeat, color: Colors.black),
              label: Text(
                'Confirm Repost',
                style: GoogleFonts.roboto(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16),
              ),
              onPressed: _confirmRepost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Indicate cancellation
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.roboto(color: Colors.tealAccent, fontSize: 16),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}