import 'dart:io';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';

class ReplyAttachmentDisplayWidget extends StatelessWidget {
  final Map<String, dynamic> attachmentMap;
  final int currentIndex;
  final List<Map<String, dynamic>> allAttachmentsInThisPost;
  final Map<String, dynamic> postOrReplyData;
  final BorderRadius borderRadius;

  const ReplyAttachmentDisplayWidget({
    super.key,
    required this.attachmentMap,
    required this.currentIndex,
    required this.allAttachmentsInThisPost,
    required this.postOrReplyData,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Safe type access with defaults
    final String attachmentType = attachmentMap['type']?.toString() ?? 'unknown';
    final String? displayUrl = attachmentMap['url']?.toString();
    final String? attachmentFilename = attachmentMap['filename']?.toString();
    final File? localFile = attachmentMap['file'] is File ? attachmentMap['file'] as File : null;

    // Post or reply metadata
    final String messageContent = postOrReplyData['content']?.toString() ?? '';
    final String userName = postOrReplyData['username']?.toString() ?? 'Unknown User';
    final String? userAvatarUrl = postOrReplyData['useravatar']?.toString();
    final DateTime timestamp = postOrReplyData['createdAt'] is String
        ? DateTime.tryParse(postOrReplyData['createdAt'] as String) ?? DateTime.now()
        : postOrReplyData['createdAt'] is DateTime
            ? postOrReplyData['createdAt'] as DateTime
            : DateTime.now();

    final int viewsCount = postOrReplyData['viewsCount'] is int
        ? postOrReplyData['viewsCount'] as int
        : (postOrReplyData['views'] as List?)?.length ?? 0;
    final int likesCount = postOrReplyData['likesCount'] is int
        ? postOrReplyData['likesCount'] as int
        : (postOrReplyData['likes'] as List?)?.length ?? 0;
    final int repostsCount = postOrReplyData['repostsCount'] is int
        ? postOrReplyData['repostsCount'] as int
        : (postOrReplyData['reposts'] as List?)?.length ?? 0;

    // Generate unique key for attachment
    final String attachmentKeySuffix = attachmentMap['_id']?.toString().isNotEmpty == true
        ? attachmentMap['_id'] as String
        : attachmentMap['url']?.toString().isNotEmpty == true
            ? attachmentMap['url'] as String
            : 'index_$currentIndex';

    Widget contentWidget;

    switch (attachmentType) {
      case 'video':
        contentWidget = VideoAttachmentWidget(
          key: Key('video_reply_att_$attachmentKeySuffix'),
          attachment: attachmentMap,
          post: postOrReplyData,
          borderRadius: borderRadius,
          enforceFeedConstraints: false,
        );
        break;

      case 'image':
        contentWidget = displayUrl?.isNotEmpty == true
            ? Image.network(
                displayUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
              )
            : localFile != null
                ? Image.file(
                    localFile,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
                  )
                : _buildErrorPlaceholder();
        break;

      case 'pdf':
        final uri = displayUrl != null
            ? Uri.tryParse(displayUrl)
            : localFile != null
                ? Uri.file(localFile.path)
                : null;
        contentWidget = uri != null
            ? PdfThumbnailWidget(
                pdfUri: uri,
                aspectRatio: 4 / 3,
              )
            : _buildErrorPlaceholder();
        break;

      case 'audio':
        contentWidget = AudioAttachmentWidget(
          key: Key('audio_reply_att_$attachmentKeySuffix'),
          attachment: attachmentMap,
          post: postOrReplyData,
          borderRadius: borderRadius,
        );
        break;

      default:
        contentWidget = _buildDefaultPlaceholder(attachmentFilename, displayUrl);
        break;
    }

    return GestureDetector(
      onTap: () {
        final initialIndex = allAttachmentsInThisPost.indexWhere((att) =>
            att['url']?.toString() == attachmentMap['url']?.toString() ||
            (att['_id']?.toString() == attachmentMap['_id']?.toString() &&
                att['_id'] != null));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaViewPage(
              attachments: allAttachmentsInThisPost,
              initialIndex: initialIndex != -1 ? initialIndex : currentIndex,
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

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40),
    );
  }

  Widget _buildDefaultPlaceholder(String? filename, String? url) {
    return Container(
      color: Colors.grey[900],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FeatherIcons.film, color: Colors.tealAccent, size: 40),
          const SizedBox(height: 8),
          Text(
            filename ?? (url?.split('/').last) ?? 'unknown',
            style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class PdfThumbnailWidget extends StatelessWidget {
  final Uri pdfUri;
  final double aspectRatio;

  const PdfThumbnailWidget({
    super.key,
    required this.pdfUri,
    this.aspectRatio = 4 / 3,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: PdfViewer.uri(
        pdfUri,
      ),
    );
  }
}