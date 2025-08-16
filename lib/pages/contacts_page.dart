import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContactsPage extends StatefulWidget {
  final bool isCreatingGroup;
  const ContactsPage({super.key, this.isCreatingGroup = false});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final DataController _dataController = Get.find<DataController>();
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    final currentUserId = _dataController.user.value['user']['_id'];
    _dataController.fetchFollowing(currentUserId);
  }

  void _onUserTap(Map<String, dynamic> user) {
    if (widget.isCreatingGroup) {
      setState(() {
        if (_selectedUserIds.contains(user['_id'])) {
          _selectedUserIds.remove(user['_id']);
        } else {
          _selectedUserIds.add(user['_id']);
        }
      });
    } else {
      // Find existing chat or create a new one
      final existingChat = _dataController.chats.values.firstWhere(
        (chat) =>
            chat['isGroup'] == false &&
            chat['participants']
                .any((p) => p['_id'] == user['_id']),
        orElse: () => null,
      );

      if (existingChat != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chat: existingChat),
          ),
        );
      } else {
        final currentUserId = _dataController.user.value['user']['_id'];
        _dataController.createChat([currentUserId, user['_id']]).then((chat) {
          if (chat != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(chat: chat),
              ),
            );
          }
        });
      }
    }
  }

  void _createGroup() {
    if (_selectedUserIds.length < 2) {
      // Show error, need at least 2 other members for a group
      return;
    }
    final currentUserId = _dataController.user.value['user']['_id'];
    final participantIds = [currentUserId, ..._selectedUserIds];

    // a dialog to get group name
    final groupNameController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('New Group'),
            content: TextField(
              controller: groupNameController,
              decoration: const InputDecoration(hintText: 'Group Name'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final groupName = groupNameController.text.trim();
                  if (groupName.isNotEmpty) {
                    _dataController.createChat(participantIds, isGroup: true, groupName: groupName).then((chat) {
                      if (chat != null) {
                        Navigator.pop(context); // close dialog
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(chat: chat),
                          ),
                        );
                      }
                    });
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isCreatingGroup ? 'Create Group' : 'New Chat'),
        actions: [
          if (widget.isCreatingGroup)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _createGroup,
            ),
        ],
      ),
      body: Obx(() {
        if (_dataController.isLoadingFollowing.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_dataController.following.isEmpty) {
          return const Center(child: Text('You are not following anyone yet.'));
        }
        return ListView.builder(
          itemCount: _dataController.following.length,
          itemBuilder: (context, index) {
            final user = _dataController.following[index];
            final isSelected = _selectedUserIds.contains(user['_id']);

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(user['avatar'] ?? ''),
              ),
              title: Text(user['name'] ?? 'No Name'),
              onTap: () => _onUserTap(user),
              trailing: widget.isCreatingGroup
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        _onUserTap(user);
                      },
                    )
                  : null,
            );
          },
        );
      }),
    );
  }
}
