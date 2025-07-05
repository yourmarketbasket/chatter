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
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


class PostContent extends StatefulWidget {
  final Map<String, dynamic> postData;
  final bool isReply;
  final int indentLevel;
  final String? pageOriginalPostId; // The original post ID of the ReplyPage itself
  final Function(String, String, Color) showSnackBar; // For user feedback
  final Function(Map<String, dynamic>) onSharePost; // Callback for sharing
  final Function(String parentReplyId) onReplyToItem; // Callback to initiate a reply
  final Function() refreshReplies; // Callback to refresh replies list after an action

  // Added for state updates within PostContent for likes/reposts on replies
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

    // Determine the ultimate root post ID for API calls.
    // If pageOriginalPostId is provided (meaning we are on a ReplyPage), use it.
    // Otherwise, if this PostContent is for a reply (isReply=true), it should have an originalPostId.
    // If it's not a reply and no pageOriginalPostId, then this post itself is the root.
    final String threadOriginalPostId = widget.pageOriginalPostId ??
                                     (_currentPostData['originalPostId'] as String? ?? currentEntryId);


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
            correctlyTypedAttachments.add(Map<String, dynamic>.from(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ));
          } catch (e) {
            print('Error converting attachment Map to Map<String, dynamic>: $e. Attachment: $item');
          }
        }
      }
    }

    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';
    final List<dynamic> likesList = _currentPostData['likes'] is List ? _currentPostData['likes'] as List<dynamic> : [];
    final bool isLikedByCurrentUser = likesList.any((like) =>
        (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId)
    );

    final int likesCount = _currentPostData['likesCount'] as int? ?? likesList.length;
    final int repostsCount = _currentPostData['repostsCount'] as int? ?? (_currentPostData['reposts'] is List ? (_currentPostData['reposts'] as List).length : 0);
    final int viewsCount = _currentPostData['viewsCount'] as int? ?? (_currentPostData['views'] is List ? (_currentPostData['views'] as List).length : 0);
    final int repliesCount = _currentPostData['repliesCount'] as int? ?? (_currentPostData['replies'] is List ? (_currentPostData['replies'] as List).length : 0);

    final EdgeInsets postItemPadding = widget.isReply
        ? EdgeInsets.only(left: 16.0 * widget.indentLevel + 4.0, right: 4.0)
        : const EdgeInsets.only(right: 4.0);

    // View tracking:
    // For the main post on the page, viewing is handled in ReplyPage's initState.
    // For replies displayed on the page, viewReply is called here.
    if (widget.isReply) {
      // Ensure threadOriginalPostId is valid (it's the root post of the thread)
      // currentEntryId is the ID of this specific reply item.
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
                padding: EdgeInsets.only(top: 8.0, right: 12.0, left: widget.isReply ? 0 : 8.0),
                child: CircleAvatar(
                  radius: widget.isReply ? 14 : 18,
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
                      behavior: HitTestBehavior.opaque, // Ensure it captures taps within its bounds
                      onTap: widget.isReply ? () {
                        print("[PostContent onTap Navigating] Main content area tapped for Reply ID: ${_currentPostData['_id']}");
                        print("  - widget.isReply: ${widget.isReply}");
                        print("  - Navigating with post (content): '${_currentPostData['content']}' (ID: ${_currentPostData['_id']})");
                        print("  - Passing to new ReplyPage as originalPostId (threadOriginalPostId): $threadOriginalPostId");
                        // Navigate to a new ReplyPage for this reply.
                        // The postData for the new page is _currentPostData (this reply).
                        // The originalPostId for the new page is threadOriginalPostId.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReplyPage( // This creates a dependency on ReplyPage
                              post: _currentPostData,
                              originalPostId: threadOriginalPostId,
                            ),
                          ),
                        );
                      } : null,
                      child: Container(
                        color: Colors.red.withOpacity(0.1), // VISUAL DEBUG for tap area
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
                              // The other props like username, timestamp for MediaViewPage are derived from postOrReplyData by ReplyAttachmentDisplayWidget
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
                          StatButton(
                            icon: FeatherIcons.messageCircle,
                            text: '$repliesCount',
                            color: Colors.tealAccent,
                            onPressed: () {
                              widget.onReplyToItem(currentEntryId); // Pass current item's ID
                              // widget.showSnackBar('Reply', 'Replying to @$username...', Colors.teal[700]!);
                            },
                          ),
                          StatButton( // Views button
                            icon: FeatherIcons.eye,
                            text: '$viewsCount',
                            color: Colors.white70, // Or another distinct color
                            onPressed: () {
                              // Typically, views are just for display, no action on tap.
                              // If an action is needed (e.g., show list of viewers), implement here.
                              print("Views button tapped for post/reply $currentEntryId - $viewsCount views");
                            },
                          ),
                          StatButton(
                            icon: FeatherIcons.repeat,
                            text: '$repostsCount',
                            color: Colors.greenAccent,
                            onPressed: () async {
                              Map<String, dynamic> result;
                              if (widget.isReply) {
                                result = await _dataController.repostReply(threadOriginalPostId, currentEntryId);
                                if (result['success'] == true) {
                                  widget.showSnackBar('Success', result['message'] ?? 'Reply reposted!', Colors.green[700]!);
                                  if (mounted) {
                                    setState(() {
                                      var newRepostsList = List<dynamic>.from(_currentPostData['reposts'] ?? []);
                                      if (!newRepostsList.contains(currentUserId)) {
                                        newRepostsList.add(currentUserId); // Or the user object if backend expects that
                                      }
                                      _currentPostData['reposts'] = newRepostsList;
                                      _currentPostData['repostsCount'] = newRepostsList.length;
                                    });
                                    widget.onReplyDataUpdated(_currentPostData);
                                  }
                                } else {
                                  widget.showSnackBar('Error', result['message'] ?? 'Failed to repost reply.', Colors.red[700]!);
                                }
                              } else { // It's a main post
                                result = await _dataController.repostPost(currentEntryId);
                                 if (result['success'] == true) {
                                  widget.showSnackBar('Success', result['message'] ?? 'Post reposted!', Colors.green[700]!);
                                   if (mounted) {
                                      setState(() {
                                        var newRepostsList = List<dynamic>.from(_currentPostData['reposts'] ?? []);
                                        if (!newRepostsList.contains(currentUserId)) {
                                          newRepostsList.add(currentUserId);
                                        }
                                        _currentPostData['reposts'] = newRepostsList;
                                        _currentPostData['repostsCount'] = newRepostsList.length;
                                      });
                                      // For main post, ReplyPage itself might need to update its state if _mainPostData is used directly
                                      // This callback allows ReplyPage to sync if needed.
                                      widget.onReplyDataUpdated(_currentPostData);
                                    }
                                } else {
                                  widget.showSnackBar('Error', result['message'] ?? 'Failed to repost post.', Colors.red[700]!);
                                }
                              }
                            },
                          ),
                          StatButton(
                            icon: isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart,
                            text: '$likesCount',
                            color: isLikedByCurrentUser ? Colors.pinkAccent : Colors.pinkAccent.withOpacity(0.7),
                            onPressed: () async {
                              Map<String, dynamic> result;
                              if (widget.isReply) {
                                if (isLikedByCurrentUser) {
                                  result = await _dataController.unlikeReply(threadOriginalPostId, currentEntryId);
                                  if (result['success'] == true) {
                                    widget.showSnackBar('Success', result['message'] ?? 'Reply unliked!', Colors.grey[700]!);
                                    if (mounted) {
                                      setState(() {
                                        var newLikesList = List<dynamic>.from(_currentPostData['likes'] ?? []);
                                        newLikesList.removeWhere((id) => (id is Map ? id['_id'] == currentUserId : id.toString() == currentUserId));
                                        _currentPostData['likes'] = newLikesList;
                                        _currentPostData['likesCount'] = newLikesList.length;
                                      });
                                      widget.onReplyDataUpdated(_currentPostData);
                                    }
                                  } else {
                                    widget.showSnackBar('Error', result['message'] ?? 'Failed to unlike reply.', Colors.red[700]!);
                                  }
                                } else {
                                  result = await _dataController.likeReply(threadOriginalPostId, currentEntryId);
                                  if (result['success'] == true) {
                                    widget.showSnackBar('Success', result['message'] ?? 'Reply liked!', Colors.pink[700]!);
                                    if (mounted) {
                                      setState(() {
                                        var newLikesList = List<dynamic>.from(_currentPostData['likes'] ?? []);
                                        if (!newLikesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId))) {
                                          newLikesList.add(currentUserId); // Or the user object
                                        }
                                        _currentPostData['likes'] = newLikesList;
                                        _currentPostData['likesCount'] = newLikesList.length;
                                      });
                                      widget.onReplyDataUpdated(_currentPostData);
                                    }
                                  } else {
                                    widget.showSnackBar('Error', result['message'] ?? 'Failed to like reply.', Colors.red[700]!);
                                  }
                                }
                              } else { // It's a main post
                                if (isLikedByCurrentUser) {
                                  result = await _dataController.unlikePost(currentEntryId);
                                  if (result['success'] == true) {
                                    widget.showSnackBar('Success', result['message'] ?? 'Post unliked!', Colors.grey[700]!);
                                     if (mounted) {
                                        setState(() {
                                          var newLikesList = List<dynamic>.from(_currentPostData['likes'] ?? []);
                                          newLikesList.removeWhere((id) => (id is Map ? id['_id'] == currentUserId : id.toString() == currentUserId));
                                          _currentPostData['likes'] = newLikesList;
                                          _currentPostData['likesCount'] = newLikesList.length;
                                        });
                                        widget.onReplyDataUpdated(_currentPostData);
                                      }
                                  } else {
                                     widget.showSnackBar('Error', result['message'] ?? 'Failed to unlike post.', Colors.red[700]!);
                                  }
                                } else {
                                  result = await _dataController.likePost(currentEntryId);
                                  if (result['success'] == true) {
                                    widget.showSnackBar('Success', result['message'] ?? 'Post liked!', Colors.pink[700]!);
                                    if (mounted) {
                                      setState(() {
                                        var newLikesList = List<dynamic>.from(_currentPostData['likes'] ?? []);
                                         if (!newLikesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId))) {
                                          newLikesList.add(currentUserId);
                                        }
                                        _currentPostData['likes'] = newLikesList;
                                        _currentPostData['likesCount'] = newLikesList.length;
                                      });
                                      widget.onReplyDataUpdated(_currentPostData);
                                    }
                                  } else {
                                    widget.showSnackBar('Error', result['message'] ?? 'Failed to like post.', Colors.red[700]!);
                                  }
                                }
                              }
                            },
                          ),
                          if (!widget.isReply) // Bookmark only for original post
                            StatButton(
                              icon: FeatherIcons.bookmark,
                              text: '', // No count for bookmark in this UI
                              color: Colors.white70,
                              onPressed: () {
                                // Bookmark logic here, potentially call _dataController
                                widget.showSnackBar(
                                  'Bookmark Post',
                                  'Bookmark post by @$username (not implemented yet).',
                                  Colors.teal[700]!,
                                );
                              },
                            ),
                          if (widget.isReply) // Empty SizedBox to maintain spacing alignment with main post's bookmark
                            const SizedBox(width: 24 + 8), // Approx width of a StatButton (icon + text + padding)

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
}
