import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/models/feed_models.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:flutter/material.dart';
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
  final List<Attachment> attachments;
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

class _MediaViewPageState extends State<MediaViewPage> {
  late PageController _pageController;
  late int _currentPageIndex;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
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
  Future<bool> _isAndroid13OrLower() async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt <= 33;
  }

  String _getPageTitle(Attachment attachment) {
    switch (attachment.type.toLowerCase()) {
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
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SizedBox(height: 20),
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
                final Attachment currentAttachment = widget.attachments[index];
                final String displayPath = currentAttachment.url ?? currentAttachment.file?.path ?? 'Unknown attachment';
                final String optimizedUrl = currentAttachment.type.toLowerCase() == 'video' 
                    ? _optimizeCloudinaryVideoUrl(currentAttachment.url)
                    : _optimizeCloudinaryUrl(currentAttachment.url);

                Widget mediaWidget;
                switch (currentAttachment.type.toLowerCase()) {
                  case 'image':
                    mediaWidget = _buildImageViewer(context, currentAttachment, displayPath, optimizedUrl);
                    break;
                  case 'pdf':
                    mediaWidget = _buildPdfViewer(context, currentAttachment, displayPath, optimizedUrl);
                    break;
                  case 'video':
                    mediaWidget = FutureBuilder<bool>(
                      future: _isAndroid13OrLower(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                          return VideoPlayerContainer(
                            url: optimizedUrl.isNotEmpty ? optimizedUrl : currentAttachment.url,
                            file: currentAttachment.file,
                            displayPath: displayPath,
                            isAndroid13OrLower: snapshot.data!,
                          );
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
                    mediaWidget = AudioPlayerWidget(
                      url: optimizedUrl.isNotEmpty ? optimizedUrl : currentAttachment.url,
                      file: currentAttachment.file,
                      displayPath: displayPath,
                    );
                    break;
                  default:
                    mediaWidget = buildError(
                      context,
                      icon: FeatherIcons.file,
                      message: 'Unsupported attachment type: ${currentAttachment.type}',
                      fileName: displayPath.split('/').last,
                      iconColor: Colors.grey[600],
                    );
                }
                return Center(child: mediaWidget);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: widget.userAvatarUrl != null && widget.userAvatarUrl!.isNotEmpty
                          ? NetworkImage(_optimizeCloudinaryUrl(widget.userAvatarUrl!))
                          : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.userName,
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM d, yyyy \'at\' hh:mm a').format(widget.timestamp),
                  style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('${widget.viewsCount} Views', style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(width: 16),
                    Text('${widget.likesCount} Likes', style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(width: 16),
                    Text('${widget.repostsCount} Reposts', style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildImageViewer(BuildContext context, Attachment attachment, String displayPath, String optimizedUrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final String currentOptimizedUrl = _optimizeCloudinaryUrl(attachment.url);
        if (currentOptimizedUrl.isNotEmpty) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: currentOptimizedUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Center(child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent), backgroundColor: Colors.grey)),
                errorWidget: (context, url, error) => buildError(context, message: 'Error loading image: $error'),
                cacheKey: attachment.url,
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
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => buildError(context, message: 'Error loading image file: $error'),
              ),
            ),
          );
        } else {
          return buildError(context, message: 'No image source available for $displayPath');
        }
      },
    );
  }

  Widget _buildPdfViewer(BuildContext context, Attachment attachment, String displayPath, String optimizedUrl) {
    final String currentOptimizedUrl = _optimizeCloudinaryUrl(attachment.url);
    if (currentOptimizedUrl.isNotEmpty || attachment.file != null) {
      final Uri pdfUri = currentOptimizedUrl.isNotEmpty
          ? Uri.parse(currentOptimizedUrl)
          : Uri.file(attachment.file!.path);
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
  final bool isAndroid13OrLower;

  const VideoPlayerContainer({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    required this.isAndroid13OrLower,
  }) : super(key: key);

  @override
  _VideoPlayerContainerState createState() => _VideoPlayerContainerState();
}

class _VideoPlayerContainerState extends State<VideoPlayerContainer> {
  BetterPlayerController? betterPlayerController;
  VideoPlayerController? videoPlayerController;
  bool _isLoading = true;
  String? _errorMessage;
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isAndroid13OrLower) {
        // Configure BetterPlayer for older Android versions
        final betterPlayerDataSource = widget.url != null
            ? BetterPlayerDataSource(
                BetterPlayerDataSourceType.network,
                widget.url!,
                cacheConfiguration: BetterPlayerCacheConfiguration(
                  useCache: true,
                  preCacheSize: 10 * 1024 * 1024,
                  maxCacheSize: 100 * 1024 * 1024,
                  maxCacheFileSize: 10 * 1024 * 1024,
                ),
                bufferingConfiguration: BetterPlayerBufferingConfiguration(
                  minBufferMs: 5000,
                  maxBufferMs: 15000,
                  bufferForPlaybackMs: 2500,
                  bufferForPlaybackAfterRebufferMs: 5000,
                ),
                resolutions: {
                  'low': widget.url!.replaceAll('q_auto:good', 'q_auto:low'),
                  'medium': widget.url!,
                  'high': widget.url!.replaceAll('q_auto:good', 'q_auto:best'),
                },
              )
            : BetterPlayerDataSource(
                BetterPlayerDataSourceType.file,
                widget.file!.path,
              );

        betterPlayerController = BetterPlayerController(
          BetterPlayerConfiguration(
            autoPlay: false,
            fit: BoxFit.contain,
            errorBuilder: (context, errorMessage) => buildError(context, message: errorMessage ?? 'Video playback error'),
            controlsConfiguration: BetterPlayerControlsConfiguration(
              enableSkips: false,
              enableFullscreen: true,
              enablePip: true,
              enableQualities: widget.url != null,
              loadingWidget: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              ),
            ),
          ),
          betterPlayerDataSource: betterPlayerDataSource,
        );

        // Preload video
        await betterPlayerController?.preCache(betterPlayerDataSource);
      } else {
        // Configure VideoPlayer for newer Android versions
        videoPlayerController = widget.url != null
            ? VideoPlayerController.networkUrl(Uri.parse(widget.url!))
            : VideoPlayerController.file(widget.file!);

        await videoPlayerController!.initialize();
        videoPlayerController!.setLooping(true);
        
        // Monitor buffer health
        videoPlayerController!.addListener(() {
          final buffered = videoPlayerController!.value.buffered;
          if (buffered.isNotEmpty && mounted) {
            final bufferDuration = buffered.last.end - buffered.last.start;
            if (bufferDuration.inSeconds < 5 && videoPlayerController!.value.isPlaying) {
              videoPlayerController!.pause();
              Future.delayed(Duration(seconds: 2), () {
                if (mounted && videoPlayerController!.value.buffered.last.end.inSeconds > 10) {
                  videoPlayerController!.play();
                }
              });
            }
          }
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        return _initializeVideoPlayer();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load video after $_maxRetries attempts: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    betterPlayerController?.dispose();
    videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
        ),
      );
    }

    if (_errorMessage != null) {
      return buildError(context, message: _errorMessage!);
    }

    return widget.isAndroid13OrLower
        ? BetterPlayerWidget(
            url: widget.url,
            file: widget.file,
            displayPath: widget.displayPath,
          )
        : VideoPlayerWidget(
            url: widget.url,
            file: widget.file,
            displayPath: widget.displayPath,
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