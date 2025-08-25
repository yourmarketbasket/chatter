import 'package:chatter/pages/chat_screen_page.dart';
import 'package:chatter/pages/profile_page.dart';
import 'package:chatter/helpers/verification_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/Get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatter/widgets/app_drawer.dart';

class AddParticipantsPage extends StatefulWidget {
  final Map<String, dynamic> chat;
  const AddParticipantsPage({Key? key, required this.chat}) : super(key: key);

  @override
  _AddParticipantsPageState createState() => _AddParticipantsPageState();
}

class _AddParticipantsPageState extends State<AddParticipantsPage> {
  final DataController _dataController = Get.find<DataController>();
  final RxMap<String, bool> _isUpdatingFollowStatus = <String, bool>{}.obs;
  final List<Map<String, dynamic>> _selectedUsers = [];
  final TextEditingController _searchController = TextEditingController();
  final RxList<Map<String, dynamic>> _filteredUsers =
      <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_dataController.allUsers.isEmpty) {
          _dataController.fetchAllUsers().then((_) {
            _filterUsers();
          }).catchError((error) {
            if (mounted) {
              Get.snackbar(
                'Error Loading Users',
                'Failed to load users. Please try again later.',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.red[700],
                colorText: Colors.white,
              );
            }
          });
        } else {
          _filterUsers();
        }
      }
    });

    _searchController.addListener(() {
      _filterUsers();
    });
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    final participantIds = (widget.chat['participants'] as List)
        .map((p) => p['_id'] as String)
        .toSet();

    var availableUsers = _dataController.allUsers
        .where((user) => !participantIds.contains(user['_id']))
        .toList();

    if (query.isEmpty) {
      _filteredUsers.assignAll(availableUsers);
    } else {
      _filteredUsers.assignAll(availableUsers.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final username = (user['username'] ?? '').toLowerCase();
        return name.contains(query) || username.contains(query);
      }).toList());
    }
  }

  Future<void> _toggleFollow(String targetUserId, bool currentFollowStatus) async {
    if (_isUpdatingFollowStatus[targetUserId] == true) return;

    _isUpdatingFollowStatus[targetUserId] = true;

    try {
      final String currentUserId = _dataController.user.value['user']['_id'];
      Map<String, dynamic> result;
      if (currentFollowStatus) {
        result = await _dataController.unfollowUser(targetUserId);
      } else {
        result = await _dataController.followUser(targetUserId);
      }

      if (mounted && result['success'] == true) {
         int userIndex = _dataController.allUsers.indexWhere((u) => u['_id'] == targetUserId);
         if (userIndex != -1) {
           var userToUpdate = Map<String, dynamic>.from(_dataController.allUsers[userIndex]);
           userToUpdate['isFollowingCurrentUser'] = !currentFollowStatus;
           _dataController.allUsers[userIndex] = userToUpdate;
           _filterUsers(); // Update filtered list to reflect follow status
         }
      } else if (mounted) {
        Get.snackbar(
          'Error',
          result['message'] ?? 'Failed to update follow status.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          'An unexpected error occurred.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) {
       _isUpdatingFollowStatus[targetUserId] = false;
      }
    }
  }

  void _addMembers() async {
    final chatId = widget.chat['_id'];
    for (var user in _selectedUsers) {
      await _dataController.addMember(chatId, user['_id']);
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Add Participants',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.roboto(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_filteredUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FeatherIcons.users,
                          size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'No users to add.'
                            : 'No users match your search.',
                        style: GoogleFonts.roboto(
                            color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredUsers.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey[850],
                  height: 1,
                  indent: 72,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  final String userId = user['_id'] ?? '';
                  final String avatarUrl = user['avatar'] ?? '';
                  final String name = user['name'] ?? 'User';
                  final String username = user['username'] ?? 'username';
                  final String avatarInitial = name.isNotEmpty
                      ? name[0].toUpperCase()
                      : (username.isNotEmpty
                          ? username[0].toUpperCase()
                          : '?');

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 3.0),
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
                    title: Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        Icon(Icons.verified,
                            color: getVerificationBadgeColor(
                                user['verification']?['entityType'],
                                user['verification']?['level']),
                            size: 12)
                      ],
                    ),
                    subtitle: Text(
                      '@$username',
                      style: GoogleFonts.roboto(
                          color: Colors.grey[500], fontSize: 12),
                    ),
                    onTap: () {
                      setState(() {
                        if (_selectedUsers.any((u) => u['_id'] == userId)) {
                          _selectedUsers
                              .removeWhere((u) => u['_id'] == userId);
                        } else {
                          _selectedUsers.add(user);
                        }
                      });
                    },
                    selected: _selectedUsers.any((u) => u['_id'] == userId),
                    selectedTileColor: Colors.teal.withOpacity(0.2),
                  );
                },
                padding: const EdgeInsets.only(bottom: 16),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: _selectedUsers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _addMembers,
              label: const Text('Add to Group'),
              icon: const Icon(Icons.check),
              backgroundColor: Colors.tealAccent,
            )
          : null,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
