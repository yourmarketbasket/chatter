import 'dart:convert';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/widgets/reply/reply_attachment_grid.dart';
import 'package:chatter/widgets/reply/stat_button.dart';
import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PostContent extends StatefulWidget {
  final Map<String, dynamic> postData;
  final bool isReply;
  final int indentationLevel;
  final bool isPreview;
  final String? pageOriginalPostId;
  final Function(String, String, Color) showSnackBar;
  final Function(Map<String, dynamic>) onSharePost;
  final Function(String parentReplyId) onReplyToItem;
  final Function() refreshReplies;
  final Function(Map<String, dynamic> updatedReplyData) onReplyDataUpdated;
  final bool drawInternalVerticalLine;
  final int postDepth;

  const PostContent({
    Key? key,
    required this.postData,
    required this.isReply,
    this.indentationLevel = 0,
    this.isPreview = false,
    this.pageOriginalPostId,
    required this.showSnackBar,
    required this.onSharePost,
    required this.onReplyToItem,
    required this.refreshReplies,
    required this.onReplyDataUpdated,
    this.drawInternalVerticalLine = true,
    required this.postDepth,
  }) : super(key: key);

  @override
  _PostContentState createState() => _PostContentState();
}

class _PostContentState extends State<PostContent> {
  late DataController _dataController;
  late Map<String, dynamic> _currentPostData;

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
    _initializePostData();
  }

  void _initializePostData() {
    _currentPostData = Map<String, dynamic>.from(widget.postData);
    _currentPostData['likes'] = List<dynamic>.from(_currentPostData['likes'] ?? []);
    _currentPostData['reposts'] = List<dynamic>.from(_currentPostData['reposts'] ?? []);
  }

  @override
  void didUpdateWidget(covariant PostContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postData != oldWidget.postData) {
      _initializePostData();
    }
  }

  String _getContentText() {
    String contentText = _currentPostData['content'] as String? ?? '';
    if (_currentPostData['buffer'] != null && _currentPostData['buffer']['data'] is List) {
      try {
        final List<int> data = List<int>.from(_currentPostData['buffer']['data'] as List);
        contentText = utf8.decode(data);
      } catch (e) {
        widget.showSnackBar('Error', 'Failed to display content.', Colors.red[700]!);
        contentText = 'Error displaying content.';
      }
    }
    return contentText;
  }

  List<Map<String, dynamic>> _processAttachments() {
    final List<Map<String, dynamic>> attachments = [];
    final dynamic rawAttachments = _currentPostData['attachments'];
    if (rawAttachments is List && rawAttachments.isNotEmpty) {
      for (final item in rawAttachments) {
        if (item is Map<String, dynamic>) {
          attachments.add(item);
        } else if (item is Map) {
          try {
            attachments.add(Map<String, dynamic>.from(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ));
          } catch (e) {
            widget.showSnackBar('Error', 'Failed to load attachment.', Colors.red[700]!);
          }
        }
      }
    }
    return attachments;
  }

  Future<void> _handleRepost(String currentEntryId, String threadOriginalPostId, String currentUserId) async {
    Map<String, dynamic> result;
    if (widget.isReply) {
      result = await _dataController.repostReply(threadOriginalPostId, currentEntryId);
    } else {
      result = await _dataController.repostPost(currentEntryId);
    }
    if (result['success'] == true) {
      if (mounted) {
        setState(() {
          var newRepostsList = List<dynamic>.from(_currentPostData['reposts'] ?? []);
          if (!newRepostsList.contains(currentUserId)) {
            newRepostsList.add(currentUserId);
          }
          _currentPostData['reposts'] = newRepostsList;
          _currentPostData['repostsCount'] = newRepostsList.length;
        });
        widget.onReplyDataUpdated(_currentPostData);
      }
    } else {
      widget.showSnackBar('Error', result['message'] ?? 'Failed to repost.', Colors.red[700]!);
    }
  }

  Future<void> _handleLike(String currentEntryId, String threadOriginalPostId, bool isLikedByCurrentUser, String currentUserId) async {
    Map<String, dynamic> result;
    if (widget.isReply) {
      result = isLikedByCurrentUser
          ? await _dataController.unlikeReply(threadOriginalPostId, currentEntryId)
          : await _dataController.likeReply(threadOriginalPostId, currentEntryId);
    } else {
      result = isLikedByCurrentUser
          ? await _dataController.unlikePost(currentEntryId)
          : await _dataController.likePost(currentEntryId);
    }
    if (result['success'] == true) {
      if (mounted) {
        setState(() {
          var newLikesList = List<dynamic>.from(_currentPostData['likes'] ?? []);
          if (isLikedByCurrentUser) {
            newLikesList.removeWhere((id) => id is String ? id == currentUserId : id['_id'] == currentUserId);
          } else if (!newLikesList.any((like) => like is String ? like == currentUserId : like['_id'] == currentUserId)) {
            newLikesList.add(currentUserId);
          }
          _currentPostData['likes'] = newLikesList;
          _currentPostData['likesCount'] = newLikesList.length;
        });
        widget.onReplyDataUpdated(_currentPostData);
      }
    } else {
      widget.showSnackBar('Error', result['message'] ?? 'Failed to update like.', Colors.red[700]!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentEntryId = _currentPostData['_id'] as String? ?? '';
    final String username = _currentPostData['username'] as String? ?? 'Unknown User';
    final String threadOriginalPostId = widget.pageOriginalPostId ?? (_currentPostData['originalPostId'] as String? ?? currentEntryId);
    final String? userAvatar = _currentPostData['useravatar'] as String?;
    final String avatarInitial = _currentPostData['avatarInitial'] as String? ?? (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = _currentPostData['createdAt'] is String
        ? (DateTime.tryParse(_currentPostData['createdAt'] as String) ?? DateTime.now())
        : (_currentPostData['createdAt'] is DateTime ? _currentPostData['createdAt'] as DateTime : DateTime.now());

    final String contentText = _getContentText();
    final List<Map<String, dynamic>> attachments = _processAttachments();

    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';
    final List<dynamic> likesList = _currentPostData['likes'] is List ? _currentPostData['likes'] as List<dynamic> : [];
    final bool isLikedByCurrentUser = likesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId));

    final int likesCount = _currentPostData['likesCount'] as int? ?? likesList.length;
    final int repostsCount = _currentPostData['repostsCount'] as int? ?? (_currentPostData['reposts']?.length ?? 0);
    final int viewsCount = _currentPostData['viewsCount'] as int? ?? (_currentPostData['views']?.length ?? 0);
    final int repliesCount = _currentPostData['repliesCount'] as int? ?? (_currentPostData['replies']?.length ?? 0);
    final int itemDepth = _currentPostData['depth'] as int? ?? 0;

    final double avatarRadius = widget.isReply ? 14 : 18;
    final double indentOffset = widget.indentationLevel * 20.0;

    if (widget.isReply && !widget.isPreview) {
      _dataController.viewReply(threadOriginalPostId, currentEntryId);
    }

    Widget contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: widget.isReply ? indentOffset : 8.0,
                top: 8.0,
                right: 12.0,
              ),
              child: widget.isReply && !widget.isPreview && widget.drawInternalVerticalLine
                  ? CustomPaint(
                      painter: _VerticalLinePainter(avatarRadius: avatarRadius, avatarLeftPadding: 0),
                      child: Padding(
                        padding: EdgeInsets.only(left: avatarRadius + 6),
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.tealAccent.withOpacity(0.2),
                          backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                          child: userAvatar == null || userAvatar.isEmpty
                              ? Text(
                                  avatarInitial,
                                  style: GoogleFonts.poppins(
                                    color: Colors.tealAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: widget.isReply ? 12 : 14,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: Colors.tealAccent.withOpacity(0.2),
                      backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                      child: userAvatar == null || userAvatar.isEmpty
                          ? Text(
                              avatarInitial,
                              style: GoogleFonts.poppins(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: widget.isReply ? 12 : 14,
                              ),
                            )
                          : null,
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: widget.isReply
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReplyPage(
                                  post: _currentPostData,
                                  originalPostId: threadOriginalPostId,
                                   postDepth: widget.postDepth, // The ReplyPage displays this item, so it's at this depth
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '@$username',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: widget.isReply ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${DateFormat('h:mm a').format(timestamp)} · ${DateFormat('MMM d, yyyy').format(timestamp)} · $viewsCount views',
                                style: GoogleFonts.roboto(
                                  fontSize: widget.isReply ? 11 : 12,
                                  color: Colors.grey[400],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          contentText,
                          style: GoogleFonts.roboto(
                            fontSize: widget.isReply ? 13 : 14,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                        if (attachments.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ReplyAttachmentGrid(
                            attachmentsArg: attachments,
                            postOrReplyData: _currentPostData,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (itemDepth < 9)
                          StatButton(
                            icon: FeatherIcons.messageCircle,
                            text: '$repliesCount',
                            color: Colors.tealAccent,
                            onPressed: () => widget.onReplyToItem(currentEntryId),
                          )
                        else
                          const SizedBox(width: 24 + 8),
                        StatButton(
                          icon: FeatherIcons.eye,
                          text: '$viewsCount',
                          color: Colors.white70,
                          onPressed: () {
                            print("Views button tapped for post/reply $currentEntryId - $viewsCount views");
                          },
                        ),
                        StatButton(
                          icon: FeatherIcons.repeat,
                          text: '$repostsCount',
                          color: Colors.greenAccent,
                          onPressed: () => _handleRepost(currentEntryId, threadOriginalPostId, currentUserId),
                        ),
                        StatButton(
                          icon: isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart,
                          text: '$likesCount',
                          color: isLikedByCurrentUser ? Colors.pinkAccent : Colors.pinkAccent.withOpacity(0.7),
                          onPressed: () => _handleLike(currentEntryId, threadOriginalPostId, isLikedByCurrentUser, currentUserId),
                        ),
                        if (!widget.isReply)
                          StatButton(
                            icon: FeatherIcons.bookmark,
                            text: '',
                            color: Colors.white70,
                            onPressed: () {
                              print('Bookmark action triggered for @$username (UI only, no snackbar)');
                            },
                          )
                        else
                          const SizedBox(width: 24 + 8),
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: contentColumn,
      );
    }

    final EdgeInsets outerPadding = widget.isReply
        ? const EdgeInsets.only(left: 4.0, right: 4.0, top: 4.0, bottom: 4.0)
        : const EdgeInsets.only(left: 8.0, right: 4.0, top: 8.0, bottom: 4.0);

    return Padding(
      padding: outerPadding,
      child: contentColumn,
    );
  }
}

class _VerticalLinePainter extends CustomPainter {
  final double avatarRadius;
  final double avatarLeftPadding;

  _VerticalLinePainter({required this.avatarRadius, required this.avatarLeftPadding});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 1.5;

    final double lineX = (avatarRadius + 6) / 2;
    canvas.drawLine(Offset(lineX, avatarRadius), Offset(lineX, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _VerticalLinePainter oldDelegate) {
    return oldDelegate.avatarRadius != avatarRadius || oldDelegate.avatarLeftPadding != avatarLeftPadding;
  }
}