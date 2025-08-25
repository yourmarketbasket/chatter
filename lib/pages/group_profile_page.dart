import 'dart:io';
import 'package:chatter/pages/add_participants_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:image_cropper/image_cropper.dart';
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
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 24),
          titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18),
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
          color: const Color.fromARGB(255, 255, 255, 255),
          surfaceTintColor: Colors.transparent,
          textStyle: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        dialogBackgroundColor: Colors.grey[900],
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titleTextStyle: const TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 20),
          contentTextStyle: const TextStyle(color: Color.fromARGB(179, 78, 78, 78)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.tealAccent,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.tealAccent),
          hintStyle: const TextStyle(color: Colors.white54),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.tealAccent, width: 2),
          ),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
        ),
        chipTheme:  ChipThemeData(
          selectedColor: Color.fromARGB(255, 10, 117, 92).withOpacity(0.2),
          secondarySelectedColor: Colors.amber,
          labelStyle: TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.w500),
          secondaryLabelStyle: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
          padding: EdgeInsets.symmetric(horizontal: 1, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(25)),
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
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 3.2, vertical: 4.8),
              children: [
                // Group Avatar
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: (currentChat['groupAvatar'] != null &&
                                currentChat['groupAvatar'].isNotEmpty)
                            ? NetworkImage(currentChat['groupAvatar'])
                            : null,
                        child: (currentChat['groupAvatar'] == null ||
                                currentChat['groupAvatar'].isEmpty)
                            ? Icon(Icons.group, size: 60, color: Colors.white38)
                            : null,
                      ),
                      if (isSuperAdmin || isAdmin)
                        Positioned(
                          right: -5,
                          bottom: -5,
                          child: Container(
                            decoration:  BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, size: 14, color: Colors.tealAccent),
                              padding: const EdgeInsets.all(2.6),
                              constraints: const BoxConstraints(
                                minWidth: 10,
                                minHeight: 10,
                              ),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(
                                    source: ImageSource.gallery);
                                if (pickedFile != null) {
                                  final cropper = ImageCropper();
                                  final croppedFile = await cropper.cropImage(
                                    sourcePath: pickedFile.path,
                                    uiSettings: [
                                      AndroidUiSettings(
                                          toolbarTitle: 'Crop Image',
                                          toolbarColor: Colors.teal,
                                          toolbarWidgetColor: Colors.white,
                                          initAspectRatio:
                                              CropAspectRatioPreset.square,
                                          lockAspectRatio: true,
                                          aspectRatioPresets: [
                                            CropAspectRatioPreset.square,
                                          ]),
                                      IOSUiSettings(
                                        title: 'Crop Image',
                                        aspectRatioLockEnabled: true,
                                        aspectRatioPickerButtonHidden: true,
                                        resetAspectRatioEnabled: false,
                                        aspectRatioPresets: [
                                          CropAspectRatioPreset.square,
                                        ],
                                      ),
                                    ],
                                  );
                  
                                  if (croppedFile != null) {
                                    final file = File(croppedFile.path);
                                    final avatarUrl =
                                        await dataController.uploadAvatar(file);
                                    if (avatarUrl != null) {
                                      await dataController.updateGroupAvatar(
                                          currentChat['_id'], avatarUrl);
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4.8),
                // Group Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        currentChat['name'] ?? '',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (isSuperAdmin || isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.tealAccent),
                        onPressed: () {
                          final textController =
                              TextEditingController(text: currentChat['name']);
                          Get.dialog(
                            AlertDialog(
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                              backgroundColor: const Color.fromARGB(255, 52, 53, 53),
                              title: const Text('Edit Group Name', style: TextStyle(color: Colors.white)),
                              content: TextField(
                                controller: textController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Enter group name',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    dataController.updateGroupDetails(
                                        currentChat['_id'], name: textController.text);
                                    Get.back();
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 2.4),
                // Group Description
                GestureDetector(
                  onTap: (isSuperAdmin || isAdmin)
                      ? () {
                          final textController =
                              TextEditingController(text: currentChat['about']);
                          Get.dialog(
                            AlertDialog(
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                              backgroundColor: const Color.fromARGB(255, 66, 66, 66),
                              title: const Text('Edit Group Description', style: TextStyle(color: Colors.white)),
                              content: TextField(
                                controller: textController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Enter group description',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    dataController.updateGroupDetails(
                                        currentChat['_id'], about: textController.text);
                                    Get.back();
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    currentChat['about'] ?? 'No description',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6.4),
                // Participants
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Participants (${currentChat['participants']?.length ?? 0})',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.white),
                    ),
                    if (isSuperAdmin || isAdmin)
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.tealAccent),
                        onPressed: () {
                          Get.to(() => AddParticipantsPage(chat: currentChat));
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 2.4),
                ...?(currentChat['participants'] as List<dynamic>?)
                    ?.map((participant) {
                  final p = participant as Map<String, dynamic>;
                  final isParticipantAdmin = currentChat['admins']
                          ?.any((admin) => admin['_id'] == p['_id']) ??
                      false;
                  final isParticipantSuperAdmin =
                      currentChat['superAdmin']?['_id'] == p['_id'];
                  final isMuted = p['isMuted'] ?? false;
            
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 0.8),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: p['avatar'] != null && p['avatar'].isNotEmpty
                          ? NetworkImage(p['avatar'])
                          : null,
                      child: p['avatar'] == null || p['avatar'].isEmpty
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? 'Unknown'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isParticipantSuperAdmin)
                              Chip(
                                padding: EdgeInsets.all(0),
                                label: Row(
                                  children: [
                                    const Icon(Icons.shield,
                                        size: 10, color: Colors.teal),
                                    Text('Super Admin'),
                                  ],
                                ),
                                backgroundColor:
                                    Color.fromARGB(255, 20, 131, 105)
                                        .withOpacity(0.2),
                                side: const BorderSide(color: Colors.transparent),
                              ),
                            if (isParticipantSuperAdmin || isParticipantAdmin)
                              Chip(
                                padding: EdgeInsets.all(0),
                                label: Row(
                                  children: [
                                    const Icon(Icons.shield_outlined,
                                        size: 10, color: Colors.teal),
                                    Text('Admin'),
                                  ],
                                ),
                                backgroundColor:
                                    Color.fromARGB(255, 20, 131, 105)
                                        .withOpacity(0.2),
                                side: const BorderSide(color: Colors.transparent),
                              ),
                            if (!isParticipantSuperAdmin && !isParticipantAdmin)
                              Chip(
                                padding: EdgeInsets.all(0),
                                label: Text('Member'),
                                backgroundColor:
                                    Color.fromARGB(255, 20, 131, 105)
                                        .withOpacity(0.2),
                                side: const BorderSide(
                                    color: Color.fromARGB(0, 104, 35, 35)),
                              ),
                            if (isMuted) const SizedBox(width: 1.6),
                            if (isMuted)
                              Chip(
                                padding: EdgeInsets.all(0),
                                label: Text('Muted'),
                                backgroundColor:
                                    Colors.redAccent.withOpacity(0.2),
                                side: const BorderSide(
                                    color: Color.fromARGB(0, 104, 35, 35)),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: (isSuperAdmin || isAdmin) &&
                            p['_id'] != dataController.user.value['user']['_id']
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white70),
                            onSelected: (value) {
                              switch (value) {
                                case 'remove':
                                  if ((currentChat['participants']?.length ??
                                          0) <=
                                      3) {
                                    Get.dialog(
                                      AlertDialog(
                                        title: const Text('Cannot Remove User'),
                                        content: const Text(
                                            'A group must have at least 3 members.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Get.back(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    dataController.removeMember(
                                        currentChat['_id'], p['_id']);
                                  }
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
                const SizedBox(height: 4.8),
                // // Group Settings
                // if (isSuperAdmin || isAdmin)
                //   ListTile(
                //     contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                //     title: Text(
                //       'Group Settings',
                //       style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Colors.white),
                //     ),
                //     trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                //     onTap: () {
                //       // TODO: Navigate to group settings page
                //     },
                //   ),
                // Leave Group
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  title: const Text(
                    'Leave Group',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Get.dialog(
                      AlertDialog(
                        title: const Text('Leave Group'),
                        content: const Text('Are you sure you want to leave this group?'),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              dataController.leaveGroup(currentChat['_id']);
                              Get.back();
                              Get.back();
                            },
                            child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}