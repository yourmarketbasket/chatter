import 'package:chatter/pages/buy_me_a_coffee_page.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/landing-page.dart';
import 'package:chatter/pages/login.dart';
import 'package:chatter/pages/admin_page.dart';
import 'package:chatter/pages/main_chats.dart';
import 'package:chatter/pages/register.dart';
import 'package:chatter/services/socket-service.dart';
import 'package:chatter/services/media_visibility_service.dart'; // Import MediaVisibilityService
import 'package:chatter/services/notification_service.dart'; // Import NotificationService
import 'package:chatter/controllers/data-controller.dart'; // Added import
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatter/helpers/timeago_helpers.dart';
// import 'package:device_info_plus/device_info_plus.dart'; // No longer needed for player selection
// import 'dart:io'; // No longer needed for player selection (Platform check)

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set timeago locale
  timeago.setLocaleMessages('en_short_hr_ago', EnShortHrAgoMessages());
  timeago.setDefaultLocale('en_short_hr_ago');

  // Suppress logging
  Logger.root.level = Level.OFF;
  Logger.root.onRecord.listen((record) {
    // Don't print anything to the console
  });

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize DataController and register as singleton
  final DataController dataController = Get.put(DataController());
  // Initialize MediaVisibilityService
  Get.put(MediaVisibilityService());

  // Removed Android version fetching for player selection.
  // If dataController.androidSDKVersion is used elsewhere, its population might need to be re-evaluated or retained.
  // For now, we assume it was primarily for player choice.
  // print("Android SDK Version logic for player selection removed.");


  // Initialize SocketService. The constructor of SocketService calls connect().
  // Register SocketService as a singleton.
  Get.put(SocketService());

  // Initialize NotificationService
  Get.put(NotificationService());


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
      routingCallback: (routing) {
        if (routing != null) {
          _dataController.currentRoute.value = routing.current;
        }
      },
      title: 'Chatter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LandingPage(), // Show LandingPage while checking storage
      getPages: [
        GetPage(name: '/landing', page: () => const LandingPage()),
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/register', page: () => const RegisterPage()),
        GetPage(name: '/home', page: () => const HomeFeedScreen()),
        GetPage(name: '/buy-me-a-coffee', page: () => const BuyMeACoffeePage()),
        // main chats page
        GetPage(name: '/chats', page: () =>  MainChatsPage()),
        GetPage(name: '/admin', page: () => const AdminPage()),
      ],
    );
  }
}