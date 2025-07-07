import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'chatter_default_channel';
  static const String _channelName = 'Chatter Notifications';
  static const String _channelDescription = 'Default channel for Chatter app notifications';

  // Use the specific 16px icon name for the status bar
  // This static const is no longer strictly needed here if only used for initialization,
  // but can be kept if used elsewhere or for clarity.
  // static const String _notificationIconName = '@drawable/ic_status_16px'; // Original problematic line

  Future<void> init() async {
    // Correctly reference the drawable resource name without the '@drawable/' prefix.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_status_16px');

    // TODO: Add iOS initialization settings if needed in the future
    // const DarwinInitializationSettings initializationSettingsIOS = ...;

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      // iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    await _createAndroidNotificationChannel();
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
