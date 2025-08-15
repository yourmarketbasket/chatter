import 'package:chatter/pages/users_list_page.dart';
import 'package:chatter/widgets/chat/group_chat_list.dart';
import 'package:chatter/widgets/chat/one_to_one_chat_list.dart';
import 'package:chatter/pages/create_group_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class MainChatPage extends StatefulWidget {
  const MainChatPage({Key? key}) : super(key: key);

  @override
  _MainChatPageState createState() => _MainChatPageState();
}

class _MainChatPageState extends State<MainChatPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onFabPressed() {
    if (_tabController.index == 0) {
      // Navigate to a page to start a new one-on-one chat
      Get.to(() => const UsersListPage());
    } else {
      // Navigate to the create group page
      Get.to(() => const CreateGroupPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text(
          'Dig In',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.grey[500],
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          OneToOneChatList(),
          GroupChatList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        child: const Icon(FeatherIcons.plus),
      ),
    );
  }
}
