import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _searchController = TextEditingController();
  final DataController _dataController = Get.find<DataController>();

  bool _isLoading = false;
  Map<String, dynamic>? _searchedUser;
  String? _errorMessage;

  void _searchUser() async {
    final String name = _searchController.text.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _searchedUser = null;
      _errorMessage = null;
    });

    final result = await _dataController.searchUserByName(name);

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _searchedUser = result['user'];
      } else {
        _errorMessage = result['message'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search User by Name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchUser,
                ),
              ),
              onSubmitted: (_) => _searchUser(),
            ),
            const SizedBox(height: 20),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                      : _searchedUser != null
                          ? _buildUserCard(_searchedUser!)
                          : const Center(child: Text('Search for a user to begin.')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final verification = user['verification'];
    String verificationStatus = "Not Verified";
    if (verification != null) {
      verificationStatus =
          "Verified: ${verification['entityType']} - ${verification['level']}";
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(user['avatar'] ?? 'https://i.pravatar.cc/150'),
        ),
        title: Text(user['name'] ?? 'No name'),
        subtitle: Text(verificationStatus),
        trailing: ElevatedButton(
          child: const Text('Update'),
          onPressed: () => _showVerificationDialog(user),
        ),
      ),
    );
  }

  void _showVerificationDialog(Map<String, dynamic> user) {
    String? entityType = user['verification']?['entityType'];
    String? level = user['verification']?['level'];
    bool paid = user['verification']?['paid'] ?? false;

    final Map<String, List<String>> levels = {
      'individual': ['basic', 'intermediate', 'premium'],
      'organization': ['basic', 'intermediate', 'premium'],
      'government': ['basic', 'intermediate', 'premium'],
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Verification'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: entityType,
                      hint: const Text('Entity Type'),
                      items: ['individual', 'organization', 'government']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          entityType = value;
                          level = null; // Reset level when entity type changes
                        });
                      },
                    ),
                    if (entityType != null)
                      DropdownButtonFormField<String>(
                        value: level,
                        hint: const Text('Level'),
                        items: levels[entityType]!
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            level = value;
                          });
                        },
                      ),
                    SwitchListTile(
                      title: const Text('Paid'),
                      value: paid,
                      onChanged: (value) {
                        setDialogState(() {
                          paid = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (entityType != null && level != null)
                      ? () async {
                          final result = await _dataController.verifyUser(
                            user['_id'],
                            entityType!,
                            level!,
                            paid,
                          );
                          Navigator.of(context).pop();
                          if (result['success']) {
                            Get.snackbar('Success', result['message']);
                            _searchUser(); // Refresh user data
                          } else {
                            Get.snackbar('Error', result['message']);
                          }
                        }
                      : null,
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
