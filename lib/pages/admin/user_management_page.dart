import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final DataController dataController = Get.find<DataController>();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = dataController.allUsers;
    _searchController.addListener(_searchUsers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_searchUsers);
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = dataController.allUsers.where((user) {
        final username = user['username']?.toLowerCase() ?? '';
        return username.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Users',
                labelStyle: GoogleFonts.roboto(color: Colors.white),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: GoogleFonts.roboto(color: Colors.white),
            ),
          ),
          Expanded(
            child: Obx(
              () => ListView.builder(
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user['avatar'] ?? ''),
                    ),
                    title: Text(user['username'] ?? '', style: GoogleFonts.roboto(color: Colors.white)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user['isSuspended'] ?? false ? 'Suspended' : 'Active',
                          style: GoogleFonts.roboto(
                            color: user['isSuspended'] ?? false ? Colors.red : Colors.green,
                          ),
                        ),
                        Switch(
                          value: user['isSuspended'] ?? false,
                          onChanged: (value) {
                            Get.dialog(
                              AlertDialog(
                                title: Text(value ? 'Suspend User' : 'Unsuspend User'),
                                content: Text('Are you sure you want to ${value ? 'suspend' : 'unsuspend'} ${user['username']}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Get.back(),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Get.back();
                                      final result = value
                                          ? await dataController.suspendUser(user['_id'])
                                          : await dataController.unsuspendUser(user['_id']);
                                      Get.snackbar(
                                        result['success'] ? 'Success' : 'Error',
                                        result['message'],
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                    },
                                    child: Text(value ? 'Suspend' : 'Unsuspend'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
