import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/register.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  DataController dataController = Get.put(DataController());
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _usernameError;
  String? _passwordError;
  String? _generalMessage;
  bool _isSuccess = false;

  // In-memory user store (for demo purposes)
  static final Map<String, String> _users = {};

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Reset errors and success state
    setState(() {
      _usernameError = null;
      _passwordError = null;
      _generalMessage = null;
      _isSuccess = false;
    });

    // Validation
    List<String> errors = [];
    if (username.isEmpty) {
      _usernameError = 'Username cannot be empty.';
      errors.add(_usernameError!);
    } else if (username.length < 3) {
      _usernameError = 'Username must be at least 3 characters.';
      errors.add(_usernameError!);
    }

    if (password.isEmpty) {
      _passwordError = 'Password cannot be empty.';
      errors.add(_passwordError!);
    } else if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters.';
      errors.add(_passwordError!);
    }

    if (errors.isNotEmpty) {
      setState(() {
        _generalMessage = errors.length > 1 ? 'Fix the errors to proceed.' : errors.first;
        _isSuccess = false;
      });
      return;
    }

    // Send to server via the dataController
    var response = await dataController.loginUser({
      'username': username,
      'password': password,
    });

    if (response['success']) {
      setState(() {
        _generalMessage = response['message'] ?? 'Login successful!';
        _isSuccess = true;
      });
      await Future.delayed(const Duration(seconds: 2)); // Show success message briefly
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeFeedScreen()),
      );
    } else {
      setState(() {
        _generalMessage = response['message'] ?? 'Login failed. Please try again.';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FeatherIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                  'Chatter',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome to Chatter, log in here',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                if (_generalMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isSuccess ? Colors.green[700]! : Colors.red[700]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSuccess ? FeatherIcons.checkCircle : FeatherIcons.alertCircle,
                          color: _isSuccess ? Colors.green[400] : Colors.red[400],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _generalMessage!,
                            style: GoogleFonts.roboto(
                              color: _isSuccess ? Colors.green[400] : Colors.red[400],
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_generalMessage != null) const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Username (Alias)',
                    labelStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                    hintText: 'e.g., ShengPlayer',
                    hintStyle: GoogleFonts.roboto(color: Colors.grey[700]),
                    errorText: _usernameError,
                    errorStyle: GoogleFonts.roboto(color: Colors.red[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[700]!),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[700]!),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF252525),
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
                    errorText: _passwordError,
                    errorStyle: GoogleFonts.roboto(color: Colors.red[400], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[700]!),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red[700]!),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF252525),
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Log In',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    child: Text(
                      'No account? Register',
                      style: GoogleFonts.roboto(
                        color: Colors.tealAccent,
                        fontSize: 14,
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