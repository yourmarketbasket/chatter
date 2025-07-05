import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionsBottomSheetContent extends StatelessWidget {
  final Map<String, dynamic> post; // The post data for context
  final Function(String title, String message, Color backgroundColor) showSnackBar;

  const ActionsBottomSheetContent({
    Key? key,
    required this.post,
    required this.showSnackBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String postUsername = post['username'] as String? ?? 'User';
    final String postId = post['_id'] as String? ?? "unknown_post_id";
    //This should be a configurable URL
    final String postLink = "https://chatter.yourdomain.com/post/$postId";

    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(FeatherIcons.userX, color: Colors.tealAccent, size: 24),
            title: Text('Block @$postUsername',
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              // Placeholder for block user functionality
              showSnackBar('Block User', 'Block @$postUsername (not implemented yet).', Colors.orange);
            },
          ),
          ListTile(
            leading: const Icon(FeatherIcons.alertTriangle, color: Colors.tealAccent, size: 24),
            title: Text('Report Post',
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              // Placeholder for report post functionality
              showSnackBar('Report Post', 'Report post by @$postUsername (not implemented yet).', Colors.orange);
            },
          ),
          ListTile(
            leading: const Icon(FeatherIcons.link, color: Colors.tealAccent, size: 24),
            title: Text('Copy link to post',
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: postLink)).then((_) {
                showSnackBar('Link Copied', 'Post link copied to clipboard!', Colors.green[700]!);
              }).catchError((error) {
                showSnackBar('Error', 'Could not copy link: $error', Colors.red[700]!);
              });
            },
          ),
          // Add other actions if needed, e.g., Mute, Unfollow, etc.
        ],
      ),
    );
  }
}
