import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:chatter/widgets/video_player_widget.dart'; // Added import
import 'package:chatter/widgets/better_player_widget.dart'; // Added import

class MediaViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> attachments;
  final int initialIndex;
  final String message;
  final String userName;
  final String? userAvatarUrl;
  final DateTime timestamp;
  final int viewsCount;
  final int likesCount;
  final int repostsCount;

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
  }) : super(key: key);

  @override
  _MediaViewPageState createState() => _MediaViewPageState();
}

class _MediaViewPageState extends State<MediaViewPage> with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentPageIndex;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  AnimationController? _transformationAnimationController;
  TransformationController? _transformationController;
  final Dio _dio = Dio();
  int? _androidSdkInt; // To store Android SDK version

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    if (widget.attachments.any((item) => item is! Map<String, dynamic>)) {
      debugPrint("CRITICAL WARNING: MediaViewPage received invalid attachments list.");
    }

    _currentPageIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _fetchAndroidVersion();
  }

  Future<void> _fetchAndroidVersion() async {
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (mounted) {
        setState(() {
          _androidSdkInt = androidInfo.version.sdkInt;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController?.dispose();
    _transformationAnimationController?.dispose();
    super.dispose();
  }

  String _optimizeCloudinaryVideoUrl(String? url) {
    if (url == null || !url.contains('cloudinary.com')) return url ?? '';
    final uri = Uri.parse(url);
    final optimizedParams = {
      ...uri.queryParameters,
      'q': 'auto:good',
      'f': 'auto',
      'c': 'scale',
      'ac': 'aac',
      'vc': 'auto',
      'dpr': 'auto',
      'cs': 'hls',
      'w': '1280',
      'h': '720',
      'r': '24',
      'b': 'auto',
    };
    return uri.replace(queryParameters: optimizedParams).toString();
  }

  String _optimizeCloudinaryUrl(String? url) {
    if (url == null || !url.contains('cloudinary.com')) return url ?? '';
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'q': 'auto',
      'f': 'auto',
    }).toString();
  }

  String _getPageTitle(Map<String, dynamic> attachment) {
    final String type = attachment['type']?.toString().toLowerCase() ?? 'unknown';
    switch (type) {
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FeatherIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.userAvatarUrl != null && widget.userAvatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(
                      _optimizeCloudinaryUrl(widget.userAvatarUrl!),
                      maxWidth: 100, // Optimize memory for AppBar avatar
                      maxHeight: 100,
                    )
                  : null,
              child: widget.userAvatarUrl == null || widget.userAvatarUrl!.isEmpty
                  ? const Icon(FeatherIcons.user, size: 18, color: Colors.white)
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
                    icon: const Icon(FeatherIcons.download, color: Colors.white),
                    onPressed: () => _downloadAttachment(widget.attachments[_currentPageIndex]),
                  ),
          IconButton(
            icon: const Icon(FeatherIcons.moreVertical, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
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
                    final Map<String, dynamic> currentAttachment = widget.attachments[index];
                    final String? url = currentAttachment['url'] as String?;
                    final File? file = currentAttachment['file'] as File?;
                    final String type = currentAttachment['type']?.toString().toLowerCase() ?? 'unknown';
                    final String displayPath = url ?? file?.path ?? 'Unknown attachment';
                    final String optimizedUrl = type == 'video' ? _optimizeCloudinaryVideoUrl(url) : _optimizeCloudinaryUrl(url);

                    Widget mediaWidget;
                    switch (type) {
                      case 'image':
                        mediaWidget = _buildFullScreenImageViewer(context, currentAttachment, displayPath, optimizedUrl);
                        break;
                      case 'pdf':
                        mediaWidget = _buildPdfViewer(context, currentAttachment, displayPath, optimizedUrl);
                        break;
                      case 'video':
                        mediaWidget = VideoPlayerContainer(
                          url: optimizedUrl.isNotEmpty ? optimizedUrl : url,
                          file: file,
                          displayPath: displayPath,
                          // Conditional player selection:
                          // Android < 12 (SDK < 31) -> better_player_enhanced
                          // Android >= 12 (SDK >= 31) -> video_player
                          preferBetterPlayer: Platform.isAndroid && _androidSdkInt != null && _androidSdkInt! < 31,
                          thumbnailUrl: currentAttachment['thumbnailUrl'] as String?,
                          aspectRatioString: currentAttachment['aspectRatio'] as String?,
                          numericAspectRatio: (currentAttachment['width'] is num && currentAttachment['height'] is num && (currentAttachment['height'] as num) > 0)
                              ? (currentAttachment['width'] as num) / (currentAttachment['height'] as num)
                              : null, // Calculate and pass numeric aspect ratio
                        );
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
                    return Center(child: mediaWidget);
                  },
                ),
              ),
            ],
          ),
          _buildAppBarGradientMask(context),
        ],
      ),
    );
  }

  Widget _buildAppBarGradientMask(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: statusBarHeight + appBarHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenImageViewer(BuildContext context, Map<String, dynamic> attachment, String displayPath, String? optimizedUrl) {
    final String? url = attachment['url'] as String?;
    final File? file = attachment['file'] as File?;

    // Retrieve width and height from attachment
    final num? imageWidth = attachment['width'] as num?;
    final num? imageHeight = attachment['height'] as num?;
    double? originalAspectRatio;

    if (imageWidth != null && imageHeight != null && imageWidth > 0 && imageHeight > 0) {
      originalAspectRatio = imageWidth / imageHeight;
    }

    _transformationController?.value = Matrix4.identity();

    final imageContentWidget = optimizedUrl?.isNotEmpty == true
        ? CachedNetworkImage(
            imageUrl: optimizedUrl!,
            fit: BoxFit.contain,
            memCacheWidth: 1080, // Cap memory for full-screen images
            placeholder: (context, url) => const Center(child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent))),
            errorWidget: (context, url, error) => buildError(context, message: 'Error loading image: $error'),
            cacheKey: url,
          )
        : file != null
            ? Image.file(
                file,
                fit: BoxFit.contain,
                // Width and alignment are handled by AspectRatio and InteractiveViewer
                errorBuilder: (context, error, stackTrace) => buildError(context, message: 'Error loading image file: $error'),
              )
            : buildError(context, message: 'No image source available for $displayPath');

    Widget interactiveImage = InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5, // Allow zooming out slightly
      maxScale: 4.0,
      child: imageContentWidget,
    );

    return GestureDetector(
      onDoubleTapDown: (details) => _handleDoubleTap(details.localPosition),
      // The InteractiveViewer will now be the direct child of GestureDetector (and thus Center from PageView's itemBuilder).
      // It will use the screen space. The child (CachedNetworkImage with BoxFit.contain) will fit itself initially.
      child: interactiveImage,
    );
  }

  void _handleDoubleTap(Offset tapPosition) {
    if (_transformationController == null) return;

    _transformationAnimationController?.reset();
    final currentMatrix = _transformationController!.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();

    Matrix4 targetMatrix;
    if (currentScale <= 1.01) { // If at initial fitted scale (or very close to it)
      const double targetScale = 2.5; // Zoom in to 2.5x
      final Offset centeredTapPosition = Offset(
        tapPosition.dx * (targetScale - 1),
        tapPosition.dy * (targetScale - 1),
      );
      targetMatrix = Matrix4.identity()
        ..translate(-centeredTapPosition.dx, -centeredTapPosition.dy)
        ..scale(targetScale);
    } else {
      targetMatrix = Matrix4.identity();
    }

    final animation = Matrix4Tween(begin: currentMatrix, end: targetMatrix).animate(
      CurveTween(curve: Curves.easeInOut).animate(_transformationAnimationController!),
    );

    animation.addListener(() {
      _transformationController?.value = animation.value;
    });

    _transformationAnimationController!.forward();
  }

  Widget _buildPdfViewer(BuildContext context, Map<String, dynamic> attachment, String displayPath, String? optimizedUrl) {
    final String? url = attachment['url'] as String?;
    final File? file = attachment['file'] as File?;

    if (optimizedUrl?.isNotEmpty == true || file != null) {
      final Uri pdfUri = optimizedUrl?.isNotEmpty == true ? Uri.parse(optimizedUrl!) : Uri.file(file!.path);
      return PdfViewer.uri(
        pdfUri,
        params: const PdfViewerParams(
          margin: 0,
          backgroundColor: Colors.transparent,
          maxScale: 2.0,
          minScale: 0.5,
        ),
      );
    }
    return buildError(context, message: 'No PDF source available for $displayPath');
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

    bool permissionGranted = await _requestStoragePermission();
    if (!permissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission denied.', style: GoogleFonts.roboto())),
      );
      return;
    }

    Directory? targetDirectory;
    String downloadsPathMessage = "Downloaded to ";

    if (Platform.isAndroid) {
      try {
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          String publicDownloadsPath = '${externalDir.path}/Download';
          targetDirectory = Directory(publicDownloadsPath);
          if (!await targetDirectory.exists()) {
            await targetDirectory.create(recursive: true);
          }
          downloadsPathMessage = "Downloaded to Downloads folder. Path: ";
        }
      } catch (e) {
        debugPrint("Error accessing external storage: $e");
      }
    }

    if (targetDirectory == null) {
      try {
        targetDirectory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        downloadsPathMessage = Platform.isIOS ? "Downloaded to app files. Path: " : "Downloaded to app-specific folder. Path: ";
      } catch (e) {
        debugPrint("Error getting downloads directory: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get downloads directory.', style: GoogleFonts.roboto())),
        );
        return;
      }
    }

    String fileName = attachment['filename']?.toString() ?? url.split('/').last;
    if (fileName.isEmpty || !fileName.contains('.')) {
      final String type = attachment['type']?.toString().toLowerCase() ?? 'unknown';
      String extension = switch (type) {
        'image' => '.jpg',
        'video' => '.mp4',
        'audio' => '.mp3',
        'pdf' => '.pdf',
        _ => '.dat',
      };
      fileName = "downloaded_file_${DateTime.now().millisecondsSinceEpoch}$extension";
    }

    final String savePath = "${targetDirectory.path}/$fileName";

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
        SnackBar(content: Text('$downloadsPathMessage$savePath', style: GoogleFonts.roboto())),
      );
    } catch (e) {
      debugPrint("Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e', style: GoogleFonts.roboto())),
      );
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      return true;
    }

    final status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
      return false;
    }
    return false;
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
        style: GoogleFonts.roboto(color: Colors.white70, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      if (fileName != null) ...[
        const SizedBox(height: 10),
        Text(
          fileName,
          style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ],
  );
}

class VideoPlayerContainer extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;
  final bool preferBetterPlayer; // Changed from useBetterPlayer
  final String? thumbnailUrl;
  final String? aspectRatioString;
  final double? numericAspectRatio;

  const VideoPlayerContainer({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    required this.preferBetterPlayer, // Changed
    this.thumbnailUrl,
    this.aspectRatioString,
    this.numericAspectRatio,
  }) : super(key: key);

  @override
  _VideoPlayerContainerState createState() => _VideoPlayerContainerState();
}

class _VideoPlayerContainerState extends State<VideoPlayerContainer> {
  @override
  Widget build(BuildContext context) {
    final double videoAspectRatio = widget.numericAspectRatio ??
        (double.tryParse(widget.aspectRatioString ?? '') ?? 16 / 9);

    Widget playerWidget;
    if (widget.preferBetterPlayer) {
      playerWidget = BetterPlayerWidget(
        url: widget.url,
        file: widget.file,
        displayPath: widget.displayPath,
        thumbnailUrl: widget.thumbnailUrl,
        isFeedContext: false,
        // Pass aspect ratio for thumbnail and loading indicator handling
        videoAspectRatioProp: videoAspectRatio,
      );
    } else {
      playerWidget = VideoPlayerWidget(
        url: widget.url,
        file: widget.file,
        displayPath: widget.displayPath,
        thumbnailUrl: widget.thumbnailUrl,
        isFeedContext: false,
        videoAspectRatioProp: videoAspectRatio, // Pass aspect ratio
      );
    }
    // Ensure the player is centered and respects the calculated aspect ratio
    return Center(
      child: AspectRatio(
        aspectRatio: videoAspectRatio,
        child: playerWidget,
      ),
    );
  }
}

// Removed InternalBetterPlayerWidget and _InternalBetterPlayerWidgetState
// as BetterPlayerWidget from lib/widgets/better_player_widget.dart is now used.

//This widget is actually still used by VideoPlayerContainer if preferBetterPlayer is true.
//It should be InternalBetterPlayerWidget as previously named if we are keeping it separate.
//For now, assuming this is the one to modify for placeholder.
//If plan implies modifying the one in lib/widgets/, this needs to be done there.
//Based on current plan step "InternalBetterPlayerWidget (in media_view_page.dart)"

class InternalBetterPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;
  final String? thumbnailUrl;
  final String? aspectRatioString; // This was from before, might be redundant if videoAspectRatioProp is used
  final double? numericAspectRatio; // This was from before, might be redundant
  final double? videoAspectRatioProp; // New: To be passed from VideoPlayerContainer

  const InternalBetterPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    this.thumbnailUrl,
    this.aspectRatioString,
    this.numericAspectRatio,
    this.videoAspectRatioProp, // New
  }) : super(key: key);

  @override
  _InternalBetterPlayerWidgetState createState() => _InternalBetterPlayerWidgetState();
}

class _InternalBetterPlayerWidgetState extends State<InternalBetterPlayerWidget> {
  BetterPlayerController? _betterPlayerController;
  bool _isLoading = true; // Will represent if the main video is loading
  bool _isInitialized = false; // Tracks if BetterPlayerController is initialized
  String? _errorMessage;
  // _videoAspectRatio is now determined by videoAspectRatioProp or defaults.
  // double? _videoAspectRatio; // This local state might be less important now

  @override
  void initState() {
    super.initState();
    // _videoAspectRatio = widget.videoAspectRatioProp ?? widget.numericAspectRatio ?? (double.tryParse(widget.aspectRatioString ?? '') ?? 16/9);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // No longer setting _isLoading = true here, as placeholder handles initial view.
    // _isLoading will be true while BetterPlayer is actually fetching/buffering.
    // setState(() { _isLoading = true; _errorMessage = null; });
    setState(() { _errorMessage = null; _isInitialized = false; });


    try {
      // Determine aspect ratio to use for the player configuration itself
      // This might be used by BetterPlayer if it needs an explicit aspect ratio hint,
      // but ideally, BoxFit.cover within a sized parent AspectRatio handles it.
      double playerConfigAspectRatio = widget.videoAspectRatioProp ?? 16/9;
      // if (widget.numericAspectRatio != null && widget.numericAspectRatio! > 0 && widget.numericAspectRatio!.isFinite) {
      //   playerConfigAspectRatio = widget.numericAspectRatio!;
      // } else if (widget.aspectRatioString != null && widget.aspectRatioString!.isNotEmpty) {
      //   final parsedAspectRatioFromString = double.tryParse(widget.aspectRatioString!);
      //   if (parsedAspectRatioFromString != null && parsedAspectRatioFromString.isFinite && parsedAspectRatioFromString > 0) {
      //     playerConfigAspectRatio = parsedAspectRatioFromString;
      //   }
      // }


      final configuration = BetterPlayerConfiguration(
        autoPlay: true, // Autoplay once ready
        looping: false,
        fit: BoxFit.cover, // Cover the area defined by parent AspectRatio
        aspectRatio: playerConfigAspectRatio, // Provide aspect ratio hint to player
        placeholder: _buildThumbnailWithLoadingIndicator(),
        errorBuilder: (context, errorMessage) {
          // Ensure UI updates on error
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(mounted) {
              setState(() {
                _isLoading = false;
                _isInitialized = false;
                _errorMessage = errorMessage ?? 'Error playing video';
              });
            }
          });
          return buildError( // buildError is a global helper in this file
            context,
            message: errorMessage ?? 'Error playing video',
            fileName: widget.displayPath.split('/').last,
          );
        },
        controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControlsOnInitialize: true, // Show controls immediately
            showControls: true, // Enable controls
        ),
        cacheConfiguration: const BetterPlayerCacheConfiguration(
          useCache: false,
        ),
      );

      BetterPlayerDataSource dataSource;
      if (widget.url != null && widget.url!.isNotEmpty) {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          widget.url!,
        );
      } else if (widget.file != null) {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.file,
          widget.file!.path,
        );
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No video source available';
        });
        return;
      }

      _betterPlayerController = BetterPlayerController(
        configuration,
        betterPlayerDataSource: dataSource,
      );

      _betterPlayerController!.addEventsListener((event) {
        if (!mounted) return;
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          setState(() {
            _isInitialized = true;
            _isLoading = false; // Video is initialized, so not "loading" in the placeholder sense
          });
        } else if (event.betterPlayerEventType == BetterPlayerEventType.bufferingStart || event.betterPlayerEventType == BetterPlayerEventType.play) {
          // Consider buffering as loading if not yet initialized fully
           if (!_isInitialized) { // Or a more specific flag for "buffering placeholder"
            setState(() { _isLoading = true; });
           }
        } else if (event.betterPlayerEventType == BetterPlayerEventType.bufferingEnd || event.betterPlayerEventType == BetterPlayerEventType.playing) {
           setState(() { _isLoading = false; });
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
           setState(() {
            _isLoading = false;
            _isInitialized = false;
            _errorMessage = event.parameters?['message'] as String? ?? 'Player error';
          });
        }
      });

    } catch (e) {
      debugPrint('Error initializing video player: $e');
      setState(() {
        _isLoading = false;
        _isInitialized = false;
        _errorMessage = 'Failed to initialize video player: $e';
      });
    }
  }

  Widget _buildThumbnailWithLoadingIndicator() {
    final double effectiveAspectRatio = widget.videoAspectRatioProp ?? 16 / 9;
    // Approximate screen width for memCacheWidth, or pass it if available
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
          AspectRatio(
            aspectRatio: effectiveAspectRatio,
            child: CachedNetworkImage(
              imageUrl: widget.thumbnailUrl!,
              fit: BoxFit.cover,
              memCacheWidth: screenWidth.round(), // Cache at screen width
              errorWidget: (context, url, error) => Container(color: Colors.black), // Fallback for thumbnail error
              placeholder: (context, url) => Container(color: Colors.black), // Basic placeholder
            ),
          ),
        // Show loading indicator if _isLoading is true (meaning player is trying to load/buffer)
        // and not yet fully initialized and playing.
        // This condition might need refinement based on BetterPlayer events.
        // Typically, _isLoading would be true before 'initialized' or during 'bufferingStart'.
        if (_isLoading || !_isInitialized) // Show indicator if loading OR not yet initialized
           Center(child: CircularProgressIndicator(strokeWidth: 1.0, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
      ],
    );
  }

  @override
  void dispose() {
    _betterPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return buildError( // buildError is a global helper
        context,
        message: _errorMessage,
        fileName: widget.displayPath.split('/').last,
      );
    }

    // If controller is null (e.g. no source or init failed before controller creation), show placeholder or error
    if (_betterPlayerController == null) {
        // This shows the thumbnail and potentially a loading indicator if _isLoading is true
        return _buildThumbnailWithLoadingIndicator();
    }

    // Once controller is created, BetterPlayer handles its own placeholder via config, then transitions to video
    return BetterPlayer(controller: _betterPlayerController!);
    // The parent VideoPlayerContainer provides the main AspectRatio wrapper.
    // InternalBetterPlayerWidget's build method should just return the BetterPlayer.
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
      if (widget.url != null && widget.url!.isNotEmpty) {
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
        if (mounted) setState(() => _duration = duration);
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
    setState(() => _position = position);
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
      debugPrint('Error: $_errorMessage');
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
        const Icon(FeatherIcons.music, color: Colors.tealAccent, size: 100),
        const SizedBox(height: 10),
        Text(
          widget.displayPath.split('/').last,
          style: GoogleFonts.roboto(color: Colors.white70, fontSize: 16),
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