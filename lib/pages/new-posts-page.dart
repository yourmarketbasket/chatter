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
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumb;

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({Key? key}) : super(key: key);

  @override
  _NewPostScreenState createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _postController = TextEditingController();
  final List<Attachment> _selectedAttachments = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingAudio = false;
  String? _currentRecordingPath;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  final ImagePicker _picker = ImagePicker();
  String? _currentlyPlayingPath; // Track which audio file is playing
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  StreamSubscription<PlayerState>? _playerStateSubscription; // Store subscription

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    // Set up audio player state listener
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        if (mounted) { // Check if widget is still mounted
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
        permission = sdkInt < 33 ? Permission.storage : null; // No permission needed on Android 13+
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
      // Android 13+ uses scoped storage; FilePicker doesn't need permissions
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
        final directory = await getTemporaryDirectory();
        _currentRecordingPath = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: _currentRecordingPath!);
        setState(() {
          _isRecordingAudio = true;
        });
        _pulseController?.forward();
      }
    }
  }

  Future<void> _stopAudioRecording() async {
    final path = await _audioRecorder.stop();
    if (path != null) {
      final file = File(path);
      print('[NewPostScreen] Audio Recorded: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
      final sizeInMB = await file.length() / (1024 * 1024); // Use await file.length()
      if (sizeInMB <= 10) {
        print('[NewPostScreen] Adding to _selectedAttachments: type=audio, path=${file.path}');
        setState(() {
          _selectedAttachments.add(Attachment(file: file, type: "audio"));
          _isRecordingAudio = false;
        });
        _pulseController?.reset();
      } else {
        _showPermissionDialog(
          'File Size Error',
          'Audio file exceeds 10MB!',
        );
      }
    }
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    try {
      if (await _requestMediaPermissions(fromCamera ? 'camera' : 'image')) {
        final XFile? image = await _picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1920, // Limit resolution to reduce file size
          maxHeight: 1080,
          imageQuality: 85, // Compress image to reduce size
        );
        if (image != null) {
          final file = File(image.path);
          print('[NewPostScreen] Image Picked: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
          final sizeInMB = await file.length() / (1024 * 1024); // Use await file.length()
          if (sizeInMB <= 10) {
            print('[NewPostScreen] Adding to _selectedAttachments: type=image, path=${file.path}');
            setState(() {
              _selectedAttachments.add(Attachment(file: file, type: "image"));
            });
          } else {
            _showPermissionDialog(
              'File Size Error',
              'Image file exceeds 10MB limit.',
            );
          }
        } else {
          _showPermissionDialog(
            'No Image Selected',
            'No image was selected or the operation was cancelled.',
          );
        }
      }
    } catch (e) {
      _showPermissionDialog(
        'Error Picking Image',
        'An error occurred while picking the image: $e',
      );
    }
  }

  Future<void> _pickVideo({required bool fromCamera}) async {
    try {
      if (await _requestMediaPermissions(fromCamera ? 'camera' : 'video')) {
        final XFile? video = await _picker.pickVideo(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          maxDuration: const Duration(seconds: 30), // Limit video duration
        );
        if (video != null) {
          final file = File(video.path);
          print('[NewPostScreen] Video Picked: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
          final sizeInMB = await file.length() / (1024 * 1024); // Use await file.length()
          if (sizeInMB <= 10) {
            print('[NewPostScreen] Adding to _selectedAttachments: type=video, path=${file.path}');
            setState(() {
              _selectedAttachments.add(Attachment(file: file, type: "video"));
            });
          } else {
            _showPermissionDialog(
              'File Size Error',
              'Video file exceeds 10MB limit.',
            );
          }
        } else {
          _showPermissionDialog(
            'No Video Selected',
            'No video was selected or the operation was cancelled.',
          );
        }
      }
    } catch (e) {
      _showPermissionDialog(
        'Error Picking Video',
        'An error occurred while picking the video: $e',
      );
    }
  }

  Future<void> _pickPdf() async {
    if (await _requestMediaPermissions('pdf')) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        print('[NewPostScreen] PDF Picked: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
        final sizeInMB = await file.length() / (1024 * 1024); // Use await file.length()
        if (sizeInMB <= 10) {
          print('[NewPostScreen] Adding to _selectedAttachments: type=pdf, path=${file.path}');
          setState(() {
            _selectedAttachments.add(Attachment(file: file, type: "pdf"));
          });
        } else {
          _showPermissionDialog(
            'File Size Error',
            'PDF file exceeds 10MB!',
          );
        }
      }
    }
  }

  Future<void> _pickAudio() async {
    if (await _requestMediaPermissions('audio')) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        print('[NewPostScreen] Audio Picked: path=${file.path}, exists=${await file.exists()}, length=${await file.length()}');
        final sizeInMB = await file.length() / (1024 * 1024); // Use await file.length()
        if (sizeInMB <= 10) {
          print('[NewPostScreen] Adding to _selectedAttachments: type=audio, path=${file.path}');
          setState(() {
            _selectedAttachments.add(Attachment(file: file, type: "audio"));
          });
        } else {
          _showPermissionDialog(
            'File Size Error',
            'Audio file exceeds 10MB!',
          );
        }
      }
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
      return null;
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel(); // Cancel the stream subscription
    _postController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.stop();
    _audioRecorder.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  Widget _buildAttachmentPreview(Attachment attachment) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: attachment.type == "image"
                ? Image.file(
                    attachment.file,
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
                : attachment.type == "pdf"
                    ? PdfViewer.file(
                        attachment.file.path,
                        params: const PdfViewerParams(
                          maxScale: 1.0,
                        ),
                      )
                    : attachment.type == "audio"
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _currentlyPlayingPath == attachment.file.path &&
                                          _audioPlayer.state == PlayerState.playing
                                      ? FeatherIcons.pause
                                      : FeatherIcons.play,
                                  color: Colors.tealAccent,
                                  size: 40,
                                ),
                                onPressed: () async {
                                  if (_currentlyPlayingPath == attachment.file.path &&
                                      _audioPlayer.state == PlayerState.playing) {
                                    await _audioPlayer.pause();
                                    if (mounted) {
                                      setState(() {
                                        _currentlyPlayingPath = null;
                                      });
                                    }
                                  } else {
                                    await _audioPlayer.stop(); // Stop any currently playing audio
                                    await _audioPlayer.play(DeviceFileSource(attachment.file.path));
                                    if (mounted) {
                                      setState(() {
                                        _currentlyPlayingPath = attachment.file.path;
                                      });
                                    }
                                  }
                                },
                              ),
                              Text(
                                attachment.file.path.split('/').last,
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
                            future: _generateVideoThumbnail(attachment.file.path),
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
              if (attachment.type == "audio" && _currentlyPlayingPath == attachment.file.path) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'New Chatter',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(FeatherIcons.x, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.4,
                child: TextField(
                  controller: _postController,
                  maxLength: 280,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Niaje? What's the vibe?",
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
                    scale: _pulseAnimation!,
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
                      // Show dialog to choose between gallery and camera
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
                      // Show dialog to choose between gallery and camera
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
                      print('[NewPostScreen] Popping with attachments: ${_selectedAttachments.map((a) => 'type=${a.type}, path=${a.file.path}').toList()}');
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
    );
  }
}