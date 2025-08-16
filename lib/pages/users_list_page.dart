import 'package:chatter/pages/conversation_page.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  // Local state to manage button loading
  final RxMap<String, bool> _isUpdatingFollowStatus = <String, bool>{}.obs;
  bool _isGroupCreationMode = false;
  final List<Map<String, dynamic>> _selectedUsers = [];


  @override
  void initState() {
    super.initState();
    // Fetch users. DataController's fetchAllUsers now handles isLoading state.
    // No need to check if allUsers is empty here, as fetchAllUsers will be called
    // and the Obx widget will react to isLoading and allUsers list changes.
    // Wrap in addPostFrameCallback to ensure it runs after the first frame build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Check if widget is still mounted when callback executes
        _dataController.fetchAllUsers().catchError((error) {
          print("Error initially fetching all users from initState: $error");
          if (mounted) {
            // It's good practice to also schedule the snackbar display after the frame,
            // especially if the error handling itself might happen very quickly.
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
      }
    });
  }

  Future<void> _toggleFollow(String targetUserId, bool currentFollowStatus) async {
    if (_isUpdatingFollowStatus[targetUserId] == true) return; // Prevent multiple clicks

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
        // DataController's allUsers list should be updated via its own logic after follow/unfollow
        // For immediate feedback, we can manually update the specific user item's 'isFollowingCurrentUser'
        // This is an optimistic update for the button state.
        // The source of truth (allUsers list) will be updated when DataController's methods complete.
         int userIndex = _dataController.allUsers.indexWhere((u) => u['_id'] == targetUserId);
         if (userIndex != -1) {
           var userToUpdate = Map<String, dynamic>.from(_dataController.allUsers[userIndex]);
           userToUpdate['isFollowingCurrentUser'] = !currentFollowStatus;
           // Assigning to an index of an RxList will automatically trigger updates
           // for Obx widgets listening to this list. Explicit .refresh() is often
           // unnecessary here and can sometimes cause issues if called mid-build.
           _dataController.allUsers[userIndex] = userToUpdate;
           // _dataController.allUsers.refresh(); // Removed this line
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Twitter dark theme background
      appBar: AppBar(
        title: Text(
          _isGroupCreationMode ? 'Select Users' : 'Browse Users',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isGroupCreationMode ? Icons.close : Icons.group_add),
            onPressed: () {
              setState(() {
                _isGroupCreationMode = !_isGroupCreationMode;
                _selectedUsers.clear();
              });
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Obx(() {
        if (_dataController.isLoading.value && _dataController.allUsers.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent[400]!),
            ),
          );
        }
        if (!_dataController.isLoading.value && _dataController.allUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FeatherIcons.users, size: 48, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text(
                  'No users found or failed to load.',
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
                  onPressed: () => _dataController.fetchAllUsers(),
                )
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: _dataController.allUsers.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, index) {
            final user = _dataController.allUsers[index];
            final String userId = user['_id'] ?? '';
            final String avatarUrl = user['avatar'] ?? '';
            final String name = user['name'] ?? 'User'; // Display name
            final String username = user['username'] ?? 'username'; // Handle
            final int followersCount = user['followersCount'] ?? 0;
            final int followingCount = user['followingCount'] ?? 0;
            final bool isFollowing = user['isFollowingCurrentUser'] ?? false;
            final String avatarInitial = name.isNotEmpty ? name[0].toUpperCase() : (username.isNotEmpty ? username[0].toUpperCase() : '?');

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: 18)) : null,
              ),
              title: Text(
                name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('$followersCount Followers', style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('·', style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('$followingCount Following', style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ],
              ),
              trailing: Obx(() {
                // Listen to changes in the loading state for this specific user's button
                final bool isLoadingFollowAction = _isUpdatingFollowStatus[userId] ?? false;

                return ElevatedButton(
                  onPressed: isLoadingFollowAction ? null : () => _toggleFollow(userId, isFollowing),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.transparent : Colors.white,
                    foregroundColor: isFollowing ? Colors.white : Colors.black,
                    side: isFollowing ? BorderSide(color: Colors.grey[700]!) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(90, 36), // Ensure button has a decent size
                  ),
                  child: isLoadingFollowAction
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(isFollowing ? Colors.white : Colors.black),
                          ),
                        )
                      : Text(isFollowing ? 'Unfollow' : 'Follow', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 13)),
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
                  final newChat = await _dataController.createChat([currentUserId, userId]);
                  if (newChat != null) {
                    Get.to(() => ConversationPage(
                          conversationId: newChat.id,
                          username: name,
                          userAvatar: avatarUrl,
                        ));
                  } else {
                    Get.snackbar('Error', 'Could not create chat.',
                        snackPosition: SnackPosition.BOTTOM);
                  }
                }
              },
              selected: _isGroupCreationMode && _selectedUsers.any((u) => u['_id'] == userId),
              selectedTileColor: Colors.teal.withOpacity(0.2),
            );
          },
          padding: const EdgeInsets.only(bottom: 16), // Add padding at the bottom
        );
      }),
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
}
