import 'package:flutter/material.dart';
import 'package:better_player_enhanced/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatter/pages/media_view_page.dart'; // For MediaViewPage._buildError
import 'dart:async';
import 'dart:io';

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
          fit: BoxFit.cover, // Ensure video covers the space, constrained by AspectRatio
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
              Center( // Center the AspectRatio
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
