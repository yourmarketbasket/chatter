import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkPreviewWidget extends StatefulWidget {
  final String url;

  const LinkPreviewWidget({Key? key, required this.url}) : super(key: key);

  @override
  _LinkPreviewWidgetState createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends State<LinkPreviewWidget> {
  late Future<Metadata?> _metadataFuture;

  @override
  void initState() {
    super.initState();
    _metadataFuture = _fetchMetadata();
  }

  Future<Metadata?> _fetchMetadata() async {
    try {
      var urlToFetch = _getDomain(widget.url);
      // aHR0cHM6Ly9jb3JzLWFueXdoZXJlLmhlcm9rdWFwcC5jb20v is the base64 of https://cors-anywhere.herokuapp.com/
      return await AnyLinkPreview.getMetadata(
        link: urlToFetch,
        cache: const Duration(days: 7),
        proxyUrl: "https://cors-anywhere.herokuapp.com/", // A proxy is needed to bypass CORS issues on web
      );
    } catch (e) {
      // It's better to not show an error in the chat, just fail silently.
      return null;
    }
  }

  String _getDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$url');
      }
      // The user wants something like "www.codethelabs.com" from "codethelabs.com/assets/files/chatter.apk"
      String host = uri.host;
      if (host.isEmpty) return url;
      if (!host.startsWith('www.')) {
        host = 'www.$host';
      }
      return 'https://$host';
    } catch (e) {
      return url; // Fallback to original url
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Metadata?>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final metadata = snapshot.data!;

        return GestureDetector(
          onTap: () async {
            final uri = Uri.parse(widget.url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metadata.image != null && metadata.image!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      metadata.image!,
                      fit: BoxFit.cover,
                      height: 150,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                if (metadata.title != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      metadata.title!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (metadata.desc != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      metadata.desc!,
                      style: TextStyle(color: Colors.grey[400]),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    Uri.parse(_getDomain(widget.url)).host,
                    style: TextStyle(color: Colors.blue[300], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
