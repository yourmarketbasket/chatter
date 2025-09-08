import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
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
import 'package:url_launcher/url_launcher.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().showNotification(message);
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  DataController _dataController = Get.put(DataController());
  bool _isInitialized = false;

  static const String _channelId = 'chatter_default_channel';
  static const String _channelName = 'Chatter Notifications';
  static const String _channelDescription = 'Default channel for Chatter app notifications';

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _requestPermissions();
    final fcmToken = await _firebaseMessaging.getToken();
        _dataController.updateFcmToken(fcmToken!);
    

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
      showNotification(message);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void onDidReceiveNotificationResponse(NotificationResponse response) async {
    final payloadString = response.payload;
    if (payloadString != null) {
      final payload = jsonDecode(payloadString);
      final type = payload['type'] as String?;

      // Handle app update notifications first
      if (type == 'app_update') {
        final updateUrl = payload['update_url'] as String?;
        if (updateUrl != null) {
          final uri = Uri.parse(updateUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            // print('Could not launch $updateUrl');
          }
        }
        return; // Stop further processing
      }

      // Existing chat notification logic
      final chatId = payload['chatId'];
      final messageId = payload['messageId'];

      if (!Get.isRegistered<DataController>()) {
        return;
      }
      final dataController = Get.find<DataController>();

      if (response.actionId == 'REPLY') {
        final repliedText = response.input;
        if (repliedText != null && repliedText.isNotEmpty) {
          final clientMessageId = const Uuid().v4();
          final currentUser = dataController.user.value['user'];

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
            'replyTo': messageId,
            'viewOnce': false,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'status': 'sending',
          };
          dataController.addTemporaryMessage(tempMessage);

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
        if (messageId != null) {
          dataController.markMessageAsReadById(messageId);
        }
      } else {
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

      final response = await http.get(Uri.parse(avatarUrl));
      if (response.statusCode == 200) {
        final image = img.decodeImage(response.bodyBytes);
        if (image != null) {
          final circularImage = img.copyCropCircle(image);
          final resizedImage = img.copyResize(circularImage, width: 96, height: 96);
          final pngBytes = img.encodePng(resizedImage);
          await file.writeAsBytes(pngBytes);
          return filePath;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _downloadImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${imageUrl.split('/').last}';
      final file = File(filePath);

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final image = img.decodeImage(response.bodyBytes);
        if (image != null) {
          final resizedImage = img.copyResize(image, width: 512);
          final pngBytes = img.encodePng(resizedImage);
          await file.writeAsBytes(pngBytes);
          return filePath;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> showNotification(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    final type = data['type'] as String?;

    if (type == 'new_message') {
      
      if (notification == null) {
        return;
      }
      final String chatId = data['chatId'];

      if ((_dataController.currentRoute.value == '/ChatScreen' &&
              _dataController.activeChatId.value == chatId) ||
          _dataController.isMainChatsActive.value) {
        AudioPlayer()
            .play(AssetSource('notification-sounds/new-message-audio.mp3'));
        return;
      }
      final String groupKey = chatId;
      final String? messageBody = notification.body;
      final String? messageTitle = notification.title;
      final String? files = data['files'];
      List<dynamic>? fileList;
      String? imagePath;

      if (files != null && files.isNotEmpty) {
        try {
          fileList = jsonDecode(files);
          if (fileList!.isNotEmpty) {
            imagePath = await _downloadImage(fileList[0]['url']);
          }
        } catch (e) {
          // Handle JSON parsing or download error
        }
      }

      final largeIconPath =
          await _generateAvatar(data['senderAvatar'], messageTitle ?? '?');

      StyleInformation? styleInformation;
      if (imagePath != null && messageBody != null) {
        styleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          largeIcon:
              largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
          contentTitle: messageTitle,
          summaryText: messageBody,
          htmlFormatContentTitle: true,
          htmlFormatSummaryText: true,
        );
      } else if (imagePath != null) {
        styleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          largeIcon:
              largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
          contentTitle: messageTitle,
          htmlFormatContentTitle: true,
        );
      } else if (messageBody != null) {
        styleInformation = BigTextStyleInformation(
          messageBody,
          contentTitle: messageTitle,
          htmlFormatContentTitle: true,
          htmlFormatSummaryText: true,
        );
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        groupKey: groupKey,
        icon: 'ic_status_16px',
        importance: Importance.max,
        priority: Priority.high,
        largeIcon:
            largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
        styleInformation: styleInformation,
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
      final payload =
          jsonEncode({'chatId': chatId, 'messageId': data['messageId']});

      await _flutterLocalNotificationsPlugin.show(
        Random().nextInt(2147483647),
        messageTitle,
        messageBody,
        notificationDetails,
        payload: payload,
      );

      final List<ActiveNotification> activeNotifications =
          await _flutterLocalNotificationsPlugin
                  .resolvePlatformSpecificImplementation<
                      AndroidFlutterLocalNotificationsPlugin>()
                  ?.getActiveNotifications() ??
              [];

      final List<ActiveNotification> chatNotifications = activeNotifications
          .where((n) => n.groupKey == groupKey && n.id != 0)
          .toList();

      if (chatNotifications.length > 1) {
        final List<String> lines =
            chatNotifications.map((n) => n.body ?? '').toList();
        final InboxStyleInformation inboxStyleInformation = InboxStyleInformation(
          lines,
          contentTitle: messageTitle,
          summaryText: '${chatNotifications.length} new messages',
        );

        final AndroidNotificationDetails summaryAndroidDetails =
            AndroidNotificationDetails(
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
    } else if (type == 'new_post') {
      return;
    } else if (data['type'] == 'group_invitation') {
      // This notification type requires the `notification` object.
      if (notification == null) {
        return;
      }
      final largeIconPath =
          await _generateAvatar(data['adderAvatar'], data['addedBy'] ?? '?');
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: 'ic_status_16px',
        importance: Importance.max,
        priority: Priority.high,
        largeIcon:
            largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
        styleInformation: BigTextStyleInformation(notification.body ?? ''),
      );
      final notificationDetails = NotificationDetails(android: androidDetails);
      final payload = jsonEncode({'chatId': data['chatId']});

      await _flutterLocalNotificationsPlugin.show(
        Random().nextInt(2147483647),
        notification.title,
        notification.body,
        notificationDetails,
        payload: payload,
      );
    } else if (type == 'app_update') {
      final title = data['title'] as String? ?? 'Update Available';
      final body = data['body'] as String? ?? 'A new version is available. Tap to update.';
      final updateUrl = data['update_url'] as String?;
      final actionButtonTitle = data['action_button_title'] as String? ?? 'Update Now';

      if (updateUrl == null) {
        // print('App update notification received without update_url.');
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_status_16px',
        actions: [
          AndroidNotificationAction(
            'UPDATE_NOW_ACTION', // An ID for the action
            actionButtonTitle,
            showsUserInterface: false,
          ),
        ],
      );

      final notificationDetails = NotificationDetails(android: androidDetails);
      final payload = jsonEncode({
        'type': 'app_update',
        'update_url': updateUrl,
      });

      await _flutterLocalNotificationsPlugin.show(
        Random().nextInt(2147483647), // A unique ID for the notification
        title,
        body,
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
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt >= 33) {
        PermissionStatus status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    }
    return true;
  }
}