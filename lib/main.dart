import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/landing-page.dart';
import 'package:chatter/pages/login.dart';
import 'package:chatter/pages/register.dart';
import 'package:chatter/services/socket-service.dart';
import 'package:chatter/controllers/data-controller.dart'; // Added import
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/painting.dart'; // Required for PaintingBinding
import 'package:chatter/services/custom_cache_manager.dart'; // Required for CustomCacheManager
// import 'package:device_info_plus/device_info_plus.dart'; // No longer needed for player selection
// import 'dart:io'; // No longer needed for player selection (Platform check)

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize DataController and register as singleton
  final DataController dataController = Get.put(DataController());

  // Removed Android version fetching for player selection.
  // If dataController.androidSDKVersion is used elsewhere, its population might need to be re-evaluated or retained.
  // For now, we assume it was primarily for player choice.
  // print("Android SDK Version logic for player selection removed.");


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

class _ChatterAppState extends State<ChatterApp> with WidgetsBindingObserver { // Mixin WidgetsBindingObserver
  late FlutterSecureStorage _storage;
  final  DataController _dataController = Get.put(DataController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer
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

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    print('[ChatterApp] System reported low memory pressure. Clearing caches.');

    // Clear custom thumbnail cache (which also handles CachedNetworkImage default disk cache if same manager key is used)
    CustomCacheManager.instance.emptyCache().then((_) {
      print('[ChatterApp] Cleared CustomCacheManager (thumbnails & possibly default CachedNetworkImage disk cache).');
    }).catchError((e) {
      print('[ChatterApp] Error clearing CustomCacheManager: $e');
    });

    // Clear Flutter's global image cache (in-memory)
    PaintingBinding.instance.imageCache.clear();
    print('[ChatterApp] Cleared PaintingBinding imageCache (in-memory images).');

    // Note: video_player does not offer a direct global cache clear API.
    // It relies on HTTP caching headers and OS-level caching.
    // If specific BetterPlayerController instances were accessible globally, one might call clearCache on them.
    // For now, these are the main caches we can proactively clear.
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
    WidgetsBinding.instance.removeObserver(this); // Remove observer
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