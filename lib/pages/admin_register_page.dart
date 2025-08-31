import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/admin_login_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';

class AdminRegisterPage extends StatefulWidget {
  const AdminRegisterPage({Key? key}) : super(key: key);

  @override
  _AdminRegisterPageState createState() => _AdminRegisterPageState();
}

class _AdminRegisterPageState extends State<AdminRegisterPage> {
  final DataController dataController = Get.find<DataController>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _adminCodeController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _registerAdmin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final adminCode = _adminCodeController.text.trim();

    if (username.isEmpty || password.isEmpty || adminCode.isEmpty) {
      Get.snackbar('Error', 'All fields are required', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final response = await dataController.registerAdmin(username, password, adminCode);

    if (response['success']) {
      Get.snackbar('Success', 'Admin registered successfully', snackPosition: SnackPosition.BOTTOM);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminLoginPage()),
      );
    } else {
      Get.snackbar('Error', response['message'] ?? 'Admin registration failed', snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('Admin Registration'),
        backgroundColor: const Color(0xFF000000),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Admin Account',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                    filled: true,
                    fillColor: const Color(0xFF252525),
                     border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                    filled: true,
                    fillColor: const Color(0xFF252525),
                     border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? FeatherIcons.eyeOff : FeatherIcons.eye,
                        color: Colors.grey[500],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _adminCodeController,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Admin Registration Code',
                    labelStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                    filled: true,
                    fillColor: const Color(0xFF252525),
                     border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _registerAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Register Admin',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
