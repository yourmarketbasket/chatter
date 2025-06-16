import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/landing-page.dart';
import 'package:chatter/pages/login.dart';
import 'package:chatter/pages/register.dart';
import 'package:chatter/services/socket-service.dart';
import 'package:chatter/controllers/data-controller.dart'; // Added import
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize DataController and register as singleton
  final DataController dataController = Get.put(DataController());

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