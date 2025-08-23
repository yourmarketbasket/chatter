import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:image_picker/image_picker.dart';

class GroupProfilePage extends StatelessWidget {
  final Map<String, dynamic> chat;

  const GroupProfilePage({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();

    return Theme(
      data: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
          accentColor: Colors.tealAccent,
          backgroundColor: Colors.black,
          cardColor: Colors.grey[900],
        ).copyWith(
          onPrimary: Colors.white,
          onSecondary: Colors.grey[300],
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleSmall: TextStyle(color: Colors.grey),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.grey[850],
          textStyle: const TextStyle(color: Colors.white),
        ),
        dialogBackgroundColor: Colors.grey[850],
        dialogTheme: DialogThemeData(
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
          contentTextStyle: TextStyle(color: Colors.grey[300]),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.tealAccent),
          hintStyle: TextStyle(color: Colors.grey[400]),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[600]!),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.tealAccent),
          ),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[600]!),
          ),
        ),
      ),
      child: Obx(() {
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
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage:
                            NetworkImage(currentChat['groupAvatar'] ?? ''),
                        child: currentChat['groupAvatar'] == null || currentChat['groupAvatar'].isEmpty
                            ? Icon(Icons.group, size: 50, color: Colors.grey[700])
                            : null,
                      ),
                      if (isSuperAdmin || isAdmin)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final pickedFile = await picker.pickImage(
                                  source: ImageSource.gallery);
                              if (pickedFile != null) {
                                final file = File(pickedFile.path);
                                final avatarUrl =
                                    await dataController.uploadAvatar(file);
                                if (avatarUrl != null) {
                                  await dataController.updateGroupAvatar(
                                      currentChat['_id'], avatarUrl);
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Group Name
              ListTile(
                title: const Text('Group Name', style: TextStyle(color: Colors.white)),
                subtitle: Text(currentChat['name'] ?? '', style: TextStyle(color: Colors.grey[400])),
                trailing: (isSuperAdmin || isAdmin)
                    ? Icon(Icons.edit, color: Colors.grey[400])
                    : null,
                onTap: () {
                  if (isSuperAdmin || isAdmin) {
                    final textController =
                        TextEditingController(text: currentChat['name']);
                    Get.dialog(
                      AlertDialog(
                        title: const Text('Edit Group Name'),
                        content: TextField(
                          controller: textController,
                          style: const TextStyle(color: Colors.white),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              dataController.updateGroup(currentChat['_id'],
                                  {'name': textController.text});
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
                title: const Text('About', style: TextStyle(color: Colors.white)),
                subtitle: Text(currentChat['about'] ?? 'No description', style: TextStyle(color: Colors.grey[400])),
                trailing: (isSuperAdmin || isAdmin)
                    ? Icon(Icons.edit, color: Colors.grey[400])
                    : null,
                onTap: () {
                  if (isSuperAdmin || isAdmin) {
                    final textController =
                        TextEditingController(text: currentChat['about']);
                    Get.dialog(
                      AlertDialog(
                        title: const Text('Edit Group Description'),
                        content: TextField(
                          controller: textController,
                          style: const TextStyle(color: Colors.white),
                        ),
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
                    'Participants (${currentChat['participants']?.length ?? 0})', style: TextStyle(color: Colors.white)),
                trailing: (isSuperAdmin || isAdmin)
                    ? IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          // TODO: Implement add participants
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
                    child: p['avatar'] == null || p['avatar'].isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(p['name'] ?? 'Unknown', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    isParticipantSuperAdmin
                        ? 'Super Admin'
                        : isParticipantAdmin
                            ? 'Admin'
                            : 'Member',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
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
                      content: const Text(
                          'Are you sure you want to leave this group?'),
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
      }),
    );
  }
}
