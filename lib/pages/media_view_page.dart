import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart'; // For fallback icons
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart'; // For video playback
import 'package:audioplayers/audioplayers.dart' as audioplayers; // For audio playback with prefix
import 'package:cached_network_image/cached_network_image.dart'; // For cached image loading
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart'; // For checking Android version

// MediaViewPage displays an attachment (image, PDF, video, or audio) in a full-screen view.
class MediaViewPage extends StatelessWidget {
  final Attachment attachment;

  const MediaViewPage({Key? key, required this.attachment}) : super(key: key);

  // Optimize Cloudinary URL for faster loading without breaking the path
  String _optimizeCloudinaryUrl(String url) {
    if (!url.contains('cloudinary.com')) return url;
    final uri = Uri.parse(url);
    // Append quality and format optimizations as query parameters
    final optimizedUrl = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'q': 'auto',
      'f': 'auto',
    });
    return optimizedUrl.toString();
  }

  // Check if the device is running Android 13 or lower
  Future<bool> _isAndroid13OrLower() async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt <= 33; // API level 33 is Android 13
  }

  @override
  Widget build(BuildContext context) {
    // Determine the display widget and page title based on attachment type
    String pageTitle;
    Widget mediaWidget;

    // Safely get the display path for error messages or placeholders
    final String displayPath = attachment.url ?? attachment.file?.path ?? 'Unknown attachment';
    final String optimizedUrl = attachment.url != null ? _optimizeCloudinaryUrl(attachment.url!) : '';

    switch (attachment.type.toLowerCase()) {
      case 'image':
        pageTitle = 'View Image';
        mediaWidget = _buildImageViewer(context, displayPath, optimizedUrl);
        break;
      case 'pdf':
        pageTitle = 'View PDF';
        mediaWidget = _buildPdfViewer(context, displayPath, optimizedUrl);
        break;
      case 'video':
        pageTitle = 'View Video';
        mediaWidget = FutureBuilder<bool>(
          future: _isAndroid13OrLower(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
              if (snapshot.data!) {
                // Use BetterPlayer for Android 13 and lower
                return BetterPlayerWidget(
                  url: optimizedUrl.isNotEmpty ? optimizedUrl : attachment.url,
                  file: attachment.file,
                  displayPath: displayPath,
                );
              } else {
                // Use VideoPlayer for Android 14 and higher
                return VideoPlayerWidget(
                  url: optimizedUrl.isNotEmpty ? optimizedUrl : attachment.url,
                  file: attachment.file,
                  displayPath: displayPath,
                );
              }
            }
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              ),
            );
          },
        );
        break;
      case 'audio':
        pageTitle = 'View Audio';
        mediaWidget = AudioPlayerWidget(
          url: optimizedUrl.isNotEmpty ? optimizedUrl : attachment.url,
          file: attachment.file,
          displayPath: displayPath,
        );
        break;
      default:
        pageTitle = 'View Attachment';
        mediaWidget = _buildPlaceholder(
          context,
          icon: FeatherIcons.file,
          message: 'Unsupported attachment type: ${attachment.type}',
          fileName: displayPath.split('/').last,
          iconColor: Colors.grey[600],
        );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(pageTitle, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: mediaWidget),
        ],
      ),
    );
  }

  // Builds an image viewer for network or local images with full-screen pinch-to-zoom and caching
  Widget _buildImageViewer(BuildContext context, String displayPath, String optimizedUrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (optimizedUrl.isNotEmpty || attachment.url != null) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: optimizedUrl.isNotEmpty ? optimizedUrl : attachment.url!,
                fit: BoxFit.contain, // Maintains original aspect ratio
                placeholder: (context, url) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LinearProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                        backgroundColor: Colors.grey,
                      ),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) => _buildError(
                  context,
                  message: 'Error loading image: $error',
                ),
                cacheKey: attachment.url, // Use the original URL as the cache key
              ),
            ),
          );
        } else if (attachment.file != null) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.file(
                attachment.file!,
                fit: BoxFit.contain, // Maintains original aspect ratio
                errorBuilder: (context, error, stackTrace) => _buildError(
                  context,
                  message: 'Error loading image file: $error',
                ),
              ),
            ),
          );
        } else {
          return _buildError(
            context,
            message: 'No image source available for $displayPath',
          );
        }
      },
    );
  }

  // Builds a PDF viewer for network or local PDFs
  Widget _buildPdfViewer(BuildContext context, String displayPath, String optimizedUrl) {
    if (optimizedUrl.isNotEmpty || attachment.url != null || attachment.file != null) {
      final Uri pdfUri = optimizedUrl.isNotEmpty
          ? Uri.parse(optimizedUrl)
          : attachment.url != null
              ? Uri.parse(attachment.url!)
              : Uri.file(attachment.file!.path);
      return PdfViewer.uri(
        pdfUri,
        params: const PdfViewerParams(
          margin: 0, // Fits PDF to screen while maintaining aspect ratio
          backgroundColor: Colors.transparent,
          maxScale: 2.0,
          minScale: 0.5,
        ),
      );
    } else {
      return _buildError(
        context,
        message: 'No PDF source available for $displayPath',
      );
    }
  }

  // Builds a generic error widget for failed media loading
  static Widget _buildError(BuildContext context, {required String message}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          FeatherIcons.alertTriangle,
          color: Colors.redAccent,
          size: 50,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: GoogleFonts.roboto(
            color: Colors.white70,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Builds a placeholder for unsupported or unimplemented media types
  Widget _buildPlaceholder(
    BuildContext context, {
    required IconData icon,
    required String message,
    required String fileName,
    Color? iconColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: iconColor ?? Colors.tealAccent,
          size: 100,
        ),
        const SizedBox(height: 20),
        Text(
          message,
          style: GoogleFonts.roboto(
            color: Colors.white70,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
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
    );
  }
}

// Widget for video playback with seeking and progress bar using video_player
class VideoPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;

  const VideoPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isPlaying = false;
  int _retryCount = 0;
  final int _maxRetries = 3;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _showControls = true; // Controls visibility state
  Timer? _hideControlsTimer; // Timer to auto-hide controls
  late AnimationController _animationController; // For fade animation
  late Animation<double> _fadeAnimation; // Fade animation for controls

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for fade effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Smooth fade duration
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showControls = true; // Show controls initially
      _animationController.forward(); // Ensure controls are visible at start
    });

    try {
      if (widget.url != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.url!),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
          httpHeaders: {
            'Cache-Control': 'max-age=604800', // Cache videos for 7 days
          },
        );
      } else if (widget.file != null) {
        _controller = VideoPlayerController.file(widget.file!);
      } else {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
          _errorMessage = 'No video source available';
        });
        return;
      }

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
          _duration = _controller!.value.duration;
        });

        _controller!.addListener(() {
          if (mounted) {
            setState(() {
              _position = _controller!.value.position;
              _isPlaying = _controller!.value.isPlaying;
              // Show controls when video stops
              if (!_isPlaying && !_showControls) {
                _showControls = true;
                _animationController.forward();
              }
            });
          }
        });
      }
    } catch (e) {
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        return _initializeVideoPlayer();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitialized = false;
            _errorMessage = 'Failed to load video after $_maxRetries attempts: $e';
          });
        }
      }
    }
  }

  void _seekToPosition(double value) {
    final position = _duration * value;
    _controller?.seekTo(position);
  }

  // Toggle controls visibility on tap
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _animationController.forward();
        // Start timer to hide controls after 3 seconds if playing
        if (_isPlaying) {
          _hideControlsTimer?.cancel();
          _hideControlsTimer = Timer(const Duration(seconds: 3), () {
            if (mounted && _isPlaying) {
              setState(() {
                _showControls = false;
                _animationController.reverse();
              });
            }
          });
        }
      } else {
        _animationController.reverse();
        _hideControlsTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _hideControlsTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Display thumbnail if available
            widget.url != null
                ? CachedNetworkImage(
                    imageUrl: widget.url!.replaceAll(RegExp(r'\.\w+$'), '.jpg'),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.black),
                    errorWidget: (context, url, error) => Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              backgroundColor: Colors.grey,
              strokeWidth: 1,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null || _errorMessage != null) {
      return MediaViewPage._buildError(
        context,
        message: _errorMessage ?? 'Error loading video: ${widget.displayPath}',
      );
    }

    return Center(
      child: GestureDetector(
        onTap: _toggleControls, // Toggle controls on tap
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: _fadeAnimation.value,
                duration: const Duration(milliseconds: 300),
                child: _showControls
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: const BoxDecoration(
                          color: Colors.transparent, // Transparent background
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.tealAccent,
                                size: 30,
                              ),
                              onPressed: _isInitialized
                                  ? () async {
                                      if (_isPlaying) {
                                        await _controller!.pause();
                                      } else {
                                        await _controller!.play();
                                        // Hide controls after 3 seconds if playing
                                        setState(() {
                                          _showControls = true;
                                          _animationController.forward();
                                        });
                                        _hideControlsTimer?.cancel();
                                        _hideControlsTimer = Timer(const Duration(seconds: 3), () {
                                          if (mounted && _isPlaying) {
                                            setState(() {
                                              _showControls = false;
                                              _animationController.reverse();
                                            });
                                          }
                                        });
                                      }
                                      setState(() {});
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(_position),
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Slider(
                                value: _duration.inMilliseconds > 0
                                    ? _position.inMilliseconds / _duration.inMilliseconds
                                    : 0.0,
                                onChanged: _isInitialized ? (value) => _seekToPosition(value) : null,
                                activeColor: Colors.tealAccent,
                                inactiveColor: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_duration),
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
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

// Widget for video playback using better_player for Android 13 and lower
class BetterPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;

  const BetterPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
  }) : super(key: key);

  @override
  _BetterPlayerWidgetState createState() => _BetterPlayerWidgetState();
}

class _BetterPlayerWidgetState extends State<BetterPlayerWidget> with SingleTickerProviderStateMixin {
  BetterPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isPlaying = false;
  int _retryCount = 0;
  final int _maxRetries = 3;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  double? _aspectRatio; // No default aspect ratio

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showControls = true;
      _animationController.forward();
    });

    try {
      BetterPlayerDataSource dataSource;
      if (widget.url != null) {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          widget.url!,
          cacheConfiguration: const BetterPlayerCacheConfiguration(
            useCache: true,
            maxCacheSize: 100 * 1024 * 1024, // 100 MB
            maxCacheFileSize: 10 * 1024 * 1024, // 10 MB per file
          ),
          headers: {
            'Cache-Control': 'max-age=604800', // Cache videos for 7 days
          },
        );
      } else if (widget.file != null) {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.file,
          widget.file!.path,
        );
      } else {
        setState(() {
          _isLoading = false;
          _isInitialized = false;
          _errorMessage = 'No video source available';
        });
        return;
      }

      _controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: false,
          looping: false,
          fit: BoxFit.contain,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControls: false, // We'll use custom controls
          ),
          handleLifecycle: true,
          autoDispose: true,
        ),
        betterPlayerDataSource: dataSource,
      );

      await _controller!.setupDataSource(dataSource);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
          _duration = _controller!.videoPlayerController!.value.duration ?? Duration.zero;
          _aspectRatio = _controller!.videoPlayerController!.value.aspectRatio;
        });

        _controller!.addEventsListener((event) {
          if (mounted) {
            setState(() {
              if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
                _position = event.parameters?['progress'] ?? _position;
              }
              _isPlaying = _controller!.isPlaying() ?? false;
              _duration = _controller!.videoPlayerController!.value.duration ?? _duration;
              _aspectRatio = _controller!.videoPlayerController!.value.aspectRatio ?? _aspectRatio;
              if (!_isPlaying && !_showControls) {
                _showControls = true;
                _animationController.forward();
              }
            });
          }
        });
      }
    } catch (e) {
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        return _initializeVideoPlayer();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitialized = false;
            _errorMessage = 'Failed to load video after $_maxRetries attempts: $e';
          });
        }
      }
    }
  }

  void _seekToPosition(double value) {
    final position = _duration * value;
    _controller?.seekTo(position);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _animationController.forward();
        if (_isPlaying) {
          _hideControlsTimer?.cancel();
          _hideControlsTimer = Timer(const Duration(seconds: 3), () {
            if (mounted && _isPlaying) {
              setState(() {
                _showControls = false;
                _animationController.reverse();
              });
            }
          });
        }
      } else {
        _animationController.reverse();
        _hideControlsTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _hideControlsTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            widget.url != null
                ? CachedNetworkImage(
                    imageUrl: widget.url!.replaceAll(RegExp(r'\.\w+$'), '.jpg'),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.black),
                    errorWidget: (context, url, error) => Container(color: Colors.black),
                  )
                : Container(color: Colors.black),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              backgroundColor: Colors.grey,
              strokeWidth: 1,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null || _errorMessage != null) {
      return MediaViewPage._buildError(
        context,
        message: _errorMessage ?? 'Error loading video: ${widget.displayPath}',
      );
    }

    if (_aspectRatio == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          backgroundColor: Colors.grey,
          strokeWidth:   1,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth, // Use full available width
                  maxHeight: constraints.maxHeight,
                ),
                child: AspectRatio(
                  aspectRatio: _aspectRatio!,
                  child: BetterPlayer(controller: _controller!),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: _fadeAnimation.value,
                  duration: const Duration(milliseconds: 300),
                  child: _showControls
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.tealAccent,
                                  size: 30,
                                ),
                                onPressed: _isInitialized
                                    ? () async {
                                        if (_isPlaying) {
                                          await _controller!.pause();
                                        } else {
                                          await _controller!.play();
                                          setState(() {
                                            _showControls = true;
                                            _animationController.forward();
                                          });
                                          _hideControlsTimer?.cancel();
                                          _hideControlsTimer = Timer(const Duration(seconds: 3), () {
                                            if (mounted && _isPlaying) {
                                              setState(() {
                                                _showControls = false;
                                                _animationController.reverse();
                                              });
                                            }
                                          });
                                        }
                                        setState(() {});
                                      }
                                    : null,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(_position),
                                style: GoogleFonts.roboto(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Slider(
                                  value: _duration.inMilliseconds > 0
                                      ? _position.inMilliseconds / _duration.inMilliseconds
                                      : 0.0,
                                  onChanged: _isInitialized ? (value) => _seekToPosition(value) : null,
                                  activeColor: Colors.tealAccent,
                                  inactiveColor: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_duration),
                                style: GoogleFonts.roboto(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        );
      },
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

      // Set the audio source and wait for completion
      await _audioPlayer.setSource(audioSource);

      // Get duration after setting source
      final duration = await _audioPlayer.getDuration();
      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
        });
        // Initialize waveform with duration
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
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitialized = false;
            _errorMessage = 'Failed to load audio after $_maxRetries attempts: $e';
          });
        }
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
            LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              backgroundColor: Colors.grey,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _errorMessage != null) {
      return MediaViewPage._buildError(
        context,
        message: _errorMessage ?? 'Error loading audio: ${widget.displayPath}',
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
        const SizedBox(height: 20),
        Text(
          widget.displayPath.split('/').last,
          style: GoogleFonts.roboto(
            color: Colors.white70,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 20),
        CustomWaveform(
          controller: _waveformController,
          animationController: _animationController,
          height: 100,
          width: MediaQuery.of(context).size.width - 40,
        ),
        const SizedBox(height: 20),
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

// Controller for managing waveform data and animation
class WaveformPlayerController {
  List<double> _waveformData = [];
  double _progress = 0.0;

  Future<void> prepareWaveform(String path, Duration duration) async {
    // Generate dynamic waveform data simulating pitch and amplitude
    const sampleCount = 200; // Increased samples for smoother waveform
    final random = Random();
    _waveformData = List.generate(sampleCount, (index) {
      // Simulate amplitude (volume) with random variations
      final amplitude = 0.3 + random.nextDouble() * 0.5;
      // Simulate pitch (frequency) with a sine wave
      final frequency = 1.0 + random.nextDouble() * 4.0; // Vary frequency for pitch effect
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

// Custom waveform widget using CustomPaint
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

// Painter for drawing the waveform
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

      // Draw played portion in active color, unplayed in gray
      canvas.drawRect(rect, i <= progressIndex ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}