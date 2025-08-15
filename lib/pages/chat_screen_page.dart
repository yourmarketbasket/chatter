import 'dart:io';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/chat_models.dart';
import 'package:chatter/widgets/message_input_area.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DataController dataController = Get.find<DataController>();
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    // Fetch messages for this chat when the screen loads
    dataController.fetchMessages(widget.chat.id);
  }

  @override
  void dispose() {
    // Clear the messages for the current conversation when leaving the screen
    dataController.currentConversationMessages.clear();
    super.dispose();
  }

  void _editMessage(ChatMessage message) {
    final editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(hintText: 'Edit your message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement message editing logic in DataController
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(ChatMessage message) {
    // TODO: Implement message deletion logic in DataController
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              if (message.senderId == dataController.user.value['user']['_id']) {
                _editMessage(message);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteMessage(message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.thumb_up),
            title: const Text('React'),
            onTap: () {
              Navigator.pop(context);
              // Reaction logic to be implemented
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(ChatMessage replyTo) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Replying to: ${replyTo.text}',
              style: TextStyle(color: Colors.grey[400]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment(ChatMessage message) {
    if (message.attachments == null || message.attachments!.isEmpty) {
      return const SizedBox.shrink();
    }

    // For now, we only display the first attachment.
    final attachment = message.attachments!.first;
    final attachmentType = attachment.type?.toLowerCase();

    // In a real app, you would have a more robust way to check if the URL is local or remote.
    final isLocalFile = !attachment.url.startsWith('http');

    switch (attachmentType) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: isLocalFile
                  ? FileImage(File(attachment.url))
                  : NetworkImage(attachment.url) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        );
      case 'mp4':
        return VideoPlayerWidget(videoUrl: attachment.url, isLocal: isLocalFile);
      default:
        // Generic file attachment
        return Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  attachment.filename,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildMessageContent(ChatMessage message, int index) {
    final isYou = message.senderId == dataController.user.value['user']['_id'];
    final messages = dataController.currentConversationMessages;
    final isSameSenderAsNext = index > 0 && messages[index - 1].senderId == message.senderId;
    final bottomMargin = isSameSenderAsNext ? 2.0 : 8.0;
    final hasAttachment = message.attachments != null && message.attachments!.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Dismissible(
        key: Key(message.id),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          setState(() {
            _replyingTo = message;
          });
          return false;
        },
        background: Container(
          color: Colors.tealAccent.withOpacity(0.5),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16.0),
          child: const Icon(Icons.reply, color: Colors.white),
        ),
        child: Container(
          margin: EdgeInsets.only(bottom: bottomMargin),
          padding: const EdgeInsets.all(12.0),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isYou ? Colors.tealAccent.withOpacity(0.2) : Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: isYou ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (widget.chat.isGroup && !isYou)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    // TODO: Resolve sender name from ID
                    message.senderId,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (message.voiceNote != null)
                AudioPlayerWidget(
                  audioUrl: message.voiceNote!.url,
                  isLocal: true, // Voice notes are always local initially
                ),
              if (hasAttachment) ...[
                _buildAttachment(message),
                if (message.text != null && message.text!.isNotEmpty)
                  const SizedBox(height: 8),
              ],
              if (message.text != null && message.text!.isNotEmpty)
                Text(
                  message.text!,
                  style: TextStyle(color: isYou ? Colors.white : Colors.grey[200]),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${message.createdAt.hour}:${message.createdAt.minute}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                  if (isYou) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _getStatusIcon(message.status),
                      size: 12,
                      color: _getStatusColor(message.status),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.read:
        return Colors.tealAccent;
      case MessageStatus.failed:
        return Colors.red;
      default:
        return Colors.grey[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the user to display for a 1-on-1 chat
    final otherUser = widget.chat.isGroup
        ? null
        : widget.chat.participants.firstWhere(
            (p) => p.id != dataController.user.value['user']['_id'],
            orElse: () => widget.chat.participants.first, // Fallback
          );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.tealAccent,
                  // Use group avatar or other user's avatar
                  backgroundImage: (widget.chat.isGroup
                          ? widget.chat.groupAvatar
                          : otherUser?.avatar) !=
                      null
                      ? NetworkImage((widget.chat.isGroup
                          ? widget.chat.groupAvatar
                          : otherUser!.avatar)!)
                      : null,
                  child: (widget.chat.isGroup
                              ? widget.chat.groupAvatar
                              : otherUser?.avatar) ==
                          null
                      ? Text(
                          widget.chat.isGroup
                              ? (widget.chat.groupName?[0] ?? '?')
                              : (otherUser?.name[0] ?? '?'),
                          style: const TextStyle(color: Colors.black),
                        )
                      : null,
                ),
                if (!widget.chat.isGroup && (otherUser?.online ?? false))
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              widget.chat.isGroup ? widget.chat.groupName! : otherUser!.name,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (dataController.isLoadingMessages.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                itemCount: dataController.currentConversationMessages.length,
                itemBuilder: (context, index) {
                  final message = dataController.currentConversationMessages[index];
                  return Align(
                    alignment: message.senderId == dataController.user.value['user']['_id']
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: _buildMessageContent(message, index),
                  );
                },
              );
            }),
          ),
          if (_replyingTo != null) _buildReplyPreview(_replyingTo!),
          MessageInputArea(
            onSendMessage: (text) {
              final message = ChatMessage(
                chatId: widget.chat.id,
                senderId: dataController.user.value['user']['_id'],
                text: text,
                replyTo: _replyingTo?.id,
              );
              dataController.sendChatMessage(message);
              setState(() {
                _replyingTo = null;
              });
            },
            onSendAttachments: (files) {
              for (final file in files) {
                // This is a temporary way to create an attachment.
                // In a real app, you would upload the file to a server first.
                final attachment = Attachment(
                  filename: file.name,
                  url: file.path!, // Using local path for now
                  size: file.size,
                  type: file.extension ?? 'file',
                );
                final message = ChatMessage(
                  chatId: widget.chat.id,
                  senderId: dataController.user.value['user']['_id'],
                  attachments: [attachment],
                  text: '', // Or maybe the filename?
                );
                dataController.sendChatMessage(message);
              }
            },
            onSendVoiceNote: (path, duration) {
              final voiceNote = VoiceNote(
                url: path,
                duration: duration,
              );
              final message = ChatMessage(
                chatId: widget.chat.id,
                senderId: dataController.user.value['user']['_id'],
                voiceNote: voiceNote,
              );
              dataController.sendChatMessage(message);
            },
          ),
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isLocal;

  const VideoPlayerWidget({super.key, required this.videoUrl, this.isLocal = false});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isLocal) {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    }
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                ),
              ],
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isLocal;

  const AudioPlayerWidget({super.key, required this.audioUrl, this.isLocal = false});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _play() {
    if (widget.isLocal) {
      _audioPlayer.play(DeviceFileSource(widget.audioUrl));
    } else {
      _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                _play();
              }
            },
          ),
          Expanded(
            child: Slider(
              value: _position.inSeconds.toDouble(),
              min: 0.0,
              max: _duration.inSeconds.toDouble(),
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
              },
            ),
          ),
        ],
      ),
    );
  }
}