import 'package:chatter/pages/chat_screen_page.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:chatter/helpers/verification_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/Get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatter/widgets/app_drawer.dart';

class UsersListPage extends StatefulWidget {
  const UsersListPage({Key? key}) : super(key: key);

  @override
  _UsersListPageState createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  final DataController _dataController = Get.find<DataController>();
  final RxMap<String, bool> _isUpdatingFollowStatus = <String, bool>{}.obs;
  bool _isGroupCreationMode = false;
  final List<Map<String, dynamic>> _selectedUsers = [];
  final TextEditingController _searchController = TextEditingController();
  final RxList<Map<String, dynamic>> _filteredUsers = <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_dataController.allUsers.isEmpty) {
          _dataController.fetchAllUsers().then((_) {
            _filteredUsers.assignAll(_dataController.allUsers);
          }).catchError((error) {
            print("Error initially fetching all users from initState: $error");
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_){
                if (mounted) {
                   Get.snackbar(
                    'Error Loading Users',
                    'Failed to load users. Please try again later.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red[700],
                    colorText: Colors.white,
                  );
                }
              });
            }
          });
        } else {
          _filteredUsers.assignAll(_dataController.allUsers);
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
      _filteredUsers.assignAll(_dataController.allUsers); // Revert to original list
    } else {
      _filteredUsers.assignAll(_dataController.allUsers.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final username = (user['username'] ?? '').toLowerCase();
        return name.contains(query) || username.contains(query);
      }).toList());
    }
  }

  Future<void> _toggleFollow(String targetUserId, bool currentFollowStatus) async {
    if (_isUpdatingFollowStatus[targetUserId] == true) return;

    _isUpdatingFollowStatus[targetUserId] = true;

    try {
      final String currentUserId = _dataController.user.value['user']['_id'];
      Map<String, dynamic> result;
      if (currentFollowStatus) {
        result = await _dataController.unfollowUser(targetUserId);
      } else {
        result = await _dataController.followUser(targetUserId);
      }

      if (mounted && result['success'] == true) {
         int userIndex = _dataController.allUsers.indexWhere((u) => u['_id'] == targetUserId);
         if (userIndex != -1) {
           var userToUpdate = Map<String, dynamic>.from(_dataController.allUsers[userIndex]);
           userToUpdate['isFollowingCurrentUser'] = !currentFollowStatus;
           _dataController.allUsers[userIndex] = userToUpdate;
           _filterUsers(); // Update filtered list to reflect follow status
         }
      } else if (mounted) {
        Get.snackbar(
          'Error',
          result['message'] ?? 'Failed to update follow status.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          'An unexpected error occurred.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) {
       _isUpdatingFollowStatus[targetUserId] = false;
      }
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
          value: 'select',
          child: Row(
            children: [
              const Icon(Icons.person_add, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Text(
                _isGroupCreationMode ? 'Unselect' : 'Select',
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
      if (value == 'select') {
        setState(() {
          _isGroupCreationMode = !_isGroupCreationMode;
          if (!_isGroupCreationMode) {
            _selectedUsers.clear();
          }
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
        title: Text(
          _isGroupCreationMode ? 'Select Users' : 'Browse Users',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showGroupMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.roboto(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
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
                            ? 'No users found or failed to load.'
                            : 'No users match your search.',
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
                        onPressed: () => _dataController.fetchAllUsers().then((_) {
                          _filterUsers();
                        }),
                      )
                    ],
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredUsers.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey[850],
                  height: 1,
                  indent: 72,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  final String userId = user['_id'] ?? '';
                  final String avatarUrl = user['avatar'] ?? '';
                  final String name = user['name'] ?? 'User';
                  final String username = user['username'] ?? 'username';
                  final int followersCount = user['followersCount'] ?? 0;
                  final int followingCount = user['followingCount'] ?? 0;
                  final bool isFollowing = user['isFollowingCurrentUser'] ?? false;
                  final String avatarInitial = name.isNotEmpty
                      ? name[0].toUpperCase()
                      : (username.isNotEmpty ? username[0].toUpperCase() : '?');

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
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
                            fontSize: 13,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.verified,
                              color: getVerificationBadgeColor(
                                  user['verification']?['entityType'],
                                  user['verification']?['level']),
                              size: 12),
                        )
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@$username',
                          style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$followersCount Followers',
                              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '·',
                              style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$followingCount Following',
                              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 9),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Obx(() {
                      final bool isLoadingFollowAction = _isUpdatingFollowStatus[userId] ?? false;
                      return ElevatedButton(
                        onPressed: isLoadingFollowAction
                            ? null
                            : () => _toggleFollow(userId, isFollowing),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.transparent : Colors.white,
                          foregroundColor: isFollowing ? Colors.white : Colors.black,
                          side: isFollowing ? BorderSide(color: Colors.grey[700]!) : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: const Size(90, 36),
                        ),
                        child: isLoadingFollowAction
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isFollowing ? Colors.white : Colors.black,
                                  ),
                                ),
                              )
                            : Text(
                                isFollowing ? 'Unfollow' : 'Follow',
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      );
                    }),
                    onTap: () async {
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
                    selected: _isGroupCreationMode && _selectedUsers.any((u) => u['_id'] == userId),
                    selectedTileColor: Colors.teal.withOpacity(0.2),
                  );
                },
                padding: const EdgeInsets.only(bottom: 16),
              );
            }),
          ),
        ],
      ),
      drawer: const AppDrawer(),
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