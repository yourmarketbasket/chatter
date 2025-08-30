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
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'package:chatter/pages/users_list_page.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:device_info_plus/device_info_plus.dart'; // No longer needed for player selection
// import 'dart:io'; // No longer needed for player selection (Platform check)

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
  late StreamSubscription _intentDataStreamSubscription;

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

    // For sharing any data coming from outside the app while it is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      setState(() {
        _handleSharedData(value);
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // For sharing any data coming from outside the app while it is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      setState(() {
        if (value.isNotEmpty) {
          _handleSharedData(value);
        }
      });
    });
  }

  void _handleSharedData(List<SharedMediaFile> sharedFiles) {
    if (sharedFiles.isEmpty) return;

    Get.to(() => UsersListPage(
          sharedData: sharedFiles,
          onUserSelected: (user) {
            final file = sharedFiles.first;
            if (file.type == SharedMediaType.text || file.path.startsWith('http')) {
              _dataController.sendChatMessage({
                'chatId': user['chatId'],
                'content': file.path,
                'type': 'text',
                'senderId': _dataController.user.value['user']['_id'],
                'participants': [
                  _dataController.user.value['user']['_id'],
                  user['_id']
                ],
              }, null);
            } else if (file.type == SharedMediaType.url || file.path.startsWith('geo:')) {
              _dataController.sendChatMessage({
                'chatId': user['chatId'],
                'content': file.path,
                'type': 'location',
                'senderId': _dataController.user.value['user']['_id'],
                'participants': [
                  _dataController.user.value['user']['_id'],
                  user['_id']
                ],
              }, null);
            } else if (file.path.endsWith('.vcf')) {
              _dataController.sendChatMessage({
                'chatId': user['chatId'],
                'content': file.path,
                'type': 'contact',
                'senderId': _dataController.user.value['user']['_id'],
                'participants': [
                  _dataController.user.value['user']['_id'],
                  user['_id']
                ],
              }, null);
            } else {
              final files = sharedFiles
                  .map((file) => PlatformFile(
                        name: file.path.split('/').last,
                        path: file.path,
                        size: 0,
                      ))
                  .toList();
              _dataController.sendChatMessage({
                'chatId': user['chatId'],
                'content': '',
                'type': 'attachment',
                'files': files
                    .map((file) => {
                          'url': file.path,
                          'type':
                              _dataController.getMediaType(file.extension ?? ''),
                          'size': file.size,
                          'filename': file.name,
                        })
                    .toList(),
                'senderId': _dataController.user.value['user']['_id'],
                'participants': [
                  _dataController.user.value['user']['_id'],
                  user['_id']
                ],
              }, null);
            }
            Get.back();
          },
        ));
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
    _intentDataStreamSubscription.cancel();
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
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.tealAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.pinkAccent,
        ),
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black,
          ),
        ),
      ),
      navigatorObservers: [routeObserver],
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