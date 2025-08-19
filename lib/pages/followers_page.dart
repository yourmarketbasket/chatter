import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';

class FollowersPage extends StatefulWidget {
  // If this page can be for a user other than the logged-in one, pass their userId
  final String? viewUserId;

  const FollowersPage({Key? key, this.viewUserId}) : super(key: key);

  @override
  _FollowersPageState createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> with SingleTickerProviderStateMixin {
  final DataController _dataController = Get.find<DataController>();
  late TabController _tabController;
  late String _targetUserId; // The ID of the user whose followers/following are being viewed

  // Local loading state for follow/unfollow buttons
  final RxMap<String, bool> _isUpdatingFollowStatus = <String, bool>{}.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Determine whose followers/following to show
    _targetUserId = widget.viewUserId ?? _dataController.user.value['user']?['_id'] as String? ?? '';

    if (_targetUserId.isEmpty) {
      // Handle error: No user ID to fetch data for.
      // This might happen if logged out or viewUserId is not properly passed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Get.snackbar('Error', 'User ID not found. Cannot load network.',
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      });
      return;
    }

    // Fetch initial data for both tabs for the _targetUserId
    // Clear previous lists and fetch data after the first frame to avoid build errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Ensure the widget is still in the tree
        _dataController.followers.clear();
        _dataController.following.clear();

        _dataController.fetchFollowers(_targetUserId).catchError((e) {
          if (mounted) {
            Get.snackbar('Error', 'Could not load followers: ${e.toString()}',
                backgroundColor: Colors.red, colorText: Colors.white);
          }
        });
        _dataController.fetchFollowing(_targetUserId).catchError((e) {
          if (mounted) {
            Get.snackbar('Error', 'Could not load following list: ${e.toString()}',
                backgroundColor: Colors.red, colorText: Colors.white);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow(String listedUserId, bool currentFollowStatus) async {
    final String loggedInUserId = _dataController.user.value['user']?['_id'] as String? ?? '';
    if (loggedInUserId.isEmpty || loggedInUserId == listedUserId) {
      // Cannot follow/unfollow self, or not logged in
      return;
    }

    if (_isUpdatingFollowStatus[listedUserId] == true) return;
    _isUpdatingFollowStatus[listedUserId] = true;

    try {
      Map<String, dynamic> result;
      if (currentFollowStatus) {
        result = await _dataController.unfollowUser(listedUserId);
      } else {
        result = await _dataController.followUser(listedUserId);
      }

      if (mounted && result['success'] == true) {
        // Optimistically update the UI for the specific user in both lists
        // The DataController's followUser/unfollowUser should update the main user's following list
        // and then we need to re-evaluate 'isFollowingCurrentUser' for all displayed users.
        // A simpler approach for immediate UI feedback is to toggle the state locally.
        // For a more robust solution, fetchFollowers/fetchFollowing could be recalled,
        // or DataController could provide a way to update a specific user's follow status in its lists.

        _updateLocalFollowStatus(_dataController.followers, listedUserId, !currentFollowStatus);
        _updateLocalFollowStatus(_dataController.following, listedUserId, !currentFollowStatus);

      } else if (mounted) {
        Get.snackbar('Error', result['message'] ?? 'Failed to update follow status.',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'An unexpected error occurred: ${e.toString()}',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } finally {
      if (mounted) {
        _isUpdatingFollowStatus[listedUserId] = false;
      }
    }
  }

  void _updateLocalFollowStatus(RxList<Map<String, dynamic>> list, String userId, bool newFollowStatus) {
    int index = list.indexWhere((u) => u['_id'] == userId);
    if (index != -1) {
      var user = Map<String, dynamic>.from(list[index]);
      user['isFollowingCurrentUser'] = newFollowStatus;
      list[index] = user;
    }
  }


  @override
  Widget build(BuildContext context) {
    // Use a different title if viewing someone else's network
    final bool isViewingOwnProfile = widget.viewUserId == null || widget.viewUserId == _dataController.user.value['user']?['_id'];
    final String appBarTitle = isViewingOwnProfile ? 'Your Network' : "${_dataController.allUsers.firstWhereOrNull((u) => u['_id'] == _targetUserId)?['username'] ?? 'User'}'s Network";


    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: GoogleFonts.poppins( color: Colors.white, fontSize: 15),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      drawer: isViewingOwnProfile ? const AppDrawer() : null, // Only show drawer for own network
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_dataController.followers, _dataController.isLoadingFollowers, "No followers yet.", "Failed to load followers."),
          _buildUserList(_dataController.following, _dataController.isLoadingFollowing, "Not following anyone yet.", "Failed to load following list."),
        ],
      ),
    );
  }

  Widget _buildUserList(RxList<Map<String, dynamic>> userList, RxBool isLoadingController, String emptyMessage, String errorMessage) {
    return Obx(() {
      final bool isLoading = isLoadingController.value; // Use the specific loading controller

      if (isLoading && userList.isEmpty) { // Show loading only if list is empty and loading
        return Center(child: CircularProgressIndicator(color: Colors.tealAccent[400]));
      }
      // After loading, if list is still empty, show empty/error message
      if (!isLoading && userList.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FeatherIcons.users, size: 48, color: Colors.grey[700]),
              const SizedBox(height: 16),
              Text(
                // Check if it was an error or just empty due to no data
                // This requires DataController to perhaps set an error flag, or we infer from isLoading being false + list empty
                _dataController.followers.isEmpty && _tabController.index == 0 && !_dataController.isLoadingFollowers.value ? errorMessage :
                _dataController.following.isEmpty && _tabController.index == 1 && !_dataController.isLoadingFollowing.value ? errorMessage : emptyMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(FeatherIcons.refreshCw, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent[700], foregroundColor: Colors.black),
                onPressed: () {
                  if (_tabController.index == 0) {
                    _dataController.fetchFollowers(_targetUserId);
                  } else {
                    _dataController.fetchFollowing(_targetUserId);
                  }
                },
              )
            ],
          )
        );
      }

      return ListView.separated(
        itemCount: userList.length,
        separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 72, endIndent: 16),
        
        itemBuilder: (context, index) {
          final userItem = userList[index];
          print(userItem);
          final String listedUserId = userItem['_id'] ?? '';
          final String avatarUrl = userItem['avatar'] ?? '';
          final String username = userItem['username'] ?? 'username';
          final String name = userItem['name'] ?? 'User';
          final bool isFollowingListedUser = userItem['isFollowingCurrentUser'] ?? false;
          final String avatarInitial = name.isNotEmpty ? name[0].toUpperCase() : (username.isNotEmpty ? username[0].toUpperCase() : '?');
          final String loggedInUserId = _dataController.user.value['user']?['_id'] as String? ?? '';


          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 1.0),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
              child: avatarUrl.isEmpty ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: 18)) : null,
            ),
            title: Row(
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins( color: Colors.white, fontSize: 13),
                ),
                Icon(Icons.verified, color:Colors.amber, size:14)
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username',
                  style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 10),
                ),
                Row(
                  children: [
                    Text('Followers ${userItem['followersCount'].toString()}', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 10)),
                    const SizedBox(width: 10),
                    Text('Following ${userItem['followingCount'].toString()}', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 10)),


                  ],
                )
              ],
            ),
            trailing: (loggedInUserId.isNotEmpty && listedUserId != loggedInUserId) // Only show button if not self and logged in
              ? Obx(() {
                  final bool isLoadingAction = _isUpdatingFollowStatus[listedUserId] ?? false;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowingListedUser ? Colors.transparent : Colors.white,
                      foregroundColor: isFollowingListedUser ? Colors.white : Colors.black,
                      side: isFollowingListedUser ? BorderSide(color: Colors.grey[700]!) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       minimumSize: const Size(90, 36),
                    ),
                    onPressed: isLoadingAction ? null : () => _toggleFollow(listedUserId, isFollowingListedUser),
                    child: isLoadingAction
                        ? SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(isFollowingListedUser ? Colors.white : Colors.black)))
                        : Text(isFollowingListedUser ? 'Unfollow' : 'Follow', style: GoogleFonts.roboto( fontSize: 13)),
                  );
                })
              : null, // No button for self or if not logged in
            onTap: () {
               if (username.isNotEmpty && listedUserId.isNotEmpty) {
                 Get.to(() => ProfilePage(userId: listedUserId, username: username, userAvatarUrl: avatarUrl));
               } else {
                  Get.snackbar('Error', 'Cannot navigate to profile: User data incomplete.', snackPosition: SnackPosition.BOTTOM);
               }
            },
          );
        },
      );
    });
  }
}
