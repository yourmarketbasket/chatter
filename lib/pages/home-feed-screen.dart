import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/new-posts-page.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:chatter/pages/repost_page.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/pages/search_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:chatter/widgets/video_attachment_widget.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final DataController dataController = Get.find<DataController>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToPostScreen() async {
    final result = await Get.bottomSheet<Map<String, dynamic>>(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: const NewPostScreen(),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (result != null && result is Map<String, dynamic>) {
      final String content = result['content'] as String? ?? '';
      final List<Map<String, dynamic>> attachments =
          (result['attachments'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? <Map<String, dynamic>>[];

      if (content.isNotEmpty || attachments.isNotEmpty) {
        _addPost(content, attachments);
      }
    }
  }

  Future<void> _navigateToRepostPage(Map<String, dynamic> post) async {
    final confirmed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepostPage(post: post),
      ),
    );

    if (confirmed == true) {
      setState(() {
        post['reposts'] = (post['reposts'] ?? 0) + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Poa! Reposted!',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.teal[700],
        ),
      );
    }
  }

  Future<void> _addPost(String content, List<Map<String, dynamic>> attachments) async {
    print('[HomeFeedScreen _addPost] Received ${attachments.length} attachments.');
    for (int i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      try {
        print(
            '[HomeFeedScreen _addPost] Attachment ${i + 1}: type=${a['type']}, path=${(a['file'] as File?)?.path}, '
            'file_exists_sync=${(a['file'] as File?)?.existsSync()}, length_sync=${(a['file'] as File?)?.lengthSync()}, '
            'filename=${a['filename']}, size=${a['size']}, url=${a['url']}');
      } catch (e) {
        print(
            '[HomeFeedScreen _addPost] Attachment ${i + 1}: type=${a['type']}, path=${(a['file'] as File?)?.path}, '
            'url=${a['url']} - Error getting file stats: $e');
      }
    }

    List<Map<String, dynamic>> uploadedAttachments = [];
    if (attachments.isNotEmpty) {
      List<File> files = attachments.where((a) => a['file'] != null).map((a) => a['file']! as File).toList();
      print('[HomeFeedScreen _addPost] Extracted ${files.length} files for upload:');
      for (int i = 0; i < files.length; i++) {
        final f = files[i];
        try {
          print('[HomeFeedScreen _addPost] File ${i + 1} for upload: path=${f.path}, exists_sync=${f.existsSync()}, '
              'length_sync=${f.lengthSync()}');
        } catch (e) {
          print('[HomeFeedScreen _addPost] File ${i + 1} for upload: path=${f.path} - Error getting file stats: $e');
        }
      }
      List<Map<String, dynamic>> uploadResults = await dataController.uploadFiles(files);

      for (int i = 0; i < attachments.length; i++) {
        var result = uploadResults[i];
        final originalAttachment = attachments.firstWhere(
            (att) => (att['file'] as File?)?.path == result['filePath'],
            orElse: () => attachments[i]);

        print(result);
        if (result['success'] == true) {
          String originalUrl = result['url'] as String;
          String? thumbnailUrl = result['thumbnailUrl'] as String?;
          uploadedAttachments.add({
            'file': originalAttachment['file'],
            'type': originalAttachment['type'],
            'filename':
                (originalAttachment['file'] as File?)?.path.split('/').last ?? result['filename'] ?? 'unknown',
            'size': result['size'] ??
                ((originalAttachment['file'] as File?) != null ? await (originalAttachment['file'] as File)!.length() : 0),
            'url': originalUrl,
            'thumbnailUrl': thumbnailUrl,
            'aspectRatio': result['aspectRatio'] ?? 16 / 9, // Aspect ratio from uploadFiles
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload ${(originalAttachment['file'] as File?)?.path.split('/').last}: ${result['message']}',
                style: GoogleFonts.roboto(color: Colors.white),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }

    if (content.trim().isEmpty && uploadedAttachments.isEmpty) {
      return;
    }

    Map<String, dynamic> postData = {
      'username': dataController.user.value['user']['name'] ?? 'YourName',
      'content': content.trim(),
      'useravatar': dataController.user.value['avatar'] ?? '',
      'attachments': uploadedAttachments.map((att) => {
            'filename': att['filename'],
            'url': att['url'],
            'size': att['size'],
            'type': att['type'],
            'thumbnailUrl': att['thumbnailUrl'],
            'aspectRatio': att['aspectRatio'],
          }).toList(),
    };

    final result = await dataController.createPost(postData);

    if (result['success'] == true) {
      if (result['post'] != null) {
        dataController.addNewPost(result['post'] as Map<String, dynamic>);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fantastic! Your chatter is live!',
              style: GoogleFonts.roboto(color: Colors.white),
            ),
            backgroundColor: Colors.teal[700],
          ),
        );
      } else {
        dataController.fetchFeeds();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chatter posted! Refreshing feed to show it.',
              style: GoogleFonts.roboto(color: Colors.white),
            ),
            backgroundColor: Colors.orange[700],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Could not create post, please try again later',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<void> _navigateToReplyPage(Map<String, dynamic> post) async {
    final newReply = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyPage(post: post),
      ),
    );

    if (newReply != null && newReply is Map<String, dynamic>) {
      Map<String, dynamic> replyData = {
        'username': newReply['username'] ?? 'YourName',
        'content': newReply['content']?.trim() ?? '',
        'useravatar': newReply['useravatar'] ?? '',
        'attachments': (newReply['attachments'] as List<Map<String, dynamic>>?)?.map((att) => {
              'filename': (att['file'] as File?)?.path.split('/').last ?? att['filename'] ?? 'unknown',
              'url': att['url'],
              'size': (att['file'] as File?) != null ? (att['file'] as File).lengthSync() : att['size'] ?? 0,
              'type': att['type'],
              'thumbnailUrl': att['thumbnailUrl'],
              'aspectRatio': att['aspectRatio'],
            }).toList() ??
            [],
      };

      final postId = post['_id'] as String?;
      if (postId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Original post ID is missing.', style: GoogleFonts.roboto(color: Colors.white)),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      final result = await dataController.replyToPost(
        postId: postId,
        content: replyData['content'] as String,
        attachments: replyData['attachments'] as List<Map<String, dynamic>>,
      );

      if (result['success'] == true) {
        final postIndex = dataController.posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          final postMap = dataController.posts[postIndex];
          postMap['replyCount'] = (postMap['replyCount'] ?? 0) + 1;
          dataController.posts[postIndex] = postMap;
          dataController.posts.refresh();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply added!', style: GoogleFonts.roboto(color: Colors.white)),
            backgroundColor: Colors.teal[700],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add reply: ${result['message'] ?? 'Unknown error'}',
              style: GoogleFonts.roboto(color: Colors.white),
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Widget _buildPostContent(Map<String, dynamic> post, {required bool isReply}) {
    final String username = post['username'] as String? ?? 'Unknown User';
    final String content = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    final String avatarInitial = (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp =
        post['createdAt'] is String ? DateTime.parse(post['createdAt'] as String) : DateTime.now();
    int likes = post['likes'] as int? ?? 0;
    int reposts = post['reposts'] as int? ?? 0;
    int views = post['views'] as int? ?? 0;
    List<Map<String, dynamic>> attachments =
        (post['attachments'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    int replyCount = (post['replies'] as List<dynamic>?)?.length ?? post['replyCount'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 16 : 20,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
              child: userAvatar == null || userAvatar.isEmpty
                  ? Text(
                      avatarInitial,
                      style: GoogleFonts.poppins(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: isReply ? 14 : 16,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              username,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: isReply ? 14 : 16,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 4.0),
                            Icon(
                              Icons.verified,
                              color: Colors.amber,
                              size: isReply ? 13 : 15,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              ' · @$username',
                              style: GoogleFonts.poppins(
                                fontSize: isReply ? 10 : 12,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a · MMM d').format(timestamp),
                        style: GoogleFonts.roboto(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: GoogleFonts.roboto(
                      fontSize: isReply ? 13 : 14,
                      color: const Color.fromARGB(255, 255, 255, 255),
                      height: 1.5,
                    ),
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildAttachmentGrid(attachments, post),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              FeatherIcons.heart,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                post['likes'] = (post['likes'] as int? ?? 0) + 1;
                              });
                            },
                          ),
                          Text(
                            '$likes',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              FeatherIcons.messageCircle,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              _navigateToReplyPage(post);
                            },
                          ),
                          Text(
                            '$replyCount',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              FeatherIcons.repeat,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              _navigateToRepostPage(post);
                            },
                          ),
                          Text(
                            '$reposts',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              FeatherIcons.eye,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                          Text(
                            '$views',
                            style: GoogleFonts.roboto(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttachmentGrid(List<Map<String, dynamic>> attachmentsArg, Map<String, dynamic> post) {
    const double itemSpacing = 4.0;

    if (attachmentsArg.isEmpty) {
      return const SizedBox.shrink();
    }

    if (attachmentsArg.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _buildAttachmentWidget(
          attachmentsArg[0],
          0,
          post,
          BorderRadius.circular(12.0),
          fit: BoxFit.cover,
        ),
      );
    } else if (attachmentsArg.length == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: AspectRatio(
          aspectRatio: 2 * (4 / 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover),
              ),
              const SizedBox(width: itemSpacing),
              Expanded(
                child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover),
              ),
            ],
          ),
        ),
      );
    } else if (attachmentsArg.length == 3) {
      return LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          const double borderRadius = 12.0;
          double leftItemWidth = (width * 0.66) - (itemSpacing / 2);
          double rightColumnWidth = width * 0.33 - (itemSpacing / 2);
          double totalHeight = width * (9 / 16);

          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: SizedBox(
              height: totalHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftItemWidth,
                    child: _buildAttachmentWidget(
                      attachmentsArg[0],
                      0,
                      post,
                      BorderRadius.zero,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: itemSpacing),
                  SizedBox(
                    width: rightColumnWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildAttachmentWidget(
                            attachmentsArg[1],
                            1,
                            post,
                            BorderRadius.zero,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: itemSpacing),
                        Expanded(
                          child: _buildAttachmentWidget(
                            attachmentsArg[2],
                            2,
                            post,
                            BorderRadius.zero,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (attachmentsArg.length == 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: AspectRatio(
          aspectRatio: 1 / 1,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: itemSpacing,
              mainAxisSpacing: itemSpacing,
              childAspectRatio: 1,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              return _buildAttachmentWidget(attachmentsArg[index], index, post, BorderRadius.zero, fit: BoxFit.cover);
            },
          ),
        ),
      );
    } else if (attachmentsArg.length == 5) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const double borderRadius = 12.0;
          double containerWidth = constraints.maxWidth;
          double h1 = (containerWidth - itemSpacing) / 2;
          double h2 = (containerWidth - 2 * itemSpacing) / 3;
          double totalHeight = h1 + itemSpacing + h2;

          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: SizedBox(
              height: totalHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: h1,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildAttachmentWidget(attachmentsArg[0], 0, post, BorderRadius.zero, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                          child: _buildAttachmentWidget(attachmentsArg[1], 1, post, BorderRadius.zero, fit: BoxFit.cover),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: itemSpacing),
                  SizedBox(
                    height: h2,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildAttachmentWidget(attachmentsArg[2], 2, post, BorderRadius.zero, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                          child: _buildAttachmentWidget(attachmentsArg[3], 3, post, BorderRadius.zero, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: itemSpacing),
                        Expanded(
                          child: _buildAttachmentWidget(attachmentsArg[4], 4, post, BorderRadius.zero, fit: BoxFit.cover),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      const int crossAxisCount = 3;
      const double childAspectRatio = 1.0;

      return LayoutBuilder(
        builder: (context, constraints) {
          double itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * itemSpacing) / crossAxisCount;
          double itemHeight = itemWidth / childAspectRatio;
          int numRows = (attachmentsArg.length / crossAxisCount).ceil();
          double totalHeight = numRows * itemHeight + (numRows - 1) * itemSpacing;

          return ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: SizedBox(
              height: totalHeight,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: itemSpacing,
                  mainAxisSpacing: itemSpacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: attachmentsArg.length,
                itemBuilder: (context, index) {
                  return _buildAttachmentWidget(attachmentsArg[index], index, post, BorderRadius.zero, fit: BoxFit.cover);
                },
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildAttachmentWidget(
      Map<String, dynamic> attachmentMap, int idx, Map<String, dynamic> post, BorderRadius borderRadius,
      {BoxFit fit = BoxFit.contain}) {
    final String attachmentType = attachmentMap['type'] as String? ?? 'unknown';
    final String? displayUrl = attachmentMap['url'] as String?;

    List<Map<String, dynamic>> correctlyTypedPostAttachments = [];
    if (post['attachments'] is List) {
      for (var item in (post['attachments'] as List)) {
        if (item is Map<String, dynamic>) {
          correctlyTypedPostAttachments.add(item);
        } else if (item is Map) {
          try {
            correctlyTypedPostAttachments.add(Map<String, dynamic>.from(item));
          } catch (e) {
            print('[HomeFeedScreen] Error converting attachment item Map to Map<String, dynamic>: $e for item $item');
          }
        } else {
          print('[HomeFeedScreen] Skipping non-map attachment item: $item');
        }
      }
    }

    Widget contentWidget;

    if (attachmentType == "video") {
      contentWidget = VideoAttachmentWidget(
        key: Key('video_${attachmentMap['url'] ?? idx}'),
        attachment: attachmentMap,
        post: post,
        borderRadius: BorderRadius.zero,
        isFeedContext: true, // This will be used to tell VideoAttachmentWidget to use 4:3
      );
    } else if (attachmentType == "audio") {
      contentWidget = AudioAttachmentWidget(
        key: Key('audio_${attachmentMap['url'] ?? idx}'),
        attachment: attachmentMap,
        post: post,
        borderRadius: BorderRadius.zero,
      );
    } else if (attachmentType == "image") {
      Widget imageContent;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        imageContent = CachedNetworkImage(
          imageUrl: displayUrl,
          fit: BoxFit.cover, // Ensure image covers the 4:3 area
          placeholder: (context, url) => Container(color: Colors.grey[900]),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[900],
            child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40),
          ),
        );
      } else if ((attachmentMap['file'] as File?) != null) {
        imageContent = Image.file(
          attachmentMap['file'] as File,
          fit: BoxFit.cover, // Ensure image covers the 4:3 area
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[900],
            child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40),
          ),
        );
      } else {
        imageContent = Container(
          color: Colors.grey[900],
          child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40),
        );
      }
      contentWidget = AspectRatio(
        aspectRatio: 4 / 3,
        child: imageContent,
      );
    } else if (attachmentType == "pdf") {
      if (displayUrl != null && displayUrl.isNotEmpty) {
        contentWidget = PdfViewer.uri(
          Uri.parse(displayUrl),
          params: const PdfViewerParams(margin: 0, maxScale: 1.0, backgroundColor: Colors.grey),
        );
      } else {
        contentWidget = Container(
          color: Colors.grey[900],
          child: const Icon(FeatherIcons.fileText, color: Colors.grey, size: 40),
        );
      }
    } else {
      contentWidget = Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              attachmentType == "audio" ? FeatherIcons.music : FeatherIcons.file,
              color: Colors.tealAccent,
              size: 20,
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaViewPage(
              attachments: correctlyTypedPostAttachments,
              initialIndex: idx,
              message: post['content'] as String? ?? '',
              userName: post['username'] as String? ?? 'Unknown User',
              userAvatarUrl: post['useravatar'] as String?,
              timestamp: post['createdAt'] is String ? DateTime.parse(post['createdAt'] as String) : DateTime.now(),
              viewsCount: post['views'] as int? ?? 0,
              likesCount: post['likes'] as int? ?? 0,
              repostsCount: post['reposts'] as int? ?? 0,
              transitionVideoId: (attachmentType == "video" &&
                      dataController.isTransitioningVideo.value &&
                      dataController.activeFeedPlayerVideoId.value == attachmentMap['url'])
                  ? dataController.activeFeedPlayerVideoId.value
                  : null,
              transitionControllerType: (attachmentType == "video" &&
                      dataController.isTransitioningVideo.value &&
                      dataController.activeFeedPlayerVideoId.value == attachmentMap['url'])
                  ? (dataController.activeFeedPlayerController.value is BetterPlayerController
                      ? 'better_player'
                      : 'video_player')
                  : null,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Chatter',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 24,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Obx(() {
        if (dataController.posts.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
            ),
          );
        }
        return ListView.separated(
          controller: _scrollController,
          itemCount: dataController.posts.length,
          separatorBuilder: (context, index) => Divider(
            color: Colors.grey[850],
            height: 1,
          ),
          itemBuilder: (context, index) {
            final postMap = dataController.posts[index] as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
              child: _buildPostContent(postMap, isReply: false),
            );
          },
        );
      }),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        key: GlobalKey<ExpandableFabState>(),
        distance: 65.0,
        type: ExpandableFabType.up,
        overlayStyle: ExpandableFabOverlayStyle(
          color: Colors.black.withOpacity(0.5),
        ),
        openButtonBuilder: RotateFloatingActionButtonBuilder(
          backgroundColor: Colors.tealAccent,
          foregroundColor: Colors.black,
          child: const Icon(FeatherIcons.menu),
        ),
        closeButtonBuilder: RotateFloatingActionButtonBuilder(
          backgroundColor: Colors.tealAccent,
          foregroundColor: Colors.black,
          child: const Icon(Icons.close),
        ),
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_add_post',
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.tealAccent, width: 1),
                borderRadius: BorderRadius.circular(10)),
            onPressed: _navigateToPostScreen,
            tooltip: 'Add Post',
            child: const Icon(FeatherIcons.plusCircle, color: Colors.tealAccent),
          ),
          FloatingActionButton.small(
            heroTag: 'fab_home',
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.tealAccent, width: 1),
                borderRadius: BorderRadius.circular(10)),
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              dataController.fetchFeeds();
            },
            tooltip: 'Home',
            child: const Icon(FeatherIcons.home, color: Colors.tealAccent),
          ),
          FloatingActionButton.small(
            heroTag: 'fab_search',
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.tealAccent, width: 1),
                borderRadius: BorderRadius.circular(10)),
            onPressed: () {
              Get.to(() => const SearchPage(), transition: Transition.rightToLeft);
            },
            tooltip: 'Search',
            child: const Icon(FeatherIcons.search, color: Colors.tealAccent),
          ),
        ],
      ),
    );
  }
}