import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({Key? key}) : super(key: key);

  @override
  _CreateGroupPageState createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final DataController _dataController = Get.find<DataController>();
  final TextEditingController _groupNameController = TextEditingController();
  final List<String> _selectedUserIds = [];

  @override
  void initState() {
    super.initState();
    // Fetch all users to select from
    _dataController.fetchAllUsers();
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _createGroup() async {
    if (_groupNameController.text.trim().isEmpty || _selectedUserIds.length < 2) {
      Get.snackbar(
        'Error',
        'Group name cannot be empty and you must select at least 2 members.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final result = await _dataController.createDummyGroupChat(
      _groupNameController.text.trim(),
      _selectedUserIds,
    );

    if (result['success']) {
      Get.back(); // Go back to the direct messages page
      Get.snackbar(
        'Success',
        'Group created successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Error',
        result['message'] ?? 'Failed to create group.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Create Group', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupNameController,
              style: GoogleFonts.roboto(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Members',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_dataController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_dataController.allUsers.isEmpty) {
                return const Center(child: Text('No users found.'));
              }
              return ListView.builder(
                itemCount: _dataController.allUsers.length,
                itemBuilder: (context, index) {
                  final user = _dataController.allUsers[index];
                  final bool isSelected = _selectedUserIds.contains(user['_id']);
                  return CheckboxListTile(
                    title: Text(user['name'], style: GoogleFonts.roboto(color: Colors.white)),
                    subtitle: Text('@${user['username']}', style: GoogleFonts.roboto(color: Colors.grey[500])),
                    value: isSelected,
                    onChanged: (bool? value) {
                      _toggleUserSelection(user['_id']);
                    },
                    activeColor: Colors.tealAccent,
                    checkColor: Colors.black,
                  );
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        backgroundColor: Colors.tealAccent,
        heroTag: 'createGroupPageFAB',
        child: const Icon(Icons.check, color: Colors.black),
      ),
    );
  }
}
