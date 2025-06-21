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

  const BetterPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    this.thumbnailUrl,
    this.isFeedContext = false, // Default to false
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
  // double? _aspectRatio; // No longer needed, BetterPlayer will use intrinsic video aspect ratio

  // For single video playback
  final DataController _dataController = Get.find<DataController>();
  String? _videoUniqueId;
  StreamSubscription? _currentlyPlayingVideoSubscription;
  // StreamSubscription? _isTransitioningVideoSubscription; // No longer needed here, MediaViewPage manages its own lifecycle
  void Function(BetterPlayerEvent)? _eventListener;
  bool _wasPlayingBeforeTransition = false;


  @override
  void initState() {
    super.initState();
    _videoUniqueId = widget.url ?? widget.file?.path ?? widget.key.toString();
    print("[BPW initState] for $_videoUniqueId. isFeed: ${widget.isFeedContext}");

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // This widget is now primarily for MediaViewPage or contexts *not* the main feed's auto-playing grid.
    // If it's in the feed (isFeedContext = true), it's likely a simplified version or needs careful handling.
    // The complex transition logic (reclaiming controller from feed) is mostly handled by VideoAttachmentWidget for the feed.

    // Scenario 1: MediaViewPage is taking over a controller from the feed.
    if (!widget.isFeedContext && // This instance is in MediaViewPage
        _dataController.isTransitioningVideo.value &&
        _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
        _dataController.activeFeedPlayerController.value is BetterPlayerController) {

      print("[BPW initState] MediaViewPage taking controller for $_videoUniqueId from feed.");
      _controller = _dataController.activeFeedPlayerController.value as BetterPlayerController;
      _wasPlayingBeforeTransition = _controller?.isPlaying() ?? false; // Capture if it was playing

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
          if (_controller!.videoPlayerController!.value.isInitialized) {
            _duration = _controller!.videoPlayerController!.value.duration ?? Duration.zero;
            _position = _controller!.videoPlayerController!.value.position ?? Duration.zero;
          } else {
            // Controller might not be fully initialized yet if transition was too fast
             _duration = Duration.zero;
             _position = Duration.zero;
          }
          _isPlaying = _controller!.isPlaying() ?? false;
          _showControls = true; // Always show controls initially in MediaViewPage
          _animationController.forward();
        });
        _attachListeners(); // Attach listeners for MediaViewPage context

        // If it was playing in feed, ensure it continues in MediaViewPage
        // The activeFeedPlayerPosition should be respected by the init listener
        // if (_isPlaying) { // Or use _wasPlayingBeforeTransition
        //    _controller!.play();
        // }
        // The event listener's initialized block will handle seekTo and play
      }
    } else {
      // Scenario 2: Standard initialization (e.g., MediaViewPage opens a video not from feed, or if it's used elsewhere)
      print("[BPW initState] Standard initialization for $_videoUniqueId.");
      _initializeVideoPlayer();
    }

    // Listen for global currently playing video to pause if this isn't the one
    _currentlyPlayingVideoSubscription = _dataController.currentlyPlayingVideoId.listen((playingId) {
      if (_controller != null && (_controller!.isPlaying() ?? false)) {
        if (playingId != null && playingId != _videoUniqueId) {
          print("[BPW] Another video ($playingId) started. Pausing $_videoUniqueId.");
          _controller!.pause();
          // UI update for play/pause button will be handled by the event listener
        }
      }
    });
  }

  void _attachListeners() {
    if (_controller == null || _eventListener != null) { // Avoid attaching multiple times
        if(_eventListener != null && _controller != null) _controller!.removeEventsListener(_eventListener!);
        else if (_controller == null) return;
    }
    _eventListener = (event) {
      if (!mounted || _controller == null) return;
      bool needsSetState = false;

      switch (event.betterPlayerEventType) {
        case BetterPlayerEventType.initialized:
          print("[BPW Event] Initialized: $_videoUniqueId");
          _duration = _controller!.videoPlayerController!.value.duration ?? Duration.zero;
          _position = _controller!.videoPlayerController!.value.position ?? Duration.zero;
          _isInitialized = true;
          _isLoading = false;
          needsSetState = true;

          // If this controller was taken for MediaViewPage
          if (!widget.isFeedContext &&
              _dataController.isTransitioningVideo.value &&
              _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
              _dataController.activeFeedPlayerController.value == _controller) {

            final targetPosition = _dataController.activeFeedPlayerPosition.value;
            if (targetPosition != null) {
              _controller!.seekTo(targetPosition);
              _position = targetPosition; // Update local position immediately
            }
            // if (_wasPlayingBeforeTransition) { // Check if it should auto-play
            //   _controller!.play();
            // }
             _controller!.play(); // Generally, media view page should autoplay
          }
          break;

        case BetterPlayerEventType.progress:
          final newPosition = event.parameters?['progress'] as Duration?;
          if (newPosition != null && _position != newPosition) {
            _position = newPosition;
            needsSetState = true;
          }
          break;

        case BetterPlayerEventType.play:
        case BetterPlayerEventType.pause:
        case BetterPlayerEventType.finished:
          final newIsPlayingState = _controller!.isPlaying() ?? false;
          if (_isPlaying != newIsPlayingState) {
            _isPlaying = newIsPlayingState;
            needsSetState = true;
            if (_isPlaying) {
              _dataController.videoDidStartPlaying(_videoUniqueId!); // Global tracking
              // Auto-hide controls if playing and controls are shown
              if (_showControls) {
                _hideControlsTimer?.cancel();
                _hideControlsTimer = Timer(const Duration(seconds: 3), () {
                  if (mounted && _isPlaying && _showControls) {
                    setState(() {
                      _showControls = false;
                      _animationController.reverse();
                    });
                  }
                });
              }
            } else {
               _dataController.videoDidStopPlaying(_videoUniqueId!);
              // Ensure controls are shown when paused/finished
              if (!_showControls) {
                _showControls = true;
                _animationController.forward();
                needsSetState = true;
              }
            }
          }
          // Update duration just in case it wasn't available at init
          final currentDuration = _controller!.videoPlayerController!.value.duration;
          if (currentDuration != null && _duration != currentDuration) {
            _duration = currentDuration;
            needsSetState = true;
          }
          break;

        case BetterPlayerEventType.exception:
          print("[BPW Event] Exception for $_videoUniqueId: ${event.parameters?['message']}");
          _errorMessage = event.parameters?['message']?.toString() ?? 'Error playing video';
          _isLoading = false;
          _isInitialized = false;
          needsSetState = true;
          break;
        default:
          break;
      }
      if (needsSetState) {
        setState(() {});
      }
    };
    _controller!.addEventsListener(_eventListener!);
    // Manually trigger a state update if already initialized to refresh UI with current values
    if(_isInitialized){
        setState(() {
            _duration = _controller!.videoPlayerController!.value.duration ?? Duration.zero;
            _position = _controller!.videoPlayerController!.value.position ?? Duration.zero;
            _isPlaying = _controller!.isPlaying() ?? false;
        });
    }
  }


  Future<void> _initializeVideoPlayer() async {
    if (_isLoading || _isInitialized) return; // Don't re-initialize if already loading or initialized

    print("[BPW _initializeVideoPlayer] Initializing new controller for $_videoUniqueId");
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    BetterPlayerDataSource dataSource;
    if (widget.url != null && widget.url!.isNotEmpty) {
      dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.url!,
        cacheConfiguration: const BetterPlayerCacheConfiguration(
          useCache: true, // Enable caching
          maxCacheSize: 200 * 1024 * 1024, // Increased cache size
          maxCacheFileSize: 20 * 1024 * 1024,
        ),
        headers: {'Cache-Control': 'max-age=604800'},
      );
    } else if (widget.file != null) {
      dataSource = BetterPlayerDataSource(BetterPlayerDataSourceType.file, widget.file!.path);
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No video source available for BetterPlayerWidget.';
        });
      }
      return;
    }

    // Dispose any existing controller before creating a new one
    if (_controller != null) {
        if (_eventListener != null) _controller!.removeEventsListener(_eventListener!);
        _controller!.dispose();
        _controller = null;
    }

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: !widget.isFeedContext, // Autoplay typically for MediaViewPage, not for feed items unless specifically designed
        looping: false, // Looping usually false for MediaViewPage
        aspectRatio: null, // Let player determine from video
        fit: BoxFit.contain,
        placeholder: _buildPlaceholder(),
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false, // We use custom controls overlay
          loadingWidget: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
        ),
        handleLifecycle: true, // Standardized to true
        autoDispose: false,   // Standardized to false
      ),
      betterPlayerDataSource: dataSource,
    );

    // Attach the main event listener immediately
    _attachListeners();
    // No specific init listener needed anymore, main listener handles init event.
  }

  void _seekToPosition(double value) {
    if (_controller == null || !_isInitialized) return;
    final position = _duration * value;
    _controller!.seekTo(position);
    // The event listener will update the UI for position
  }

  void _toggleControls() {
    if (!_isInitialized) return; // Don't toggle if not initialized
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _animationController.forward();
        // If playing, set timer to hide controls
        if (_isPlaying) {
          _hideControlsTimer?.cancel();
          _hideControlsTimer = Timer(const Duration(seconds: 3), () {
            if (mounted && _isPlaying && _showControls) { // Check _showControls again
              setState(() {
                _showControls = false;
                _animationController.reverse();
              });
            }
          });
        }
      } else {
        _animationController.reverse();
        _hideControlsTimer?.cancel(); // Cancel timer if controls are manually hidden
      }
    });
  }

  @override
  void dispose() {
    print("[BPW dispose] Disposing for $_videoUniqueId. isFeed: ${widget.isFeedContext}");
    _currentlyPlayingVideoSubscription?.cancel();
    _hideControlsTimer?.cancel();
    _animationController.dispose();

    bool isControllerFromFeed = !widget.isFeedContext && // In MediaViewPage
                               _dataController.isTransitioningVideo.value && // Still in "transition mode"
                               _dataController.activeFeedPlayerVideoId.value == _videoUniqueId &&
                               _dataController.activeFeedPlayerController.value == _controller;

    if (isControllerFromFeed) {
      print("[BPW dispose] $_videoUniqueId (MediaViewPage) was using controller from feed. Signaling end of transition.");
      // Update DataController with the final state before MediaViewPage closes
      if (_controller != null && _controller!.videoPlayerController!.value.initialized) {
        _dataController.activeFeedPlayerPosition.value = _controller!.videoPlayerController!.value.position;
        // Optionally, also update a 'wasPlaying' state if feed needs to know
      }
      _dataController.isTransitioningVideo.value = false; // Crucial: signal feed it can reclaim/reinit
      // DO NOT dispose _controller here. It belongs to the feed.
      // Clear DataController's hold on it, so feed doesn't think it's still with MediaViewPage.
      _dataController.activeFeedPlayerController.value = null;
      _dataController.activeFeedPlayerVideoId.value = null;
      // _dataController.activeFeedPlayerPosition.value = null; // Position is kept for feed to potentially use
       if (_eventListener != null && _controller != null) { // Remove listener from shared controller
           _controller!.removeEventsListener(_eventListener!);
           _eventListener = null; // Prevent re-attachment issues
       }

    } else {
      // Standard disposal: This controller was initialized and is owned by this BetterPlayerWidget instance.
      print("[BPW dispose] $_videoUniqueId normally disposing its own controller.");
      if (_eventListener != null && _controller != null) {
        _controller!.removeEventsListener(_eventListener!);
      }
      _controller?.dispose(); // This will also call videoPlayerController.dispose()
    }
    _controller = null; // Ensure controller is nulled
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