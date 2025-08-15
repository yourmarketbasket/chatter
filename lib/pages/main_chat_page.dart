import 'package:chatter/widgets/chat/group_chat_list.dart';
import 'package:chatter/widgets/chat/one_to_one_chat_list.dart';
import 'package:chatter/pages/create_group_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';

class MainChatPage extends StatefulWidget {
  const MainChatPage({Key? key}) : super(key: key);

  @override
  _MainChatPageState createState() => _MainChatPageState();
}

class _MainChatPageState extends State<MainChatPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    OneToOneChatList(),
    GroupChatList(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: _pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.to(() => const CreateGroupPage());
        },
        child: const Icon(FeatherIcons.plus),
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: const Color(0xFF121212),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: Icon(FeatherIcons.user, color: _selectedIndex == 0 ? Colors.tealAccent : Colors.grey[500]),
              onPressed: () => _onItemTapped(0),
              tooltip: 'Chats',
            ),
            IconButton(
              icon: Icon(FeatherIcons.users, color: _selectedIndex == 1 ? Colors.tealAccent : Colors.grey[500]),
              onPressed: () => _onItemTapped(1),
              tooltip: 'Groups',
            ),
          ],
        ),
      ),
    );
  }
}
