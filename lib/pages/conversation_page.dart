import 'dart:async';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:chatter/pages/group_details_page.dart';
import 'package:chatter/services/socket-service.dart';
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
  final SocketService _socketService = Get.find<SocketService>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final RxBool _isMessageEmpty = true.obs;
  final RxBool _isRecording = false.obs;
  Timer? _recordingTimer;
  final RxInt _recordingDuration = 0.obs;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  String? _recordedAudioPath;
  late PlayerController _playbackController;

  @override
  void initState() {
    super.initState();
    _playbackController = PlayerController();
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
    _dataController.getMessagesForChat(widget.conversationId).catchError((e) {
      Get.snackbar('Error', 'Could not load messages: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    });
    _socketService.joinChat(widget.conversationId);
    _socketService.markChatAsSeen(
        widget.conversationId, _dataController.user.value['user']['_id']);
  }

  @override
  void dispose() {
    _dataController.clearCurrentlyOpenChatId();
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _pulseController.dispose();
    _playbackController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _pendingAttachments = [];
  Map<String, dynamic>? _replyingToMessage;

  String _getAttachmentType(String extension) {
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      return 'image';
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      return 'video';
    } else if (['mp3', 'wav', 'm4a'].contains(extension)) {
      return 'audio';
    } else {
      return 'document';
    }
  }

  void _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        for (var file in result.files) {
          if (file.path != null) {
            final fileExtension = p.extension(file.path!).toLowerCase().substring(1);
            _pendingAttachments.add({
              'type': _getAttachmentType(fileExtension),
              'path': file.path,
              'file': File(file.path!),
              'filename': file.name,
              'isUploading': true,
            });
          }
        }
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty && _pendingAttachments.isEmpty) return;

    final String content = _messageController.text.trim();
    final String messageId = ObjectId().hexString;
    final currentUser = _dataController.user.value['user'];

    // Create the optimistic message with local attachment paths
    final Map<String, dynamic> optimisticMessage = {
      '_id': messageId,
      'content': content,
      'sender': {
        '_id': currentUser['_id'],
        'name': currentUser['name'],
        'avatar': currentUser['avatar'],
      },
      'chat': widget.conversationId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'status': 'sending',
      'attachments': _pendingAttachments.map((att) => {
        'type': att['type'],
        'path': att['path'], // Local path for immediate display
        'filename': att['filename'],
        'isUploading': true,
      }).toList(),
      'replyTo': _replyingToMessage?['_id'],
    };

    // Add to UI immediately
    _dataController.currentConversationMessages.add(optimisticMessage);
    _uploadAndSend(messageId, content, List.from(_pendingAttachments));

    // Clear input fields
    _messageController.clear();
    setState(() {
      _pendingAttachments = [];
      _replyingToMessage = null;
    });

    // Scroll to bottom
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

  void _uploadAndSend(String messageId, String content, List<Map<String, dynamic>> attachments) async {
    List<Map<String, dynamic>> uploadedAttachments = [];
    if (attachments.isNotEmpty) {
      // Prepare files for upload service
      List<Map<String, dynamic>> filesToUpload = attachments.map((att) {
        return {'type': att['type'], 'file': att['file']};
      }).toList();

      // Upload files
      final uploadResults = await _dataController.uploadFiles(filesToUpload);

      // Check if all uploads were successful
      if (uploadResults.every((res) => res['success'] == true)) {
        uploadedAttachments = uploadResults.asMap().entries.map((entry) {
          final index = entry.key;
          final res = entry.value;
          // Use index to map to original attachment, avoiding filename mismatches
          final originalAtt = attachments[index];
          if (res['url'] == null || res['url'].isEmpty) {
            // Log error and mark upload as failed for this file
            print('Upload failed for file: ${originalAtt['filename']}');
            return null;
          }
          return {
            'type': originalAtt['type'],
            'url': res['url'],
            'filename': originalAtt['filename'],
          };
        }).where((att) => att != null).cast<Map<String, dynamic>>().toList();

        // If no attachments were successfully uploaded, fail the message
        if (uploadedAttachments.isEmpty && attachments.isNotEmpty) {
          final index = _dataController.currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
          if (index != -1) {
            _dataController.currentConversationMessages[index]['status'] = 'failed';
            _dataController.currentConversationMessages.refresh();
          }
          Get.snackbar('Error', 'All files failed to upload.');
          return;
        }
      } else {
        // Handle upload failure: update message status to 'failed'
        final index = _dataController.currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
        if (index != -1) {
          _dataController.currentConversationMessages[index]['status'] = 'failed';
          _dataController.currentConversationMessages.refresh();
        }
        Get.snackbar('Error', 'Some files failed to upload.');
        return;
      }
    }

    // Prepare final payload for the server
    final Map<String, dynamic> messagePayload = {
      'chatId': widget.conversationId,
      'content': content,
      'clientMessageId': messageId,
      'attachments': uploadedAttachments,
      'replyTo': _replyingToMessage?['_id'],
    };

    if (!widget.isGroupChat) {
      messagePayload['receiverId'] = widget.receiverId;
    }

    _socketService.sendMessage(messagePayload);
  }

  String _buildPresenceText(Map<String, dynamic>? presence) {
    if (presence == null) {
      return '';
    }
    if (presence['isOnline'] == true) {
      return 'Online';
    }
    if (presence['lastSeen'] != null) {
      final lastSeenTime = DateTime.tryParse(presence['lastSeen']);
      if (lastSeenTime != null) {
        return 'Last seen ${timeago.format(lastSeenTime)}';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // Determine current user ID for message alignment
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
              radius: 18,
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
                  Obx(() {
                    final presence = _dataController.userPresence[widget.receiverId];
                    return Text(
                      _buildPresenceText(presence),
                      style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                    );
                  }),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.isGroupChat)
            IconButton(
              icon: const Icon(FeatherIcons.info, color: Colors.white),
              onPressed: () {
                Get.to(() => GroupDetailsPage(chatId: widget.conversationId));
              },
            )
          else
            IconButton(
              icon: const Icon(FeatherIcons.moreVertical, color: Colors.white),
              onPressed: () {
                // TODO: Implement more options for one-on-one chat (e.g., view profile, block)
              },
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_dataController.isLoadingMessages.value) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.tealAccent));
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
              // Scroll to bottom when messages load for the first time or when new messages arrive
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
                  final bool isMe = message['sender']['_id'] == currentUserId;

                  // Pre-process attachments to separate media from others
                  final attachments = (message['attachments'] as List?) ?? [];
                  final mediaAttachments = attachments
                      .where((att) => att['type'] == 'image' || att['type'] == 'video')
                      .toList();
                  final otherAttachments = attachments
                      .where((att) => att['type'] != 'image' && att['type'] != 'video')
                      .toList();
                  final hasContent = message['content'] != null && message['content'].isNotEmpty;

                  return Dismissible(
                      key: Key(message['_id']),
                      direction: DismissDirection.startToEnd,
                      onDismissed: (direction) {
                        setState(() {
                          _replyingToMessage = message;
                        });
                      },
                      background: Container(
                        color: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerLeft,
                        child: const Icon(Icons.reply, color: Colors.white),
                      ),
                      child: GestureDetector(
                        onLongPress: () {
                          if (isMe) {
                            _showMessageOptions(context, message);
                          }
                        },
                        child: Align(
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
                                      message['sender']['name'],
                                      style: GoogleFonts.roboto(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                // 1. Media Attachments
                                if (mediaAttachments.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Column(
                                      children: mediaAttachments
                                          .map((attachment) => _buildAttachment(attachment, isMe, message))
                                          .toList(),
                                    ),
                                  ),

                                // 2. Content
                                if (hasContent)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: mediaAttachments.isNotEmpty ? 8.0 : 0,
                                      left: 4.0,
                                      right: 4.0,
                                      bottom: 4.0,
                                    ),
                                    child: Text(
                                      message['content'],
                                      style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                                    ),
                                  ),

                                // 3. Other Attachments (Audio, Docs)
                                if (otherAttachments.isNotEmpty)
                                  ...otherAttachments.map((attachment) {
                                    return Padding(
                                      padding: EdgeInsets.only(top: hasContent || mediaAttachments.isNotEmpty ? 8.0 : 0),
                                      child: _buildAttachment(attachment, isMe, message),
                                    );
                                  }).toList(),

                                // 4. Timestamp and Status
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTimestamp(message['createdAt']),
                                        style: GoogleFonts.roboto(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 5),
                                        _buildStatusIcon(message),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ));
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
                  'Replying to ${_replyingToMessage!['sender']['name']}',
                  style: GoogleFonts.roboto(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  _replyingToMessage!['content'],
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
// force
  void _showMessageOptions(BuildContext context, Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Message Options', style: GoogleFonts.poppins(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(FeatherIcons.edit, color: Colors.white),
                title: Text('Edit Message', style: GoogleFonts.roboto(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showEditMessageDialog(context, message);
                },
              ),
              ListTile(
                leading: const Icon(FeatherIcons.trash2, color: Colors.redAccent),
                title: Text('Delete Message', style: GoogleFonts.roboto(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(context).pop();
                  _dataController.deleteMessage(widget.conversationId, message['_id']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditMessageDialog(BuildContext context, Map<String, dynamic> message) {
    final TextEditingController editController = TextEditingController(text: message['content']);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Edit Message', style: GoogleFonts.poppins(color: Colors.white)),
          content: TextField(
            controller: editController,
            style: GoogleFonts.roboto(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter new message',
              hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save', style: GoogleFonts.roboto(color: Colors.tealAccent)),
              onPressed: () {
                _dataController.editMessage(widget.conversationId, message['_id'], editController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showPermissionDialog(
          'Microphone Permission Required',
          'Please grant microphone permission to record audio.',
          openSettings: status.isPermanentlyDenied,
        );
        return;
      }
    }

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      _isRecording.value = true;
      _recordingDuration.value = 0;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration.value++;
      });
      _pulseController.forward();
    } catch (e) {
      _showPermissionDialog('Recording Error', 'Failed to start audio recording: $e');
    }
  }

  Future<void> _stopAudioRecording() async {
    _recordingTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        await _playbackController.preparePlayer(path: path);
        setState(() {
          _recordedAudioPath = path;
        });
      }
    } catch (e) {
      _showPermissionDialog('Recording Error', 'Failed to stop audio recording: $e');
    } finally {
      _isRecording.value = false;
      _pulseController.reset();
    }
  }

  Future<void> _cancelAudioRecording() async {
    _recordingTimer?.cancel();
    try {
      await _audioRecorder.stop(); // Stop and discard
    } catch (e) {
      // Ignore errors on cancel, maybe log them
      print("Error stopping recorder on cancel: $e");
    } finally {
      _isRecording.value = false;
      _pulseController.reset();
      _recordingDuration.value = 0;
      setState(() {
        _recordedAudioPath = null;
      });
    }
  }

  void _sendVoiceMessage() {
    if (_recordedAudioPath == null) return;

    final file = File(_recordedAudioPath!);
    final String filename = p.basename(file.path);
    final attachment = {
      'type': 'audio',
      'path': _recordedAudioPath,
      'file': file,
      'filename': filename,
      'isUploading': true,
    };

    // Clear the recorded audio path and rebuild UI
    setState(() {
      _pendingAttachments.add(attachment);
      _recordedAudioPath = null;
    });

    // Send the message with the attachment
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
          Expanded(
            child: AudioFileWaveforms(
              size: Size(MediaQuery.of(context).size.width, 50.0),
              playerController: _playbackController,
              playerWaveStyle: const PlayerWaveStyle(
                fixedWaveColor: Colors.white54,
                liveWaveColor: Colors.white,
                spacing: 6.0,
                showSeekLine: false,
              ),
              waveformType: WaveformType.long,
              continuousWaveform: true,
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

  Widget _buildStatusIcon(Map<String, dynamic> message) {
    final status = message['status'] as String?;
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, color: Colors.blue, size: 16);
      case 'delivered':
        return const Icon(Icons.done_all, color: Colors.white, size: 16);
      case 'sent':
        return const Icon(Icons.done, color: Colors.white, size: 16);
      case 'sending':
        return const Icon(Icons.watch_later_outlined, color: Colors.white, size: 16);
      default:
        return const SizedBox.shrink();
    }
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
                    attachment['file'],
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

  Widget _buildAttachment(Map<String, dynamic> attachment, bool isMe, Map<String, dynamic> message) {
    final String type = attachment['type'] ?? 'document';
    final String? url = attachment['url'];
    final String? localPath = attachment['path'];
    final bool isUploading = attachment['isUploading'] ?? false;
    final String filename = attachment['filename'] ?? 'file';

    Widget placeholder(Widget? icon) {
      return Container(
        height: isUploading ? 80 : 60,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon != null) ...[icon, const SizedBox(width: 12)],
            Expanded(
              child: Text(
                filename,
                style: GoogleFonts.roboto(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isUploading) const SizedBox(width: 12),
            if (isUploading) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
          ],
        ),
      );
    }

    switch (type) {
      case 'image':
        if (localPath != null && isUploading) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.file(File(localPath), height: 250, width: double.infinity, fit: BoxFit.cover),
                Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        if (url != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(height: 250, color: Colors.grey[900], child: const Center(child: CircularProgressIndicator())),
              errorWidget: (context, url, error) => placeholder(Icon(FeatherIcons.alertTriangle, color: Colors.redAccent)),
            ),
          );
        }
        break;
      case 'video':
        // For now, videos, audio and documents will use the same placeholder.
        // A future step would be to implement video thumbnails and players.
        return placeholder(const Icon(FeatherIcons.video, color: Colors.white, size: 28));
      case 'audio':
        final post = {
          'attachments': message['attachments'],
          'content': message['content'],
          'username': message['sender']['name'],
          'useravatar': message['sender']['avatar'],
          'timestamp': message['createdAt'],
          'viewsCount': 0,
          'likesCount': 0,
          'repostsCount': 0,
        };
        return AudioAttachmentWidget(
          key: Key(attachment['url'] ?? attachment['path']),
          attachment: attachment,
          post: post,
          borderRadius: BorderRadius.circular(12.0),
        );
      case 'document':
      default:
        return placeholder(const Icon(FeatherIcons.fileText, color: Colors.white, size: 28));
    }
    // Fallback for any unhandled case
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: placeholder(const Icon(FeatherIcons.file, color: Colors.grey)),
    );
  }
}