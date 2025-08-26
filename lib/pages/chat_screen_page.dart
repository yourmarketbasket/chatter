import 'dart:ui' as BorderType;

import 'package:better_player_enhanced/better_player.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/group_profile_page.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:io';
import 'package:chatter/pages/media_view_page.dart';
import 'package:get/get.dart';
import 'package:chatter/widgets/message_input_area.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatter/widgets/video_player_widget.dart';
import 'package:chatter/widgets/better_player_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:chatter/widgets/audio_waveform_widget.dart';
import 'package:chatter/widgets/all_attachments_dialog.dart';
import 'package:chatter/widgets/reply_message_snippet.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:chatter/services/socket-service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';

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
  int _sdkInt = 0;
  final Map<String, Uint8List?> _localVideoThumbnails = {};

  @override
  void initState() {
    super.initState();
    _getAndroidSdkInt();
    final chatId = dataController.currentChat.value['_id'] as String?;
    dataController.activeChatId.value = chatId;

    if (chatId != null) {
      Get.find<SocketService>().joinChatRoom(chatId);
      _loadMessages();
    } else {
      dataController.currentConversationMessages.clear();
    }

    // Add a listener to the chats map to detect if the current chat is deleted.
    dataController.chats.listen((chatsMap) {
      final currentChatId = dataController.currentChat.value['_id'];
      // If the chat we are currently viewing has disappeared from the map
      if (currentChatId != null && !chatsMap.containsKey(currentChatId)) {
        // And if this screen is still mounted
        if (mounted) {
          // Pop the screen
          print('[ChatScreen] Current chat $currentChatId was deleted. Navigating back.');
          Navigator.of(context).pop();
        }
      }
    });

    dataController.currentConversationMessages.listen((_) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });
  }

  void _loadMessages() async {
    await dataController.fetchMessages(dataController.currentChat.value['_id']!);
  }

  void _getAndroidSdkInt() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (mounted) {
        setState(() {
          _sdkInt = deviceInfo.version.sdkInt;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    dataController.currentConversationMessages.clear();
    dataController.activeChatId.value = null;
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

  void _generateVideoThumbnail(String path) async {
    final thumbnail = await VideoThumbnail.thumbnailData(
      video: path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 128,
      quality: 25,
    );
    if (mounted) {
      setState(() {
        _localVideoThumbnails[path] = thumbnail;
      });
    }
  }

  void _sendMessage(String? text, List<PlatformFile>? files, {bool isVoiceNote = false}) async {
    if ((text?.trim().isEmpty ?? true) && (files?.isEmpty ?? true)) {
      return;
    }

    if (files != null) {
      for (var file in files) {
        if (_getMediaType(file.extension ?? '').startsWith('video')) {
          _generateVideoThumbnail(file.path!);
        }
      }
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        backgroundColor: const Color.fromARGB(255, 46, 46, 46),
        title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(hintText: 'Edit your message', hintStyle: TextStyle(color: Colors.white)),
          style: const TextStyle(color: Colors.white),
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
            child: const Text('Save', style: TextStyle(color: Colors.tealAccent)),
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
      backgroundColor: const Color.fromARGB(255, 31, 31, 31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),

      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message['senderId']['_id'] == dataController.user.value['user']['_id'])
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.white),
            title: const Text('Delete for me', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _deleteMessage(message, forEveryone: false);
            },
          ),
          if (message['senderId']['_id'] == dataController.user.value['user']['_id'])
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.white),
              title: const Text('Delete for everyone', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message, forEveryone: true);
              },
            ),
          ListTile(
            leading: const Icon(Icons.thumb_up, color: Colors.white),
            title: const Text('React', style: TextStyle(color: Colors.white)),
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
        if (isLocalFile) {
          final thumbnailUrl = attachment['url'];
          final thumbnailData = _localVideoThumbnails[thumbnailUrl];
          if (thumbnailData != null) {
            content = Image.memory(thumbnailData, fit: BoxFit.cover, key: key);
          } else {
            content = Container(
              key: key,
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          }
        } else {
          // Use BetterPlayer for Android versions lower than 13 (SDK 33)
          if (Platform.isAndroid && _sdkInt > 0 && _sdkInt < 33) {
            // simple controls
            content = BetterPlayerWidget(
              key: key,
              url: attachment['url'],
              displayPath: attachment['filename'] ?? 'video.mp4',
              videoAspectRatioProp: 9 / 16,
              controlsType: VideoControlsType.simple,
            );
          } else {
            // Use VideoPlayer for other platforms or Android 13+
            content = VideoPlayerWidget(
              key: key,
              url: attachment['url'],
            );
          }
        }
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

              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_new,
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

 Widget _buildMessageContent(Map<String, dynamic> message, Map<String, dynamic>? prevMessage) {
  final senderId = message['senderId'] is Map ? message['senderId']['_id'] : message['senderId'];
  final isYou = senderId == dataController.user.value['user']['_id'];
  final prevSenderId = prevMessage != null ? (prevMessage['senderId'] is Map ? prevMessage['senderId']['_id'] : prevMessage['senderId']) : null;
  final isSameSenderAsPrevious = prevSenderId != null && prevSenderId == senderId;
  final bottomMargin = isSameSenderAsPrevious ? 2.0 : 8.0;
  final hasAttachment = message['files'] != null && (message['files'] as List).isNotEmpty;

  // Determine sender name for display
  final sender = dataController.allUsers.firstWhere(
    (u) => u['_id'] == senderId,
    orElse: () {
      final participant = (dataController.currentChat.value['participants'] as List).firstWhere(
        (p) => (p is Map ? p['_id'] : p) == senderId,
        orElse: () => <String, dynamic>{},
      );
      if (participant is Map && participant['name'] != null) {
        return Map<String, dynamic>.from(participant);
      }
      return {'_id': senderId, 'name': 'Unknown User'};
    },
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
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.5,
          minWidth: MediaQuery.of(context).size.width * 0.25,
        ),
        decoration: BoxDecoration(
          color: isYou ? Colors.transparent.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: isYou ? Colors.teal.withOpacity(0.6) : const Color.fromARGB(167, 143, 141, 141), width: 1.0),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12.0),
            topRight: Radius.circular( 12.0),
            bottomLeft: Radius.circular(isYou ?12.0: 0.0),
            bottomRight: Radius.circular(isYou? 0.0:12.0),),
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
                    constraints: BoxConstraints(
                      // maxwidth should take the entire width of the message bubble
                      maxWidth: MediaQuery.of(context).size.width * 0.5,                      
                      minWidth: MediaQuery.of(context).size.width * 0.25,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900]?.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                        left: BorderSide(color: Colors.tealAccent, width: 2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          originalMessage['senderId']['_id'] == dataController.user.value['user']['_id']
                              ? 'You'
                              : dataController.allUsers.firstWhere(
                                  (u) => u['_id'] == originalMessage['senderId']['_id'],
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
                          Icons.open_in_new,
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
                 // Ensure this is imported

                Text(
                  DateFormat('h:mm a').format(DateTime.parse(message['createdAt']).toLocal()),
                  // googlepoppins font
                  style: GoogleFonts.roboto(
                    color: Colors.grey[400],
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
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
// capitalizing each letter
  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildDateChip(DateTime date) {
    return Center(
      child: Row(
        children: [
          // horizontal line
          Expanded(
            child: Container(
              height: 0.2,
              color: Colors.grey[850],
            ),
            
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),            
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[850]!, width: 0.5),
              // color: Colors.grey[850],
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
        
          // horizontal line
          Expanded(
            child: Container(
              height: 0.2,
              color: Colors.grey[850],
            ),
          ),],
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
          surfaceTintColor: Colors.black,
          title: GestureDetector(
            onTap: (){
              if (chat['type'] != 'group') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(
                          userId: otherUserMap!['_id'],
                          username: otherUserMap['name'],
                          userAvatarUrl: otherUserMap['avatar'],
                        ),
                      ),
                    );
                  }else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupProfilePage(chat: chat),
                      ),
                    );
                  }
            },
            child: Row(
              children: [
                Stack(
                  children: [
                    DottedBorder(
                      options: CircularDottedBorderOptions(
                        gradient: LinearGradient(
                          colors: [(otherUserMap?['online'] ?? false) ? Colors.teal : const BorderType.Color.fromARGB(255, 161, 161, 161), Colors.black],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        strokeWidth: 1.5,
                      ),
                      child: CircleAvatar(
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
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat['type'] == 'group'
                          ? _capitalizeFirstLetter(chat['name'] ?? 'Group Chat')
                          : _capitalizeFirstLetter(otherUserMap!['name'] ?? 'User'),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    if (chat['type'] != 'group')
                      Obx(() {
                        final isTyping = chat['_id'] != null && dataController.isTyping[chat['_id']] != null;
                        if (isTyping) {
                          return const Text(
                            'typing...',
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                        final user = dataController.allUsers.firstWhere(
                          (u) => u['_id'] == otherUserMap!['_id'],
                          orElse: () => otherUserMap,
                        );
                        if (user['online'] == true) {
                          return const Text(
                            'online',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          );
                        }
                        if (user['lastSeen'] != null) {
                          return Text(
                            'last seen ${formatLastSeen(DateTime.parse(user['lastSeen']))}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          );
                        }
                        return const Text(
                          'offline',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          )
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
                      Map<String, dynamic>? prevMessage;
                      if (index > 0) {
                        for (int i = index - 1; i >= 0; i--) {
                          if (groupedMessages[i] is Map<String, dynamic>) {
                            prevMessage = groupedMessages[i] as Map<String, dynamic>;
                            break;
                          }
                        }
                      }

                      return VisibilityDetector(
                        key: Key(message['_id'] ?? message['clientMessageId']),
                        onVisibilityChanged: (visibilityInfo) {
                          if (visibilityInfo.visibleFraction > 0.5) {
                            dataController.markMessageAsRead(message);
                          }
                        },
                        child: Align(
                          alignment: message['senderId']['_id'] ==
                                  dataController.user.value['user']['_id']
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: _buildMessageContent(message, prevMessage),
                        ),
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