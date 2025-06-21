import 'package:flutter/material.dart';
import 'package:better_player_enhanced/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';

// Widget for video playback using better_player for Android 13 and lower
class BetterPlayerWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final String displayPath;
  final String? thumbnailUrl;
  final bool isFeedContext; // Added to identify if this player is in the home feed
  final Duration? startAt; // New parameter to start playback at a specific position

  const BetterPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    this.thumbnailUrl,
    this.isFeedContext = false, // Default to false
    this.startAt, // New parameter
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

  final DataController _dataController = Get.find<DataController>();
  String? _videoUniqueId;
  StreamSubscription? _currentlyPlayingVideoSubscription;
  StreamSubscription? _isTransitioningVideoSubscription;
  void Function(BetterPlayerEvent)? _eventListener;


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

    // Simplified initState: Always initialize its own player. No controller passing.
    _initializeVideoPlayer();

    _currentlyPlayingVideoSubscription = _dataController.currentlyPlayingVideoId.listen((playingId) {
      if (_controller != null && (_controller!.isPlaying() ?? false)) {
        if (playingId != null && playingId != _videoUniqueId) {
          _controller!.pause();
          // _isPlaying state will be updated by the event listener
        }
      }
    });

    // If in feed, listen for transition signals to pause itself if it's the video being transitioned.
    if (widget.isFeedContext) {
      _isTransitioningVideoSubscription = _dataController.isTransitioningVideo.listen((isTransitioning) {
        if (isTransitioning && _dataController.activeFeedPlayerVideoId.value == _videoUniqueId) {
          if (_controller != null && (_controller!.isPlaying() ?? false)) {
            _controller!.pause();
            print("BetterPlayerWidget ($_videoUniqueId in feed) paused because it's transitioning to MediaViewPage.");
          }
        }
      });
    }
  }

  void _attachListeners() {
    _eventListener = (event) {
      if (mounted) {
        bool changed = false;
        if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
          final newPosition = event.parameters?['progress'] as Duration? ?? _position;
          if (_position != newPosition) {
            _position = newPosition;
            changed = true;
          }
        }

        final newIsPlayingState = _controller?.isPlaying() ?? false;
        if (_isPlaying != newIsPlayingState) {
          if (newIsPlayingState && !_isPlaying) { // Started playing
            _dataController.videoDidStartPlaying(_videoUniqueId!);
            // No longer setting activeFeedPlayerController in DataController
          } else if (!newIsPlayingState && _isPlaying) { // Paused or finished
            _dataController.videoDidStopPlaying(_videoUniqueId!);
          }
          _isPlaying = newIsPlayingState;
          changed = true;
        }

        // If in feed and playing, update DataController with current position for potential transition.
        if (widget.isFeedContext && _isPlaying) {
          _dataController.activeFeedPlayerPosition.value = _position;
          _dataController.activeFeedPlayerVideoId.value = _videoUniqueId; // Ensure ID is set
        }

        _duration = _controller?.videoPlayerController?.value.duration ?? _duration;

        if (!_isPlaying && !_showControls) {
          _showControls = true;
          _animationController.forward();
          changed = true;
        }
        if (changed) {
          setState(() {});
        }
      }
    };
    _controller?.addEventsListener(_eventListener!);
  }


  Future<void> _initializeVideoPlayer() async {
    // Removed logic for adopting controller from DataController.

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showControls = true;
      _animationController.forward();
    });

    // Dispose existing controller if any (e.g. on retry or re-initialization)
    if(_controller != null) {
        await _controller!.dispose();
        _controller = null;
        _isInitialized = false;
        print("BetterPlayerWidget ($_videoUniqueId) disposed existing controller before re-initializing.");
    }


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
            'Cache-Control': 'max-age=604800',
          },
        );
      } else if (widget.file != null) {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.file,
          widget.file!.path,
        );
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

      _controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: widget.isFeedContext ? false : true, // Autoplay if not in feed (e.g. MediaViewPage)
          looping: widget.isFeedContext ? true : false, // Loop in feed, not necessarily in MediaViewPage
          aspectRatio: null,
          fit: BoxFit.contain,
          placeholder: _buildPlaceholder(),
          startAt: widget.startAt, // Use the passed startAt parameter
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControls: false,
            loadingWidget: SizedBox.shrink(),
          ),
          handleLifecycle: true, // Let BetterPlayer handle app lifecycle
          autoDispose: true, // Auto dispose controller with widget
        ),
        betterPlayerDataSource: dataSource,
      );

      _eventListener = (BetterPlayerEvent event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isInitialized = true;
              _duration = _controller!.videoPlayerController!.value.duration ?? Duration.zero;
            });
            // If not in feed context (e.g. MediaViewPage) and a startAt was provided, it should have started there.
            // Autoplay is true for non-feed contexts.
            // If in feed, playback is typically controlled by VisibilityDetector or other logic.
          }
        } else if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
            if (mounted) {
                 setState(() {
                    _isLoading = false;
                    _isInitialized = false;
                    _errorMessage = event.parameters?['message']?.toString() ?? 'Error initializing video';
                 });
            }
        }
        // Call _attachListeners once after the first successful initialization
        // to handle ongoing events like progress, play, pause.
        // Ensure it's only attached once.
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized && _eventListener != null) {
             _controller!.removeEventsListener(_eventListener!); // Remove this specific init-focused listener
             _attachListeners(); // Attach the main event listener
        }
      };
      _controller!.addEventsListener(_eventListener!);

    } catch (e) {
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        _initializeVideoPlayer(); // Retry initialization
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

    // Removed conditional disposal logic related to transitions.
    // If autoDispose: true is set in BetterPlayerConfiguration,
    // BetterPlayer itself should handle disposing the controller when the widget is disposed.
    // Explicitly removing listeners is still good practice if autoDispose isn't fully relied upon
    // or if there are scenarios where the controller might be swapped.
    if (_eventListener != null && _controller != null) {
      _controller!.removeEventsListener(_eventListener!);
    }
    // _controller?.dispose(); // Rely on autoDispose or BetterPlayer's own disposal.
    // If not relying on autoDispose, then uncomment the line above.
    // For safety with the current refactor, let's ensure it's explicitly called if not autoDisposing.
    // Since autoDispose is true, this should be redundant but harmless.
    // However, if _controller was swapped or not managed by a BetterPlayer widget directly, manual dispose is key.
    // Given it's part of _BetterPlayerWidgetState, autoDispose should handle it.
    // Let's remove the explicit call to see if autoDispose works as expected.
    // If issues arise, re-add: _controller?.dispose();
    print("BetterPlayerWidget ($_videoUniqueId) dispose method called.");


    _hideControlsTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget _buildPlaceholder() {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.contain,
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
      );
    } else {
      // Default placeholder if no thumbnail URL is provided
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          strokeWidth: 2,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there's an error message, display it.
    if (_errorMessage != null) {
      print('Error: $_errorMessage');
      return Center(
        child: Text(
          _errorMessage!, // Already checked for null
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    // If still loading and not yet initialized (controller is null), show placeholder.
    // This handles the very initial state before controller setup attempts.
    // The BetterPlayerConfiguration.placeholder will handle loading display during controller setup.
    if (_isLoading && _controller == null) {
      return _buildPlaceholder();
    }

    // If not initialized and controller is null (could be due to no source), show error.
    // This case should ideally be caught by _errorMessage, but as a fallback.
    if (!_isInitialized || _controller == null) {
      return Center(
        child: Text(
          _errorMessage ?? 'Video player not available.', // Generic error if _errorMessage is null
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Once controller is available and initialized (or attempting to initialize),
    // BetterPlayer widget itself will use its placeholder.
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Center(
                // Removed the explicit AspectRatio widget wrapper.
                // BetterPlayer with aspectRatio: null in its config will use intrinsic video ratio.
                // The Center widget will handle centering if BoxFit.contain leads to letter/pillarboxing.
                child: BetterPlayer(controller: _controller!),
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