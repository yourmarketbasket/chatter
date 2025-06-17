import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart'; // For fallback icons
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart'; // For video playback
import 'package:audioplayers/audioplayers.dart' as audioplayers; // For audio playback with prefix
import 'package:cached_network_image/cached_network_image.dart'; // For cached image loading
import 'package:chatter/widgets/video_player_widget.dart';
import 'package:chatter/widgets/better_player_widget.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart'; // For checking Android version
import 'package:intl/intl.dart'; // For date formatting

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

  // Optimize Cloudinary URL
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

  // Check Android version
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
      appBar: AppBar(
        title: Text(
          widget.attachments.isNotEmpty ? _getPageTitle(widget.attachments[_currentPageIndex]) : "View Post",
          style: GoogleFonts.poppins(color: Colors.white)
        ),
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
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
                final Attachment currentAttachment = widget.attachments[index];
                final String displayPath = currentAttachment.url ?? currentAttachment.file?.path ?? 'Unknown attachment';
                final String optimizedUrl = _optimizeCloudinaryUrl(currentAttachment.url);

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
                          if (snapshot.data!) {
                            return BetterPlayerWidget(
                              url: optimizedUrl.isNotEmpty ? optimizedUrl : currentAttachment.url,
                              file: currentAttachment.file,
                              displayPath: displayPath,
                            );
                          } else {
                            return VideoPlayerWidget(
                              url: optimizedUrl.isNotEmpty ? optimizedUrl : currentAttachment.url,
                              file: currentAttachment.file,
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
                    mediaWidget = AudioPlayerWidget(
                      url: optimizedUrl.isNotEmpty ? optimizedUrl : currentAttachment.url,
                      file: currentAttachment.file,
                      displayPath: displayPath,
                    );
                    break;
                  default:
                    mediaWidget = _buildPlaceholder(
                      context,
                      icon: FeatherIcons.file,
                      message: 'Unsupported attachment type: ${currentAttachment.type}',
                      fileName: displayPath.split('/').last,
                      iconColor: Colors.grey[600],
                    );
                }
                return Center(child: mediaWidget); // Ensure media widget is centered
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: widget.userAvatarUrl != null && widget.userAvatarUrl!.isNotEmpty
                          ? NetworkImage(_optimizeCloudinaryUrl(widget.userAvatarUrl!))
                          : const AssetImage('assets/images/default_avatar.png') as ImageProvider, // Placeholder
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
                const SizedBox(height: 12),
                Divider(color: Colors.grey[700]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSocialButton(FeatherIcons.heart, 'Like', () { /* Like action */ }),
                    _buildSocialButton(FeatherIcons.repeat, 'Repost', () { /* Repost action */ }),
                    _buildSocialButton(FeatherIcons.messageSquare, 'Comment', () { /* Comment action */ }),
                    _buildSocialButton(FeatherIcons.share, 'Share', () { /* Share action */ }),
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
        minimumSize: Size(50, 30), // Adjust size to fit content
      )
    );
  }

  Widget _buildImageViewer(BuildContext context, Attachment attachment, String displayPath, String optimizedUrl) {
    // ... (Keep existing _buildImageViewer logic, but use the passed attachment)
    // Replace `attachment.url` with `currentAttachment.url` etc.
    // For brevity, I'm not fully expanding this here but it needs to be updated
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
                errorWidget: (context, url, error) => _buildError(context, message: 'Error loading image: $error'),
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
                errorBuilder: (context, error, stackTrace) => _buildError(context, message: 'Error loading image file: $error'),
              ),
            ),
          );
        } else {
          return _buildError(context, message: 'No image source available for $displayPath');
        }
      },
    );
  }

  Widget _buildPdfViewer(BuildContext context, Attachment attachment, String displayPath, String optimizedUrl) {
    // ... (Keep existing _buildPdfViewer logic, but use the passed attachment)
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
      return _buildError(context, message: 'No PDF source available for $displayPath');
    }
  }

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