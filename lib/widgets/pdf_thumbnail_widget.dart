import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as p;

class PdfThumbnailWidget extends StatefulWidget {
  final String url;
  final bool isLocal;
  final int? fileSize; // Optional file size in bytes

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
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: widget.isLocal
            ? PdfViewer.file(
                widget.url,
                params: const PdfViewerParams(
                  pageNumber: 1,
                  maxScale: 1.0,
                  minScale: 1.0,
                  panEnabled: false,
                  scrollEnabled: false,
                  layoutPages: null,
                ),
              )
            : PdfViewer.uri(
                Uri.parse(widget.url),
                params: const PdfViewerParams(
                  pageNumber: 1,
                  maxScale: 1.0,
                  minScale: 1.0,
                  panEnabled: false,
                  scrollEnabled: false,
                  layoutPages: null,
                ),
              ),
      ),
    );
  }
}