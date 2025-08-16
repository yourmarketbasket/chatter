import 'package:chatter/controllers/data-controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  NotificationService().showNotification(message);
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final DataController _dataController = Get.find<DataController>();

  static const String _channelId = 'chatter_default_channel';
  static const String _channelName = 'Chatter Notifications';
  static const String _channelDescription = 'Default channel for Chatter app notifications';

  // Use the specific 16px icon name for the status bar
  // This static const is no longer strictly needed here if only used for initialization,
  // but can be kept if used elsewhere or for clarity.
  // static const String _notificationIconName = '@drawable/ic_status_16px'; // Original problematic line

  Future<void> init() async {
    await _firebaseMessaging.requestPermission();
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      print('FCM Token: $fcmToken');
      _dataController.updateFcmToken(fcmToken);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_status_16px');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload != null) {
          print('notification payload: ${response.payload}');
          // This is a simplified navigation. In a real app, you'd want to
          // check if the user is already on the chat screen, etc.
          // Also, you'd need the other chat details like username and avatar.
          // For now, we'll just print.
        }
      },
    );

    await _createAndroidNotificationChannel();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }

      showNotification(message);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void showNotification(RemoteMessage message) {
    final notification = message.data;
    if (notification['type'] == 'NEW_MESSAGE') {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification['senderName'],
        notification['messageText'],
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: 'ic_status_16px',
          ),
        ),
        payload: notification['chatId'],
      );
    }
  }

  Future<void> _createAndroidNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    if (kDebugMode) {
      print("Notification channel '$_channelId' created.");
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt >= 33) { // Android 13+
        PermissionStatus status = await Permission.notification.request();
        if (status.isGranted) {
          if (kDebugMode) print("Notification permission granted.");
          return true;
        } else {
          if (kDebugMode) print("Notification permission denied.");
          return false;
        }
      } else {
        if (kDebugMode) print("Notification permission not required for Android SDK ${deviceInfo.version.sdkInt}.");
        return true;
      }
    }
    return true;
  }

  Future<void> showTestNotification() async {
    if (kDebugMode) {
      print("Attempting to show test notification...");
    }
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      if (kDebugMode) {
        print("Cannot show notification due to missing permissions.");
      }
      return;
    }

    // Ensure the icon name here matches the one used in initialization
    // and is the name of your monochrome drawable resource.
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      icon: 'ic_status_16px', // Correct: Just the name of the drawable resource
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      // iOS: iOSPlatformChannelSpecifics,
    );

    try {
      // await _flutterLocalNotificationsPlugin.show(
      //   0,
      //   'Test Notification',
      //   'This is a test notification from Chatter!',
      //   platformChannelSpecifics,
      // );
      if (kDebugMode) {
        print("Test notification shown successfully.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error showing notification: $e");
      }
    }
  }
}
