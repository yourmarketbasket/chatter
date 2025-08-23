import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';

class GroupProfilePage extends StatelessWidget {
  final Map<String, dynamic> chat;

  const GroupProfilePage({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();

    return Obx(() {
      final currentChat = dataController.chats[chat['_id']];
      if (currentChat == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final isSuperAdmin = currentChat['superAdmin']?['_id'] ==
          dataController.user.value['user']['_id'];
      final isAdmin = currentChat['admins']?.any((admin) =>
              admin['_id'] == dataController.user.value['user']['_id']) ??
          false;

      return Scaffold(
        appBar: AppBar(
          title: Text(currentChat['name'] ?? 'Group Profile'),
        ),
        body: ListView(
          children: [
            // Group Avatar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      NetworkImage(currentChat['groupAvatar'] ?? ''),
                  child: currentChat['groupAvatar'] == null
                      ? const Icon(Icons.group, size: 50)
                      : null,
                ),
              ),
            ),
            // Group Name
            ListTile(
              title: const Text('Group Name'),
              subtitle: Text(currentChat['name'] ?? ''),
              trailing:
                  (isSuperAdmin || isAdmin) ? const Icon(Icons.edit) : null,
              onTap: () {
                if (isSuperAdmin || isAdmin) {
                  final textController =
                      TextEditingController(text: currentChat['name']);
                  Get.dialog(
                    AlertDialog(
                      title: const Text('Edit Group Name'),
                      content: TextField(controller: textController),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            dataController.updateGroup(
                                currentChat['_id'], {'name': textController.text});
                            Get.back();
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            // Group Description
            ListTile(
              title: const Text('About'),
              subtitle: Text(currentChat['about'] ?? 'No description'),
              trailing:
                  (isSuperAdmin || isAdmin) ? const Icon(Icons.edit) : null,
              onTap: () {
                if (isSuperAdmin || isAdmin) {
                  final textController =
                      TextEditingController(text: currentChat['about']);
                  Get.dialog(
                    AlertDialog(
                      title: const Text('Edit Group Description'),
                      content: TextField(controller: textController),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            dataController.updateGroup(currentChat['_id'],
                                {'about': textController.text});
                            Get.back();
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            const Divider(),
            // Participants
            ListTile(
              title: Text(
                  'Participants (${currentChat['participants']?.length ?? 0})'),
              trailing: (isSuperAdmin || isAdmin)
                  ? IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        // TODO: Implement add participants. This would likely involve
                        // navigating to a new page to select users from the allUsers list.
                        // For now, we'll leave this as a future improvement.
                      },
                    )
                  : null,
            ),
            ...?(currentChat['participants'] as List<dynamic>?)
                ?.map((participant) {
              final p = participant as Map<String, dynamic>;
              final isParticipantAdmin = currentChat['admins']
                      ?.any((admin) => admin['_id'] == p['_id']) ??
                  false;
              final isParticipantSuperAdmin =
                  currentChat['superAdmin']?['_id'] == p['_id'];
              final isMuted = currentChat['mutedMembers']
                      ?.any((m) => m['userId']['_id'] == p['_id']) ??
                  false;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(p['avatar'] ?? ''),
                  child: p['avatar'] == null ? const Icon(Icons.person) : null,
                ),
                title: Text(p['name'] ?? 'Unknown'),
                subtitle: isParticipantSuperAdmin
                    ? const Text('Super Admin')
                    : isParticipantAdmin
                        ? const Text('Admin')
                        : const Text('Member'),
                trailing: (isSuperAdmin || isAdmin) &&
                        p['_id'] != dataController.user.value['user']['_id']
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'remove':
                              dataController.removeParticipant(
                                  currentChat['_id'], p['_id']);
                              break;
                            case 'promote':
                              dataController.promoteAdmin(
                                  currentChat['_id'], p['_id']);
                              break;
                            case 'demote':
                              dataController.demoteAdmin(
                                  currentChat['_id'], p['_id']);
                              break;
                            case 'mute':
                              if (isMuted) {
                                dataController.unmuteMember(
                                    currentChat['_id'], p['_id']);
                              } else {
                                dataController.muteMember(
                                    currentChat['_id'], p['_id']);
                              }
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'remove',
                            child: Text('Remove'),
                          ),
                          if (isSuperAdmin)
                            PopupMenuItem<String>(
                              value: isParticipantAdmin ? 'demote' : 'promote',
                              child: Text(isParticipantAdmin
                                  ? 'Demote from Admin'
                                  : 'Promote to Admin'),
                            ),
                          PopupMenuItem<String>(
                            value: 'mute',
                            child: Text(isMuted ? 'Unmute' : 'Mute'),
                          ),
                        ],
                      )
                    : null,
              );
            }).toList(),
            const Divider(),
            // Group Settings
            if (isSuperAdmin || isAdmin)
              ListTile(
                title: const Text('Group Settings'),
                onTap: () {
                  // TODO: Navigate to group settings page
                },
              ),
            // Leave Group
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Leave Group',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Get.dialog(
                  AlertDialog(
                    title: const Text('Leave Group'),
                    content:
                        const Text('Are you sure you want to leave this group?'),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          dataController.leaveGroup(currentChat['_id']);
                          Get.back(); // Close the dialog
                          Get.back(); // Go back from the profile page
                        },
                        child: const Text('Leave',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}
