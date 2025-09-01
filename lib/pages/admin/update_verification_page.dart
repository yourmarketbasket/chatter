import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/helpers/verification_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateVerificationPage extends StatefulWidget {
  const UpdateVerificationPage({Key? key}) : super(key: key);

  @override
  _UpdateVerificationPageState createState() => _UpdateVerificationPageState();
}

class _UpdateVerificationPageState extends State<UpdateVerificationPage> {
  final DataController dataController = Get.find<DataController>();
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _foundUser;
  String? _selectedEntityType;
  String? _selectedLevel;
  bool _paid = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search User by Username',
                labelStyle: GoogleFonts.roboto(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.tealAccent),
                ),
              ),
              style: GoogleFonts.roboto(color: Colors.white),
              onSubmitted: (username) async {
                final result = await dataController.searchUserByUsername(username);
                if (result['success']) {
                  setState(() {
                    _foundUser = result['user'];
                    _selectedEntityType = _foundUser?['verification']?['entityType'];
                    _selectedLevel = _foundUser?['verification']?['level'];
                    _paid = _foundUser?['verification']?['paid'] ?? false;
                  });
                } else {
                  Get.snackbar('Error', result['message'],
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white);
                }
              },
            ),
            if (_foundUser != null) ...[
              const SizedBox(height: 20),
              _UserProfileCard(user: _foundUser!),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedEntityType,
                items: ['individual', 'organization', 'government']
                    .map((label) => DropdownMenuItem(
                          child: Text(label, style: GoogleFonts.roboto(color: Colors.white)),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEntityType = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Entity Type',
                  labelStyle: GoogleFonts.roboto(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.tealAccent),
                  ),
                ),
                dropdownColor: Colors.grey[800],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                items: ['free', 'basic', 'intermediate', 'premium']
                    .map((label) => DropdownMenuItem(
                          child: Text(label, style: GoogleFonts.roboto(color: Colors.white)),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Level',
                  labelStyle: GoogleFonts.roboto(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.tealAccent),
                  ),
                ),
                 dropdownColor: Colors.grey[800],
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: Text('Paid', style: GoogleFonts.roboto(color: Colors.white)),
                value: _paid,
                onChanged: (value) {
                  setState(() {
                    _paid = value ?? false;
                  });
                },
                activeColor: Colors.tealAccent,
                checkColor: Colors.black,
                tileColor: Colors.grey[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.verified_user),
                label: Text('Update Verification', style: GoogleFonts.roboto()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.tealAccent, side: const BorderSide(color: Colors.tealAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (_foundUser != null &&
                      _selectedEntityType != null &&
                      _selectedLevel != null) {
                    final result = await dataController.updateUserVerification(
                      _foundUser!['_id'],
                      _selectedEntityType!,
                      _selectedLevel!,
                      _paid,
                    );
                    if (result['success']) {
                      setState(() {
                        _foundUser!['verification'] = result['verification'];
                      });
                    }
                    Get.snackbar(
                      result['success'] ? 'Success' : 'Error',
                      result['message'],
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: result['success'] ? Colors.green : Colors.red,
                      colorText: Colors.white,
                    );
                  } else {
                    Get.snackbar(
                      'Error',
                      'Please fill out all fields.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserProfileCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserProfileCard({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String name = user['name'] ?? 'N/A';
    final String? avatar = user['avatar'];
    final verification = user['verification'];
    final String verificationStatus = verification != null
        ? '${verification['level']} (${verification['entityType']})'
        : 'Not Verified';
    final Color badgeColor = getVerificationBadgeColor(
        verification?['entityType'], verification?['level']);

    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      elevation: 5,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 40.0, bottom: 20.0, left: 20, right: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: badgeColor, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      verificationStatus,
                      style: GoogleFonts.roboto(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: -30,
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.black,
              child: CircleAvatar(
                radius: 32,
                backgroundImage: (avatar != null && avatar.isNotEmpty)
                    ? NetworkImage(avatar)
                    : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.poppins(fontSize: 30, color: Colors.white),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
