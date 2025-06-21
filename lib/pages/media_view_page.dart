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
  final String? transitionVideoId;
  final String? transitionControllerType;

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

class _MediaViewPageState extends State<MediaViewPage> with TickerProviderStateMixin {
  final DataController _dataController = Get.find<DataController>();
  late PageController _pageController;
  late int _currentPageIndex;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  AnimationController? _transformationAnimationController;
  TransformationController? _transformationController;
  final Dio _dio = Dio();

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
  }

  @override
  void dispose() {
    if (widget.transitionVideoId != null &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == widget.transitionVideoId) {
      final activeController = _dataController.activeFeedPlayerController.value;
      bool controllerMatchesTransitionType = false;
      if (widget.transitionControllerType == 'better_player' && activeController is BetterPlayerController) {
        controllerMatchesTransitionType = true;
      } else if (widget.transitionControllerType == 'video_player' && activeController is VideoPlayerController) {
        controllerMatchesTransitionType = true;
      }

      if (controllerMatchesTransitionType) {
        _dataController.isTransitioningVideo.value = false;
      } else {
        debugPrint("MediaViewPage disposing: Transition mismatch for ${widget.transitionVideoId}.");
        _dataController.isTransitioningVideo.value = false;
      }
    }
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
                  ? CachedNetworkImageProvider(_optimizeCloudinaryUrl(widget.userAvatarUrl!))
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
                          useBetterPlayer: true,
                          thumbnailUrl: currentAttachment['thumbnailUrl'] as String?,
                          aspectRatio: currentAttachment['aspectRatio'] as String?, // Pass string aspect ratio
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

    _transformationController?.value = Matrix4.identity();

    final imageWidget = optimizedUrl?.isNotEmpty == true
        ? CachedNetworkImage(
            imageUrl: optimizedUrl!,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent))),
            errorWidget: (context, url, error) => buildError(context, message: 'Error loading image: $error'),
            cacheKey: url,
            width: MediaQuery.of(context).size.width,
            alignment: Alignment.center,
          )
        : file != null
            ? Image.file(
                file,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) => buildError(context, message: 'Error loading image file: $error'),
              )
            : buildError(context, message: 'No image source available for $displayPath');

    return GestureDetector(
      onDoubleTapDown: (details) => _handleDoubleTap(details.localPosition),
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        child: imageWidget,
      ),
    );
  }

  void _handleDoubleTap(Offset tapPosition) {
    if (_transformationController == null) return;

    _transformationAnimationController?.reset();
    final currentMatrix = _transformationController!.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();

    Matrix4 targetMatrix;
    if (currentScale <= 1.01) {
      const double targetScale = 2.0;
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
  final bool useBetterPlayer;
  final String? thumbnailUrl;
  final String? aspectRatio; // Backend-provided aspect ratio as string

  const VideoPlayerContainer({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    required this.useBetterPlayer,
    this.thumbnailUrl,
    this.aspectRatio,
  }) : super(key: key);

  @override
  _VideoPlayerContainerState createState() => _VideoPlayerContainerState();
}

class _VideoPlayerContainerState extends State<VideoPlayerContainer> {
  @override
  Widget build(BuildContext context) {
    return BetterPlayerWidget(
      url: widget.url,
      file: widget.file,
      displayPath: widget.displayPath,
      thumbnailUrl: widget.thumbnailUrl,
      aspectRatio: widget.aspectRatio,
    );
  }
}

class BetterPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;
  final String? thumbnailUrl;
  final String? aspectRatio; // Backend-provided aspect ratio as string

  const BetterPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    this.thumbnailUrl,
    this.aspectRatio,
  }) : super(key: key);

  @override
  _BetterPlayerWidgetState createState() => _BetterPlayerWidgetState();
}

class _BetterPlayerWidgetState extends State<BetterPlayerWidget> {
  BetterPlayerController? _betterPlayerController;
  bool _isLoading = true;
  String? _errorMessage;
  double? _videoAspectRatio;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Parse backend-provided aspect ratio string
      if (widget.aspectRatio != null && widget.aspectRatio!.isNotEmpty) {
        final parsedAspectRatio = double.tryParse(widget.aspectRatio!);
        if (parsedAspectRatio != null && parsedAspectRatio.isFinite && parsedAspectRatio > 0) {
          _videoAspectRatio = parsedAspectRatio;
        } else {
          debugPrint('Invalid aspect ratio string from backend: ${widget.aspectRatio}, falling back to player or default');
        }
      }

      final configuration = BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        fit: BoxFit.fitWidth, // Fill device width, adjust height based on aspect ratio
        aspectRatio: _videoAspectRatio ?? 16 / 9, // Use parsed aspect ratio or default
        placeholder: widget.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.fitWidth,
                width: double.infinity,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              )
            : null,
        errorBuilder: (context, errorMessage) => buildError(
          context,
          message: errorMessage ?? 'Error playing video',
          fileName: widget.displayPath.split('/').last,
        ),
      );

      BetterPlayerDataSource dataSource;
      if (widget.url != null && widget.url!.isNotEmpty) {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          widget.url!,
          cacheConfiguration: const BetterPlayerCacheConfiguration(
            useCache: true,
            maxCacheSize: 10 * 1024 * 1024,
            maxCacheFileSize: 10 * 1024 * 1024,
          ),
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

      // If no valid backend aspect ratio, get it from the video player after initialization
      if (_videoAspectRatio == null) {
        _betterPlayerController!.addEventsListener((event) {
          if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
            final videoPlayerController = _betterPlayerController!.videoPlayerController;
            if (videoPlayerController != null && videoPlayerController.value.initialized) {
              double aspectRatio = videoPlayerController.value.aspectRatio;
              if (aspectRatio.isFinite && aspectRatio > 0) {
                if (mounted) {
                  setState(() {
                    _videoAspectRatio = aspectRatio;
                  });
                }
              } else {
                debugPrint('Invalid aspect ratio from video: $aspectRatio, using default 16:9');
                if (mounted) {
                  setState(() {
                    _videoAspectRatio = 16 / 9;
                  });
                }
              }
            }
          }
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize video player: $e';
      });
    }
  }

  @override
  void dispose() {
    _betterPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
    }

    if (_errorMessage != null) {
      return buildError(
        context,
        message: _errorMessage,
        fileName: widget.displayPath.split('/').last,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      child: AspectRatio(
        aspectRatio: _videoAspectRatio ?? 16 / 9,
        child: BetterPlayer(controller: _betterPlayerController!),
      ),
    );
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