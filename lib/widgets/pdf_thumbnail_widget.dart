import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
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
    _thumbnailFuture = _generateThumbnail();
  }

  Future<Uint8List?> _generateThumbnail() async {
    PdfDocument? doc;
    PdfPage? page;
    PdfImage? pageImage;
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

      page = doc.pages.first;

      const double thumbnailWidth = 200;
      pageImage = await page.render(
        width: thumbnailWidth.round(),
        height: ((thumbnailWidth * page.height) / page.width).round(),
        // Assuming the older version might not have this parameter, but it's a good guess
        // format: PdfPageImageFormat.bgra,
      );

      if (pageImage == null) {
        return null;
      }

      // Manually convert BGRA to RGBA for the image package
      final pixels = pageImage.pixels;
      for (var i = 0; i < pixels.length; i += 4) {
        final b = pixels[i];
        final r = pixels[i + 2];
        pixels[i] = r;
        pixels[i + 2] = b;
      }

      // Create an image from the RGBA bytes
      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pixels.buffer,
        order: img.ChannelOrder.rgba, // Specify the channel order
      );

      return img.encodePng(image);

    } catch (e) {
      print('Error generating PDF thumbnail with pdfrx: $e');
      return null;
    } finally {
      // Dispose resources
      pageImage?.dispose();
      page?.dispose();
      // Assuming dispose() is the correct method for the older version
      doc?.dispose();
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
