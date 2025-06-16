import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/new-posts-page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:open_file/open_file.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class Attachment {
  final File file;
  final String type;
  String? url;

  Attachment({required this.file, required this.type, this.url});
}

class ChatterPost {
  final String username;
  final String content;
  final DateTime timestamp;
  int likes;
  int reposts;
  int views;
  final List<Map<String, dynamic>> attachments;
  final String avatarInitial;
  final List<ChatterPost> replies;

  ChatterPost({
    required this.username,
    required this.content,
    required this.timestamp,
    this.likes = 0,
    this.reposts = 0,
    this.views = 0,
    this.attachments = const [],
    required this.avatarInitial,
    this.replies = const [],
  });
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final DataController dataController = Get.put(DataController());
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, BetterPlayerController> _betterPlayerControllers = {};
  final Map<String, bool> _videoHasError = {};
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, bool> _audioPlaying = {};
  final Map<String, String?> _pdfThumbnailCache = {};
  final Map<String, bool> _controllersDisposed = {};
  int? _androidVersion;

  @override
  void initState() {
    super.initState();
    _checkAndroidVersion();
    dataController.fetchFeeds().catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load feed: $error', style: GoogleFonts.roboto(color: Colors.white)),
          backgroundColor: Colors.red[700],
        ),
      );
      return null;
    });
  }

  Future<void> _checkAndroidVersion() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (mounted) {
        setState(() {
          _androidVersion = int.tryParse(androidInfo.version.release.split('.').first) ?? 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoControllers.forEach((key, controller) {
      controller.pause();
      controller.dispose();
      _controllersDisposed[key] = true;
    });
    _videoControllers.clear();
    _betterPlayerControllers.forEach((key, controller) {
      controller.pause();
      controller.dispose();
      _controllersDisposed[key] = true;
    });
    _betterPlayerControllers.clear();
    _audioPlayers.forEach((key, player) {
      player.stop();
      player.dispose();
    });
    _audioPlayers.clear();
    super.dispose();
  }

  void _navigateToPostScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewPostScreen()),
    );
    if (result != null && result is Map<String, dynamic>) {
      await _addPost(result['content'] as String, result['attachments'] as List<Attachment>);
    }
  }

  Future<void> _addPost(String content, List<Attachment> attachments) async {
    List<Map<String, dynamic>> uploadedAttachments = [];
    if (attachments.isNotEmpty) {
      List<File> files = attachments.map((a) => a.file).toList();
      List<Map<String, dynamic>> uploadResults = await dataController.uploadFilesToCloudinary(files);

      for (int i = 0; i < attachments.length; i++) {
        var result = uploadResults[i];
        if (result['success'] == true && result['url'] is String) {
          uploadedAttachments.add({
            'filename': attachments[i].file.path.split('/').last,
            'url': result['url'] as String,
            'size': await attachments[i].file.length(),
            'type': attachments[i].type,
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to upload ${attachments[i].file.path.split('/').last}: ${result['message'] ?? 'Unknown error'}',
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
      'username': dataController.user.value['user']?['name'] ?? 'Unknown',
      'content': content.trim(),
      'attachments': uploadedAttachments,
    };

    final result = await dataController.createPost(postData);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Poa! Your chatter is live!',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.teal[700],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create post: ${result['message'] ?? 'Unknown error'}',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _showRepliesDialog(ChatterPost post) {
    final replyController = TextEditingController();
    final List<Attachment> replyAttachments = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.tealAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                'Replies',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
                        ),
                        child: _buildPostContent(post, isReply: false),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: post.replies.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Colors.grey[800],
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: _buildPostContent(post.replies[index], isReply: true),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: replyController,
                        maxLength: 280,
                        maxLines: 3,
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Post your reply...",
                          hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.tealAccent),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF252525),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(FeatherIcons.image, color: Colors.tealAccent),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                              if (image != null) {
                                final file = File(image.path);
                                final sizeInMB = await file.length() / (1024 * 1024);
                                if (sizeInMB <= 10) {
                                  setDialogState(() {
                                    replyAttachments.add(Attachment(file: file, type: "image"));
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File must be under 10MB!',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Upload Image',
                          ),
                          IconButton(
                            icon: const Icon(FeatherIcons.fileText, color: Colors.tealAccent),
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf'],
                                allowMultiple: false,
                              );
                              if (result != null && result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                final sizeInMB = await file.length() / (1024 * 1024);
                                if (sizeInMB <= 10) {
                                  setDialogState(() {
                                    replyAttachments.add(Attachment(file: file, type: "pdf"));
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File must be under 10MB!',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Upload Document',
                          ),
                          IconButton(
                            icon: const Icon(FeatherIcons.music, color: Colors.tealAccent),
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.audio,
                                allowMultiple: false,
                              );
                              if (result != null && result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                final sizeInMB = await file.length() / (1024 * 1024);
                                if (sizeInMB <= 10) {
                                  setDialogState(() {
                                    replyAttachments.add(Attachment(file: file, type: "audio"));
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File must be under 10MB!',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Upload Audio',
                          ),
                          IconButton(
                            icon: const Icon(FeatherIcons.video, color: Colors.tealAccent),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
                              if (video != null) {
                                final file = File(video.path);
                                final sizeInMB = await file.length() / (1024 * 1024);
                                if (sizeInMB <= 10) {
                                  setDialogState(() {
                                    replyAttachments.add(Attachment(file: file, type: "video"));
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'File must be under 10MB!',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                }
                              }
                            },
                            tooltip: 'Upload Video',
                          ),
                        ],
                      ),
                      if (replyAttachments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: replyAttachments.map((attachment) {
                            return Chip(
                              label: Text(
                                attachment.file.path.split('/').last,
                                style: GoogleFonts.roboto(color: Colors.white, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              backgroundColor: Colors.grey[800],
                              deleteIcon: const Icon(FeatherIcons.x, size: 16, color: Colors.white),
                              onDeleted: () {
                                setDialogState(() {
                                  replyAttachments.remove(attachment);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.roboto(color: Colors.grey[400]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (replyController.text.trim().isEmpty && replyAttachments.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter some text or add attachments!',
                            style: GoogleFonts.roboto(color: Colors.white),
                          ),
                          backgroundColor: Colors.red[700],
                        ),
                      );
                      return;
                    }

                    List<Map<String, dynamic>> uploadedReplyAttachments = [];
                    if (replyAttachments.isNotEmpty) {
                      List<File> files = replyAttachments.map((a) => a.file).toList();
                      List<Map<String, dynamic>> uploadResults = await dataController.uploadFilesToCloudinary(files);

                      for (int i = 0; i < replyAttachments.length; i++) {
                        var result = uploadResults[i];
                        if (result['success'] == true && result['url'] is String) {
                          uploadedReplyAttachments.add({
                            'filename': replyAttachments[i].file.path.split('/').last,
                            'url': result['url'] as String,
                            'size': await replyAttachments[i].file.length(),
                            'type': replyAttachments[i].type,
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to upload ${replyAttachments[i].file.path.split('/').last}: ${result['message'] ?? 'Unknown error'}',
                                style: GoogleFonts.roboto(color: Colors.white),
                              ),
                              backgroundColor: Colors.red[700],
                            ),
                          );
                        }
                      }
                    }

                    if (replyController.text.trim().isEmpty && uploadedReplyAttachments.isEmpty) {
                      return;
                    }

                    setState(() {
                      post.replies.add(
                        ChatterPost(
                          username: dataController.user.value['user']?['name'] ?? 'YourName',
                          content: replyController.text.trim(),
                          timestamp: DateTime.now(),
                          attachments: uploadedReplyAttachments,
                          avatarInitial: dataController.user.value['user']?['name']?.isNotEmpty ?? false
                              ? dataController.user.value['user']['name'][0].toUpperCase()
                              : 'Y',
                          views: Random().nextInt(100) + 10,
                        ),
                      );
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Poa! Reply posted!',
                          style: GoogleFonts.roboto(color: Colors.white),
                        ),
                        backgroundColor: Colors.teal[700],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Reply',
                    style: GoogleFonts.roboto(color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _optimizeCloudinaryVideoUrl(String url, {bool isThumbnail = false, bool isFullScreen = false}) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (!url.contains('cloudinary.com') || !pathSegments.contains('video')) {
      return url;
    }

    final uploadIndex = pathSegments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex + 1 >= pathSegments.length) {
      return url;
    }
    final publicIdWithFormat = pathSegments.sublist(uploadIndex + 1).join('/');
    final publicId = publicIdWithFormat.contains('.')
        ? publicIdWithFormat.substring(0, publicIdWithFormat.lastIndexOf('.'))
        : publicIdWithFormat;
    final format = publicIdWithFormat.contains('.')
        ? publicIdWithFormat.substring(publicIdWithFormat.lastIndexOf('.') + 1)
        : 'mp4';

    String transformations;
    if (isThumbnail) {
      transformations = 'q_auto:low,f_auto,w_480,h_270,c_fill,e_preview,so_0';
    } else if (isFullScreen) {
      transformations = 'q_auto:best,f_auto,w_1280,c_fill,so_0,vc_h264:baseline';
    } else {
      transformations = 'q_auto:good,f_auto,w_480,c_fill,so_0,vc_h264:baseline';
    }

    final optimizedPath = pathSegments.sublist(0, uploadIndex + 1).join('/') + '/$transformations/$publicId.$format';
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      path: '/$optimizedPath',
    ).toString();
  }

  Future<String?> _generateThumbnail(String videoUrl) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await video_thumb.VideoThumbnail.thumbnailFile(
        video: _optimizeCloudinaryVideoUrl(videoUrl, isThumbnail: true),
        thumbnailPath: tempDir.path,
        imageFormat: video_thumb.ImageFormat.PNG,
        maxHeight: 200,
        quality: 75,
      );
      return thumbnailPath;
    } catch (e) {
      print("Error generating thumbnail: $e");
      return null;
    }
  }

  Future<String?> _generatePdfThumbnail(String pdfUrl) async {
    if (_pdfThumbnailCache.containsKey(pdfUrl)) {
      return _pdfThumbnailCache[pdfUrl];
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.png');

      final document = await PdfDocument.openUri(Uri.parse(pdfUrl));
      final page = await document.pages[0].render(
        width: 200,
        height: 200,
      );

      if (page != null) {
        await tempFile.writeAsBytes(page.bytes);
        _pdfThumbnailCache[pdfUrl] = tempFile.path;
        await document.dispose();
        return tempFile.path;
      }
      await document.dispose();
      return null;
    } catch (e) {
      print("Error generating PDF thumbnail: $e");
      return null;
    }
  }

  Future<bool> _isUrlAccessible(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print("URL accessibility check failed: $e");
      return false;
    }
  }

  Future<Size> _getImageDimensions(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final image = img.decodeImage(response.bodyBytes);
        if (image != null) {
          return Size(image.width.toDouble(), image.height.toDouble());
        }
      }
      return const Size(300, 300);
    } catch (e) {
      print("Error getting image dimensions: $e");
      return const Size(300, 300);
    }
  }

  void _showFullScreenMedia(BuildContext context, String url, String type, String filename) {
    VideoPlayerController? fullScreenVideoController;
    BetterPlayerController? fullScreenBetterPlayerController;
    bool isPlaying = true;
    final attachmentKey = '${filename}_${url.hashCode}';

    if (type == 'video') {
      final optimizedUrl = _optimizeCloudinaryVideoUrl(url, isFullScreen: true);
      final useVideoPlayer = _androidVersion != null && _androidVersion! >= 13;

      if (useVideoPlayer && !(_videoHasError[attachmentKey] ?? false)) {
        fullScreenVideoController = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
        fullScreenVideoController.initialize().then((_) {
          if (mounted && !_controllersDisposed[attachmentKey]!) {
            setState(() {
              fullScreenVideoController?.play();
              fullScreenVideoController?.setLooping(true);
            });
          }
        }).catchError((error) {
          if (mounted && !_controllersDisposed[attachmentKey]!) {
            setState(() {
              _videoHasError[attachmentKey] = true;
              _videoControllers.remove(attachmentKey);
              _controllersDisposed[attachmentKey] = true;
              fullScreenVideoController?.dispose();
              fullScreenVideoController = null;
              fullScreenBetterPlayerController = _createBetterPlayerController(optimizedUrl);
              fullScreenBetterPlayerController?.play();
            });
          }
        });
      } else {
        fullScreenBetterPlayerController = _createBetterPlayerController(optimizedUrl);
        if (mounted && !_controllersDisposed[attachmentKey]!) {
          fullScreenBetterPlayerController.play();
        }
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return FutureBuilder<Size>(
                future: type == 'image' ? _getImageDimensions(url) : Future.value(const Size(16, 9)),
                builder: (context, snapshot) {
                  final maxWidth = MediaQuery.of(context).size.width * 0.9;
                  final maxHeight = MediaQuery.of(context).size.height * 0.9;
                  double? dialogWidth;
                  double? dialogHeight;

                  if (snapshot.hasData && type == 'image') {
                    final size = snapshot.data!;
                    final aspectRatio = size.width / size.height;
                    dialogWidth = min(size.width, maxWidth);
                    dialogHeight = min(size.height, maxHeight);
                    if (dialogWidth / dialogHeight > aspectRatio) {
                      dialogWidth = dialogHeight * aspectRatio;
                    } else {
                      dialogHeight = dialogWidth / aspectRatio;
                    }
                  }

                  return Container(
                    width: dialogWidth,
                    height: dialogHeight,
                    child: Stack(
                      children: [
                        Center(
                          child: type == 'image'
                              ? CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(
                                    FeatherIcons.image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                )
                              : type == 'video'
                                  ? (_videoHasError[attachmentKey] ?? false) || fullScreenVideoController == null
                                      ? fullScreenBetterPlayerController != null
                                          ? BetterPlayer(controller: fullScreenBetterPlayerController!)
                                          : Container(
                                              color: Colors.grey[900],
                                              child: const Icon(
                                                FeatherIcons.video,
                                                color: Colors.tealAccent,
                                                size: 40,
                                              ),
                                            )
                                      : fullScreenVideoController?.value.isInitialized == true
                                          ? AspectRatio(
                                              aspectRatio: fullScreenVideoController!.value.aspectRatio,
                                              child: VideoPlayer(fullScreenVideoController!),
                                            )
                                          : Container(
                                              color: Colors.grey[900],
                                              child: const Icon(
                                                FeatherIcons.video,
                                                color: Colors.tealAccent,
                                                size: 40,
                                              ),
                                            )
                                  : Container(),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: const Icon(FeatherIcons.x, color: Colors.white),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        if (type == 'video' && fullScreenVideoController != null && fullScreenVideoController?.value.isInitialized == true)
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                VideoProgressIndicator(
                                  fullScreenVideoController!,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                    playedColor: Colors.tealAccent,
                                    bufferedColor: Colors.grey,
                                    backgroundColor: Colors.grey,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        FeatherIcons.rewind,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      onPressed: () {
                                        if (fullScreenVideoController?.value.isInitialized == true && !_controllersDisposed[attachmentKey]!) {
                                          final newPosition = (fullScreenVideoController?.value.position ?? Duration.zero) - const Duration(seconds: 10);
                                          fullScreenVideoController?.seekTo(
                                            newPosition < Duration.zero ? Duration.zero : newPosition,
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isPlaying ? FeatherIcons.pause : FeatherIcons.play,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      onPressed: () {
                                        if (fullScreenVideoController?.value.isInitialized == true && !_controllersDisposed[attachmentKey]!) {
                                          setDialogState(() {
                                            isPlaying = !isPlaying;
                                            if (isPlaying) {
                                              fullScreenVideoController?.play();
                                            } else {
                                              fullScreenVideoController?.pause();
                                            }
                                          });
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        FeatherIcons.fastForward,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      onPressed: () {
                                        if (fullScreenVideoController?.value.isInitialized == true && !_controllersDisposed[attachmentKey]!) {
                                          final newPosition = (fullScreenVideoController?.value.position ?? Duration.zero) + const Duration(seconds: 10);
                                          final duration = fullScreenVideoController?.value.duration ?? Duration.zero;
                                          fullScreenVideoController?.seekTo(
                                            newPosition > duration ? duration : newPosition,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      if (fullScreenVideoController != null && !(_controllersDisposed[attachmentKey] ?? false)) {
        fullScreenVideoController?.pause();
        fullScreenVideoController?.dispose();
        _controllersDisposed[attachmentKey] = true;
      }
      if (fullScreenBetterPlayerController != null && !(_controllersDisposed[attachmentKey] ?? false)) {
        fullScreenBetterPlayerController?.pause();
        fullScreenBetterPlayerController?.dispose();
        _controllersDisposed[attachmentKey] = true;
      }
    });
  }

  BetterPlayerController _createBetterPlayerController(String url) {
    return BetterPlayerController(
       BetterPlayerConfiguration(
        autoPlay: false,
        looping: true,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
          enableOverflowMenu: false,
          enablePlayPause: false,
          enableMute: false,
          enableProgressBar: false,
          enableProgressText: false,
        ),
        fit: BoxFit.contain,
        errorBuilder: (context, errorMessage) => Container(
          color: Colors.grey[900],
          child: const Icon(
            FeatherIcons.video,
            color: Colors.grey,
            size: 40,
          ),
        ),
      ),
      betterPlayerDataSource: BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        url,
        cacheConfiguration: const BetterPlayerCacheConfiguration(
          useCache: true,
          preCacheSize: 10 * 1024 * 1024,
          maxCacheSize: 100 * 1024 * 1024,
        ),
      ),
    );
  }

  Future<void> _openPdf(String url, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$filename';
      final file = File(filePath);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to open PDF: ${result.message}',
                style: GoogleFonts.roboto(color: Colors.white),
              ),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error downloading PDF: $e',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Widget _buildPostContent(ChatterPost post, {required bool isReply}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isReply ? 16 : 20,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              child: Text(
                post.avatarInitial,
                style: GoogleFonts.poppins(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: isReply ? 14 : 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '@${post.username}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: isReply ? 14 : 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        DateFormat('h:mm a · MMM d').format(post.timestamp),
                        style: GoogleFonts.roboto(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.content,
                    style: GoogleFonts.roboto(
                      fontSize: isReply ? 13 : 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (post.attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: post.attachments.length > 1 ? 2 : 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: post.attachments.length,
                      itemBuilder: (context, idx) {
                        final attachment = post.attachments[idx];
                        final originalUrl = attachment['url'] as String;
                        final displayUrl = attachment['type'] == 'video'
                            ? _optimizeCloudinaryVideoUrl(originalUrl)
                            : originalUrl;
                        final attachmentKey = '${post.timestamp.millisecondsSinceEpoch}_$idx';

                        if (attachment['type'] == "image") {
                          return GestureDetector(
                            onTap: () {
                              _showFullScreenMedia(context, displayUrl, "image", attachment['filename']);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: displayUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[900],
                                  child: const Icon(
                                    FeatherIcons.image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else if (attachment['type'] == "pdf") {
                          return GestureDetector(
                            onTap: () {
                              _openPdf(displayUrl, attachment['filename']);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FutureBuilder<String?>(
                                future: _generatePdfThumbnail(displayUrl),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
                                    return Image.file(
                                      File(snapshot.data!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.grey[900],
                                        child: const Icon(
                                          FeatherIcons.fileText,
                                          color: Colors.tealAccent,
                                          size: 40,
                                        ),
                                      ),
                                    );
                                  }
                                  return Container(
                                    color: Colors.grey[900],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        } else if (attachment['type'] == "video") {
                          final useVideoPlayer = _androidVersion != null && _androidVersion! >= 13;

                          if (!_videoControllers.containsKey(attachmentKey) &&
                              !_betterPlayerControllers.containsKey(attachmentKey) &&
                              !(_controllersDisposed[attachmentKey] ?? false)) {
                            if (useVideoPlayer && !(_videoHasError[attachmentKey] ?? false)) {
                              final controller = VideoPlayerController.networkUrl(Uri.parse(displayUrl));
                              _videoControllers[attachmentKey] = controller;
                              controller.initialize().then((_) {
                                if (mounted && !_controllersDisposed[attachmentKey]!) {
                                  setState(() {});
                                }
                              }).catchError((error) {
                                if (mounted && !_controllersDisposed[attachmentKey]!) {
                                  setState(() {
                                    _videoHasError[attachmentKey] = true;
                                    _videoControllers.remove(attachmentKey);
                                    controller.dispose();
                                    _controllersDisposed[attachmentKey] = true;
                                    _betterPlayerControllers[attachmentKey] = _createBetterPlayerController(displayUrl);
                                  });
                                }
                              });
                            } else {
                              _betterPlayerControllers[attachmentKey] = _createBetterPlayerController(displayUrl);
                            }
                          }

                          final videoController = _videoControllers[attachmentKey];
                          final betterPlayerController = _betterPlayerControllers[attachmentKey];

                          return GestureDetector(
                            onTap: () {
                              _showFullScreenMedia(context, originalUrl, "video", attachment['filename']);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FutureBuilder<String?>(
                                future: _generateThumbnail(originalUrl),
                                builder: (context, snapshot) {
                                  return VisibilityDetector(
                                    key: Key(attachmentKey),
                                    onVisibilityChanged: (info) {
                                      if (!mounted || (_controllersDisposed[attachmentKey] ?? false)) return;
                                      if (info.visibleFraction > 0.8) {
                                        if (videoController != null && videoController.value.isInitialized && !(_controllersDisposed[attachmentKey] ?? false)) {
                                          videoController.play().catchError((e) {
                                            if (mounted) {
                                              print("Error playing video: $e");
                                            }
                                          });
                                          videoController.setLooping(true);
                                        } else if (betterPlayerController != null && !(_controllersDisposed[attachmentKey] ?? false)) {
                                          betterPlayerController.play().catchError((e) {
                                            if (mounted) {
                                              print("Error playing better player: $e");
                                            }
                                          });
                                        }
                                      } else {
                                        if (videoController != null && videoController.value.isInitialized && !(_controllersDisposed[attachmentKey] ?? false)) {
                                          videoController.pause().catchError((e) {
                                            if (mounted) {
                                              print("Error pausing video: $e");
                                            }
                                          });
                                        }
                                        if (betterPlayerController != null && !(_controllersDisposed[attachmentKey] ?? false)) {
                                          betterPlayerController.pause().catchError((e) {
                                            if (mounted) {
                                              print("Error pausing better player: $e");
                                            }
                                          });
                                        }
                                      }
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (snapshot.hasData && snapshot.data != null)
                                          Container(
                                            decoration: BoxDecoration(
                                              image: DecorationImage(
                                                image: FileImage(File(snapshot.data!)),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                color: Colors.black.withOpacity(0.3),
                                              ),
                                            ),
                                          ),
                                        Container(
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                                            maxHeight: MediaQuery.of(context).size.width * 0.8 * (9 / 16),
                                          ),
                                          child: (_videoHasError[attachmentKey] ?? false) || videoController == null
                                              ? betterPlayerController != null
                                                  ? BetterPlayer(controller: betterPlayerController)
                                                  : CachedNetworkImage(
                                                      imageUrl: _optimizeCloudinaryVideoUrl(originalUrl, isThumbnail: true),
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => const Center(
                                                        child: CircularProgressIndicator(
                                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                                                        ),
                                                      ),
                                                      errorWidget: (context, url, error) => Container(
                                                        color: Colors.grey[900],
                                                        child: const Icon(
                                                          FeatherIcons.video,
                                                          color: Colors.grey,
                                                          size: 40,
                                                        ),
                                                      ),
                                                    )
                                              : videoController.value.isInitialized
                                                  ? AspectRatio(
                                                      aspectRatio: videoController.value.aspectRatio,
                                                      child: VideoPlayer(videoController),
                                                    )
                                                  : CachedNetworkImage(
                                                      imageUrl: _optimizeCloudinaryVideoUrl(originalUrl, isThumbnail: true),
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => const Center(
                                                        child: CircularProgressIndicator(
                                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                                                        ),
                                                      ),
                                                      errorWidget: (context, url, error) => Container(
                                                        color: Colors.grey[900],
                                                        child: const Icon(
                                                          FeatherIcons.video,
                                                          color: Colors.grey,
                                                          size: 40,
                                                        ),
                                                      ),
                                                    ),
                                        ),
                                        if ((videoController == null || !videoController.value.isInitialized || !videoController.value.isPlaying) &&
                                            (betterPlayerController == null || (betterPlayerController != null && !(betterPlayerController.isPlaying() ?? false))))
                                          const Icon(
                                            FeatherIcons.playCircle,
                                            color: Colors.white70,
                                            size: 40,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        } else if (attachment['type'] == "audio") {
                          if (!_audioPlayers.containsKey(attachmentKey)) {
                            _audioPlayers[attachmentKey] = AudioPlayer();
                            _audioPlaying[attachmentKey] = false;
                          }
                          final player = _audioPlayers[attachmentKey]!;
                          final isPlaying = _audioPlaying[attachmentKey] ?? false;

                          return GestureDetector(
                            onTap: () async {
                              setState(() {
                                _audioPlaying[attachmentKey] = !isPlaying;
                              });
                              if (isPlaying) {
                                await player.pause();
                              } else {
                                try {
                                  await player.setSourceUrl(displayUrl);
                                  await player.resume();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to play audio: $e',
                                        style: GoogleFonts.roboto(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.red[700],
                                    ),
                                  );
                                  setState(() {
                                    _audioPlaying[attachmentKey] = false;
                                  });
                                }
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  isPlaying ? FeatherIcons.pauseCircle : FeatherIcons.playCircle,
                                  color: Colors.tealAccent,
                                  size: 40,
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            color: Colors.grey[900],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  FeatherIcons.file,
                                  color: Colors.tealAccent,
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  attachment['filename'],
                                  style: GoogleFonts.roboto(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
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
                                post.likes++;
                              });
                            },
                          ),
                          Text(
                            '${post.likes}',
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
                              _showRepliesDialog(post);
                            },
                          ),
                          Text(
                            '${post.replies.length}',
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
                              setState(() {
                                post.reposts++;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Poa! Reposted!',
                                    style: GoogleFonts.poppins(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.teal[700],
                                ),
                              );
                            },
                          ),
                          Text(
                            '${post.reposts}',
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
                            '${post.views}',
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
      body: Obx(() {
        if (dataController.posts.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
            ),
          );
        }
        return ListView.separated(
          itemCount: dataController.posts.length,
          separatorBuilder: (context, index) => Divider(
            color: Colors.grey[850],
            height: 1,
          ),
          itemBuilder: (context, index) {
            final postMap = dataController.posts[index];
            final post = ChatterPost(
              username: postMap['username'] ?? 'Unknown User',
              content: postMap['content'] ?? '',
              timestamp: postMap['createdAt'] is String ? DateTime.parse(postMap['createdAt']) : DateTime.now(),
              likes: postMap['likes'] ?? 0,
              reposts: postMap['reposts'] ?? 0,
              views: postMap['views'] ?? 0,
              avatarInitial: (postMap['username']?.isNotEmpty ?? false) ? postMap['username'][0].toUpperCase() : '?',
              attachments: (postMap['attachments'] as List<dynamic>?)?.map((att) => {
                    'filename': att['filename'] ?? '',
                    'url': att['url'] as String? ?? '',
                    'size': att['size'] ?? 0,
                    'type': att['type'] ?? 'unknown',
                  }).toList() ??
                  [],
              replies: [],
            );
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: Curves.easeInOut,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: _buildPostContent(post, isReply: false),
              ),
            );
          },
        );
      }),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF000000),
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.roboto(),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.search, size: 24),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(FeatherIcons.user, size: 24),
            label: 'Profile',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Search screen coming soon!',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                backgroundColor: Colors.teal[700],
              ),
            );
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Profile screen coming soon!',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                backgroundColor: Colors.teal[700],
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToPostScreen,
        backgroundColor: Colors.tealAccent,
        elevation: 2,
        child: const Icon(FeatherIcons.plus, color: Colors.black),
      ),
    );
  }
}

extension PdfImageExtension on PdfImage {
  List<int> get bytes => <int>[];
}

extension MapGetOrElse<K, V> on Map<K, V> {
  V getOrElse(K key, V defaultValue) => this[key] ?? defaultValue;
}