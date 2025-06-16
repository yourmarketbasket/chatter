import 'package:chatter/pages/home-feed-screen.dart'; // For Attachment type
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart'; // For PDF viewing
import 'package:feather_icons/feather_icons.dart'; // For fallback icons
import 'dart:io';

// MediaViewPage displays an attachment (image, PDF, video, or audio) in a full-screen view.
// Video and audio playback are placeholders, as their respective packages (e.g., audioplayers)
// are imported but not implemented.

class MediaViewPage extends StatelessWidget {
  final Attachment attachment;

  const MediaViewPage({Key? key, required this.attachment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the display widget and page title based on attachment type
    String pageTitle;
    Widget mediaWidget;

    // Safely get the display path for error messages or placeholders
    final String displayPath = attachment.url ?? attachment.file?.path ?? 'Unknown attachment';

    switch (attachment.type.toLowerCase()) {
      case 'image':
        pageTitle = 'View Image';
        mediaWidget = _buildImageViewer(context, displayPath);
        break;
      case 'pdf':
        pageTitle = 'View PDF';
        mediaWidget = _buildPdfViewer(context, displayPath);
        break;
      case 'video':
        pageTitle = 'View Video';
        mediaWidget = _buildPlaceholder(
          context,
          icon: FeatherIcons.video,
          message: 'Video playback not implemented yet.',
          fileName: displayPath.split('/').last,
        );
        break;
      case 'audio':
        pageTitle = 'View Audio';
        mediaWidget = _buildPlaceholder(
          context,
          icon: FeatherIcons.music,
          message: 'Audio playback not implemented yet.',
          fileName: displayPath.split('/').last,
        );
        break;
      default:
        pageTitle = 'View Attachment';
        mediaWidget = _buildPlaceholder(
          context,
          icon: FeatherIcons.file,
          message: 'Unsupported attachment type: ${attachment.type}',
          fileName: displayPath.split('/').last,
          iconColor: Colors.grey[600],
        );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          pageTitle,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.black,
          child: Center(child: mediaWidget),
        ),
      ),
    );
  }

  // Builds an image viewer for network or local images with pinch-to-zoom
  Widget _buildImageViewer(BuildContext context, String displayPath) {
    if (attachment.url != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          attachment.url!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildError(
            context,
            message: 'Error loading image: $error',
          ),
        ),
      );
    } else if (attachment.file != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.file(
          attachment.file!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildError(
            context,
            message: 'Error loading image file: $error',
          ),
        ),
      );
    } else {
      return _buildError(
        context,
        message: 'No image source available for $displayPath',
      );
    }
  }

  // Builds a PDF viewer for network or local PDFs
  Widget _buildPdfViewer(BuildContext context, String displayPath) {
    if (attachment.url != null || attachment.file != null) {
      final Uri pdfUri = attachment.url != null
          ? Uri.parse(attachment.url!)
          : Uri.file(attachment.file!.path);
      return PdfViewer.uri(
        pdfUri,
        params: const PdfViewerParams(
          maxScale: 2.0,
          minScale: 0.5,
        ),
      );
    } else {
      return _buildError(
        context,
        message: 'No PDF source available for $displayPath',
      );
    }
  }

  // Builds a generic error widget for failed media loading
  Widget _buildError(BuildContext context, {required String message}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          FeatherIcons.alertTriangle,
          color: Colors.redAccent,
          size: 50,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: GoogleFonts.roboto(
            color: Colors.white70,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Builds a placeholder for unsupported or unimplemented media types
  Widget _buildPlaceholder(
    BuildContext context, {
    required IconData icon,
    required String message,
    required String fileName,
    Color? iconColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: iconColor ?? Colors.tealAccent,
          size: 100,
        ),
        const SizedBox(height: 20),
        Text(
          message,
          style: GoogleFonts.roboto(
            color: Colors.white70,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          fileName,
          style: GoogleFonts.roboto(
            color: Colors.grey[500],
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}