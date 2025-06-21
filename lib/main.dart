import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/landing-page.dart';
import 'package:chatter/pages/login.dart';
import 'package:chatter/pages/register.dart';
import 'package:chatter/services/socket-service.dart';
import 'package:chatter/controllers/data-controller.dart'; // Added import
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Added for device info
import 'dart:io'; // Added for Platform check

void main() async { // Changed to async
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize DataController and register as singleton
  final DataController dataController = Get.put(DataController());

  // Fetch Android version and store in DataController
  if (Platform.isAndroid) {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    dataController.androidSDKVersion.value = androidInfo.version.sdkInt;
  } else {
    // For non-Android platforms, you might set a default or a specific indicator
    // For example, 0 or a high number if your logic depends on it.
    // Setting to a high number (e.g., 34 or higher) to ensure non-Android defaults to video_player logic
    dataController.androidSDKVersion.value = 34; // Assuming 34+ will use video_player
  }
  print("Android SDK Version: ${dataController.androidSDKVersion.value}");


  // Initialize SocketService. The constructor of SocketService calls connect().
  // Register SocketService as a singleton.
  final SocketService socketService = Get.put(SocketService());

  runApp(const ChatterApp());
}

class ChatterApp extends StatefulWidget {
  const ChatterApp({super.key});

  @override
  _ChatterAppState createState() => _ChatterAppState();
}

class _ChatterAppState extends State<ChatterApp> {
  late FlutterSecureStorage _storage;
  final  DataController _dataController = Get.put(DataController());

  @override
  void initState() {
    super.initState();
    _dataController.init(); // Initialize DataController
    // Initialize secure storage with platform-specific options
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
    // Check initial screen after initialization
    _checkInitialScreen();
  }

  Future<void> _checkInitialScreen() async {
    try {
      // Check if token and user exist in secure storage
      final token = await _storage.read(key: 'token');
      final user = await _storage.read(key: 'user');
      // Navigate to HomeFeedScreen if both token and user exist, otherwise LoginPage
      if (token != null && user != null) {
        Get.offAll(() => const HomeFeedScreen());
      } else {
        Get.offAll(() => const LoginPage());
      }
    } catch (e) {
      // In case of any error, navigate to LoginPage
      Get.offAll(() => const LoginPage());
    }
  }

  @override
  void dispose() {
    // Clean up SocketService when the app is disposed
    final socketService = Get.find<SocketService>();
    socketService.disconnect();
    socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Chatter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LandingPage(), // Show LandingPage while checking storage
    );
  }
}