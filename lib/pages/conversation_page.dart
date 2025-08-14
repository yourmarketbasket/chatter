import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/services/socket-service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';

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

class _ConversationPageState extends State<ConversationPage> {
  final DataController _dataController = Get.find<DataController>();
  final SocketService _socketService = Get.find<SocketService>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    // Fetch messages for this conversation
    _dataController.getMessagesForChat(widget.conversationId).catchError((e) {
      Get.snackbar('Error', 'Could not load messages: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    });
    _socketService.joinChat(widget.conversationId);
  }

  List<Map<String, dynamic>> _attachments = [];
  Map<String, dynamic>? _replyingToMessage;

  void _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      // This is a simplified version. In a real app, you would show a loading indicator
      // and handle errors from the upload service.
      final uploadResult = await _dataController.uploadFiles([
        {'type': 'file', 'file': file}
      ]);

      if (uploadResult.isNotEmpty && uploadResult[0]['success']) {
        setState(() {
          _attachments.add({
            'type': 'file', // Or determine from file type
            'url': uploadResult[0]['url'],
            'filename': result.files.single.name,
          });
        });
      } else {
        Get.snackbar('Error', 'File upload failed.');
      }
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty && _attachments.isEmpty) return;

    final messagePayload = {
      'sender': _dataController.user.value['user']['_id'],
      'receiver': widget.receiverId,
      'chat': widget.conversationId,
      'content': _messageController.text.trim(),
      'attachments': _attachments,
      'replyTo': _replyingToMessage?['_id'],
    };
    _socketService.sendMessage(messagePayload);

    _messageController.clear();
    setState(() {
      _attachments = [];
      _replyingToMessage = null;
    });
    // Scroll to bottom after sending
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
              backgroundImage: CachedNetworkImageProvider(widget.userAvatar),
              backgroundColor: Colors.grey[800],
            ),
            const SizedBox(width: 12),
            Text(
              widget.username,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18),
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
              // Scroll to bottom when messages load for the first time or when new messages arrive
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                   _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final bool isMe = message['sender']['_id'] == currentUserId;

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
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.tealAccent.withOpacity(0.8) : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message['content'] != null && message['content'].isNotEmpty)
                                Text(
                                  message['content'],
                                  style: GoogleFonts.roboto(color: isMe ? Colors.black : Colors.white, fontSize: 15),
                                ),
                              if (message['attachments'] != null && (message['attachments'] as List).isNotEmpty)
                                ... (message['attachments'] as List).map((attachment) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      attachment['filename'] ?? 'Attachment',
                                      style: GoogleFonts.roboto(
                                        color: isMe ? Colors.black : Colors.white,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                  ),
                                  );
                                }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          if (_replyingToMessage != null) _buildReplyContext(),
          _buildMessageInputField(),
        ],
      ),
    );
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

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.grey[850]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(FeatherIcons.paperclip, color: Colors.grey[400]),
            onPressed: _pickAndUploadFile,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
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
                  borderSide: BorderSide(color: Colors.tealAccent, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Obx(() => IconButton(
                icon: Icon(
                  _messageController.text.isEmpty ? FeatherIcons.mic : FeatherIcons.send,
                  color: Colors.tealAccent,
                ),
                onPressed: () async {
                  if (_messageController.text.isEmpty) {
                    if (_isRecording) {
                      final path = await _audioRecorder.stop();
                      if (path != null) {
                        final file = File(path);
                        final uploadResult = await _dataController.uploadFiles([
                          {'type': 'audio', 'file': file}
                        ]);

                        if (uploadResult.isNotEmpty && uploadResult[0]['success']) {
                          final attachment = {
                            'type': 'audio',
                            'url': uploadResult[0]['url'],
                            'filename': 'voice_note.m4a',
                          };
                          _attachments.add(attachment);
                          _sendMessage();
                        } else {
                          Get.snackbar('Error', 'Failed to upload voice note.');
                        }
                      }
                      setState(() {
                        _isRecording = false;
                      });
                    } else {
                      if (await _audioRecorder.hasPermission()) {
                        await _audioRecorder.start(const RecordConfig(), path: 'audio_record.m4a');
                        setState(() {
                          _isRecording = true;
                        });
                      }
                    }
                  } else {
                    _sendMessage();
                  }
                },
              )),
        ],
      ),
    );
  }
}
