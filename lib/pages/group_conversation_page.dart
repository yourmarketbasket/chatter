import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupChatScreen extends StatefulWidget {
  final Map<String, dynamic> groupChat;

  const GroupChatScreen({super.key, required this.groupChat});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  Map<String, dynamic>? _replyingTo;
  int _messageIdCounter = 11; // Starting after dummy messages

  final List<Map<String, dynamic>> _messages = [
    {
      '_id': '1',
      'message': 'Let\'s plan the trip!',
      'sender': 'Alice',
      'senderInitials': 'A',
      'time': '11:45 AM',
      'status': 'read',
      'edited': false,
      'deleted': false,
      'attachment': null,
      'attachmentType': null,
      'replyTo': null,
    },
    {
      '_id': '2',
      'message': 'Sounds good! I’ll bring snacks.',
      'sender': 'You',
      'senderInitials': 'Y',
      'time': '11:47 AM',
      'status': 'delivered',
      'edited': true,
      'deleted': false,
      'attachment': null,
      'attachmentType': null,
      'replyTo': null,
    },
    {
      '_id': '3',
      'message': 'Check this itinerary image!',
      'sender': 'Bob',
      'senderInitials': 'B',
      'time': '11:50 AM',
      'status': 'sent',
      'edited': false,
      'deleted': false,
      'attachment': 'https://picsum.photos/id/237/200/300',
      'attachmentType': 'image',
      'replyTo': null,
    },
    {
      '_id': '4',
      'message': 'Message deleted',
      'sender': 'Charlie',
      'senderInitials': 'C',
      'time': '11:55 AM',
      'status': 'read',
      'edited': false,
      'deleted': true,
      'attachment': null,
      'attachmentType': null,
      'replyTo': null,
    },
    {
      '_id': '5',
      'message': 'Found a cool GIF for the trip!',
      'sender': 'Alice',
      'senderInitials': 'A',
      'time': '12:00 PM',
      'status': 'read',
      'edited': false,
      'deleted': false,
      'attachment': 'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif',
      'attachmentType': 'gif',
      'replyTo': null,
    },
    {
      '_id': '6',
      'message': 'Here’s a video of the destination!',
      'sender': 'You',
      'senderInitials': 'Y',
      'time': '12:05 PM',
      'status': 'sent',
      'edited': false,
      'deleted': false,
      'attachment': 'https://www.w3schools.com/html/mov_bbb.mp4',
      'attachmentType': 'video',
      'replyTo': null,
    },
    {
      '_id': '7',
      'message': 'Listen to this audio guide.',
      'sender': 'Bob',
      'senderInitials': 'B',
      'time': '12:10 PM',
      'status': 'read',
      'edited': false,
      'deleted': false,
      'attachment': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'attachmentType': 'audio',
      'replyTo': null,
    },
    {
      '_id': '8',
      'message': 'Here’s the trip itinerary PDF.',
      'sender': 'Charlie',
      'senderInitials': 'C',
      'time': '12:15 PM',
      'status': 'sent',
      'edited': false,
      'deleted': false,
      'attachment': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      'attachmentType': 'pdf',
      'replyTo': null,
    },
    {
      '_id': '9',
      'message': 'Drafted a plan in this Word doc.',
      'sender': 'Alice',
      'senderInitials': 'A',
      'time': '12:20 PM',
      'status': 'read',
      'edited': false,
      'deleted': false,
      'attachment': 'https://www.learningcontainer.com/wp-content/uploads/2020/02/sample-doc-file.doc',
      'attachmentType': 'doc',
      'replyTo': null,
    },
    {
      '_id': '10',
      'message': 'Looks good, let’s finalize it!',
      'sender': 'You',
      'senderInitials': 'Y',
      'time': '12:25 PM',
      'status': 'sent',
      'edited': false,
      'deleted': false,
      'attachment': null,
      'attachmentType': null,
      'replyTo': {'_id': '8', 'sender': 'Charlie', 'message': 'Here’s the trip itinerary PDF.', 'deleted': false},
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add({
          '_id': (_messageIdCounter++).toString(),
          'message': _messageController.text.trim(),
          'sender': 'You',
          'senderInitials': 'Y',
          'time': 'Now',
          'status': 'sent',
          'edited': false,
          'deleted': false,
          'attachment': null,
          'attachmentType': null,
          'replyTo': _replyingTo,
        });
        _messageController.clear();
        _replyingTo = null;
      });
    }
  }

  void _editMessage(Map<String, dynamic> message) {
    final editController = TextEditingController(text: message['message']);
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
                setState(() {
                  message['message'] = editController.text.trim();
                  message['edited'] = true;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(Map<String, dynamic> message) {
    setState(() {
      message['deleted'] = true;
      message['message'] = 'Message deleted';
      message['attachment'] = null;
      message['attachmentType'] = null;
    });
  }

  void _showMessageOptions(Map<String, dynamic> message) {
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
              if (message['sender'] == 'You' && !message['deleted']) {
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
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reactions'),
                  content: const Text('Reactions coming soon!'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(Map<String, dynamic> replyTo) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Replying to ${replyTo['sender']}: ${replyTo['deleted'] ? 'Message deleted' : replyTo['message']}',
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

  Widget _buildAttachment(Map<String, dynamic> message) {
    final attachment = message['attachment'];
    final attachmentType = message['attachmentType'];

    switch (attachmentType) {
      case 'image':
      case 'gif':
        return Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(attachment),
              fit: BoxFit.cover,
            ),
          ),
        );
      case 'video':
        return VideoPlayerWidget(videoUrl: attachment);
      case 'audio':
        return AudioPlayerWidget(audioUrl: attachment);
      case 'pdf':
        return GestureDetector(
          onTap: () async {
            final url = Uri.parse(attachment);
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Container(
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
                const Text(
                  'PDF Document',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      case 'doc':
        return GestureDetector(
          onTap: () async {
            final url = Uri.parse(attachment);
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Word Document',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMessageContent(Map<String, dynamic> message, int index) {
    final isYou = message['sender'] == 'You';
    final isLastMessage = index == 0;
    final nextMessageIndex = _messages.length - index;
    final isSameSenderAsNext = !isLastMessage &&
        _messages[nextMessageIndex]['sender'] == message['sender'];
    final bottomMargin = isSameSenderAsNext ? 2.0 : 8.0;
    final hasAttachment = message['attachment'] != null && !message['deleted'];
    final padding = hasAttachment
        ? const EdgeInsets.symmetric(horizontal: 2.4, vertical: 12.0) // 80% reduction from 12.0
        : const EdgeInsets.all(12.0);

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Dismissible(
        key: Key(message['_id']),
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
          padding: padding,
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
              if (!isYou)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    message['sender'],
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (message['replyTo'] != null)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  margin: const EdgeInsets.only(bottom: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${message['replyTo']['sender']}: ${message['replyTo']['deleted'] ? 'Message deleted' : message['replyTo']['message']}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (message['deleted'])
                Text(
                  'Message deleted',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (hasAttachment)
                Column(
                  crossAxisAlignment: isYou ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    _buildAttachment(message),
                    if (message['message'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          message['message'],
                          style: TextStyle(color: isYou ? Colors.white : Colors.grey[200]),
                        ),
                      ),
                  ],
                )
              else
                Text(
                  message['message'],
                  style: TextStyle(color: isYou ? Colors.white : Colors.grey[200]),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message['time'],
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                  if (isYou) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _getStatusIcon(message['status']),
                      size: 12,
                      color: _getStatusColor(message['status']),
                    ),
                  ],
                  if (message['edited']) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(edited)',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      default:
        return Icons.access_time;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'read':
        return Colors.tealAccent;
      default:
        return Colors.grey[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupChat['name'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            Text(
              '${widget.groupChat['participants'].length} participants',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
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
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return Align(
                  alignment: message['sender'] == 'You' ? Alignment.centerRight : Alignment.centerLeft,
                  child: _buildMessageContent(message, index),
                );
              },
            ),
          ),
          if (_replyingTo != null) _buildReplyPreview(_replyingTo!),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.tealAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
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
        ? Container(
            width: 150,
            height: 150,
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
        : Container(
            width: 150,
            height: 150,
            child: const Center(child: CircularProgressIndicator()),
          );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;

  const AudioPlayerWidget({super.key, required this.audioUrl});

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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
                await _audioPlayer.play(UrlSource(widget.audioUrl));
              }
            },
          ),
          const Text(
            'Audio File',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}