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

class _MainChatPageState extends State<MainChatPage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  static const List<Widget> _pages = <Widget>[
    OneToOneChatList(),
    GroupChatList(),
  ];

  static const List<String> _appBarTitles = <String>[
    'Chats',
    'Groups',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onFabPressed() {
    if (_selectedIndex == 0) {
      Get.to(() => const UsersListPage());
    } else {
      Get.to(() => const CreateGroupPage());
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearchExpanded
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search ${_appBarTitles[_selectedIndex].toLowerCase()}...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                ),
              )
            : Text(
                _appBarTitles[_selectedIndex],
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.tealAccent,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchExpanded ? FeatherIcons.x : FeatherIcons.search,
              color: Colors.tealAccent,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10.0,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: _pages,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        heroTag: 'mainChatPageFAB',
        child: const Icon(FeatherIcons.plus),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12.0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.tealAccent,
          unselectedItemColor: Colors.grey[500],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          elevation: 0,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          iconSize: 25.2,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(FeatherIcons.messageSquare),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(FeatherIcons.users),
              ),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}