import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';

class AdminAuthPage extends StatefulWidget {
  const AdminAuthPage({Key? key}) : super(key: key);

  @override
  _AdminAuthPageState createState() => _AdminAuthPageState();
}

class _AdminAuthPageState extends State<AdminAuthPage> {
  final DataController dataController = Get.find<DataController>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _adminCodeController = TextEditingController();
  bool _isLoginPage = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _usernameError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _adminCodeError;
  String? _generalMessage;
  bool _isSuccess = false;
  bool _isLoading = false;

  void _togglePage() {
    setState(() {
      _isLoginPage = !_isLoginPage;
      _usernameError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _adminCodeError = null;
      _generalMessage = null;
      _isSuccess = false;
      _isLoading = false;
      _usernameController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _adminCodeController.clear();
    });
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _usernameError = null;
      _passwordError = null;
      _generalMessage = null;
      _isSuccess = false;
      _isLoading = true;
    });

    if (username.isEmpty) {
      setState(() {
        _usernameError = 'Username cannot be empty.';
        _isLoading = false;
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Password cannot be empty.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await dataController.loginAdmin(username, password);
      if (response['success']) {
        setState(() {
          _generalMessage = 'Login successful!';
          _isSuccess = true;
        });
        await Future.delayed(const Duration(seconds: 2));
        Get.offAll(() => const HomeFeedScreen());
      } else {
        setState(() {
          _generalMessage = response['message'] ?? 'Login failed.';
          _isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _generalMessage = 'An error occurred.';
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final adminCode = _adminCodeController.text.trim();

    setState(() {
      _usernameError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _adminCodeError = null;
      _generalMessage = null;
      _isSuccess = false;
      _isLoading = true;
    });

    if (username.isEmpty) {
      setState(() {
        _usernameError = 'Username cannot be empty.';
        _isLoading = false;
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Password cannot be empty.';
        _isLoading = false;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match.';
        _isLoading = false;
      });
      return;
    }

    if (adminCode.isEmpty) {
      setState(() {
        _adminCodeError = 'Admin code cannot be empty.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await dataController.registerAdmin(
          username, password, adminCode);
      if (response['success']) {
        setState(() {
          _generalMessage = 'Registration successful! Please login.';
          _isSuccess = true;
          _isLoginPage = true;
        });
      } else {
        setState(() {
          _generalMessage = response['message'] ?? 'Registration failed.';
          _isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _generalMessage = 'An error occurred.';
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
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
        title: Text(
          _isLoginPage ? 'Admin Login' : 'Admin Register',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_generalMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isSuccess ? Colors.green[700]! : Colors.red[700]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _generalMessage!,
                      style: GoogleFonts.roboto(
                        color: _isSuccess ? Colors.green[400] : Colors.red[400],
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (_generalMessage != null) const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  style: GoogleFonts.roboto(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                    hintText: 'e.g., admin_user',
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
                  style: GoogleFonts.roboto(color: Colors.white),
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
                if (!_isLoginPage) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: GoogleFonts.roboto(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                      errorText: _confirmPasswordError,
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
                          _obscureConfirmPassword
                              ? FeatherIcons.eyeOff
                              : FeatherIcons.eye,
                          color: Colors.grey[500],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _adminCodeController,
                    style: GoogleFonts.roboto(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Admin Registration Code',
                      labelStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                      errorText: _adminCodeError,
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
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoginPage ? _login : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            _isLoginPage ? 'Login' : 'Register',
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
                    onPressed: _togglePage,
                    child: Text(
                      _isLoginPage
                          ? 'Don\'t have an admin account? Register'
                          : 'Already have an admin account? Login',
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
