import 'package:chatter/pages/admin/post_management_page.dart';
import 'package:chatter/pages/admin/user_management_page.dart';
import 'package:chatter/pages/admin/update_verification_page.dart';
import 'package:chatter/pages/admin/nudge_page.dart'; // Import the new page
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminActionsPage extends StatefulWidget {
  const AdminActionsPage({Key? key}) : super(key: key);

  @override
  _AdminActionsPageState createState() => _AdminActionsPageState();
}

class _AdminActionsPageState extends State<AdminActionsPage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    const UserManagementPage(),
    const PostManagementPage(),
    const UpdateVerificationPage(),
    const NudgePage(), // Add the new page
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Admin Actions',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: 'Posts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'Verify',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign), // Add icon for the new page
            label: 'Nudge', // Add label for the new page
          ),
        ],
        backgroundColor: Colors.black,
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
