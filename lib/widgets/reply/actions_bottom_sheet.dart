import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionsBottomSheetContent extends StatelessWidget {
  final Map<String, dynamic> post; // The post or reply data
  final Function(String title, String message, Color backgroundColor) showSnackBar;
  final DataController dataController = Get.find<DataController>();
  final bool isReply;
  final String? originalPostId;

  ActionsBottomSheetContent({
    Key? key,
    required this.post,
    required this.showSnackBar,
    this.isReply = false,
    this.originalPostId,
  }) : super(key: key);

  @override
  void _showEditDialog(BuildContext context) {
    final TextEditingController editController = TextEditingController(text: post['content']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${isReply ? 'Reply' : 'Post'}'),
        content: TextField(controller: editController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final success = isReply
                  ? await dataController.editReply(originalPostId!, post['_id'], editController.text)
                  : await dataController.editPost(post['_id'], editController.text);
              Navigator.pop(context);
              if (success) {
                showSnackBar('Success', 'Your ${isReply ? 'reply' : 'post'} has been updated.', Colors.green);
              } else {
                showSnackBar('Error', 'Failed to update your ${isReply ? 'reply' : 'post'}.', Colors.red);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String postUsername = post['username'] as String? ?? 'User';
    final String postId = post['_id'] as String? ?? "unknown_post_id";
    final String postAuthorId = post['userId'] as String? ?? '';
    final String currentUserId = dataController.user.value['user']['_id'];
    final bool isAuthor = postAuthorId == currentUserId;

    //This should be a configurable URL
    final String postLink = "https://chatter.yourdomain.com/post/$postId";

    return SafeArea(
      child: Wrap(
        children: [
          if (isAuthor) ...[
            ListTile(
              leading: const Icon(FeatherIcons.edit, color: Colors.tealAccent, size: 24),
              title: Text('Edit', style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(FeatherIcons.trash2, color: Colors.redAccent, size: 24),
              title: Text('Delete', style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                final success = isReply
                    ? await dataController.deleteReply(originalPostId!, post['_id'])
                    : await dataController.deletePost(post['_id']);
                if (success) {
                  showSnackBar('Success', 'Your ${isReply ? 'reply' : 'post'} has been deleted.', Colors.green);
                } else {
                  showSnackBar('Error', 'Failed to delete your ${isReply ? 'reply' : 'post'}.', Colors.red);
                }
              },
            ),
          ],
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
