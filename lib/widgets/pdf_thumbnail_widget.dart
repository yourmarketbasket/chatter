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
    final documentBuilder = widget.isLocal
        ? PdfDocumentViewBuilder.file(widget.url)
        : PdfDocumentViewBuilder.network(widget.url);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: documentBuilder(
          builder: (context, document) {
            if (document == null) {
              return Center(child: CircularProgressIndicator());
            }
            return PdfPageView(
              pdfPage: document.pages.first,
              // You can add other parameters here if needed
            );
          },
        ),
      ),
    );
  }
}