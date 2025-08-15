import 'package:chatter/pages/chat_screen_page.dart';
import 'package:flutter/material.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _dummyChats = [
    {
      'name': 'Alice',
      'initials': 'A',
      'online': true,
      'lastMessage': 'Hey, how are you?',
      'sender': 'other',
      'time': '10:30 AM',
      'status': 'read',
      'edited': false,
      'deleted': false,
      'attachment': null,
    },
    {
      'name': 'Bob',
      'initials': 'B',
      'online': false,
      'lastMessage': 'Check this out!',
      'sender': 'you',
      'time': 'Yesterday',
      'status': 'delivered',
      'edited': true,
      'deleted': false,
      'attachment': 'https://example.com/image.jpg',
    },
    {
      'name': 'Charlie',
      'initials': 'C',
      'online': true,
      'lastMessage': 'Message deleted',
      'sender': 'other',
      'time': '2 days ago',
      'status': 'sent',
      'edited': false,
      'deleted': true,
      'attachment': null,
    },
    // Add more dummy data as needed
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListView.builder(
        itemCount: _dummyChats.length,
        itemBuilder: (context, index) {
          final chat = _dummyChats[index];
          String preview = chat['deleted']
              ? 'Message deleted'
              : chat['attachment'] != null
                  ? 'Attachment'
                  : chat['lastMessage'];
          if (chat['edited']) {
            preview += ' (edited)';
          }
          if (chat['sender'] == 'you') {
            preview = 'You: $preview';
          }

          IconData statusIcon;
          Color statusColor;
          switch (chat['status']) {
            case 'sent':
              statusIcon = Icons.check;
              statusColor = Colors.grey[400]!;
              break;
            case 'delivered':
              statusIcon = Icons.done_all;
              statusColor = Colors.grey[400]!;
              break;
            case 'read':
              statusIcon = Icons.done_all;
              statusColor = Colors.tealAccent;
              break;
            default:
              statusIcon = Icons.access_time;
              statusColor = Colors.grey[400]!;
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.tealAccent,
                  child: Text(
                    chat['initials'],
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                if (chat['online'])
                  Positioned(
                    bottom: 0,
                    right: 0,
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
            title: Text(
              chat['name'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              preview,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat['time'],
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                Icon(
                  statusIcon,
                  size: 16,
                  color: statusColor,
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(chat: _dummyChats[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}