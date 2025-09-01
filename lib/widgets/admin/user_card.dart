import 'package:chatter/helpers/verification_helper.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const UserCard({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? userAvatar = user['avatar'] as String?;
    final String username = user['name'] as String? ?? 'Unknown';
    final String avatarInitial = (username.isNotEmpty ? username[0].toUpperCase() : '?');

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.tealAccent.withOpacity(0.2),
              backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? CachedNetworkImageProvider(userAvatar) : null,
              child: userAvatar == null || userAvatar.isEmpty ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: 24)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        username,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        color: getVerificationBadgeColor(
                          user['verification']?['entityType'],
                          user['verification']?['level'],
                        ),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${user['_id']}',
                    style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                  ),
                  if (user['verification'] != null)
                    Text(
                      'Verification: ${user['verification']['level']} (${user['verification']['entityType']})',
                      style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                    )
                  else
                    Text(
                      'Not Verified',
                      style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
