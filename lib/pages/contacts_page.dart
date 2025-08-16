import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

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
      final currentUserId = _dataController.user.value['user']['_id'];

      // Look for an existing chat
      final existingChat = _dataController.chats.values.firstWhere(
        (chat) {
          if (chat['isGroup'] == true) return false;

          final participantIds = (chat['participants'] as List).map((p) {
            if (p is Map<String, dynamic>) return p['_id'] as String;
            return p as String;
          }).toSet(); // Use a Set for efficient lookup

          return participantIds.contains(currentUserId) &&
              participantIds.contains(user['_id']);
        },
        orElse: () => null,
      );

      if (existingChat != null) {
        // Chat already exists, just open it
        _dataController.currentChat.value = existingChat;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      } else {
        // Chat does not exist, create it
        final currentUserData = _dataController.user.value['user'];
        _dataController
            .createChat([currentUserId, user['_id']], isGroup: false)
            .then((chat) {
          if (chat != null) {
            final hydratedChat = Map<String, dynamic>.from(chat);
            hydratedChat['participants'] = [currentUserData, user];
            _dataController.chats[chat['_id']] = hydratedChat;
            _dataController.currentChat.value = hydratedChat;

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          } else {
            Get.snackbar('Error', 'Could not create chat.');
          }
        });
      }
    }
  }

  void _createGroup() {
    if (_selectedUserIds.length < 2) {
      Get.snackbar('Error', 'Select at least 2 members to create a group.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    final currentUserId = _dataController.user.value['user']['_id'];
    final participantIds = <String>[currentUserId, ..._selectedUserIds];

    final groupNameController = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('New Group', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: groupNameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Group Name',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.tealAccent)),
          ),
          TextButton(
            onPressed: () {
              final groupName = groupNameController.text.trim();
              if (groupName.isNotEmpty) {
                _dataController
                    .createChat(participantIds,
                        isGroup: true, groupName: groupName)
                    .then((chat) {
                  Get.back(); // Close dialog
                  if (chat != null) {
                    _dataController.currentChat.value = chat;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatScreen(),
                      ),
                    );
                  }
                });
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.isCreatingGroup ? 'Create Group' : 'New Chat',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          if (widget.isCreatingGroup)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.tealAccent),
              onPressed: _createGroup,
            ),
        ],
      ),
      body: Obx(() {
        if (_dataController.isLoadingFollowing.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_dataController.following.isEmpty) {
          return const Center(
              child: Text('You are not following anyone yet.',
                  style: TextStyle(color: Colors.white)));
        }
        return ListView.builder(
          itemCount: _dataController.following.length,
          itemBuilder: (context, index) {
            final user = _dataController.following[index];
            final isSelected = _selectedUserIds.contains(user['_id']);
            final String avatarUrl = user['avatar'] ?? '';
            final bool isVerified = user['isVerified'] ?? false;

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage:
                    (avatarUrl != null && avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        user['name']?[0] ?? '?',
                        style: const TextStyle(
                            color: Colors.tealAccent, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Row(
                children: [
                  Text(user['name'] ?? 'No Name',
                      style: const TextStyle(color: Colors.white)),
                  if (isVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.verified, color: Colors.amber, size: 16),
                    ),
                ],
              ),
              subtitle: Text(
                '${user['followersCount'] ?? 0} Followers, ${user['followingCount'] ?? 0} Following',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              onTap: () => _onUserTap(user),
              trailing: widget.isCreatingGroup
                  ? InkWell(
                      onTap: () => _onUserTap(user),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.tealAccent
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? Colors.tealAccent : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.black,
                              )
                            : null,
                      ),
                    )
                  : null,
            );
          },
        );
      }),
    );
  }
}
