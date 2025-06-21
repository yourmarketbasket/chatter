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

    // Check if this player should resume from a transitioning state
    if (widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
        _dataController.activeFeedPlayerController.value is VideoPlayerController) {
      // This feed player is returning from MediaViewPage
      _controller = _dataController.activeFeedPlayerController.value as VideoPlayerController?;
      if (_controller != null) {
        _isInitialized = true;
        _isLoading = false;
        _duration = _controller!.value.duration;
        _position = _controller!.value.position;
        _isPlaying = _controller!.value.isPlaying;
        _showControls = true;
        _animationController.forward();
        _controller!.addListener(_onControllerUpdate); // Add consolidated listener
        // Important: Clear the transitioning state as we've reclaimed the controller
        _dataController.isTransitioningVideo.value = false;
         // Ensure it plays if it was playing
        if (_isPlaying) {
          _controller!.play();
           // _onControllerUpdate will handle DataController updates for playing state
        }
      } else {
        _initializeVideoPlayer(); // Fallback if controller is null
      }
    } else {
      _initializeVideoPlayer();
    }

    _currentlyPlayingVideoSubscription = _dataController.activeFeedPlayerVideoId.listen((playingId) {
      if (_controller != null && _controller!.value.isInitialized && _controller!.value.isPlaying) {
        if (playingId != null && playingId != _videoUniqueId) {
          _controller!.pause();
          // _isPlaying will be updated by _onControllerUpdate
        }
      }
    });

    if (widget.isFeedContext) {
      _isTransitioningVideoSubscription = _dataController.isTransitioningVideo.listen((isTransitioning) {
        if (isTransitioning && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
          // If this video is transitioning to MediaViewPage, ensure its state is captured
           if (_controller != null && _controller!.value.isInitialized) {
            _dataController.activeFeedPlayerPosition.value = _controller!.value.position;
            // The controller itself is passed, so its playing state is inherent.
            // No need to pause here, MediaViewPage will decide to play/pause.
            // However, if it *was* playing, ensure DataController knows this.
            if (_controller!.value.isPlaying) {
                 _dataController.activeFeedPlayerController.value = _controller; // Ensure controller is in DC
                 _dataController.activeFeedPlayerVideoId.value = _videoUniqueId; // Ensure ID is in DC
            }
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
        if (widget.isFeedContext) { // Update active player only if in feed and starts playing
          _dataController.activeFeedPlayerController.value = _controller;
          _dataController.activeFeedPlayerVideoId.value = _videoUniqueId;
        }
      } else if (!newIsPlayingState && _isPlaying) { // Just paused or finished
        _dataController.videoDidStopPlaying(_videoUniqueId!);
        // If in feed, and this video stops, and it's not being transitioned, clear it from DataController
        // This part is tricky: if another video starts, currentlyPlayingVideoId will change,
        // and that video's listener will set activeFeedPlayerController.
        // Clearing here might be redundant or conflict.
        // Let's rely on dispose and new video playing to manage activeFeedPlayerController.
      }
      _isPlaying = newIsPlayingState;
      changed = true;
    }

    // If in feed and playing, always update position for potential transition
    if (widget.isFeedContext && _isPlaying) {
      _dataController.activeFeedPlayerPosition.value = _position;
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
    // Check if we are using a controller passed from DataController (for MediaViewPage)
    if (_dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
        _dataController.activeFeedPlayerController.value is VideoPlayerController &&
        !widget.isFeedContext) { // This condition is for MediaViewPage using feed's controller

      _controller = _dataController.activeFeedPlayerController.value as VideoPlayerController;
      // The controller is already initialized and likely playing.
      // We just need to update local state and attach listeners.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
          _duration = _controller!.value.duration;
          _position = _controller!.value.position;
          _isPlaying = _controller!.value.isPlaying;
          _showControls = true;
          _animationController.forward();
        });
        _controller!.addListener(_onControllerUpdate); // Add consolidated listener

        // If MediaViewPage is taking controller, ensure it seeks and plays if needed
        if (_dataController.activeFeedPlayerPosition.value != null) {
          _controller!.seekTo(_dataController.activeFeedPlayerPosition.value!);
        }
        // The _onControllerUpdate listener will now manage _isPlaying and DataController updates.
        // If the controller's internal state is already "playing", _onControllerUpdate will reflect that.
        // If it needs an explicit play() call:
        bool wasPlaying = (_dataController.activeFeedPlayerController.value as VideoPlayerController?)?.value.isPlaying ?? false; // Example check
        // A more robust way might be to store 'isPlaying' in DataController during transition start.
        // For now, let's assume if controller is passed, its state is preserved.
        // If _controller was playing (from feed), and it's the same instance, it should continue.
        // If a new controller was somehow created for MediaViewPage (not ideal for seamless), then play if needed.
        // The current logic reuses the controller instance, so its state should persist.

         // MediaViewPage should NOT set isTransitioningVideo to false here.
         // It remains true while MediaViewPage has control.
      }
      return;
    }

    // Standard initialization
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
          httpHeaders: {
            'Cache-Control': 'max-age=604800',
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
    _isTransitioningVideoSubscription?.cancel();

    _controller?.removeListener(_onControllerUpdate); // Remove the consolidated listener

    // Conditional disposal for seamless transition
    if (widget.isFeedContext &&
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
      // This feed player's controller is being handed over to MediaViewPage.
      // Do NOT dispose the _controller here.
      print("VideoPlayerWidget ($_videoUniqueId in feed) NOT disposing controller due to transition.");
    } else if (!widget.isFeedContext &&
               _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
               _dataController.activeFeedPlayerController.value == _controller ) {
      // This player (in MediaViewPage) was using a controller from the feed.
      // Do NOT dispose it here. It will be reclaimed by the feed player.
      print("VideoPlayerWidget ($_videoUniqueId in MediaViewPage) NOT disposing shared controller.");
      // When MediaViewPage is closed (widget is disposed), signal that the transition is over.
      if (_dataController.isTransitioningVideo.value && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
        // Update DataController with the final position from MediaViewPage
        if (_controller != null && _controller!.value.isInitialized) {
           _dataController.activeFeedPlayerPosition.value = _controller!.value.position;
        }
        _dataController.isTransitioningVideo.value = false; // Signal end of transition
        print("VideoPlayerWidget ($_videoUniqueId in MediaViewPage) signalling end of transition.");
      }
    }
     else {
      // Standard disposal logic if not part of an active transition
      _controller?.dispose();
      print("VideoPlayerWidget ($_videoUniqueId) normally disposing controller.");
      // If this was the active feed player and it's disposed normally (not transitioning out)
      // and it's indeed THIS controller that's active (e.g. another video didn't take over)
      if (widget.isFeedContext &&
          _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
          !_dataController.isTransitioningVideo.value) { // Ensure not transitioning
          _dataController.activeFeedPlayerController.value = null;
          _dataController.activeFeedPlayerVideoId.value = null;
          _dataController.activeFeedPlayerPosition.value = null;
      }
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
