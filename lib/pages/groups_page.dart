import 'package:chatter/pages/group_conversation_page.dart';
import 'package:flutter/material.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _dummyGroups = [
    {
      'name': 'Family Group',
      'initials': 'F',
      'participants': ['Alice', 'Bob', 'You'],
      'lastMessage': 'Let\'s plan the trip!',
      'sender': 'Alice',
      'time': '11:45 AM',
      'status': 'read',
      'edited': false,
      'deleted': false,
      'attachment': null,
    },
    {
      'name': 'Work Team',
      'initials': 'W',
      'participants': ['Charlie', 'David', 'You'],
      'lastMessage': 'Meeting notes',
      'sender': 'You',
      'time': 'Yesterday',
      'status': 'delivered',
      'edited': false,
      'deleted': false,
      'attachment': 'https://example.com/document.pdf',
    },
    {
      'name': 'Friends Circle',
      'initials': 'FC',
      'participants': ['Eve', 'Frank', 'You'],
      'lastMessage': 'Message deleted',
      'sender': 'Eve',
      'time': '3 days ago',
      'status': 'sent',
      'edited': true,
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
        itemCount: _dummyGroups.length,
        itemBuilder: (context, index) {
          final group = _dummyGroups[index];
          String preview = group['deleted']
              ? 'Message deleted'
              : group['attachment'] != null
                  ? 'Attachment'
                  : group['lastMessage'];
          if (group['edited']) {
            preview += ' (edited)';
          }
          preview = '${group['sender']}: $preview';

          IconData statusIcon;
          Color statusColor;
          switch (group['status']) {
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
            leading: CircleAvatar(
              backgroundColor: Colors.tealAccent,
              child: Text(
                group['initials'],
                style: const TextStyle(color: Colors.black),
              ),
            ),
            title: Text(
              group['name'],
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
                  group['time'],
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
                  builder: (context) => GroupChatScreen(groupChat: _dummyGroups[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}