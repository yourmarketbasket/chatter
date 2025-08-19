import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/Get.dart';
import 'package:google_fonts/google_fonts.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final DataController _dataController = Get.find<DataController>();
  bool _isGroupCreationMode = false;
  final List<Map<String, dynamic>> _selectedUsers = [];
  final TextEditingController _searchController = TextEditingController();
  final RxList<Map<String, dynamic>> _filteredUsers = <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_dataController.contacts.isEmpty) {
          _dataController.fetchContacts().then((_) {
            _filteredUsers.assignAll(_dataController.contacts);
          }).catchError((error) {
            print("Error fetching contacts: $error");
            if (mounted) {
              Get.snackbar(
                'Error Loading Contacts',
                'Failed to load contacts. Please try again later.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red[700],
                colorText: Colors.white,
              );
            }
          });
        } else {
          _filteredUsers.assignAll(_dataController.contacts);
        }
      }
    });

    _searchController.addListener(() {
      _filterUsers();
    });
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredUsers.assignAll(_dataController.contacts);
    } else {
      _filteredUsers.assignAll(_dataController.contacts.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        return name.contains(query);
      }).toList());
    }
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

                final newChat = await _dataController.createGroupChat(
                  participantIds,
                  groupNameController.text,
                );

                Get.back();

                if (newChat != null) {
                  _dataController.currentChat.value = newChat;
                  Get.to(() => const ChatScreen());
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

  void _inviteContact() {
    final inviteController = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Invite Contact', style: GoogleFonts.poppins(color: Colors.white)),
        content: TextField(
          controller: inviteController,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter email or username',
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.tealAccent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.tealAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.tealAccent)),
          ),
          TextButton(
            onPressed: () {
              final inviteInput = inviteController.text.trim();
              if (inviteInput.isNotEmpty) {
                Get.snackbar('Invite Sent', 'Invitation sent to $inviteInput',
                    backgroundColor: Colors.teal, colorText: Colors.white);
                Get.back();
              } else {
                Get.snackbar('Error', 'Please enter an email or username',
                    backgroundColor: Colors.red, colorText: Colors.white);
              }
            },
            child: Text('Invite', style: GoogleFonts.poppins(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  void _showGroupMenu(BuildContext context) {
    showMenu(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.tealAccent),
        borderRadius: BorderRadius.circular(8.0),
      ),
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 150,
        kToolbarHeight,
        0,
        0,
      ),
      items: [
        PopupMenuItem(
          value: 'create_group',
          child: Row(
            children: [
              const Icon(Icons.group_add, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Text(
                'Create Group',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ],
          ),
        ),
        if (_isGroupCreationMode)
          PopupMenuItem(
            value: 'select',
            child: Row(
              children: [
                const Icon(Icons.person_add, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Text(
                  'Unselect',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ],
            ),
          ),
        if (_isGroupCreationMode)
          PopupMenuItem(
            value: 'select_all',
            child: Row(
              children: [
                const Icon(Icons.group, color: Colors.tealAccent),
                const SizedBox(width: 8),
                Text(
                  'Select All',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
      color: Colors.black,
    ).then((value) {
      if (value == 'create_group') {
        setState(() {
          _isGroupCreationMode = true;
        });
      } else if (value == 'select') {
        setState(() {
          _isGroupCreationMode = false;
          _selectedUsers.clear();
        });
      } else if (value == 'select_all') {
        setState(() {
          _selectedUsers.clear();
          _selectedUsers.addAll(_filteredUsers);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: _isGroupCreationMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isGroupCreationMode = false;
                    _selectedUsers.clear();
                  });
                },
              )
            : null,
        title: Text(
          _isGroupCreationMode ? 'Select Contacts' : 'Contacts',
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        actions: _isGroupCreationMode
            ? [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isGroupCreationMode = false;
                      _selectedUsers.clear();
                    });
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showGroupMenu(context),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showGroupMenu(context),
                ),
              ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.roboto(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: GestureDetector(
              onTap: _inviteContact,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _inviteContact,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(11.2),
                      minimumSize: const Size(33.6, 33.6),
                    ),
                    child: const Icon(Icons.person_add_alt_1_outlined, size: 16.8),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'Invite Contact',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_filteredUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FeatherIcons.users, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'No contacts found.'
                            : 'No contacts match your search.',
                        style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent[700],
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(FeatherIcons.refreshCw, size: 18),
                        label: const Text('Retry'),
                        onPressed: () => _dataController.fetchContacts().then((_) {
                          _filterUsers();
                        }),
                      )
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  final String userId = user['_id'] ?? '';
                  final String avatarUrl = user['avatar'] ?? '';
                  final String name = user['name'] ?? 'User';
                  final int followersCount = user['followers'].length ?? 0;
                  final int followingCount = user['following'].length ?? 0;
                  final bool isVerified = user['isVerified'] ?? false;
                  final String avatarInitial = name.isNotEmpty
                      ? name[0].toUpperCase()
                      : '?';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.tealAccent.withOpacity(0.2),
                      backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              avatarInitial,
                              style: GoogleFonts.poppins(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        // golden badge
                        
                          const Icon(
                            Icons.verified,
                            color: Colors.amber,
                            size: 12,
                          )
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          '$followersCount Followers',
                          style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 10),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '·',
                          style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$followingCount Following',
                          style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 10),
                        ),
                      ],
                    ),
                    trailing: _isGroupCreationMode
                        ? Icon(
                            _selectedUsers.any((u) => u['_id'] == userId)
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: _selectedUsers.any((u) => u['_id'] == userId)
                                ? Colors.tealAccent
                                : Colors.grey,
                          )
                        : IconButton(
                            icon: const Icon(FeatherIcons.messageCircle, color: Colors.tealAccent),
                            onPressed: () {
                              final currentUserId = _dataController.user.value['user']['_id'];
                              Map<String, dynamic>? existingChat;
                              try {
                                existingChat = _dataController.chats.values.firstWhere(
                                  (chat) {
                                    if (chat['isGroup'] == true) return false;
                                    final participantIds = (chat['participants'] as List).map((p) {
                                      if (p is Map<String, dynamic>) return p['_id'] as String;
                                      return p as String;
                                    }).toSet();
                                    return participantIds.contains(currentUserId) &&
                                        participantIds.contains(userId);
                                  },
                                );
                              } catch (e) {
                                existingChat = null;
                              }

                              if (existingChat != null) {
                                _dataController.currentChat.value = existingChat;
                                Get.to(() => const ChatScreen());
                              } else {
                                final tempChat = {
                                  'participants': [_dataController.user.value['user'], user],
                                  'type': 'dm',
                                };
                                _dataController.currentChat.value = tempChat;
                                Get.to(() => const ChatScreen());
                              }
                            },
                          ),
                    onTap: () {
                      if (_isGroupCreationMode) {
                        setState(() {
                          if (_selectedUsers.any((u) => u['_id'] == userId)) {
                            _selectedUsers.removeWhere((u) => u['_id'] == userId);
                          } else {
                            _selectedUsers.add(user);
                          }
                        });
                      } else {
                        final currentUserId = _dataController.user.value['user']['_id'];
                        Map<String, dynamic>? existingChat;
                        try {
                          existingChat = _dataController.chats.values.firstWhere(
                            (chat) {
                              if (chat['isGroup'] == true) return false;
                              final participantIds = (chat['participants'] as List).map((p) {
                                if (p is Map<String, dynamic>) return p['_id'] as String;
                                return p as String;
                              }).toSet();
                              return participantIds.contains(currentUserId) &&
                                  participantIds.contains(userId);
                            },
                          );
                        } catch (e) {
                          existingChat = null;
                        }

                        if (existingChat != null) {
                          _dataController.currentChat.value = existingChat;
                          Get.to(() => const ChatScreen());
                        } else {
                          final tempChat = {
                            'participants': [_dataController.user.value['user'], user],
                            'type': 'dm',
                          };
                          _dataController.currentChat.value = tempChat;
                          Get.to(() => const ChatScreen());
                        }
                      }
                    },
                    onLongPress: () {
                      if (!_isGroupCreationMode) {
                        setState(() {
                          _isGroupCreationMode = true;
                          _selectedUsers.add(user);
                        });
                      }
                    },
                    selected: _isGroupCreationMode && _selectedUsers.any((u) => u['_id'] == userId),
                    selectedTileColor: Colors.teal.withOpacity(0.2),
                  );
                },
                padding: const EdgeInsets.only(bottom: 4),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: _isGroupCreationMode && _selectedUsers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _createGroup,
              label: const Text('Create Group'),
              icon: const Icon(Icons.check),
              backgroundColor: Colors.tealAccent,
            )
          : null,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}