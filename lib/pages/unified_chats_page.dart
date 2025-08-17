import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:flutter/material.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UnifiedChatsPage extends StatefulWidget {
  const UnifiedChatsPage({super.key});

  @override
  State<UnifiedChatsPage> createState() => _UnifiedChatsPageState();
}

class _UnifiedChatsPageState extends State<UnifiedChatsPage> {
  final DataController _dataController = Get.find<DataController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (_dataController.isLoadingChats.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final allChats = _dataController.chats.values.toList();

        if (allChats.isEmpty) {
          return const Center(
              child: Text('No conversations yet.',
                  style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          itemCount: allChats.length,
          itemBuilder: (context, index) {
            final chat = allChats[index];
            final isGroup = chat['type'] == "group";
            final lastMessageData = chat['lastMessage'];
            final currentUserId = _dataController.user.value['user']['_id'];

            String title;
            String avatarUrl;
            String avatarLetter;
            Widget trailingWidget;

            if (isGroup) {
              title = chat['name'] ?? 'Group Chat';
              avatarUrl = chat['groupAvatar'] ?? '';
              avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'G';
              trailingWidget = const SizedBox.shrink();
            } else {
              final otherUserRaw = (chat['participants'] as List<dynamic>)
                  .firstWhere(
                    (p) => p['_id'] != currentUserId,
                    orElse: () => (chat['participants'] as List<dynamic>).first,
                  );

              final otherUser = otherUserRaw is Map<String, dynamic>
                  ? otherUserRaw
                  : _dataController.allUsers.firstWhere(
                      (u) => u['_id'] == otherUserRaw,
                      orElse: () => {'name': 'Unknown', 'avatar': ''},
                    );

              title = otherUser['name'] ?? 'User';
              avatarUrl = otherUser['avatar'] ?? '';
              avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'U';

              trailingWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    otherUser['online'] == true
                        ? 'online'
                        : (otherUser['lastSeen'] != null
                            ? formatLastSeen(DateTime.parse(otherUser['lastSeen']))
                            : 'offline'),
                    style: TextStyle(
                      color: otherUser['online'] == true
                          ? Colors.tealAccent
                          : Colors.grey[400],
                      fontSize: 12,
                      fontWeight: otherUser['online'] == true
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              );
            }

            String preview = '';
            if (lastMessageData != null && lastMessageData is Map<String, dynamic>) {
              if ((lastMessageData['files'] as List?)?.isNotEmpty ?? false) {
                preview = 'Attachment';
              } else {
                preview = lastMessageData['content'] ?? '';
              }
              final senderId = lastMessageData['senderId'];
              String senderName;
              if (senderId == currentUserId) {
                senderName = 'You';
              } else {
                if (isGroup) {
                  final sender = (chat['participants'] as List).firstWhere(
                    (p) => p['_id'] == senderId,
                    orElse: () => {'name': '...'},
                  );
                  senderName = sender['name'];
                } else {
                  senderName = title; // In 1-on-1 chat, the title is the other user's name
                }
              }
              preview = '$senderName: $preview';
            }

            IconData statusIcon = Icons.access_time;
            Color statusColor = Colors.grey[400]!;
            if (lastMessageData != null && lastMessageData is Map<String, dynamic>) {
              final readReceipts = lastMessageData['readReceipts'] as List?;
              if (readReceipts != null && readReceipts.isNotEmpty) {
                final receipt = readReceipts.firstWhere(
                  (r) => r['userId'] != currentUserId,
                  orElse: () => {'status': 'sent'},
                );
                switch (receipt['status']) {
                  case 'sent':
                    statusIcon = Icons.check;
                    break;
                  case 'delivered':
                    statusIcon = Icons.done_all;
                    break;
                  case 'read':
                    statusIcon = Icons.done_all;
                    statusColor = Colors.tealAccent;
                    break;
                }
              }
            }

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.tealAccent.withOpacity(0.2),
                    backgroundImage: avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            avatarLetter,
                            style: const TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  if (isGroup)
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black,
                        child: Icon(
                          Icons.group,
                          size: 16,
                          color: Colors.tealAccent,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                preview,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isGroup) trailingWidget,
                  if (lastMessageData != null &&
                      lastMessageData is Map<String, dynamic>)
                    Text(
                      formatTime(
                          DateTime.parse(lastMessageData['createdAt'] as String)),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  if (lastMessageData != null &&
                      lastMessageData is Map<String, dynamic> &&
                      lastMessageData['senderId'] == currentUserId)
                    Icon(
                      statusIcon,
                      size: 16,
                      color: statusColor,
                    ),
                ],
              ),
              onTap: () {
                _dataController.currentChat.value = chat;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(),
                  ),
                );
              },
            );
          },
        );
      }),
    );
  }
}