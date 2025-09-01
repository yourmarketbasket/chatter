import 'package:chatter/controllers/data-controller.dart';
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
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search User by Username',
                labelStyle: GoogleFonts.roboto(color: Colors.white),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: GoogleFonts.roboto(color: Colors.white),
              onSubmitted: (username) async {
                final result = await dataController.searchUserByUsername(username);
                if (result['success']) {
                  setState(() {
                    _foundUser = result['user'];
                  });
                } else {
                  Get.snackbar('Error', result['message']);
                }
              },
            ),
            if (_foundUser != null) ...[
              const SizedBox(height: 20),
              Text('Found User: ${_foundUser!['username']}', style: GoogleFonts.roboto(color: Colors.white)),
              Text('Current Verification: ${_foundUser!['verification'] ?? 'Not Verified'}', style: GoogleFonts.roboto(color: Colors.white)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedEntityType,
                items: ['individual', 'organization', 'government']
                    .map((label) => DropdownMenuItem(
                          child: Text(label),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEntityType = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Entity Type'),
              ),
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                items: ['free', 'basic', 'intermediate', 'premium']
                    .map((label) => DropdownMenuItem(
                          child: Text(label),
                          value: label,
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Level'),
              ),
              CheckboxListTile(
                title: const Text('Paid', style: TextStyle(color: Colors.white)),
                value: _paid,
                onChanged: (value) {
                  setState(() {
                    _paid = value ?? false;
                  });
                },
              ),
              ElevatedButton(
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
                    Get.snackbar(
                      result['success'] ? 'Success' : 'Error',
                      result['message'],
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } else {
                    Get.snackbar(
                      'Error',
                      'Please fill out all fields.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
                child: const Text('Update Verification'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
