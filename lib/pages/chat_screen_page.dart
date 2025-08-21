import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:chatter/pages/media_view_page.dart';
import 'package:get/get.dart';
import 'package:chatter/widgets/message_input_area.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatter/widgets/video_player_widget.dart';
import 'package:chatter/widgets/audio_waveform_widget.dart';
import 'package:chatter/widgets/all_attachments_dialog.dart';
import 'package:chatter/widgets/reply_message_snippet.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DataController dataController = Get.find<DataController>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    if (dataController.currentChat.value['_id'] != null) {
      _loadMessagesAndMarkAsRead();
    } else {
      dataController.currentConversationMessages.clear();
    }
    dataController.currentConversationMessages.listen((_) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      _markVisibleMessagesAsRead();
    });
    _scrollController.addListener(_markVisibleMessagesAsRead);
  }

  void _loadMessagesAndMarkAsRead() async {
    await dataController.fetchMessages(dataController.currentChat.value['_id']!);
    _markVisibleMessagesAsRead();
  }

  void _markVisibleMessagesAsRead() {
    final currentUserId = dataController.getUserId();
    if (currentUserId == null) return;

    final unreadMessages = dataController.currentConversationMessages.where((msg) {
      final senderId = msg['senderId'] is Map ? msg['senderId']['_id'] : msg['senderId'];
      if (senderId == currentUserId) return false;

      final receipts = (msg['readReceipts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final isRead = receipts.any((r) => r['userId'] == currentUserId && r['status'] == 'read');
      return !isRead;
    }).toList();

    for (final message in unreadMessages) {
      dataController.markMessageAsRead(message);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_markVisibleMessagesAsRead);
    _scrollController.dispose();
    dataController.currentConversationMessages.clear();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(String? text, List<PlatformFile>? files, {bool isVoiceNote = false}) async {
    if ((text?.trim().isEmpty ?? true) && (files?.isEmpty ?? true)) {
      return;
    }

    final clientMessageId = const Uuid().v4();
    final messageType = isVoiceNote ? 'voice' : (files?.isNotEmpty ?? false) ? 'attachment' : 'text';
    final now = DateTime.now().toUtc();

    // Create a temporary message for optimistic UI update
    final tempMessage = {
      'clientMessageId': clientMessageId,
      'chatId': dataController.currentChat.value['_id'],
      'senderId': {
        '_id': dataController.user.value['user']['_id'],
        'name': dataController.user.value['user']['name'],
        'avatar': dataController.user.value['user']['avatar'],
      },
      'content': text?.trim() ?? '',
      'type': messageType,
      'files': files?.map((file) => {
            'url': file.path!,
            'type': isVoiceNote ? 'voice' : _getMediaType(file.extension ?? ''),
            'size': file.size,
            'filename': file.name,
            'isUploading': true,
            'uploadProgress': 0.0,
          }).toList() ?? [],
      'replyTo': _replyingTo?['_id'],
      'viewOnce': false,
      'createdAt': now.toIso8601String(),
      'status': 'sending',
    };
    // force

    // Add the temporary message to the UI
    dataController.addTemporaryMessage(tempMessage);
    _messageController.clear();
    

    List<Map<String, dynamic>> uploadedFiles = [];
    if (files != null && files.isNotEmpty) {
      final attachmentsData = files.map((file) {
        final fileType = isVoiceNote ? 'voice' : _getMediaType(file.extension ?? '');
        return {
          'file': File(file.path!),
          'type': fileType,
          'filename': file.name,
        };
      }).toList();

      final uploadResults = await dataController.uploadChatFiles(
        attachmentsData,
        (sentBytes, totalBytes) {
          final progress = totalBytes > 0 ? sentBytes / totalBytes : 0.0;
          dataController.updateUploadProgress(clientMessageId, progress);
        },
      );

      if (uploadResults.any((result) => !result['success'])) {
        dataController.updateMessageStatus(clientMessageId, 'failed');
        // Optionally, show an error message to the user
        return;
      }

      uploadedFiles = uploadResults.map((result) => {
        'url': result['url'],
        'type': result['type'],
        'size': result['size'],
        'filename': result['filename'],
      }).toList();
    }

    
    final finalMessage = {
      'clientMessageId': clientMessageId,
      'chatId': dataController.currentChat.value['_id'],
      'participants': dataController.currentChat.value['participants'],
      'senderId': {
        '_id': dataController.user.value['user']['_id'],
        'name': dataController.user.value['user']['name'],
        'avatar': dataController.user.value['user']['avatar'],
      },
      'content': text?.trim() ?? '',
      'type': messageType,
      'files': uploadedFiles,
      'replyTo': _replyingTo?['_id'],
      'viewOnce': false,
    };

    // Send the final message to the backend
    await dataController.sendChatMessage(finalMessage, clientMessageId);
    setState(() {
      _replyingTo = null;
    });
  }

  void _editMessage(Map<String, dynamic> message) {
    final editController = TextEditingController(text: message['content']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(hintText: 'Edit your message'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                dataController.editChatMessage(message['_id'], editController.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(Map<String, dynamic> message, {required bool forEveryone}) {
    dataController.deleteChatMessage(message['_id'], forEveryone: forEveryone);
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message['senderId']['_id'] == dataController.user.value['user']['_id'])
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete for me'),
            onTap: () {
              Navigator.pop(context);
              _deleteMessage(message, forEveryone: false);
            },
          ),
          if (message['senderId']['_id'] == dataController.user.value['user']['_id'])
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete for everyone'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message, forEveryone: true);
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

  Widget _buildReplyAttachmentPreview(Map<String, dynamic> attachment) {
    final extension = attachment['type']?.toLowerCase() ?? '';
    final isLocalFile = !(attachment['url'] as String).startsWith('http');
    Widget preview;

    switch (extension) {
      case 'image/jpeg':
      case 'image/png':
      case 'image':
        preview = Image(
          image: isLocalFile
              ? FileImage(File(attachment['url']))
              : NetworkImage(attachment['url']) as ImageProvider,
          fit: BoxFit.cover,
        );
        break;
      case 'video/mp4':
      case 'video':
        preview = const Icon(Icons.videocam, size: 24, color: Colors.white);
        break;
      case 'audio/mp3':
      case 'voice':
        preview = const Icon(Icons.audiotrack, size: 24, color: Colors.white);
        break;
      case 'application/pdf':
        preview =
            const Icon(Icons.picture_as_pdf, size: 24, color: Colors.white);
        break;
      default:
        preview =
            const Icon(Icons.insert_drive_file, size: 24, color: Colors.white);
    }
    return SizedBox(
        width: 40,
        height: 40,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(4), child: preview));
  }

  Widget _buildReplyPreview(Map<String, dynamic> replyTo) {
    final sender = (dataController.currentChat.value['participants'] as List)
        .firstWhere(
      (p) => p['_id'] == replyTo['senderId']['_id'],
      orElse: () => {'_id': replyTo['senderId']['_id'], 'name': 'Unknown User'},
    );
    final senderName = replyTo['senderId']['_id'] ==
            dataController.user.value['user']['_id']
        ? 'You'
        : sender['name'];

    Widget contentPreview;
    if (replyTo['files'] != null && (replyTo['files'] as List).isNotEmpty) {
      final firstAttachment = (replyTo['files'] as List).first;
      contentPreview = Row(
        children: [
          _buildReplyAttachmentPreview(firstAttachment),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              firstAttachment['type'].startsWith('image') ? 'Image' : firstAttachment['filename'],
              style: TextStyle(color: Colors.grey[300]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (replyTo['type'] == 'voice') {
      contentPreview = Row(
        children: [
          const Icon(Icons.audiotrack, size: 24, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'Voice note',
            style: TextStyle(color: Colors.grey[300]),
          ),
        ],
      );
    } else {
      contentPreview = Text(
        replyTo['content'] ?? '',
        style: TextStyle(color: Colors.grey[300]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      color: Colors.grey[900],
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withOpacity(0.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          border: const Border(
            left: BorderSide(color: Colors.tealAccent, width: 4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  contentPreview,
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => setState(() => _replyingTo = null),
            ),
          ],
        ),
      ),
    );
  }

  String _mapToSimpleType(String detailedType) {
    if (detailedType.startsWith('image')) return 'image';
    if (detailedType.startsWith('video')) return 'video';
    if (detailedType.startsWith('audio') || detailedType == 'voice') return 'audio';
    if (detailedType.startsWith('application/pdf')) return 'pdf';
    return 'unknown';
  }

  void _openMediaView(Map<String, dynamic> message, int initialIndex) {
    final attachmentsForViewer = (message['files'] as List)
        .map((att) => {
              'url': att['url'],
              'type': _mapToSimpleType(att['type']),
              'filename': att['filename'],
            })
        .toList();

    final senderId = message['senderId'] is Map
        ? message['senderId']['_id']
        : message['senderId'];

    final sender = (dataController.currentChat.value['participants'] as List)
        .firstWhere(
      (p) => p['_id'] == senderId,
      orElse: () => {'_id': senderId, 'name': 'Unknown User', 'avatar': ''},
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaViewPage(
          attachments: attachmentsForViewer,
          initialIndex: initialIndex,
          message: message['content'] ?? '',
          userName: sender['name'],
          userAvatarUrl: sender['avatar'],
          timestamp: DateTime.parse(message['createdAt']),
          viewsCount: 0,
          likesCount: 0,
          repostsCount: 0,
        ),
      ),
    );
  }

  Widget _buildAttachment(Map<String, dynamic> message) {
    return Obx(() {
      final updatedMessage = dataController.currentConversationMessages.firstWhere(
        (m) => m['clientMessageId'] == message['clientMessageId'],
        orElse: () => message,
      );

      if (updatedMessage['files'] == null || (updatedMessage['files'] as List).isEmpty) {
        return const SizedBox.shrink();
      }

      final attachments = updatedMessage['files'] as List;
      const maxVisible = 4;
      final hasMore = attachments.length > maxVisible;
      final gridItemCount = hasMore ? maxVisible : attachments.length;
      final crossAxisCount = attachments.length == 1 ? 1 : 2;
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
          final isLocalFile = !(attachment['url'] as String).startsWith('http');
        final attachmentKey = ValueKey('${updatedMessage['clientMessageId']}_$index');

          if (hasMore && index == maxVisible - 1) {
            final remainingCount = attachments.length - maxVisible + 1;
            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AllAttachmentsDialog(
                    message: updatedMessage,
                    chat: dataController.currentChat.value,
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                _buildAttachmentContent(attachment, isLocalFile, key: attachmentKey),
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

          return GestureDetector(
            onTap: () => _openMediaView(updatedMessage, index),
          child: _buildAttachmentContent(attachment, isLocalFile, key: attachmentKey),
          );
        },
      );
    });
  }

  Widget _buildAttachmentContent(Map<String, dynamic> attachment, bool isLocalFile, {Key? key}) {
    final attachmentType = attachment['type']?.toLowerCase();
    final simpleType = _mapToSimpleType(attachmentType ?? '');

    final uploadOverlay = (attachment['isUploading'] ?? false)
        ? Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: attachment['uploadProgress'],
                  strokeWidth: 2,
                  backgroundColor: Colors.grey.withOpacity(0.5),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    Widget content;
    switch (attachmentType) {
      case 'image/jpeg':
      case 'image/png':
        content = Container(
          key: key,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: isLocalFile
                  ? FileImage(File(attachment['url']))
                  : NetworkImage(attachment['url']) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        );
        break;
      case 'video/mp4':
        content = VideoPlayerWidget(
          key: key,
          url: isLocalFile ? null : attachment['url'],
          file: isLocalFile ? File(attachment['url']) : null,
        );
        break;
      case 'audio/mp3':
      case 'voice':
        content = AudioWaveformWidget(
          audioPath: attachment['url'],
          isLocal: isLocalFile,
        );
        break;
      case 'application/pdf':
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
                  attachment['filename'],
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        break;
      default:
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
                  attachment['filename'],
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        break;
    }

    final downloadOverlay = (attachment['isDownloading'] ?? false)
        ? Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: attachment['downloadProgress'],
                  strokeWidth: 2,
                  backgroundColor: Colors.grey.withOpacity(0.5),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final fullViewIcon = simpleType != 'image'
        ? Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_full,
                color: Colors.white,
                size: 18,
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
        fullViewIcon,
      ],
    );
  }

 Widget _buildMessageContent(Map<String, dynamic> message, int index) {
  final senderId = message['senderId'] is Map ? message['senderId']['_id'] : message['senderId'];
  final isYou = senderId == dataController.user.value['user']['_id'];
  final messages = dataController.currentConversationMessages;
  final isSameSenderAsNext = index > 0 && (messages[index - 1]['senderId'] is Map ? messages[index - 1]['senderId']['_id'] : messages[index - 1]['senderId']) == senderId;
  final bottomMargin = isSameSenderAsNext ? 2.0 : 8.0;
  final hasAttachment = message['files'] != null && (message['files'] as List).isNotEmpty;

  // Determine sender name for display
  final sender = (dataController.currentChat.value['participants'] as List).firstWhere(
    (p) => p['_id'] == senderId,
    orElse: () => {'_id': senderId, 'name': 'Unknown User'},
  );
  final senderName = isYou ? 'You' : sender['name'];

  return GestureDetector(
    onLongPress: () {
      if (!(message['deletedForEveryone'] ?? false)) _showMessageOptions(message);
    },
    child: Dismissible(
      key: Key(message['clientMessageId'] ?? message['_id']),
      direction: (message['deletedForEveryone'] ?? false)
          ? DismissDirection.none
          : DismissDirection.startToEnd,
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
            // Display sender name for group chats
            if (dataController.currentChat.value['type'] == 'group' && !isYou)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            if (message['deletedForEveryone'] ?? false)
              Text(
                'Message deleted',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              )
            else ...[
              if (message['replyTo'] != null)
                Obx(() {
                  final originalMessage = dataController.currentConversationMessages.firstWhere(
                    (m) => m['_id'] == message['replyTo'],
                    orElse: () => {
                      '_id': '',
                      'senderId': {'_id': '', 'name': 'Unknown User'},
                      'content': 'Original message not found.',
                      'files': [],
                      'type': 'text',
                    },
                  );
                  if (originalMessage['_id'].isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[900]?.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(color: Colors.tealAccent, width: 4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          originalMessage['senderId']['_id'] == dataController.user.value['user']['_id']
                              ? 'You'
                              : (dataController.currentChat.value['participants'] as List).firstWhere(
                                  (p) => p['_id'] == originalMessage['senderId']['_id'],
                                  orElse: () => {'name': 'Unknown User'},
                                )['name'],
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (originalMessage['files'] != null && (originalMessage['files'] as List).isNotEmpty)
                          Row(
                            children: [
                              _buildReplyAttachmentPreview(originalMessage['files'][0]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  originalMessage['files'][0]['type'].startsWith('image')
                                      ? 'Image'
                                      : originalMessage['files'][0]['filename'],
                                  style: TextStyle(color: Colors.grey[300]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else if (originalMessage['type'] == 'voice')
                          Row(
                            children: [
                              const Icon(Icons.audiotrack, size: 24, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Voice note',
                                style: TextStyle(color: Colors.grey[300]),
                              ),
                            ],
                          )
                        else
                          Text(
                            originalMessage['content'] ?? '',
                            style: TextStyle(color: Colors.grey[300]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                }),
              if (message['type'] == 'voice')
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    GestureDetector(
                  onTap: () => _openMediaView(message, 0),
                      child: AudioWaveformWidget(
                        audioPath: message['files'][0]['url'],
                        isLocal: !(message['files'][0]['url'] as String).startsWith('http'),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_full,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              if (hasAttachment && message['type'] != 'voice') ...[
                _buildAttachment(message),
                if (message['content'] != null && message['content']!.isNotEmpty)
                  const SizedBox(height: 8),
              ],
              if (message['content'] != null && message['content']!.isNotEmpty)
                Text(
                  message['content']!,
                  style: TextStyle(color: isYou ? Colors.white : Colors.grey[200]),
                ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message['edited'] ?? false)
                  Text(
                    '(edited) ',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Text(
                  formatTime(DateTime.parse(message['createdAt']).toLocal()),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
                if (isYou) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _getStatusIcon(_getAggregateStatus(message)),
                    size: 12,
                    color: _getStatusColor(_getAggregateStatus(message)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ));
  }
  String _getAggregateStatus(Map<String, dynamic> message) {
    // Priority 1: Check for a temporary/failed status first.
    if (message['status'] == 'sending') return 'sending';
    if (message['status_for_failed_only'] == 'failed') return 'failed';

    // Priority 2: Derive status from receipts.
    final receipts = (message['readReceipts'] as List?)?.cast<Map<String, dynamic>>();
    if (receipts == null || receipts.isEmpty) {
      return 'sent'; // No receipts means it's sent but not delivered/read.
    }

    // If all receipts are 'read'
    if (receipts.every((r) => r['status'] == 'read')) {
      return 'read';
    }
    // If any receipt is 'delivered' or 'read'
    if (receipts.any((r) => r['status'] == 'delivered' || r['status'] == 'read')) {
      return 'delivered';
    }

    return 'sent';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sending':
        return Icons.access_time; // Clock icon for sending
      case 'sent':
        return Icons.check; // Single tick for sent
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.access_time; // Default to clock
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'read':
        return Colors.tealAccent;
      case 'failed':
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
        return 'image/jpeg';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video/mp4';
      case 'mp3':
      case 'wav':
      case 'm4a':
        return 'audio/mp3';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatDateForChip(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) {
      return 'Today';
    } else if (dateToCompare == yesterday) {
      return 'Yesterday';
    } else {
      // Assuming a simple format, can be replaced with intl package for more robust formatting
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Widget _buildDateChip(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatDateForChip(date),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  List<dynamic> _buildGroupedMessageList() {
    final messages = dataController.currentConversationMessages;
    if (messages.isEmpty) return [];

    List<dynamic> groupedList = [];
    DateTime? lastDate;

    for (var message in messages) {
      final messageDate = DateTime.parse(message['createdAt']).toLocal();
      if (lastDate == null ||
          lastDate.year != messageDate.year ||
          lastDate.month != messageDate.month ||
          lastDate.day != messageDate.day) {
        groupedList.add(messageDate);
      }
      groupedList.add(message);
      lastDate = messageDate;
    }
    return groupedList;
  }

  Widget _buildDeletedMessageBubble(Map<String, dynamic> message) {
    final senderId = message['senderId'] is Map ? message['senderId']['_id'] : message['senderId'];
    final isYou = senderId == dataController.user.value['user']['_id'];

    return Align(
      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[850]?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block, // A "deleted" or "blocked" icon
              color: Colors.grey[400],
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              'Message deleted',
              style: TextStyle(
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatTime(DateTime.parse(message['createdAt']).toLocal()),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chat = dataController.currentChat.value;
      if (chat.isEmpty) {
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final otherUser = chat['type'] == 'group'
          ? null
          : (chat['participants'] as List<dynamic>).firstWhere(
              (p) {
                if (p is Map<String, dynamic>) {
                  return p['_id'] != dataController.user.value['user']['_id'];
                }
                return p != dataController.user.value['user']['_id'];
              },
              orElse: () => (chat['participants'] as List<dynamic>).first,
            );

      final otherUserMap = otherUser is Map<String, dynamic>
          ? otherUser
          : dataController.allUsers.firstWhere(
              (u) => u['_id'] == otherUser,
              orElse: () => {'name': 'Unknown', 'avatar': ''},
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
                    backgroundImage: (chat['type'] == 'group'
                                ? chat['groupAvatar']
                                : otherUserMap?['avatar']) !=
                            null &&
                            (chat['type'] == 'group'
                                ? chat['groupAvatar']
                                : otherUserMap?['avatar'])
                                .isNotEmpty
                        ? NetworkImage((chat['type'] == 'group'
                            ? chat['groupAvatar']
                            : otherUserMap!['avatar'])!)
                        : null,
                    child: (chat['type'] == 'group'
                                ? chat['groupAvatar']
                                : otherUserMap?['avatar']) ==
                            null ||
                            (chat['type'] == 'group'
                                ? chat['groupAvatar']
                                : otherUserMap?['avatar'])
                                .isEmpty
                        ? Text(
                            chat['type'] == 'group'
                                ? (chat['name']?[0] ?? '?')
                                : (otherUserMap?['name'][0] ?? '?'),
                            style: const TextStyle(color: Colors.black),
                          )
                        : null,
                  ),
                  if (chat['type'] != 'group' && (otherUserMap?['online'] ?? false))
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
                chat['type'] == 'group'
                    ? chat['name']!
                    : otherUserMap!['name'],
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
                final groupedMessages = _buildGroupedMessageList();
                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  itemCount: groupedMessages.length,
                  itemBuilder: (context, index) {
                    final item = groupedMessages[index];
                    if (item is DateTime) {
                      return _buildDateChip(item);
                    } else {
                      final message = item as Map<String, dynamic>;
                      final currentUserId = dataController.getUserId();

                      // Priority 1: Check if message was deleted for everyone
                      if (message['deletedForEveryone'] == true) {
                        return _buildDeletedMessageBubble(message);
                      }

                      // Priority 2: Check if message was deleted for the current user
                      final deletedFor = (message['deletedFor'] as List?)?.map((e) => e.toString()).toList() ?? [];
                      if (deletedFor.contains(currentUserId)) {
                        return const SizedBox.shrink(); // Hide the message
                      }

                      // Priority 3: Render the normal message
                      return Align(
                        alignment: message['senderId']['_id'] ==
                                dataController.user.value['user']['_id']
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: _buildMessageContent(message, index),
                      );
                    }
                  },
                );
              }),
            ),
            if (_replyingTo != null) _buildReplyPreview(_replyingTo!),
            MessageInputArea(
              onSend: (text, files) {
                final isVoiceNote = files.isNotEmpty &&
                    _getMediaType(files.first.extension ?? '') == 'audio/mp3';
                _sendMessage(text, files, isVoiceNote: isVoiceNote);
              },
            ),
          ],
        ),
      );
    });
  }
}