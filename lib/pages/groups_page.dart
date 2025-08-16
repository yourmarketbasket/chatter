import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:chatter/models/chat_models.dart';
import 'package:chatter/pages/conversation_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final DataController _dataController = Get.find<DataController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final groupChats = _dataController.conversations
            .where((chat) => chat.isGroup)
            .toList();

        if (_dataController.isLoadingConversations.value &&
            groupChats.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent));
        }

        if (groupChats.isEmpty) {
          return const Center(
            child: Text(
              'No groups yet.\nTap the + icon to create a new group.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: groupChats.length,
          itemBuilder: (context, index) {
            final group = groupChats[index];
            final lastMessage = group.lastMessage;

            String preview = 'No messages yet.';
            if (lastMessage != null) {
              preview = lastMessage.deleted
                  ? 'Message deleted'
                  : lastMessage.attachments?.isNotEmpty == true
                      ? 'Attachment'
                      : lastMessage.text ?? '...';
              if (lastMessage.edited) {
                preview += ' (edited)';
              }
            }

            final avatarText = group.groupName != null && group.groupName!.isNotEmpty
                ? group.groupName![0].toUpperCase()
                : 'G';

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: CircleAvatar(
                backgroundColor: Colors.tealAccent,
                backgroundImage: group.groupAvatar != null
                    ? CachedNetworkImageProvider(group.groupAvatar!)
                    : null,
                child: group.groupAvatar == null
                    ? Text(
                        avatarText,
                        style: const TextStyle(color: Colors.black),
                      )
                    : null,
              ),
              title: Text(
                group.groupName ?? 'Unnamed Group',
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
              trailing: lastMessage != null
                  ? Text(
                      TimeHelper.getFormattedTime(lastMessage.createdAt),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    )
                  : null,
              onTap: () {
                Get.to(() => ConversationPage(
                      conversationId: group.id,
                      username: group.groupName ?? 'Group',
                      userAvatar: group.groupAvatar,
                    ));
              },
            );
          },
        );
      }),
    );
  }
}