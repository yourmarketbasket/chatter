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
  StreamSubscription? _isTransitioningVideoSubscription; // For seamless transition

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

    // Simplified: Always initialize its own player. No controller passing.
    _initializeVideoPlayer();

    _currentlyPlayingVideoSubscription = _dataController.currentlyPlayingVideoId.listen((playingId) {
      if (_controller != null && _controller!.value.isInitialized && _controller!.value.isPlaying) {
        if (playingId != null && playingId != _videoUniqueId) {
          _controller!.pause();
        }
      }
    });

    // This subscription is to pause this feed player if MediaViewPage starts playing *this* video.
    // It assumes MediaViewPage sets isTransitioningVideo=true and activeFeedPlayerVideoId correctly.
    if (widget.isFeedContext) {
      _isTransitioningVideoSubscription = _dataController.isTransitioningVideo.listen((isTransitioning) {
        if (isTransitioning && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
          if (_controller != null && _controller!.value.isInitialized && _controller!.value.isPlaying) {
            _controller!.pause();
            print("VideoPlayerWidget ($_videoUniqueId in feed) paused because it's transitioning to MediaViewPage.");
          }
        }
      });
    }
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
        _dataController.videoDidStartPlaying(_videoUniqueId!);
        // No longer setting activeFeedPlayerController in DataController
      } else if (!newIsPlayingState && _isPlaying) { // Just paused or finished
        _dataController.videoDidStopPlaying(_videoUniqueId!);
      }
      _isPlaying = newIsPlayingState;
      changed = true;
    }

    // If in feed and playing, update position in DataController for potential transition start point.
    if (widget.isFeedContext && _isPlaying) {
      _dataController.activeFeedPlayerPosition.value = _position;
      _dataController.activeFeedPlayerVideoId.value = _videoUniqueId; // Keep track of which video's pos this is
    }

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
    // Removed logic for adopting a controller from DataController.
    // This widget now always creates its own.

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showControls = true; // Default to showing controls on new init
      _animationController.forward(); // Animate controls in
    });

    // Dispose any existing controller before creating a new one
    // This handles cases like re-initialization after being disposed by VisibilityDetector
    if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
        _isInitialized = false;
         print("VideoPlayerWidget ($_videoUniqueId) disposed existing controller before re-initializing.");
    }

    try {
      if (widget.url != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.url!),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true, // Important for lists
            allowBackgroundPlayback: false,
          ),
          httpHeaders: {
            'Cache-Control': 'max-age=604800', // Example caching header
          },
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

      // Check if we need to start at a specific position (e.g., when used in MediaViewPage after transition)
      Duration? startAt;
      if (!widget.isFeedContext && // Only apply startAt if NOT in feed (i.e., likely in MediaViewPage)
          _dataController.isTransitioningVideo.value &&
          _dataController.activeFeedPlayerVideoId.value == widget.url) {
          startAt = _dataController.activeFeedPlayerPosition.value;
          print("VideoPlayerWidget ($_videoUniqueId in MediaViewPage) initializing with startAt: $startAt");
      }


      await _controller!.initialize();
      if (startAt != null) {
          await _controller!.seekTo(startAt);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
          _duration = _controller!.value.duration;
        });
        _controller!.addListener(_onControllerUpdate);
        // If not in feed context (e.g. MediaViewPage) and was meant to transition, auto-play.
        if (!widget.isFeedContext && _dataController.isTransitioningVideo.value && _dataController.activeFeedPlayerVideoId.value == widget.url) {
            _controller!.play();
        }

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
    _currentlyPlayingVideoSubscription?.cancel();
    _isTransitioningVideoSubscription?.cancel();
    _controller?.removeListener(_onControllerUpdate);

    // Simplified dispose: always dispose its own controller.
    _controller?.dispose();
    print("VideoPlayerWidget ($_videoUniqueId) disposed controller.");

    // Clear DataController state if this was the active feed player and it's not part of an active transition
    // This part might be redundant if MediaViewPage's dispose handles clearing transition state robustly.
    // Or, if another video in feed starts playing, it will overwrite activeFeedPlayerVideoId.
    if (widget.isFeedContext &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
        !_dataController.isTransitioningVideo.value) { // Ensure not in an active transition FOR THIS VIDEO
      // If this video was the last one providing position/ID to DataController, clear it.
      // _dataController.activeFeedPlayerVideoId.value = null;
      // _dataController.activeFeedPlayerPosition.value = null;
      // Not clearing activeFeedPlayerController as it's already removed from DataController state.
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
