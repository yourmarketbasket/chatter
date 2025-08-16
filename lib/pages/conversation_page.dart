import 'dart:async';
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

  const ConversationPage({
    Key? key,
    required this.conversationId,
    required this.username,
    required this.userAvatar,
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
    // Fetch messages for this conversation
    _dataController.fetchMessages(widget.conversationId).catchError((e) {
      Get.snackbar('Error', 'Could not load messages: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    });

    _messageController.addListener(_onTyping);
  }

  void _onTyping() {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _socketService.sendTypingStart(widget.conversationId);
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _socketService.sendTypingStop(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTyping);
    _typingTimer?.cancel();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      '_id': DateTime.now().millisecondsSinceEpoch.toString(),
      'chatId': widget.conversationId,
      'senderId': _dataController.user.value['user']['_id'], // Assuming user ID is here
      'text': _messageController.text.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    _dataController.sendChatMessage(message);

    _messageController.clear();
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
    // Determine current user ID for message alignment (assuming it's available in dataController.user)
    final String currentUserId = _dataController.user.value['id']?.toString() ?? 'currentUser';


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
          IconButton(
            icon: const Icon(FeatherIcons.moreVertical, color: Colors.white),
            onPressed: () {
              // TODO: Implement more options (e.g., view profile, block)
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
                  final bool isMe = message['senderId'] == currentUserId;
                  // Basic message bubble
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
                        message['text'] ?? '',
                        style: GoogleFonts.roboto(color: isMe ? Colors.black : Colors.white, fontSize: 15),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          Obx(() {
            final isTyping = _dataController.isTyping[widget.conversationId] ?? false;
            if (isTyping) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      '${widget.username} is typing...',
                      style: GoogleFonts.roboto(color: Colors.grey[400], fontStyle: FontStyle.italic),
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
                  borderSide: BorderSide(color: Colors.tealAccent, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(FeatherIcons.send, color: Colors.tealAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
