import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:dio/dio.dart'; // Added for CancelToken

class PdfThumbnailWidget extends StatefulWidget {
  final String url;
  final bool isLocal;
  final int? fileSize;

  const PdfThumbnailWidget({
    Key? key,
    required this.url,
    this.isLocal = false,
    this.fileSize,
  }) : super(key: key);

  @override
  _PdfThumbnailWidgetState createState() => _PdfThumbnailWidgetState();
}

class _PdfThumbnailWidgetState extends State<PdfThumbnailWidget> {
  late Future<Map<String, dynamic>> _thumbnailFuture;
  CancelToken? _cancelToken;
  bool _isMounted = true;

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    _thumbnailFuture = _generateThumbnail();
  }

  @override
  void dispose() {
    _isMounted = false;
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _generateThumbnail() async {
    PdfDocument? doc;
    PdfImage? pageImage;

    try {
      // Open PDF (local or remote)
      if (widget.isLocal) {
        doc = await PdfDocument.openFile(widget.url);
      } else {
        final dio = Dio();
        final response = await dio.get(
          widget.url,
          cancelToken: _cancelToken,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.statusCode == 200) {
          doc = await PdfDocument.openData(Uint8List.fromList(response.data));
        } else {
          throw Exception('Failed to download PDF: ${response.statusCode}');
        }
      }

      if (!_isMounted) {
        return {'thumbnail': null, 'pageCount': 0};
      }

      if (doc == null || doc.pages.isEmpty) {
        return {'thumbnail': null, 'pageCount': 0};
      }

      final page = doc.pages.first;
      const double thumbnailWidth = 780;
      final int renderWidth = thumbnailWidth.round();
      final int renderHeight = ((thumbnailWidth * page.height) / page.width).round();

      pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
      );

      if (!_isMounted) {
        return {'thumbnail': null, 'pageCount': doc.pages.length};
      }

      if (pageImage == null || pageImage.pixels.isEmpty) {
        return {'thumbnail': null, 'pageCount': doc.pages.length};
      }

      // Convert BGRA -> RGBA
      final pixels = pageImage.pixels;
      for (int i = 0; i < pixels.length; i += 4) {
        final b = pixels[i];
        final r = pixels[i + 2];
        pixels[i] = r;
        pixels[i + 2] = b;
      }

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pixels.buffer,
        order: img.ChannelOrder.rgba,
      );

      return {
        'thumbnail': Uint8List.fromList(img.encodePng(image)),
        'pageCount': doc.pages.length
      };
    } catch (e) {
      if (!_isMounted || e is DioException && CancelToken.isCancel(e)) {
        return {'thumbnail': null, 'pageCount': 0};
      }
      return {'thumbnail': null, 'pageCount': 0};
    } finally {
      pageImage?.dispose();
      doc?.dispose();
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _trimFileName(String name) {
    final baseName = p.basename(name);
    if (baseName.length <= 25) return baseName;
    return '${baseName.substring(0, 22)}...';
  }

  Widget _buildInfoOverlay(int pageCount) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.3),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _trimFileName(widget.url),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatFileSize(widget.fileSize),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$pageCount page${pageCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _thumbnailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[200]!, Colors.grey[300]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.blueAccent,
                  ),
                ),
              );
            }

            final thumbnail = snapshot.data?['thumbnail'] as Uint8List?;
            final pageCount = snapshot.data?['pageCount'] as int? ?? 0;

            if (snapshot.hasError || thumbnail == null) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey[100]!, Colors.grey[300]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.picture_as_pdf,
                        color: Colors.grey,
                        size: 64,
                      ),
                    ),
                  ),
                  _buildInfoOverlay(pageCount),
                ],
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  height: 300,
                ),
                _buildInfoOverlay(pageCount),
              ],
            );
          },
        ),
      ),
    );
  }
}