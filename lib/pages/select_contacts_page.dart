import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/conversation_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum SelectContactsMode { dm, group }

class SelectContactsPage extends StatefulWidget {
  final SelectContactsMode mode;

  const SelectContactsPage({Key? key, required this.mode}) : super(key: key);

  @override
  _SelectContactsPageState createState() => _SelectContactsPageState();
}

class _SelectContactsPageState extends State<SelectContactsPage> {
  final DataController _dataController = Get.find<DataController>();
  final List<Map<String, dynamic>> _selectedUsers = [];

  @override
  void initState() {
    super.initState();
    final currentUserId = _dataController.user.value['user']['_id'];
    _dataController.fetchFollowing(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == SelectContactsMode.dm ? 'New Chat' : 'New Group'),
      ),
      body: Obx(() {
        if (_dataController.isLoadingFollowing.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          itemCount: _dataController.following.length,
          itemBuilder: (context, index) {
            final user = _dataController.following[index];
            final isSelected = _selectedUsers.contains(user);
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(user['avatar']),
              ),
              title: Text(user['name']),
              subtitle: Text('@${user['username']}'),
              trailing: widget.mode == SelectContactsMode.group
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedUsers.add(user);
                          } else {
                            _selectedUsers.remove(user);
                          }
                        });
                      },
                    )
                  : null,
              onTap: () async {
                if (widget.mode == SelectContactsMode.dm) {
                  final currentUserId = _dataController.user.value['user']['_id'];
                  final newChat = await _dataController.createChat([currentUserId, user['_id']]);
                  if (newChat != null) {
                    Get.off(() => ConversationPage(
                          conversationId: newChat.id,
                          username: user['name'],
                          userAvatar: user['avatar'],
                        ));
                  } else {
                    Get.snackbar('Error', 'Could not create chat.');
                  }
                } else {
                  setState(() {
                    if (isSelected) {
                      _selectedUsers.remove(user);
                    } else {
                      _selectedUsers.add(user);
                    }
                  });
                }
              },
            );
          },
        );
      }),
      floatingActionButton: _selectedUsers.isNotEmpty && widget.mode == SelectContactsMode.group
          ? FloatingActionButton(
              onPressed: _createGroup,
              child: const Icon(Icons.check),
            )
          : null,
    );
  }

  void _createGroup() {
    final groupNameController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('New Group'),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(hintText: 'Group Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (groupNameController.text.isNotEmpty) {
                final participantIds = _selectedUsers.map((u) => u['_id'] as String).toList();
                final currentUserId = _dataController.user.value['user']['_id'];
                participantIds.add(currentUserId);

                final newChat = await _dataController.createChat(
                  participantIds,
                  isGroup: true,
                  groupName: groupNameController.text,
                );

                Get.back(); // Close dialog

                if (newChat != null) {
                  Get.to(() => ConversationPage(
                        conversationId: newChat.id,
                        username: newChat.groupName!,
                        userAvatar: newChat.groupAvatar ?? '',
                      ));
                } else {
                  Get.snackbar('Error', 'Could not create group chat.');
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
