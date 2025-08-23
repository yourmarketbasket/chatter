import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/helpers/time_helper.dart';
import 'package:chatter/helpers/verification_helper.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:chatter/pages/followers_page.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MainChatsPage extends StatefulWidget {
  const MainChatsPage({super.key});

  @override
  _MainChatsPageState createState() => _MainChatsPageState();
}

class _MainChatsPageState extends State<MainChatsPage> {
  final TextEditingController _searchController = TextEditingController();
  final DataController _dataController = Get.find<DataController>();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.teal,
          accentColor: Colors.tealAccent,
          backgroundColor: Colors.black,
          cardColor: Colors.grey[900],
        ).copyWith(
          onPrimary: Colors.white,
          onSecondary: Colors.grey[300],
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          labelMedium: TextStyle(color: Colors.grey),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      child: Scaffold(
        extendBody: true,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // go to contacts page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowersPage(),
              ),
            );
          },
          backgroundColor: Colors.tealAccent.withOpacity(0.1),
          shape: const CircleBorder(),
          child: const Icon(
            FeatherIcons.userPlus,
            color: Colors.tealAccent,
          ),
        ),
        body: Obx(() {
          if (_dataController.isLoadingChats.value &&
              _dataController.chats.isEmpty) {
            return const Center(child: CircularProgressIndicator());
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
                final otherUserRaw = (chat['participants'] as List<dynamic>).firstWhere((p) => p['_id'] != currentUserId, orElse: () => (chat['participants'] as List<dynamic>).first);
                final otherUser = otherUserRaw is Map<String, dynamic> ? otherUserRaw : _dataController.allUsers.firstWhere((u) => u['_id'] == otherUserRaw, orElse: () => {'name': 'Unknown', 'avatar': ''});
                title = otherUser['name'] ?? 'User';
              }
              return title.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();
          }

          return RefreshIndicator(
            onRefresh: () => _dataController.fetchChats(),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  title: const Text('Chats'),
                  pinned: true,
                  floating: true,
                  snap: true,
                  stretch: true,
                  expandedHeight: 160.0,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    background: Container(
                      color: Colors.black,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[900]!.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                        ],
                      ),
                    ),
                  ),
                ),
                if (allChats.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No conversations match your search.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final chat = allChats[index];
                        final isGroup = chat['type'] == "group";
                        final lastMessageData = chat['lastMessage'];
                        final currentUserId = _dataController.user.value['user']['_id'];

                        String title;
                        String avatarUrl;
                        String avatarLetter;
                        Widget trailingWidget;
                        Map<String, dynamic> otherUser = {};

                        if (isGroup) {
                          title = chat['name'] ?? 'Group Chat';
                          avatarUrl = chat['groupAvatar'] ?? '';
                          avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'G';
                          trailingWidget = const SizedBox.shrink();
                        } else {
                          final List<dynamic> participants = chat['participants'] as List<dynamic>;
                          final otherParticipantRaw = participants.firstWhere(
                            (p) {
                              final pId = (p is Map<String, dynamic>) ? p['_id'] : p;
                              return pId != currentUserId;
                            },
                            orElse: () => participants.first,
                          );

                          Map<String, dynamic> otherUser;
                          if (otherParticipantRaw is Map<String, dynamic>) {
                            otherUser = otherParticipantRaw;
                          } else {
                            // It's a string ID, so we need to look it up in allUsers
                            final otherUserId = otherParticipantRaw as String;
                            otherUser = _dataController.allUsers.firstWhere(
                              (u) => u['_id'] == otherUserId,
                              orElse: () => {'name': 'Unknown', 'avatar': ''},
                            );
                          }

                          title = otherUser['name'] ?? 'User';
                          avatarUrl = otherUser['avatar'] ?? '';
                          avatarLetter = title.isNotEmpty ? title[0].toUpperCase() : 'U';

                          trailingWidget = Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                otherUser['online'] == true ? 'online' : (otherUser['lastSeen'] != null ? formatLastSeen(DateTime.parse(otherUser['lastSeen'])) : 'offline'),
                                style: TextStyle(
                                  color: otherUser['online'] == true ? Colors.tealAccent : Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: otherUser['online'] == true ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          );
                        }

                        String preview = '';
                        if (lastMessageData != null && lastMessageData is Map<String, dynamic>) {
                          final senderId = lastMessageData['senderId'];
                          final senderIdString = senderId is Map ? senderId['_id'] : senderId;
                          String senderName;

                          if (senderIdString == currentUserId) {
                            senderName = 'You';
                          } else {
                            if (isGroup) {
                              final sender = (chat['participants'] as List).firstWhere((p) => p['_id'] == senderIdString, orElse: () => {'name': '...'});
                              senderName = sender['name'];
                            } else {
                              senderName = title;
                            }
                          }

                          if (lastMessageData['deletedForEveryone'] == true) {
                            preview = 'Message deleted';
                          } else if ((lastMessageData['files'] as List?)?.isNotEmpty ?? false) {
                            preview = 'Attachment';
                          } else {
                            preview = lastMessageData['content'] ?? '';
                          }
                          preview = '$senderName: $preview';
                        }

                        IconData statusIcon = Icons.access_time;
                        Color statusColor = Colors.grey[400]!;
                        if (lastMessageData != null && lastMessageData is Map<String, dynamic>) {
                          final readReceipts = lastMessageData['readReceipts'] as List?;
                          if (readReceipts != null && readReceipts.isNotEmpty) {
                            final receipt = readReceipts.firstWhere((r) => r['userId'] != currentUserId, orElse: () => {'status': 'sent'});
                            switch (receipt['status']) {
                              case 'sent':
                                statusIcon = Icons.check;
                                break;
                              case 'delivered':
                                statusIcon = Icons.done_all;
                                break;
                              case 'read':
                                statusIcon = Icons.done_all;
                                statusColor = Colors.tealAccent;
                                break;
                            }
                          }
                        }

                        return GestureDetector(
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Chat'),
                                content: const Text('Are you sure you want to permanently delete this chat and all its messages?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await _dataController.deleteChat(chat['_id']);
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.tealAccent.withOpacity(0.2),
                                  backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                                  child: avatarUrl.isEmpty ? Text(avatarLetter, style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)) : null,
                                ),
                                if (isGroup)
                                  const Positioned(
                                    right: -4,
                                    bottom: -4,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.black,
                                      child: Icon(Icons.group, size: 16, color: Colors.tealAccent),
                                    ),
                                  ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                if (!isGroup)
                                  Icon(Icons.verified,
                                      color: getVerificationBadgeColor(
                                          otherUser['verification']?['entityType'],
                                          otherUser['verification']?['level']),
                                      size: 14),
                              ],
                            ),
                            subtitle: Obx(() {
                              final typingUserId = _dataController.isTyping[chat['_id']];
                              if (typingUserId != null) {
                                final typingUser = _dataController.allUsers.firstWhere((u) => u['_id'] == typingUserId, orElse: () => {'name': 'Someone'});
                                return Text(
                                  '${typingUser['name']} is typing...',
                                  style: const TextStyle(color: Colors.tealAccent, fontStyle: FontStyle.italic, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                              return Text(
                                preview,
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isGroup) trailingWidget,
                                if (lastMessageData != null && lastMessageData is Map<String, dynamic>)
                                  Text(
                                    formatLastSeen(DateTime.parse(lastMessageData['createdAt'] as String).toLocal()),
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                  ),
                                if (lastMessageData != null && lastMessageData is Map<String, dynamic> && lastMessageData['senderId'] == currentUserId)
                                  Icon(statusIcon, size: 16, color: statusColor),
                              ],
                            ),
                            onTap: () {
                              _dataController.currentChat.value = chat;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ChatScreen(),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: allChats.length,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}