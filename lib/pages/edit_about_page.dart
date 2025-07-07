import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';

class EditAboutPage extends StatefulWidget {
  const EditAboutPage({Key? key}) : super(key: key);

  @override
  _EditAboutPageState createState() => _EditAboutPageState();
}

class _EditAboutPageState extends State<EditAboutPage> {
  final DataController _dataController = Get.find<DataController>();
  late TextEditingController _aboutTextController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current "about" text from DataController
    final String currentAbout = _dataController.user.value['user']?['about'] as String? ?? '';
    _aboutTextController = TextEditingController(text: currentAbout);
  }

  @override
  void dispose() {
    _aboutTextController.dispose();
    super.dispose();
  }

  Future<void> _saveAboutInfo() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final String newAboutText = _aboutTextController.text.trim();
    final result = await _dataController.updateAboutInfo(newAboutText);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      Get.back(); // Go back to the previous page (e.g., AppDrawer or ProfilePage)
      Get.snackbar(
        'Success',
        result['message'] ?? 'Your "About" information has been updated.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Error',
        result['message'] ?? 'Failed to update "About" information.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Edit About Info', style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(FeatherIcons.save, color: Colors.tealAccent),
                  onPressed: _saveAboutInfo,
                  tooltip: 'Save',
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Tell us a little about yourself. This will be displayed on your profile.',
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _aboutTextController,
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
              maxLines: 5, // Allow multiple lines for "about" text
              maxLength: 280, // Optional: Set a character limit
              decoration: InputDecoration(
                hintText: 'Write something about yourself...',
                hintStyle: GoogleFonts.roboto(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.tealAccent, width: 1.5),
                ),
                counterStyle: GoogleFonts.roboto(color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
