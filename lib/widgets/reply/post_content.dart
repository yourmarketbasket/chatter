import 'dart:convert';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/reply_page.dart'; // May be needed for navigation, or pass callback
import 'package:chatter/widgets/reply/reply_attachment_grid.dart';
import 'package:chatter/widgets/reply/stat_button.dart';
import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
// import 'package:share_plus/share_plus.dart'; // Not used directly, handled by callback
// import 'dart:io'; // Not used directly
// import 'package:http/http.dart' as http; // Not used directly
// import 'package:path_provider/path_provider.dart'; // Not used directly
// import 'package:path/path.dart' as path; // Not used directly

class PostContent extends StatefulWidget {
  final Map<String, dynamic> postData;
  final bool isReply;
  final int indentationLevel; // New parameter
  final bool isPreview; // New parameter
  final String? pageOriginalPostId; // The original post ID of the ReplyPage itself
  final Function(String, String, Color) showSnackBar; // For user feedback
  final Function(Map<String, dynamic>) onSharePost; // Callback for sharing
  final Function(String parentReplyId) onReplyToItem; // Callback to initiate a reply
  final Function() refreshReplies; // Callback to refresh replies list after an action
  final Function(Map<String, dynamic> updatedReplyData) onReplyDataUpdated;

  const PostContent({
    Key? key,
    required this.postData,
    required this.isReply,
    this.indentationLevel = 0, // Default value
    this.isPreview = false, // Default value
    this.pageOriginalPostId,
    required this.showSnackBar,
    required this.onSharePost,
    required this.onReplyToItem,
    required this.refreshReplies,
    required this.onReplyDataUpdated,
  }) : super(key: key);

  @override
  _PostContentState createState() => _PostContentState();
}

class _PostContentState extends State<PostContent> {
  late DataController _dataController;
  late Map<String, dynamic> _currentPostData; // Local mutable copy

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
    _currentPostData = Map<String, dynamic>.from(widget.postData);
    // Ensure lists are also new instances if they exist and might be modified
    if (_currentPostData['likes'] != null && _currentPostData['likes'] is List) {
      _currentPostData['likes'] = List<dynamic>.from(_currentPostData['likes'] as List);
    }
    if (_currentPostData['reposts'] != null && _currentPostData['reposts'] is List) {
      _currentPostData['reposts'] = List<dynamic>.from(_currentPostData['reposts'] as List);
    }
  }

  @override
  void didUpdateWidget(covariant PostContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postData != oldWidget.postData) {
      _currentPostData = Map<String, dynamic>.from(widget.postData);
      if (_currentPostData['likes'] != null && _currentPostData['likes'] is List) {
        _currentPostData['likes'] = List<dynamic>.from(_currentPostData['likes'] as List);
      }
      if (_currentPostData['reposts'] != null && _currentPostData['reposts'] is List) {
        _currentPostData['reposts'] = List<dynamic>.from(_currentPostData['reposts'] as List);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentEntryId = _currentPostData['_id'] as String;
    final String username = _currentPostData['username'] as String? ?? 'Unknown User';
    final String threadOriginalPostId = widget.pageOriginalPostId ?? (_currentPostData['originalPostId'] as String? ?? currentEntryId);

    String contentText = _currentPostData['content'] as String? ?? '';
    if (_currentPostData['buffer'] != null && _currentPostData['buffer']['data'] is List) {
      try {
        final List<int> data = List<int>.from(_currentPostData['buffer']['data'] as List);
        contentText = utf8.decode(data);
      } catch (e) {
        print('Error decoding buffer content for $currentEntryId: $e');
        contentText = 'Error displaying content.';
      }
    }

    final String? userAvatar = _currentPostData['useravatar'] as String?;
    final String avatarInitial = _currentPostData['avatarInitial'] as String? ?? (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = _currentPostData['createdAt'] is String
        ? (DateTime.tryParse(_currentPostData['createdAt'] as String) ?? DateTime.now())
        : (_currentPostData['createdAt'] is DateTime ? _currentPostData['createdAt'] as DateTime : DateTime.now());

    List<Map<String, dynamic>> correctlyTypedAttachments = [];
    final dynamic rawAttachments = _currentPostData['attachments'];
    if (rawAttachments is List && rawAttachments.isNotEmpty) {
      for (final item in rawAttachments) {
        if (item is Map<String, dynamic>) {
          correctlyTypedAttachments.add(item);
        } else if (item is Map) {
          try {
            correctlyTypedAttachments.add(Map<String, dynamic>.from(item.map((key, value) => MapEntry(key.toString(), value))));
          } catch (e) {
            print('Error converting attachment Map to Map<String, dynamic>: $e. Attachment: $item');
          }
        }
      }
    }

    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';
    final List<dynamic> likesList = _currentPostData['likes'] is List ? _currentPostData['likes'] as List<dynamic> : [];
    final bool isLikedByCurrentUser = likesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId));

    final int likesCount = _currentPostData['likesCount'] as int? ?? likesList.length;
    final int repostsCount = _currentPostData['repostsCount'] as int? ?? (_currentPostData['reposts'] is List ? (_currentPostData['reposts'] as List).length : 0);
    final int viewsCount = _currentPostData['viewsCount'] as int? ?? (_currentPostData['views'] is List ? (_currentPostData['views'] as List).length : 0);
    final int repliesCount = _currentPostData['repliesCount'] as int? ?? (_currentPostData['replies'] is List ? (_currentPostData['replies'] as List).length : 0);

    final double avatarRadius = widget.isReply ? 14 : 18;
    final double indentOffset = widget.indentationLevel * 20.0; // Each level indents by 20px, adjust as needed

    if (widget.isReply && !widget.isPreview) { // View tracking for non-preview replies
      _dataController.viewReply(threadOriginalPostId, currentEntryId);
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // This Padding is for the avatar and the potential vertical line
            Padding(
              padding: EdgeInsets.only(
                left: widget.isReply ? indentOffset : 8.0, // Base indent for all replies, plus level indent
                top: 8.0,
                right: 12.0,
              ),
              child: widget.isReply && !widget.isPreview // Only show line for grouped, non-preview replies
                  ? CustomPaint(
                      painter: _VerticalLinePainter(avatarRadius: avatarRadius, avatarLeftPadding: 0), // No extra padding here
                      child: Padding(
                        padding: EdgeInsets.only(left: avatarRadius + 6), // Space for line then avatar
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.tealAccent.withOpacity(0.2),
                          backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                          child: userAvatar == null || userAvatar.isEmpty
                              ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: widget.isReply ? 12 : 14))
                              : null,
                        ),
                      ),
                    )
                  : CircleAvatar( // Avatar for main post or preview replies (no line)
                      radius: avatarRadius,
                      backgroundColor: Colors.tealAccent.withOpacity(0.2),
                      backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                      child: userAvatar == null || userAvatar.isEmpty
                          ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: widget.isReply ? 12 : 14))
                          : null,
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: widget.isReply ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReplyPage(
                            post: _currentPostData,
                            originalPostId: threadOriginalPostId,
                          ),
                        ),
                      );
                    } : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '@$username',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: widget.isReply ? 14 : 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${DateFormat('h:mm a').format(timestamp)} · ${DateFormat('MMM d, yyyy').format(timestamp)} · $viewsCount views',
                                style: GoogleFonts.roboto(fontSize: widget.isReply ? 11 : 12, color: Colors.grey[400]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          contentText,
                          style: GoogleFonts.roboto(fontSize: widget.isReply ? 13 : 14, color: const Color.fromARGB(255, 255, 255, 255), height: 1.5),
                        ),
                        if (correctlyTypedAttachments.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ReplyAttachmentGrid(
                            attachmentsArg: correctlyTypedAttachments,
                            postOrReplyData: _currentPostData,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 0), // No extra indent for action buttons themselves
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatButton(
                          icon: FeatherIcons.messageCircle,
                          text: '$repliesCount',
                          color: Colors.tealAccent,
                          onPressed: () => widget.onReplyToItem(currentEntryId),
                        ),
                        StatButton(
                          icon: FeatherIcons.repeat,
                          text: '$repostsCount',
                          color: Colors.greenAccent,
                          onPressed: () async {
                            Map<String, dynamic> result;
                            if (widget.isReply) {
                              result = await _dataController.repostReply(threadOriginalPostId, currentEntryId);
                            } else {
                              result = await _dataController.repostPost(currentEntryId);
                            }
                            if (!mounted) return;
                            if (result['success'] == true) {
                              // Success snackbar removed
                              if (widget.isReply) {
                                setState(() {
                                  var newRepostsList = List<dynamic>.from(_currentPostData['reposts'] ?? []);
                                  if (!newRepostsList.contains(currentUserId)) newRepostsList.add(currentUserId);
                                  _currentPostData['reposts'] = newRepostsList;
                                  _currentPostData['repostsCount'] = newRepostsList.length;
                                });
                                widget.onReplyDataUpdated(_currentPostData);
                              } else {
                                setState(() {
                                   var newRepostsList = List<dynamic>.from(_currentPostData['reposts'] ?? []);
                                   if (!newRepostsList.contains(currentUserId)) newRepostsList.add(currentUserId);
                                  _currentPostData['reposts'] = newRepostsList;
                                  _currentPostData['repostsCount'] = newRepostsList.length;
                                });
                                widget.onReplyDataUpdated(_currentPostData); // For main post on ReplyPage
                              }
                            } else {
                              widget.showSnackBar('Error', result['message'] ?? (widget.isReply ? 'Failed to repost reply.' : 'Failed to repost post.'), Colors.red[700]!);
                            }
                          },
                        ),
                        StatButton(
                          icon: isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart,
                          text: '$likesCount',
                          color: isLikedByCurrentUser ? Colors.pinkAccent : Colors.pinkAccent.withOpacity(0.7),
                          onPressed: () async {
                            Map<String, dynamic> result;
                            bool currentlyLiked = isLikedByCurrentUser; // Snapshot before async
                            if (widget.isReply) {
                              result = currentlyLiked
                                  ? await _dataController.unlikeReply(threadOriginalPostId, currentEntryId)
                                  : await _dataController.likeReply(threadOriginalPostId, currentEntryId);
                            } else {
                              result = currentlyLiked
                                  ? await _dataController.unlikePost(currentEntryId)
                                  : await _dataController.likePost(currentEntryId);
                            }
                            if (!mounted) return;
                            if (result['success'] == true) {
                              // Success snackbar removed
                              setState(() {
                                var newLikesList = List<dynamic>.from(_currentPostData['likes'] ?? []);
                                if (currentlyLiked) {
                                  newLikesList.removeWhere((id) => (id is Map ? id['_id'] == currentUserId : id.toString() == currentUserId));
                                } else {
                                  if (!newLikesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId))) {
                                    newLikesList.add(currentUserId);
                                  }
                                }
                                _currentPostData['likes'] = newLikesList;
                                _currentPostData['likesCount'] = newLikesList.length;
                              });
                              widget.onReplyDataUpdated(_currentPostData);
                            } else {
                              widget.showSnackBar('Error', result['message'] ?? (widget.isReply ? 'Failed to update like status for reply.' : 'Failed to update like status for post.'), Colors.red[700]!);
                            }
                          },
                        ),
                        if (!widget.isReply)
                          StatButton(
                            icon: FeatherIcons.bookmark,
                            text: '',
                            color: Colors.white70,
                            onPressed: () {
                              // Informational snackbar removed, only errors should remain.
                              // widget.showSnackBar('Bookmark Post','Bookmark post by @$username (not implemented yet).', Colors.teal[700]!);
                              print('Bookmark action triggered for @$username (UI only, no snackbar)');
                            },
                          ),
                        if (widget.isReply) const SizedBox(width: 24 + 8),
                        StatButton(
                          icon: FeatherIcons.share2,
                          text: '',
                          color: Colors.white70,
                          onPressed: () => widget.onSharePost(_currentPostData),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    if (widget.isPreview) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey[800]!, width: 0.5),
            bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), // Added horizontal padding
        child: content,
      );
    }

    // Base padding for all items, adjusted if it's a reply for indentation
    final EdgeInsets outerPadding = widget.isReply
        ? EdgeInsets.only(left: 4.0, right: 4.0, top: 4.0, bottom: 4.0) // Consistent padding for replies
        : EdgeInsets.only(left: 8.0, right: 4.0, top: 8.0, bottom: 4.0); // Padding for main post

    return Padding(
      padding: outerPadding,
      child: content,
    );
  }
}

class _VerticalLinePainter extends CustomPainter {
  final double avatarRadius;
  final double avatarLeftPadding; // Padding to the left of the avatar itself

  _VerticalLinePainter({required this.avatarRadius, required this.avatarLeftPadding});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 1.5;

    // Start the line from the center of where the avatar would be, vertically
    // The avatar itself is painted by the CircleAvatar widget.
    // This painter is for the line extending downwards from it.
    // The CustomPaint widget will be to the left of the actual CircleAvatar.
    // So, the line should be drawn relative to the CustomPaint's own coordinate system.
    // X-coordinate for the line: center of the avatar.
    // Avatar's actual center X within its own space is avatarRadius.
    // The line starts from avatar's vertical center, downwards.
    // The line should start to the left of the main content of the reply, aligned with the avatar's center.

    final lineStartX = avatarLeftPadding + avatarRadius; // Center X of the avatar
    // The line should start from below the avatar, or from its vertical center and extend down.
    // Let's start it from the top of the CustomPaint area, extending downwards.
    // The CustomPaint area will be alongside the Avatar and the reply content.
    // For a simple vertical line, it starts at (centerX, 0) and goes to (centerX, size.height).
    // This line is intended to be to the left of the reply content, aligned with the avatar.

    // If the CustomPaint is a peer to the Avatar in a Row, and the line is inside CustomPaint,
    // the line needs to be drawn from top to bottom of the CustomPaint's area.
    // The positioning of the CustomPaint itself will handle the indent.

    // Let's assume this CustomPaint widget is placed such that its width is small (e.g., just for the line)
    // and it's positioned correctly by its parent.
    // The line starts from the top center of this CustomPaint area and goes down.
    // This painter is intended to be to the left of the main content,
    // and the avatar is also to the left.
    // The line should appear to emanate from the avatar.

    // The line should be drawn in the space *before* the CircleAvatar.
    // The CustomPaint widget should be placed to the left of the CircleAvatar.
    // The `padding: EdgeInsets.only(left: avatarRadius + 6)` for the CircleAvatar
    // implies the CustomPaint is to its left.

    // Draw line from top to bottom of the available height for this painter.
    // The painter is inside a Padding which has `left: avatarRadius + 6` for the CircleAvatar.
    // This means the CustomPaint itself is positioned by the parent Row.
    // The line should start from the vertical center of the avatar and go down.
    // The avatar's top is at some Y. Its center is avatar.top + avatarRadius.
    // The line should effectively start at this Y and continue for the height of the reply.

    // Let's draw the line from top to bottom of the CustomPaint's own area.
    // The X position should be such that it appears centered with the avatar.
    // If this CustomPaint is given the width of the avatar + some padding,
    // then lineStartX would be avatarRadius.
    // Given the current structure, this CustomPaint is a child of a Padding,
    // and that Padding also contains the CircleAvatar. This is complex.

    // Simpler: The CustomPaint will be a thin strip. The line is in its center.
    // The parent Row will have: CustomPaint | Avatar | Content
    // No, the current code is: CustomPaint(child: Padding(child: Avatar))
    // This means the line is drawn, then avatar on top. Line should be beside.

    // Corrected understanding:
    // Row [
    //   CustomPaint (for line),
    //   Avatar,
    //   Content Column
    // ]
    // The CustomPaint itself will be given some width. The line is drawn in its center.
    // The `indentOffset` handles the left padding for this entire Row.
    // The line is drawn from the Y-center of avatar downwards.

    // The line should start from avatar's center Y and go down.
    // The avatar's top edge is roughly at `paintYOffset` if we consider padding.
    // Let's assume the line starts from `avatarRadius` (relative to top of the content part)
    // and extends to `size.height`.
    // The X position will be `avatarRadius / 2` if the CustomPaint width is `avatarRadius`.
    // This is getting complicated. Let's simplify: The line is drawn from top to bottom
    // of the container that holds the reply content, offset to align with avatar.

    // The line is drawn from the top of the content area (aligned with top of avatar)
    // down to the bottom of the content area.
    // Its X position is to the left of the avatar.
    // The current structure has Padding(child: CustomPaint(child: Padding(child: CircleAvatar))).
    // This means the line is "behind" the avatar.

    // Let's assume the provided `size` to this painter is the full height of the reply content.
    // The line should be drawn to the left of the actual avatar.
    // The padding `EdgeInsets.only(left: avatarRadius + 6)` is applied to the CircleAvatar.
    // The CustomPaint is the parent of this padding.
    // So, the line needs to be drawn at `(avatarRadius + 6) / 2` if it's to be centered in that padding.
    // This means the line is between the very start of the indented area and the avatar.

    // Start line from vertical center of avatar (approx avatarRadius from top of its box)
    // and extend to bottom of the PostContent.
    final double lineX = (avatarRadius + 6) / 2; // Center of the padding space left of avatar
    canvas.drawLine(Offset(lineX, avatarRadius), Offset(lineX, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _VerticalLinePainter oldDelegate) {
    return oldDelegate.avatarRadius != avatarRadius || oldDelegate.avatarLeftPadding != avatarLeftPadding;
  }
}
