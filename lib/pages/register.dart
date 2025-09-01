import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/admin_page.dart';
import 'package:chatter/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/instance_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  DataController dataController = Get.put(DataController());
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  String? _usernameError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _generalMessage;
  bool _isSuccess = false;
  bool _isLoading = false; // Added for progress indicator
  int _tapCount = 0;

  // Password strength criteria
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _isPasswordFocused = false;


  // In-memory user store (for demo purposes)
  static final Map<String, String> _users = {};

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordCriteria);
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
        // Trigger validation display when field is focused and not empty, or when it loses focus
        if (_isPasswordFocused && _passwordController.text.isNotEmpty) {
          _updatePasswordCriteria(); // Update criteria states
        } else if (!_isPasswordFocused && _passwordController.text.isNotEmpty) {
          // If focus is lost and field is not empty, ensure errors are shown if criteria not met
           _updatePasswordCriteria();
        } else if (_passwordController.text.isEmpty){
          _passwordError = null; // Clear error if field is empty
        }
      });
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordCriteria);
    _passwordFocusNode.removeListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordCriteria() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      _hasNumber = RegExp(r'\d').hasMatch(password);
      _hasSymbol = RegExp(r'[!@#$%^&*()_+\-=\[\]{};'':"\\|,.<>\/?~`]').hasMatch(password);

      // Validate password field immediately for error message
      if (password.isNotEmpty && _isPasswordFocused) {
        if (!(_hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSymbol)) {
          _passwordError = 'Password does not meet all criteria.';
        } else {
          _passwordError = null;
        }
      } else if (password.isEmpty && _isPasswordFocused) {
        _passwordError = 'Password cannot be empty.';
      } else {
        _passwordError = null; // Clear error if not focused or becomes valid
      }
    });
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Reset errors and success state
    setState(() {
      _usernameError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _generalMessage = null;
      _isSuccess = false;
      _isLoading = true; // Start loading
    });

    // Validation
    List<String> errors = [];
    if (username.isEmpty) {
      _usernameError = 'Username cannot be empty.';
      errors.add(_usernameError!);
    } else if (username.length < 3) {
      _usernameError = 'Username must be at least 3 characters.';
      errors.add(_usernameError!);
    } else if (_users.containsKey(username)) {
      _usernameError = 'Username already taken.';
      errors.add(_usernameError!);
    }

    if (password.isEmpty) {
      _passwordError = 'Password cannot be empty.';
      errors.add(_passwordError!);
    } else if (!(_hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSymbol)) {
      _passwordError = 'Password does not meet all criteria.';
      errors.add(_passwordError!);
    }

    if (confirmPassword.isEmpty) {
      _confirmPasswordError = 'Confirm password cannot be empty.';
      errors.add(_confirmPasswordError!);
    } else if (password != confirmPassword) {
      _confirmPasswordError = 'Passwords do not match.';
      errors.add(_confirmPasswordError!);
    }

    if (!_acceptTerms) {
      errors.add('You must accept the Terms and Conditions.');
    }

    if (errors.isNotEmpty) {
      setState(() {
        _generalMessage = errors.length > 1 ? 'Fix the errors to proceed.' : errors.first;
        _isSuccess = false;
        _isLoading = false; // Stop loading
      });
      return;
    }

    try {
      // Send the data to the server
      final response = await dataController.registerUser({
        'username': username,
        'password': password,
      });

      if (response['success'] == true) {
        setState(() {
          _generalMessage = 'Registration successful! You can now log in.';
          _isSuccess = true;
        });
        await Future.delayed(const Duration(seconds: 2)); // Show success message briefly
        Get.to(() => const LoginPage());
      } else {
        setState(() {
          _generalMessage = response['error'] ?? 'Registration failed. Please try again.';
          _isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _generalMessage = 'An unexpected error occurred. Please try again.';
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Privacy Notice: Use an alias, not your real name. For your security, we don’t collect emails or phone numbers. If you lose your username or password, your account cannot be recovered. Keep your details safe!',
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Account',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
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
                    hintText: 'e.g., ShengStar',
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
                Focus(
                  focusNode: _passwordFocusNode,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Password',
                    labelStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                    hintText: '8+ chars, 1 capital, 1 symbol',
                    hintStyle: GoogleFonts.roboto(color: Colors.grey[700]),
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
                ),
                if (_isPasswordFocused || _passwordController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: PasswordCriteriaWidget(
                      hasMinLength: _hasMinLength,
                      hasUppercase: _hasUppercase,
                      hasLowercase: _hasLowercase,
                      hasNumber: _hasNumber,
                      hasSymbol: _hasSymbol,
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
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
                        _obscureConfirmPassword ? FeatherIcons.eyeOff : FeatherIcons.eye,
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
                Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms = value ?? false;
                        });
                      },
                      checkColor: Colors.black,
                      activeColor: Colors.tealAccent,
                      side: BorderSide(color: Colors.grey[700]!),
                    ),
                    Expanded(
                      child: Text(
                        'I accept the Terms and Conditions',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _register,
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
                            'Register',
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
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: Text(
                      'Already have an account? Log in',
                      style: GoogleFonts.roboto(
                        color: Colors.tealAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _tapCount++;
                    });
                    if (_tapCount == 10) {
                      _tapCount = 0; // Reset counter
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminPage()),
                      );
                    }
                  },
                  child: Center(
                    child: Text(
                      'Powered by Code the Labs',
                      style: GoogleFonts.roboto(
                        color: Colors.white70,
                        fontSize: 12,
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

class PasswordCriteriaWidget extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSymbol;

  const PasswordCriteriaWidget({
    Key? key,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSymbol,
  }) : super(key: key);

  Widget _buildCriteriaRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            met ? FeatherIcons.checkCircle : FeatherIcons.xCircle,
            color: met ? Colors.greenAccent[400] : Colors.redAccent[400],
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.roboto(
              color: met ? Colors.greenAccent[400] : Colors.redAccent[400],
              fontSize: 13,
              decoration: met ? TextDecoration.none : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCriteriaRow('At least 8 characters', hasMinLength),
        _buildCriteriaRow('At least one uppercase letter (A-Z)', hasUppercase),
        _buildCriteriaRow('At least one lowercase letter (a-z)', hasLowercase),
        _buildCriteriaRow('At least one number (0-9)', hasNumber),
        _buildCriteriaRow('At least one symbol (!@#\$%^&*...)', hasSymbol),
      ],
    );
  }
}