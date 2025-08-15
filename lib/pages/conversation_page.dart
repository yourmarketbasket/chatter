import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:chatter/pages/group_details_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:intl/intl.dart';
import 'package:objectid/objectid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatter/widgets/audio_attachment_widget.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatter/models/message_model.dart' as model;

class ConversationPage extends StatefulWidget {
  final String conversationId;
  final String username;
  final String userAvatar;
  final String receiverId;
  final bool isGroupChat;

  const ConversationPage({
    Key? key,
    required this.conversationId,
    required this.username,
    required this.userAvatar,
    required this.receiverId,
    required this.isGroupChat,
  }) : super(key: key);

  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> with SingleTickerProviderStateMixin {
  final DataController _dataController = Get.find<DataController>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxBool _isMessageEmpty = true.obs;
  final RxBool _isRecording = false.obs;
  Timer? _recordingTimer;
  final RxInt _recordingDuration = 0.obs;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  String? _recordedAudioPath;
  String? _currentlyPlayingPath;

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
    _pulseController.stop();

    _messageController.addListener(() {
      _isMessageEmpty.value = _messageController.text.isEmpty;
    });
    _dataController.getMessagesForChat(widget.conversationId);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted && state == PlayerState.completed) {
        setState(() {
          _currentlyPlayingPath = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _dataController.clearCurrentlyOpenChatId();
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  List<File> _pendingAttachments = [];
  model.Message? _replyingToMessage;

  void _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        _pendingAttachments.addAll(result.paths.map((path) => File(path!)).toList());
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty && _pendingAttachments.isEmpty && _recordedAudioPath == null) return;

    final String content = _messageController.text.trim();
    List<String> attachmentPaths = _pendingAttachments.map((f) => f.path).toList();
    if (_recordedAudioPath != null) {
      attachmentPaths.add(_recordedAudioPath!);
    }

    _dataController.sendDummyMessage(
      widget.conversationId,
      content,
      attachmentPaths,
      widget.isGroupChat,
    );

    _messageController.clear();
    setState(() {
      _pendingAttachments = [];
      _recordedAudioPath = null;
      _replyingToMessage = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _buildPresenceText() {
    // Dummy presence
    return 'Online';
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = _dataController.user.value['user']['_id'];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16, // 10% reduction from 18
              backgroundImage: widget.userAvatar.isNotEmpty ? CachedNetworkImageProvider(widget.userAvatar) : null,
              backgroundColor: Colors.tealAccent.withOpacity(0.3),
              child: widget.userAvatar.isEmpty ? Text(widget.username[0], style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.bold)) : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.username,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18),
                ),
                if (!widget.isGroupChat)
                  Text(
                    _buildPresenceText(),
                    style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.isGroupChat)
            IconButton(
              icon: const Icon(FeatherIcons.info, color: Colors.white),
              onPressed: () {
                // Get.to(() => GroupDetailsPage(chatId: widget.conversationId));
              },
            )
          else
            IconButton(
              icon: const Icon(FeatherIcons.moreVertical, color: Colors.white),
              onPressed: () {},
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_dataController.isLoadingMessages.value) {
                return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
              }
              final messages = _dataController.currentConversationMessages;
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet. Start the conversation!',
                    style: GoogleFonts.roboto(color: Colors.grey[500]),
                  ),
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final bool isMe = message.sender.id == currentUserId;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5.0),
                      padding: const EdgeInsets.all(8.0),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMe && widget.isGroupChat)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                message.sender.name,
                                style: GoogleFonts.roboto(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (message.content?.isNotEmpty ?? false)
                            Text(
                              message.content!,
                              style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                            ),
                          // Attachment display would go here
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('h:mm a').format(message.createdAt.toLocal()),
                                  style: GoogleFonts.roboto(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 5),
                                  Icon(
                                    message.status == model.MessageStatus.read ? Icons.done_all : Icons.done,
                                    color: message.status == model.MessageStatus.read ? Colors.blue : Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          if (_replyingToMessage != null) _buildReplyContext(),
          if (_pendingAttachments.isNotEmpty) _buildPendingAttachments(),
          if (_recordedAudioPath != null)
            _buildRecordingPlayback()
          else
            _buildMessageInputField(),
        ],
      ),
    );
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) {
      return '';
    }
    final dateTime = DateTime.tryParse(isoString);
    if (dateTime == null) {
      return '';
    }
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }

  Widget _buildReplyContext() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: Colors.grey[800],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingToMessage!.sender.name}',
                  style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  _replyingToMessage!.content ?? '',
                  style: GoogleFonts.roboto(color: Colors.grey[400]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                _replyingToMessage = null;
              });
            },
          ),
        ],
      ),
    );
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

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<void> _startAudioRecording() async {
    if (await _audioRecorder.hasPermission()) {
      try {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording.value = true;
          _recordedAudioPath = path;
        });
        _pulseController.forward();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordingDuration.value++;
        });
      } catch (e) {
        _showPermissionDialog('Recording Error', 'Failed to start audio recording: $e');
      }
    }
  }

  Future<void> _stopAudioRecording() async {
    _recordingTimer?.cancel();
    try {
      await _audioRecorder.stop();
    } catch (e) {
      _showPermissionDialog('Recording Error', 'Failed to stop audio recording: $e');
    } finally {
      setState(() {
        _isRecording.value = false;
      });
      _pulseController.reset();
    }
  }

  void _sendVoiceMessage() {
    _sendMessage();
  }

  Widget _buildRecordingPlayback() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.grey[850]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(FeatherIcons.trash2, color: Colors.redAccent),
            onPressed: () {
              setState(() {
                _recordedAudioPath = null;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _audioPlayer.state == PlayerState.playing ? FeatherIcons.pause : FeatherIcons.play,
              color: Colors.tealAccent,
            ),
            onPressed: () {
              if (_audioPlayer.state == PlayerState.playing) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play(DeviceFileSource(_recordedAudioPath!));
              }
              setState(() {});
            },
          ),
          Expanded(
            child: Text(
              'Recorded Audio',
              style: GoogleFonts.roboto(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(FeatherIcons.send, color: Colors.tealAccent),
            onPressed: _sendVoiceMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            border: Border(top: BorderSide(color: Colors.grey[850]!)),
          ),
          child: Row(
            children: [
              if (_isRecording.value)
                IconButton(
                  icon: const Icon(FeatherIcons.trash2, color: Colors.redAccent),
                  onPressed: _cancelAudioRecording,
                )
              else
                IconButton(
                  icon: Icon(FeatherIcons.paperclip, color: Colors.grey[400]),
                  onPressed: _pickFiles,
                ),
              Expanded(
                child: _isRecording.value
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const Icon(FeatherIcons.mic, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_recordingDuration.value),
                            style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      )
                    : TextField(
                        controller: _messageController,
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          filled: true,
                          fillColor: Colors.grey[850],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                          isDense: true,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
              ),
              const SizedBox(width: 8),
              _buildSendOrRecordButton(),
            ],
          ),
        ));
  }

  Widget _buildSendOrRecordButton() {
    return Obx(() {
      if (_isRecording.value) {
        // Show pulsing stop button
        return ScaleTransition(
          scale: _pulseAnimation,
          child: IconButton(
            icon: const Icon(FeatherIcons.square, color: Colors.red),
            onPressed: _stopAudioRecording,
          ),
        );
      } else if (!_isMessageEmpty.value) {
        // Show send button
        return IconButton(
          icon: const Icon(FeatherIcons.send, color: Colors.tealAccent),
          onPressed: _sendMessage,
        );
      } else {
        // Show mic button
        return IconButton(
          icon: const Icon(FeatherIcons.mic, color: Colors.tealAccent),
          onPressed: _startAudioRecording,
        );
      }
    });
  }

  Widget _buildPendingAttachments() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.black.withOpacity(0.3),
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingAttachments.length,
        itemBuilder: (context, index) {
          final attachment = _pendingAttachments[index];
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                width: 80,
                height: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(
                    attachment,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _pendingAttachments.removeAt(index);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}