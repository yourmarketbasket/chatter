import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';

class FollowersPage extends StatefulWidget {
  const FollowersPage({Key? key}) : super(key: key);

  @override
  _FollowersPageState createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> with SingleTickerProviderStateMixin {
  final DataController _dataController = Get.find<DataController>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Fetch initial data for both tabs
    // Assuming current user's ID is needed, get it from dataController.user
    final String currentUserId = _dataController.user.value['id']?.toString() ?? 'currentUser';
    if (_dataController.followers.isEmpty) {
      _dataController.fetchFollowers(currentUserId).catchError((e) {
        Get.snackbar('Error', 'Could not load followers: ${e.toString()}',
            backgroundColor: Colors.red, colorText: Colors.white);
      });
    }
    if (_dataController.following.isEmpty) {
      _dataController.fetchFollowing(currentUserId).catchError((e) {
        Get.snackbar('Error', 'Could not load following list: ${e.toString()}',
            backgroundColor: Colors.red, colorText: Colors.white);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(
          'Network', // Or 'Connections', 'Followers'
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
    return Obx(() {
      if (isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
      }
      if (userList.isEmpty) {
        return Center(
          child: Text(
            emptyMessage,
            style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 16),
          ),
        );
      }
      return ListView.separated(
        itemCount: userList.length,
        separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 80),
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemBuilder: (context, index) {
          final user = userList[index];
          final String avatarUrl = user['avatar'] ?? 'https://via.placeholder.com/150/grey/white?text=U';
          final String username = user['username'] ?? 'Unknown User';
          final String name = user['name'] ?? ''; // Optional: if 'name' field exists

          return ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage: CachedNetworkImageProvider(avatarUrl),
            ),
            title: Text(
              username,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16),
            ),
            subtitle: name.isNotEmpty
                ? Text(
                    name,
                    style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
                  )
                : null,
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: user['isFollowing'] == true ? Colors.transparent : Colors.tealAccent,
                side: user['isFollowing'] == true ? BorderSide(color: Colors.grey[600]!) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                // Placeholder: Implement follow/unfollow logic
                final String currentUserId = _dataController.user.value['id']?.toString() ?? 'currentUser';
                _dataController.toggleFollowStatus(currentUserId, user['id'], !(user['isFollowing'] == true));
                 Get.snackbar(
                  'Action',
                  'Follow/Unfollow action for $username (placeholder).',
                  backgroundColor: Colors.blueGrey, colorText: Colors.white);
              },
              child: Text(
                user['isFollowing'] == true ? 'Unfollow' : 'Follow',
                style: GoogleFonts.roboto(
                  color: user['isFollowing'] == true ? Colors.grey[300] : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              // Optional: Navigate to user's profile
              Get.snackbar('Profile', 'View profile of $username (placeholder).',
                  backgroundColor: Colors.indigo, colorText: Colors.white);
            },
          );
        },
      );
    });
  }
}
