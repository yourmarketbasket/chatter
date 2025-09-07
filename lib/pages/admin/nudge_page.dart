import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class NudgePage extends StatefulWidget {
  const NudgePage({Key? key}) : super(key: key);

  @override
  _NudgePageState createState() => _NudgePageState();
}

class _NudgePageState extends State<NudgePage> {
  final TextEditingController _versionController = TextEditingController();

  void _sendNudge(String type) {
    String message = '';
    if (type == 'version') {
      final version = _versionController.text.trim();
      if (version.isEmpty) {
        Get.snackbar(
          'Error',
          'Please enter a version number.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
        );
        return;
      }
      message = 'Nudge sent for version update: $version';
    } else {
      message = 'Generic nudge sent to all users.';
    }

    Get.snackbar(
      'Nudge Sent',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade800,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'App Update Nudge',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _versionController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Target App Version (e.g., 1.0.1)',
                labelStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.tealAccent),
                ),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _sendNudge('version'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Nudge for Version Update',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'Generic Nudge',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will send a generic "Please update your app" notification to all users.',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _sendNudge('generic'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Send Generic Nudge',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
