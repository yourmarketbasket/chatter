import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:chatter/helpers/verification_helper.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:chatter/pages/followers_page.dart';
import 'package:chatter/pages/users_list_page.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
// added som enew stuff

class MainChatsPage extends StatefulWidget {
  const MainChatsPage({super.key});

  @override
  _MainChatsPageState createState() => _MainChatsPageState();
}

class _MainChatsPageState extends State<MainChatsPage> {
  final TextEditingController _searchController = TextEditingController();
  final DataController _dataController = Get.find<DataController>();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedChats = {};

  void _toggleSelection(String chatId) {
    setState(() {
      if (_selectedChats.contains(chatId)) {
        _selectedChats.remove(chatId);
        if (_selectedChats.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedChats.add(chatId);
        _isSelectionMode = true;
      }
    });
  }

  void _deleteSelectedChats() {
    _dataController.deleteMultipleChats(_selectedChats.toList());
    setState(() {
      _selectedChats.clear();
      _isSelectionMode = false;
    });
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _dataController.isMainChatsActive.value = true;
    _dataController.fetchChats();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dataController.isMainChatsActive.value = false;
    super.dispose();
  }

  String _getAggregateStatus(Map<String, dynamic> message) {
    if (message['status'] == 'sending') return 'sending';
    if (message['status_for_failed_only'] == 'failed') return 'failed';
    final receipts = (message['readReceipts'] as List?)?.cast<Map<String, dynamic>>();
    if (receipts == null || receipts.isEmpty) return 'sent';
    if (receipts.every((r) => r['status'] == 'read')) return 'read';
    if (receipts.any((r) => r['status'] == 'delivered' || r['status'] == 'read')) return 'delivered';
    return 'sent';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sending':
        return Icons.access_time;
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.access_time;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'read':
        return Colors.tealAccent.shade400;
      case 'failed':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
          accentColor: Colors.tealAccent.shade400,
          backgroundColor: Colors.black,
          cardColor: Colors.grey.shade900,
        ).copyWith(
          onPrimary: Colors.white,
          onSecondary: Colors.grey.shade300,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
        ).copyWith(
          bodyMedium: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          labelMedium: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
          titleLarge: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
          iconTheme: IconThemeData(color: Colors.tealAccent.shade400),
        ),
      ),
      child: Scaffold(
        extendBody: true,
        floatingActionButton: ExpandableFab(
          type: ExpandableFabType.up,
          distance: 70,
          children: [
            Row(
              children: [
                const Text("New Group", style: TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  backgroundColor: Colors.tealAccent.shade400.withOpacity(0.2),
                  child: const Icon(Icons.group_add, color: Colors.tealAccent),
                  onPressed: () {
                    Get.to(() => const UsersListPage(isGroupCreationMode: true));
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text("New Chat", style: TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  backgroundColor: Colors.tealAccent.shade400.withOpacity(0.2),
                  child: const Icon(Icons.person_add, color: Colors.tealAccent),
                  onPressed: () {
                    Get.to(() => const FollowersPage());
                  },
                ),
              ],
            ),
          ],
        ),
        appBar: _isSelectionMode
            ? AppBar(
                title: Text('${_selectedChats.length} selected'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedChats.clear();
                    });
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _deleteSelectedChats,
                  ),
                ],
              )
            : null,
        body: Obx(() {
          if (_dataController.isLoadingChats.value && _dataController.chats.isEmpty) {
            return Center(child: CircularProgressIndicator(color: Colors.tealAccent.shade400));
          }

          var allChats = _dataController.chats.values.toList();
          allChats.sort((a, b) {
            final lastMsgA = a['lastMessage'];
            final lastMsgB = b['lastMessage'];
            final timeA = lastMsgA != null ? DateTime.parse(lastMsgA['createdAt']) : DateTime.parse(a['updatedAt']);
            final timeB = lastMsgB != null ? DateTime.parse(lastMsgB['createdAt']) : DateTime.parse(b['updatedAt']);
            return timeB.compareTo(timeA);
          });

          if (_searchQuery.isNotEmpty) {
            allChats = allChats.where((chat) {
              final isGroup = chat['type'] == "group";
              String title;
              if (isGroup) {
                title = chat['name'] ?? 'Group Chat';
              } else {
                final currentUserId = _dataController.user.value['user']['_id'];
                final otherUserRaw = (chat['participants'] as List<dynamic>).firstWhere(
                  (p) => p['_id'] != currentUserId,
                  orElse: () => (chat['participants'] as List<dynamic>).first,
                );
                final otherUser = otherUserRaw is Map<String, dynamic>
                    ? otherUserRaw
                    : _dataController.allUsers.firstWhere(
                        (u) => u['_id'] == otherUserRaw,
                        orElse: () => {'name': 'Unknown', 'avatar': ''},
                      );
                title = otherUser['name'] ?? 'User';
              }
              return title.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();
          }

          return ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
            child: Container(
              color: Colors.black,
              child: RefreshIndicator(
                onRefresh: () => _dataController.fetchChats(),
                color: Colors.tealAccent.shade400,
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverAppBar(
                      pinned: true,
                      floating: true,
                      snap: true,
                      stretch: true,
                      expandedHeight: 120.0,
                      automaticallyImplyLeading: true,
                      flexibleSpace: FlexibleSpaceBar(
                        stretchModes: const [StretchMode.blurBackground],
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black, Colors.grey.shade900.withOpacity(0.8)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: SafeArea(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 56.0, top: 16.0, bottom: 8.0),
                                  child: Text(
                                    'Chats',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search chats...',
                                      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
                                      filled: true,
                                      fillColor: Colors.grey.shade900.withOpacity(0.4),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        borderSide: BorderSide.none,
                                      ),
                                      prefixIcon: Icon(Icons.search, color: Colors.tealAccent.shade400, size: 20),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                    ),
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (allChats.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No conversations match your search.',
                            style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final chat = allChats[index];
                            final currentUserId = _dataController.user.value['user']['_id'];

                            // Wrap the entire ListTile generation in an Obx
                            return Obx(() {
                              
                              _dataController.chats.length;

                              final isGroup = chat['type'] == "group";

                              // --- All data lookup happens inside Obx ---
                              String title;
                              String avatarUrl;
                              String avatarLetter;
                              bool isUserOnline = false;
                              Map<String, dynamic> verificationData;
                              Map<String, dynamic>? otherUser; // Can be null for groups

                              if (isGroup) {
                                title = chat['name'] ?? 'Group Chat';
                                avatarUrl = chat['groupAvatar'] ?? '';
                                avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'G';
                                verificationData = chat['verification'] ?? {'entityType': null, 'level': null};
                              } else {
                                final otherParticipantRaw = (chat['participants'] as List<dynamic>).firstWhere(
                                  (p) => (p is Map<String, dynamic> ? p['_id'] : p) != currentUserId,
                                  orElse: () => null,
                                );

                                if (otherParticipantRaw == null) {
                                  return ListTile(title: Text("Invalid Chat", style: GoogleFonts.poppins(color: Colors.red)));
                                }

                                final otherUserId = otherParticipantRaw is Map<String, dynamic> ? otherParticipantRaw['_id'] : otherParticipantRaw;

                                otherUser = _dataController.allUsers.firstWhere(
                                    (u) => u['_id'] == otherUserId,
                                    orElse: () => {
                                      '_id': otherUserId,
                                      'name': otherParticipantRaw is Map ? otherParticipantRaw['name'] : 'User',
                                      'avatar': otherParticipantRaw is Map ? otherParticipantRaw['avatar'] : '',
                                      'online': false,
                                      'lastSeen': null,
                                      'verification': null,
                                    },
                                );

                                title = otherUser['name'] ?? 'User';
                                avatarUrl = otherUser['avatar'] ?? '';
                                avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'U';
                                isUserOnline = otherUser['online'] ?? false;
                                verificationData = otherUser['verification'] ?? {'entityType': null, 'level': null};
                              }

                              final lastMessageData = chat['lastMessage'];
                              String preview = '';
                              if (lastMessageData != null && lastMessageData is Map<String, dynamic>) {
                                final senderId = lastMessageData['senderId'];
                                final senderIdString = senderId is Map ? senderId['_id'] : senderId;

                                if (lastMessageData['deletedForEveryone'] == true) {
                                  preview = 'Message deleted';
                                } else if ((lastMessageData['files'] as List?)?.isNotEmpty ?? false) {
                                  preview = 'Attachment';
                                } else {
                                  preview = lastMessageData['content'] ?? '';
                                }

                                if (senderIdString == currentUserId) {
                                  preview = 'You: $preview';
                                } else if (isGroup) {
                                  final senderName = (chat['participants'] as List)
                                          .firstWhere((p) => p['_id'] == senderIdString, orElse: () => {'name': '...'})['name'];
                                  preview = '$senderName: $preview';
                                }
                              }

                              final String status = lastMessageData != null ? _getAggregateStatus(lastMessageData) : 'none';
                              final IconData statusIcon = _getStatusIcon(status);
                              final Color statusColor = _getStatusColor(status);
                              final bool isMyMessage = lastMessageData != null && (lastMessageData['senderId'] is Map ? lastMessageData['senderId']['_id'] : lastMessageData['senderId']) == currentUserId;
                              final int unreadCount = chat['unreadCount'] as int? ?? 0;
                              final bool isSelected = _selectedChats.contains(chat['_id']);

                              return GestureDetector(
                                onLongPress: () {
                                  _toggleSelection(chat['_id']);
                                },
                                child: ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.teal.withOpacity(0.2),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.tealAccent.shade400.withOpacity(0.2),
                                        backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                                        child: isSelected
                                            ? const Icon(Icons.check, color: Colors.white)
                                            : (avatarUrl.isEmpty
                                                ? Text(avatarLetter, style: GoogleFonts.poppins(color: Colors.tealAccent.shade400, fontWeight: FontWeight.w600, fontSize: 16))
                                                : null),
                                      ),
                                      if (isGroup)
                                        Positioned(
                                          right: -4,
                                          bottom: -4,
                                          child: CircleAvatar(
                                            radius: 10,
                                            backgroundColor: Colors.black,
                                            child: Icon(Icons.group, size: 14, color: Colors.tealAccent.shade400),
                                          ),
                                        ),
                                      if (!isGroup && isUserOnline)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.black, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        _capitalizeFirstLetter(title),
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                                      ),
                                      if (verificationData['entityType'] != null && verificationData['level'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4.0),
                                          child: Icon(
                                            Icons.verified,
                                            color: getVerificationBadgeColor(verificationData['entityType'], verificationData['level']),
                                            size: 20,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Obx(() {
                                    final typingUserId = _dataController.isTyping[chat['_id']];
                                    if (typingUserId != null) {
                                      final typingUser = _dataController.allUsers.firstWhere(
                                        (u) => u['_id'] == typingUserId,
                                        orElse: () => {'name': 'Someone'},
                                      );
                                      return Text(
                                        '${typingUser['name']} is typing...',
                                        style: GoogleFonts.poppins(
                                          color: Colors.teal.shade400,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }
                                    return Text(
                                      preview,
                                      style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!isGroup && otherUser != null)
                                        Text(
                                          isUserOnline
                                              ? 'online'
                                              : (otherUser['lastSeen'] != null
                                                  ? 'last seen ${formatLastSeen(DateTime.parse(otherUser['lastSeen']))}'
                                                  : 'offline'),
                                          style: GoogleFonts.poppins(
                                            color: isUserOnline ? Colors.tealAccent.shade400 : Colors.grey.shade500,
                                            fontSize: 11,
                                            fontWeight: isUserOnline ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      if (lastMessageData != null)
                                        Text(
                                          formatLastSeen(DateTime.parse(lastMessageData['createdAt'] as String).toLocal()),
                                          style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 11),
                                        ),
                                      const SizedBox(height: 4),
                                      if (unreadCount > 0)
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Colors.teal,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      else if (isMyMessage && status != 'none')
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Icon(statusIcon, size: 14, color: statusColor),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleSelection(chat['_id']);
                                    } else {
                                      _dataController.currentChat.value = chat;
                                      if (unreadCount > 0) {
                                        _dataController.chats[chat['_id']]!['unreadCount'] = 0;
                                        _dataController.chats.refresh();
                                      }
                                      Get.to(() => const ChatScreen());
                                    }
                                  },
                                ),
                              );
                            });
                          },
                          childCount: allChats.length,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}