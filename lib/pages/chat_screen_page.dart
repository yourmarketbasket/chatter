import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/models/chat_models.dart';
import 'package:chatter/models/feed_models.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:chatter/pages/media_view_page.dart';
import 'package:get/get.dart';
import 'package:chatter/widgets/message_input_area.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    // Fetch messages for this chat when the screen loads
    dataController.fetchMessages(widget.chat.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    // Clear the messages for the current conversation when leaving the screen
    dataController.currentConversationMessages.clear();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      final message = ChatMessage(
        chatId: widget.chat.id,
        senderId: dataController.user.value['user']['_id'],
        text: _messageController.text.trim(),
        replyTo: _replyingTo?.id,
      );
      dataController.sendChatMessage(message);
      _messageController.clear();
      setState(() {
        _replyingTo = null;
      });
    }
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
              if (editController.text.trim().isNotEmpty) {
                dataController.editChatMessage(message.id, editController.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(ChatMessage message) {
    dataController.deleteChatMessage(message.id);
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

  void _openMediaView(ChatMessage message, int initialIndex) {
    final attachmentsForViewer = message.attachments!
        .map((att) => {
              'url': att.url,
              'type': att.type,
              'filename': att.filename,
            })
        .toList();

    final sender = widget.chat.participants.firstWhere(
      (p) => p.id == message.senderId,
      // Fallback for safety, though sender should always be in participants
      orElse: () => ChatUser(id: message.senderId, name: 'Unknown User'),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewPage(
          attachments: attachmentsForViewer,
          initialIndex: initialIndex,
          message: message.text ?? '',
          userName: sender.name,
          userAvatarUrl: sender.avatar,
          timestamp: message.createdAt,
          viewsCount: 0,
          likesCount: 0,
          repostsCount: 0,
        ),
      ),
    );
  }

  Widget _buildAttachment(ChatMessage message) {
    if (message.attachments == null || message.attachments!.isEmpty) {
      return const SizedBox.shrink();
    }

    final attachments = message.attachments!;
    const maxVisible = 4;
    final hasMore = attachments.length > maxVisible;
    final gridItemCount = hasMore ? maxVisible : attachments.length;
    // Dynamic cross-axis count for better layout
    final crossAxisCount = attachments.length == 1 ? 1 : 2;
    // For a single image, use a portrait-ish aspect ratio. For a grid, use squares.
    final aspectRatio = attachments.length == 1 ? 3 / 4 : 1.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: aspectRatio,
      ),
      itemCount: gridItemCount,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        final isLocalFile = !attachment.url.startsWith('http');

        // The last grid item, if there are more attachments to show
        if (hasMore && index == maxVisible - 1) {
          final remainingCount = attachments.length - maxVisible + 1;
          return GestureDetector(
            onTap: () => _openMediaView(message, index),
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                _buildAttachmentContent(attachment, isLocalFile),
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Text(
                      '+$remainingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Regular attachment item
        final attachmentType = attachment.type?.toLowerCase();
        // Assuming 'file' is a generic type for other downloadable files
        final isDownloadable = attachmentType == 'pdf' || attachmentType == 'file';

        return GestureDetector(
          onTap: () {
            if (isDownloadable && !attachment.isDownloading) {
              dataController.handleFileAttachmentTap(message.id, attachment.id);
            } else if (!isDownloadable) {
              _openMediaView(message, index);
            }
          },
          child: _buildAttachmentContent(attachment, isLocalFile),
        );
      },
    );
  }

  Widget _buildAttachmentContent(Attachment attachment, bool isLocalFile) {
    final attachmentType = attachment.type?.toLowerCase();

    final uploadOverlay = attachment.isUploading
        ? Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: attachment.uploadProgress,
                  strokeWidth: 2,
                  backgroundColor: Colors.grey.withOpacity(0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    Widget content;
    switch (attachmentType) {
      case 'image':
        content = Container(
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
        break;
      case 'video':
        content = VideoPlayerWidget(videoUrl: attachment.url, isLocal: isLocalFile);
        break;
      case 'audio':
        content = AudioPlayerWidget(audioUrl: attachment.url, isLocal: isLocalFile);
        break;
      case 'pdf':
        content = Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.white),
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
        break;
      default:
        // Generic file attachment
        content = Container(
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
        break;
    }

    final downloadOverlay = attachment.isDownloading
        ? Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: attachment.downloadProgress,
                  strokeWidth: 2,
                  backgroundColor: Colors.grey.withOpacity(0.5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        uploadOverlay,
        downloadOverlay,
      ],
    );
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
              if (message.voiceNote != null)
                GestureDetector(
                  onTap: () {
                    final attachmentsForViewer = [
                      {
                        'url': message.voiceNote!.url,
                        'type': 'audio',
                        'filename': message.voiceNote!.url.split('/').last,
                      }
                    ];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MediaViewPage(
                          attachments: attachmentsForViewer,
                          initialIndex: 0,
                          message: '',
                          userName: widget.chat.isGroup ? message.senderId : widget.chat.participants.firstWhere((p) => p.id != dataController.user.value['user']['_id']).name,
                          userAvatarUrl: null,
                          timestamp: message.createdAt,
                          viewsCount: 0,
                          likesCount: 0,
                          repostsCount: 0,
                        ),
                      ),
                    );
                  },
                  child: AudioPlayerWidget(
                    audioUrl: message.voiceNote!.url,
                    isLocal: true, // Voice notes are always local initially
                  ),
                ),
              if (hasAttachment) ...[
                _buildAttachment(message),
                if (message.text != null && message.text!.isNotEmpty)
                  const SizedBox(height: 8),
              ],
              if (message.deleted)
                Text(
                  'Message deleted',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (message.text != null && message.text!.isNotEmpty)
                Text(
                  message.text!,
                  style: TextStyle(color: isYou ? Colors.white : Colors.grey[200]),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.edited)
                    Text(
                      '(edited) ',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
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

  String _getMediaType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video';
      case 'mp3':
      case 'wav':
      case 'm4a':
        return 'audio';
      case 'pdf':
        return 'pdf';
      default:
        return 'file';
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = widget.chat.isGroup
        ? null
        : widget.chat.participants.firstWhere(
            (p) => p.id != dataController.user.value['user']['_id'],
            orElse: () => widget.chat.participants.first,
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
                  backgroundImage: (widget.chat.isGroup ? widget.chat.groupAvatar : otherUser?.avatar) != null
                      ? NetworkImage((widget.chat.isGroup ? widget.chat.groupAvatar : otherUser!.avatar)!)
                      : null,
                  child: (widget.chat.isGroup ? widget.chat.groupAvatar : otherUser?.avatar) == null
                      ? Text(
                          widget.chat.isGroup ? (widget.chat.groupName?[0] ?? '?') : (otherUser?.name[0] ?? '?'),
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
            onSend: (text, files) {
              final attachments = files
                  .map((file) => Attachment(
                        filename: file.name,
                        url: file.path!,
                        size: file.size,
                        type: _getMediaType(file.extension ?? ''),
                      ))
                  .toList();

              final isVoiceNote = attachments.isNotEmpty && attachments.first.type == 'audio';

              final message = ChatMessage(
                chatId: widget.chat.id,
                senderId: dataController.user.value['user']['_id'],
                text: text,
                attachments: isVoiceNote ? null : attachments,
                voiceNote: isVoiceNote ? VoiceNote(url: attachments.first.url, duration: Duration.zero) : null,
                replyTo: _replyingTo?.id,
              );

              dataController.sendChatMessage(message);

              setState(() {
                _replyingTo = null;
              });
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