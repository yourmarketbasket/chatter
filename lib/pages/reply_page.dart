import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/media_view_page.dart';
import 'package:chatter/widgets/video_attachment_widget.dart'; // Import VideoAttachmentWidget
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart'; // Import share_plus
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart'; // Added import

class ReplyPage extends StatefulWidget {
  final Map<String, dynamic> post;

  const ReplyPage({Key? key, required this.post}) : super(key: key);

  @override
  _ReplyPageState createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  final TextEditingController _replyController = TextEditingController();
  final List<Map<String, dynamic>> _replyAttachments = [];
  late DataController _dataController;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  List<Map<String, dynamic>> _replies = [];
  bool _isLoadingReplies = true;
  String? _fetchRepliesError;
  bool _isSubmittingReply = false;
  bool _showReplyField = true; // To toggle reply input field visibility

  @override
  void initState() {
    super.initState();
    _dataController = Get.find<DataController>();
    _fetchPostReplies();

    if (widget.post['_id'] != null) {
      _dataController.viewPost(widget.post['_id'] as String);
    } else {
      print("Error: Post ID is null in ReplyPage. Cannot record view.");
    }
  }

  Future<void> _fetchPostReplies({bool showLoadingIndicator = true}) async {
    if (!mounted) return; // Early exit if not mounted
    setState(() {
      if (showLoadingIndicator) _isLoadingReplies = true;
      _fetchRepliesError = null;
    });

    try {
      final postId = widget.post['_id'] as String?;
      if (postId == null) {
        print("Error: Post ID is null in _fetchPostReplies. Cannot fetch replies.");
        if (mounted) {
          setState(() {
            _fetchRepliesError = 'Cannot load replies: Original post ID is missing.';
            _isLoadingReplies = false;
          });
        }
        return;
      }
      final fetchedReplies = await _dataController.fetchReplies(postId);
      if (mounted) {
        setState(() {
          _replies = fetchedReplies;
          if (showLoadingIndicator) _isLoadingReplies = false;
        });
      }
    } catch (e) {
      print('Error fetching replies: $e');
      if (mounted) {
        setState(() {
          _fetchRepliesError = 'Failed to load replies. Please try again.'; // This message will be simplified later
          if (showLoadingIndicator) _isLoadingReplies = false;
        });
      }
    }

  // Method to share a post
  void _sharePost(Map<String, dynamic> post) {
    final String postId = post['_id'] as String? ?? "unknown_post";
    final String content = post['content'] as String? ?? "Check out this post!";
    // Construct a deep link or a web URL to the post if available
    // Example: String postUrl = "https://chatter.yourdomain.com/post/$postId";
    // For now, just sharing the content.

    String shareText = content;
    // if (postUrl.isNotEmpty) { // Once you have post URLs
    //   shareText += "\n\nView post: $postUrl";
    // }

    Share.share(shareText, subject: 'Check out this post from Chatter!');
  }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  // Method to share a post
  void _sharePost(Map<String, dynamic> post) {
    final String postId = post['_id'] as String? ?? "unknown_post";
    final String content = post['content'] as String? ?? "Check out this post!";
    // Construct a deep link or a web URL to the post if available
    // Example: String postUrl = "https://chatter.yourdomain.com/post/$postId";
    // For now, just sharing the content.

    String shareText = content;
    // if (postUrl.isNotEmpty) { // Once you have post URLs
    //   shareText += "\n\nView post: $postUrl";
    // }

    Share.share(shareText, subject: 'Check out this post from Chatter!');
  }

  Future<int?> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.version.sdkInt;
      } catch (e) {
        print('Error getting Android SDK version: $e');
        return null;
      }
    }
    return null;
  }

  Future<bool> _requestMediaPermissions(String action) async {
    if (!Platform.isAndroid) return true;
    final int? sdkInt = await _getAndroidSdkVersion();
    if (sdkInt == null) {
      _showSnackBar('Error', 'Unable to determine Android version. Check permissions in settings.', Colors.red[700]!);
      return false;
    }
    Permission? permission;
    String permissionName = '';
    switch (action) {
      case 'image': permission = sdkInt >= 33 ? Permission.photos : Permission.storage; permissionName = 'Photos'; break;
      case 'video': permission = sdkInt >= 33 ? Permission.videos : Permission.storage; permissionName = 'Videos'; break;
      case 'audio': permission = sdkInt >= 33 ? Permission.audio : Permission.storage; permissionName = 'Audio'; break;
      case 'pdf': permission = sdkInt < 33 ? Permission.storage : null; permissionName = 'Storage'; break;
      default: return false;
    }
    if (action == 'pdf' && sdkInt >= 33) return true;
    if (permission == null) return false;
    final status = await permission.request();
    if (status.isGranted) return true;
    _showSnackBar('$permissionName Permission Required', status.isPermanentlyDenied ? 'Please enable $permissionName permission in app settings.' : 'Please grant $permissionName permission to continue.', Colors.red[700]!);
    return false;
  }

  void _showSnackBar(String title, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title: $message', style: GoogleFonts.roboto(color: Colors.white)), backgroundColor: backgroundColor));
  }

  Widget _buildPostContent(Map<String, dynamic> post, {required bool isReply}) {
    final String username = post['username'] as String? ?? 'Unknown User';
    final String content = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    final String avatarInitial = post['avatarInitial'] as String? ?? (username.isNotEmpty ? username[0].toUpperCase() : '?');
    final DateTime timestamp = post['timestamp'] is String ? (DateTime.tryParse(post['timestamp'] as String) ?? DateTime.now()) : (post['timestamp'] is DateTime ? post['timestamp'] : DateTime.now());

    List<Map<String, dynamic>> correctlyTypedAttachments = [];
    final dynamic rawAttachments = post['attachments'];
    if (rawAttachments is List) {
      for (final item in rawAttachments) { // Use 'final' for loop variable
        if (item is Map<String, dynamic>) {
          correctlyTypedAttachments.add(item);
        } else if (item is Map) {
          // Attempt to convert Map to Map<String, dynamic>
          // This handles cases where item might be Map<dynamic, dynamic>
          try {
            correctlyTypedAttachments.add(Map<String, dynamic>.from(item.map(
              (key, value) => MapEntry(key.toString(), value),
            )));
          } catch (e) {
            print('Error converting attachment Map to Map<String, dynamic>: $e. Attachment: $item');
            // Optionally, add a placeholder for unconvertible attachments or skip
          }
        } else {
          // Log or handle items that are not maps, if necessary
          print('Skipping non-map attachment item: $item');
        }
      }
    }


    // Stats for original post
    final int likesCount = widget.post['likesCount'] as int? ?? (widget.post['likes'] as List?)?.length ?? 0;
    final int repostsCount = widget.post['repostsCount'] as int? ?? (widget.post['reposts'] as List?)?.length ?? 0;
    final int viewsCount = widget.post['viewsCount'] as int? ?? (widget.post['views'] as List?)?.length ?? 0;

    // Define a minimal horizontal padding to be applied
    const EdgeInsets minimalHorizontalPadding = EdgeInsets.symmetric(horizontal: 4.0);

    return Padding( // Added padding to the whole content block
      padding: minimalHorizontalPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 16 : 20,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
                child: userAvatar == null || userAvatar.isEmpty ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: isReply ? 14 : 16)) : null,
              ),
              const SizedBox(width: 8), // Reduced space next to avatar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('@$username', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isReply ? 14 : 16, color: Colors.white)),
                      Text(DateFormat('h:mm a · MMM d').format(timestamp), style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(content, style: GoogleFonts.roboto(fontSize: isReply ? 13 : 14, color: Colors.white70, height: 1.5)),
                  if (correctlyTypedAttachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildReplyAttachmentGrid(correctlyTypedAttachments, post, username, userAvatar, timestamp, viewsCount, likesCount, repostsCount, content),
                  ],
                  if (!isReply) ...[ // Show stats only for the main post, not for replies in this context
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat(FeatherIcons.heart, '$likesCount Likes', Colors.pinkAccent),
                        _buildStat(FeatherIcons.repeat, '$repostsCount Reposts', Colors.greenAccent),
                        _buildStat(FeatherIcons.eye, '$viewsCount Views', Colors.blueAccent),
                        IconButton(icon: const Icon(FeatherIcons.share2, color: Colors.white70, size: 18), onPressed: () => _sharePost(widget.post)),
                        IconButton(icon: const Icon(FeatherIcons.bookmark, color: Colors.white70, size: 18), onPressed: () { /* TODO: Implement Bookmark */ }),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // Helper method to parse aspect ratio string (e.g., "16:9") to double
  double? _parseAspectRatio(dynamic aspectRatio) {
    if (aspectRatio == null) return null;
    try {
      if (aspectRatio is double) {
        return (aspectRatio > 0) ? aspectRatio : 1.0; // Ensure positive
      }
      if (aspectRatio is String) {
        if (aspectRatio.contains(':')) {
          final parts = aspectRatio.split(':');
          if (parts.length == 2) {
            final width = double.tryParse(parts[0].trim());
            final height = double.tryParse(parts[1].trim());
            if (width != null && height != null && width > 0 && height > 0) {
              return width / height;
            }
          }
        } else {
          final value = double.tryParse(aspectRatio);
          if (value != null && value > 0) {
            return value;
          }
        }
      }
    } catch (e) {
      print('Error parsing aspect ratio: $e');
    }
    return 1.0; // Default to 1:1 if parsing fails or invalid
  }

  // Builds the individual attachment item for the grid
  Widget _buildReplyAttachmentWidget(
    Map<String, dynamic> attachmentMap,
    int idx,
    List<Map<String, dynamic>> allAttachmentsInThisPost, // All attachments of the specific post/reply being built
    Map<String, dynamic> postOrReplyData, // The specific post or reply map this attachment belongs to
    BorderRadius borderRadius
  ) {
    final String attachmentType = attachmentMap['type'] as String? ?? 'unknown';
    final String? displayUrl = attachmentMap['url'] as String?;
    final String? attachmentFilename = attachmentMap['filename'] as String?;
    final File? localFile = attachmentMap['file'] is File ? attachmentMap['file'] as File? : null; // Ensure 'file' is File

    // For MediaViewPage context
    final String messageContent = postOrReplyData['content'] as String? ?? '';
    final String userName = postOrReplyData['username'] as String? ?? 'Unknown User';
    final String? userAvatarUrl = postOrReplyData['useravatar'] as String?;
    final DateTime timestamp = postOrReplyData['timestamp'] is String
        ? (DateTime.tryParse(postOrReplyData['timestamp'] as String) ?? DateTime.now())
        : (postOrReplyData['timestamp'] is DateTime ? postOrReplyData['timestamp'] : DateTime.now());

    // Counts should refer to the original post (widget.post) when viewing its attachments,
    // or to the specific reply's counts if viewing a reply's attachments (though replies don't typically show these counts)
    final int viewsCount = widget.post['viewsCount'] as int? ?? (widget.post['views'] as List?)?.length ?? 0;
    final int likesCount = widget.post['likesCount'] as int? ?? (widget.post['likes'] as List?)?.length ?? 0;
    final int repostsCount = widget.post['repostsCount'] as int? ?? (widget.post['reposts'] as List?)?.length ?? 0;


    Widget contentWidget;

    final String attachmentKeySuffix;
    if (attachmentMap['_id'] != null && (attachmentMap['_id'] as String).isNotEmpty) {
        attachmentKeySuffix = attachmentMap['_id'] as String;
    } else if (attachmentMap['url'] != null && (attachmentMap['url'] as String).isNotEmpty) {
        attachmentKeySuffix = attachmentMap['url'] as String;
    } else {
        attachmentKeySuffix = idx.toString();
        print("Warning: Reply attachment for post/reply ${postOrReplyData['id']} at index $idx is using an index-based key suffix. Data: $attachmentMap");
    }

    if (attachmentType == "video") {
      contentWidget = VideoAttachmentWidget(
        key: Key('video_reply_$attachmentKeySuffix'),
        attachment: attachmentMap,
        post: postOrReplyData,
        borderRadius: borderRadius,
        enforceFeedConstraints: false,
      );
    } else if (attachmentType == "image") {
      if (displayUrl != null && displayUrl.isNotEmpty) {
        contentWidget = Image.network(displayUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
      } else if (localFile != null) {
        contentWidget = Image.file(localFile, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900], child: const Icon(FeatherIcons.image, color: Colors.grey, size: 40)));
      } else {
        contentWidget = Container(color: Colors.grey[900], child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40));
      }
    } else if (attachmentType == "pdf") {
      final uri = displayUrl != null ? Uri.tryParse(displayUrl) : (localFile != null ? Uri.file(localFile.path) : null);
      if (uri != null) {
        contentWidget = Container(
          color: Colors.grey[800],
          child: Center(child: Icon(FeatherIcons.fileText, color: Colors.white.withOpacity(0.7), size: 40)),
        );
      } else {
        contentWidget = Container(color: Colors.grey[900], child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40));
      }
    } else if (attachmentType == "audio") {
      contentWidget = AudioAttachmentWidget(
        key: Key('audio_reply_$attachmentKeySuffix'),
        attachment: attachmentMap,
        post: postOrReplyData,
        borderRadius: borderRadius,
      );
    } else {
      contentWidget = Container(
        color: Colors.grey[900],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FeatherIcons.film, color: Colors.tealAccent, size: 40), // Generic fallback icon
            const SizedBox(height: 8),
            Text(attachmentFilename ?? (displayUrl ?? 'unknown').split('/').last, style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
          int initialIndex = allAttachmentsInThisPost.indexWhere((att) =>
              (att['url'] != null && att['url'] == attachmentMap['url']) ||
              (att.hashCode == attachmentMap.hashCode) // Fallback if URL is null (e.g. local file)
          );
          if (initialIndex == -1) initialIndex = idx;


        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MediaViewPage(
              attachments: allAttachmentsInThisPost,
              initialIndex: initialIndex,
              message: messageContent,
              userName: userName,
              userAvatarUrl: userAvatarUrl,
              timestamp: timestamp,
              viewsCount: viewsCount,
              likesCount: likesCount,
              repostsCount: repostsCount,
            ),
          ),
        );
      },
      child: ClipRRect( // Individual item clipping if needed, but outer grid ClipRRect is primary
        borderRadius: borderRadius,
        child: contentWidget,
      ),
    );
  }


  // Builds the attachment grid, similar to HomeFeedScreen
  Widget _buildReplyAttachmentGrid(
    List<Map<String, dynamic>> attachmentsArg,
    Map<String, dynamic> postOrReplyData, // The specific post/reply this grid belongs to
    // Pass other context if needed by _buildReplyAttachmentWidget for MediaViewPage
    String userName,
    String? userAvatar,
    DateTime timestamp,
    int viewsCount,
    int likesCount,
    int repostsCount,
    String messageContent
  ) {
    const double itemSpacing = 4.0;
    if (attachmentsArg.isEmpty) return const SizedBox.shrink();

    // Determine the context for MediaViewPage - use the attachments from postOrReplyData
    // Ensure robust handling of attachments list
    final List<Map<String, dynamic>> allAttachmentsForMediaView;
    final dynamic rawPostAttachments = postOrReplyData['attachments'];
    if (rawPostAttachments is List) {
      allAttachmentsForMediaView = rawPostAttachments.whereType<Map<String, dynamic>>().toList();
    } else {
      allAttachmentsForMediaView = [];
    }


    Widget gridContent;

    if (attachmentsArg.length == 1) {
      final attachment = attachmentsArg[0];
      double aspectRatioToUse = _parseAspectRatio(attachment['aspectRatio']) ??
                                (attachment['type'] == 'video' ? 16/9 : 1.0);
      if (aspectRatioToUse <= 0) { // Ensure it's positive, else default
        aspectRatioToUse = (attachment['type'] == 'video' ? 16/9 : 1.0);
      }

      gridContent = AspectRatio(
        aspectRatio: aspectRatioToUse,
        child: _buildReplyAttachmentWidget(attachment, 0, allAttachmentsForMediaView, postOrReplyData, BorderRadius.circular(12.0)), // Single item gets full rounding
      );
    } else if (attachmentsArg.length == 2) {
      gridContent = AspectRatio(
        aspectRatio: 2 * (4 / 3), // Maintain a reasonable overall shape
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[0], 0, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
            const SizedBox(width: itemSpacing),
            Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[1], 1, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
          ],
        ),
      );
    } else if (attachmentsArg.length == 3) {
       gridContent = LayoutBuilder(builder: (context, constraints) {
        double width = constraints.maxWidth;
        // Corrected width calculation for 3 items
        double leftItemWidth = (width - itemSpacing) * (2/3);
        double rightColumnWidth = (width - itemSpacing) * (1/3);
        // Attempt to make overall grid squarish or 4:3 like
        double totalHeight = width * ( (attachmentsArg[0]['type'] == 'video' || attachmentsArg[1]['type'] == 'video' || attachmentsArg[2]['type'] == 'video' ) ? (9/16) : (3/4) );
        if (attachmentsArg.any((att) => (_parseAspectRatio(att['aspectRatio']) ?? 1.0) < 1)) { // If any portrait items
            totalHeight = width * (4/3); // Make grid taller for portrait content
        }


        return SizedBox(
            height: totalHeight, // Constrain height
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: leftItemWidth, child: _buildReplyAttachmentWidget(attachmentsArg[0], 0, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
                const SizedBox(width: itemSpacing),
                SizedBox(
                  width: rightColumnWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[1], 1, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
                      const SizedBox(height: itemSpacing),
                      Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[2], 2, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
                    ],
                  ),
                ),
              ],
            ),
          );
      });
    } else if (attachmentsArg.length == 4) {
      gridContent = AspectRatio(
        aspectRatio: 1.0, // Square grid
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: itemSpacing, mainAxisSpacing: itemSpacing, childAspectRatio: 1),
          itemCount: 4,
          itemBuilder: (context, index) => _buildReplyAttachmentWidget(attachmentsArg[index], index, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero),
        ),
      );
    } else if (attachmentsArg.length == 5) {
        gridContent = LayoutBuilder(builder: (context, constraints) {
          double containerWidth = constraints.maxWidth;
          double h1 = (containerWidth - itemSpacing) / 2;
          double h2 = (containerWidth - 2 * itemSpacing) / 3;
          double totalHeight = h1 + itemSpacing + h2;
          return SizedBox(
              height: totalHeight,
              child: Column(
                children: [
                  SizedBox(height: h1, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[0], 0, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)), const SizedBox(width: itemSpacing),
                    Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[1], 1, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
                  ])),
                  const SizedBox(height: itemSpacing),
                  SizedBox(height: h2, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[2], 2, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)), const SizedBox(width: itemSpacing),
                    Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[3], 3, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)), const SizedBox(width: itemSpacing),
                    Expanded(child: _buildReplyAttachmentWidget(attachmentsArg[4], 4, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero)),
                  ])),
                ],
              ),
            );
       });
    } else { // 6 or more items
      const int crossAxisCount = 3;
      const double childAspectRatio = 1.0; // Square items
      gridContent = LayoutBuilder(builder: (context, constraints) {
        double itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * itemSpacing) / crossAxisCount;
        double itemHeight = itemWidth / childAspectRatio;
        int numRows = (attachmentsArg.length / crossAxisCount).ceil();
        double totalHeight = numRows * itemHeight + (numRows - 1) * itemSpacing;
         return SizedBox(
            height: totalHeight,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, crossAxisSpacing: itemSpacing, mainAxisSpacing: itemSpacing, childAspectRatio: childAspectRatio),
              itemCount: attachmentsArg.length, // Show all items up to a reasonable limit, or cap at 6 for a 2x3 grid
              itemBuilder: (context, index) => _buildReplyAttachmentWidget(attachmentsArg[index], index, allAttachmentsForMediaView, postOrReplyData, BorderRadius.zero),
            ),
          );
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0), // Outer rounding for the whole grid
      child: gridContent,
    );
  }


  Future<void> _pickAndAddAttachment(String type) async {
    File? file;
    String dialogTitle = '';
    String message = '';
    XFile? pickedFile;

    try {
      if (!await _requestMediaPermissions(type)) return;

      final picker = ImagePicker();
      if (type == "image") {
        dialogTitle = 'Upload Image';
        pickedFile = await picker.pickImage(source: ImageSource.gallery);
      } else if (type == "video") {
        dialogTitle = 'Upload Video';
        pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      } else if (type == "pdf") {
        dialogTitle = 'Upload Document';
        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: false);
        if (result != null && result.files.single.path != null) file = File(result.files.single.path!);
      } else if (type == "audio") {
        dialogTitle = 'Upload Audio';
        final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
        if (result != null && result.files.single.path != null) file = File(result.files.single.path!);
      }

      if (pickedFile != null) file = File(pickedFile.path);
      // Note: 'file' could still be null here if FilePicker for PDF/Audio didn't yield a result
      // and pickedFile was also null (e.g. if image/video pick was cancelled).

      if (file != null) {
        final sizeInBytes = await file.length();
        final double sizeInMB = sizeInBytes / (1024 * 1024);

        if (sizeInMB > 20) {
          message = 'File "${file.path.split('/').last}" is too large (${sizeInMB.toStringAsFixed(1)}MB). Must be under 20MB.';
          _showSnackBar(dialogTitle, message, Colors.red[700]!);
          return; // Exit if file is too large
        }

        // If file is valid and within size limits
        if (mounted) {
          setState(() {
            _replyAttachments.add({
              'file': file,
              'type': type,
              'filename': file?.path.split('/').last,
              'size': sizeInBytes,
            });
          });
        }
        message = '${type[0].toUpperCase()}${type.substring(1)} selected: ${file.path.split('/').last}';
        _showSnackBar(dialogTitle, message, Colors.teal[700]!);

      } else {
        // This 'else' block now correctly covers all cases where 'file' is null after picking attempts.
        message = 'No file selected for $type.';
        _showSnackBar(dialogTitle, message, Colors.red[700]!);
      }
    } catch (e) {
      message = 'Error picking $type: $e';
      _showSnackBar('Error', message, Colors.red[700]!);
    }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(FeatherIcons.image, color: Colors.tealAccent),
                title: Text('Image', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("image");
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.video, color: Colors.tealAccent),
                title: Text('Video', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("video");
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.fileText, color: Colors.tealAccent),
                title: Text('PDF Document', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("pdf");
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.music, color: Colors.tealAccent),
                title: Text('Audio', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndAddAttachment("audio");
                },
              ),
            ],
          ),
        );
      },
    );
  }


  void _submitReply() async {
    if (_isSubmittingReply) return;
    if (_replyController.text.trim().isEmpty && _replyAttachments.isEmpty) {
      _showSnackBar('Input Error', 'Please enter text or add an attachment.', Colors.red[700]!);
      return;
    }
    if (mounted) setState(() { _isSubmittingReply = true; }); else return; // Exit if not mounted

    List<Map<String, dynamic>> uploadedReplyAttachments = [];
    try {
      if (_replyAttachments.isNotEmpty) {
        final filesToUpload = _replyAttachments.where((a) => a['file'] != null && a['file'] is File).map((a) => {'file': a['file'], 'type': a['type'], 'filename': a['filename'], 'size': a['size']}).toList();
        if (filesToUpload.isNotEmpty) {
          final uploadResults = await _dataController.uploadFiles(filesToUpload);
          int uploadResultIndex = 0;
          for (var originalAttachment in _replyAttachments) {
            if (originalAttachment['file'] != null && originalAttachment['file'] is File) {
              if (uploadResultIndex < uploadResults.length) {
                final result = uploadResults[uploadResultIndex];
                if (result['success'] == true && result['url'] != null) {
                  uploadedReplyAttachments.add({'type': originalAttachment['type'], 'filename': originalAttachment['filename'] ?? result['filename'] ?? 'unknown', 'size': originalAttachment['size'] ?? result['size'] ?? 0, 'url': result['url'] as String, 'thumbnailUrl': result['thumbnailUrl'] as String?});
                } else {
                  _showSnackBar('Upload Error', 'Failed to upload ${originalAttachment['filename'] ?? 'a file'}: ${result['message'] ?? 'Unknown error'}', Colors.red[700]!);
                }
                uploadResultIndex++;
              }
            } else if (originalAttachment['url'] != null) {
              uploadedReplyAttachments.add(originalAttachment);
            }
          }
        }
      }
      if (_replyController.text.trim().isEmpty && uploadedReplyAttachments.isEmpty && _replyAttachments.isNotEmpty) {
        _showSnackBar('Upload Error', 'Failed to upload attachments. Reply not sent.', Colors.red[700]!);
        if (mounted) setState(() { _isSubmittingReply = false; });
        return;
      }
      final postId = widget.post['_id'] as String?;
      if (postId == null) {
        _showSnackBar('Error', 'Cannot post reply: Original post ID is missing.', Colors.red[700]!);
        if (mounted) setState(() { _isSubmittingReply = false; });
        return;
      }
      final result = await _dataController.replyToPost(postId: postId, content: _replyController.text.trim(), attachments: uploadedReplyAttachments);

      if (!mounted) return; // Check mounted after await

      if (result['success'] == true && result['reply'] != null) {
        final newReply = result['reply'] as Map<String, dynamic>;
        setState(() {
          _replies.insert(0, newReply);
          _replyController.clear();
          _replyAttachments.clear();
        });
        _showSnackBar('Success', result['message'] ?? 'Reply posted!', Colors.teal[700]!);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context, true);
      } else if (result['success'] == true && result['reply'] == null) {
        _showSnackBar('Success', result['message'] ?? 'Reply posted! Refreshing...', Colors.teal[700]!);
        await _fetchPostReplies(); // This already has mounted checks
        _replyController.clear();
        if (mounted) setState(() { _replyAttachments.clear(); });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, true);
      } else {
        _showSnackBar('Error', result['message'] ?? 'Failed to post reply.', Colors.red[700]!);
      }
    } catch (e) {
      print('Error in _submitReply: $e');
      if (mounted) { // Check mounted before showing snackbar from catch
        _showSnackBar('Error', 'An unexpected error occurred: ${e.toString()}', Colors.red[700]!);
      }
    } finally {
      if (mounted) {
        setState(() { _isSubmittingReply = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String postUsername = widget.post['username'] as String? ?? 'User';
    final DateTime parsedTimestamp = widget.post['timestamp'] is String
        ? (DateTime.tryParse(widget.post['timestamp'] as String) ?? DateTime.now())
        : (widget.post['timestamp'] is DateTime ? widget.post['timestamp'] : DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Post by @$postUsername', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
            Text(
              DateFormat('MMM d, yyyy · h:mm a').format(parsedTimestamp),
              style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String result) {
              // Handle the selection
              if (result == 'block') {
                print('Block @$postUsername');
                // TODO: Implement block user functionality
                _showSnackBar('Block User', 'Block @$postUsername (not implemented yet).', Colors.orange);
              } else if (result == 'report') {
                print('Report post by @$postUsername');
                // TODO: Implement report post functionality
                _showSnackBar('Report Post', 'Report post by @$postUsername (not implemented yet).', Colors.orange);
              } else if (result == 'copy_link') {
                final String postId = widget.post['_id'] as String? ?? "unknown_post_id";
                // Replace with your actual app's domain and post path structure
                final String postLink = "https://chatter.yourdomain.com/post/$postId";
                Clipboard.setData(ClipboardData(text: postLink)).then((_) {
                  _showSnackBar('Link Copied', 'Post link copied to clipboard!', Colors.green[700]!);
                }).catchError((error) {
                  _showSnackBar('Error', 'Could not copy link: $error', Colors.red[700]!);
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'block',
                child: Text('Block @$postUsername', style: GoogleFonts.roboto()),
              ),
              PopupMenuItem<String>(
                value: 'report',
                child: Text('Report Post', style: GoogleFonts.roboto()),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'copy_link',
                child: Text('Copy link to post', style: GoogleFonts.roboto()),
              ),
            ],
            color: const Color(0xFF2C2C2C), // Dark background for the menu
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // Adjusted padding for the entire scrollable content
              padding: const EdgeInsets.only(top: 16.0, bottom: 16.0, left: 8.0, right: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    // Removed specific bottom padding here, rely on overall column spacing
                    // padding: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
                    child: _buildPostContent(widget.post, isReply: false),
                  ),
                  const SizedBox(height: 20), // Spacing after the main post
                  Padding( // Added padding to the "Replies" header row
                    padding: const EdgeInsets.symmetric(horizontal: 4.0), // Minimal horizontal padding
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         _isLoadingReplies && _fetchRepliesError == null
                          ? Row(
                              children: [
                                 Text("Reloading Replies...", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[400])),
                                 const SizedBox(width: 8),
                                 const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent))),
                              ],
                            )
                          : Text("Replies", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.tealAccent),
                              tooltip: "Refresh Replies",
                              onPressed: () => _fetchPostReplies(showLoadingIndicator: true),
                            ),
                            IconButton(
                              icon: Icon(_showReplyField ? FeatherIcons.messageCircle : FeatherIcons.edit3, color: Colors.tealAccent),
                              tooltip: _showReplyField ? "Hide Reply Field" : "Show Reply Field",
                              onPressed: () {
                                setState(() {
                                  _showReplyField = !_showReplyField;
                                });
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingReplies && _fetchRepliesError == null
                      ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator(color: Colors.tealAccent)))
                      : _fetchRepliesError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20.0),
                                child: Text(
                                  "Couldn't load replies. Tap refresh to try again.",
                                  style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : _replies.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                                    child: Text(
                                      "No replies yet.",
                                      style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _replies.length,
                                  itemBuilder: (context, index) {
                                    final reply = _replies[index];
                                    // Each reply item will also get minimal padding from _buildPostContent
                                    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: _buildPostContent(reply, isReply: true));
                                  },
                                ),
                ],
              ),
            ),
          ),
          if (_showReplyField) _buildReplyInputArea(),
        ],
      ),
    );
  }

  Widget _buildReplyInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyAttachments.isNotEmpty) ...[
             SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _replyAttachments.map((attachment) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                      avatar: attachment['type'] == 'image' ? const Icon(FeatherIcons.image, size:16)
                            : attachment['type'] == 'video' ? const Icon(FeatherIcons.video, size:16)
                            : attachment['type'] == 'audio' ? const Icon(FeatherIcons.music, size:16)
                            : const Icon(FeatherIcons.file, size:16),
                      label: Text(
                        (attachment['filename'] ?? (attachment['file']?.path.split('/').last ?? 'Preview')),
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: Colors.grey[700],
                      deleteIcon: const Icon(FeatherIcons.x, size: 14, color: Colors.white70),
                      onDeleted: () {
                        setState(() {
                          _replyAttachments.remove(attachment);
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(FeatherIcons.paperclip, color: Colors.tealAccent, size: 22),
                onPressed: _showAttachmentPicker,
                tooltip: 'Add Media',
              ),
              Expanded(
                child: TextField(
                  controller: _replyController,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Post your reply...",
                    hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 0),
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 280,
                  buildCounter: (BuildContext context, {int? currentLength, int? maxLength, bool? isFocused}) => null,
                ),
              ),
              _isSubmittingReply
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        height: 24, width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(FeatherIcons.send, color: Colors.tealAccent, size: 22),
                      onPressed: _submitReply,
                      tooltip: 'Post Reply',
                    ),
            ],
          ),
        ],
      ),
    );
  }
}