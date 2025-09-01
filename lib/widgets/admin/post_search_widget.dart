import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/widgets/admin/user_card.dart';
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
    final theme = Theme.of(context);
    final inputDecoration = InputDecoration(
      labelStyle: GoogleFonts.roboto(color: Colors.white70),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.secondary),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                decoration: inputDecoration.copyWith(
                  labelText: 'Search User by Username',
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                ),
                style: GoogleFonts.roboto(color: Colors.white),
                onSubmitted: (username) async {
                  final result =
                      await dataController.searchUserByUsername(username);
                  if (result['success']) {
                    setState(() {
                      _foundUser = result['user'];
                      final verification = _foundUser?['verification'];
                      if (verification != null) {
                        _selectedEntityType = verification['entityType'];
                        _selectedLevel = verification['level'];
                        _paid = verification['paid'] ?? false;
                      } else {
                        _selectedEntityType = null;
                        _selectedLevel = null;
                        _paid = false;
                      }
                    });
                  } else {
                    setState(() {
                      _foundUser = null;
                    });
                    Get.snackbar('Error', result['message'],
                        snackPosition: SnackPosition.BOTTOM);
                  }
                },
              ),
              if (_foundUser != null) ...[
                const SizedBox(height: 24),
                UserCard(user: _foundUser!),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedEntityType,
                  items: ['individual', 'organization', 'government']
                      .map((label) => DropdownMenuItem(
                            child: Text(label, style: GoogleFonts.roboto()),
                            value: label,
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedEntityType = value;
                    });
                  },
                  decoration: inputDecoration.copyWith(labelText: 'Entity Type'),
                  dropdownColor: Colors.grey[900],
                  style: GoogleFonts.roboto(color: Colors.white),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  items: ['free', 'basic', 'intermediate', 'premium']
                      .map((label) => DropdownMenuItem(
                            child: Text(label, style: GoogleFonts.roboto()),
                            value: label,
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLevel = value;
                    });
                  },
                  decoration: inputDecoration.copyWith(labelText: 'Level'),
                  dropdownColor: Colors.grey[900],
                  style: GoogleFonts.roboto(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: CheckboxListTile(
                    title: Text('Paid', style: GoogleFonts.roboto(color: Colors.white)),
                    value: _paid,
                    onChanged: (value) {
                      setState(() {
                        _paid = value ?? false;
                      });
                    },
                    activeColor: theme.colorScheme.secondary,
                    checkColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (_foundUser != null &&
                        _selectedEntityType != null &&
                        _selectedLevel != null) {
                      final result =
                          await dataController.updateUserVerification(
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
                      if (result['success']) {
                        // Refetch user to show updated verification
                        final updatedUserResult = await dataController
                            .searchUserByUsername(_searchController.text);
                        if (updatedUserResult['success']) {
                          setState(() {
                            _foundUser = updatedUserResult['user'];
                          });
                        }
                      }
                    } else {
                      Get.snackbar(
                        'Error',
                        'Please fill out all fields.',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Update Verification',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
