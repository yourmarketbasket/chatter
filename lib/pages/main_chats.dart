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
  final FocusNode _searchFocusNode = FocusNode();

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
    // Add listener to detect focus changes
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && mounted) {
        setState(() {
          // Optional: Update state if needed when focus is lost
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          iconTheme: IconThemeData(color: Colors.tealAccent.shade400),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          // Unfocus the search field when tapping anywhere outside
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
          // Ensure the keyboard is dismissed
          FocusScope.of(context).requestFocus(FocusNode());
        },
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: Colors.black,
          floatingActionButton: ExpandableFab(
            childrenOffset: Offset(-5, -5),
            type: ExpandableFabType.up,
            childrenAnimation: ExpandableFabAnimation.none,
            margin: EdgeInsets.only(left: -100),
            distance: 70,
            children: [
              Row(
                children: [
                  const Text("New Group", style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: "newGroup",
                    shape: const CircleBorder(),
                    backgroundColor: Colors.teal.withOpacity(0.5),
                    child: const Icon(Icons.person_add, color: Colors.tealAccent, size: 18),
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
                    shape: const CircleBorder(),
                    heroTag: "newChat",
                    backgroundColor: Colors.teal.withOpacity(0.5),
                    child: const Icon(Icons.person_add, color: Colors.tealAccent, size: 18),
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
                  title: Text('${_selectedChats.length} selected', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.normal)),
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
              dynamic lastMsgA = a['lastMessage'];
              dynamic lastMsgB = b['lastMessage'];

              String? timeAString;
              if (lastMsgA is Map) {
                timeAString = lastMsgA['createdAt'];
              }
              timeAString ??= a['updatedAt'] ?? a['createdAt'];

              String? timeBString;
              if (lastMsgB is Map) {
                timeBString = lastMsgB['createdAt'];
              }
              timeBString ??= b['updatedAt'] ?? b['createdAt'];

              final timeA = timeAString != null ? DateTime.parse(timeAString) : DateTime.fromMillisecondsSinceEpoch(0);
              final timeB = timeBString != null ? DateTime.parse(timeBString) : DateTime.fromMillisecondsSinceEpoch(0);

              return timeB.compareTo(timeA);
            });

            if (_searchQuery.isNotEmpty) {
              allChats = allChats.where((chat) {
                final isGroup = chat['type'] == "group";
                String title;
                if (isGroup) {
                  title = chat['name'] ?? 'Group Chat';
                } else {
                  final currentUserId = _dataController.getUserId() ?? '';
                  final otherParticipant = (chat['participants'] as List<dynamic>?)?.firstWhere(
                    (p) => p is Map && p['_id'] != currentUserId,
                    orElse: () => null,
                  );
                  title = (otherParticipant as Map<String, dynamic>?)?['name'] ?? 'User';
                }
                return title.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0, top: 16.0, bottom: 8.0),
                    child: Text(
                      'Chats',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade800.withOpacity(0.9),
                          Colors.black.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Search chats...',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.shade300,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      onSubmitted: (value) {
                        _searchFocusNode.unfocus();
                      },
                      onTapOutside: (event) {
                        // Unfocus when tapping outside the TextField
                        _searchFocusNode.unfocus();
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 0.0),
                    padding: const EdgeInsets.only(top: 0.0),
                    color: Colors.black,
                    child: RefreshIndicator(
                      onRefresh: () => _dataController.fetchChats(),
                      color: Colors.tealAccent.shade400,
                      child: allChats.isEmpty
                          ? Center(
                              child: Text(
                                'No conversations match your search.',
                                style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: allChats.length,
                              itemBuilder: (context, index) {
                                final chat = allChats[index];
                                final currentUserId = _dataController.getUserId() ?? '';

                                final isGroup = chat['type'] == "group";

                                String title;
                                String avatarUrl;
                                String avatarLetter;
                                bool isUserOnline = false;
                                Map<String, dynamic>? verificationData;
                                Map<String, dynamic>? otherUser;

                                if (isGroup) {
                                  title = chat['name'] ?? 'Group Chat';
                                  avatarUrl = chat['groupAvatar'] ?? '';
                                  avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'G';
                                  verificationData = chat['verification'];
                                } else {
                                  final participants = chat['participants'] as List<dynamic>? ?? [];
                                  otherUser = participants.firstWhere(
                                    (p) => p is Map && p['_id'] != currentUserId,
                                    orElse: () => null,
                                  );

                                  if (otherUser == null) {
                                    return ListTile(title: Text("Loading Chat...", style: GoogleFonts.poppins(color: Colors.grey)));
                                  }

                                  title = otherUser['name'] ?? 'User';
                                  avatarUrl = otherUser['avatar'] ?? '';
                                  avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'U';
                                  isUserOnline = otherUser['online'] ?? false;
                                  verificationData = otherUser['verification'];
                                }

                                final lastMessageData = chat['lastMessage'];
                                String preview = '';
                                String status = 'none';
                                bool isMyMessage = false;
                                String lastMessageTimestamp = '';

                                if (lastMessageData is Map<String, dynamic>) {
                                  final senderId = lastMessageData['senderId'];
                                  final senderIdString = senderId is Map ? senderId['_id'] as String? : senderId as String?;

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
                                    final senderName = (senderId is Map ? senderId['name'] as String? : null) ?? '...';
                                    preview = '$senderName: $preview';
                                  }

                                  status = _getAggregateStatus(lastMessageData);
                                  isMyMessage = senderIdString == currentUserId;
                                  lastMessageTimestamp = lastMessageData['createdAt'] as String? ?? '';
                                }

                                final IconData statusIcon = _getStatusIcon(status);
                                final Color statusColor = _getStatusColor(status);
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
                                          child: avatarUrl.isEmpty
                                              ? Text(avatarLetter, style: GoogleFonts.poppins(color: Colors.tealAccent.shade400, fontWeight: FontWeight.w600, fontSize: 16))
                                              : null,
                                        ),
                                        if (isUserOnline)
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
                                        if (isSelected)
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_circle,
                                              color: Color.fromARGB(255, 143, 143, 143),
                                              size: 24,
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
                                        if (verificationData?['entityType'] != null && verificationData?['level'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Icon(
                                              Icons.verified,
                                              color: getVerificationBadgeColor(verificationData?['entityType'], verificationData?['level']),
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
                                          '${_capitalizeFirstLetter(typingUser['name'])} is typing...',
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
                                                    ? 'seen ${formatLastSeen(DateTime.parse(otherUser['lastSeen']))}'
                                                    : 'offline'),
                                            style: GoogleFonts.poppins(
                                              color: isUserOnline ? Colors.tealAccent.shade400 : Colors.grey.shade500,
                                              fontSize: 9,
                                              fontWeight: isUserOnline ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        if (lastMessageTimestamp.isNotEmpty)
                                          Text(
                                            formatLastSeen(DateTime.parse(lastMessageTimestamp).toLocal()),
                                            style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 9),
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
                              },
                            ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
// hallow