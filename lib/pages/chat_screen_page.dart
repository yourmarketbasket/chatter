import 'dart:async';
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
import 'package:chatter/widgets/reply_attachment_preview.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:chatter/services/socket-service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'package:chatter/pages/users_list_page.dart';
import 'package:flutter/services.dart';
import 'package:chatter/widgets/message_bubble.dart';
import 'package:chatter/widgets/pdf_thumbnail_widget.dart';


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DataController dataController = Get.find<DataController>();
  final SocketService socketService = Get.find<SocketService>();
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _replyingTo;
  int _sdkInt = 0;
  final Map<String, Uint8List?> _localVideoThumbnails = {};
  bool _isSelectionMode = false;
  final Set<String> _selectedMessages = {};

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
        if (_selectedMessages.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessages.add(messageId);
        _isSelectionMode = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _getAndroidSdkInt();
    final chatId = dataController.currentChat.value['_id'] as String?;
    dataController.activeChatId.value = chatId;

    if (chatId != null) {
      socketService.joinChatRoom(chatId);
      _loadMessages();
    } else {
      dataController.currentConversationMessages.clear();
    }

    // Listen for socket events
    _socketSubscription = socketService.events.listen(_handleSocketEvent);

    // Add a listener to the chats map to detect if the current chat is deleted.
    dataController.chats.listen((chatsMap) {
      final currentChatId = dataController.currentChat.value['_id'];
      if (currentChatId != null && !chatsMap.containsKey(currentChatId) && mounted) {
        Navigator.of(context).pop();
      }
    });

    dataController.currentConversationMessages.listen((_) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final eventName = event['event'];
    final data = event['data'];
    final currentChatId = dataController.activeChatId.value;

    if (currentChatId == null) return;

    // A map of event handlers
    final handlers = {
      'message:new': () {
        if (data['chatId'] == currentChatId) {
          // The DataController's handleNewMessage already adds the message
          // and refreshes the list. We just need to ensure the UI rebuilds.
          setState(() {}); // Trigger a rebuild to show the new message
        }
      },
      'message:update': () {
        if (data['chatId'] == currentChatId) {
          setState(() {}); // Trigger a rebuild
        }
      },
      'message:delete': () {
         if (data['chatId'] == currentChatId) {
          setState(() {}); // Trigger a rebuild
        }
      },
      'message:reaction': () {
        if (data['chatId'] == currentChatId) {
          setState(() {}); // Trigger a rebuild
        }
      },
      'message:reaction:removed': () {
        if (data['chatId'] == currentChatId) {
          setState(() {}); // Trigger a rebuild
        }
      },
      'typing:started': () {
        if (data['chatId'] == currentChatId) {
          setState(() {}); // Rebuild to show typing indicator
        }
      },
      'typing:stopped': () {
         if (data['chatId'] == currentChatId) {
          setState(() {}); // Rebuild to hide typing indicator
        }
      },
      'chat:updated': () {
        if (data['_id'] == currentChatId) {
          setState(() {}); // Rebuild app bar with new details
        }
      }
    };

    // Execute the handler if it exists
    if (handlers.containsKey(eventName)) {
      handlers[eventName]!();
    }
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
    _socketSubscription?.cancel();
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

  void _forwardSelectedMessages() {
    final messagesToForward = _selectedMessages
        .map((id) => dataController.currentConversationMessages.firstWhere((m) => (m['_id'] ?? m['clientMessageId']) == id))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UsersListPage(
          onUserSelected: (user) {
            dataController.forwardMultipleMessages(messagesToForward, user['_id']);
            Navigator.pop(context); // Close UsersListPage
            setState(() {
              _isSelectionMode = false;
              _selectedMessages.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Forwarding ${_selectedMessages.length} message(s) to ${user['name']}')),
            );
          },
        ),
      ),
    );
  }

  void _deleteMessage(Map<String, dynamic> message, {required bool forEveryone}) {
    dataController.deleteChatMessage(message['_id'], forEveryone: forEveryone);
  }

  void _copyMessage(Map<String, dynamic> message) {
    Clipboard.setData(ClipboardData(text: message['content']));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  void _showReactionDialog(BuildContext context, Map<String, dynamic> message, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: position.dy - 80, // Adjust position to be above the press point
              left: position.dx - 100, // Center the dialog horizontally
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['👍', '❤️', '😂', '😮', '😢', '🙏']
                        .map((emoji) => GestureDetector(
                              onTap: () {
                                dataController.addReaction(message['_id'], emoji);
                                Navigator.pop(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(emoji, style: const TextStyle(fontSize: 24)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }



  Widget _buildReactions(Map<String, dynamic> message, bool isYou) {
    final reactions = message['reactions'] as List<dynamic>? ?? [];
    final currentUserId = dataController.getUserId();

    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group reactions by emoji
    final groupedReactions = <String, List<String>>{};
    for (var reaction in reactions) {
      final emoji = reaction['emoji'] as String;
      final userIdValue = reaction['userId'];
      final String userId;
      if (userIdValue is Map) {
        userId = userIdValue['_id'] as String;
      } else {
        userId = userIdValue as String;
      }
      if (groupedReactions.containsKey(emoji)) {
        groupedReactions[emoji]!.add(userId);
      } else {
        groupedReactions[emoji] = [userId];
      }
    }

    return Positioned(
      bottom: -5, // Move up 10px from -8
      left: isYou ? 5 : null,
      right: isYou ? null : 5,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: groupedReactions.entries.map((entry) {
          final emoji = entry.key;
          final userIds = entry.value;
          final count = userIds.length;
          final hasReacted = userIds.contains(currentUserId);

          return GestureDetector(
            onTap: () {
              if (hasReacted) {
                dataController.removeReaction(message['_id'], emoji);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color:const BorderType.Color.fromARGB(255, 92, 92, 92), width: 0.5),
              ),
              child: Text(
                '$emoji $count',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getReplyPreviewText(Map<String, dynamic> attachment) {
    String? filename = attachment['filename'];
    if (filename == null || filename.isEmpty) {
        final url = attachment['url'] as String? ?? '';
        if (url.isNotEmpty) {
            try {
                // For URLs, decode and take the last path segment
                filename = Uri.decodeComponent(Uri.parse(url).pathSegments.last);
            } catch (e) {
                // For local file paths, just split by the separator
                filename = url.split(Platform.pathSeparator).last;
            }
        }
    }


    final attachmentType = attachment['type'] as String? ?? '';
    if (attachmentType.startsWith('image') || attachmentType.startsWith('video')) {
      return filename ?? (attachmentType.startsWith('image') ? 'Image' : 'Video');
    } else if (attachmentType.startsWith('audio') || attachmentType == 'voice') {
      return 'Voice Note';
    } else if (attachmentType == 'application/pdf') {
      return filename ?? 'PDF Document';
    } else {
      return filename ?? 'File';
    }
  }

  Widget _buildReplyPreview(Map<String, dynamic> replyTo) {
    final replyToSenderId = replyTo['senderId'] is Map
        ? replyTo['senderId']['_id']
        : replyTo['senderId'];

    // Find the sender in the allUsers list for more reliable name resolution
    final sender = dataController.allUsers.firstWhere(
      (u) => u['_id'] == replyToSenderId,
      orElse: () {
        // Fallback to searching participants list if not in allUsers
        final participants = dataController.currentChat.value['participants'] as List? ?? [];
        return participants.firstWhere(
          (p) => (p is Map ? p['_id'] : p) == replyToSenderId,
          orElse: () => {'_id': replyToSenderId, 'name': 'Unknown User'},
        );
      },
    );

    final senderName = replyToSenderId == dataController.getUserId()
        ? 'You'
        : (sender['name'] ?? 'Unknown User');

    Widget contentPreview;
    if (replyTo['files'] != null && (replyTo['files'] as List).isNotEmpty) {
      final firstAttachment = (replyTo['files'] as List).first;
      contentPreview = Row(
        children: [
          ReplyAttachmentPreview(attachment: firstAttachment),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getReplyPreviewText(firstAttachment),
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
            'Voice Note',
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
      padding: const EdgeInsets.fromLTRB(2, 8, 8, 0),
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
            // Use BetterPlayer for other platforms or Android 13+
            content = BetterPlayerWidget(
              key: key,
              url: attachment['url'],
              displayPath: attachment['filename'] ?? 'video.mp4',
              videoAspectRatioProp: 9 / 16,
              controlsType: VideoControlsType.simple,
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
        content = PdfThumbnailWidget(
          url: attachment['url'],
          isLocal: isLocalFile,
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

  AppBar _buildNormalAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Obx(() {
        final chat = dataController.currentChat.value;
        final isGroup = chat['type'] == 'group';

        String title;
        String avatarUrl;
        String avatarLetter;
        bool isOnline = false;
        Map<String, dynamic>? userForProfile;

        if (isGroup) {
          title = chat['name'] ?? 'Group Chat';
          avatarUrl = chat['groupAvatar'] ?? '';
          avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'G';
        } else {
          final currentUserId = dataController.user.value['user']['_id'];
          final otherParticipantRaw = (chat['participants'] as List<dynamic>).firstWhere(
            (p) => (p is Map ? p['_id'] : p) != currentUserId,
            orElse: () => null,
          );

          if (otherParticipantRaw == null) {
            return const Text('Error: User not found', style: TextStyle(color: Colors.red, fontSize: 14));
          }

          final otherUserId = otherParticipantRaw is Map ? otherParticipantRaw['_id'] : otherParticipantRaw;

          final otherUser = dataController.allUsers.firstWhere(
            (u) => u['_id'] == otherUserId,
            orElse: () => {
              '_id': otherUserId,
              'name': 'Loading...',
              'avatar': '',
              'online': false,
              'lastSeen': null,
            },
          );

          userForProfile = otherUser;
          title = otherUser['name'] ?? 'User';
          avatarUrl = otherUser['avatar'] ?? '';
          avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'U';
          isOnline = otherUser['online'] ?? false;
        }

        Widget statusWidget;
        if (!isGroup && userForProfile != null) {
          final chatId = chat['_id'] as String?;
          final isTypingMap = dataController.isTyping.value;
          String? typingUserId;
          if (chatId != null) {
            typingUserId = isTypingMap[chatId];
          }

          if (typingUserId != null && typingUserId == userForProfile['_id']) {
            statusWidget = const Text(
              'typing...',
              style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontStyle: FontStyle.italic),
            );
          } else {
            if (userForProfile['online'] == true) {
              statusWidget = const Text('online', style: TextStyle(color: Colors.green, fontSize: 12));
            } else if (userForProfile['lastSeen'] != null) {
              statusWidget = Text(
                'last seen ${formatLastSeen(DateTime.parse(userForProfile['lastSeen']))}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              );
            } else {
              statusWidget = const Text('offline', style: TextStyle(color: Colors.grey, fontSize: 12));
            }
          }
        } else {
          statusWidget = const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            if (isGroup) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GroupProfilePage(chat: chat)),
              );
            } else if (userForProfile != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    userId: userForProfile!['_id'],
                    username: userForProfile['name'],
                    userAvatarUrl: userForProfile['avatar'],
                  ),
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
                        colors: [isOnline ? Colors.teal : const BorderType.Color.fromARGB(255, 161, 161, 161), Colors.black],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      strokeWidth: 1.5,
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.tealAccent,
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty ? Text(avatarLetter, style: const TextStyle(color: Colors.black)) : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalizeFirstLetter(title),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    statusWidget,
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  AppBar _buildContextualAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {
          setState(() {
            _isSelectionMode = false;
            _selectedMessages.clear();
          });
        },
      ),
      title: Text(
        '${_selectedMessages.length} selected',
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      actions: [
        if (_selectedMessages.length == 1)
          IconButton(
            icon: const Icon(Icons.reply, color: Colors.white),
            onPressed: () {
              final messageId = _selectedMessages.first;
              final message = dataController.currentConversationMessages.firstWhere((m) => (m['_id'] ?? m['clientMessageId']) == messageId);
              setState(() {
                _replyingTo = message;
                _isSelectionMode = false;
                _selectedMessages.clear();
              });
            },
          ),
        if (_selectedMessages.every((id) => (dataController.currentConversationMessages.firstWhere((m) => (m['_id'] ?? m['clientMessageId']) == id)['content'] as String).isNotEmpty))
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white),
            onPressed: () {
              String combinedText = '';
              List<String> sortedIds = _selectedMessages.toList();
              sortedIds.sort((a, b) {
                final msgA = dataController.currentConversationMessages.firstWhere((m) => (m['_id'] ?? m['clientMessageId']) == a);
                final msgB = dataController.currentConversationMessages.firstWhere((m) => (m['_id'] ?? m['clientMessageId']) == b);
                return DateTime.parse(msgA['createdAt']).compareTo(DateTime.parse(msgB['createdAt']));
              });

              for (var messageId in sortedIds) {
                final message = dataController.currentConversationMessages.firstWhere((m) => (m['_id'] ?? m['clientMessageId']) == messageId);
                combinedText += message['content'] + '\n';
              }
              Clipboard.setData(ClipboardData(text: combinedText.trim()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message(s) copied to clipboard')),
              );
              setState(() {
                _isSelectionMode = false;
                _selectedMessages.clear();
              });
            },
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              final messageId = _selectedMessages.first;
              final message = dataController.currentConversationMessages.firstWhere((m) => (m['_id'] ?? m['clientMessageId']) == messageId);
              _editMessage(message);
            } else if (value == 'delete_me') {
              dataController.deleteMultipleMessages(_selectedMessages.toList(), deleteFor: "me");
            } else if (value == 'delete_everyone') {
              dataController.deleteMultipleMessages(_selectedMessages.toList(), deleteFor: "everyone");
            }
            setState(() {
              _isSelectionMode = false;
              _selectedMessages.clear();
            });
          },
          itemBuilder: (BuildContext context) {
            final currentUserId = dataController.getUserId();
            final canDeleteForEveryone = _selectedMessages.every((id) {
              final message = dataController.currentConversationMessages.firstWhere((m) => (m['_id'] ?? m['clientMessageId']) == id);
              final senderId = message['senderId'] is Map ? message['senderId']['_id'] : message['senderId'];
              return senderId == currentUserId;
            });

            return <PopupMenuEntry<String>>[
              if (_selectedMessages.length == 1)
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit'),
                ),
              const PopupMenuItem<String>(
                value: 'delete_me',
                child: Text('Delete for me'),
              ),
              if (canDeleteForEveryone)
                const PopupMenuItem<String>(
                  value: 'delete_everyone',
                  child: Text('Delete for everyone'),
                ),
            ];
          },
          icon: const Icon(Icons.more_vert, color: Colors.white),
        ),
      ],
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

      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _isSelectionMode ? _buildContextualAppBar() : _buildNormalAppBar(),
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
                        child: Dismissible(
                          key: Key(message['_id'] ?? message['clientMessageId']),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            setState(() {
                              _replyingTo = message;
                            });
                            return false; // This prevents the widget from being dismissed
                          },
                          background: Container(
                            color: Colors.teal.withOpacity(0.2),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20.0),
                            child: const Icon(Icons.reply, color: Colors.white),
                          ),
                          child: GestureDetector(
                            onLongPressStart: (details) {
                              final messageId = message['_id'] ?? message['clientMessageId'];
                              if (messageId != null) {
                                _toggleSelection(messageId);
                              }
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _showReactionDialog(context, message, details.globalPosition);
                                }
                              });
                            },
                            onTap: () {
                              if (_isSelectionMode) {
                                final messageId = message['_id'] ?? message['clientMessageId'];
                                if (messageId != null) {
                                  _toggleSelection(messageId);
                                }
                              }
                            },
                            child: Container(
                              color: _selectedMessages.contains(message['_id'] ?? message['clientMessageId'])
                                  ? Colors.teal.withOpacity(0.2)
                                  : Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Align(
                                  alignment: message['senderId']['_id'] == dataController.getUserId()
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (message['senderId']['_id'] != dataController.getUserId() && _selectedMessages.contains(message['_id'] ?? message['clientMessageId']))
                                        IconButton(
                                          icon: const Icon(Icons.forward, color: Colors.white),
                                          onPressed: _forwardSelectedMessages,
                                        ),
                                      Flexible(
                                        child: MessageBubble(
                                          message: message,
                                          prevMessage: prevMessage,
                                          dataController: dataController,
                                          openMediaView: _openMediaView,
                                          buildAttachment: _buildAttachment,
                                          getReplyPreviewText: _getReplyPreviewText,
                                          buildReactions: _buildReactions,
                                        ),
                                      ),
                                      if (message['senderId']['_id'] == dataController.getUserId() && _selectedMessages.contains(message['_id'] ?? message['clientMessageId']))
                                        IconButton(
                                          icon: const Icon(Icons.forward, color: Colors.white),
                                          onPressed: _forwardSelectedMessages,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
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
            // wanyeee
          ],
        ),
      );
    });
  }
}