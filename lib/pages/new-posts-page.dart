import 'dart:async';
import 'dart:io';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumb;
import 'package:image/image.dart' as img; // Added for image processing
import 'package:flutter_video_info/flutter_video_info.dart'; // Added for video processing

// NewPostScreen allows users to create a new post with text and attachments (image, PDF, audio, video).
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({Key? key}) : super(key: key);

  @override
  _NewPostScreenState createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _postController = TextEditingController();
  final List<Map<String, dynamic>> _selectedAttachments = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingAudio = false;
  String? _currentRecordingPath;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final ImagePicker _picker = ImagePicker();
  String? _currentlyPlayingPath;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        if (mounted) {
          setState(() {
            _currentlyPlayingPath = null;
          });
        }
      }
    });
  }

  Future<int?> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.version.sdkInt;
      } catch (e) {
        print('Error getting Android SDK version: $e');
        return null;
      }
    }
    return null;
  }

  Future<bool> _requestMediaPermissions(String action) async {
    if (!Platform.isAndroid) return true;

    final int? sdkInt = await _getAndroidSdkVersion();
    if (sdkInt == null) {
      _showPermissionDialog(
        'Error',
        'Unable to determine Android version. Please check app permissions in settings.',
        openSettings: true,
      );
      return false;
    }

    Permission? permission;
    String permissionName = '';

    switch (action) {
      case 'image':
        permission = sdkInt >= 33 ? Permission.photos : Permission.storage;
        permissionName = 'Photos';
        break;
      case 'video':
        permission = sdkInt >= 33 ? Permission.videos : Permission.storage;
        permissionName = 'Videos';
        break;
      case 'audio':
        permission = sdkInt >= 33 ? Permission.audio : Permission.storage;
        permissionName = 'Audio';
        break;
      case 'pdf':
        permission = sdkInt < 33 ? Permission.storage : null;
        permissionName = 'Storage';
        break;
      case 'camera':
        permission = Permission.camera;
        permissionName = 'Camera';
        break;
      default:
        return false;
    }

    if (action == 'pdf' && sdkInt >= 33) {
      return true;
    }

    if (permission == null) return false;

    final status = await permission.request();
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      _showPermissionDialog(
        '$permissionName Permission Required',
        'Please enable $permissionName permission in app settings.',
        openSettings: true,
      );
    } else {
      _showPermissionDialog(
        '$permissionName Permission Required',
        'Please grant $permissionName permission to continue.',
      );
    }
    return false;
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return true;
    }
    if (status.isPermanentlyDenied) {
      _showPermissionDialog(
        'Microphone Permission Required',
        'Please enable microphone access in app settings.',
        openSettings: true,
      );
    } else {
      _showPermissionDialog(
        'Microphone Permission Required',
        'Please grant microphone permission to record audio.',
      );
    }
    return false;
  }

  void _showPermissionDialog(String title, String message, {bool openSettings = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.roboto(color: Colors.white)),
        content: Text(message, style: GoogleFonts.roboto(color: Colors.white70)),
        backgroundColor: const Color(0xFF252525),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.tealAccent)),
          ),
          if (openSettings)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: Text('Settings', style: GoogleFonts.roboto(color: Colors.tealAccent)),
            ),
        ],
      ),
    );
  }

  Future<void> _startAudioRecording() async {
    if (await _requestMicrophonePermission()) {
      if (await _audioRecorder.hasPermission()) {
        try {
          final directory = await getTemporaryDirectory();
          _currentRecordingPath = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: _currentRecordingPath!);
          setState(() {
            _isRecordingAudio = true;
          });
          _pulseController.forward();
        } catch (e) {
          _showPermissionDialog(
            'Recording Error',
            'Failed to start audio recording: $e',
          );
        }
      }
    }
  }

  Future<void> _stopAudioRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        final file = File(path);
        print('[NewPostScreen] Audio Recorded: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
        final int fileSize = await file.length();
        final sizeInMB = fileSize / (1024 * 1024);
        if (sizeInMB <= 10) {
          // Attempt to get duration
          int? durationMs;
          final tempAudioPlayer = AudioPlayer();
          try {
            await tempAudioPlayer.setSourceDeviceFile(file.path);
            durationMs = (await tempAudioPlayer.getDuration())?.inMilliseconds;
            await tempAudioPlayer.release(); // Release promptly
          } catch (e) {
            print('[NewPostScreen] Error getting audio duration: $e');
            await tempAudioPlayer.release(); // Ensure release on error
          }
          final durationSeconds = durationMs != null ? (durationMs / 1000).round() : null;

          print('[NewPostScreen] Adding to _selectedAttachments: type=audio, path=${file.path}, duration=${durationSeconds}s');
          final attachmentData = {
            'file': file,
            'type': 'audio',
            'filename': file.path.split('/').last,
            'size': fileSize,
            if (durationSeconds != null) 'duration': durationSeconds,
            // Audio doesn't typically have width/height/orientation/aspectRatio in this context
          };
          setState(() {
            _selectedAttachments.add(attachmentData);
            _isRecordingAudio = false;
          });
          _pulseController.reset();
        } else {
          _showPermissionDialog(
            'File Size Error',
            'Audio file exceeds 10MB limit.',
          );
        }
      }
    } catch (e) {
      _showPermissionDialog(
        'Recording Error',
        'Failed to stop audio recording: $e',
      );
    }
  }

  Future<Map<String, dynamic>?> _getImageDimensions(File file) async {
    try {
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image != null) {
        final width = image.width;
        final height = image.height;
        String orientation;
        if (width > height) {
          orientation = 'landscape';
        } else if (height > width) {
          orientation = 'portrait';
        } else {
          orientation = 'square';
        }
        print('[NewPostScreen] Image Decoded Dimensions: width=$width, height=$height, orientation=$orientation');
        double aspectRatio = (width != 0 && height != 0) ? (width / height) : 1.0;
        return {
          'width': width,
          'height': height,
          'orientation': orientation,
          'aspectRatio': aspectRatio.toStringAsFixed(2),
        };
      } else {
        print('[NewPostScreen] Error decoding image with image package.');
        return null;
      }
    } catch (e) {
      print('[NewPostScreen] Error getting image dimensions using image package: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getVideoDimensions(File file) async {
    try {
      // Initialize VideoPlayerController
      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      // Get video dimensions
      final size = controller.value.size;
      final width = size.width.toInt();
      final height = size.height.toInt();

      // Get duration in seconds
      final duration = controller.value.duration.inSeconds;

      // Determine orientation
      String orientation;
      if (width > height) {
        orientation = 'landscape';
      } else if (height > width) {
        orientation = 'portrait';
      } else {
        orientation = 'square';
      }

      // Calculate aspect ratio
      double aspectRatio = (width != 0 && height != 0) ? (width / height) : 1.0;

      // Log details for debugging
      print('[NewPostScreen] Video Dimensions: width=$width, height=$height, orientation=$orientation, duration=$duration, aspectRatio=${aspectRatio.toStringAsFixed(2)}');

      // Clean up controller
      await controller.dispose();

      return {
        'width': width,
        'height': height,
        'orientation': orientation,
        'aspectRatio': aspectRatio.toStringAsFixed(2),
        'duration': duration,
      };
    } catch (e) {
      print('[NewPostScreen] Error getting video dimensions using video_player: $e');
      // Fallback to thumbnail-based dimensions if needed
      final thumbnailDimensions = await _getVideoThumbnailDimensions(file.path);
      if (thumbnailDimensions != null) {
        print('[NewPostScreen] Using thumbnail dimensions as fallback');
        return {
          ...thumbnailDimensions,
          'duration': 0, // Duration unavailable in fallback
        };
      }
      return null;
    }
  }
  
  
  Future<void> _pickImage({required bool fromCamera}) async {
    try {
      if (await _requestMediaPermissions(fromCamera ? 'camera' : 'image')) {
        final XFile? image = await _picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (image != null) {
          final file = File(image.path);
          print('[NewPostScreen] Image Picked: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
          final int fileSize = await file.length();
          final sizeInMB = fileSize / (1024 * 1024);
          if (sizeInMB <= 10) {
            // Prepare attachment map
            final attachment = {
              'file': file,
              'type': 'image',
              'filename': file.path.split('/').last,
              'size': fileSize,
            };
            // Get dimensions using image package
            final dimensions = await _getImageDimensions(file);
            if (dimensions != null) {
              attachment.addAll(dimensions.cast<String, Object>()); // Add width, height, orientation
            } else {
              print('[NewPostScreen] Could not get dimensions for image, will be added without them.');
            }
            print('[NewPostScreen] Adding to _selectedAttachments: type=image, path=${file.path}, width=${attachment['width']}, height=${attachment['height']}, orientation=${attachment['orientation']}');
            setState(() {
              _selectedAttachments.add(attachment);
            });
          } else {
            _showPermissionDialog(
              'File Size Error',
              'Image file exceeds 10MB limit.',
            );
          }
        }
      }
    } catch (e) {
      _showPermissionDialog(
        'Error Picking Image',
        'An error occurred while picking the image: $e',
      );
    }
  }

  Future<Map<String, dynamic>?> _getVideoThumbnailDimensions(String videoPath) async {
    try {
      final thumbnailPath = await video_thumb.VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: video_thumb.ImageFormat.PNG,
        maxHeight: 100,
        quality: 75,
      );
      if (thumbnailPath != null) {
        final thumbnailFile = File(thumbnailPath);
        final dimensions = await _getImageDimensions(thumbnailFile);
        await thumbnailFile.delete(); // Clean up
        if (dimensions != null) {
          print('[NewPostScreen] Video Thumbnail Dimensions: width=${dimensions['width']}, height=${dimensions['height']}, orientation=${dimensions['orientation']}');
          return dimensions;
        }
      }
      print('[NewPostScreen] Failed to generate or process video thumbnail');
      return null;
    } catch (e) {
      print('[NewPostScreen] Error getting video thumbnail dimensions: $e');
      return null;
    }
  }

  Future<void> _pickVideo({required bool fromCamera}) async {
    try {
      if (await _requestMediaPermissions(fromCamera ? 'camera' : 'video')) {
        final XFile? video = await _picker.pickVideo(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          maxDuration: const Duration(seconds: 30),
        );
        if (video != null) {
          final file = File(video.path);
          print('[NewPostScreen] Video Picked: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
          final int fileSize = await file.length();
          final sizeInMB = fileSize / (1024 * 1024);
          if (sizeInMB <= 10) {
            // Prepare attachment map
            final attachment = {
              'file': file,
              'type': 'video',
              'filename': file.path.split('/').last,
              'size': fileSize,
            };
            // Get dimensions using flutter_video_info
            final dimensions = await _getVideoDimensions(file);
            if (dimensions != null) {
              attachment.addAll(dimensions.cast<String, Object>()); // Adds width, height, orientation, duration
            } else {
              print('[NewPostScreen] Could not get dimensions for video, will be added without them.');
            }
            print('[NewPostScreen] Adding to _selectedAttachments: type=video, path=${file.path}, width=${attachment['width']}, height=${attachment['height']}, orientation=${attachment['orientation']}, duration=${attachment['duration']}');
            setState(() {
              _selectedAttachments.add(attachment);
            });
          } else {
            _showPermissionDialog(
              'File Size Error',
              'Video file exceeds 10MB limit.',
            );
          }
        }
      }
    } catch (e) {
      print('[NewPostScreen _pickVideo] Error: $e');
      _showPermissionDialog(
        'Error Picking Video',
        'Could not pick video. Details: ${e.toString()} (Type: ${e.runtimeType.toString()})',
      );
    }
  }

  Future<void> _pickPdf() async {
    try {
      if (await _requestMediaPermissions('pdf')) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          final file = File(result.files.single.path!);
          print('[NewPostScreen] PDF Picked: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
          final int fileSize = await file.length();
          final sizeInMB = fileSize / (1024 * 1024);
          if (sizeInMB <= 10) {
            print('[NewPostScreen] Adding to _selectedAttachments: type=pdf, path=${file.path}');
            setState(() {
              _selectedAttachments.add({
                'file': file,
                'type': 'pdf',
                'filename': file.path.split('/').last,
                'size': fileSize,
              });
            });
          } else {
            _showPermissionDialog(
              'File Size Error',
              'PDF file exceeds 10MB limit.',
            );
          }
        }
      }
    } catch (e) {
      _showPermissionDialog(
        'Error Picking PDF',
        'An error occurred while picking the PDF: $e',
      );
    }
  }

  Future<void> _pickAudio() async {
    try {
      if (await _requestMediaPermissions('audio')) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          final file = File(result.files.single.path!);
          print('[NewPostScreen] Audio Picked: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
          final int fileSize = await file.length();
          final sizeInMB = fileSize / (1024 * 1024);
          if (sizeInMB <= 10) {
            print('[NewPostScreen] Adding to _selectedAttachments: type=audio, path=${file.path}');
            setState(() {
              _selectedAttachments.add({
                'file': file,
                'type': 'audio',
                'filename': file.path.split('/').last,
                'size': fileSize,
              });
            });
          } else {
            _showPermissionDialog(
              'File Size Error',
              'Audio file exceeds 10MB limit.',
            );
          }
        }
      }
    } catch (e) {
      _showPermissionDialog(
        'Error Picking Audio',
        'An error occurred while picking the audio: $e',
      );
    }
  }

  Future<String?> _generateVideoThumbnail(String videoPath) async {
    try {
      return await video_thumb.VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: video_thumb.ImageFormat.PNG,
        maxHeight: 100,
        quality: 75,
      );
    } catch (e) {
      print('Error generating video thumbnail: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _postController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _audioRecorder.stop();
    _audioRecorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildAttachmentPreview(Map<String, dynamic> attachment) {
    final File? file = attachment['file'] as File?;
    final String type = attachment['type'] as String? ?? 'unknown';

    if (file == null) {
      return Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.all(4),
        color: Colors.grey[900],
        child: const Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40),
      );
    }

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: type == 'image'
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[900],
                      child: const Icon(
                        FeatherIcons.image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  )
                : type == 'pdf'
                    ? PdfViewer.file(
                        file.path,
                        params: const PdfViewerParams(
                          maxScale: 1.0,
                        ),
                      )
                    : type == 'audio'
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _currentlyPlayingPath == file.path &&
                                          _audioPlayer.state == PlayerState.playing
                                      ? FeatherIcons.pause
                                      : FeatherIcons.play,
                                  color: Colors.tealAccent,
                                  size: 40,
                                ),
                                onPressed: () async {
                                  try {
                                    if (_currentlyPlayingPath == file.path &&
                                        _audioPlayer.state == PlayerState.playing) {
                                      await _audioPlayer.pause();
                                      if (mounted) {
                                        setState(() {
                                          _currentlyPlayingPath = null;
                                        });
                                      }
                                    } else {
                                      await _audioPlayer.stop();
                                      await _audioPlayer.play(DeviceFileSource(file.path));
                                      if (mounted) {
                                        setState(() {
                                          _currentlyPlayingPath = file.path;
                                        });
                                      }
                                    }
                                  } catch (e) {
                                    _showPermissionDialog(
                                      'Playback Error',
                                      'Failed to play audio: $e',
                                    );
                                  }
                                },
                              ),
                              Text(
                                file.path.split('/').last,
                                style: GoogleFonts.roboto(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                        : FutureBuilder<String?>(
                            future: _generateVideoThumbnail(file.path),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                return Image.file(
                                  File(snapshot.data!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[900],
                                    child: const Icon(
                                      FeatherIcons.video,
                                      color: Colors.tealAccent,
                                      size: 40,
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                color: Colors.grey[900],
                                child: const Icon(
                                  FeatherIcons.video,
                                  color: Colors.tealAccent,
                                  size: 40,
                                ),
                              );
                            },
                          ),
          ),
        ),
        IconButton(
          icon: const Icon(FeatherIcons.x, color: Colors.white, size: 16),
          onPressed: () {
            setState(() {
              _selectedAttachments.remove(attachment);
              if (type == 'audio' && _currentlyPlayingPath == file.path) {
                _audioPlayer.stop();
                _currentlyPlayingPath = null;
              }
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'New Chatter',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(FeatherIcons.x, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.35,
                    child: TextField(
                      controller: _postController,
                      maxLength: 280,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Niaje? What\'s the vibe?',
                        hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.tealAccent),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF252525),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: IconButton(
                          icon: Icon(
                            _isRecordingAudio ? FeatherIcons.square : FeatherIcons.mic,
                            color: _isRecordingAudio ? Colors.red : Colors.tealAccent,
                          ),
                          onPressed: _isRecordingAudio ? _stopAudioRecording : _startAudioRecording,
                          tooltip: 'Record Audio',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(FeatherIcons.image, color: Colors.tealAccent),
                        onPressed: () async {
                          final source = await showModalBottomSheet<ImageSource>(
                            context: context,
                            builder: (context) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(FeatherIcons.image, color: Colors.tealAccent),
                                  title: Text('Gallery', style: GoogleFonts.roboto(color: Colors.white)),
                                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                                ),
                                ListTile(
                                  leading: const Icon(FeatherIcons.camera, color: Colors.tealAccent),
                                  title: Text('Camera', style: GoogleFonts.roboto(color: Colors.white)),
                                  onTap: () => Navigator.pop(context, ImageSource.camera),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF252525),
                          );
                          if (source != null) {
                            await _pickImage(fromCamera: source == ImageSource.camera);
                          }
                        },
                        tooltip: 'Upload or Capture Image',
                      ),
                      IconButton(
                        icon: const Icon(FeatherIcons.fileText, color: Colors.tealAccent),
                        onPressed: _pickPdf,
                        tooltip: 'Upload Document',
                      ),
                      IconButton(
                        icon: const Icon(FeatherIcons.music, color: Colors.tealAccent),
                        onPressed: _pickAudio,
                        tooltip: 'Upload Audio',
                      ),
                      IconButton(
                        icon: const Icon(FeatherIcons.video, color: Colors.tealAccent),
                        onPressed: () async {
                          final source = await showModalBottomSheet<ImageSource>(
                            context: context,
                            builder: (context) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(FeatherIcons.video, color: Colors.tealAccent),
                                  title: Text('Gallery', style: GoogleFonts.roboto(color: Colors.white)),
                                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                                ),
                                ListTile(
                                  leading: const Icon(FeatherIcons.camera, color: Colors.tealAccent),
                                  title: Text('Camera', style: GoogleFonts.roboto(color: Colors.white)),
                                  onTap: () => Navigator.pop(context, ImageSource.camera),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF252525),
                          );
                          if (source != null) {
                            await _pickVideo(fromCamera: source == ImageSource.camera);
                          }
                        },
                        tooltip: 'Upload or Record Video',
                      ),
                    ],
                  ),
                  if (_isRecordingAudio)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Recording Audio...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_selectedAttachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedAttachments.length,
                        itemBuilder: (context, index) => _buildAttachmentPreview(_selectedAttachments[index]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        if (_postController.text.trim().isNotEmpty || _selectedAttachments.isNotEmpty) {
                          print('[NewPostScreen] Popping with attachments: ${_selectedAttachments.map((a) => 'type=${a['type']}, path=${(a['file'] as File?)?.path}, width=${a['width'] ?? 'null'}, height=${a['height'] ?? 'null'}, orientation=${a['orientation'] ?? 'null'}').toList()}');
                          Navigator.pop(context, {
                            'content': _postController.text.trim(),
                            'attachments': _selectedAttachments,
                          });
                        } else {
                          _showPermissionDialog(
                            'Input Error',
                            'Please enter some text or add at least one attachment!',
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.tealAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Create Post',
                            style: GoogleFonts.roboto(color: Colors.tealAccent, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(FeatherIcons.send, color: Colors.tealAccent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}