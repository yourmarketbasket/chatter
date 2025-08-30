import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkPreviewWidget extends StatefulWidget {
  final String url;
  final VoidCallback onPreviewSuccess;

  const LinkPreviewWidget({
    Key? key,
    required this.url,
    required this.onPreviewSuccess,
  }) : super(key: key);

  @override
  _LinkPreviewWidgetState createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends State<LinkPreviewWidget> {
  late Future<Metadata?> _metadataFuture;
  bool _hasCalledSuccess = false;

  @override
  void initState() {
    super.initState();
    _metadataFuture = _fetchMetadata();
  }

  Future<Metadata?> _fetchMetadata() async {
    try {
      var urlToFetch = _getDomain(widget.url);
      return await AnyLinkPreview.getMetadata(
        link: urlToFetch,
        cache: const Duration(days: 7),
      );
    } catch (e) {
      return null;
    }
  }

  String _getDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      if (uri.scheme == 'http') {
        uri = uri.replace(scheme: 'https');
      } else if (!uri.hasScheme) {
        return 'https://$url';
      }
      return uri.origin;
    } catch (e) {
      return 'https://$url';
    }
  }

  Future<void> _launchURL() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch URL')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Metadata?>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 100,

            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            constraints: const BoxConstraints(maxWidth: double.infinity),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          );
        }

        if (!_hasCalledSuccess && snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onPreviewSuccess();
          });
          _hasCalledSuccess = true;
        }

        return GestureDetector(
          onTap: _launchURL,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            constraints: const BoxConstraints(maxWidth: double.infinity),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: snapshot.hasData && snapshot.data != null
                ? _buildPreviewCard(snapshot.data!)
                : _buildErrorCard(),
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard(Metadata metadata) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metadata.image != null && metadata.image!.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    metadata.image!,
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Open Link',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metadata.title != null)
                  Text(
                    metadata.title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color.fromARGB(221, 75, 74, 74),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (metadata.desc != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      metadata.desc!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    Uri.parse(_getDomain(widget.url)).host,
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: EdgeInsets.only(top:5, bottom:5),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            'Preview Not Available',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey[200],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to visit',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            Uri.parse(_getDomain(widget.url)).host,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.blue[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          )
        ],
      ),
    );
  }
}