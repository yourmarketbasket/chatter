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
  final bool isFeedContext;
  final double? videoAspectRatioProp; // Added to receive aspect ratio for placeholder

  const BetterPlayerWidget({
    Key? key,
    this.url,
    this.file,
    required this.displayPath,
    this.thumbnailUrl,
    this.isFeedContext = false,
    this.videoAspectRatioProp, // Added
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
  // StreamSubscription? _isTransitioningVideoSubscription; // Removed for transition
  void Function(BetterPlayerEvent)? _eventListener;


  @override
  void initState() {
    super.initState();
    _isLoading = true; // Start in loading state for the placeholder
    _videoUniqueId = widget.url ?? widget.file?.path ?? widget.key.toString();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeVideoPlayer();

    _currentlyPlayingVideoSubscription = _dataController.currentlyPlayingMediaId.listen((playingId) {
      // Only enforce single video playback in feed context
      if (widget.isFeedContext &&
          _controller != null &&
          (_controller!.isPlaying() ?? false)) {
        if (playingId != null &&
            playingId != _videoUniqueId &&
            _dataController.currentlyPlayingMediaType.value == 'video') {
          _controller!.pause();
          // _isPlaying state will be updated by the event listener
        }
      }
    });
  }

  void _attachListeners() {
    _eventListener = (event) {
      if (mounted && _controller != null) { // Ensure controller is not null
        bool changed = false;
        if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
          final newPosition = event.parameters?['progress'] as Duration? ?? _position;
          if (_position != newPosition) {
            _position = newPosition;
            changed = true;
          }
        }

        final newIsPlayingState = _controller!.isPlaying() ?? false;
        if (_isPlaying != newIsPlayingState) {
          if (newIsPlayingState && !_isPlaying) { // Video started playing
            _dataController.mediaDidStartPlaying(_videoUniqueId!, 'video', _controller!);
          } else if (!newIsPlayingState && _isPlaying) { // Video stopped playing (paused or finished)
            _dataController.mediaDidStopPlaying(_videoUniqueId!, 'video');
          }
          _isPlaying = newIsPlayingState;
          changed = true;
        }

        // Handle finished event specifically to call mediaDidStopPlaying
        if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
            if (_isPlaying) { // If it was playing and then finished
                _dataController.mediaDidStopPlaying(_videoUniqueId!, 'video');
                _isPlaying = false; // Explicitly set _isPlaying to false
                changed = true;
            }
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
          cacheConfiguration: const BetterPlayerCacheConfiguration( // Disable caching
            useCache: false,
            // maxCacheSize: 100 * 1024 * 1024,
            // maxCacheFileSize: 10 * 1024 * 1024,
          ),
          // headers: { // Remove caching headers
          //   'Cache-Control': 'max-age=604800',
          // },
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

      // Removed temporary controller logic for aspect ratio calculation
      // final tempController = BetterPlayerController(...);
      // await tempController.setupDataSource(dataSource);
      // if (mounted) { ... tempController.dispose(); }

      _controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: false, // Should be false for feed, true for MediaViewPage (handled by caller)
          looping: false,
          aspectRatio: widget.videoAspectRatioProp ?? 16 / 9,
          fit: BoxFit.fitWidth, // Ensure it covers the area
          placeholder: _buildPlaceholder(), // Use the new placeholder
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControls: false, // Custom controls are built on top usually
            loadingWidget: SizedBox.shrink(),
          ),
          handleLifecycle: true,
          autoDispose: true,
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
              // _aspectRatio = _controller!.getAspectRatio() ?? _aspectRatio ?? 16 / 9; // No longer storing _aspectRatio
            });
            _controller!.removeEventsListener(_eventListener!); // Remove this init listener
            _attachListeners(); // Attach the comprehensive event listener now
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
        // The main _attachListeners will handle other events like progress, play, pause.
      };
      _eventListener = (BetterPlayerEvent event) { // Re-assign _eventListener here
        if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          if (mounted) {
            setState(() {
              _isLoading = false; // Initialized, stop loading indicator for placeholder
              _isInitialized = true;
              _duration = _controller!.videoPlayerController!.value.duration ?? Duration.zero;
            });
            _controller!.removeEventsListener(_eventListener!);
            _attachListeners(); // Attach the comprehensive event listener
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
      };
      _controller!.addEventsListener(_eventListener!);


    } catch (e) {
      if (_retryCount < _maxRetries && mounted) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        return _initializeVideoPlayer();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false; // Stop loading on final error
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

    if (_eventListener != null && _controller != null) {
      _controller!.removeEventsListener(_eventListener!);
    }
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
  Widget _buildPlaceholder() {
    final double effectiveAspectRatio = widget.videoAspectRatioProp ?? 16 / 9;
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: effectiveAspectRatio,
          child: (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: screenWidth.round(),
                  placeholder: (context, url) => Container(color: Colors.black87),
                  errorWidget: (context, url, error) => Container(color: Colors.black),
                )
              : Container(color: Colors.black87), // Fallback if no thumbnail
        ),
        if (_isLoading) // Show progress indicator if loading
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 1.0,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      // If there's an error, display it using the buildError structure
      // (assuming buildError is a global helper or defined in this scope)
      return _buildError(
          context,
          message: _errorMessage,
          fileName: widget.displayPath.split('/').last
      );
    }

    // If controller is null (init hasn't happened or failed very early) or still loading, show placeholder.
    // _isLoading is true initially and set to false on BetterPlayerEventType.initialized or playing.
    if (_controller == null || (_isLoading && !_isInitialized) ) {
      return _buildPlaceholder();
    }

    // If initialized but for some reason controller is null (should not happen if _isLoading is false)
    // or if not initialized and also not loading (e.g. error before controller creation)
    // This state indicates a problem, could show error or placeholder.
    // The _errorMessage check above should catch most failure scenarios.
    // If _isInitialized is false here, it means initialization event hasn't fired or failed.
    if (!_isInitialized && !_isLoading) {
        return _buildPlaceholder(); // Still show placeholder if not initialized and not actively loading
    }

    // Controller is available and likely initialized (or BetterPlayer will show its internal placeholder from config)
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

  Widget _buildError(BuildContext context, {String? message, String? fileName}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              message ?? 'An error occurred while loading the video.',
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (fileName != null) ...[
              const SizedBox(height: 8),
              Text(
                fileName,
                style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}