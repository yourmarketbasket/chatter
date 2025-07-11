import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
// import 'package:feather_icons/feather_icons.dart'; // Not explicitly used for icons here

class FollowersPage extends StatefulWidget {
  // Optional: If you want to view followers/following of a user other than the logged-in one.
  final String? viewUserId;

  const FollowersPage({Key? key, this.viewUserId}) : super(key: key);

  @override
  _FollowersPageState createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> with SingleTickerProviderStateMixin {
  final DataController _dataController = Get.find<DataController>();
  late TabController _tabController;
  final RxString _processingFollowUserId = ''.obs; // For button loading state

  late String _targetUserId; // The user whose followers/following list we are viewing

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Determine whose network to view: the passed userId or the current logged-in user.
    _targetUserId = widget.viewUserId ?? _dataController.user.value['user']?['_id']?.toString() ?? '';

    if (_targetUserId.isEmpty) {
      // Handle error: cannot determine user
      Get.snackbar('Error', 'Cannot determine user for network view.',
          backgroundColor: Colors.red, colorText: Colors.white);
      // Potentially navigate back or show an error message prominently
      return;
    }

    // Fetch initial data for both tabs based on _targetUserId
    // Do not check if lists are empty, always refresh for the target user.
    _dataController.fetchFollowers(_targetUserId).catchError((e) {
      if(mounted) Get.snackbar('Error', 'Could not load followers: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    });
    _dataController.fetchFollowing(_targetUserId).catchError((e) {
      if(mounted) Get.snackbar('Error', 'Could not load following list: ${e.toString()}',
          backgroundColor: Colors.red, colorText: Colors.white);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleFollowToggle(String targetUserIdToToggle, bool isCurrentlyFollowing) async {
    if (_processingFollowUserId.value == targetUserIdToToggle) return;

    _processingFollowUserId.value = targetUserIdToToggle;
    final String loggedInUserId = _dataController.user.value['user']?['_id'] ?? '';

    if (loggedInUserId.isEmpty) {
      Get.snackbar('Error', 'Could not identify current user.', backgroundColor: Colors.red);
      _processingFollowUserId.value = '';
      return;
    }
    if (loggedInUserId == targetUserIdToToggle) {
       Get.snackbar('Info', 'You cannot follow/unfollow yourself.', backgroundColor: Colors.blueGrey);
      _processingFollowUserId.value = '';
      return;
    }


    Map<String, dynamic> result;
    if (isCurrentlyFollowing) {
      result = await _dataController.unfollowUser(targetUserIdToToggle);
    } else {
      result = await _dataController.followUser(targetUserIdToToggle);
    }

     if (mounted) {
        if (result['success'] == true) {
            // Refresh the lists for the current _targetUserId to reflect changes
            // This is important because the 'isFollowing' status for items in the list might change
            // if the loggedInUser is the one whose network page (_targetUserId) is being viewed.
            // Or if the backend doesn't immediately reflect the change in the next fetch.
            // A more targeted update would be better if possible.

            // Optimistic local update of the button state for the specific user toggled
            _updateLocalUserFollowState(_dataController.followers, targetUserIdToToggle, !isCurrentlyFollowing);
            _updateLocalUserFollowState(_dataController.following, targetUserIdToToggle, !isCurrentlyFollowing);


            // If the current page is for the logged-in user, their main user object's following list also needs update
            if (_targetUserId == loggedInUserId) {
                 var loggedInUserObject = Map<String,dynamic>.from(_dataController.user.value['user'] ?? {});
                 var currentFollowingList = List<dynamic>.from(loggedInUserObject['following'] ?? []);
                 if (!isCurrentlyFollowing) { // Means we just followed
                    if (!currentFollowingList.contains(targetUserIdToToggle)) {
                        currentFollowingList.add(targetUserIdToToggle);
                    }
                 } else { // Means we just unfollowed
                    currentFollowingList.remove(targetUserIdToToggle);
                 }
                 loggedInUserObject['following'] = currentFollowingList;
                 _dataController.user.value['user'] = loggedInUserObject;
                 _dataController.user.refresh(); // For app drawer updates
            }


            Get.snackbar(
            isCurrentlyFollowing ? 'Unfollowed' : 'Followed',
            result['message'] ?? (isCurrentlyFollowing ? 'Successfully unfollowed.' : 'Successfully followed.'),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            );
        } else {
            Get.snackbar(
            'Error',
            result['message'] ?? 'Action failed.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            );
        }
        _processingFollowUserId.value = '';
    }
  }

  void _updateLocalUserFollowState(RxList<Map<String, dynamic>> list, String userId, bool newFollowState) {
    int index = list.indexWhere((u) => u['_id'] == userId);
    if (index != -1) {
        var userToUpdate = Map<String, dynamic>.from(list[index]);
        userToUpdate['isFollowing'] = newFollowState; // 'isFollowing' here means "is loggedInUser following this person"
        list[index] = userToUpdate;
        list.refresh();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Network',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
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
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_dataController.followers, _dataController.isLoadingFollowers, "No followers yet."),
          _buildUserList(_dataController.following, _dataController.isLoadingFollowing, "Not following anyone yet."),
        ],
      ),
    );
  }

  Widget _buildUserList(RxList<Map<String, dynamic>> userList, RxBool isLoading, String emptyMessage) {
    final String loggedInUserId = _dataController.user.value['user']?['_id'] ?? '';

    return Obx(() {
      if (isLoading.value && userList.isEmpty) { // Show loader only if list is empty and loading
        return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent)));
      }
      if (userList.isEmpty) {
        return Center(
          child: Text(
            emptyMessage,
            style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async {
            if (_tabController.index == 0) { // Followers tab
                await _dataController.fetchFollowers(_targetUserId);
            } else { // Following tab
                await _dataController.fetchFollowing(_targetUserId);
            }
        },
        color: Colors.tealAccent,
        backgroundColor: Colors.black,
        child: ListView.separated(
          itemCount: userList.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemBuilder: (context, index) {
            final userFromList = userList[index];
            final String listUserAvatarUrl = userFromList['avatar'] ?? '';
            // User schema uses 'name' for unique username. API should return 'name'.
            final String listUsername = userFromList['name'] ?? 'Unknown User';
            final String listUserId = userFromList['_id'] ?? '';
            // 'isFollowing' in userFromList means: is the loggedInUser following this userFromList?
            // This should be correctly set by fetchFollowers/fetchFollowing.
            final bool isFollowingThisListUser = userFromList['isFollowing'] ?? false;
            final String avatarInitial = listUsername.isNotEmpty ? listUsername[0].toUpperCase() : '?';


            return ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: listUserAvatarUrl.isNotEmpty ? CachedNetworkImageProvider(listUserAvatarUrl) : null,
                child: listUserAvatarUrl.isEmpty ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight:FontWeight.w600, fontSize: 18)) : null,
              ),
              title: Text(
                listUsername,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16),
              ),
              // Subtitle can be 'About' or other info if available and desired.
              // subtitle: userFromList['about'] != null && userFromList['about'].isNotEmpty
              //     ? Text(
              //         userFromList['about'],
              //         maxLines: 1,
              //         overflow: TextOverflow.ellipsis,
              //         style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
              //       )
              //     : null,
              trailing: loggedInUserId == listUserId // Don't show follow button for self
                ? null
                : Obx(() {
                    final bool isLoadingFollowAction = _processingFollowUserId.value == listUserId;
                    return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowingThisListUser ? Colors.transparent : Colors.tealAccent,
                        side: isFollowingThisListUser ? BorderSide(color: Colors.grey[600]!) : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: const Size(80, 30),
                        ),
                        onPressed: isLoadingFollowAction ? null : () => _handleFollowToggle(listUserId, isFollowingThisListUser),
                        child: isLoadingFollowAction
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : Text(
                                isFollowingThisListUser ? 'Unfollow' : 'Follow',
                                style: GoogleFonts.roboto(
                                color: isFollowingThisListUser ? Colors.grey[300] : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12
                                ),
                            ),
                    );
                }),
              onTap: () {
                 Get.to(() => ProfilePage(userId: listUserId, username: listUsername, userAvatarUrl: listUserAvatarUrl));
              },
            );
          },
        ),
      );
    });
  }
}
