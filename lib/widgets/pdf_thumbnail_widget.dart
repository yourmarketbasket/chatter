import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

class PdfThumbnailWidget extends StatefulWidget {
  final String url;
  final bool isLocal;

  const PdfThumbnailWidget({
    Key? key,
    required this.url,
    this.isLocal = false,
  }) : super(key: key);

  @override
  _PdfThumbnailWidgetState createState() => _PdfThumbnailWidgetState();
}

class _PdfThumbnailWidgetState extends State<PdfThumbnailWidget> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    // It's important to initialize pdfrx before using engine APIs directly.
    // The main app should call pdfrxFlutterInitialize(), but we can call it here
    // as a fallback, though it's not ideal to call it in a widget's initState.
    // A better pattern is a singleton or DI approach for initialization.
    // For now, we'll assume it's initialized in main.dart as per docs.
    _thumbnailFuture = _generateThumbnail();
  }

  Future<Uint8List?> _generateThumbnail() async {
    PdfDocument? doc;
    try {
      if (widget.isLocal) {
        doc = await PdfDocument.openFile(widget.url);
      } else {
        final response = await http.get(Uri.parse(widget.url));
        if (response.statusCode == 200) {
          doc = await PdfDocument.openData(response.bodyBytes);
        } else {
          throw Exception('Failed to download PDF: ${response.statusCode}');
        }
      }

      if (doc == null || doc.pages.isEmpty) {
        return null;
      }

      final page = doc.pages.first;
      // Render the page to an image.
      // Let's use a fixed width for consistency and calculate height based on aspect ratio.
      const double thumbnailWidth = 200;
      final pageImage = await page.render(
        width: thumbnailWidth,
        height: (thumbnailWidth * page.height) / page.width,
      );

      if (pageImage == null) {
        return null;
      }

      // Use the library's method to create an image object.
      final image = pageImage.createImageNF();

      // Encode to PNG
      final pngBytes = img.encodePng(image);

      // It's important to dispose the pageImage to free up memory
      pageImage.dispose();

      return pngBytes;
    } catch (e) {
      print('Error generating PDF thumbnail with pdfrx: $e');
      return null;
    } finally {
      // Ensure the document is closed.
      await doc?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[850],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // Fallback to a generic icon if thumbnail fails
          return Container(
            color: Colors.grey[800],
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  p.basename(widget.url),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }
}
