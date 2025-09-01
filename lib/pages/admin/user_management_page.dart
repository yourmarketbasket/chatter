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
    print(_filteredUsers[1]);
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
        final name = user['name']?.toLowerCase() ?? '';
        return name.contains(query);
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
                  // print(user);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (user['avatar'] != null && user['avatar'].isNotEmpty)
                          ? NetworkImage(user['avatar'])
                          : null,
                      child: (user['avatar'] == null || user['avatar'].isEmpty)
                          ? Text(user['name'] != null && user['name'].isNotEmpty ? user['name'][0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(user['name'] ?? '', style: GoogleFonts.roboto(color: Colors.white)),
                    subtitle: Text(
                      user['isSuspended'] ?? false ? 'Suspended' : 'Active',
                      style: GoogleFonts.roboto(
                        color: user['isSuspended'] ?? false ? Colors.red : Colors.green,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        user['isSuspended'] ?? false ? Icons.person_off : Icons.person,
                        color: user['isSuspended'] ?? false ? Colors.red : Colors.green,
                      ),
                      onPressed: () {
                        final bool isSuspended = user['isSuspended'] ?? false;
                        Get.dialog(
                          AlertDialog(
                            title: Text(isSuspended ? 'Unsuspend User' : 'Suspend User'),
                            content: Text('Are you sure you want to ${isSuspended ? 'unsuspend' : 'suspend'} ${user['name']}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Get.back();
                                  final result = isSuspended
                                      ? await dataController.unsuspendUser(user['_id'])
                                      : await dataController.suspendUser(user['_id']);
                                  Get.snackbar(
                                    result['success'] ? 'Success' : 'Error',
                                    result['message'],
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  // Refresh the user list
                                  setState(() {
                                    _searchUsers();
                                  });
                                },
                                child: Text(isSuspended ? 'Unsuspend' : 'Suspend'),
                              ),
                            ],
                          ),
                        );
                      },
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
