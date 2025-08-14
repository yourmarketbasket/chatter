import 'dart:async';

import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/participant_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:chatter/services/socket-service.dart';

class ConversationPage extends StatefulWidget {
  final String chatId;
  final ParticipantModel receiver;

  const ConversationPage({
    Key? key,
    required this.chatId,
    required this.receiver,
  }) : super(key: key);

  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final DataController _dataController = Get.find<DataController>();
  final SocketService _socketService = Get.find<SocketService>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _dataController.fetchMessages(widget.chatId);
    _messageController.addListener(_handleTyping);
  }

  void _handleTyping() {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _socketService.typing(widget.chatId, _dataController.user.value['user']);

    _typingTimer = Timer(const Duration(seconds: 2), () {
      _socketService.stopTyping(widget.chatId, _dataController.user.value['user']);
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleTyping);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _dataController.messages.clear();
    _dataController.currentChatId.value = '';
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    _dataController.sendChatMessage(
      _messageController.text.trim(),
      widget.chatId,
      widget.receiver.id,
    );
    _messageController.clear();
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
    final String currentUserId = _dataController.user.value['user']['_id'];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Obx(() {
          final isOnline = _dataController.onlineUsers.contains(widget.receiver.id);
          return Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: CachedNetworkImageProvider(widget.receiver.avatar),
                backgroundColor: Colors.grey[800],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiver.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18),
                  ),
                  if (isOnline)
                    Text(
                      'Online',
                      style: GoogleFonts.roboto(color: Colors.green, fontSize: 12),
                    ),
                ],
              ),
            ],
          );
        }),
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.moreVertical, color: Colors.white),
            onPressed: () {
              // TODO: Implement more options
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
              final messages = _dataController.messages;
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
                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final bool isMe = message.sender.id == currentUserId;
                  if (!message.isRead && !isMe) {
                    _socketService.markAsRead(message.id, widget.chatId, currentUserId);
                  }
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.tealAccent.withOpacity(0.8) : Colors.grey[800],
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        message.content,
                        style: GoogleFonts.roboto(color: isMe ? Colors.black : Colors.white, fontSize: 15),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          Obx(() {
            final isTyping = _dataController.typingUsers['${widget.chatId}-${widget.receiver.id}'] ?? false;
            if (isTyping) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      '${widget.receiver.name} is typing...',
                      style: GoogleFonts.roboto(color: Colors.grey[500], fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          _buildMessageInputField(),
        ],
      ),
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
            onPressed: () {
              // TODO: Implement attachment picking
            },
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
                  borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(FeatherIcons.send, color: Colors.tealAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
