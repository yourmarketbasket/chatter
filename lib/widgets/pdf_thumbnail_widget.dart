import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
  late Future<PdfPageImage?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _generateThumbnail();
  }

  Future<PdfPageImage?> _generateThumbnail() async {
    try {
      PdfDocument doc;
      if (widget.isLocal) {
        doc = await PdfDocument.openFile(widget.url);
      } else {
        // For network URLs, we need to download the file first.
        final response = await http.get(Uri.parse(widget.url));
        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          // Use a unique name to avoid conflicts
          final filename = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(widget.url)}';
          final file = File(p.join(dir.path, filename));
          await file.writeAsBytes(response.bodyBytes);
          doc = await PdfDocument.openFile(file.path);
        } else {
          throw Exception('Failed to download PDF: ${response.statusCode}');
        }
      }

      if (doc.pageCount > 0) {
        final page = await doc.getPage(1); // 1-based index
        final pageImage = await page.render();
        await page.dispose(); // It's good practice to dispose the page
        return pageImage;
      }
      return null;
    } catch (e) {
      print('Error generating PDF thumbnail: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdfPageImage?>(
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

        final pageImage = snapshot.data!;
        return Image.memory(
          pageImage.bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }
}
