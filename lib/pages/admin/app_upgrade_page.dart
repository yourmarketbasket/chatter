import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';

class AppUpgradePage extends StatefulWidget {
  const AppUpgradePage({Key? key}) : super(key: key);

  @override
  _AppUpgradePageState createState() => _AppUpgradePageState();
}

class _AppUpgradePageState extends State<AppUpgradePage> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _changelogController = TextEditingController();
  final DataController _dataController = Get.find<DataController>();
  bool _isLoading = false;

  void _issueUpgradeNudge() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final version = _versionController.text;
      final changelog = _changelogController.text.split('\n').where((s) => s.trim().isNotEmpty).toList();

      // Issue nudge for both platforms
      final resultAndroid = await _dataController.issueAppUpgradeNudge(version, changelog, 'android');
      final resultIos = await _dataController.issueAppUpgradeNudge(version, changelog, 'ios');

      setState(() {
        _isLoading = false;
      });

      if (resultAndroid['success'] && resultIos['success']) {
        Get.snackbar(
          'Success',
          'Upgrade nudge issued for version $version on Android and iOS.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to issue nudge. Android: ${resultAndroid['message']} iOS: ${resultIos['message']}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Issue App Upgrade Nudge',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _versionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'App Version (e.g., 1.2.3)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.tealAccent),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a version number';
                  }
                  // Basic version format check
                  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) {
                    return 'Please use format X.Y.Z (e.g., 1.2.3)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _changelogController,
                style: const TextStyle(color: Colors.white),
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Changelog (one item per line)',
                  labelStyle: TextStyle(color: Colors.grey),
                  alignLabelWithHint: true,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.tealAccent),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the changelog';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _issueUpgradeNudge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Issue Nudge',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
