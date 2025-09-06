import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:better_player_enhanced/better_player.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' as dio; 
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_handler/share_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/feed_models.dart';
import '../services/socket-service.dart';
import '../services/notification_service.dart';
import '../services/upload_service.dart'; 
import 'package:chatter/firebase_options.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

class DataController extends GetxController {
  final UploadService _uploadService = UploadService(); // Instantiate UploadService

  final RxBool isLoading = false.obs;
  final Uuid _uuid = const Uuid();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Set to keep track of post IDs for which view registration is in progress
  final Set<String> _pendingViewRegistrations = <String>{};

  // URL
  final String baseUrl = 'https://chatter-api-little-field-3471.fly.dev/';
  final dio.Dio _dio = dio.Dio(dio.BaseOptions(
    baseUrl: 'https://chatter-api-little-field-3471.fly.dev/',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));
  final user = {}.obs;
  final RxList<Map<String, dynamic>> posts = <Map<String, dynamic>>[].obs;
  final RxInt _currentPage = 1.obs;
  final RxBool _hasMorePosts = true.obs;
  final RxBool _isFetchingPosts = false.obs;
  String get newClientMessageId => _uuid.v4();

  // Placeholder for all users
  final RxList<Map<String, dynamic>> allUsers = <Map<String, dynamic>>[].obs;

  // Add these Rx variables inside DataController class
  final RxMap<String, Map<String, dynamic>> chats =
      <String, Map<String, dynamic>>{}.obs;
  final RxBool isLoadingChats = false.obs;
  final RxList<Map<String, dynamic>> currentConversationMessages = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingMessages = false.obs;
  final RxMap<String, String?> isTyping = <String, String?>{}.obs;
  final Rx<Map<String, dynamic>> currentChat = Rx<Map<String, dynamic>>({});
  final RxnString activeChatId = RxnString();
  final RxString currentRoute = ''.obs;
  final RxBool isMainChatsActive = false.obs;

  // Add these Rx variables inside DataController class
  final RxList<Map<String, dynamic>> followers = <Map<String, dynamic>>[].obs;
  final RxInt _currentFollowersPage = 1.obs;
  final RxBool _hasMoreFollowers = true.obs;
  final RxBool _isFetchingFollowers = false.obs;

  final RxBool isLoadingFollowers = false.obs;
  final RxList<Map<String, dynamic>> following = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingFollowing = false.obs;
  final RxInt _currentFollowingPage = 1.obs;
  final RxBool _hasMoreFollowing = true.obs;
  final RxBool _isFetchingFollowing = false.obs;

  // For User's Posts Page
  final RxList<Map<String, dynamic>> userPosts = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingUserPosts = false.obs;
  final RxInt _currentUserPostsPage = 1.obs;
  final RxBool _hasMoreUserPosts = true.obs;
  final RxBool _isFetchingUserPosts = false.obs;

  // For managing single media playback (video or audio)
  final Rxn<String> currentlyPlayingMediaId = Rxn<String>();
  final Rxn<String> currentlyPlayingMediaType = Rxn<String>(); // 'video' or 'audio'
  final Rxn<Object> activeMediaController = Rxn<Object>(); // Can be VideoPlayerController, BetterPlayerController, or AudioPlayer

  // Progress tracking for post creation
  final RxDouble uploadProgress = 0.0.obs;
  // Constants for progress allocation
  static const double _uploadPhaseProportion = 0.8; // 80% for file uploads
  static const double _savePhaseProportion = 0.2; // 20% for saving post to DB

  // Observable to notify ProfilePage to refresh
  final RxString profileUpdateTrigger = ''.obs;

  // For app updates
  final Rxn<Map<String, dynamic>> appUpdateNudgeData = Rxn<Map<String, dynamic>>();
  final Rxn<String> appVersion = Rxn<String>();


  @override
  void onInit() {
    super.onInit();
    init();
  }

  @override
  void onClose() {
    _dio.close(); // Clean up Dio instance
    super.onClose();
  }

  void init() async {
    // Load user data from secure storage
    String? userJson = await _storage.read(key: 'user');
    if (userJson != null) {
      user.value = jsonDecode(userJson);
    }
    // force

    // Only proceed with network calls if user is logged in
    if (user.value['token'] != null) {
      // Fetch non-essential data in parallel (fire and forget)
      fetchFeeds().catchError((e) {
          // print('Error fetching initial feeds: $e');
        posts.clear(); // Clear posts on error
      });
      final String? currentUserId = user.value['user']?['_id'];
      if (currentUserId != null && currentUserId.isNotEmpty) {
        // print('[DataController.init] User loaded from storage. Fetching initial network data for $currentUserId');
        fetchFollowers(currentUserId).catchError((e) {
          // print('Error fetching followers in init: $e');
        });
        fetchFollowing(currentUserId).catchError((e) {
          // print('Error fetching following in init: $e');
        });
      }

      // Initialize socket service after user data is loaded
      Get.find<SocketService>().initSocket();
      // For chat functionality, we need all users before we can correctly display chats.
      // So we await these calls in sequence.
      await fetchAllUsers();
      await fetchChats();

      // Initialize NotificationService after user data is loaded to ensure token is sent correctly
      final NotificationService notificationService = Get.find<NotificationService>();
      await notificationService.init();

      // Report current app version to backend
      updateUserAppVersion().catchError((e) {
        print('[DataController] Error reporting user app version in init: $e');
      });
    }
  }

  String? getAuthToken() {
    if (user.value.containsKey('token')) {
      return user.value['token'] as String?;
    }
    return null;
  }

  Future<List<String>> getActiveChatIds() async {
    return chats.keys.toList();
  }

  void handleNewUser(Map<String, dynamic> data) {
    // Not implemented
  }

  void handleNewChat(Map<String, dynamic> newChatData) {
    // All new and updated chat data should go through the same logic.
    handleChatUpdated(newChatData);
  }

  String getMediaType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'image/jpeg';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video/mp4';
      case 'mp3':
      case 'wav':
      case 'm4a':
        return 'audio/mp3';
      case 'pdf':
        return 'application/pdf';
      case 'vcf':
        return 'text/x-vcard';
      default:
        return 'application/octet-stream';
    }
  }

  void handleNewMessage(Map<String, dynamic> newMessage) {
    final chatId = newMessage['chatId'] as String?;
    if (chatId == null || newMessage['_id'] == null) return;

    // --- Update Chat List First ---
    if (chats.containsKey(chatId)) {
      final chat = chats[chatId]!;
      chat['lastMessage'] = newMessage;
      final senderId = newMessage['senderId'] is Map ? newMessage['senderId']['_id'] : newMessage['senderId'];
      if (senderId != null && senderId != getUserId()) {
        // Only increment unread count if the chat is not the active one
        if (activeChatId.value != chatId) {
          chat['unreadCount'] = (chat['unreadCount'] ?? 0) + 1;
        }
      }
      chats[chatId] = chat;
      chats.refresh();
    } else {
      // If chat is not in the list, fetch all chats again to get the new one.
      fetchChats();
    }

    // --- Update Conversation View ---
    if (activeChatId.value == chatId) {
      final newMsgId = newMessage['_id'] as String;
      final clientMsgId = newMessage['clientMessageId'] as String?;

      // Check for and replace optimistic message
      final existingMsgIndex = currentConversationMessages.indexWhere((m) {
        return (clientMsgId != null && m['clientMessageId'] == clientMsgId) || m['_id'] == newMsgId;
      });

      if (existingMsgIndex != -1) {
        currentConversationMessages[existingMsgIndex] = newMessage;
      } else {
        currentConversationMessages.add(newMessage);
      }

      // Mark as delivered
      final senderId = newMessage['senderId'] is Map ? newMessage['senderId']['_id'] : newMessage['senderId'];
      if (senderId != null && senderId != getUserId()) {
        markMessageAsDelivered(newMessage);
      }

      currentConversationMessages.refresh();
    }
  }

  void handleChatUpdated(Map<String, dynamic> updatedChatData) {
    print('[LOG] handleChatUpdated received: $updatedChatData');
    final chatId = updatedChatData['_id'] as String?;
    if (chatId == null) return;

    if (chats.containsKey(chatId)) {
      final existingChat = chats[chatId]!;

      // Separate the participants list to merge it intelligently
      final newParticipantsData = updatedChatData.remove('participants');

      // Update the rest of the chat details (name, about, lastMessage, etc.)
      existingChat.addAll(updatedChatData);

      // If the update contains a new participants list, merge it
      if (newParticipantsData is List) {
        final existingParticipants = List<Map<String, dynamic>>.from(existingChat['participants'] ?? []);
        final mergedParticipants = <Map<String, dynamic>>[];
        final existingParticipantsMap = { for (var p in existingParticipants) p['_id']: p };

        for (final newParticipantMap in newParticipantsData) {
          if (newParticipantMap is Map<String, dynamic>) {
            final participantId = newParticipantMap['_id'];
            if (existingParticipantsMap.containsKey(participantId)) {
              // Participant exists, merge data, preserving local 'isMuted' state as priority
              final existingParticipant = existingParticipantsMap[participantId]!;
              final mergedParticipant = Map<String, dynamic>.from(newParticipantMap);
              mergedParticipant['isMuted'] = existingParticipant['isMuted'] ?? newParticipantMap['isMuted'] ?? false;
              mergedParticipants.add(mergedParticipant);
            } else {
              // This is a new participant, add them directly
              mergedParticipants.add(newParticipantMap);
            }
          }
        }
        existingChat['participants'] = mergedParticipants;
      }

      // Put the fully updated chat object back into the main map
      chats[chatId] = existingChat;

      // Update the current chat if it's the one being viewed
      if (activeChatId.value == chatId) {
        currentChat.value = Map<String, dynamic>.from(existingChat);
      }
      chats.refresh();
    } else {
      // If the chat is not in the local list, add it. This happens on `chat:new`.
      chats[chatId] = updatedChatData;
      chats.refresh();
    }
  }

  void handleMessageStatusUpdate(Map<String, dynamic> data) {
    final messageId = data['messageId'] as String?;
    final status = data['status'] as String?;
    final userId = data['userId'] as String?;

    if (messageId == null || status == null || userId == null) return;

    void updateReceipts(Map<String, dynamic> message) {
        var receipts = List<Map<String, dynamic>>.from(message['readReceipts'] ?? []);
        final receiptIndex = receipts.indexWhere((r) => r['userId'] == userId);

        final newReceipt = {
            'userId': userId,
            'status': status,
            'timestamp': data['timestamp'] ?? DateTime.now().toUtc().toIso8601String(),
        };

        if (receiptIndex != -1) {
            if(receipts[receiptIndex]['status'] == 'read' && status == 'delivered') return;
            receipts[receiptIndex] = newReceipt;
        } else {
            receipts.add(newReceipt);
        }
        message['readReceipts'] = receipts;
    }

    final index = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (index != -1) {
        final message = Map<String, dynamic>.from(currentConversationMessages[index]);
        updateReceipts(message);

        var newList = List<Map<String, dynamic>>.from(currentConversationMessages);
        newList[index] = message;
        currentConversationMessages.assignAll(newList);
    }

    for (var chat in chats.values) {
        if (chat['lastMessage'] != null && chat['lastMessage']['_id'] == messageId) {
            final lastMessage = Map<String, dynamic>.from(chat['lastMessage'] as Map);
            updateReceipts(lastMessage);
            chat['lastMessage'] = lastMessage;
            chats[chat['_id']] = chat;
            break;
        }
    }

    currentConversationMessages.refresh();
    chats.refresh();
  }

  void handleMessageUpdate(Map<String, dynamic> data) {
    final messageId = data['_id'] as String?;
    final chatId = data['chatId'] as String?;

    if (messageId == null || chatId == null) {
      // print('[DataController] Invalid message:updated data received: $data');
      return;
    }

    // Update the message in the current conversation if it's open
    if (currentChat.value['_id'] == chatId) {
      final index = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
      if (index != -1) {
        // Merge new data into the existing message map to preserve details like sender info
        final existingMessage = Map<String, dynamic>.from(currentConversationMessages[index]);
        existingMessage.addAll(data);
        currentConversationMessages[index] = existingMessage;
        currentConversationMessages.refresh(); // Use refresh for nested changes
      }
    }

    // Update the lastMessage in the chats list if this message is the last one
    if (chats.containsKey(chatId) && chats[chatId]!['lastMessage']?['_id'] == messageId) {
      final chat = chats[chatId]!;
      // Also merge for the lastMessage to preserve details there too
      final existingLastMessage = Map<String, dynamic>.from(chat['lastMessage'] ?? {});
      existingLastMessage.addAll(data);
      chat['lastMessage'] = existingLastMessage;
      chats[chatId] = chat;
      chats.refresh();
    }
  }

  void handleMessageDelete(Map<String, dynamic> data) {
    final messageId = data['messageId'] as String?;
    final chatId = data['chatId'] as String?; // Assuming chatId is also sent
    final deletedForEveryone = data['deletedForEveryone'] as bool? ?? false;

    if (messageId == null || chatId == null) return;

    // Find the message in the conversation list and update it
    final messageIndex = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (messageIndex != -1) {
      final message = currentConversationMessages[messageIndex];
      if (deletedForEveryone) {
        message['deletedForEveryone'] = true;
        message['content'] = ''; // Clear content and files
        message['files'] = [];
      } else {
        // If delete is only for the current user, we can just remove it from the list
        currentConversationMessages.removeAt(messageIndex);
      }
      currentConversationMessages.refresh();
    }

    // Also update the lastMessage in the chat list if it was the one deleted
    if (chats.containsKey(chatId) && chats[chatId]!['lastMessage']?['_id'] == messageId) {
      final chat = chats[chatId]!;
      // Create a tombstone for the last message preview
      chat['lastMessage'] = {
        '_id': messageId,
        'content': 'Message deleted',
        'senderId': chats[chatId]!['lastMessage']['senderId'],
        'createdAt': chats[chatId]!['lastMessage']['createdAt'],
        'deletedForEveryone': true,
      };
      chats.refresh();
    }
  }

  void handleMessagesDeleted(Map<String, dynamic> data) {
    final messageIds = List<String>.from(data['messageIds'] ?? []);
    final deleteFor = data['deleteFor'] as String?;

    if (messageIds.isEmpty || deleteFor == null) {
      return;
    }

    if (deleteFor == 'everyone') {
      bool changed = false;
      for (final messageId in messageIds) {
        final index = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
        if (index != -1) {
          // Mark as deleted for everyone
          currentConversationMessages[index]['deletedForEveryone'] = true;
          currentConversationMessages[index]['content'] = '';
          currentConversationMessages[index]['files'] = [];
          changed = true;
        }
      }
      if (changed) {
        currentConversationMessages.refresh();
      }
    }
    // No action needed for deleteFor: "me" as it only affects the sender,
    // who has already handled it optimistically.
  }

  void markMessageAsReadById(String messageId) {
    if (messageId.isEmpty) return;
    // This is called from a notification, so we don't have the message object.
    // We can just send the event to the server. The server will then broadcast
    // the message:statusUpdate event, which will be handled by handleMessageStatusUpdate.
    // This assumes handleMessageStatusUpdate is correctly implemented.
    // print('[DataController] Sent mark as read event for message $messageId');
  }

  String? getUserId() {
    if (user.value.containsKey('user') && user.value['user'] is Map) {
      final userMap = user.value['user'] as Map<String, dynamic>;
      if (userMap.containsKey('_id')) {
        return userMap['_id'] as String?;
      }
    }
    return null;
  }

  // Method to fetch/initialize all users
  Future<void> fetchAllUsers() async {
    isLoading.value = true; // Indicate loading state for allUsers
    try {
      final String? token = user.value['token'];
      final String? currentUserId = user.value['user']?['_id'];

      if (token == null || currentUserId == null) {
        allUsers.clear(); // Clear previous users if any
        throw Exception('User not authenticated. Cannot fetch all users.');
      }

      // The route is users/get-all-users, parameters: userid
      // Assuming userid is the current user's ID to contextualize follow status
      final response = await _dio.get(
        'api/users', // Appending currentUserId as per common REST practice for parameters in path
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['users'] != null && response.data['users'] is List) {
          List<dynamic> fetchedUsersDynamic = response.data['users'];
          // print('[DataController] fetchAllUsers: Successfully fetched ${fetchedUsersDynamic.length} raw user entries.');
          // Process users: ensure all necessary fields are present and correctly typed.
          // Add 'isFollowingCurrentUser' based on the main user's following list.
          final List<String> currentUserFollowingIds = List<String>.from(
            (user.value['user']?['following'] as List<dynamic>? ?? []).map((e) => e.toString())
          );

          List<Map<String, dynamic>> fetchedUsers = fetchedUsersDynamic.map((userData) {
            if (userData is Map<String, dynamic>) {
              
              String userId = userData['_id']?.toString() ?? '';
              bool isFollowing = currentUserFollowingIds.contains(userId);

              int followersCount = userData['followersCount'] as int? ?? 0;
              int followingCount = userData['followingCount'] as int? ?? 0;

              
              if (followersCount == 0 && userData.containsKey('followers') && userData['followers'] is List) {
                followersCount = (userData['followers'] as List).length;
              }
              if (followingCount == 0 && userData.containsKey('following') && userData['following'] is List) {
                followingCount = (userData['following'] as List).length;
              }

              return {
                '_id': userId,
                'avatar': userData['avatar']?.toString() ?? '',
                'username': userData['name']?.toString(), 
                'name': userData['name']?.toString() ?? 'Unknown User',
                'followersCount': followersCount,
                'followingCount': followingCount,
                'isFollowingCurrentUser': isFollowing,
                'suspended': userData['suspended'],
                // Include the raw followers/following arrays if present, might be useful for other operations
                // or if socket events need to modify these specific users locally.
                'followers': userData['followers'] ?? [], // Store the array if available
                'following': userData['following'] ?? [], // Store the array if available
              };
            }
            return <String, dynamic>{}; // Return empty map for invalid data
          }).where((userMap) => userMap.isNotEmpty && userMap['_id'] != currentUserId).toList(); // Filter out empty maps and the current user

          allUsers.assignAll(fetchedUsers);
          // print('[DataController] Fetched all users successfully. Count: ${allUsers.length}');
        } else {
          allUsers.clear();
          // print('[DataController] Fetched all users but the user list is null or not a list.');
          throw Exception('User list not found in response or invalid format.');
        }
      } else {
        allUsers.clear();
        // print('[DataController] Failed to fetch all users. Status: ${response.statusCode}, Message: ${response.data?['message']}');
        throw Exception('Failed to fetch all users: ${response.data?['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
      allUsers.clear(); // Clear on error
      // print('[DataController] Error in fetchAllUsers: ${e.toString()}');
      // Optionally rethrow or handle as per UI requirements (e.g., show snackbar)
      // print('[DataController] fetchAllUsers caught error: ${e.toString()}');
      // For now, UsersListPage will show an error based on allUsers being empty + isLoading false.
    } finally {
      isLoading.value = false; // Reset loading state
      // print('[DataController] fetchAllUsers finally block. isLoading: ${isLoading.value}, allUsers count: ${allUsers.length}');
    }
  }

  // Create post
  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    // Update progress to indicate starting the save phase
    // This assumes uploads (if any) have completed and contributed to _uploadPhaseProportion
    uploadProgress.value = _uploadPhaseProportion;

    try {
      var token = user.value['token'];
      if (token == null) {
        uploadProgress.value = 0.0; // Reset progress on auth error
        throw Exception('User token not found');
      }

      // Simulate a bit of progress for the API call itself, maybe 10% of the save phase
      uploadProgress.value = _uploadPhaseProportion + (_savePhaseProportion * 0.1);

      var response = await _dio.post(
        'api/posts/create-post',
        data: data,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      // Simulate remaining progress for the save phase after API call returns
      uploadProgress.value = _uploadPhaseProportion + (_savePhaseProportion * 0.8);


      if (response.statusCode == 200 && response.data['success'] == true && response.data['post'] != null) {
        uploadProgress.value = 1.0; // Mark as complete
        return {'success': true, 'message': 'Post created successfully', 'post': response.data['post']};
      } else if (response.statusCode == 200 && response.data['success'] == true && response.data['post'] == null) {
          // print('[DataController] createPost success, but no post data returned from backend.');
        uploadProgress.value = 1.0; // Mark as complete
        return {'success': true, 'message': 'Post created successfully (no post data returned)'};
      } else {
        uploadProgress.value = 0.0; // Reset progress on failure
        return {
          'success': false,
          'message': response.data['message'] ?? 'Post creation failed',
          'post': null
        };
      }
    } catch (e) {
      uploadProgress.value = -1; // Indicate error state
      String errorMessage = e.toString();
      if (e is dio.DioException && e.response?.data != null && e.response!.data['message'] != null) {
        errorMessage = 'Failed to create post: ${e.response!.data['message']}';
      } else if (e is dio.DioException) {
        errorMessage = 'Failed to create post: ${e.message ?? e.toString()}';
      }
        // print('[DataController] Error creating post: $errorMessage');
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> unblockUser(String userIdToUnblock) async {
    // Optimistically update the UI
    final currentUser = Map<String, dynamic>.from(user.value['user']);
    final blockedUsers = List<String>.from(currentUser['blockedUsers'] ?? []);
    final wasBlocked = blockedUsers.contains(userIdToUnblock);

    if (wasBlocked) {
      blockedUsers.remove(userIdToUnblock);
      currentUser['blockedUsers'] = blockedUsers;
      user.value['user'] = currentUser;
      user.refresh();
    }

    try {
      final String? token = this.user['token'];
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await _dio.post(
        'api/users/unblock',
        data: {'userId': userIdToUnblock},
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'User unblocked successfully'};
      } else {
        // Rollback on failure
        if (wasBlocked) {
          blockedUsers.add(userIdToUnblock);
          currentUser['blockedUsers'] = blockedUsers;
          user.value['user'] = currentUser;
          user.refresh();
        }
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to unblock user. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      // Rollback on error
      if (wasBlocked) {
        blockedUsers.add(userIdToUnblock);
        currentUser['blockedUsers'] = blockedUsers;
        user.value['user'] = currentUser;
        user.refresh();
      }
      String errorMessage = 'An error occurred while unblocking the user.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> verifyUser(String userId, String entityType, String level, bool paid) async {
    try {
      final String? token = user.value['token'];
      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found.'};
      }

      final response = await _dio.post(
        'api/users/verify-user',
        data: {
          'userId': userId,
          'entityType': entityType,
          'level': level,
          'paid': paid,
        },
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'User verified successfully'};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to verify user. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      String errorMessage = 'An error occurred while verifying the user.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> searchUserByName(String name) async {
    try {
      final String? token = user.value['token'];
      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found.'};
      }

      final response = await _dio.get(
        '/api/users/by-name/$name',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['user'] != null) {
          return {'success': true, 'user': response.data['user']};
        } else {
          return {'success': false, 'message': 'User not found in response.'};
        }
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to fetch user. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      String errorMessage = 'An error occurred while fetching the user.';
      if (e is dio.DioException) {
        if (e.response?.statusCode == 404) {
          errorMessage = 'User not found.';
        } else if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  // Recursive helper to find and update a specific reply's fields
  bool _findAndUpdateNestedReply(List<dynamic> repliesList, String targetReplyId, Map<String, dynamic> updateData) {
    for (int i = 0; i < repliesList.length; i++) {
      Map<String, dynamic> currentReply = Map<String, dynamic>.from(repliesList[i]);
      if (currentReply['_id'] == targetReplyId) {
        // Found the target reply, update its fields
        updateData.forEach((key, value) {
          currentReply[key] = value;
        });
        // Ensure counts are updated if arrays were part of updateData
        if (updateData.containsKey('likes') && updateData['likes'] is List) {
          currentReply['likesCount'] = (updateData['likes'] as List).length;
        }
        if (updateData.containsKey('reposts') && updateData['reposts'] is List) {
          currentReply['repostsCount'] = (updateData['reposts'] as List).length;
        }
        if (updateData.containsKey('views') && updateData['views'] is List) {
          currentReply['viewsCount'] = (updateData['views'] as List).length;
        }
        // Note: 'replies' array changes and 'repliesCount' for nested replies are handled by _findAndAddNestedReply

        repliesList[i] = currentReply; // Update the list with the modified reply
        return true; // Reply updated
      }
      // If the current reply has its own replies, search deeper
      if (currentReply.containsKey('replies') && currentReply['replies'] is List && (currentReply['replies'] as List).isNotEmpty) {
        if (_findAndUpdateNestedReply(currentReply['replies'] as List<dynamic>, targetReplyId, updateData)) {
          // If found and updated in a deeper level, we need to update the currentReply in its parent list
          repliesList[i] = currentReply;
          return true; // Propagate success
        }
      }
    }
    return false; // Target reply not found at this level
  }

  void handleReplyUpdate(String postId, String replyId, Map<String, dynamic> updateData) {
    try {
      int postIndex = posts.indexWhere((p) => p['_id'] == postId);
      if (postIndex != -1) {
        Map<String, dynamic> postToUpdate = Map<String, dynamic>.from(posts[postIndex]);
        List<dynamic> topLevelReplies = List<dynamic>.from(postToUpdate['replies'] ?? []);

        if (_findAndUpdateNestedReply(topLevelReplies, replyId, updateData)) {
          postToUpdate['replies'] = topLevelReplies; // Assign the potentially modified list back
          posts[postIndex] = postToUpdate;
          posts.refresh();
          //   // print('[DataController] Reply $replyId in post $postId updated with data: $updateData.');
        } else {
            // print('[DataController] handleReplyUpdate: Target reply $replyId not found in post $postId.');
          // Optionally, fetch the post as a fallback
          // fetchSinglePost(postId);
        }
      } else {
          // print('[DataController] handleReplyUpdate: Post $postId not found.');
      }
    } catch (e) {
        // print('[DataController] Error handling reply update for reply $replyId in post $postId: $e');
    }
  }

  // Recursive helper to find and update a reply
  bool _findAndAddNestedReply(List<dynamic> repliesList, String targetParentReplyId, Map<String, dynamic> newReplyDocument) {
    // First, fully process the newReplyDocument using the main helper.
    // This ensures all its internal structures and counts are correct before adding.
    Map<String, dynamic> fullyProcessedNewReply = _processPostOrReply(Map<String, dynamic>.from(newReplyDocument));

    for (int i = 0; i < repliesList.length; i++) {
      Map<String, dynamic> currentReply = Map<String, dynamic>.from(repliesList[i]);
      if (currentReply['_id'] == targetParentReplyId) {
        // Found the parent reply, add the fully processed new reply to its 'replies' list
        List<dynamic> nestedReplies = List<dynamic>.from(currentReply['replies'] ?? []);

        nestedReplies.add(fullyProcessedNewReply); // Add the fully processed reply
        currentReply['replies'] = nestedReplies;
        currentReply['repliesCount'] = nestedReplies.length; // Update repliesCount of the parent reply

        repliesList[i] = currentReply; // Update the list with the modified reply
        return true; // Reply added
      }
      // If the current reply has its own replies, search deeper
      if (currentReply.containsKey('replies') && currentReply['replies'] is List && (currentReply['replies'] as List).isNotEmpty) {
        // Pass the original newReplyDocument for recursive calls, it will be processed at the start of _findAndAddNestedReply
        if (_findAndAddNestedReply(currentReply['replies'] as List<dynamic>, targetParentReplyId, newReplyDocument)) {
          repliesList[i] = currentReply; // Update the current reply in its parent list
          return true; // Propagate success
        }
      }
    }
    return false; // Parent reply not found at this level
  }

  void handleNewReplyToReply(String postId, String parentReplyId, Map<String, dynamic> emittedReply) {
    try {
      int postIndex = posts.indexWhere((p) => p['_id'] == postId);
      if (postIndex != -1) {
        Map<String, dynamic> postToUpdate = Map<String, dynamic>.from(posts[postIndex]);
        List<dynamic> topLevelReplies = List<dynamic>.from(postToUpdate['replies'] ?? []);

        // The emittedReply will be processed by _findAndAddNestedReply
        if (_findAndAddNestedReply(topLevelReplies, parentReplyId, emittedReply)) {
          postToUpdate['replies'] = topLevelReplies;
          // If the UI shows nested replies, this update to the 'replies' list and subsequent refresh should be enough.
          posts[postIndex] = postToUpdate;
          posts.refresh();
            // print('[DataController] New nested reply added to reply $parentReplyId in post $postId.');
        } else {
            // print('[DataController] handleNewReplyToReply: Parent reply $parentReplyId not found in post $postId.');
          // Optionally, fetch the post as a fallback if consistency is critical
          // fetchSinglePost(postId);
        }
      } else {
          // print('[DataController] handleNewReplyToReply: Post $postId not found.');
      }
    } catch (e) {
        // print('[DataController] Error handling new reply to reply for post $postId: $e');
    }
  }

  // view post - THIS IS THE ORIGINAL METHOD PROVIDED BY THE USER
  Future<Map<String, dynamic>> viewPost(String postId) async {
    if (_pendingViewRegistrations.contains(postId)) {
        // print('[DataController] View registration for post $postId is already in progress. Skipping.');
      return {'success': false, 'message': 'View registration already in progress.'};
    }

    try {
      _pendingViewRegistrations.add(postId);
      String? token = user.value['token'];
      // Ensure user and user ID exist
      if (user.value['user'] == null || user.value['user']['_id'] == null) {
          // print('[DataController] User data or user ID is null. Cannot record view for post $postId.');
        return {'success': false, 'message': 'User data not found.'};
      }
      String userId = user.value['user']['_id'];

      var response = await _dio.post(
        'api/posts/view-post', // Endpoint from the user's original method
        data: {'postId': postId, 'userId': userId},
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          }
        )
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // No local state update for views here; that will be handled by socket event.
          // print('[DataController] Post view for $postId recorded successfully.');
        return {'success': true, 'message': 'Post viewed successfully'};
      } else {
          // print('[DataController] Failed to record post view for $postId: ${response.data['message'] ?? 'Unknown error'}');
        return {'success': false, 'message': response.data['message'] ?? 'Post view failed'};
      }
    } catch (e) {
        // print('[DataController] Error recording post view for $postId: $e');
      return {'success': false, 'message': e.toString()};
    } finally {
      _pendingViewRegistrations.remove(postId);
    }
  }

  // like post
  Future<Map<String, dynamic>> likePost(String postId) async {
    try {
      String? token = user.value['token'];
      final String currentUserId = user.value['user']['_id'];
      if (currentUserId == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      var response = await _dio.post(
        'api/posts/like-post',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer ${user.value['token']}',
          }
        ),
        data: {'postId': postId, 'userId': currentUserId},
      );
      //   // print(response.data);
      if (response.statusCode == 200 && response.data['success'] == true) {
        // Fetch the full post to ensure data consistency
        await fetchSinglePost(postId);
        return {'success': true, 'message': response.data['message'] ?? 'Post liked successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Post like failed'};
      }
    } catch (e) {
      String errorMessage = 'An error occurred while logging in.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  void handleUserSuspended(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    if (userId == null) return;

    final index = allUsers.indexWhere((user) => user['_id'] == userId);
    if (index != -1) {
      final user = allUsers[index];
      user['suspended'] = true;
      allUsers[index] = user;
    }
  }

  void handleUserUnsuspended(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    if (userId == null) return;

    final index = allUsers.indexWhere((user) => user['_id'] == userId);
    if (index != -1) {
      final user = allUsers[index];
      user['suspended'] = false;
      allUsers[index] = user;
    }
  }

  void handleUserVerified(Map<String, dynamic> data) {
    final String? userId = data['userId'];
    final dynamic verification = data['verification'];

    if (userId == null || verification == null) {
      return;
    }

    // Update user in allUsers list
    final index = allUsers.indexWhere((u) => u['_id'] == userId);
    if (index != -1) {
      final userToUpdate = Map<String, dynamic>.from(allUsers[index]);
      userToUpdate['verification'] = verification;
      allUsers[index] = userToUpdate;
    }

    // Update current user if it's them
    if (user.value['user']?['_id'] == userId) {
      final updatedUser = Map<String, dynamic>.from(user.value);
      updatedUser['user']['verification'] = verification;
      user.value = updatedUser;
      _storage.write(key: 'user', value: jsonEncode(updatedUser));
    }

    // Update user in posts lists
    for (int i = 0; i < posts.length; i++) {
      if (posts[i]['user']?['_id'] == userId) {
        final postToUpdate = Map<String, dynamic>.from(posts[i]);
        postToUpdate['user']['verification'] = verification;
        posts[i] = postToUpdate;
      }
    }

    for (int i = 0; i < userPosts.length; i++) {
      if (userPosts[i]['user']?['_id'] == userId) {
        final postToUpdate = Map<String, dynamic>.from(userPosts[i]);
        postToUpdate['user']['verification'] = verification;
        userPosts[i] = postToUpdate;
      }
    }
  }

  void handlePostFlagged(Map<String, dynamic> data) {
    final postId = data['postId'] as String?;
    if (postId == null) return;

    final postIndex = posts.indexWhere((post) => post['_id'] == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      post['isFlagged'] = true;
      posts[postIndex] = post;
    }

    final userPostIndex = userPosts.indexWhere((post) => post['_id'] == postId);
    if (userPostIndex != -1) {
      final post = userPosts[userPostIndex];
      post['isFlagged'] = true;
      userPosts[userPostIndex] = post;
    }
  }

  void handlePostUnflagged(Map<String, dynamic> data) {
    final postId = data['postId'] as String?;
    if (postId == null) return;

    final postIndex = posts.indexWhere((post) => post['_id'] == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      post['isFlagged'] = false;
      posts[postIndex] = post;
    }

    final userPostIndex = userPosts.indexWhere((post) => post['_id'] == postId);
    if (userPostIndex != -1) {
      final post = userPosts[userPostIndex];
      post['isFlagged'] = false;
      userPosts[userPostIndex] = post;
    }
  }

  Future<Map<String, dynamic>> unflagPost(String postId) async {
    final postIndex = posts.indexWhere((post) => post['_id'] == postId);
    final userPostIndex = userPosts.indexWhere((post) => post['_id'] == postId);

    bool wasModified = false;
    if (postIndex != -1) {
      posts[postIndex]['isFlagged'] = false;
      posts.refresh();
      wasModified = true;
    }
    if (userPostIndex != -1) {
      userPosts[userPostIndex]['isFlagged'] = false;
      userPosts.refresh();
      wasModified = true;
    }

    try {
      final String? token = this.user['token'];
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await _dio.put(
        'api/posts/$postId/unflag',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // If not modified locally before, fetch to update UI
        if (!wasModified) await fetchSinglePost(postId);
        return {'success': true, 'message': 'Post unflagged successfully'};
      } else {
        // Rollback
        if (postIndex != -1) {
          posts[postIndex]['isFlagged'] = true;
          posts.refresh();
        }
        if (userPostIndex != -1) {
          userPosts[userPostIndex]['isFlagged'] = true;
          userPosts.refresh();
        }
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to unflag post. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      // Rollback
      if (postIndex != -1) {
        posts[postIndex]['isFlagged'] = true;
        posts.refresh();
      }
      if (userPostIndex != -1) {
        userPosts[userPostIndex]['isFlagged'] = true;
        userPosts.refresh();
      }
      String errorMessage = 'An error occurred while unflagging the post.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> unsuspendUser(String userId) async {
    final index = allUsers.indexWhere((user) => user['_id'] == userId);
    if (index == -1) {
      return {'success': false, 'message': 'User not found locally.'};
    }

    final userToUnsuspend = allUsers[index];
    final originalStatus = userToUnsuspend['suspended'] ?? false;
    userToUnsuspend['suspended'] = false;
    allUsers[index] = userToUnsuspend;

    try {
      final String? token = this.user['token'];
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await _dio.put(
        'api/users/$userId/unsuspend',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      // more 

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'User unsuspended successfully'};
      } else {
        userToUnsuspend['suspended'] = originalStatus;
        allUsers[index] = userToUnsuspend;
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to unsuspend user. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      userToUnsuspend['suspended'] = originalStatus;
      allUsers[index] = userToUnsuspend;
      String errorMessage = 'An error occurred while unsuspending the user.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> fetchPostsByUsername(String username) async {
    try {
      final String? token = this.user['token'];
      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found.'};
      }

      final response = await _dio.get(
        'api/posts/by-user/$username',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'posts': response.data['posts']};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to fetch posts. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      String errorMessage = 'An error occurred while fetching posts.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> searchUserByUsername(String username) async {
    try {
      final String? token = this.user['token'];
      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found.'};
      }

      final response = await _dio.get(
        'api/users/by-name/$username',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'user': response.data['user']};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to search user. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      String errorMessage = 'An error occurred while searching for the user.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> deletePostByAdmin(String postId) async {
    final postIndex = posts.indexWhere((post) => post['_id'] == postId);
    final userPostIndex = userPosts.indexWhere((post) => post['_id'] == postId);
    final postToDelete = postIndex != -1 ? posts[postIndex] : (userPostIndex != -1 ? userPosts[userPostIndex] : null);

    if (postToDelete == null) {
      return {'success': false, 'message': 'Post not found locally.'};
    }

    if (postIndex != -1) posts.removeAt(postIndex);
    if (userPostIndex != -1) userPosts.removeAt(userPostIndex);

    try {
      final String? token = this.user['token'];
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await _dio.delete(
        'api/posts/$postId/admin',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'Post deleted successfully'};
      } else {
        if (postIndex != -1) {
          posts.insert(postIndex, postToDelete);
        }
        if (userPostIndex != -1) {
          userPosts.insert(userPostIndex, postToDelete);
        }
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to delete post. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      if (postIndex != -1) {
        posts.insert(postIndex, postToDelete);
      }
      if (userPostIndex != -1) {
        userPosts.insert(userPostIndex, postToDelete);
      }
      String errorMessage = 'An error occurred while deleting the post.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> updateUserVerification(
      String userId, String entityType, String level, bool paid) async {
    try {
      final String? token = this.user['token'];
      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found.'};
      }

      final response = await _dio.post(
        'api/users/verify-user',
        data: {
          'userId': userId,
          'entityType': entityType,
          'level': level,
          'paid': paid,
        },
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final verificationData = response.data['verification'];
        handleUserVerified({'userId': userId, 'verification': verificationData});
        return {
          'success': true,
          'message': 'User verification updated',
          'verification': verificationData
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to update verification. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      String errorMessage = 'An error occurred while updating verification.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> flagPostForReview(String postId) async {
    final postIndex = posts.indexWhere((post) => post['_id'] == postId);
    final userPostIndex = userPosts.indexWhere((post) => post['_id'] == postId);

    bool wasModified = false;
    if (postIndex != -1) {
      posts[postIndex]['isFlagged'] = true;
      posts.refresh();
      wasModified = true;
    }
    if (userPostIndex != -1) {
      userPosts[userPostIndex]['isFlagged'] = true;
      userPosts.refresh();
      wasModified = true;
    }

    try {
      final String? token = this.user['token'];
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await _dio.put(
        'api/posts/$postId/flag',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // If not modified locally before, fetch to update UI
        if (!wasModified) await fetchSinglePost(postId);
        return {'success': true, 'message': 'Post flagged for review'};
      } else {
        // Rollback
        if (postIndex != -1) {
          posts[postIndex]['isFlagged'] = false;
          posts.refresh();
        }
        if (userPostIndex != -1) {
          userPosts[userPostIndex]['isFlagged'] = false;
          userPosts.refresh();
        }
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to flag post. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      // Rollback
      if (postIndex != -1) {
        posts[postIndex]['isFlagged'] = false;
        posts.refresh();
      }
      if (userPostIndex != -1) {
        userPosts[userPostIndex]['isFlagged'] = false;
        userPosts.refresh();
      }
      String errorMessage = 'An error occurred while flagging the post.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> suspendUser(String userId) async {
    final index = allUsers.indexWhere((user) => user['_id'] == userId);
    if (index == -1) {
      return {'success': false, 'message': 'User not found locally.'};
    }

    final userToSuspend = allUsers[index];
    final originalStatus = userToSuspend['suspended'] ?? false;
    userToSuspend['suspended'] = true;
    allUsers[index] = userToSuspend;

    try {
      final String? token = this.user['token'];
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await _dio.put(
        'api/users/$userId/suspend',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'User suspended successfully'};
      } else {
        userToSuspend['suspended'] = originalStatus;
        allUsers[index] = userToSuspend;
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to suspend user. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      userToSuspend['suspended'] = originalStatus;
      allUsers[index] = userToSuspend;
      String errorMessage = 'An error occurred while suspending the user.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> registerAdmin(
      String username, String password, String adminCode) async {
    try {
      final response = await _dio.post(
        'api/auth/register-admin',
        data: {
          'username': username,
          'password': password,
          'adminRegistrationCode': adminCode,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'Admin registered successfully'};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Registration failed'
        };
      }
    } catch (e) {
      String errorMessage = 'An error occurred while registering the admin.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  // Bookmark a post or reply
  Future<Map<String, dynamic>> bookmarkPost(String postId, {String? replyId}) async {
    final String endpoint = replyId != null
        ? 'api/posts/$postId/replies/$replyId/bookmark'
        : 'api/posts/$postId/bookmark';
    // print('[DataController] Bookmarking item: $endpoint');
    try {
      String? token = user.value['token'];
      if (token == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.post(
        endpoint,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // print('[DataController] Bookmarked item successfully');
        // The socket event will handle the update.
        return {'success': true, 'message': response.data['message'] ?? 'Bookmarked successfully'};
      } else {
        // print('[DataController] Failed to bookmark item: ${response.data['message']}');
        return {'success': false, 'message': response.data['message'] ?? 'Failed to bookmark'};
      }
    } catch (e) {
      // print('[DataController] Error bookmarking item: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Unbookmark a post or reply
  Future<Map<String, dynamic>> unbookmarkPost(String postId, {String? replyId}) async {
    final String endpoint = replyId != null
        ? 'api/posts/$postId/replies/$replyId/bookmark'
        : 'api/posts/$postId/bookmark';
    // print('[DataController] Unbookmarking item: $endpoint');
    try {
      String? token = user.value['token'];
      if (token == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.delete(
        endpoint,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // print('[DataController] Unbookmarked item successfully');
        // The socket event will handle the update.
        return {'success': true, 'message': response.data['message'] ?? 'Unbookmarked successfully'};
      } else {
        // print('[DataController] Failed to unbookmark item: ${response.data['message']}');
        return {'success': false, 'message': response.data['message'] ?? 'Failed to unbookmark'};
      }
    } catch (e) {
      // print('[DataController] Error unbookmarking item: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get bookmarked posts
  Future<Map<String, dynamic>> getBookmarkedPosts() async {
    // print('[DataController] Fetching bookmarked posts');
    try {
      String? token = user.value['token'];
      if (token == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.get(
        'api/posts/bookmarked',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // print('[DataController] Fetched bookmarked posts successfully');
        return {'success': true, 'posts': response.data['posts']};
      } else {
        // print('[DataController] Failed to fetch bookmarked posts: ${response.data['message']}');
        return {'success': false, 'message': response.data['message'] ?? 'Failed to fetch bookmarks'};
      }
    } catch (e) {
      // print('[DataController] Error fetching bookmarked posts: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // unlike post
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    try {
      String? token = user.value['token'];
      final String currentUserId = user.value['user']['_id'];
      if (currentUserId == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      var response = await _dio.post(
        'api/posts/unlike-post',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          }
        ),
        data: {'postId': postId, 'userId': currentUserId},
      );
      //   // print(response.data);
      if (response.statusCode == 200 && response.data['success'] == true) {
        // Fetch the full post to ensure data consistency
        await fetchSinglePost(postId);
        return {'success': true, 'message': response.data['message'] ?? 'Post unliked successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Post unlike failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  // view post
  // Future<Map<String, dynamic>> viewPost(String postId) async {
  //   try {
  //     String? token = user.value['token'];
  //     var response = await _dio.post(
  //       'api/posts/view-post',
  //       data: {'postId': postId, 'userId': user.value['user']['_id']},
  //       options: dio.Options(
  //         headers: {
  //           'Authorization': 'Bearer $token',
  //         }
  //       )
  //     );
  //     //   // print(response.data);
  //     if (response.statusCode == 200 && response.data['success'] == true) {
  //       return {'success': true, 'message': 'Post viewed successfully'};
  //     } else {
  //       return {'success': false, 'message': response.data['message'] ?? 'Post view failed'};
  //     }
  //   } catch (e) {
  //     return {'success': false, 'message': e.toString()};
  //   }
  // }

  //  reply to post
  Future<Map<String, dynamic>> replyToPost(Map<String, dynamic> data) async {
    try {
      String? token = user.value['token'];
      String? currentUserId = user.value['user']?['_id'];

      if (token == null || currentUserId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.post(
        '/api/posts/reply-to-post',
        data: {
          'postId': data['postId'],
          'userId': currentUserId,
          'content': data['content'],
          'attachments': data['attachments'] ?? [], // Ensure attachments are included
        },
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Optimistic UI Update
        int postIndex = posts.indexWhere((p) => p['_id'] == data['postId']);
        if (postIndex != -1) {
          posts[postIndex]['replies'].add(response.data['reply']);
        }
        return {'success': true, 'message': 'Reply added successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Post reply failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Method to fetch a single post by its ID and update it in the local list
  Future<void> fetchSinglePost(String postId) async {
    if (postId.isEmpty) {
        // print('[DataController] fetchSinglePost: postId is empty. Cannot fetch.');
      return;
    }
    // Optional: Add a loading state for this specific post if needed for UI
    // isLoadingPost[postId] = true; (would require managing a map of loading states)
      // print('[DataController] Fetching single post: $postId');

    try {
      var token = user.value['token'];
      if (token == null) {
          // print('[DataController] fetchSinglePost: User token not found. Cannot fetch post $postId.');
        throw Exception('User token not found');
      }

      // Assuming an endpoint like /api/posts/get-post/:postId
      // Adjust the endpoint as per your backend API structure.
      var response = await _dio.get(
        'api/posts/get-post/$postId',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true && response.data['post'] != null) {
        Map<String, dynamic> fetchedPostData = Map<String, dynamic>.from(response.data['post']);
        // Use the existing updatePostFromSocket logic to process and replace the post
        // This ensures consistent handling of post data and derived counts.
        updatePostFromSocket(fetchedPostData);
          // print('[DataController] Successfully fetched and updated post $postId.');
      } else {
          // print('[DataController] Failed to fetch post $postId. Status: ${response.statusCode}, Message: ${response.data['message']}');
        throw Exception('Failed to fetch post $postId: ${response.data['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
        // print('[DataController] Error fetching single post $postId: $e');
      // Optional: Set an error state for this specific post if needed for UI
      // postErrors[postId] = e.toString();
      // Rethrow if the caller needs to handle it, or handle silently here.
      // For now, just logging.
    } finally {
      // Optional: Clear loading state for this specific post
      // isLoadingPost[postId] = false;
    }
  }

  // repost a post
  Future<Map<String, dynamic>> repostPost(String postId) async {
    String? token = user.value['token'];
    String? currentUserId = user.value['user']?['_id'];

    if (token == null || currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      var response = await _dio.post(
        '/api/posts/repost-post',
        data: {'postId': postId, 'userId': currentUserId},
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Fetch the full post to ensure data consistency
        await fetchSinglePost(postId);
        return {'success': true, 'message': response.data['message'] ?? 'Post reposted successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to repost post'};
      }
    } catch (e) {
        // print('[DataController] Error reposting post $postId: $e');
      if (e is dio.DioException && e.response?.data != null && e.response!.data['message'] != null) {
        return {'success': false, 'message': 'Failed to repost: ${e.response!.data['message']}'};
      }
      return {'success': false, 'message': 'An error occurred while reposting: ${e.toString()}'};
    }
  }


  // Recursive helper to process a post or a reply, including its nested replies
  Map<String, dynamic> _processPostOrReply(Map<String, dynamic> itemData) {
    Map<String, dynamic> processedItem = Map<String, dynamic>.from(itemData);

    // Ensure basic fields and counts
    processedItem['likesCount'] = (processedItem['likes'] as List?)?.length ?? 0;
    processedItem['repostsCount'] = (processedItem['reposts'] as List?)?.length ?? 0;
    processedItem['viewsCount'] = (processedItem['views'] as List?)?.length ?? 0;
    processedItem['bookmarksCount'] = (processedItem['bookmarks'] as List?)?.length ?? 0;

    // Ensure attachments are correctly typed (List<Map<String, dynamic>>)
    if (processedItem['attachments'] is List) {
      processedItem['attachments'] = List<Map<String, dynamic>>.from(
        (processedItem['attachments'] as List).map((att) {
          if (att is Map<String, dynamic>) {
            return att;
          } else if (att is Map) {
            return Map<String, dynamic>.from(att);
          }
          return <String, dynamic>{}; // Should not happen with valid data
        }).where((att) => att.isNotEmpty)
      );
    } else {
      processedItem['attachments'] = <Map<String, dynamic>>[];
    }

    // Process nested replies
    if (processedItem['replies'] != null && processedItem['replies'] is List) {
      List<dynamic> rawReplies = processedItem['replies'] as List<dynamic>;
      List<Map<String, dynamic>> processedNestedReplies = [];
      for (var replyData in rawReplies) {
        if (replyData is Map<String, dynamic>) {
          processedNestedReplies.add(_processPostOrReply(replyData)); // Recursive call
        } else if (replyData is Map) {
          // Attempt to convert if it's Map but not Map<String, dynamic>
          processedNestedReplies.add(_processPostOrReply(Map<String, dynamic>.from(replyData)));
        }
      }
      processedItem['replies'] = processedNestedReplies;
      processedItem['replyCount'] = processedNestedReplies.length;
    } else {
      processedItem['replies'] = <Map<String, dynamic>>[];
      processedItem['replyCount'] = 0;
    }

    // Ensure essential lists exist even if empty, to prevent null errors downstream
    processedItem['likes'] ??= [];
    processedItem['reposts'] ??= [];
    processedItem['views'] ??= [];
    processedItem['bookmarks'] ??= [];

    return processedItem;
  }

  // fetch all feeds for timeline
  Future<void> fetchFeeds({bool isRefresh = false}) async {
    if (_isFetchingPosts.value) return;
    _isFetchingPosts.value = true;

    if (isRefresh) {
      _currentPage.value = 1;
      _hasMorePosts.value = true;
      posts.clear();
    }

    if (!_hasMorePosts.value) {
      _isFetchingPosts.value = false;
      return;
    }

    try {
      var token = user.value['token'];
      if (token == null) {
        throw Exception('User token not found');
      }
      var response = await _dio.get(
        '/api/posts/get-all-posts?page=${_currentPage.value}&limit=100',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        List<Map<String, dynamic>> fetchedPosts = List<Map<String, dynamic>>.from(response.data['posts']);
        if (fetchedPosts.isNotEmpty) {
          final blockedUsers = user.value['user']?['blockedUsers'] ?? [];
          List<Map<String, dynamic>> processedFetchedPosts = [];
          for (var postData in fetchedPosts) {
            if (!blockedUsers.contains(postData['user']?['_id'])) {
              processedFetchedPosts.add(_processPostOrReply(postData));
            }
          }
          posts.addAll(processedFetchedPosts);
          _currentPage.value++;
        } else {
          _hasMorePosts.value = false;
        }
      } else {
        throw Exception('Failed to fetch feeds');
      }
    } catch (e) {
      // print('Error fetching feeds: $e');
      // On error, you might want to allow a retry
    } finally {
      _isFetchingPosts.value = false;
    }
  }

  // Fetch replies for a post
  Future<List<Map<String, dynamic>>> fetchReplies(String postId) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User token not found. Please log in.');
      }

      final response = await _dio.get(
        '/api/posts/fetch-replies/$postId',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        //   // print("[DataController] Raw replies data from API for post $postId: ${response.data}");
        final List<dynamic> repliesData = response.data['replies'];
        List<Map<String, dynamic>> processedReplies = [];

        for (var replyData in repliesData) {
          if (replyData == null || replyData is! Map<String,dynamic>) {
            //   // print("[DataController] Skipping invalid reply data item: $replyData");
            continue;
          }
          Map<String,dynamic> currentReply = Map<String,dynamic>.from(replyData);

          // Safely extract and parse attachments
          List<Map<String, dynamic>> attachments = [];
          if (currentReply['attachments'] != null && currentReply['attachments'] is List) {
            for (var attData in (currentReply['attachments'] as List<dynamic>)) {
              if (attData is Map<String, dynamic>) {
                attachments.add({
                  'type': attData['type']?.toString() ?? 'unknown',
                  'url': attData['url']?.toString() ?? '',
                  'filename': attData['filename']?.toString() ?? '',
                  'size': (attData['size'] is num ? attData['size'] : int.tryParse(attData['size']?.toString() ?? '0'))?.toInt() ?? 0,
                  'thumbnailUrl': attData['thumbnailUrl']?.toString(), // Include thumbnail
                });
              }
            }
          }

          String username = currentReply['username']?.toString() ?? 'Unknown User';
          String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';
          if (currentReply['avatarInitial'] != null && currentReply['avatarInitial'].toString().isNotEmpty) {
            avatarInitial = currentReply['avatarInitial'].toString();
          }

          // Content: Pass buffer directly. _buildPostContent in ReplyPage will handle decoding.
          // Also pass 'content' if available as a direct string.
          String textContent = currentReply['content']?.toString() ?? '';
          final bufferData = currentReply['buffer'];

          processedReplies.add({
            '_id': currentReply['_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'username': username,
            'content': textContent, // Direct text content
            'buffer': bufferData,   // Buffer for potentially encoded content
            'createdAt': currentReply['createdAt'], // Pass as is (String or DateTime)
            'likes': List<dynamic>.from(currentReply['likes'] ?? []),
            'reposts': List<dynamic>.from(currentReply['reposts'] ?? []),
            'views': List<dynamic>.from(currentReply['views'] ?? []),
            'attachments': attachments,
            'avatarInitial': avatarInitial,
            'useravatar': currentReply['useravatar']?.toString(),
            'replies': List<dynamic>.from(currentReply['replies'] ?? const []),
            'userId': currentReply['userId']?.toString(),
          });
        }
        //   // print("[DataController] Processed replies for post $postId: $processedReplies");
        return processedReplies;
      } else {
          // print('[DataController] Error fetching replies for post $postId: ${response.statusCode} - ${response.data?['message']}');
        throw Exception('Failed to fetch replies: ${response.data?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
        // print('[DataController] Exception caught in fetchReplies for post $postId: $e');
      throw Exception('An error occurred while fetching replies: $e');
    }
  }

  // Add a new post to the beginning of the list, preventing duplicates
  void addNewPost(Map<String, dynamic> newPost) {
    Map<String, dynamic> processedNewPost = Map<String, dynamic>.from(newPost);

    processedNewPost['likesCount'] = (processedNewPost['likes'] as List?)?.length ?? 0;
    processedNewPost['repostsCount'] = (processedNewPost['reposts'] as List?)?.length ?? 0;
    processedNewPost['viewsCount'] = (processedNewPost['views'] as List?)?.length ?? processedNewPost['viewsCount'] ?? 0;

    if (processedNewPost['replies'] is List) {
      processedNewPost['replyCount'] = (processedNewPost['replies'] as List).length;
    } else if (processedNewPost['replyCount'] == null) {
      processedNewPost['replyCount'] = 0;
    }

    final String? newPostId = processedNewPost['_id'] as String?;

    if (newPostId == null) {
      //   // print("Warning: Adding a new post without an '_id'. Cannot check for duplicates by ID. Post data: $processedNewPost");
      posts.insert(0, processedNewPost);
      return;
    }

    final bool alreadyExists = posts.any((existingPost) {
      final String? existingPostId = existingPost['_id'] as String?;
      return existingPostId != null && existingPostId == newPostId;
    });

    if (!alreadyExists) {
      posts.insert(0, processedNewPost);
        // print("New post with ID $newPostId added to the list.");
    } else {
        // print("Post with ID $newPostId already exists in the list. Attempting to update.");
      final int existingPostIndex = posts.indexWhere((p) => (p['_id'] as String?) == newPostId);
      if (existingPostIndex != -1) {
        // Replace with new data, as it might be an update (e.g. from socket)
        posts[existingPostIndex] = processedNewPost;
        posts.refresh();
          // print("Updating existing post with ID $newPostId with new data.");
      }
    }
  }

  // Register user
  Future<Map<String, dynamic>> registerUser(Map<String, String> data) async {
    try {
      var response = await _dio.post(
        'api/auth/register',
        data: data,
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'User registered successfully'};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Registration failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Login user
  Future<Map<String, dynamic>> loginUser(Map<String, String> data) async {
    try {
      var response = await _dio.post(
        'api/auth/login',
        data: data,
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        try {
          // Save token and user data to secure storage
          String? tokenValue = response.data['user']['token']?.toString();
          String userJson = jsonEncode(response.data['user']);

          await _storage.write(key: 'token', value: tokenValue);
          await _storage.write(key: 'user', value: userJson);

          // Update the in-memory user state immediately
          user.value = jsonDecode(userJson);
            // print('[DataController] User data saved to storage and in-memory state updated.');

          // notification service is already initialized in main.dart
          // ... (rest of original logic)
          // Now, fetch feeds
          try {
            // update the fcm token and send to database by calling init
              // print('[DataController] Login successful. Fetching initial feeds...');
            await fetchFeeds(); // Fetches main content feed
              // print('[DataController] Initial feeds fetched successfully after login.');

            // Fetch user's network data (followers/following) for AppDrawer and Network page
            final String? currentUserId = user.value['user']?['_id'];
            if (currentUserId != null && currentUserId.isNotEmpty) {
              // print('[DataController.loginUser] Fetching initial network data for $currentUserId');
              fetchFollowers(currentUserId).catchError((e) {
                // print('Error fetching followers post-login: $e');
              });
              fetchFollowing(currentUserId).catchError((e) {
                // print('Error fetching following post-login: $e');
              });
            }
            Get.find<SocketService>().initSocket();
            await fetchAllUsers();
            await fetchChats();

            // Initialize NotificationService after user data is loaded to ensure token is sent correctly
            final NotificationService notificationService = Get.find<NotificationService>();
            await notificationService.init();

          } catch (feedError) {
              // print('[DataController] Error fetching feeds/network data immediately after login: ${feedError.toString()}. Login itself is still considered successful.');
            // Optionally, you could set a flag here to indicate feeds/network failed to load.
          }

          return {'success': true, 'message': 'User logged in successfully'};
        } catch (e) {
          // This catch is for errors during storage write or updating user.value
            // print('[DataController] Error saving user data or updating state after login: ${e.toString()}');
          return {
            'success': false,
            'message': 'Login partially failed: Could not save user session: ${e.toString()}'
          };
        }
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Login failed'
        };
      }
    } catch (e) {
      // This catch is for network errors or other issues with the login API call itself
        // print('[DataController] Login API call failed: ${e.toString()}');
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  // Method to be called from UI (e.g. home-feed-screen.dart)
  Future<List<Map<String, dynamic>>> uploadFiles(List<Map<String, dynamic>> attachmentsData) async {
    // Reset progress for the upload phase specifically
    // uploadProgress.value = 0.0; // This might be too early if createPost also resets.
                               // HomeFeedScreen should reset before starting the whole process.

    // Define the progress callback for UploadService
    void onUploadProgress(int sentBytes, int totalBytes) {
      if (totalBytes > 0) {
        double overallUploadPhaseProgress = sentBytes / totalBytes;
        // Scale this progress to fit within the _uploadPhaseProportion
        uploadProgress.value = overallUploadPhaseProgress * _uploadPhaseProportion;
      }
    }

    // Delegate the call to the UploadService, passing the callback
    List<Map<String, dynamic>> uploadResults = await _uploadService.uploadFilesToCloudinary(
      attachmentsData,
      onUploadProgress, // Pass the callback here
    );

    // After all files are uploaded (or attempted), if successful,
    // the uploadProgress should reflect the full _uploadPhaseProportion.
    // If there were failures, it might not reach this.
    // Consider if all uploads must succeed to reach _uploadPhaseProportion.
    bool allSuccess = uploadResults.every((result) => result['success'] == true);
    if (allSuccess && attachmentsData.isNotEmpty) {
       // Ensure progress reflects completion of upload phase if all successful
      uploadProgress.value = _uploadPhaseProportion;
    } else if (attachmentsData.isEmpty) {
      // If no attachments, upload phase is skipped, progress should be at _uploadPhaseProportion
      // to allow createPost to take over from there.
      uploadProgress.value = _uploadPhaseProportion;
    }
    // If some uploads failed, uploadProgress will be less than _uploadPhaseProportion.
    // The UI/snackbar logic in HomeFeedScreen will need to handle this (e.g., show error).

    return uploadResults;
  }

  // Add these placeholder methods inside DataController class

  Future<void> fetchChats() async {
    isLoadingChats.value = true;
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await _dio.get(
        'api/chats',
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> chatData = response.data['chats'];
        final blockedUsers = user.value['user']?['blockedUsers'] ?? [];
        for (var chat in chatData) {
          if (chat['type'] == 'dm') {
            final otherParticipant = (chat['participants'] as List).firstWhere(
              (p) => p['_id'] != user.value['user']['_id'],
              orElse: () => null
            );
            if (otherParticipant != null && !blockedUsers.contains(otherParticipant['_id'])) {
              chats[chat['_id']] = chat;
            }
          } else {
            chats[chat['_id']] = chat;
          }
        }
        // After successfully fetching chats, the backend will have already
        // joined the socket to all necessary rooms.
      } else {
        throw Exception('Failed to fetch chats');
      }
    } catch (e) {
        // print('Error fetching chats: $e');
      // Optionally, show a snackbar or some error message to the user
    } finally {
      isLoadingChats.value = false;
    }
  }

  Future<void> fetchMessages(String conversationId) async {
    isLoadingMessages.value = true;
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.get(
        'api/messages/$conversationId',
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> messageData = response.data['messages'];
        final messages = List<Map<String, dynamic>>.from(messageData);
        messages.sort((a, b) => DateTime.parse(a['createdAt']).compareTo(DateTime.parse(b['createdAt'])));
        currentConversationMessages.value = messages;
      } else {
        throw Exception('Failed to fetch messages');
      }
    } catch (e) {
        // print('Error fetching messages: $e');
    } finally {
      isLoadingMessages.value = false;
    }
  }

  
  Future<void> sendChatMessage(Map<String, dynamic> message, String? clientMessageId) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final Map<String, dynamic> messageToSend = Map<String, dynamic>.from(message);
      if (messageToSend['chatId'] != null && (messageToSend['chatId'] as String).isNotEmpty) {
        messageToSend.remove('participants');
      } else {
        // For a new chat, we only need to send the other participant's ID.
        final List<dynamic> participants = messageToSend['participants'];
        final List<String> participantIds = participants
            .map((p) => (p is Map ? p['_id'] : p) as String)
            .toList();
        participantIds.remove(getUserId());
        messageToSend['participants'] = participantIds;
      }

      final response = await _dio.post(
        'api/messages',
        data: messageToSend,
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      print('[DataController.sendChatMessage] Received response: ${response.data}');

      if (response.statusCode == 201 && response.data['success'] == true) {
        final serverMessage = response.data['message'];
        final messageChatId = serverMessage['chatId'] as String?;

        // --- NEW/RESURRECTED CHAT HANDLING ---
        // If the server returns a full 'chat' object, that's the best case.
        if (response.data.containsKey('chat')) {
          print('[DataController.sendChatMessage] Response contains full chat object.');
          final newChat = response.data['chat'];
          final newChatId = newChat['_id'];
          print('[DataController.sendChatMessage] Chat ID is $newChatId. Updating state.');

          chats[newChatId] = newChat;
          currentChat.value = newChat; // This updates the whole object
          activeChatId.value = newChatId;
          chats.refresh();
        }
        // --- FALLBACK for resurrected chats that don't return the full object ---
        else {
          // If our currentChat doesn't have an ID yet, but the returned message does,
          // it means this is the first message of a new/resurrected chat.
          if (messageChatId != null && currentChat.value['_id'] == null) {
            print('[DataController.sendChatMessage] New/resurrected chat detected via message. Chat ID: $messageChatId.');

            // We don't have the full chat object, but we have the ID.
            // Update the currentChat object with the ID.
            var tempChat = Map<String, dynamic>.from(currentChat.value);
            tempChat['_id'] = messageChatId;
            currentChat.value = tempChat;
            activeChatId.value = messageChatId;

            // We should probably add this partial chat to the main chats list too,
            // so it doesn't feel like it's missing. The server will likely send a
            // `chat:updated` event soon to fill in the details.
            if (!chats.containsKey(messageChatId)) {
              chats[messageChatId] = tempChat;
              chats.refresh();
            }
          }
        }

        // --- UPDATE CONVERSATION VIEW ---
        // Only update the current conversation if the new message belongs to it.
        if (activeChatId.value == messageChatId) {
          final messageIndex = clientMessageId != null
            ? currentConversationMessages.indexWhere((m) => m['clientMessageId'] == clientMessageId)
            : -1;

          if (messageIndex != -1) {
            final localMessage = currentConversationMessages[messageIndex];
            var finalMessage = Map<String, dynamic>.from(serverMessage);
            if (clientMessageId != null) {
              finalMessage['clientMessageId'] = clientMessageId;
            }
            if ((localMessage['readReceipts'] as List?)?.isNotEmpty ?? false) {
              finalMessage['readReceipts'] = localMessage['readReceipts'];
            }
            currentConversationMessages[messageIndex] = finalMessage;
          } else {
            currentConversationMessages.add(serverMessage);
          }
        }
      } else {
        final messageIndex = clientMessageId != null
            ? currentConversationMessages.indexWhere((m) => m['clientMessageId'] == clientMessageId)
            : -1;
        if (messageIndex != -1) {
          currentConversationMessages[messageIndex]['status_for_failed_only'] = 'failed';
        }
      }
    } catch (e) {
      if (clientMessageId != null) {
        final messageIndex = currentConversationMessages.indexWhere((m) => m['clientMessageId'] == clientMessageId);
        if (messageIndex != -1) {
          currentConversationMessages[messageIndex]['status_for_failed_only'] = 'failed';
        }
      }
    } finally {
        currentConversationMessages.refresh();
    }
  }

  void markMessageAsRead(Map<String, dynamic> message) {
    final messageId = message['_id'] as String?;
    final chatId = message['chatId'] as String?;
    final currentUserId = getUserId();

    if (messageId == null || chatId == null || currentUserId == null) return;

    final senderId = message['senderId'] is Map ? message['senderId']['_id'] : message['senderId'];
    if (senderId == currentUserId) return;

    final receipts = (message['readReceipts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final alreadyRead = receipts.any((r) => r['userId'] == currentUserId && r['status'] == 'read');
    if (alreadyRead) return;

    _updateMessageStatusOnBackend(messageId, chatId, 'read');
  }

  void addTemporaryMessage(Map<String, dynamic> message) {
    currentConversationMessages.add(message);

    // Optimistically update the last message for the chat
    if (message.containsKey('chatId') && chats.containsKey(message['chatId'])) {
      final chatId = message['chatId'];
      final chat = chats[chatId]!;
      chat['lastMessage'] = message;
      chats[chatId] = chat;
    }
  }

  void updateUploadProgress(String clientMessageId, double progress) {
    final messageIndex = currentConversationMessages.indexWhere((m) => m['clientMessageId'] == clientMessageId);
    if (messageIndex != -1) {
      final message = currentConversationMessages[messageIndex];
      final files = (message['files'] as List).map((file) {
        file['uploadProgress'] = progress;
        return file;
      }).toList();
      message['files'] = files;
      currentConversationMessages[messageIndex] = message;
    }
  }

  void updateMessageStatus(String clientMessageId, String status) {
    final messageIndex = currentConversationMessages.indexWhere((m) => m['clientMessageId'] == clientMessageId);
    if (messageIndex != -1) {
      final message = currentConversationMessages[messageIndex];
      message['status'] = status;
      currentConversationMessages[messageIndex] = message;
    }
  }

  Future<List<Map<String, dynamic>>> uploadChatFiles(
    List<Map<String, dynamic>> attachmentsData,
    Function(int sentBytes, int totalBytes) onProgress,
  ) async {
    return await _uploadService.uploadFilesToCloudinary(attachmentsData, onProgress);
  }

  Future<void> editChatMessage(String messageId, String newText) async {
    // print('[DataController] Editing message $messageId');
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.patch(
        'api/messages/$messageId',
        data: {'content': newText},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        // print('[DataController] Edited message $messageId successfully');
        // The API documentation states the updated message object is returned.
        // Assuming the key is 'message' based on other similar responses.
        final updatedMessage = response.data['message'];
        final index = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
        if (index != -1) {
          currentConversationMessages[index] = updatedMessage;
        }
      } else {
        // print('[DataController] Failed to edit message $messageId: ${response.data?['message']}');
        throw Exception('Failed to edit message: ${response.data?['message']}');
      }
    } catch (e) {
      // print('[DataController] Error editing message $messageId: $e');
    }
  }

  Future<void> deleteChatMessage(String messageId, {bool forEveryone = false}) async {
    // print('[DataController] Deleting message $messageId with forEveryone=$forEveryone');
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.delete(
        'api/messages/$messageId',
        queryParameters: forEveryone ? {'for': 'everyone'} : null,
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // print('[DataController] API call to delete message $messageId successful.');

        // UI update for the user who performed the action.
        // We use the `forEveryone` parameter for an immediate optimistic update,
        // rather than waiting for the socket event or relying on the API response body.
        final index = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
        if (index != -1) {
          if (forEveryone) {
            // For "Delete for everyone", show a tombstone message.
            var message = Map<String, dynamic>.from(currentConversationMessages[index]);
            message['deletedForEveryone'] = true;
            message['content'] = ''; // Clear content
            message['files'] = []; // Clear files
            currentConversationMessages[index] = message;
          } else {
            // For "Delete for me", just remove it from the local list.
            currentConversationMessages.removeAt(index);
          }
        }
      } else {
        // print('[DataController] Failed to delete message $messageId on the server.');
        throw Exception('Failed to delete message on the server');
      }
    } catch (e) {
      // print('[DataController] Error deleting message $messageId: $e');
    }
  }

  Future<Map<String, dynamic>> deleteChat(String chatId) async {
    // print('[DataController] Deleting chat $chatId');
    try {
      String? token = user.value['token'];
      if (token == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.delete(
        'api/chats/$chatId',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // print('[DataController] Deleted chat $chatId successfully');
        // The chat will be removed from the list via the socket event `chat:hardDeleted`.
        // So no need to remove it here optimistically, to avoid race conditions.
        return {'success': true, 'message': response.data['message'] ?? 'Chat deleted successfully'};
      } else {
        // print('[DataController] Failed to delete chat $chatId: ${response.data['message']}');
        return {'success': false, 'message': response.data['message'] ?? 'Failed to delete chat'};
      }
    } catch (e) {
      // print('[DataController] Error deleting chat $chatId: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  void handleChatDeleted(String chatId) {
    print('[DataController] handleChatDeleted called for chatId: $chatId');
    if (chatId.isEmpty) {
      print('[DataController] ChatId is empty, returning.');
      return;
    }

    print('[DataController] Chats count before deletion attempt: ${chats.length}');
    if (chats.containsKey(chatId)) {
      print('[DataController] Chat found in map. Proceeding with removal.');
      final newChats = Map<String, Map<String, dynamic>>.from(chats);
      newChats.remove(chatId);
      chats.value = newChats; // Forcefully replace the map to ensure reactivity
      print('[DataController] Chats count after deletion attempt: ${chats.length}');


      // If the deleted chat is the current one, clear it.
      // The UI (ChatScreen) will be responsible for listening to this state change and popping itself.
      if (currentChat.value['_id'] == chatId) {
        print('[DataController] Deleted chat is the current chat. Clearing state.');
        currentChat.value = {};
        currentConversationMessages.clear();
      }
    } else {
      print('[DataController] Chat with ID $chatId not found in the local chats map.');
    }
  }

  void handleChatsDeletedForMe(List<String> chatIds) {
    // This event confirms that the chats were successfully deleted on the server
    // for the current user. Since we already optimistically removed them from the UI,
    // we don't need to do anything here other than maybe log it for debugging.
    // If the API call in `deleteMultipleChats` had failed, the UI would have already been reverted.
    print('[DataController] Received confirmation for soft deletion of chats: $chatIds');
  }

  void handleChatAvatarUpdated(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    final avatarUrl = data['avatarUrl'] as String?;
    if (chatId == null || avatarUrl == null) return;

    if (chats.containsKey(chatId)) {
      final chat = chats[chatId]!;
      chat['groupAvatar'] = avatarUrl;
      chats[chatId] = chat;
      if (currentChat.value['_id'] == chatId) {
        currentChat.value = Map<String, dynamic>.from(chat);
      }
      chats.refresh();
    }
  }

  void handleGroupRemovedFrom(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    if (chatId == null) return;

    if (chats.containsKey(chatId)) {
      final newChats = Map<String, Map<String, dynamic>>.from(chats);
      newChats.remove(chatId);
      chats.value = newChats;

      if (currentChat.value['_id'] == chatId) {
        currentChat.value = {};
        currentConversationMessages.clear();
      }
    }
  }

  void handleMemberJoined(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    final newMember = data['member'] as Map<String, dynamic>?;

    if (chatId == null || newMember == null || !chats.containsKey(chatId)) return;

    final chat = chats[chatId]!;
    final participants = List<Map<String, dynamic>>.from(chat['participants'] ?? []);

    // Remove existing entry if any, then add the new one to ensure data is fresh
    participants.removeWhere((p) => p['_id'] == newMember['_id']);
    participants.add(newMember);
    chat['participants'] = participants;

    if (currentChat.value['_id'] == chatId) {
      currentChat.value = Map<String, dynamic>.from(chat);
    }
    chats.refresh();
  }

  void handleMemberRemoved(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    final memberId = data['memberId'] as String?;

    if (chatId == null || memberId == null || !chats.containsKey(chatId)) return;

    if (memberId == getUserId()) {
      handleGroupRemovedFrom(data);
      return;
    }

    final chat = chats[chatId]!;
    final participants = List<Map<String, dynamic>>.from(chat['participants'] ?? []);
    participants.removeWhere((p) => p['_id'] == memberId);
    chat['participants'] = participants;

    if (currentChat.value['_id'] == chatId) {
      currentChat.value = Map<String, dynamic>.from(chat);
    }
    chats.refresh();
  }

  void handleMemberPromoted(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    final memberId = data['memberId'] as String?;

    if (chatId == null || memberId == null || !chats.containsKey(chatId)) return;

    final chat = chats[chatId]!;
    final participants = List<Map<String, dynamic>>.from(chat['participants'] ?? []);
    final memberIndex = participants.indexWhere((p) => p['_id'] == memberId);

    if (memberIndex != -1) {
      participants[memberIndex]['rank'] = 'admin';
      chat['participants'] = participants;
      if (currentChat.value['_id'] == chatId) {
        currentChat.value = Map<String, dynamic>.from(chat);
      }
      chats.refresh();
    }
  }

  void handleMemberDemoted(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    final memberId = data['memberId'] as String?;

    if (chatId == null || memberId == null || !chats.containsKey(chatId)) return;

    final chat = chats[chatId]!;
    final participants = List<Map<String, dynamic>>.from(chat['participants'] ?? []);
    final memberIndex = participants.indexWhere((p) => p['_id'] == memberId);

    if (memberIndex != -1) {
      participants[memberIndex]['rank'] = 'member';
      chat['participants'] = participants;
      if (currentChat.value['_id'] == chatId) {
        currentChat.value = Map<String, dynamic>.from(chat);
      }
      chats.refresh();
    }
  }

  void handleMemberMuted(Map<String, dynamic> data) {
    print('[LOG] handleMemberMuted received: $data');
    final chatId = data['chatId'] as String?;
    final userId = data['userId'] as String?; // Corrected from memberId to userId
    if (chatId == null || userId == null || !chats.containsKey(chatId)) return;

    // Create a new map from the existing chat to ensure immutability
    final chat = Map<String, dynamic>.from(chats[chatId]!);
    final participants = List<Map<String, dynamic>>.from(chat['participants'] ?? []);
    final memberIndex = participants.indexWhere((p) => p['_id'] == userId);

    if (memberIndex != -1) {
      // Create a new map for the participant being updated
      var updatedParticipant = Map<String, dynamic>.from(participants[memberIndex]);
      updatedParticipant['isMuted'] = true;
      participants[memberIndex] = updatedParticipant;

      // Assign the new list to the new chat map
      chat['participants'] = participants;

      // Update the main chats list and the current chat if it's active
      chats[chatId] = chat;
      if (activeChatId.value == chatId) {
        currentChat.value = chat;
      }
      chats.refresh();
    }
  }

  void handleMemberUnmuted(Map<String, dynamic> data) {
    print('[LOG] handleMemberUnmuted received: $data');
    final chatId = data['chatId'] as String?;
    final userId = data['userId'] as String?; // Corrected from memberId to userId
    if (chatId == null || userId == null || !chats.containsKey(chatId)) return;

    // Create a new map from the existing chat to ensure immutability
    final chat = Map<String, dynamic>.from(chats[chatId]!);
    final participants = List<Map<String, dynamic>>.from(chat['participants'] ?? []);
    final memberIndex = participants.indexWhere((p) => p['_id'] == userId);

    if (memberIndex != -1) {
      // Create a new map for the participant being updated
      var updatedParticipant = Map<String, dynamic>.from(participants[memberIndex]);
      updatedParticipant['isMuted'] = false;
      participants[memberIndex] = updatedParticipant;

      // Assign the new list to the new chat map
      chat['participants'] = participants;

      // Update the main chats list and the current chat if it's active
      chats[chatId] = chat;
      if (activeChatId.value == chatId) {
        currentChat.value = chat;
      }
      chats.refresh();
    }
  }

  // --- Attachment Download Logic ---

  void _updateMessageAttachment(String messageId, String attachmentId, Map<String, dynamic> updates) {
    final mIndex = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (mIndex != -1) {
      final messageToUpdate = Map<String, dynamic>.from(currentConversationMessages[mIndex]);
      final attachments = List<Map<String, dynamic>>.from(messageToUpdate['attachments'] as List);
      final aIndex = attachments.indexWhere((a) => a['_id'] == attachmentId);
      if (aIndex != -1) {
        final attachmentToUpdate = Map<String, dynamic>.from(attachments[aIndex]);
        updates.forEach((key, value) {
          attachmentToUpdate[key] = value;
        });
        attachments[aIndex] = attachmentToUpdate;
        messageToUpdate['attachments'] = attachments;
        currentConversationMessages[mIndex] = messageToUpdate;
      }
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String filename) async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  Future<void> handleFileAttachmentTap(String messageId, String attachmentId) async {
    final messageIndex = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (messageIndex == -1) return;

    final message = currentConversationMessages[messageIndex];
    final attachmentIndex = (message['attachments'] as List).indexWhere((a) => a['_id'] == attachmentId);
    if (attachmentIndex == -1) return;

    final attachment = (message['attachments'] as List)[attachmentIndex];
    final file = await _localFile(attachment['filename']);

    if (await file.exists()) {
        // print('File already downloaded at: ${file.path}');
      // On a real device, you might want to use a package like `open_file`
      // to open the file, but for now, we just log the path.
    } else {
      downloadAttachment(messageId, attachmentId);
    }
  }

  Future<void> downloadAttachment(String messageId, String attachmentId) async {
    final messageIndex = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (messageIndex == -1) return;
    final message = currentConversationMessages[messageIndex];
    final attachmentIndex = (message['attachments'] as List).indexWhere((a) => a['_id'] == attachmentId);
    if (attachmentIndex == -1) return;
    final attachment = (message['attachments'] as List)[attachmentIndex];

    _updateMessageAttachment(messageId, attachmentId, {'isDownloading': true, 'downloadProgress': 0.0});

    try {
      final file = await _localFile(attachment['filename']);
      await _dio.download(
        attachment['url'],
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _updateMessageAttachment(messageId, attachmentId, {'downloadProgress': progress});
          }
        },
      );

      _updateMessageAttachment(messageId, attachmentId, {'isDownloading': false, 'downloadProgress': 1.0});

    } catch (e) {
        // print('Error downloading file: $e');
      _updateMessageAttachment(messageId, attachmentId, {'isDownloading': false});
    }
  }

  // Add these placeholder methods inside DataController class

  Future<void> fetchFollowers(String userId, {bool isRefresh = false}) async {
    if (_isFetchingFollowers.value) return;
    _isFetchingFollowers.value = true;
    isLoadingFollowers.value = true;

    if (isRefresh) {
      _currentFollowersPage.value = 1;
      _hasMoreFollowers.value = true;
      followers.clear();
    }

    if (!_hasMoreFollowers.value) {
      _isFetchingFollowers.value = false;
      isLoadingFollowers.value = false;
      return;
    }

    try {
      final String? token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated. Cannot fetch followers.');
      }

      final response = await _dio.get(
        'api/users/get-followers/$userId?page=${_currentFollowersPage.value}&limit=1000',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['followers'] != null && response.data['followers'] is List) {
          List<dynamic> fetchedFollowersDynamic = response.data['followers'];
          if (fetchedFollowersDynamic.isNotEmpty) {
            final List<String> loggedInUserFollowingIds = List<String>.from(
              (user.value['user']?['following'] as List<dynamic>? ?? []).map((e) => e.toString())
            );

            List<Map<String, dynamic>> processedFollowers = fetchedFollowersDynamic.map((followerData) {
              if (followerData is Map<String, dynamic>) {
                String followerId = followerData['_id']?.toString() ?? '';
                bool isFollowingThisFollower = loggedInUserFollowingIds.contains(followerId);
                return {
                  '_id': followerId,
                  'avatar': followerData['avatar']?.toString() ?? '',
                  'username': followerData['name']!.toString(),
                  'name': followerData['name']?.toString() ?? 'Unknown User',
                  'isFollowingCurrentUser': isFollowingThisFollower,
                  'followersCount': followerData['followersCount'] ?? 0,
                  'followingCount': followerData['followingCount'] ?? 0,
                };
              }
              return <String, dynamic>{};
            }).where((userMap) => userMap.isNotEmpty).toList();

            followers.addAll(processedFollowers);
            _currentFollowersPage.value++;
          } else {
            _hasMoreFollowers.value = false;
          }
        } else {
          _hasMoreFollowers.value = false;
        }
      } else {
        throw Exception('Failed to fetch followers: ${response.data?['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
      //   // print('[DataController] Error in fetchFollowers for user $userId: ${e.toString()}');
    } finally {
      isLoadingFollowers.value = false;
      _isFetchingFollowers.value = false;
    }
  }

  

  Future<void> fetchFollowing(String userId, {bool isRefresh = false}) async {
    if (_isFetchingFollowing.value) return;
    _isFetchingFollowing.value = true;
    isLoadingFollowing.value = true;

    if (isRefresh) {
      _currentFollowingPage.value = 1;
      _hasMoreFollowing.value = true;
      following.clear();
    }

    if (!_hasMoreFollowing.value) {
      _isFetchingFollowing.value = false;
      isLoadingFollowing.value = false;
      return;
    }

    try {
      final String? token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated. Cannot fetch following list.');
      }

      final response = await _dio.get(
        'api/users/get-following/$userId?page=${_currentFollowingPage.value}&limit=100',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['following'] != null && response.data['following'] is List) {
          List<dynamic> fetchedFollowingDynamic = response.data['following'];
          if (fetchedFollowingDynamic.isNotEmpty) {
            final List<String> loggedInUserFollowingIds = List<String>.from(
              (user.value['user']?['following'] as List<dynamic>? ?? []).map((e) => e.toString())
            );

            List<Map<String, dynamic>> processedFollowing = fetchedFollowingDynamic.map((followingUserData) {
              if (followingUserData is Map<String, dynamic>) {
                String followingUserId = followingUserData['_id']?.toString() ?? '';
                bool isFollowingThisUser = loggedInUserFollowingIds.contains(followingUserId);
                return {
                  '_id': followingUserId,
                  'avatar': followingUserData['avatar']?.toString() ?? '',
                  'username': followingUserData['name']?.toString() ?? 'N/A',
                  'name': followingUserData['name']?.toString() ?? 'Unknown User',
                  'isFollowingCurrentUser': isFollowingThisUser,
                  'followersCount': followingUserData['followersCount'] ?? 0,
                  'followingCount': followingUserData['followingCount'] ?? 0,
                };
              }
              return <String, dynamic>{};
            }).where((userMap) => userMap.isNotEmpty).toList();

            following.addAll(processedFollowing);
            _currentFollowingPage.value++;
          } else {
            _hasMoreFollowing.value = false;
          }
        } else {
          _hasMoreFollowing.value = false;
        }
      } else {
        throw Exception('Failed to fetch following list: ${response.data?['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
        // print('[DataController] Error in fetchFollowing for user $userId: ${e.toString()}');
    } finally {
      isLoadingFollowing.value = false;
      _isFetchingFollowing.value = false;
    }
  }

  // Placeholder for toggling follow status
  void toggleFollowStatus(String currentUserId, String targetUserId, bool follow) {
    // This is a placeholder. In a real app:
    // 1. Make an API call to follow/unfollow the user.
    // 2. On success, update the local lists (`followers`, `following`) if necessary.
    //    - If `follow` is true, you might add to `following`.
    //    - If `follow` is false, you might remove from `following`.
    //    - The `isFollowing` status on items in `followers` or search results might also need updating.

    // Simple update for placeholder UI:
    // Update 'following' list
    int followingIndex = following.indexWhere((u) => u['id'] == targetUserId);
    if (follow) {
      if (followingIndex == -1) { // Not already following, add them (basic placeholder)
        following.add({
          'id': targetUserId,
          'username': 'User_$targetUserId', // Placeholder username
          'name': '',
          'avatar': 'https://i.pravatar.cc/150?u=$targetUserId',
          'isFollowing': true
        });
      } else { // Already in list, ensure status is true
          following[followingIndex]['isFollowing'] = true;
      }
    } else {
      if (followingIndex != -1) { // If unfollowing someone you were following
        following.removeAt(followingIndex);
      }
    }
    following.refresh();


    // Update 'isFollowing' status in the followers list if the user is there
    int followerIndex = followers.indexWhere((u) => u['id'] == targetUserId);
    if (followerIndex != -1) {
      followers[followerIndex]['isFollowing'] = follow;
      followers.refresh();
    }

    // Also update in allUsers list if it's being displayed elsewhere with follow buttons
    int allUsersIndex = allUsers.indexWhere((u) => u['id'] == targetUserId);
      if (allUsersIndex != -1) {
      allUsers[allUsersIndex]['isFollowing'] = follow;
      allUsers.refresh();
    }

      // print('[DataController] Toggled follow status for $targetUserId to $follow (placeholder).');
  }

  // Add this method to the DataController class
  // some test changes

  void addUserToAllUsers(Map<String, dynamic> user) {
    if (allUsers.any((u) => u['_id'] == user['_id'])) {
      return;
    }
    allUsers.add(user);
  }

  Future<void> logoutUser() async {
    try {
      // 1. Clear data from FlutterSecureStorage
      await _storage.delete(key: 'token');
      await _storage.delete(key: 'user');
        // print('[DataController] Token and user data deleted from secure storage.');

      // 2. Reset reactive variables to initial states
      user.value = {};
      posts.clear();
      allUsers.clear(); // If you want to clear this list on logout
      chats.clear();
      currentConversationMessages.clear();
      followers.clear();
      following.clear();
        // print('[DataController] In-memory user state cleared.');

      // 3. Optionally, disconnect other services
      // Example: If SocketService is managed or accessible here
      // final SocketService socketService = Get.find<SocketService>();
      // socketService.disconnect();
      //   // print('[DataController] SocketService disconnected.');
      // Note: Ensure SocketService handles multiple disconnect calls gracefully if also called in app dispose.

      // Any other cleanup specific to your application's state
      isLoading.value = false;
      isLoadingChats.value = false;
      isLoadingMessages.value = false;
      isLoadingFollowers.value = false;
      isLoadingFollowing.value = false;

    } catch (e) {
        // print('[DataController] Error during logout: ${e.toString()}');
      // Even if an error occurs, try to clear in-memory data as a fallback
      user.value = {};
      posts.clear();
      allUsers.clear();
      chats.clear();
      currentConversationMessages.clear();
      followers.clear();
      following.clear();
      // Potentially rethrow or handle error in a way that UI can respond if needed
    }
  }

  // Add this method to the DataController class

  Future<Map<String, dynamic>> updateUserAvatar(String avatarUrl) async {
    isLoading.value = true; // Optional: indicate loading state
    try {
        // print(user.value['user']['_id']);
        // print(user.value['token']);
      final String? currentUserId = user.value['user']['_id']?.toString();
      final String? token = user.value['token']?.toString();

      if (currentUserId == null || token == null) {
        isLoading.value = false;
        return {'success': false, 'message': 'User ID or token not found. Please log in again.'};
      }

      final response = await _dio.post(
        '/api/users/avatar', // Using the endpoint provided by the user
        data: {
          'userid': currentUserId,
          'avatarUrl': avatarUrl,
        },
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      isLoading.value = false;

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Backend confirms success, might return the new avatarUrl or just confirm
        String returnedAvatarUrl = response.data['avatarUrl'] ?? avatarUrl; // Use returned URL if available

        // Update local user state
        // Create a deep copy to ensure nested map 'user' is also new
        var updatedUserData = Map<String, dynamic>.from(user.value);
        if (updatedUserData['user'] is Map) {
          // Ensure 'user' key exists and is a map
          var nestedUserMap = Map<String, dynamic>.from(updatedUserData['user'] as Map);
          nestedUserMap['avatar'] = returnedAvatarUrl;
          updatedUserData['user'] = nestedUserMap;

          user.value = updatedUserData; // Update reactive user object
          user.refresh(); // Explicitly call refresh if nested changes aren't automatically picked up by all listeners

          // Save updated user object to secure storage
          await _storage.write(key: 'user', value: jsonEncode(updatedUserData));
        } else {
          // Handle case where 'user' map might not exist or is not a map (should not happen in normal flow)
            // print('[DataController] Error: User data structure is not as expected. Cannot update avatar in nested map.');
          // Potentially return an error or don't update if structure is broken
        }

          // print('[DataController] Avatar updated successfully on backend and locally. New URL: $returnedAvatarUrl');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Avatar updated successfully!',
          'avatarUrl': returnedAvatarUrl
        };
      } else {
          // print('[DataController] Backend failed to update avatar. Status: ${response.statusCode}, Message: ${response.data['message']}');
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to update avatar on backend.'
        };
      }
    } catch (e) {
      isLoading.value = false;
        // print('[DataController] Error in updateUserAvatar: ${e.toString()}');
      return {'success': false, 'message': 'An error occurred: ${e.toString()}'};
    }
  }

  void mediaDidStartPlaying(String mediaId, String mediaType, Object controller) {
    if (currentlyPlayingMediaId.value != mediaId || currentlyPlayingMediaType.value != mediaType) {
      // If another media is playing, we might need to stop it here or ensure it's stopped by its own listener.
      // For now, this method just sets the new active media.
      // The widgets themselves should pause if currentlyPlayingMediaId changes to something else.
      currentlyPlayingMediaId.value = mediaId;
      currentlyPlayingMediaType.value = mediaType;
      activeMediaController.value = controller;
        // print("[DataController] Media $mediaId (type: $mediaType) started playing. Setting global lock.");
    }
  }

  void mediaDidStopPlaying(String mediaId, String mediaType) {
    if (currentlyPlayingMediaId.value == mediaId && currentlyPlayingMediaType.value == mediaType) {
      currentlyPlayingMediaId.value = null;
      currentlyPlayingMediaType.value = null;
      activeMediaController.value = null;
        // print("[DataController] Media $mediaId (type: $mediaType) stopped playing. Releasing global lock.");
    }
  }

  void pauseCurrentMedia() {
    if (activeMediaController.value == null) {
      return;
    }

    final controller = activeMediaController.value;

    try {
      if (controller is BetterPlayerController) {
        controller.pause();
      } else if (controller is VideoPlayerController) {
        // VideoPlayerController does not have an isDisposed getter, so we rely on the try-catch.
        controller.pause();
      } else if (controller is AudioPlayer) {
        // AudioPlayer does not have an isDisposed getter, rely on try-catch.
        controller.pause();
      }
    } catch (e) {
      // print('[DataController] Error pausing media, likely because it was already disposed: $e');
      // It's safe to ignore this error as the goal was to stop the media anyway.
    }
  }

  // Method to update a post in the local list with data from a socket event (e.g. like, unlike, view)
  void updatePostFromSocket(Map<String, dynamic> updatedPostData) {
    String? eventPostId = updatedPostData['_id'] as String?;
    if (eventPostId == null) {
      eventPostId = updatedPostData['postId'] as String?; // Check for 'postId'
    }

    if (eventPostId == null) {
        // print('[DataController] updatePostFromSocket: Received post data without a usable ID (_id or postId). Cannot update. Data: $updatedPostData');
      return;
    }

    final String finalPostId = eventPostId; // Use a final variable for safety in closures/loops

    try {
      // Process the incoming updatedPostData to ensure its nested replies (if any) are also processed.
      Map<String, dynamic> fullyProcessedUpdatedPost = _processPostOrReply(Map<String, dynamic>.from(updatedPostData));

      int postIndex = posts.indexWhere((p) => p['_id'] == finalPostId);
      if (postIndex != -1) {
        // Replace the existing post with the fully processed new version.
        // This is simpler and more robust than trying to merge field by field,
        // especially with nested structures.
        posts[postIndex] = fullyProcessedUpdatedPost;
        posts.refresh();
        //   // print('[DataController] Post $finalPostId updated from socket event. New data: $fullyProcessedUpdatedPost');
      } else {
        // This is a new post not seen before.
          // print('[DataController] updatePostFromSocket: Post with ID $finalPostId not found. Assuming new post and adding.');

        // The fullyProcessedUpdatedPost is already processed, so it can be added directly.
        // Ensure its ID is correctly set if it was derived from 'postId'.
        if (fullyProcessedUpdatedPost['_id'] == null && updatedPostData['postId'] == finalPostId) {
            fullyProcessedUpdatedPost['_id'] = finalPostId;
        } else if (fullyProcessedUpdatedPost['_id'] != finalPostId && finalPostId != null) {
            // If finalPostId is derived and differs, prioritize finalPostId if not null.
            // This case should be rare if backend is consistent.
            fullyProcessedUpdatedPost['_id'] = finalPostId;
        }

        addNewPost(fullyProcessedUpdatedPost); // addNewPost also handles duplicates and inserts at 0
      }
    } catch (e) {
        // print('[DataController] Error updating post $finalPostId from socket: $e. Data: $updatedPostData'); // Used finalPostId
    }
  }

  // The old updatePostViews method is now removed.
  // View updates are handled by the postViewed socket event triggering fetchSinglePost,
  // which then calls updatePostFromSocket with the full, authoritative post data.

  void handleNewReply(String parentPostId, Map<String, dynamic> replyDocument) {
    try {
      int postIndex = posts.indexWhere((p) => p['_id'] == parentPostId);
      if (postIndex != -1) {
        Map<String, dynamic> postToUpdate = Map<String, dynamic>.from(posts[postIndex]);

        // Ensure 'replies' list exists and is mutable
        List<dynamic> repliesList = List<dynamic>.from(postToUpdate['replies'] ?? []);

        // Add the new reply
        // Process the new reply using the main helper to ensure all nested fields and counts are correct
        Map<String, dynamic> processedNewReply = _processPostOrReply(Map<String, dynamic>.from(replyDocument));

        repliesList.add(processedNewReply);
        postToUpdate['replies'] = repliesList;

        // Update replyCount for the parent post
        postToUpdate['replyCount'] = repliesList.length;

        posts[postIndex] = postToUpdate;
        posts.refresh();
          // print('[DataController] New reply added to post $parentPostId. Post updated.');
      } else {
          // print('[DataController] handleNewReply: Parent post with ID $parentPostId not found.');
        // Optionally, fetch the post if it's critical that it should exist
        // fetchSinglePost(parentPostId);
      }
    } catch (e) {
        // print('[DataController] Error handling new reply for post $parentPostId: $e');
    }
  }

  // Existing video transition methods - might need review if they conflict or overlap
  // For now, videoDidStartPlaying and videoDidStopPlaying are effectively replaced by the generic media methods.
  // Keeping these stubs in case any part of the code still calls them directly,
  // but they should ideally be refactored to call the new media methods.

  void videoDidStartPlaying(String videoId) {
    // This method is now largely superseded by mediaDidStartPlaying.
    // If called, ensure it correctly interfaces with the new media state.
    // For simplicity, we can delegate or log a warning.
      // print("[DataController] Legacy videoDidStartPlaying called for $videoId. Consider updating call site to mediaDidStartPlaying.");
    // Example: find the controller if this videoId is active and call mediaDidStartPlaying
    // This requires knowing the controller instance which isn't passed here.
    // A safer approach might be to ensure all video players call mediaDidStartPlaying directly.
    // For now, let's assume video players will be updated to call mediaDidStartPlaying.
    // If this videoId matches the current active video media, do nothing as it's already handled.
    if (currentlyPlayingMediaId.value == videoId && currentlyPlayingMediaType.value == 'video') {
      return;
    }
    // If no media is playing, or a different media is playing, this call is ambiguous without controller.
    // It might be best to let the video player itself manage this via mediaDidStartPlaying.
  }

  void videoDidStopPlaying(String videoId) {
    // Similar to videoDidStartPlaying, this is superseded.
      // print("[DataController] Legacy videoDidStopPlaying called for $videoId. Consider updating call site to mediaDidStopPlaying.");
    if (currentlyPlayingMediaId.value == videoId && currentlyPlayingMediaType.value == 'video') {
      mediaDidStopPlaying(videoId, 'video');
    }
  }

  // --- Methods for Reply Interactions ---

  Future<Map<String, dynamic>> replyToReply(Map<String, dynamic> data) async {
    // data expected to contain: postId, parentReplyId, content, attachments
    try {
      String? token = user.value['token'];
      String? currentUserId = user.value['user']?['_id'];

      if (token == null || currentUserId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.post(
        'api/posts/reply-to-reply', // Endpoint as per user request
        data: {
          'userId': currentUserId,
          'postId': data['postId'], // ID of the original top-level post
          'parentReplyId': data['parentReplyId'], // ID of the reply being replied to
          'content': data['content'],
          'attachments': data['attachments'] ?? [],
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // The backend might return the new reply, or the updated parent reply, or the updated main post.
        // For now, assume it returns the new reply object.
        // UI will likely need to re-fetch replies for the parent post or parent reply to show the new one.
          // print('[DataController] Reply to reply successful: ${response.data}');
        // TODO: Determine how to update local state. Might need to fetch parent post's replies again.
        // For now, just returning success and the new reply if available.
        return {
          'success': true,
          'message': response.data['message'] ?? 'Reply posted successfully',
          'reply': response.data['reply'] // Assuming the new reply is returned
        };
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to post reply to reply'};
      }
    } catch (e) {
        // print('[DataController] Error in replyToReply: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> likeReply(String postId, String replyId) async {
    try {
      String? token = user.value['token'];
      String? currentUserId = user.value['user']?['_id'];

      if (token == null || currentUserId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.post(
        'api/posts/like-reply', // Endpoint as per user request
        data: {
          'userId': currentUserId,
          'postId': postId, // ID of the original top-level post
          'replyId': replyId, // ID of the reply being liked
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Fetch the full root post to ensure data consistency for the entire thread
        await fetchSinglePost(postId); // postId here is the root post ID
        //   // print('[DataController] Like reply successful, root post $postId fetched: ${response.data}');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Reply liked successfully',
          // 'updatedReply' might still be useful for immediate UI feedback if the caller wants it,
          // but the authoritative state comes from fetchSinglePost.
          'likesCount': response.data['likesCount']
        };
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to like reply'};
      }
    } catch (e) {
        // print('[DataController] Error in likeReply: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> unlikeReply(String postId, String replyId) async {
    try {
      String? token = user.value['token'];
      String? currentUserId = user.value['user']?['_id'];

      if (token == null || currentUserId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.post(
        'api/posts/unlike-reply', // Endpoint as per user request
        data: {
          'userId': currentUserId,
          'postId': postId,
          'replyId': replyId,
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Fetch the full root post to ensure data consistency for the entire thread
        await fetchSinglePost(postId); // postId here is the root post ID
        //   // print('[DataController] Unlike reply successful, root post $postId fetched: ${response.data}');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Reply unliked successfully',
          'likesCount': response.data['likesCount']
        };
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to unlike reply'};
      }
    } catch (e) {
        // print('[DataController] Error in unlikeReply: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> viewReply(String postId, String replyId) async {
    // Note: View tracking for individual replies might be complex if not aggregated at the main post level.
    // The impact on UI (e.g., displaying view counts for each reply) should be considered.
    try {
      String? token = user.value['token'];
      String? currentUserId = user.value['user']?['_id'];

      if (token == null || currentUserId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }
      // Consider if a separate _pendingViewRegistrations set is needed for replies
      // or if the existing one can be used with a composite key (e.g., "reply-$replyId").
      // For now, not implementing pending registration for reply views to keep it simple.

      var response = await _dio.post(
        'api/posts/view-reply', // Endpoint as per user request
        data: {
          'userId': currentUserId,
          'postId': postId,
          'replyId': replyId,
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        //   // print('[DataController] View reply successful: ${response.data}');
        // Socket event 'replyViewed' or similar would ideally update counts if displayed.
        return {'success': true, 'message': response.data['message'] ?? 'Reply viewed successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to view reply'};
      }
    } catch (e) {
        // print('[DataController] Error in viewReply: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> repostReply(String postId, String replyId) async {
    try {
      String? token = user.value['token'];
      String? currentUserId = user.value['user']?['_id'];

      if (token == null || currentUserId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      var response = await _dio.post(
        'api/posts/repost-reply', // Endpoint as per user request
        data: {
          'userId': currentUserId,
          'postId': postId, // ID of the original top-level post
          'replyId': replyId, // ID of the reply being reposted
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Fetch the full root post to ensure data consistency for the entire thread
        await fetchSinglePost(postId); // postId here is the root post ID
        //   // print('[DataController] Repost reply successful, root post $postId fetched: ${response.data}');
        // If reposting a reply creates a new top-level post for the reposter,
        // that new post should arrive via a 'newPost' socket event or be handled by a subsequent feed refresh.
        // The primary goal here is to update the state of the original thread.
        return {
          'success': true,
          'message': response.data['message'] ?? 'Reply reposted successfully',
          'repostsCount': response.data['repostsCount']
        };
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to repost reply'};
      }
    } catch (e) {
        // print('[DataController] Error in repostReply: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fetch replies for a specific reply (children of a reply)
  Future<List<Map<String, dynamic>>> fetchRepliesForReply(String originalPostId, String parentReplyId) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User token not found. Please log in.');
      }

      // As per user prompt: route - posts/fetch-replies-for-reply(post) - data (postId, replyId)
      // Assuming "post" in "posts/fetch-replies-for-reply(post)" implies a POST request.
      final response = await _dio.post( // Changed to POST
        'api/posts/fetch-replies-for-reply',
        data: {
          'postId': originalPostId, // ID of the original top-level post
          'replyId': parentReplyId,  // ID of the reply whose children are being fetched
        },
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        //   // print("[DataController] Raw replies data from API for parent reply $parentReplyId: ${response.data}");
        final List<dynamic> repliesData = response.data['replies'] ?? []; // Default to empty list if null
        List<Map<String, dynamic>> processedReplies = [];

        for (var replyData in repliesData) {
          if (replyData == null || replyData is! Map<String,dynamic>) {
            //   // print("[DataController] Skipping invalid reply data item for parent reply $parentReplyId: $replyData");
            continue;
          }
          Map<String,dynamic> currentReply = Map<String,dynamic>.from(replyData);

          // Re-use the processing logic from fetchReplies, perhaps by extracting it to a helper
          // For now, duplicating the processing logic:
          List<Map<String, dynamic>> attachments = [];
          if (currentReply['attachments'] != null && currentReply['attachments'] is List) {
            for (var attData in (currentReply['attachments'] as List<dynamic>)) {
              if (attData is Map<String, dynamic>) {
                attachments.add({
                  'type': attData['type']?.toString() ?? 'unknown',
                  'url': attData['url']?.toString() ?? '',
                  'filename': attData['filename']?.toString() ?? '',
                  'size': (attData['size'] is num ? attData['size'] : int.tryParse(attData['size']?.toString() ?? '0'))?.toInt() ?? 0,
                  'thumbnailUrl': attData['thumbnailUrl']?.toString(),
                });
              }
            }
          }

          String username = currentReply['username']?.toString() ?? 'Unknown User';
          String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';
          if (currentReply['avatarInitial'] != null && currentReply['avatarInitial'].toString().isNotEmpty) {
            avatarInitial = currentReply['avatarInitial'].toString();
          }
          String textContent = currentReply['content']?.toString() ?? '';
          final bufferData = currentReply['buffer'];

          // Add count derivations
          currentReply['likesCount'] = (currentReply['likes'] as List?)?.length ?? 0;
          currentReply['repostsCount'] = (currentReply['reposts'] as List?)?.length ?? 0;
          currentReply['viewsCount'] = (currentReply['views'] as List?)?.length ?? 0;
          currentReply['repliesCount'] = (currentReply['replies'] as List?)?.length ?? 0;


          processedReplies.add({
            '_id': currentReply['_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'username': username,
            'content': textContent,
            'buffer': bufferData,
            'createdAt': currentReply['createdAt'],
            'likes': List<dynamic>.from(currentReply['likes'] ?? []),
            'reposts': List<dynamic>.from(currentReply['reposts'] ?? []),
            'views': List<dynamic>.from(currentReply['views'] ?? []),
            'attachments': attachments,
            'avatarInitial': avatarInitial,
            'useravatar': currentReply['useravatar']?.toString(),
            'replies': List<dynamic>.from(currentReply['replies'] ?? const []), // For further nesting if API supports
            'userId': currentReply['userId']?.toString(),
            'likesCount': currentReply['likesCount'], // Pass derived counts
            'repostsCount': currentReply['repostsCount'],
            'viewsCount': currentReply['viewsCount'],
            'repliesCount': currentReply['repliesCount'],
            // Crucially, add originalPostId and parentReplyId if the backend doesn't nest them directly
            // This might be useful for the UI if it needs this context.
            // 'originalPostId': originalPostId, // The ultimate root post
            // 'parentReplyId': parentReplyId, // The direct parent of these fetched replies
          });
        }
        //   // print("[DataController] Processed replies for parent reply $parentReplyId: $processedReplies");
        return processedReplies;
      } else {
          // print('[DataController] Error fetching replies for parent reply $parentReplyId: ${response.statusCode} - ${response.data?['message']}');
        throw Exception('Failed to fetch replies for reply: ${response.data?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
        // print('[DataController] Exception caught in fetchRepliesForReply (parent reply $parentReplyId): $e');
      throw Exception('An error occurred while fetching replies for reply: $e');
    }
  }

  Future<Map<String, dynamic>> fetchUserProfile(String username) async {
    // isLoading.value = true; // Removed: ProfilePage will manage its own loading state
    try {
      final String? token = user.value['token'];
      if (token == null) {
        // isLoading.value = false; // Removed
        return {'success': false, 'message': 'Authentication token not found.'};
      }

      final response = await _dio.get(
        '/api/users/get-user/$username', // Constructing the URL with username
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      // isLoading.value = false; // Removed

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['user'] != null) {
          return {'success': true, 'user': response.data['user']};
        } else {
          return {'success': false, 'message': 'User data not found in response.'};
        }
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to fetch user profile. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      // isLoading.value = false; // Removed
        // print('[DataController] Error fetching user profile for $username: $e');
      String errorMessage = 'An error occurred while fetching the profile.';
      if (e is dio.DioException) {
        if (e.response?.statusCode == 404) {
          errorMessage = 'User profile not found.';
        } else if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

// Helper to update a user's follow status and counts in a list
void _updateUserInList(RxList<Map<String, dynamic>> list, String userId, {bool? isFollowing, int? followersDelta, int? followingDelta}) {
  int index = list.indexWhere((u) => u['_id'] == userId);
  if (index != -1) {
    var userToUpdate = Map<String, dynamic>.from(list[index]);
    if (isFollowing != null) {
      userToUpdate['isFollowingCurrentUser'] = isFollowing;
    }
    if (followersDelta != null) {
      userToUpdate['followersCount'] = (userToUpdate['followersCount'] ?? 0) + followersDelta;
      // Also update the 'followers' array if it exists for this user map
      if (userToUpdate.containsKey('followers') && userToUpdate['followers'] is List) {
        // This is tricky: followersDelta > 0 means someone followed this user.
        // We don't know WHO followed from this generic update.
        // For now, we only update the count. Socket events will handle specific array changes.
      }
    }
    if (followingDelta != null) {
      userToUpdate['followingCount'] = (userToUpdate['followingCount'] ?? 0) + followingDelta;
      // Similar to above, we only update count.
    }
    list[index] = userToUpdate;
  }
}

Future<Map<String, dynamic>> followUser(String userIdToFollow) async {
  final String? token = user.value['token'];
  final String? currentUserId = user.value['user']?['_id'];

  if (token == null || currentUserId == null) {
    return {'success': false, 'message': 'User not authenticated.'};
  }
  if (currentUserId == userIdToFollow) {
    return {'success': false, 'message': 'Cannot follow yourself.'};
  }

  try {
    final response = await _dio.post(
      '/api/users/follow-user',
      data: {
        'thisUserId': currentUserId,
        'UserToFollowId': userIdToFollow
      },
      options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      // 1. Update current user's main data (user.value)
      if (user.value['user'] is Map) {
        var userDetail = Map<String, dynamic>.from(user.value['user']);
        var localFollowingList = List<String>.from((userDetail['following'] as List<dynamic>? ?? []).map((e) => e.toString()));
        if (!localFollowingList.contains(userIdToFollow)) {
          localFollowingList.add(userIdToFollow);
        }
        userDetail['following'] = localFollowingList;
        // Update followingCount for the logged-in user
        userDetail['followingCount'] = localFollowingList.length;

        var mainUserMap = Map<String, dynamic>.from(user.value);
        mainUserMap['user'] = userDetail;
        user.value = mainUserMap;
        await _storage.write(key: 'user', value: jsonEncode(user.value));
      }

      // 2. Update target user and current user in allUsers list
      _updateUserInList(allUsers, userIdToFollow, isFollowing: true, followersDelta: 1);
      _updateUserInList(allUsers, currentUserId, followingDelta: 1);

      // 3. Update _dataController.followers and _dataController.following lists if they are relevant
      //    (i.e., if they are currently loaded for the affected users)

      // If the `followers` list is currently loaded for `userIdToFollow` (the user who gained a follower)
      // Add `currentUserId` (the new follower) to this list.
      // We need a minimal representation of the current user.
      Map<String, dynamic>? currentUserDataForList;
      try {
        currentUserDataForList = allUsers.firstWhere((u) => u['_id'] == currentUserId);
      } catch (e) {
        currentUserDataForList = null;
      }
      if (currentUserDataForList == null && user.value['user']?['_id'] == currentUserId) {
          currentUserDataForList = {
            '_id': currentUserId,
            'avatar': user.value['user']?['avatar'] ?? '',
            'username': user.value['user']?['username'] ?? '',
            'name': user.value['user']?['name'] ?? 'Current User',
            'isFollowingCurrentUser': false, // From perspective of current user, they don't follow themselves.
                                          // But if this user is added to another's follower list, this flag might need to be true if current user follows them.
                                          // This specific 'isFollowingCurrentUser' is for the button next to this user in a list.
                                          // When adding current user to target's followers list, the 'isFollowingCurrentUser' for the current user entry
                                          // should reflect if the *target user* is followed by the *current user*. This is true by definition of this action for the target.
                                          // This is getting complex. Let's simplify: the FollowerPage's list items have their own isFollowingCurrentUser.
            // followersCount and followingCount for the currentUserDataForList are not strictly necessary here if not displayed.
          };
      }

      // If the currently loaded `followers` list is for `userIdToFollow`
      // This requires knowing whose followers list is active. For simplicity, we assume if `followers` is not empty,
      // it *could* be for `userIdToFollow`. A more robust way would be to check `_targetUserId` if FollowersPage sets it.
      // For now, if the first user in `followers` list has `userIdToFollow` as one of their followers (which is not how it works),
      // or if _dataController had a variable like `currentlyViewedProfileIdForFollowersList`.
      // Let's assume for now: if followers list is for targetUserId, add current user.
      // This part is tricky without knowing the context of `_dataController.followers`
      // Let's assume a simplified update: if `followers` list is not empty, and `userIdToFollow` is in it (which is wrong logic)
      // A better direct update for `_dataController.followers`:
      // If `_dataController.followers` is for `userIdToFollow`, then add `currentUserId` to it.
      // This needs context. The socket event handler will be more robust for this.
      // For now, let's focus on counts and the current user's own `following` list.


      // If the `following` list is currently loaded for `currentUserId`
      // Add `userIdToFollow` (the user now being followed) to this list.
      Map<String, dynamic>? targetUserDataForList;
      try {
        targetUserDataForList = allUsers.firstWhere((u) => u['_id'] == userIdToFollow);
      } catch (e) {
        targetUserDataForList = null;
      }
      if (targetUserDataForList != null) {
        // Check if `_dataController.following` is for the `currentUserId`.
        // Similar to above, this needs context.
        // If `_dataController.isLoadingFollowing` is false and `_dataController.following` is populated,
        // and we assume it's for `currentUserId` (common case for "Your Network").
        int targetInFollowingListIdx = following.indexWhere((u) => u['_id'] == userIdToFollow);
        if (targetInFollowingListIdx == -1) {
          var newFollowingEntry = Map<String, dynamic>.from(targetUserDataForList);
          newFollowingEntry['isFollowingCurrentUser'] = true; // Current user is now following this target.
          // Update counts for this specific entry
          newFollowingEntry['followersCount'] = (newFollowingEntry['followersCount'] ?? 0) + 1;
          following.add(newFollowingEntry);
        } else {
            var userToUpdate = Map<String, dynamic>.from(following[targetInFollowingListIdx]);
            userToUpdate['isFollowingCurrentUser'] = true;
            userToUpdate['followersCount'] = (userToUpdate['followersCount'] ?? 0) + 1;
            following[targetInFollowingListIdx] = userToUpdate;
        }
      }

        // print('[DataController] User $currentUserId successfully followed $userIdToFollow.');
      return {'success': true, 'message': response.data['message'] ?? 'Successfully followed user.'};
    } else {
      return {'success': false, 'message': response.data['message'] ?? 'Failed to follow user.'};
    }
  } catch (e) {
      // print('[DataController] Error following user $userIdToFollow: $e');
    String errorMessage = 'An error occurred while trying to follow.';
    if (e is dio.DioException && e.response?.data != null && e.response!.data['message'] != null) {
      errorMessage = e.response!.data['message'];
    } else if (e is dio.DioException) {
      errorMessage = e.message ?? errorMessage;
    }
    return {'success': false, 'message': errorMessage};
  }
}

Future<Map<String, dynamic>> unfollowUser(String userIdToUnfollow) async {
  final String? token = user.value['token'];
  final String? currentUserId = user.value['user']?['_id'];

  if (token == null || currentUserId == null) {
    return {'success': false, 'message': 'User not authenticated.'};
  }
   if (currentUserId == userIdToUnfollow) {
    return {'success': false, 'message': 'Cannot unfollow yourself.'};
  }

  try {
    final response = await _dio.post(
      '/api/users/unfollow-user',
      data: {
        'thisUserId': currentUserId,
        'UserToUnfollowId': userIdToUnfollow
      },
      options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      // 1. Update current user's main data (user.value)
      if (user.value['user'] is Map) {
        var userDetail = Map<String, dynamic>.from(user.value['user']);
        var localFollowingList = List<String>.from((userDetail['following'] as List<dynamic>? ?? []).map((e) => e.toString()));
        if (localFollowingList.contains(userIdToUnfollow)) {
          localFollowingList.remove(userIdToUnfollow);
        }
        userDetail['following'] = localFollowingList;
        // Update followingCount for the logged-in user
        userDetail['followingCount'] = localFollowingList.length;

        var mainUserMap = Map<String, dynamic>.from(user.value);
        mainUserMap['user'] = userDetail;
        user.value = mainUserMap;
        await _storage.write(key: 'user', value: jsonEncode(user.value));
      }

      // 2. Update target user and current user in allUsers list
      _updateUserInList(allUsers, userIdToUnfollow, isFollowing: false, followersDelta: -1);
      _updateUserInList(allUsers, currentUserId, followingDelta: -1);

      // 3. Update _dataController.followers and _dataController.following lists if they are relevant

      // If the `followers` list is currently loaded for `userIdToUnfollow` (the user who lost a follower)
      // Remove `currentUserId` (the one who unfollowed) from this list.
      // This part is complex without direct context of whose list `_dataController.followers` represents.
      // The socket event handler will be more robust.
      // For now, if `_dataController.followers` contains `currentUserId`, remove them.
      // This is a simplification.
      followers.removeWhere((u) => u['_id'] == currentUserId);


      // If the `following` list is currently loaded for `currentUserId`
      // Remove `userIdToUnfollow` (the user no longer being followed) from this list.
      following.removeWhere((u) => u['_id'] == userIdToUnfollow);


        // print('[DataController] User $currentUserId successfully unfollowed $userIdToUnfollow.');
      return {'success': true, 'message': response.data['message'] ?? 'Successfully unfollowed user.'};
    } else {
      return {'success': false, 'message': response.data['message'] ?? 'Failed to unfollow user.'};
    }
  } catch (e) {
      // print('[DataController] Error unfollowing user $userIdToUnfollow: $e');
    String errorMessage = 'An error occurred while trying to unfollow.';
    if (e is dio.DioException && e.response?.data != null && e.response!.data['message'] != null) {
      errorMessage = e.response!.data['message'];
    } else if (e is dio.DioException) {
      errorMessage = e.message ?? errorMessage;
    }
    return {'success': false, 'message': errorMessage};
  }
}

void clearUserPosts() {
    userPosts.clear();
    // isLoadingUserPosts.value = false; // Optionally reset loading state too
  }

  Future<void> fetchUserPosts(String targetUserId, {bool isRefresh = false}) async {
    if (_isFetchingUserPosts.value) return;
    _isFetchingUserPosts.value = true;
    isLoadingUserPosts.value = true;

    if (isRefresh) {
      _currentUserPostsPage.value = 1;
      _hasMoreUserPosts.value = true;
      userPosts.clear();
    }

    if (!_hasMoreUserPosts.value) {
      _isFetchingUserPosts.value = false;
      isLoadingUserPosts.value = false;
      return;
    }

    try {
      final String? token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated. Cannot fetch user posts.');
      }

      final response = await _dio.get(
        'api/posts/fetch-user-posts/$targetUserId?page=${_currentUserPostsPage.value}&limit=20',
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['posts'] != null && response.data['posts'] is List) {
          List<dynamic> fetchedPostsDynamic = response.data['posts'];
          if (fetchedPostsDynamic.isNotEmpty) {
            List<Map<String, dynamic>> processedPosts = fetchedPostsDynamic.map((postData) {
              if (postData is Map<String, dynamic>) {
                return _processPostOrReply(postData);
              }
              return <String, dynamic>{};
            }).where((postMap) => postMap.isNotEmpty).toList();
            userPosts.addAll(processedPosts);
            _currentUserPostsPage.value++;
          } else {
            _hasMoreUserPosts.value = false;
          }
        } else {
          _hasMoreUserPosts.value = false;
        }
      } else {
        throw Exception('Failed to fetch user posts: ${response.data?['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
      // print('[DataController.fetchUserPosts] Error in fetchUserPosts for user $targetUserId: ${e.toString()}');
    } finally {
      isLoadingUserPosts.value = false;
      _isFetchingUserPosts.value = false;
    }
  }


  Future<Map<String, dynamic>> updateAboutInfo(String aboutText) async {
    final String? token = user.value['token'];
    final String? currentUserId = user.value['user']?['_id'];

    if (token == null || currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated. Please log in again.'};
    }

    try {
      final response = await _dio.post(
        '/api/users/update-about', // Endpoint to update "about" for the logged-in user
        data: {'about': aboutText, 'userid': currentUserId},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Optimistically update local user data
        if (user.value['user'] is Map) {
          var updatedUserObject = Map<String, dynamic>.from(user.value['user']);
          updatedUserObject['about'] = aboutText; // Assuming the backend returns the updated user or just the new 'about' text

          var mainUserMap = Map<String, dynamic>.from(user.value);
          mainUserMap['user'] = updatedUserObject;
          user.value = mainUserMap;
          user.refresh();

          // Save updated user object to secure storage
          await _storage.write(key: 'user', value: jsonEncode(user.value));
            // print('[DataController] "About" info updated locally and in storage.');
        }
        return {'success': true, 'message': response.data['message'] ?? 'About information updated successfully.'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to update about information.'};
      }
    } catch (e) {
        // print('[DataController] Error updating about info: $e');
      String errorMessage = 'An error occurred while updating about information.';
      if (e is dio.DioException && e.response?.data != null && e.response!.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      } else if (e is dio.DioException) {
        errorMessage = e.message ?? errorMessage;
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  // --- Real-time Update Handlers for Socket Events ---

  void handleUserFollowedSocket(Map<String, dynamic> data) {
    final String? followerId = data['followerId'] as String?; // The user who initiated the follow
    final String? followedId = data['followedId'] as String?; // The user who was followed
    // final int? newFollowerCountForFollowedUser = data['newFollowerCountForFollowedUser'] as int?; // Optional: use if backend sends definitive counts
    // final int? newFollowingCountForFollower = data['newFollowingCountForFollower'] as int?; // Optional

    if (followerId == null || followedId == null) {
        // print('[DataController.handleUserFollowedSocket] Received insufficient data: $data');
      return;
    }

      // print('[DataController.handleUserFollowedSocket] Processing: $followerId followed $followedId');

    // Update the user who was followed (their followersCount increases)
    int followedUserIndex = allUsers.indexWhere((u) => u['_id'] == followedId);
    if (followedUserIndex != -1) {
      var userToUpdate = Map<String, dynamic>.from(allUsers[followedUserIndex]);
      userToUpdate['followersCount'] = (userToUpdate['followersCount'] ?? 0) + 1;
      if (userToUpdate.containsKey('followers') && userToUpdate['followers'] is List && !(userToUpdate['followers'] as List).contains(followerId)) {
        (userToUpdate['followers'] as List).add(followerId); // Add to array if structure supports
      }
      // If the current logged-in user is the one who was followed, update their 'isFollowingCurrentUser' for the follower
      // This is complex as 'isFollowingCurrentUser' is relative to the logged-in user.
      // If followerId is the loggedInUser, then for the followedId user, 'isFollowingCurrentUser' remains true.
      // This logic is more about how the `followedId` user appears in lists for `followerId`.
      allUsers[followedUserIndex] = userToUpdate;
    }

    // Update the user who initiated the follow (their followingCount increases)
    int followerUserIndex = allUsers.indexWhere((u) => u['_id'] == followerId);
    if (followerUserIndex != -1) {
      var userToUpdate = Map<String, dynamic>.from(allUsers[followerUserIndex]);
      userToUpdate['followingCount'] = (userToUpdate['followingCount'] ?? 0) + 1;
       if (userToUpdate.containsKey('following') && userToUpdate['following'] is List && !(userToUpdate['following'] as List).contains(followedId)) {
        (userToUpdate['following'] as List).add(followedId);
      }
      // If the followerId is the currently logged-in user, this user ('followerId') is now following 'followedId'.
      if (followerId == user.value['user']?['_id']) {
        userToUpdate['isFollowingCurrentUser'] = true; // This seems incorrect for the follower user itself.
                                                      // 'isFollowingCurrentUser' on a user in allUsers means "is the logged-in user following THIS user".
                                                      // So, for the `followedId` user, their `isFollowingCurrentUser` should be true if `followerId` is the logged-in user.
                                                      // Let's correct the logic for 'isFollowingCurrentUser' update.
         // If the current logged-in user IS the followerId, then for the followedId user in allUsers,
         // their 'isFollowingCurrentUser' flag should become true.
         int targetUserIdx = allUsers.indexWhere((u) => u['_id'] == followedId);
         if(targetUserIdx != -1) {
           var targetUser = Map<String, dynamic>.from(allUsers[targetUserIdx]);
           targetUser['isFollowingCurrentUser'] = true;
           allUsers[targetUserIdx] = targetUser;
         }
      }
      allUsers[followerUserIndex] = userToUpdate;
    }

    // Update logged-in user's data if they are involved
    if (user.value['user']?['_id'] == followerId) { // Logged-in user is the follower
      var userDetail = Map<String, dynamic>.from(user.value['user']);
      var localFollowingList = List<String>.from((userDetail['following'] as List<dynamic>? ?? []).map((e) => e.toString()));
      if (!localFollowingList.contains(followedId)) {
        localFollowingList.add(followedId);
        userDetail['following'] = localFollowingList;
        userDetail['followingCount'] = localFollowingList.length;
        var mainUserMap = Map<String, dynamic>.from(user.value);
        mainUserMap['user'] = userDetail;
        user.value = mainUserMap;
        _storage.write(key: 'user', value: jsonEncode(user.value));
      }
    } else if (user.value['user']?['_id'] == followedId) { // Logged-in user was followed
      var userDetail = Map<String, dynamic>.from(user.value['user']);
      var localFollowersList = List<String>.from((userDetail['followers'] as List<dynamic>? ?? []).map((e) => e.toString()));
      if (!localFollowersList.contains(followerId)) {
        localFollowersList.add(followerId);
        userDetail['followers'] = localFollowersList;
        userDetail['followersCount'] = localFollowersList.length; // Assuming followersCount field exists
        var mainUserMap = Map<String, dynamic>.from(user.value);
        mainUserMap['user'] = userDetail;
        user.value = mainUserMap;
        _storage.write(key: 'user', value: jsonEncode(user.value));
      }
    }

    // Update currently loaded followers/following lists for FollowersPage/NetworkPage
    // This requires knowing whose list is loaded. Assume _targetUserId is set by FollowersPage.
    // For simplicity, we'll attempt updates if the lists are populated.

    // If current user (`followerId`) followed `followedId`:
    // - Add `followedId` to `_dataController.following` if it's for `followerId`.
    // - Add `followerId` to `_dataController.followers` if it's for `followedId`.
    Map<String, dynamic>? followedUserData;
    try {
      followedUserData = allUsers.firstWhere((u) => u['_id'] == followedId);
    } catch (e) {
      followedUserData = null;
    }
    if (followedUserData != null) {
        int idx = following.indexWhere((u) => u['_id'] == followedId);
        if (idx == -1) { // If not already in the `following` list of the current user (followerId)
            // This check is implicitly for when `followerId` is the loggedInUser and their `following` list is active
            if (user.value['user']?['_id'] == followerId) {
                 var entry = Map<String, dynamic>.from(followedUserData);
                 entry['isFollowingCurrentUser'] = true; // Current user (follower) is following this one.
                 following.add(entry);
            }
        } else { // Already there, ensure state is correct
            if (user.value['user']?['_id'] == followerId) {
                var entry = Map<String, dynamic>.from(following[idx]);
                entry['isFollowingCurrentUser'] = true;
                entry['followersCount'] = (entry['followersCount'] ?? 0) + 1; // The followed user's follower count increases
                following[idx] = entry;
            }
        }
    }

    Map<String, dynamic>? followerUserData;
    try {
      followerUserData = allUsers.firstWhere((u) => u['_id'] == followerId);
    } catch (e) {
      followerUserData = null;
    }
     if (followerUserData != null) {
        int idx = followers.indexWhere((u) => u['_id'] == followerId);
        if (idx == -1) { // If `followerId` is not in the `followers` list of `followedId`
             // This implies the `followers` list is for `followedId`
             // This part is tricky; FollowersPage needs to manage its own _targetUserId context for this to be accurate.
             // A simple check: if followers list is not empty and its content seems to be for `followedId`.
             // For now, this is an optimistic update.
             // Let's assume if `followers` list is active for `followedId`, we add the `followerId` to it.
             // This should ideally be tied to a state like `_currentlyViewedProfileIdForFollowersPage == followedId`.
             // For now, we'll skip direct manipulation of `_dataController.followers` here as it's less certain.
             // The page should refetch or use Obx on `allUsers` data for the profile being viewed.
        }
    }
    // Refresh lists to ensure UI updates
    allUsers.refresh();
    followers.refresh();
    following.refresh();

    // Notify ProfilePage if the followed user's profile might be open
    profileUpdateTrigger.value = followedId ?? DateTime.now().millisecondsSinceEpoch.toString(); // Use timestamp as unique trigger if ID is null
  }


  void handleUserUnfollowedSocket(Map<String, dynamic> data) {
    final String? unfollowerId = data['unfollowerId'] as String?; // The user who initiated the unfollow
    final String? unfollowedId = data['unfollowedId'] as String?; // The user who was unfollowed
    // final int? newFollowerCountForUnfollowedUser = data['newFollowerCountForUnfollowedUser'] as int?; // Optional
    // final int? newFollowingCountForUnfollower = data['newFollowingCountForUnfollower'] as int?; // Optional


    if (unfollowerId == null || unfollowedId == null) {
        // print('[DataController.handleUserUnfollowedSocket] Received insufficient data: $data');
      return;
    }
      // print('[DataController.handleUserUnfollowedSocket] Processing: $unfollowerId unfollowed $unfollowedId');

    // Update the user who was unfollowed (their followersCount decreases)
    int unfollowedUserIndex = allUsers.indexWhere((u) => u['_id'] == unfollowedId);
    if (unfollowedUserIndex != -1) {
      var userToUpdate = Map<String, dynamic>.from(allUsers[unfollowedUserIndex]);
      userToUpdate['followersCount'] = (userToUpdate['followersCount'] ?? 1) - 1;
      if (userToUpdate.containsKey('followers') && userToUpdate['followers'] is List) {
        (userToUpdate['followers'] as List).remove(unfollowerId);
      }
      // If the current logged-in user IS the unfollowerId, then for the unfollowedId user in allUsers,
      // their 'isFollowingCurrentUser' flag should become false.
      if (unfollowerId == user.value['user']?['_id']) {
          userToUpdate['isFollowingCurrentUser'] = false;
      }
      allUsers[unfollowedUserIndex] = userToUpdate;
    }

    // Update the user who initiated the unfollow (their followingCount decreases)
    int unfollowerUserIndex = allUsers.indexWhere((u) => u['_id'] == unfollowerId);
    if (unfollowerUserIndex != -1) {
      var userToUpdate = Map<String, dynamic>.from(allUsers[unfollowerUserIndex]);
      userToUpdate['followingCount'] = (userToUpdate['followingCount'] ?? 1) - 1;
      if (userToUpdate.containsKey('following') && userToUpdate['following'] is List) {
        (userToUpdate['following'] as List).remove(unfollowedId);
      }
      allUsers[unfollowerUserIndex] = userToUpdate;
    }

    // Update logged-in user's data if they are involved
    if (user.value['user']?['_id'] == unfollowerId) { // Logged-in user is the unfollower
      var userDetail = Map<String, dynamic>.from(user.value['user']);
      var localFollowingList = List<String>.from((userDetail['following'] as List<dynamic>? ?? []).map((e) => e.toString()));
      if (localFollowingList.contains(unfollowedId)) {
        localFollowingList.remove(unfollowedId);
        userDetail['following'] = localFollowingList;
        userDetail['followingCount'] = localFollowingList.length;
        var mainUserMap = Map<String, dynamic>.from(user.value);
        mainUserMap['user'] = userDetail;
        user.value = mainUserMap;
        _storage.write(key: 'user', value: jsonEncode(user.value));
      }
    } else if (user.value['user']?['_id'] == unfollowedId) { // Logged-in user was unfollowed
      var userDetail = Map<String, dynamic>.from(user.value['user']);
      var localFollowersList = List<String>.from((userDetail['followers'] as List<dynamic>? ?? []).map((e) => e.toString()));
      if (localFollowersList.contains(unfollowerId)) {
        localFollowersList.remove(unfollowerId);
        userDetail['followers'] = localFollowersList;
        userDetail['followersCount'] = localFollowersList.length; // Assuming followersCount field exists
        var mainUserMap = Map<String, dynamic>.from(user.value);
        mainUserMap['user'] = userDetail;
        user.value = mainUserMap;
        _storage.write(key: 'user', value: jsonEncode(user.value));
      }
    }

    // Update currently loaded followers/following lists
    // If current user (`unfollowerId`) unfollowed `unfollowedId`:
    // - Remove `unfollowedId` from `_dataController.following` if it's for `unfollowerId`.
    // - Remove `unfollowerId` from `_dataController.followers` if it's for `unfollowedId`.
    if (user.value['user']?['_id'] == unfollowerId) {
        following.removeWhere((u) => u['_id'] == unfollowedId);
    }
    // Similar to follow, direct manipulation of `_dataController.followers` for the `unfollowedId` is tricky
    // without page context. Page should refetch or rely on Obx from allUsers.
    // However, if the `followers` list *is* for the `unfollowedId` and contains `unfollowerId`, remove them.
    // This is an optimistic attempt.
    // followers.removeWhere((u) => u['_id'] == unfollowerId); // This line is context dependent.

    allUsers.refresh();
    followers.refresh();
    following.refresh();

    // Notify ProfilePage if the unfollowed user's profile might be open
    profileUpdateTrigger.value = unfollowedId ?? DateTime.now().millisecondsSinceEpoch.toString();
  }

  void handleUserOnlineStatus(String userId, bool isOnline, {String? lastSeen}) {
    final index = allUsers.indexWhere((user) => user['_id'] == userId);
    if (index != -1) {
      final user = allUsers[index];
      user['online'] = isOnline;
      if (lastSeen != null) {
        user['lastSeen'] = lastSeen;
      }
      allUsers[index] = user;
    }
  }

  Future<Map<String, dynamic>> loginAdmin(String username, String password) async {
    try {
      final response = await _dio.post(
        'api/auth/login-admin',
        data: {
          'username': username,
          'password': password,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        String? tokenValue = response.data['user']['token']?.toString();
        String userJson = jsonEncode(response.data['user']);

        await _storage.write(key: 'token', value: tokenValue);
        await _storage.write(key: 'user', value: userJson);

        this.user.value = jsonDecode(userJson);

        await fetchFeeds();
        final String? currentUserId = user.value['user']?['_id'];
        if (currentUserId != null && currentUserId.isNotEmpty) {
          fetchFollowers(currentUserId);
          fetchFollowing(currentUserId);
        }
        await fetchAllUsers();
        await fetchChats();

        Get.find<SocketService>().initSocket();
        final NotificationService notificationService = Get.find<NotificationService>();
        await notificationService.init();

        return {'success': true, 'message': 'Admin logged in successfully'};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Login failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> blockUser(String userIdToBlock) async {
    try {
      final String? token = this.user['token'];
      if (token == null) {
        return {'success': false, 'message': 'Authentication token not found.'};
      }

      final response = await _dio.post(
        'api/users/block',
        data: {'userId': userIdToBlock},
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Optimistically update the UI
        final currentUser = Map<String, dynamic>.from(user.value['user']);
        final blockedUsers = List<String>.from(currentUser['blockedUsers'] ?? []);
        if (!blockedUsers.contains(userIdToBlock)) {
          blockedUsers.add(userIdToBlock);
          currentUser['blockedUsers'] = blockedUsers;
          user.value['user'] = currentUser;
          user.refresh();
        }
        return {'success': true, 'message': 'User blocked successfully'};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to block user. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      String errorMessage = 'An error occurred while blocking the user.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<Map<String, dynamic>> deletePostByUser(String postId) async {
    final postIndex = posts.indexWhere((post) => post['_id'] == postId);
    final userPostIndex = userPosts.indexWhere((post) => post['_id'] == postId);
    final post = postIndex != -1 ? posts[postIndex] : (userPostIndex != -1 ? userPosts[userPostIndex] : null);

    if (post == null) {
      return {'success': false, 'message': 'Post not found locally.'};
    }

    if (postIndex != -1) posts.removeAt(postIndex);
    if (userPostIndex != -1) userPosts.removeAt(userPostIndex);

    try {
      final String? token = this.user['token'];
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      final response = await _dio.delete(
        'api/posts/$postId',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'Post deleted successfully'};
      } else {
        if (postIndex != -1) {
          posts.insert(postIndex, post);
        }
        if (userPostIndex != -1) {
          userPosts.insert(userPostIndex, post);
        }
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to delete post. Status: ${response.statusCode}'
        };
      }
    } catch (e) {
      if (postIndex != -1) {
        posts.insert(postIndex, post);
      }
      if (userPostIndex != -1) {
        userPosts.insert(userPostIndex, post);
      }
      String errorMessage = 'An error occurred while deleting the post.';
      if (e is dio.DioException) {
        if (e.response?.data != null && e.response!.data['message'] != null) {
          errorMessage = e.response!.data['message'];
        } else {
          errorMessage = e.message ?? errorMessage;
        }
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<void> _updateMessageStatusOnBackend(String messageId, String chatId, String status) async {
    try {
      final token = getAuthToken();
      if (token == null) throw Exception('User not authenticated');

      await _dio.post(
        'api/messages/status',
        data: {
          'messageId': messageId,
          'chatId': chatId,
          'status': status,
        },
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      // print('Error updating message status on backend: $e');
    }
  }

  void markMessageAsRead_DEPRECATED(Map<String, dynamic> message) {
    final messageId = message['_id'] as String?;
    final chatId = message['chatId'] as String?;
    final currentUserId = getUserId();

    if (messageId == null || chatId == null || currentUserId == null) return;

    // Check sender to prevent marking own messages as read
    final senderId = message['senderId'] is Map ? message['senderId']['_id'] : message['senderId'];
    if (senderId == currentUserId) return;

    // Check if it's already marked as read to avoid redundant API calls
    final receipts = (message['readReceipts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final alreadyRead = receipts.any((r) => r['userId'] == currentUserId && r['status'] == 'read');
    if (alreadyRead) return;

    // Only make the API call. The UI will update when the socket event comes back.
    _updateMessageStatusOnBackend(messageId, chatId, 'read');
  }

  void markMessageAsDelivered(Map<String, dynamic> message) {
    final messageId = message['_id'] as String?;
    final chatId = message['chatId'] as String?;
    final currentUserId = getUserId();

    if (messageId == null || chatId == null || currentUserId == null) return;

    // Only make the API call. The UI will update when the socket event comes back.
    _updateMessageStatusOnBackend(messageId, chatId, 'delivered');
  }

  void handleTypingStart(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String;
    final userId = data['userId'] as String;
    if (userId != getUserId()) {
      isTyping[chatId] = userId;
    }
  }

  void handleTypingStop(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String;
    isTyping[chatId] = null;
  }

  Future<void> updateFcmToken(String token) async {
    try {
      final userId = user.value['user']['_id'];
      if (userId == null) return;

      await _dio.post(
        'api/users/update-fcm-token',
        data: {'userId': userId, 'fcmToken': token},
        options: dio.Options(
          headers: {'Authorization': 'Bearer ${user.value['token']}'},
        ),
      );
        // print('FCM token updated successfully');
    } catch (e) {
        // print('Error updating FCM token: $e');
    }
  }


  Future<Map<String, dynamic>?> createGroupChat(List<String> participantIds, String groupName) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final requestData = {
        'participants': participantIds,
        'name': groupName,
        // 'about' is optional, so it's omitted.
      };
      // print("Sending create group chat request with data: $requestData");

      final response = await _dio.post(
        'api/chats/group', // Corrected endpoint
        data: requestData,
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) {
            return status != null && status < 500; // Accept all statuses under 500
          },
        ),
      );

      // print("Received create group chat response: ${response.data}");

      if (response.statusCode == 201 && response.data['success'] == true) {
        final newChat = response.data['group']; // Corrected key based on docs
        // Add to local chats list
        chats[newChat['_id']] = newChat;
        chats.refresh();
        return newChat;
      } else {
        // print('Failed to create group chat: ${response.data?['message']}');
        throw Exception('Failed to create group chat: ${response.data?['message']}');
      }
    } catch (e) {
      // print('Error creating group chat: $e');
      return null;
    }
  }

  // ASSUMED ENDPOINT
  Future<Map<String, dynamic>?> getGroupDetailsFromInvite(String inviteCode) async {
    try {
      final token = user.value['token'];
      if (token == null) throw Exception('User not authenticated');
      // This endpoint is assumed as it is not in the documentation.
      final response = await _dio.get(
        'api/invites/$inviteCode',
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['group'];
      }
      return null;
    } catch (e) {
      print('Error getting group details from invite: $e');
      return null;
    }
  }

  // ASSUMED ENDPOINT
  Future<bool> joinGroupFromInvite(String inviteCode) async {
    try {
      final token = user.value['token'];
      if (token == null) throw Exception('User not authenticated');
      // This endpoint is assumed as it is not in the documentation.
      final response = await _dio.post(
        'api/invites/$inviteCode/join',
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        fetchChats();
        return true;
      }
      return false;
    } catch (e) {
      print('Error joining group from invite: $e');
      return false;
    }
  }

  Future<bool> updateGroupDetails(String chatId, {String? name, String? about}) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (about != null) data['about'] = about;

      final response = await _dio.patch(
        'api/chats/$chatId/details',
        data: data,
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      // print('Error updating group details: $e');
      return false;
    }
  }

  Future<String?> generateGroupInviteLink(String chatId) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.post(
        'api/chats/$chatId/invite-link',
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200 && response.data['inviteLink'] != null) {
        return response.data['inviteLink'];
      }
      return null;
    } catch (e) {
      print('Error generating group invite link: $e');
      return null;
    }
  }

  Future<bool> updateGroupAvatar(String chatId, String avatarUrl) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.post(
        'api/chats/$chatId/update-avatar',
        data: {'avatarUrl': avatarUrl},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      // print('Error updating group avatar: $e');
      return false;
    }
  }

  Future<bool> addMember(String chatId, String memberId) async {
    try {
      final token = user.value['token'];
      if (token == null) throw Exception('User not authenticated');

      final response = await _dio.post(
        'api/chats/$chatId/add-member',
        data: {'memberId': memberId},
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final updatedGroup = response.data['group'];
        if (updatedGroup != null) {
          // Replace the local chat data with the authoritative response from the server
          chats[chatId] = updatedGroup;
          if (currentChat.value['_id'] == chatId) {
            currentChat.value = Map<String, dynamic>.from(updatedGroup);
          }
          chats.refresh();
        }
        return true;
      } else {
        throw Exception('Failed to add member on server: ${response.data?['message']}');
      }
    } catch (e) {
      print('Error adding member: $e');
      return false;
    }
  }

  Future<bool> removeMember(String chatId, String memberId) async {
    try {
      final token = user.value['token'];
      if (token == null) throw Exception('User not authenticated');

      final response = await _dio.post(
        'api/chats/$chatId/remove-member',
        data: {'memberId': memberId},
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final updatedGroup = response.data['group'];
        if (updatedGroup != null) {
          chats[chatId] = updatedGroup;
          if (currentChat.value['_id'] == chatId) {
            currentChat.value = Map<String, dynamic>.from(updatedGroup);
          }
          chats.refresh();
        }
        return true;
      } else {
        throw Exception('Failed to remove member on server: ${response.data?['message']}');
      }
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }

  Future<bool> promoteAdmin(String chatId, String memberId) async {
    try {
      final token = user.value['token'];
      if (token == null) throw Exception('User not authenticated');

      final response = await _dio.post(
        'api/chats/$chatId/promote-admin',
        data: {'memberId': memberId},
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final updatedGroup = response.data['group'];
        if (updatedGroup != null) {
          chats[chatId] = updatedGroup;
          if (currentChat.value['_id'] == chatId) {
            currentChat.value = Map<String, dynamic>.from(updatedGroup);
          }
          chats.refresh();
        }
        return true;
      } else {
        throw Exception('Failed to promote admin on server: ${response.data?['message']}');
      }
    } catch (e) {
      print('Error promoting admin: $e');
      return false;
    }
  }

  Future<bool> demoteAdmin(String chatId, String memberId) async {
    try {
      final token = user.value['token'];
      if (token == null) throw Exception('User not authenticated');

      final response = await _dio.post(
        'api/chats/$chatId/demote-admin',
        data: {'memberId': memberId},
        options: dio.Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final updatedGroup = response.data['group'];
        if (updatedGroup != null) {
          chats[chatId] = updatedGroup;
          if (currentChat.value['_id'] == chatId) {
            currentChat.value = Map<String, dynamic>.from(updatedGroup);
          }
          chats.refresh();
        }
        return true;
      } else {
        throw Exception('Failed to demote admin on server: ${response.data?['message']}');
      }
    } catch (e) {
      print('Error demoting admin: $e');
      return false;
    }
  }

  Future<bool> muteMember(String chatId, String memberId) async {
    print('[LOG] muteMember called for member $memberId in chat $chatId');
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.post(
        'api/chats/$chatId/mute-member',
        data: {'memberId': memberId},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('[LOG] muteMember API response: ${response.data}');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('[LOG] Error muting member: $e');
      return false;
    }
  }

  Future<bool> unmuteMember(String chatId, String memberId) async {
    print('[LOG] unmuteMember called for member $memberId in chat $chatId');
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.post(
        'api/chats/$chatId/unmute-member',
        data: {'memberId': memberId},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('[LOG] unmuteMember API response: ${response.data}');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('[LOG] Error unmuting member: $e');
      return false;
    }
  }

  Future<bool> leaveGroup(String chatId) async {
    final currentUserId = getUserId();
    if (currentUserId == null) return false;
    return removeMember(chatId, currentUserId);
  }

  Future<String?> uploadAvatar(File file) async {
    final uploadResult = await _uploadService.uploadFilesToCloudinary([
      {
        'file': file,
        'type': 'image',
        'filename': file.path.split('/').last,
      }
    ], (sent, total) {}); // Empty progress callback

    if (uploadResult.isNotEmpty && uploadResult.first['success'] == true) {
      return uploadResult.first['url'];
    }
    return null;
  }

  Future<bool> closeGroup(String chatId) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.delete(
        'api/chats/$chatId/close',
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      // print('Error closing group: $e');
      return false;
    }
  }

  void handleChatClosed(Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    if (chatId == null) return;

    if (chats.containsKey(chatId)) {
      chats.remove(chatId);
      if (currentChat.value['_id'] == chatId) {
        currentChat.value = {};
        currentConversationMessages.clear();
      }
      chats.refresh();
    }
  }

  Future<void> forwardMultipleMessages(List<Map<String, dynamic>> messages, String targetUserId) async {
    // Sort messages by timestamp to ensure they are forwarded in chronological order.
    messages.sort((a, b) => DateTime.parse(a['createdAt']).compareTo(DateTime.parse(b['createdAt'])));

    for (final message in messages) {
      // Awaiting each message ensures they are sent sequentially.
      // The `forwardMessage` method already contains the necessary logic to find the chat and send the message.
      await forwardMessage(message, targetUserId);
      // A small delay can be helpful to prevent potential rate-limiting issues on the backend.
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> forwardMessage(Map<String, dynamic> originalMessage, String targetUserId) async {
    // This is the correct approach. We create a new message object for forwarding,
    // ensuring it has no `chatId` and the correct new `participants`.
    // Then we pass it to the robust `sendChatMessage` method which handles
    // both new and existing conversations correctly.
    final newClientMessageId = const Uuid().v4();
    final Map<String, dynamic> payload = {
      'clientMessageId': newClientMessageId,
      'content': originalMessage['content'],
      'type': originalMessage['type'],
      'files': originalMessage['files'],
      'isForwarded': true,
      'participants': [getUserId(), targetUserId],
      // No chatId is included, so sendChatMessage will use participants to find/create a chat.
    };

    // Delegate to the existing sendChatMessage function.
    await sendChatMessage(payload, newClientMessageId);
  }

  Future<void> addReaction(String messageId, String emoji) async {
    // Optimistic UI Update
    final messageIndex = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (messageIndex != -1) {
      final message = currentConversationMessages[messageIndex];
      final reactions = List<Map<String, dynamic>>.from(message['reactions'] ?? []);
      final myReactionIndex = reactions.indexWhere((r) => r['userId'] == getUserId());

      if (myReactionIndex != -1) {
        // User is changing their reaction
        reactions[myReactionIndex]['emoji'] = emoji;
      } else {
        // User is adding a new reaction
        reactions.add({'userId': getUserId(), 'emoji': emoji});
      }
      message['reactions'] = reactions;
      currentConversationMessages[messageIndex] = message;
      currentConversationMessages.refresh();
    }

    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      await _dio.post(
        'api/messages/$messageId/reactions',
        data: {'emoji': emoji},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } catch (e) {
      // print('Error adding reaction: $e');
      // Here you might want to revert the optimistic update on failure
    }
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    // Optimistic UI Update
    final messageIndex = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (messageIndex != -1) {
      final message = currentConversationMessages[messageIndex];
      final reactions = List<Map<String, dynamic>>.from(message['reactions'] ?? []);
      final myReactionIndex = reactions.indexWhere((r) => r['userId'] == getUserId() && r['emoji'] == emoji);

      if (myReactionIndex != -1) {
        reactions.removeAt(myReactionIndex);
      }

      message['reactions'] = reactions;
      currentConversationMessages[messageIndex] = message;
      currentConversationMessages.refresh();
    }

    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      await _dio.delete(
        'api/messages/$messageId/reactions',
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } catch (e) {
      // print('Error removing reaction: $e');
      // Here you might want to revert the optimistic update on failure
    }
  }

  void handleMessageReaction(Map<String, dynamic> data) {
    final messageId = data['messageId'] as String?;
    final reactions = data['reactions'] as List<dynamic>?;

    if (messageId == null || reactions == null) return;

    final messageIndex = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (messageIndex != -1) {
      final message = currentConversationMessages[messageIndex];
      message['reactions'] = reactions;
      currentConversationMessages[messageIndex] = message;
      currentConversationMessages.refresh();
    }
  }

  void handleMessageReactionRemoved(Map<String, dynamic> data) {
    final messageId = data['messageId'] as String?;
    final reactions = data['reactions'] as List<dynamic>?;

    if (messageId == null || reactions == null) return;

    final messageIndex = currentConversationMessages.indexWhere((m) => m['_id'] == messageId);
    if (messageIndex != -1) {
      final message = currentConversationMessages[messageIndex];
      message['reactions'] = reactions;
      currentConversationMessages[messageIndex] = message;
      currentConversationMessages.refresh();
    }
  }

  Future<void> deleteMultipleChats(List<String> chatIds) async {
    // Optimistic UI update: Remove the chats from the local list immediately.
    final Map<String, Map<String, dynamic>> removedChats = {};
    for (final chatId in chatIds) {
      if (chats.containsKey(chatId)) {
        removedChats[chatId] = chats[chatId]!;
        chats.remove(chatId);
      }
    }
    chats.refresh();

    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.delete(
        'api/chats',
        data: {'chatIds': chatIds},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200 || response.data['success'] != true) {
        // If the API call fails, revert the change by adding the chats back.
        print('Failed to delete chats on the server. Reverting local changes.');
        chats.addAll(removedChats);
        chats.refresh();
      }
      // If successful, the optimistic update is correct.
      // The socket event `chats:deletedForMe` will be the final confirmation.
    } catch (e) {
      print('Error deleting multiple chats: $e. Reverting local changes.');
      // Revert UI on error
      chats.addAll(removedChats);
      chats.refresh();
    }
  }

  Future<void> deleteMultipleMessages(List<String> messageIds, {required String deleteFor}) async {
    // Optimistic UI update
    final List<Map<String, dynamic>> removedMessages = [];
    final Map<String, Map<String, dynamic>> originalMessages = {};

    if (deleteFor == 'me') {
      // For "delete for me", we remove the messages from the list
      currentConversationMessages.removeWhere((message) {
        if (messageIds.contains(message['_id'])) {
          removedMessages.add(message);
          return true;
        }
        return false;
      });
    } else { // for 'everyone'
      // For "delete for everyone", we mark them as deleted
      for (var i = 0; i < currentConversationMessages.length; i++) {
        final message = currentConversationMessages[i];
        if (messageIds.contains(message['_id'])) {
          originalMessages[message['_id']] = Map<String, dynamic>.from(message);
          currentConversationMessages[i]['deletedForEveryone'] = true;
          currentConversationMessages[i]['content'] = '';
          currentConversationMessages[i]['files'] = [];
        }
      }
    }
    currentConversationMessages.refresh();

    try {
      final token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated');
      }
      final response = await _dio.delete(
        'api/messages',
        data: {
          'messageIds': messageIds,
          'deleteFor': deleteFor,
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200 || response.data['success'] != true) {
        print('Failed to delete messages on the server. Reverting local changes.');
        // Revert the optimistic UI update
        if (deleteFor == 'me') {
          currentConversationMessages.addAll(removedMessages);
          currentConversationMessages.sort((a, b) => DateTime.parse(a['createdAt']).compareTo(DateTime.parse(b['createdAt'])));
        } else {
          for (var i = 0; i < currentConversationMessages.length; i++) {
            final message = currentConversationMessages[i];
            if (originalMessages.containsKey(message['_id'])) {
              currentConversationMessages[i] = originalMessages[message['_id']]!;
            }
          }
        }
        currentConversationMessages.refresh();
      }
    } catch (e) {
      print('Error deleting multiple messages: $e. Reverting local changes.');
      // Revert the optimistic UI update on error
      if (deleteFor == 'me') {
        currentConversationMessages.addAll(removedMessages);
        currentConversationMessages.sort((a, b) => DateTime.parse(a['createdAt']).compareTo(DateTime.parse(b['createdAt'])));
      } else {
        for (var i = 0; i < currentConversationMessages.length; i++) {
          final message = currentConversationMessages[i];
          if (originalMessages.containsKey(message['_id'])) {
            currentConversationMessages[i] = originalMessages[message['_id']]!;
          }
        }
      }
      currentConversationMessages.refresh();
    }
  }

  Future<void> sendMessageWithSharedMedia(SharedMedia sharedMedia, String targetUserId) async {
    final List<PlatformFile>? files = sharedMedia.attachments?.map((attachment) {
      return PlatformFile(
        name: attachment!.path.split('/').last,
        path: attachment.path,
        size: 0 // size is not available here, but uploadChatFiles will get it.
      );
    }).toList();

    final String? text = sharedMedia.content;

    if ((text?.trim().isEmpty ?? true) && (files?.isEmpty ?? true)) {
      return;
    }

    // Find existing chat or prepare for a new one
    String? chatId;
    try {
      final targetChat = chats.values.firstWhere(
        (chat) =>
            chat['type'] == 'dm' &&
            (chat['participants'] as List).any((p) => p['userId']['_id'] == targetUserId),
      );
      chatId = targetChat['_id'];
    } catch (e) {
      chatId = null; // No existing chat found
    }

    final clientMessageId = const Uuid().v4();
    final messageType = (files?.isNotEmpty ?? false) ? 'attachment' : 'text';

    List<Map<String, dynamic>> uploadedFiles = [];
    if (files != null && files.isNotEmpty) {
      final attachmentsData = files.map((file) {
        return {
          'file': File(file.path!),
          'type': getMediaType(file.extension ?? ''),
          'filename': file.name,
        };
      }).toList();

      final uploadResults = await uploadChatFiles(
        attachmentsData,
        (sentBytes, totalBytes) {
          // No progress update UI here, but the function requires a callback.
        },
      );

      if (uploadResults.any((result) => !result['success'])) {
        Get.snackbar('Error', 'Failed to upload some attachments.');
        return;
      }

      uploadedFiles = uploadResults.map((result) => {
        'url': result['url'],
        'type': result['type'],
        'size': result['size'],
        'filename': result['filename'],
      }).toList();
    }

    final finalMessage = {
      'clientMessageId': clientMessageId,
      'chatId': chatId,
      'participants': [getUserId(), targetUserId],
      'senderId': {
        '_id': user.value['user']['_id'],
        'name': user.value['user']['name'],
        'avatar': user.value['user']['avatar'],
      },
      'content': text?.trim() ?? '',
      'type': messageType,
      'files': uploadedFiles,
    };

    await sendChatMessage(finalMessage, clientMessageId);

    final targetUser = allUsers.firstWhere((u) => u['_id'] == targetUserId, orElse: () => {'name': 'user'});
    Get.snackbar('Success', 'Message sent to ${targetUser['name']}');
  }

  // --- App Update Methods ---

  Future<Map<String, dynamic>?> getLatestAppUpdate() async {
    try {
      final String? token = getAuthToken();
      if (token == null) {
        print('[DataController] getLatestAppUpdate: User not authenticated.');
        return null;
      }

      String platform;
      if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else {
        // For this app, web and other platforms are not targeted for this feature.
        return null;
      }

      final response = await _dio.get(
        'api/updates/latest',
        queryParameters: {'platform': platform},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['update'] as Map<String, dynamic>?;
      } else {
        print('[DataController] Failed to get latest app update: ${response.data?['message']}');
        return null;
      }
    } catch (e) {
      print('[DataController] Error fetching latest app update: $e');
      return null;
    }
  }

  Future<void> updateUserAppVersion() async {
    try {
      final String? token = getAuthToken();
      if (token == null) {
        print('[DataController] updateUserAppVersion: User not authenticated.');
        return;
      }

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String version = packageInfo.version;
      appVersion.value = version;

      await _dio.post(
        'api/users/app-version',
        data: {'version': version},
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      print('[DataController] User app version updated to $version');
    } catch (e) {
      print('[DataController] Error updating user app version: $e');
    }
  }

  void handleAppUpdateNudge(Map<String, dynamic> data) {
    print('[DataController] Received app update nudge: $data');
    appUpdateNudgeData.value = data;
  }
}