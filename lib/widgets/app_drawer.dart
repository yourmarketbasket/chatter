import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/users_list_page.dart'; // Will be created in a later step
import 'package:chatter/pages/direct_messages_page.dart';
import 'package:chatter/pages/followers_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();
    // Observe the user data for reactive updates
    final user = dataController.user.value;
    final String? avatarUrl = user['avatar'];
    final String username = user['username'] ?? 'User';
    final String email = user['email'] ?? 'user@example.com'; // Assuming email is available

    // Fallback avatar initial
    final String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Drawer(
      backgroundColor: const Color(0xFF121212), // Darker background for the drawer
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(
              username,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            accountEmail: Text(
              email,
              style: GoogleFonts.roboto(fontSize: 14),
            ),
            currentAccountPicture: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.tealAccent.withOpacity(0.3),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(
                          avatarInitial,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Colors.tealAccent,
                    shape: const CircleBorder(),
                    elevation: 2.0,
                    child: InkWell(
                      onTap: () {
                        // TODO: Implement avatar upload functionality
                        Get.snackbar(
                          'Coming Soon!',
                          'Avatar upload functionality will be implemented later.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.teal[700],
                          colorText: Colors.white,
                        );
                      },
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(
                          FeatherIcons.edit2,
                          size: 16.0,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            decoration: BoxDecoration(
              color: Colors.teal[700], // Teal color for the header background
            ),
          ),
          ListTile(
            leading: Icon(FeatherIcons.rss, color: Colors.grey[300]),
            title: Text(
              'My Feeds',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back(); // Close the drawer
              // Navigate to HomeFeedScreen, ensuring it's the main view
              // If already on HomeFeedScreen, just close drawer. Otherwise, navigate.
              if (Get.currentRoute != '/HomeFeedScreen') { // Check current route if defined
                Get.offAll(() => const HomeFeedScreen()); // Use offAll to clear stack if coming from elsewhere
              }
            },
          ),
          ListTile(
            leading: Icon(FeatherIcons.users, color: Colors.grey[300]),
            title: Text(
              'Browse Users',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back(); // Close the drawer
              // Navigate to UsersListPage - This page will be created in the next step
              // For now, this will throw an error if UsersListPage is not created.
              // We'll create UsersListPage in the next plan step.
               Get.to(() => const UsersListPage());
            },
          ),
          // New Items:
          ListTile(
            leading: Icon(FeatherIcons.messageSquare, color: Colors.grey[300]),
            title: Text(
              'Direct Messages',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back();
              Get.to(() => const DirectMessagesPage());
            },
          ),
          ListTile(
            leading: Icon(FeatherIcons.gitMerge, color: Colors.grey[300]), // Changed icon for Network to avoid clash
            title: Text(
              'Network',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back();
              Get.to(() => const FollowersPage());
            },
          ),
          const Divider(color: Color(0xFF303030)),
          ListTile(
            leading: Icon(FeatherIcons.settings, color: Colors.grey[300]),
            title: Text(
              'Settings',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              // TODO: Implement settings page navigation
              Get.back();
              Get.snackbar('Coming Soon!', 'Settings page is under development.',
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.amber[700], colorText: Colors.black);
            },
          ),
          ListTile(
            leading: Icon(FeatherIcons.logOut, color: Colors.grey[300]),
            title: Text(
              'Logout',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              // TODO: Implement logout functionality (clear token, navigate to login)
              Get.back();
              Get.snackbar('Placeholder', 'Logout functionality to be implemented.',
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange[700], colorText: Colors.white);
            },
          ),
        ],
      ),
    );
  }
}
