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

  @override
  void initState() {
    super.initState();
    // Fetch users if the list is empty
    if (_dataController.allUsers.isEmpty) {
      _dataController.fetchAllUsers().catchError((error) {
        print("Error fetching all users: $error");
        Get.snackbar(
          'Error',
          'Failed to load users.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xFF121212), // Slightly different shade for app bar
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Ensure back button is white
      ),
      drawer: const AppDrawer(), // Add the drawer here
      body: Obx(() {
        if (_dataController.allUsers.isEmpty) {
          // Show loading indicator or a message if fetch is in progress or failed
          // For now, simple check. Could be enhanced with a loading state in DataController.
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
            ),
          );
        }
        return ListView.separated(
          itemCount: _dataController.allUsers.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey[850], height: 1, indent: 70, endIndent: 16),
          itemBuilder: (context, index) {
            final user = _dataController.allUsers[index];
            final String avatarUrl = user['avatar'] ?? '';
            final String username = user['username'] ?? 'Unknown User';
            final String email = user['email'] ?? 'No email';
            final String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';

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
                email,
                style: GoogleFonts.roboto(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
              ),
              onTap: () {
                // TODO: Implement navigation to a user's profile page or chat
                Get.snackbar(
                  'User Profile',
                  'Viewing profile for $username (Not implemented yet).',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.blueGrey[700],
                  colorText: Colors.white,
                );
              },
            );
          },
          padding: const EdgeInsets.symmetric(vertical: 8),
        );
      }),
    );
  }
}
