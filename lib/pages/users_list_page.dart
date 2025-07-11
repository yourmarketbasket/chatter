import 'package:chatter/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatter/widgets/app_drawer.dart'; // Import the drawer

class UsersListPage extends StatefulWidget {
  const UsersListPage({Key? key}) : super(key: key);

  @override
  _UsersListPageState createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  final DataController _dataController = Get.find<DataController>();
  final RxString _processingFollowUserId = ''.obs; // To track loading state for follow/unfollow buttons


  @override
  void initState() {
    super.initState();
    // Fetch users if the list is empty or to refresh
    _dataController.fetchAllUsers().catchError((error) {
      print("Error fetching all users: $error");
      if (mounted) {
        Get.snackbar(
          'Error',
          'Failed to load users: ${error.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    });
  }

  Future<void> _handleFollowToggle(String targetUserId, bool isCurrentlyFollowing) async {
     if (_processingFollowUserId.value == targetUserId) return; // Already processing

    _processingFollowUserId.value = targetUserId;
    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';

    if (currentUserId.isEmpty) {
      Get.snackbar('Error', 'Could not identify current user.', backgroundColor: Colors.red);
      _processingFollowUserId.value = '';
      return;
    }

    Map<String, dynamic> result;
    if (isCurrentlyFollowing) {
      result = await _dataController.unfollowUser(targetUserId);
    } else {
      result = await _dataController.followUser(targetUserId);
    }

    if (mounted) {
        if (result['success'] == true) {
            // Optimistically update the specific user in the allUsers list
            // This is important if the backend doesn't immediately reflect the change
            // or if we don't want to re-fetch the entire list.
            int userIndex = _dataController.allUsers.indexWhere((u) => u['_id'] == targetUserId);
            if (userIndex != -1) {
                var userToUpdate = Map<String, dynamic>.from(_dataController.allUsers[userIndex]);
                var followersList = List<dynamic>.from(userToUpdate['followers'] ?? []);

                if (isCurrentlyFollowing) { // Was following, now unfollowed
                    followersList.removeWhere((followerId) => followerId == currentUserId);
                     // Also update logged-in user's following list
                    var loggedInUserFollowing = List<dynamic>.from(_dataController.user.value['user']?['following'] ?? []);
                    loggedInUserFollowing.removeWhere((id) => id == targetUserId);
                    _dataController.user.value['user']['following'] = loggedInUserFollowing;


                } else { // Was not following, now followed
                    if (!followersList.contains(currentUserId)) {
                        followersList.add(currentUserId);
                    }
                    // Also update logged-in user's following list
                    var loggedInUserFollowing = List<dynamic>.from(_dataController.user.value['user']?['following'] ?? []);
                    if (!loggedInUserFollowing.contains(targetUserId)) {
                       loggedInUserFollowing.add(targetUserId);
                    }
                    _dataController.user.value['user']['following'] = loggedInUserFollowing;
                }
                userToUpdate['followers'] = followersList;
                _dataController.allUsers[userIndex] = userToUpdate;
                _dataController.allUsers.refresh();
                _dataController.user.refresh(); // Refresh to update app drawer if necessary
            }

            Get.snackbar(
            isCurrentlyFollowing ? 'Unfollowed' : 'Followed',
            result['message'] ?? (isCurrentlyFollowing ? 'Successfully unfollowed user.' : 'Successfully followed user.'),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            );
        } else {
            Get.snackbar(
            'Error',
            result['message'] ?? 'Failed to perform action.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            );
        }
        _processingFollowUserId.value = '';
    }
  }


  @override
  Widget build(BuildContext context) {
    final String currentUserId = _dataController.user.value['user']?['_id'] ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Browse Users',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: Obx(() {
        if (_dataController.isLoading.value && _dataController.allUsers.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
            ),
          );
        }
        if (!_dataController.isLoading.value && _dataController.allUsers.isEmpty) {
          return Center(
            child: Text(
              "No users found. Try refreshing.",
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 16),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _dataController.fetchAllUsers(),
          color: Colors.tealAccent,
          backgroundColor: Colors.black,
          child: ListView.separated(
            itemCount: _dataController.allUsers.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 70, endIndent: 16),
            itemBuilder: (context, index) {
              final user = _dataController.allUsers[index];
              final String userId = user['_id'] ?? '';
              final String avatarUrl = user['avatar'] ?? '';
              // User schema uses 'name' for the unique username.
              final String username = user['name'] ?? 'Unknown User';
              final List<dynamic> followers = user['followers'] ?? [];
              final List<dynamic> following = user['following'] ?? [];
              final String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';

              // Check if the current logged-in user is following this user.
              // The `followers` field on `user` (the one being displayed) lists IDs of users WHO FOLLOW THEM.
              // We need to check if `currentUserId` is in `user['followers']`.
              // No, this is wrong. To check if I (current user) am following `user`,
              // I need to check if `user['_id']` is in `_dataController.user.value['user']['following']`.
              final List<dynamic> loggedInUserFollowingList = _dataController.user.value['user']?['following'] ?? [];
              final bool isFollowingThisUser = loggedInUserFollowingList.any((id) => id == userId);


              // Don't display the current logged-in user in the list
              if (userId == currentUserId) {
                return const SizedBox.shrink(); // Or some other placeholder if you want to mark it
              }

              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.tealAccent.withOpacity(0.2),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
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
                title: Text(
                  username,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Followers: ${followers.length} · Following: ${following.length}',
                  style: GoogleFonts.roboto(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
                trailing: Obx(() {
                   final bool isLoadingFollowAction = _processingFollowUserId.value == userId;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowingThisUser ? Colors.transparent : Colors.tealAccent,
                        side: isFollowingThisUser ? BorderSide(color: Colors.grey[600]!) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Adjusted padding
                        minimumSize: const Size(80, 30), // Ensure button has a decent minimum size
                      ),
                      onPressed: isLoadingFollowAction ? null : () => _handleFollowToggle(userId, isFollowingThisUser),
                      child: isLoadingFollowAction
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : Text(
                              isFollowingThisUser ? 'Unfollow' : 'Follow',
                              style: GoogleFonts.roboto(
                                color: isFollowingThisUser ? Colors.grey[300] : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                    );
                }),
                onTap: () {
                  Get.to(() => ProfilePage(userId: userId, username: username, userAvatarUrl: avatarUrl));
                },
              );
            },
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        );
      }),
    );
  }
}
