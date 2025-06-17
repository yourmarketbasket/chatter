import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatter/pages/media_view_page.dart'; // For MediaViewPage._buildError
import 'dart:async';
import 'dart:io';

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
      return MediaViewPage._buildError( // This is the line that needs the import for MediaViewPage
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
