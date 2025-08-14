import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionsBottomSheetContent extends StatefulWidget {
  final Map<String, dynamic> post; // The post data for context
  final Function(String title, String message, Color backgroundColor) showSnackBar;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ActionsBottomSheetContent({
    Key? key,
    required this.post,
    required this.showSnackBar,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  _ActionsBottomSheetContentState createState() => _ActionsBottomSheetContentState();
}

class _ActionsBottomSheetContentState extends State<ActionsBottomSheetContent> {
  late DataController _dataController;

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
  }

  @override
  Widget build(BuildContext context) {
    final String postUsername = widget.post['username'] as String? ?? 'User';
    final String postId = widget.post['_id'] as String? ?? "unknown_post_id";
    //This should be a configurable URL
    final String postLink = "https://chatter.yourdomain.com/post/$postId";
    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';

    String? authorId;
    if (widget.post['user'] is Map && (widget.post['user'] as Map).containsKey('_id')) {
      authorId = widget.post['user']['_id'] as String?;
    } else if (widget.post['userId'] is String) {
      authorId = widget.post['userId'] as String?;
    } else if (widget.post['userId'] is Map && (widget.post['userId'] as Map).containsKey('_id')) {
      authorId = widget.post['userId']['_id'] as String?;
    }

    return SafeArea(
      child: Wrap(
        children: [
          if (currentUserId == authorId) ...[
            ListTile(
              leading: const Icon(FeatherIcons.edit, color: Colors.tealAccent, size: 24),
              title: Text('Edit Post',
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                widget.onEdit?.call();
              },
            ),
            ListTile(
              leading: const Icon(FeatherIcons.trash, color: Colors.redAccent, size: 24),
              title: Text('Delete Post',
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete?.call();
              },
            ),
            const Divider(color: Colors.grey),
          ],
          ListTile(
            leading: const Icon(FeatherIcons.userX, color: Colors.tealAccent, size: 24),
            title: Text('Block @$postUsername',
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              // Placeholder for block user functionality
              widget.showSnackBar('Block User', 'Block @$postUsername (not implemented yet).', Colors.orange);
            },
          ),
          ListTile(
            leading: const Icon(FeatherIcons.alertTriangle, color: Colors.tealAccent, size: 24),
            title: Text('Report Post',
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              // Placeholder for report post functionality
              widget.showSnackBar('Report Post', 'Report post by @$postUsername (not implemented yet).', Colors.orange);
            },
          ),
          ListTile(
            leading: const Icon(FeatherIcons.link, color: Colors.tealAccent, size: 24),
            title: Text('Copy link to post',
                style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: postLink)).then((_) {
                widget.showSnackBar('Link Copied', 'Post link copied to clipboard!', Colors.green[700]!);
              }).catchError((error) {
                widget.showSnackBar('Error', 'Could not copy link: $error', Colors.red[700]!);
              });
            },
          ),
          // Add other actions if needed, e.g., Mute, Unfollow, etc.
        ],
      ),
    );
  }
}
