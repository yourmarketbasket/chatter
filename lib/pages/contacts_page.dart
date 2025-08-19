import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> with SingleTickerProviderStateMixin {
  final DataController _dataController = Get.find<DataController>();
  final Set<String> _selectedUserIds = {};
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchQuery = ''.obs;
  bool _isCreatingGroup = false;
  bool _isSearchExpanded = false; // Added missing declaration
  late AnimationController _animationController;
  late Animation<Alignment> _searchAlignment;
  late Animation<double> _searchWidth;

  @override
  void initState() {
    super.initState();
    final currentUserId = _dataController.user.value['user']['_id'];
    _searchController.addListener(() {
      _searchQuery.value = _searchController.text.toLowerCase();
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _searchAlignment = Tween<Alignment>(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _searchWidth = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onUserTap(Map<String, dynamic> user) {
    if (_isCreatingGroup) {
      setState(() {
        if (_selectedUserIds.contains(user['_id'])) {
          _selectedUserIds.remove(user['_id']);
        } else {
          _selectedUserIds.add(user['_id']);
        }
      });
    } else {
      // Start DM chat
      final chatId = const Uuid().v4();
      // Get.to(() => ChatScreenPage(
      //       chatId: chatId,
      //       participants: [user['_id'], _dataController.user.value['user']['_id']],
      //       isGroupChat: false,
      //       chatName: user['name'],
      //     ));
    }
  }

  void _createGroup() {
    if (_selectedUserIds.isNotEmpty) {
      final chatId = const Uuid().v4();
      final participants = [
        ..._selectedUserIds,
        _dataController.user.value['user']['_id']
      ];
      
      Get.dialog(
        AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Group Name', style: GoogleFonts.poppins(color: Colors.white)),
          content: TextField(
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter group name',
              hintStyle: GoogleFonts.poppins(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.tealAccent),
              ),
            ),
            onSubmitted: (groupName) {
              if (groupName.trim().isNotEmpty) {
                // Get.to(() => ChatScreenPage(
                //       chatId: chatId,
                //       participants: participants,
                //       isGroupChat: true,
                //       chatName: groupName,
                //     ));
                setState(() {
                  _isCreatingGroup = false;
                  _selectedUserIds.clear();
                });
                Get.back();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.tealAccent)),
            ),
          ],
        ),
      );
    } else {
      Get.snackbar('Error', 'Please select at least one contact',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _inviteContact() {
    final inviteController = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Invite Contact', style: GoogleFonts.poppins(color: Colors.white)),
        content: TextField(
          controller: inviteController,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter email or username',
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.tealAccent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.tealAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.tealAccent)),
          ),
          TextButton(
            onPressed: () {
              final inviteInput = inviteController.text.trim();
              if (inviteInput.isNotEmpty) {
                Get.snackbar('Invite Sent', 'Invitation sent to $inviteInput',
                    backgroundColor: Colors.teal, colorText: Colors.white);
                Get.back();
              } else {
                Get.snackbar('Error', 'Please enter an email or username',
                    backgroundColor: Colors.red, colorText: Colors.white);
              }
            },
            child: Text('Invite', style: GoogleFonts.poppins(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          if (_dataController.isLoadingFollowing.value) {
            return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
          }
          if (_dataController.following.isEmpty) {
            return Center(
              child: Text(
                'You are not following anyone yet.',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.black,
                floating: true,
                pinned: true,
                title: Text(
                  'Contacts',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isSearchExpanded
                          ? const Icon(Icons.close, key: ValueKey('close'), color: Colors.tealAccent)
                          : const Icon(Icons.search, key: ValueKey('search'), color: Colors.tealAccent),
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                        if (_isSearchExpanded) {
                          _animationController.forward();
                        } else {
                          _animationController.reverse();
                          _searchController.clear();
                          _searchQuery.value = '';
                        }
                      });
                    },
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60.0),
                  child: Align(
                    alignment: _searchAlignment.value,
                    child: SizeTransition(
                      sizeFactor: _searchWidth,
                      axis: Axis.horizontal,
                      axisAlignment: 1.0,
                      child: Container(
                        height: 60.0,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search contacts...',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.tealAccent.withOpacity(0.3))),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCreatingGroup = true;
                          });
                        },
                        child: Row(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isCreatingGroup = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(11.2), // Reduced by 30% from 16.0
                                minimumSize: const Size(33.6, 33.6), // Reduced by 30% from 48
                              ),
                              child: const Icon(Icons.group_add_outlined, size: 16.8), // Reduced by 30% from 24
                            ),
                            const SizedBox(width: 12.0),
                            Text(
                              'Create Group',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      GestureDetector(
                        onTap: _inviteContact,
                        child: Row(
                          children: [
                            ElevatedButton(
                              onPressed: _inviteContact,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(11.2), // Reduced by 30% from 16.0
                                minimumSize: const Size(33.6, 33.6), // Reduced by 30% from 48
                              ),
                              child: const Icon(Icons.person_add_alt_1_outlined, size: 16.8), // Reduced by 30% from 24
                            ),
                            const SizedBox(width: 12.0),
                            Text(
                              'Invite Contact',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Obx(() {
                final filteredList = _searchQuery.value.isEmpty
                    ? _dataController.contacts.value
                    : _dataController.contacts.value.where((user) {
                        final name = user['name']?.toLowerCase() ?? '';
                        return name.contains(_searchQuery.value);
                      }).toList();

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = filteredList[index];
                      final isSelected = _selectedUserIds.contains(user['_id']);
                      final String avatarUrl = user['avatar'] ?? '';
                      final bool isVerified = user['isVerified'] ?? false;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.tealAccent.withOpacity(0.2),
                          backgroundImage:
                              (avatarUrl.isNotEmpty) ? CachedNetworkImageProvider(avatarUrl) : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  user['name']?[0] ?? '?',
                                  style: GoogleFonts.poppins(
                                      color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Text(
                              user['name'] ?? 'No Name',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            if (isVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Icon(Icons.verified, color: Colors.amber, size: 16),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${user['followersCount'] ?? 0} Followers, ${user['followingCount'] ?? 0} Following',
                          style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                        ),
                        onTap: () => _onUserTap(user),
                        trailing: _isCreatingGroup
                            ? InkWell(
                                onTap: () => _onUserTap(user),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? Colors.tealAccent : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? Colors.tealAccent : Colors.grey,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                              )
                            : null,
                      );
                    },
                    childCount: filteredList.length,
                  ),
                );
              }),
            ],
          );
        }),
      ),
      floatingActionButton: _isCreatingGroup
          ? FloatingActionButton(
              onPressed: _createGroup,
              backgroundColor: Colors.tealAccent,
              child: const Icon(Icons.check, color: Colors.black),
            )
          : null,
    );
  }
}