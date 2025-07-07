import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';

class ProfilePage extends StatelessWidget {
  final String userId; // Might be used later for fetching full profile
  final String username;
  final String? userAvatarUrl;

  const ProfilePage({
    Key? key,
    required this.userId,
    required this.username,
    this.userAvatarUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String avatarInitial = (username.isNotEmpty) ? username[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          username, // Display username in AppBar title
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Back button color
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 60, // Larger avatar
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: userAvatarUrl != null && userAvatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(userAvatarUrl!)
                    : null,
                child: (userAvatarUrl == null || userAvatarUrl!.isEmpty)
                    ? Text(
                        avatarInitial,
                        style: GoogleFonts.poppins(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 50,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                '@$username',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Followers: (coming soon)',
                style: GoogleFonts.roboto(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                icon: Icon(FeatherIcons.messageCircle, color: Colors.black),
                label: Text(
                  'Direct Message (coming soon)',
                  style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  // Placeholder action
                  print('Direct Message button tapped for user $userId');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Direct Message functionality coming soon for $username!', style: GoogleFonts.roboto()),
                      backgroundColor: Colors.tealAccent.withOpacity(0.8),
                    ),
                  );
                },
              ),
              // Add more profile details or user's posts feed here later
            ],
          ),
        ),
      ),
    );
  }
}
