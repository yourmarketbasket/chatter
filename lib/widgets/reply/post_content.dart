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
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class PostContent extends StatefulWidget {
  final Map<String, dynamic> postData;
  final bool isReply;
  final int indentLevel;
  final String? pageOriginalPostId;
  final Function(String, String, Color) showSnackBar;
  final Function(Map<String, dynamic>) onSharePost;
  final Function(String parentReplyId) onReplyToItem;
  final Function() refreshReplies;
  final Function(Map<String, dynamic> updatedReplyData) onReplyDataUpdated;

  const PostContent({
    Key? key,
    required this.postData,
    required this.isReply,
    this.indentLevel = 0,
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
  late Map<String, dynamic> _currentPostData;

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
    _currentPostData = Map<String, dynamic>.from(widget.postData);
    _initializeLists();
  }

  void _initializeLists() {
    if (_currentPostData['likes'] != null && _currentPostData['likes'] is List) {
      _currentPostData['likes'] = List<dynamic>.from(_currentPostData['likes'] as List);
    } else {
      _currentPostData['likes'] = <dynamic>[];
    }
    if (_currentPostData['reposts'] != null && _currentPostData['reposts'] is List) {
      _currentPostData['reposts'] = List<dynamic>.from(_currentPostData['reposts'] as List);
    } else {
      _currentPostData['reposts'] = <dynamic>[];
    }
  }

  @override
  void didUpdateWidget(covariant PostContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postData != oldWidget.postData) {
      _currentPostData = Map<String, dynamic>.from(widget.postData);
      _initializeLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentEntryId = _currentPostData['_id'] as String? ?? '';
    final String username = _currentPostData['username'] as String? ?? 'Unknown User';
    final String threadOriginalPostId = widget.pageOriginalPostId ??
        (_currentPostData['originalPostId'] as String? ?? currentEntryId);

    String contentText = _currentPostData['content'] as String? ?? '';
    if (_currentPostData['buffer'] != null && _currentPostData['buffer']['data'] is List) {
      try {
        final List<int> data = List<int>.from(_currentPostData['buffer']['data'] as List);
        contentText = utf8.decode(data);
      } catch (e) {
        debugPrint('Error decoding buffer content for $currentEntryId: $e');
        contentText = 'Error displaying content.';
      }
    }

    final String? userAvatar = _currentPostData['useravatar'] as String?;
    final String avatarInitial = _currentPostData['avatarInitial'] as String? ??
        (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = _currentPostData['createdAt'] is String
        ? (DateTime.tryParse(_currentPostData['createdAt'] as String) ?? DateTime.now())
        : (_currentPostData['createdAt'] is DateTime
            ? _currentPostData['createdAt'] as DateTime
            : DateTime.now());

    List<Map<String, dynamic>> correctlyTypedAttachments = [];
    final dynamic rawAttachments = _currentPostData['attachments'];
    if (rawAttachments is List && rawAttachments.isNotEmpty) {
      for (final item in rawAttachments) {
        if (item is Map<String, dynamic>) {
          correctlyTypedAttachments.add(item);
        } else if (item is Map) {
          try {
            correctlyTypedAttachments.add(Map<String, dynamic>.from(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ));
          } catch (e) {
            debugPrint('Error converting attachment Map to Map<String, dynamic>: $e. Attachment: $item');
          }
        }
      }
    }

    final String currentUserId = _dataController.user.value['user']?['_id'] as String? ?? '';
    final List<dynamic> likesList = _currentPostData['likes'] ?? [];
    final bool isLikedByCurrentUser = likesList.any((like) =>
        (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId));

    final int likesCount = _currentPostData['likesCount'] as int? ?? likesList.length;
    final int repostsCount = _currentPostData['repostsCount'] as int? ??
        (_currentPostData['reposts']?.length ?? 0);
    final int viewsCount = _currentPostData['viewsCount'] as int? ??
        (_currentPostData['views']?.length ?? 0);
    final int repliesCount = _currentPostData['repliesCount'] as int? ??
        (_currentPostData['replies']?.length ?? 0);

    final EdgeInsets postItemPadding = widget.isReply
        ? EdgeInsets.only(left: 16.0 * widget.indentLevel + 4.0, right: 4.0)
        : const EdgeInsets.only(right: 4.0);

    if (widget.isReply && currentEntryId.isNotEmpty) {
      _dataController.viewReply(threadOriginalPostId, currentEntryId);
    }

    return Padding(
      padding: postItemPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                    top: 8.0, right: 12.0, left: widget.isReply ? 0 : 8.0),
                child: CircleAvatar(
                  radius: widget.isReply ? 14 : 18,
                  backgroundColor: Colors.tealAccent.withOpacity(0.2),
                  backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                      ? NetworkImage(userAvatar)
                      : null,
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
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.isReply
                          ? () {
                              debugPrint(
                                  "[PostContent onTap Navigating] Main GESTUREDETECTOR tapped for Reply ID: $currentEntryId");
                              debugPrint(
                                  "  - widget.isReply: ${widget.isReply}");
                              debugPrint(
                                  "  - Navigating with post (content): '${_currentPostData['content']}' (ID: $currentEntryId)");
                              debugPrint(
                                  "  - Passing to new ReplyPage as originalPostId (threadOriginalPostId): $threadOriginalPostId");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReplyPage(
                                    post: _currentPostData,
                                    originalPostId: threadOriginalPostId,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Listener(
                        onPointerDown: (event) {
                          debugPrint(
                              "[PostContent Listener onPointerDown] Event at ${event.position} for item ID: $currentEntryId");
                        },
                        onPointerUp: (event) {
                          debugPrint(
                              "[PostContent Listener onPointerUp] Event at ${event.position} for item ID: $currentEntryId");
                        },
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
                                color: const Color.fromARGB(255, 255, 255, 255),
                                height: 1.5,
                              ),
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
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatButton(
                            icon: FeatherIcons.messageCircle,
                            text: '$repliesCount',
                            color: Colors.tealAccent,
                            onPressed: () {
                              widget.onReplyToItem(currentEntryId);
                            },
                          ),
                          StatButton(
                            icon: FeatherIcons.eye,
                            text: '$viewsCount',
                            color: Colors.white70,
                            onPressed: () {
                              debugPrint(
                                  "Views button tapped for post/reply $currentEntryId - $viewsCount views");
                            },
                          ),
                          StatButton(
                            icon: FeatherIcons.repeat,
                            text: '$repostsCount',
                            color: Colors.greenAccent,
                            onPressed: () async {
                              Map<String, dynamic> result;
                              if (widget.isReply) {
                                result = await _dataController.repostReply(
                                    threadOriginalPostId, currentEntryId);
                                _handleRepostResult(result, currentUserId);
                              } else {
                                result = await _dataController
                                    .repostPost(currentEntryId);
                                _handleRepostResult(result, currentUserId);
                              }
                            },
                          ),
                          StatButton(
                            icon: isLikedByCurrentUser
                                ? Icons.favorite
                                : FeatherIcons.heart,
                            text: '$likesCount',
                            color: isLikedByCurrentUser
                                ? Colors.pinkAccent
                                : Colors.pinkAccent.withOpacity(0.7),
                            onPressed: () async {
                              Map<String, dynamic> result;
                              if (widget.isReply) {
                                if (isLikedByCurrentUser) {
                                  result = await _dataController.unlikeReply(
                                      threadOriginalPostId, currentEntryId);
                                  _handleLikeResult(
                                      result, currentUserId, false);
                                } else {
                                  result = await _dataController.likeReply(
                                      threadOriginalPostId, currentEntryId);
                                  _handleLikeResult(result, currentUserId, true);
                                }
                              } else {
                                if (isLikedByCurrentUser) {
                                  result = await _dataController
                                      .unlikePost(currentEntryId);
                                  _handleLikeResult(
                                      result, currentUserId, false);
                                } else {
                                  result = await _dataController
                                      .likePost(currentEntryId);
                                  _handleLikeResult(result, currentUserId, true);
                                }
                              }
                            },
                          ),
                          if (!widget.isReply)
                            StatButton(
                              icon: FeatherIcons.bookmark,
                              text: '',
                              color: Colors.white70,
                              onPressed: () {
                                widget.showSnackBar(
                                  'Bookmark Post',
                                  'Bookmark post by @$username (not implemented yet).',
                                  Colors.teal[700]!,
                                );
                              },
                            ),
                          if (widget.isReply)
                            const SizedBox(width: 32),
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
      ),
    );
  }

  void _handleRepostResult(
      Map<String, dynamic> result, String currentUserId) {
    if (result['success'] == true) {
      widget.showSnackBar(
          'Success', result['message'] ?? 'Reposted!', Colors.green[700]!);
      if (mounted) {
        setState(() {
          var newRepostsList = List<dynamic>.from(_currentPostData['reposts']);
          if (!newRepostsList.contains(currentUserId)) {
            newRepostsList.add(currentUserId);
          }
          _currentPostData['reposts'] = newRepostsList;
          _currentPostData['repostsCount'] = newRepostsList.length;
        });
        widget.onReplyDataUpdated(_currentPostData);
      }
    } else {
      widget.showSnackBar(
          'Error', result['message'] ?? 'Failed to repost.', Colors.red[700]!);
    }
  }

  void _handleLikeResult(
      Map<String, dynamic> result, String currentUserId, bool isLiking) {
    if (result['success'] == true) {
      widget.showSnackBar(
          'Success',
          result['message'] ?? (isLiking ? 'Liked!' : 'Unliked!'),
          isLiking ? Colors.pink[700]! : Colors.grey[700]!);
      if (mounted) {
        setState(() {
          var newLikesList = List<dynamic>.from(_currentPostData['likes']);
          if (isLiking) {
            if (!newLikesList.any((like) =>
                (like is Map
                    ? like['_id'] == currentUserId
                    : like.toString() == currentUserId))) {
              newLikesList.add(currentUserId);
            }
          } else {
            newLikesList.removeWhere((id) => (id is Map
                ? id['_id'] == currentUserId
                : id.toString() == currentUserId));
          }
          _currentPostData['likes'] = newLikesList;
          _currentPostData['likesCount'] = newLikesList.length;
        });
        widget.onReplyDataUpdated(_currentPostData);
      }
    } else {
      widget.showSnackBar(
          'Error',
          result['message'] ?? (isLiking ? 'Failed to like.' : 'Failed to unlike.'),
          Colors.red[700]!);
    }
  }
}