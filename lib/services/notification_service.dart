import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/pages/chat_screen_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'package:uuid/uuid.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  await NotificationService().showNotification(message);
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
    print('onDidReceiveBackgroundNotificationResponse: payload=${response.payload}');
    // This is where you would handle background notification actions.
    // Since this is a separate isolate, you can't easily access GetX controllers.
    // A common pattern is to use a different mechanism like shared_preferences
    // to store the action and handle it when the app starts.
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  DataController get _dataController => Get.find<DataController>();


  static const String _channelId = 'chatter_default_channel';
  static const String _channelName = 'Chatter Notifications';
  static const String _channelDescription = 'Default channel for Chatter app notifications';

  Future<void> init() async {
    await _requestPermissions();
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      print('FCM Token: $fcmToken');
      if(Get.isRegistered<DataController>()) {
        _dataController.updateFcmToken(fcmToken);
      }
    }
    // git branch
    

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_status_16px');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );

    await _createAndroidNotificationChannel();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      showNotification(message);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void onDidReceiveNotificationResponse(NotificationResponse response) async {
    final payloadString = response.payload;
    if (payloadString != null) {
      print('notification payload: $payloadString, actionId: ${response.actionId}');

      final payload = jsonDecode(payloadString);
      final chatId = payload['chatId'];
      final messageId = payload['messageId'];

      if (!Get.isRegistered<DataController>()) {
          print("DataController not registered. Cannot handle notification action.");
          return;
      }
      final dataController = Get.find<DataController>();

      if (response.actionId == 'REPLY') {
        final repliedText = response.input;
        if (repliedText != null && repliedText.isNotEmpty) {
          print('Replying with: "$repliedText" to chat ID: $chatId');
          final clientMessageId = const Uuid().v4();
          final currentUser = dataController.user.value['user'];

          // Create a temporary message for optimistic UI update, mimicking the format from ChatScreen
          final tempMessage = {
            'clientMessageId': clientMessageId,
            'chatId': chatId,
            'senderId': {
              '_id': currentUser['_id'],
              'name': currentUser['name'],
              'avatar': currentUser['avatar'],
            },
            'content': repliedText,
            'type': 'text',
            'files': [],
            'replyTo': messageId, // The ID of the message from the notification payload
            'viewOnce': false,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'status': 'sending',
          };
          dataController.addTemporaryMessage(tempMessage);

          // Prepare and send the final message to the backend
          final finalMessage = {
            'clientMessageId': clientMessageId,
            'chatId': chatId,
            'content': repliedText,
            'type': 'text',
            'replyTo': messageId,
          };
          await dataController.sendChatMessage(finalMessage, clientMessageId);
        }
      } else if (response.actionId == 'MARK_AS_READ') {
        print('Mark as Read action tapped for message ID: $messageId');
        if (messageId != null) {
            dataController.markMessageAsReadById(messageId);
        }
      } else {
        print('Notification tapped. Navigating to chat ID: $chatId');
        navigateToChat(chatId, dataController);
      }
    }
  }

  void navigateToChat(String chatId, DataController dataController) {
    final chat = dataController.chats[chatId];
    if (chat != null) {
        dataController.currentChat.value = chat;
        Get.to(() => const ChatScreen());
    } else {
        print("Chat with id $chatId not found in dataController.chats");
        // Fallback: maybe navigate to the main chats page
        Get.toNamed('/chats');
    }
  }

  Future<String?> _generateAvatar(String? avatarUrl, String senderName) async {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${avatarUrl.split('/').last}.png';
      final file = File(filePath);

      // if (await file.exists()) {
      //   return filePath;
      // }

      final response = await http.get(Uri.parse(avatarUrl));
      if (response.statusCode == 200) {
        final image = img.decodeImage(response.bodyBytes);
        if (image != null) {
          // Create a circular cropped version of the image.
          final circularImage = img.copyCropCircle(image);
          final pngBytes = img.encodePng(circularImage);
          await file.writeAsBytes(pngBytes);
          return filePath;
        }
      }
      return null;
    } catch (e) {
      print('Error generating avatar: $e');
      return null;
    }
  }

  Future<void> showNotification(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    if (notification == null) {
      print("showNotification: Received message without a notification part.");
      return;
    }

    if (data['type'] == 'new_message') {
      final String chatId = data['chatId'];
      final String groupKey = chatId;
      final String? messageBody = notification.body;
      final String? messageTitle = notification.title;

      final largeIconPath = await _generateAvatar(data['senderAvatar'], messageTitle ?? '?');

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        groupKey: groupKey,
        icon: 'ic_status_16px',
        importance: Importance.max,
        priority: Priority.high,
        largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
        actions: [
          AndroidNotificationAction(
            'REPLY',
            'Reply',
            showsUserInterface: true,
            inputs: [AndroidNotificationActionInput(label: 'Your reply...')],
          ),
          const AndroidNotificationAction('MARK_AS_READ', 'Mark as Read'),
        ],
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      final payload = jsonEncode({'chatId': chatId, 'messageId': data['messageId']});

      await _flutterLocalNotificationsPlugin.show(
        Random().nextInt(2147483647), // Use a random 32-bit integer ID
        messageTitle,
        messageBody,
        notificationDetails,
        payload: payload,
      );

      // --- Group Summary Notification ---
      final List<ActiveNotification> activeNotifications =
          await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.getActiveNotifications() ?? [];

      final List<ActiveNotification> chatNotifications = activeNotifications
          .where((n) => n.groupKey == groupKey && n.id != 0) // Exclude summary notification itself
          .toList();

      if (chatNotifications.length > 1) {
        final List<String> lines = chatNotifications.map((n) => n.body ?? '').toList();
        final InboxStyleInformation inboxStyleInformation = InboxStyleInformation(
          lines,
          contentTitle: messageTitle,
          summaryText: '${chatNotifications.length} new messages',
        );

        final AndroidNotificationDetails summaryAndroidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          groupKey: groupKey,
          setAsGroupSummary: true,
          styleInformation: inboxStyleInformation,
        );

        final NotificationDetails summaryNotificationDetails =
            NotificationDetails(android: summaryAndroidDetails);

        final int summaryId = chatId.hashCode;
        await _flutterLocalNotificationsPlugin.show(
          summaryId,
          messageTitle,
          '${chatNotifications.length} new messages',
          summaryNotificationDetails,
        );
      }

    } else if (data['type'] == 'group_invitation') {
        final largeIconPath = await _generateAvatar(data['adderAvatar'], data['addedBy'] ?? '?');
        final androidDetails = AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: 'ic_status_16px',
            importance: Importance.max,
            priority: Priority.high,
            largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
            styleInformation: BigTextStyleInformation(notification.body ?? ''),
        );
        final notificationDetails = NotificationDetails(android: androidDetails);
        final payload = jsonEncode({'chatId': data['chatId']});

        await _flutterLocalNotificationsPlugin.show(
            Random().nextInt(2147483647), // Use a random 32-bit integer ID
            notification.title,
            notification.body,
            notificationDetails,
            payload: payload,
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
}
