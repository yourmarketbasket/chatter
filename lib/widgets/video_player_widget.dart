import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatter/pages/media_view_page.dart'; // For MediaViewPage._buildError
import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';

// Widget for video playback with seeking and progress bar using video_player
class VideoPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;
  final String? thumbnailUrl;
  final bool isFeedContext; // Added to identify if this player is in the home feed

  const VideoPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    this.thumbnailUrl,
    this.isFeedContext = false, // Default to false
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

  // For single video playback
  final DataController _dataController = Get.find<DataController>();
  String? _videoUniqueId;
  StreamSubscription? _currentlyPlayingVideoSubscription;
  // StreamSubscription? _isTransitioningVideoSubscription; // Removed

  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.url ?? widget.file?.path ?? widget.key.toString();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeVideoPlayer(); // Always initialize fresh

    _currentlyPlayingVideoSubscription = _dataController.currentlyPlayingMediaId.listen((playingId) {
      // Only enforce single video playback in feed context
      if (widget.isFeedContext &&
          _controller != null &&
          _controller!.value.isInitialized &&
          _controller!.value.isPlaying) {
        if (playingId != null &&
            playingId != _videoUniqueId &&
            _dataController.currentlyPlayingMediaType.value == 'video') {
          _controller!.pause();
        }
      }
    });
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    final newPosition = _controller!.value.position;
    final newIsPlayingState = _controller!.value.isPlaying;
    bool changed = false;

    if (_position != newPosition) {
      _position = newPosition;
      changed = true;
    }

    if (_isPlaying != newIsPlayingState) {
      if (newIsPlayingState && !_isPlaying) { // Just started playing
        _dataController.mediaDidStartPlaying(_videoUniqueId!, 'video', _controller!);
      } else if (!newIsPlayingState && _isPlaying) { // Just paused or finished
        _dataController.mediaDidStopPlaying(_videoUniqueId!, 'video');
      }
      _isPlaying = newIsPlayingState;
      changed = true;
    }

    // Show controls when video stops
    if (!_isPlaying && !_showControls) {
      _showControls = true;
      _animationController.forward();
      changed = true;
    }

    if (changed) {
      setState(() {});
    }
  }


  Future<void> _initializeVideoPlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showControls = true;
      _animationController.forward();
    });

    try {
      if (widget.url != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.url!),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
          // httpHeaders: { // Caching disabled
          //   'Cache-Control': 'no-cache', // Explicitly disable cache if needed
          // },
        );
      } else if (widget.file != null) {
        _controller = VideoPlayerController.file(widget.file!);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitialized = false;
            _errorMessage = 'No video source available';
          });
        }
        return;
      }

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
          _duration = _controller!.value.duration;
        });
        _controller!.addListener(_onControllerUpdate); // Add consolidated listener
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
    _currentlyPlayingVideoSubscription?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();

    // If this video was playing, ensure DataController is updated
    if (_isPlaying) {
      _dataController.mediaDidStopPlaying(_videoUniqueId!, 'video');
    }

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
            if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.contain, // Or BoxFit.cover, depending on desired behavior
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                    strokeWidth: 2,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.error_outline, color: Colors.grey, size: 40),
                  ),
                ),
              )
            else
              Container(color: Colors.black), // Fallback if no thumbnail URL

            // Always show a progress indicator on top if still loading,
            // or remove if thumbnail itself has an indicator.
            // For this setup, CachedNetworkImage's placeholder handles it.
            // If no thumbnail, then a direct progress indicator is good.
            if (widget.thumbnailUrl == null || widget.thumbnailUrl!.isEmpty)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                backgroundColor: Colors.transparent, // Make background transparent
                strokeWidth: 2,
              ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null || _errorMessage != null) {
      print('Error: $_errorMessage');
      return Center(
        child: Text(
          _errorMessage ?? 'Video player not initialized',
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
