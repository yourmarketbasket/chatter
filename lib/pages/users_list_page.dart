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
  final Function(Map<String, dynamic>)? onUserSelected;
  final bool isGroupCreationMode;

  const UsersListPage({Key? key, this.onUserSelected, this.isGroupCreationMode = false}) : super(key: key);

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
    _isGroupCreationMode = widget.isGroupCreationMode;
    // Data is now primarily loaded by DataController's init method.
    // This page will reactively display the users from _dataController.allUsers.
    // We still need to initialize the filteredUsers list and listen for search changes.
    if (_dataController.allUsers.isNotEmpty) {
      _filterUsers();
    }
    _searchController.addListener(() {
      _filterUsers();
    });

    // Listen to changes in allUsers from the controller to update the filtered list
    _dataController.allUsers.listen((_) {
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
    bool isCreating = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: Text('New Group', style: GoogleFonts.poppins(color: Colors.white)),
            content: TextField(
              controller: groupNameController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Group Name',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCreating ? null : () => Get.back(),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
              ),
              TextButton(
                onPressed: isCreating ? null : () async {
                  if (groupNameController.text.isNotEmpty) {
                    setState(() {
                      isCreating = true;
                    });

                    final participantIds = _selectedUsers.map((u) => u['_id'] as String).toList();
                    // No need to manually add the current user; the backend should handle it.

                    final newChat = await _dataController.createGroupChat(
                      participantIds,
                      groupNameController.text,
                    );

                    if (mounted) {
                      // Close the dialog FIRST
                      Get.back();

                      if (newChat != null) {
                        _dataController.currentChat.value = newChat;
                        // Use Get.offAll to clear the selection pages from the stack
                        Get.offAll(() => const ChatScreen());
                      } else {
                        Get.snackbar(
                          'Error',
                          'Could not create group chat. Please try again.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red.shade800,
                          colorText: Colors.white
                        );
                      }
                    }
                  }
                },
                child: isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                        ),
                      )
                    : Text(
                        'Create',
                        style: GoogleFonts.poppins(color: Colors.tealAccent),
                      ),
              ),
            ],
          );
        },
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
            child: RefreshIndicator(
              onRefresh: () async {
                await _dataController.fetchAllUsers();
                _filterUsers();
              },
              child: Obx(() {
                if (_dataController.isLoading.value && _filteredUsers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_filteredUsers.isEmpty) {
                  return Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FeatherIcons.users, size: 48, color: Colors.grey[700]),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No users found. Pull to refresh.'
                                  : 'No users match your search.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      // This makes the empty space scrollable, so RefreshIndicator works.
                      ListView(),
                    ],
                  );
                }

                return ListView.separated(
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
                          Icon(Icons.verified,
                              color: getVerificationBadgeColor(
                                  user['verification']?['entityType'],
                                  user['verification']?['level']),
                              size: 12)
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
                        if (widget.onUserSelected != null) {
                          widget.onUserSelected!(user);
                        } else if (_isGroupCreationMode) {
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
                              'participants': [
                                {'userId': _dataController.user.value['user']},
                                {'userId': user}
                              ],
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