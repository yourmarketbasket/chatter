import 'package:chatter/pages/home-feed-screen.dart'; // For Attachment type
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart'; // For PDF viewing
import 'package:feather_icons/feather_icons.dart'; // For fallback icons

// Assuming Attachment class is defined in or imported by home-feed-screen.dart
// Ideally, Attachment should be in its own model file.

class MediaViewPage extends StatelessWidget {
  final Attachment attachment;

  const MediaViewPage({Key? key, required this.attachment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget mediaWidget;
    String pageTitle = "View Media";

    final String displayPath = attachment.url ?? attachment.file.path;

    switch (attachment.type) {
      case "image":
        pageTitle = "View Image";
        if (attachment.url != null) {
          mediaWidget = InteractiveViewer( // Allows pinch-to-zoom and panning
            child: Image.network(
              attachment.url!,
              fit: BoxFit.contain, // Use contain to show the whole image
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 50),
                    SizedBox(height: 10),
                    Text("Error loading image", style: GoogleFonts.roboto(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          );
        } else {
           // Displaying local file image
          mediaWidget = InteractiveViewer(
            child: Image.file(
              attachment.file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 50),
                    SizedBox(height: 10),
                    Text("Error loading image file", style: GoogleFonts.roboto(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          );
        }
        break;
      case "pdf":
        pageTitle = "View PDF";
        // PdfViewer.uri can take both network URLs and local file URIs
        Uri pdfUri = attachment.url != null ? Uri.parse(attachment.url!) : Uri.file(attachment.file.path);
        mediaWidget = PdfViewer.uri(
          pdfUri,
          params: PdfViewerParams(
            // layoutPages: (pages, params) { // Example: customize layout if needed
            //   return List.generate(pages.length, (index) => SomeCustomPdfPageLayout(pages[index]));
            // },
            // buildPagePlaceholder: (pageNumber, pageSize) => Center(child: CircularProgressIndicator()),
            // errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(child: Text("Error loading PDF")),
          ),
        );
        break;
      case "video":
        pageTitle = "View Video";
        // Placeholder for video. A real video player (like video_player package) would be integrated here.
        mediaWidget = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FeatherIcons.video, color: Colors.tealAccent, size: 100),
              SizedBox(height: 20),
              Text(
                "Video playback not implemented yet.",
                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                displayPath.split('/').last,
                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
        break;
      case "audio":
        pageTitle = "View Audio";
        // Placeholder for audio. A real audio player (like audioplayers package) would be integrated here.
        mediaWidget = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FeatherIcons.music, color: Colors.tealAccent, size: 100),
              SizedBox(height: 20),
              Text(
                "Audio playback not implemented yet.",
                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                displayPath.split('/').last,
                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
        break;
      default:
        pageTitle = "View Attachment";
        mediaWidget = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FeatherIcons.file, color: Colors.grey[600], size: 100),
              SizedBox(height: 20),
              Text(
                "Unsupported attachment type: ${attachment.type}",
                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                displayPath.split('/').last,
                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }

    return Scaffold(
      backgroundColor: Colors.black, // Full black for immersive view
      appBar: AppBar(
        title: Text(pageTitle, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Color(0xFF121212), // Dark app bar
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        color: Colors.black, // Ensure body background is black
        child: mediaWidget,
      ),
    );
  }
}
