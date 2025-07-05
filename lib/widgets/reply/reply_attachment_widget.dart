import 'dart:io';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart'; // Ensure this import is correct based on your project

class ReplyAttachmentDisplayWidget extends StatelessWidget {
  final Map<String, dynamic> attachmentMap;
  final int currentIndex; // Renamed from idx to avoid conflict if used in a loop
  final List<Map<String, dynamic>> allAttachmentsInThisPost;
  final Map<String, dynamic> postOrReplyData;
  final BorderRadius borderRadius;

  const ReplyAttachmentDisplayWidget({
    Key? key,
    required this.attachmentMap,
    required this.currentIndex,
    required this.allAttachmentsInThisPost,
    required this.postOrReplyData,
    required this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String attachmentType = attachmentMap['type'] as String? ?? 'unknown';
    final String? displayUrl = attachmentMap['url'] as String?;
    // final String? thumbnailUrl = attachmentMap['thumbnailUrl'] as String?; // Not used in original code block
    final String? attachmentFilename = attachmentMap['filename'] as String?;
    final File? localFile =
        attachmentMap['file'] is File ? attachmentMap['file'] as File? : null;

    final String messageContent = postOrReplyData['content'] as String? ?? '';
    final String userName = postOrReplyData['username'] as String? ?? 'Unknown User';
    final String? userAvatarUrl = postOrReplyData['useravatar'] as String?;
    final DateTime timestamp = postOrReplyData['createdAt'] is String
        ? (DateTime.tryParse(postOrReplyData['createdAt'] as String) ?? DateTime.now())
        : (postOrReplyData['createdAt'] is DateTime
            ? postOrReplyData['createdAt'] as DateTime // Ensure correct casting
            : DateTime.now());

    final int viewsCount =
        postOrReplyData['viewsCount'] as int? ?? (postOrReplyData['views'] as List?)?.length ?? 0;
    final int likesCount =
        postOrReplyData['likesCount'] as int? ?? (postOrReplyData['likes'] as List?)?.length ?? 0;
    final int repostsCount =
        postOrReplyData['repostsCount'] as int? ?? (postOrReplyData['reposts'] as List?)?.length ?? 0;

    Widget contentWidget;

    final String attachmentKeySuffix;
    if (attachmentMap['_id'] != null && (attachmentMap['_id'] as String).isNotEmpty) {
      attachmentKeySuffix = attachmentMap['_id'] as String;
    } else if (attachmentMap['url'] != null && (attachmentMap['url'] as String).isNotEmpty) {
      attachmentKeySuffix = attachmentMap['url'] as String;
    } else {
      attachmentKeySuffix = currentIndex.toString();
      print(
          "Warning: Reply attachment for post/reply ${postOrReplyData['_id']} at index $currentIndex is using an index-based key suffix. Data: $attachmentMap");
    }

    if (attachmentType == "video") {
      // Assuming VideoAttachmentWidget is already in lib/widgets/
      contentWidget = VideoAttachmentWidget(
        key: Key('video_reply_att_$attachmentKeySuffix'),
        attachment: attachmentMap,
        post: postOrReplyData,
        borderRadius: borderRadius,
        enforceFeedConstraints: false, // As per original usage
      );
    } else if (attachmentType == "image") {
      if (displayUrl != null && displayUrl.isNotEmpty) {
        contentWidget = Image.network(
          displayUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[900],
              child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)),
        );
      } else if (localFile != null) {
        contentWidget = Image.file(
          localFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[900],
              child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)),
        );
      } else {
        contentWidget = Container(
            color: Colors.grey[900],
            child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40));
      }
    } else if (attachmentType == "pdf") {
      final uri = displayUrl != null
          ? Uri.tryParse(displayUrl)
          : (localFile != null ? Uri.file(localFile.path) : null);
      if (uri != null) {
        // Using PdfThumbnailWidget from pdfrx package
        contentWidget = PdfThumbnail.uri(
          uri,
          // Removed PdfThumbnailWidget specific parameters not present in PdfThumbnail.uri
          // aspectRatio: 4/3, // PdfThumbnail determines its own aspect ratio
          errorBuilder: (context, error, stackTrace) => Container(
             color: Colors.grey[900],
             child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(FeatherIcons.fileText, color: Colors.redAccent, size: 30),
                  const SizedBox(height: 4),
                  Text("PDF Error", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white70))
                ],
            )
          ),
          loadingBuilder: (context, progress) => Center(child: CircularProgressIndicator(value: progress, color: Colors.tealAccent, backgroundColor: Colors.grey[800],)),
          // onTap: () { // onTap is handled by the parent GestureDetector
          //   int initialIndex = allAttachmentsInThisPost.indexWhere((att) =>
          //       (att['url'] != null && att['url'] == attachmentMap['url']) ||
          //       (att.hashCode == attachmentMap.hashCode));
          //   if (initialIndex == -1) initialIndex = currentIndex;

          //   Navigator.push(
          //     context,
          //     MaterialPageRoute(
          //       builder: (context) => MediaViewPage(
          //         attachments: allAttachmentsInThisPost,
          //         initialIndex: initialIndex,
          //         message: messageContent,
          //         userName: userName,
          //         userAvatarUrl: userAvatarUrl,
          //         timestamp: timestamp,
          //         viewsCount: viewsCount,
          //         likesCount: likesCount,
          //         repostsCount: repostsCount,
          //       ),
          //     ),
          //   );
          // },
        );
      } else {
        contentWidget = Container(
            color: Colors.grey[900],
            child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40));
      }
    } else if (attachmentType == "audio") {
      // Assuming AudioAttachmentWidget is already in lib/widgets/
      contentWidget = AudioAttachmentWidget(
        key: Key('audio_reply_att_$attachmentKeySuffix'),
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
            const Icon(FeatherIcons.film, color: Colors.tealAccent, size: 40), // Default icon
            const SizedBox(height: 8),
            Text(
                attachmentFilename ?? (displayUrl ?? 'unknown').split('/').last,
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
            (att.hashCode == attachmentMap.hashCode)); // Fallback to hashcode might be unreliable if objects change
        if (initialIndex == -1) initialIndex = currentIndex;

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
}

// Helper widget for PdfThumbnail if custom onTap is needed directly on it.
// For this refactor, the GestureDetector above handles the tap.
class PdfThumbnailWidget extends StatelessWidget {
  final String pdfUrl;
  final double aspectRatio;
  final VoidCallback onTap;

  const PdfThumbnailWidget({
    Key? key,
    required this.pdfUrl,
    this.aspectRatio = 4 / 3,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(pdfUrl);
    if (uri == null) {
      return Container(
          color: Colors.grey[900],
          child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40));
    }
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: PdfThumbnail.uri(
          uri,
          // Removed PdfThumbnailWidget specific parameters not present in PdfThumbnail.uri
          // aspectRatio: 4/3, // PdfThumbnail determines its own aspect ratio
          errorBuilder: (context, error, stackTrace) => Container(
             color: Colors.grey[900],
             child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(FeatherIcons.fileText, color: Colors.redAccent, size: 30),
                  const SizedBox(height: 4),
                  Text("PDF Error", style: GoogleFonts.roboto(fontSize: 10, color: Colors.white70))
                ],
            )
          ),
          loadingBuilder: (context, progress) => Center(child: CircularProgressIndicator(value: progress, color: Colors.tealAccent, backgroundColor: Colors.grey[800],)),
        ),
      ),
    );
  }
}
