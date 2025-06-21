import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/controllers/data-controller.dart';
// import 'package:chatter/models/feed_models.dart'; // Removed import
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/widgets/video_player_widget.dart';
import 'package:chatter/widgets/better_player_widget.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';

// MediaViewPage displays attachments with metadata and social interactions.
class MediaViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> attachments; // Changed to List<Map<String, dynamic>>
  final int initialIndex;
  final String message;
  final String userName;
  final String? userAvatarUrl;
  final DateTime timestamp;
  final int viewsCount;
  final int likesCount;
  final int repostsCount;
  final String? transitionVideoId; // For seamless transition
  final String? transitionControllerType; // 'video_player' or 'better_player'

  const MediaViewPage({
    Key? key,
    required this.attachments,
    this.initialIndex = 0,
    required this.message,
    required this.userName,
    this.userAvatarUrl,
    required this.timestamp,
    required this.viewsCount,
    required this.likesCount,
    required this.repostsCount,
    this.transitionVideoId,
    this.transitionControllerType,
  }) : super(key: key);

  @override
  _MediaViewPageState createState() => _MediaViewPageState();
}

class _MediaViewPageState extends State<MediaViewPage> {
  DataController _dataController = Get.put(DataController());
  late PageController _pageController;
  late int _currentPageIndex;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();

    // Defensive runtime check for attachments type
    if (widget.attachments.any((item) => item is! Map<String, dynamic>)) {
      print("CRITICAL WARNING: MediaViewPage received an attachments list where one or more elements are NOT Map<String, dynamic>.");
      print("Problematic attachments list: ${widget.attachments}");
      // Example of filtering (use with caution, might hide issues):
      // widget.attachments = widget.attachments.where((item) => item is Map<String, dynamic>).toList();
    }

    // Assert for development builds
    assert(
      widget.attachments.every((item) => item is Map<String, dynamic>),
      "MediaViewPage attachments list contains elements that are not of type Map<String, dynamic>. Data: ${widget.attachments.where((item) => item is! Map<String, dynamic>).toList()}"
    );

    _currentPageIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    // If this MediaViewPage was part of a video transition, signal that it's over.
    if (widget.transitionVideoId != null &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == widget.transitionVideoId) {

      // Check if the controller in DataController is still the one we might have used.
      // This is a safeguard. The primary check is isTransitioningVideo and activeFeedPlayerVideoId.
      Object? activeController = _dataController.activeFeedPlayerController.value;
      bool controllerMatchesTransitionType = false;
      if (widget.transitionControllerType == 'better_player' && activeController is BetterPlayerController) {
        controllerMatchesTransitionType = true;
      } else if (widget.transitionControllerType == 'video_player' && activeController is VideoPlayerController) {
        controllerMatchesTransitionType = true;
      }

      if (controllerMatchesTransitionType) {
          print("MediaViewPage disposing: Ending video transition for ${widget.transitionVideoId}. Feed can reclaim controller.");
          // The controller itself is not disposed here; it's handed back to the feed widget.
          // The feed widget's initState or VisibilityDetector will reclaim it.
          // Setting isTransitioningVideo to false is the main signal.
          _dataController.isTransitioningVideo.value = false;
          // DataController's activeFeedPlayerController, videoId, position should remain for the feed player to pick up.
      } else {
        // This case should ideally not happen if logic is correct.
        // It means MediaViewPage thought it was transitioning, but DataController state doesn't match.
        print("MediaViewPage disposing: Transition mismatch for ${widget.transitionVideoId}. Forcing transition end.");
        _dataController.isTransitioningVideo.value = false;
        // Clear active player state as a precaution, as it might be stale or incorrect.
        // _dataController.activeFeedPlayerController.value = null;
        // _dataController.activeFeedPlayerVideoId.value = null;
        // _dataController.activeFeedPlayerPosition.value = null;
      }
    }
    _pageController.dispose();
    super.dispose();
  }

  // Optimize Cloudinary URL for videos
  String _optimizeCloudinaryVideoUrl(String? url) {
    if (url == null || !url.contains('cloudinary.com')) return url ?? '';
    final uri = Uri.parse(url);
    
    // Video-specific optimization parameters
    final optimizedParams = {
      ...uri.queryParameters,
      'q': 'auto:good',
      'f': 'auto',
      'c': 'scale',
      'ac': 'aac',
      'vc': 'auto',
      'dpr': 'auto',
      'ar': '16:9',
      'cs': 'hls',
      'w': '1280',
      'h': '720',
      'r': '24',
      'b': 'auto',
    };
    
    return uri.replace(queryParameters: optimizedParams).toString();
  }

  // Original _optimizeCloudinaryUrl for non-video assets
  String _optimizeCloudinaryUrl(String? url) {
    if (url == null || !url.contains('cloudinary.com')) return url ?? '';
    final uri = Uri.parse(url);
    final optimizedUrl = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'q': 'auto',
      'f': 'auto',
    });
    return optimizedUrl.toString();
  }

  // Check Android version for player compatibility
  // Removed _isAndroid13OrLower, will use DataController.androidSDKVersion directly
  // Future<bool> _isAndroid13OrLower() async {
  //   if (!Platform.isAndroid) return false;
  //   final deviceInfo = DeviceInfoPlugin();
  //   final androidInfo = await deviceInfo.androidInfo;
  //   return androidInfo.version.sdkInt <= 33;
  // }

  String _getPageTitle(Map<String, dynamic> attachment) { // Changed Attachment to Map<String, dynamic>
    final String type = attachment['type'] as String? ?? 'unknown';
    switch (type.toLowerCase()) {
      case 'image':
        return 'View Image';
      case 'pdf':
        return 'View PDF';
      case 'video':
        return 'View Video';
      case 'audio':
        return 'View Audio';
      default:
        return 'View Attachment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allow body to go behind AppBar
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // No shadow for transparent AppBar
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.userAvatarUrl != null && widget.userAvatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(_optimizeCloudinaryUrl(widget.userAvatarUrl!))
                  : null,
              child: (widget.userAvatarUrl == null || widget.userAvatarUrl!.isEmpty)
                  ? Icon(FeatherIcons.user, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              widget.userName,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (widget.attachments.isNotEmpty && widget.attachments[_currentPageIndex]['url'] != null)
            _isDownloading
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(FeatherIcons.download, color: Colors.white),
                    onPressed: () {
                      _downloadAttachment(widget.attachments[_currentPageIndex]);
                    },
                  ),
          IconButton(
            icon: Icon(FeatherIcons.moreVertical, color: Colors.white),
            onPressed: () { /* TODO: Implement more options */ },
          ),
        ],
      ),
      body: Stack( // Wrap body in Stack for gradient mask
        children: [
          Column( // Original body structure
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.attachments.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> currentAttachment = widget.attachments[index]; // Now a Map
                    final String? url = currentAttachment['url'] as String?;
                    final File? file = currentAttachment['file'] as File?;
                    final String type = currentAttachment['type'] as String? ?? 'unknown';

                    final String displayPath = url ?? file?.path ?? 'Unknown attachment';
                    final String optimizedUrl = type.toLowerCase() == 'video'
                        ? _optimizeCloudinaryVideoUrl(url)
                        : _optimizeCloudinaryUrl(url);

                    Widget mediaWidget;
                    switch (type.toLowerCase()) {
                      case 'image':
                        mediaWidget = _buildFullScreenImageViewer(context, currentAttachment, displayPath, optimizedUrl);
                        // For images, we don't want the Center widget wrapping it.
                        return mediaWidget; // Return directly
                      case 'pdf':
                        mediaWidget = _buildPdfViewer(context, currentAttachment, displayPath, optimizedUrl);
                        break;
                      case 'video':
                        // Use DataController.androidSDKVersion directly
                        final int currentAndroidSDKVersion = _dataController.androidSDKVersion.value;
                        if (currentAndroidSDKVersion == 0 && Platform.isAndroid) {
                          // SDK version not yet available, show loading or placeholder
                          mediaWidget = const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                            ),
                          );
                        } else {
                          // SDK 31 is Android 12. Use better_player if SDK < 31.
                          bool useBetterPlayer = Platform.isAndroid && currentAndroidSDKVersion < 31;
                          final String? thumbnailUrl = currentAttachment['thumbnailUrl'] as String?;
                          mediaWidget = VideoPlayerContainer(
                            url: optimizedUrl.isNotEmpty ? optimizedUrl : url,
                            file: file,
                            displayPath: displayPath,
                            useBetterPlayer: useBetterPlayer, // Pass the decision
                            thumbnailUrl: thumbnailUrl,
                            // No need to pass isFeedContext, it defaults to false in VideoPlayerWidget/BetterPlayerWidget
                            // The player widgets themselves will check DataController if isTransitioningVideo is true.
                          );
                        }
                        break;
                      case 'audio':
                        mediaWidget = AudioPlayerWidget(
                          url: optimizedUrl.isNotEmpty ? optimizedUrl : url,
                          file: file,
                          displayPath: displayPath,
                        );
                        break;
                      default:
                        mediaWidget = buildError(
                          context,
                          icon: FeatherIcons.file,
                          message: 'Unsupported attachment type: $type',
                          fileName: displayPath.split('/').last,
                          iconColor: Colors.grey[600],
                        );
                    }
                    // For other types, keep the Center for now, or adjust as needed.
                    return Center(child: mediaWidget);
                  },
                ),
              ),
              // Removed the Padding widget containing metadata and engagement counts
            ],
          ),
          _buildAppBarGradientMask(context), // Add the gradient mask on top
        ],
      ),
    );
  }

  Widget _buildAppBarGradientMask(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height; // Default AppBar height
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: statusBarHeight + appBarHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.6), Colors.transparent], // Adjusted opacity
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 1.0] // Ensure gradient covers the full height
          ),
        ),
        // This container is just for the gradient, AppBar content will be drawn by Scaffold's AppBar
      ),
    );
  }


  Widget _buildSocialButton(IconData icon, String label, VoidCallback onPressed) {
    return TextButton.icon(
      icon: Icon(icon, color: Colors.white70, size: 20),
      label: Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size(50, 30),
      ),
    );
  }

  // Renamed to _buildFullScreenImageViewer and removed Center widget, LayoutBuilder
  Widget _buildFullScreenImageViewer(BuildContext context, Map<String, dynamic> attachment, String displayPath, String optimizedUrl) {
    final String? url = attachment['url'] as String?;
    final File? file = attachment['file'] as File?;

    final String currentOptimizedUrl = _optimizeCloudinaryUrl(url);
    if (currentOptimizedUrl.isNotEmpty) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: currentOptimizedUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Center(child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent), backgroundColor: Colors.grey)),
          errorWidget: (context, url, error) => buildError(context, message: 'Error loading image: $error'),
          cacheKey: url,
          width: MediaQuery.of(context).size.width, // Ensure it takes full width
          alignment: Alignment.center, // Center the image within the full width
        ),
      );
    } else if (file != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.file(
          file,
          fit: BoxFit.contain,
          width: MediaQuery.of(context).size.width, // Ensure it takes full width
          alignment: Alignment.center, // Center the image within the full width
          errorBuilder: (context, error, stackTrace) => buildError(context, message: 'Error loading image file: $error'),
        ),
      );
    } else {
      return buildError(context, message: 'No image source available for $displayPath');
    }
  }

  Widget _buildPdfViewer(BuildContext context, Map<String, dynamic> attachment, String displayPath, String optimizedUrl) {
    final String? url = attachment['url'] as String?;
    final File? file = attachment['file'] as File?;

    final String currentOptimizedUrl = _optimizeCloudinaryUrl(url);
    if (currentOptimizedUrl.isNotEmpty || file != null) {
      final Uri pdfUri = currentOptimizedUrl.isNotEmpty
          ? Uri.parse(currentOptimizedUrl)
          : Uri.file(file!.path);
      return PdfViewer.uri(
        pdfUri,
        params: const PdfViewerParams(
          margin: 0,
          backgroundColor: Colors.transparent,
          maxScale: 2.0,
          minScale: 0.5,
        ),
      );
    } else {
      return buildError(context, message: 'No PDF source available for $displayPath');
    }
  }

  Future<void> _downloadAttachment(Map<String, dynamic> attachment) async {
    if (_isDownloading) return;

    final String? url = attachment['url'] as String?;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No downloadable URL found.', style: GoogleFonts.roboto())),
      );
      return;
    }

    // 1. Check and Request Permissions
    bool permissionGranted = await _requestStoragePermission();
    if (!permissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission denied.', style: GoogleFonts.roboto())),
      );
      return;
    }

    // 2. Get Downloads Directory
    Directory? downloadsDirectory;
    try {
      downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory == null && Platform.isIOS) { // Fallback for iOS if getDownloadsDirectory is null
          downloadsDirectory = await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      print("Error getting downloads directory: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get downloads directory.', style: GoogleFonts.roboto())),
      );
      return;
    }

    if (downloadsDirectory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not determine downloads directory.', style: GoogleFonts.roboto())),
        );
        return;
    }


    String fileName = attachment['filename'] as String? ?? url.split('/').last;
    // Sanitize filename if necessary, or ensure it's valid
    if (fileName.isEmpty || !fileName.contains('.')) {
        final String type = attachment['type'] as String? ?? 'unknown';
        String extension = ".dat"; // default extension
        if (type == 'image') extension = ".jpg"; // Be more specific if possible from mime type
        else if (type == 'video') extension = ".mp4";
        else if (type == 'audio') extension = ".mp3";
        else if (type == 'pdf') extension = ".pdf";
        fileName = "downloaded_file_${DateTime.now().millisecondsSinceEpoch}$extension";
    }

    final String savePath = "${downloadsDirectory.path}/$fileName";

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded to ${savePath.split('/').last}', style: GoogleFonts.roboto())),
      );
    } catch (e) {
      print("Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}', style: GoogleFonts.roboto())),
      );
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS) return true; // iOS doesn't require explicit permission for saving to app's sandbox / getDownloadsDirectory

    PermissionStatus status;
    if (await DeviceInfoPlugin().androidInfo.then((value) => value.version.sdkInt) >= 33) { // Android 13+
        // For Android 13+, no specific storage permission needed for own app's directory or public media collections if using MediaStore.
        // getDownloadsDirectory() should work. If targeting specific media types, READ_MEDIA_IMAGES, etc. would be for *reading*.
        // For saving to a common "Downloads" folder, it's generally permissible.
        return true;
    } else { // Android 12 and below
        status = await Permission.storage.request();
    }

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      // Consider guiding user to app settings
      openAppSettings();
      return false;
    } else {
      return false;
    }
  }
}

Widget buildError(
  BuildContext context, {
  String? message,
  IconData? icon,
  String? fileName,
  Color? iconColor,
}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        icon ?? FeatherIcons.alertTriangle,
        color: iconColor ?? Colors.redAccent,
        size: icon != null ? 100 : 50,
      ),
      const SizedBox(height: 10),
      Text(
        message ?? 'Error loading content',
        style: GoogleFonts.roboto(
          color: Colors.white70,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
      if (fileName != null) ...[
        const SizedBox(height: 10),
        Text(
          fileName,
          style: GoogleFonts.roboto(
            color: Colors.grey[500],
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ],
  );
}

// VideoPlayerContainer to handle optimized video playback
class VideoPlayerContainer extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;
  final bool useBetterPlayer; // Changed from isAndroid13OrLower
  final String? thumbnailUrl;

  const VideoPlayerContainer({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    required this.useBetterPlayer, // Changed from isAndroid13OrLower
    this.thumbnailUrl,
  }) : super(key: key);

  @override
  _VideoPlayerContainerState createState() => _VideoPlayerContainerState();
}

class _VideoPlayerContainerState extends State<VideoPlayerContainer> {
  // Controllers and detailed state are managed by BetterPlayerWidget or VideoPlayerWidget.
  // This container just decides which one to show.

  // String? _errorMessage; // If any error logic remains specific to this container's setup

  @override
  void initState() {
    super.initState();
    // Initialization is handled by child widgets (BetterPlayerWidget or VideoPlayerWidget)
    // The logic for choosing player (based on DataController.androidSDKVersion) is now in the parent PageView builder,
    // so widget.useBetterPlayer is determined before this widget is built.
  }

  @override
  void dispose() {
    // Controllers are disposed by their respective widgets.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If there was any setup error specific to VideoPlayerContainer decision logic:
    // if (_errorMessage != null) {
    //   return buildError(context, message: _errorMessage!);
    // }

    // Directly render the appropriate player widget based on useBetterPlayer.
    // They will handle their own loading indicators and thumbnail display.
    if (widget.useBetterPlayer) {
      return BetterPlayerWidget(
        url: widget.url,
        file: widget.file,
        displayPath: widget.displayPath,
        thumbnailUrl: widget.thumbnailUrl,
        // isFeedContext is false by default in BetterPlayerWidget, which is correct for MediaViewPage
      );
    } else {
      return VideoPlayerWidget(
        url: widget.url,
        file: widget.file,
        displayPath: widget.displayPath,
        thumbnailUrl: widget.thumbnailUrl,
      );
    }
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;

  const AudioPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
  }) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> with SingleTickerProviderStateMixin {
  late audioplayers.AudioPlayer _audioPlayer;
  late WaveformPlayerController _waveformController;
  late AnimationController _animationController;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isLoading = true;
  int _retryCount = 0;
  final int _maxRetries = 3;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = audioplayers.AudioPlayer();
    _waveformController = WaveformPlayerController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      audioplayers.Source audioSource;
      if (widget.url != null) {
        audioSource = audioplayers.UrlSource(widget.url!);
      } else if (widget.file != null) {
        audioSource = audioplayers.DeviceFileSource(widget.file!.path);
      } else {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
          _errorMessage = 'No audio source available';
        });
        return;
      }

      await _audioPlayer.setSource(audioSource);
      final duration = await _audioPlayer.getDuration();
      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
        });
        await _waveformController.prepareWaveform(widget.url ?? widget.file!.path, duration);
      }

      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
            if (_duration.inMilliseconds > 0) {
              _waveformController.updatePosition(position.inMilliseconds / _duration.inMilliseconds);
            }
          });
        }
      });

      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == audioplayers.PlayerState.playing;
            if (_isPlaying) {
              _animationController.repeat();
            } else {
              _animationController.stop();
            }
          });
        }
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        return _initializeAudio();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
          _errorMessage = 'Failed to load audio after $_maxRetries attempts: $e';
        });
      }
    }
  }

  void _seekToPosition(double value) {
    final position = _duration * value;
    _audioPlayer.seek(position);
    _waveformController.updatePosition(value);
    setState(() {
      _position = position;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                backgroundColor: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _errorMessage != null) {
      print('Error: $_errorMessage');
      return Center(
        child: Text(
          _errorMessage ?? 'Audio player not initialized',
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FeatherIcons.music,
          color: Colors.tealAccent,
          size: 100,
        ),
        const SizedBox(height: 10),
        Text(
          widget.displayPath.split('/').last,
          style: GoogleFonts.roboto(
            color: Colors.white70,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        CustomWaveform(
          controller: _waveformController,
          animationController: _animationController,
          height: 100,
          width: MediaQuery.of(context).size.width - 40,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: _duration.inMilliseconds > 0
                    ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0,
                onChanged: _isInitialized ? (value) => _seekToPosition(value) : null,
                activeColor: Colors.tealAccent,
                inactiveColor: Colors.grey,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: GoogleFonts.roboto(color: Colors.white70),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.tealAccent,
                      size: 40,
                    ),
                    onPressed: _isInitialized
                        ? () async {
                            if (_isPlaying) {
                              await _audioPlayer.pause();
                            } else {
                              await _audioPlayer.resume();
                            }
                            setState(() {});
                          }
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDuration(_duration),
                    style: GoogleFonts.roboto(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

class WaveformPlayerController {
  List<double> _waveformData = [];
  double _progress = 0.0;

  Future<void> prepareWaveform(String path, Duration duration) async {
    const sampleCount = 200;
    final random = Random();
    _waveformData = List.generate(sampleCount, (index) {
      final amplitude = 0.3 + random.nextDouble() * 0.5;
      final frequency = 1.0 + random.nextDouble() * 4.0;
      final time = index / sampleCount;
      return amplitude * sin(2 * pi * frequency * time);
    }).map((value) => (value.abs() * 0.8 + 0.2).clamp(0.0, 1.0)).toList();
  }

  void updatePosition(double progress) {
    _progress = progress.clamp(0.0, 1.0);
  }

  List<double> getWaveformData() => _waveformData;

  double getProgress() => _progress;

  void dispose() {
    _waveformData.clear();
  }
}

class CustomWaveform extends StatelessWidget {
  final WaveformPlayerController controller;
  final AnimationController animationController;
  final double height;
  final double width;

  const CustomWaveform({
    Key? key,
    required this.controller,
    required this.animationController,
    required this.height,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, _) {
        return CustomPaint(
          size: Size(width, height),
          painter: WaveformPainter(
            waveformData: controller.getWaveformData(),
            progress: controller.getProgress(),
            isPlaying: animationController.isAnimating,
            animationValue: animationController.value,
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final bool isPlaying;
  final double animationValue;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.isPlaying,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = Colors.tealAccent
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final barWidth = size.width / waveformData.length;
    final progressIndex = (progress * waveformData.length).floor();

    for (int i = 0; i < waveformData.length; i++) {
      final barHeight = waveformData[i] * size.height * (isPlaying ? 0.9 + 0.1 * sin(i * 0.05 + animationValue * 2 * pi) : 0.9);
      final x = i * barWidth;
      final rect = Rect.fromLTWH(
        x,
        (size.height - barHeight) / 2,
        barWidth * 0.8,
        barHeight,
      );

      canvas.drawRect(rect, i <= progressIndex ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}