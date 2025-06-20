import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' as dio; // Use prefix for dio to avoid conflicts
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/feed_models.dart'; // Added import for ChatterPost

class DataController extends GetxController {

  final RxBool isLoading = false.obs;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // URL
  final String baseUrl = 'https://chatter-api.fly.dev/';
  final dio.Dio _dio = dio.Dio(dio.BaseOptions(
    baseUrl: 'https://chatter-api.fly.dev/',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));
  final user = {}.obs;
  final RxList<Map<String, dynamic>> posts = <Map<String, dynamic>>[].obs;

  // Placeholder for all users
  final RxList<Map<String, dynamic>> allUsers = <Map<String, dynamic>>[].obs;

  // Add these Rx variables inside DataController class
  final RxList<Map<String, dynamic>> conversations = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingConversations = false.obs;
  final RxList<Map<String, dynamic>> currentConversationMessages = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingMessages = false.obs;

  // Add these Rx variables inside DataController class
  final RxList<Map<String, dynamic>> followers = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingFollowers = false.obs;
  final RxList<Map<String, dynamic>> following = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingFollowing = false.obs;

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
    // fetch initial feeds
    try {
      await fetchFeeds();
    } catch (e) {
      print('Error fetching initial feeds: $e');
      posts.clear(); // Clear posts on error
    }
    // Fetch all users (placeholder)
    // We will call this from UsersListPage for now to avoid startup delays
    // fetchAllUsers();
  }

  // Method to fetch/initialize all users (placeholder implementation)
  Future<void> fetchAllUsers() async {
    // Simulate a network call
    await Future.delayed(const Duration(seconds: 1));
    // Placeholder data
    var fetchedUsers = [
      {'id': '1', 'username': 'AliceWonder', 'email': 'alice@example.com', 'avatar': 'https://i.pravatar.cc/150?u=alice'},
      {'id': '2', 'username': 'BobTheBuilder', 'email': 'bob@example.com', 'avatar': 'https://i.pravatar.cc/150?u=bob'},
      {'id': '3', 'username': 'CharlieChap', 'email': 'charlie@example.com', 'avatar': 'https://i.pravatar.cc/150?u=charlie'},
      {'id': '4', 'username': 'DianaPrince', 'email': 'diana@example.com', 'avatar': 'https://i.pravatar.cc/150?u=diana'},
      {'id': '5', 'username': 'EdwardScissor', 'email': 'edward@example.com', 'avatar': 'https://i.pravatar.cc/150?u=edward'},
    ];
    allUsers.assignAll(fetchedUsers);
    print('[DataController] Fetched all users (placeholder).');
  }

  // Create post
  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    
    try {
      var token = user.value['token'];
      if (token == null) {
        throw Exception('User token not found');
      }
      var response = await _dio.post(
        'api/posts/create-post',
        data: data,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'Post created successfully'};
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Post creation failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Method to reply to a post
  Future<Map<String, dynamic>> replyToPost({
    required String postId,
    required String content,
    List<Attachment> attachments = const [],
  }) async {
    try {
      final token = user.value['token'];
      if (token == null) {
        return {'success': false, 'message': 'User not authenticated. Please log in.'};
      }

      final userId = user.value['user']?['_id']?.toString();
      if (userId == null) {
        return {'success': false, 'message': 'User ID not found. Please log in again.'};
      }

      final String? username = user.value['user']?['name']?.toString();
      final String? userAvatar = user.value['user']?['avatar']?.toString();

      List<Map<String, dynamic>> attachmentPayload = attachments.map((att) {
        // Ensure URL is not null, provide a default or handle error if necessary
        // For now, assuming att.url will be populated by earlier upload step
        if (att.url == null) {
          print('Warning: Attachment URL is null for ${att.filename}. This attachment might not be saved correctly.');
        }
        return {
          'type': att.type,
          'url': att.url ?? '', // Or handle more gracefully if a URL is always expected
          'filename': att.filename,
          'size': att.size,
        };
      }).toList();

      final Map<String, dynamic> requestData = {
        'content': content,
        'userId': userId, // Make sure backend expects 'userId' and not e.g. 'authorId'
        'attachments': attachmentPayload,
        // Optional: include username and avatar if backend doesn't resolve from userId
        // These might be useful if the backend wants to denormalize this info directly into the reply document
        'username': username ?? 'Anonymous', // Provide a default if null
        'userAvatar': userAvatar, // Can be null
      };

      final response = await _dio.post(
        '/api/posts/$postId/reply', // Dummy endpoint
        data: requestData,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        // Assuming the backend returns the created reply object under the key 'reply'
        return {
          'success': true,
          'message': response.data['message'] ?? 'Reply posted successfully!',
          'reply': response.data['reply'] // This could be the full reply object
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to post reply. Server error.'
        };
      }
    } catch (e) {
      print('Error in replyToPost: ${e.toString()}');
      // Check if e is a DioError to potentially extract more specific error info
      if (e is dio.DioException && e.response?.data != null && e.response!.data['message'] != null) {
        return {'success': false, 'message': 'Failed to post reply: ${e.response!.data['message']}'};
      }
      return {'success': false, 'message': 'An error occurred while posting reply: ${e.toString()}'};
    }
  }

  // fetch all feeds for timeline
  Future<void> fetchFeeds() async {
    try {
      var token = user.value['token'];
      if (token == null) {
        throw Exception('User token not found');
      }
      var response = await _dio.get(
        '/api/posts/get-all-posts',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        posts.assignAll(List<Map<String, dynamic>>.from(response.data['posts']));
      } else {
        throw Exception('Failed to fetch feeds');
      }
    } catch (e) {

      print('Error fetching feeds: $e');
      posts.clear();
      rethrow; // Rethrow the exception to be handled by the caller
    }
  }

  // Fetch replies for a post
  Future<List<ChatterPost>> fetchReplies(String postId) async {
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
        print(response.data);
        final List<dynamic> repliesData = response.data['replies'];
        List<ChatterPost> replies = [];

        for (var replyData in repliesData) {
          // Safely extract and parse attachments
          List<Attachment> attachments = [];
          if (replyData['mediaAttachments'] != null && replyData['mediaAttachments'] is List) {
            for (var attData in (replyData['mediaAttachments'] as List<dynamic>)) {
              if (attData is Map<String, dynamic>) {
                attachments.add(Attachment(
                  type: attData['type']?.toString() ?? 'unknown',
                  url: attData['url']?.toString() ?? '',
                  filename: attData['fileName']?.toString() ?? '', // Adjusted to fileName
                  size: (attData['fileSize'] is num ? attData['fileSize'] : int.tryParse(attData['fileSize']?.toString() ?? '0'))?.toInt() ?? 0, // Adjusted to fileSize
                ));
              }
            }
          }

          // Safely extract username and generate avatarInitial
          String username = replyData['authorDetails']?['username']?.toString() ?? 'Unknown User';
          String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';
          if (replyData['authorDetails']?['avatarInitial'] != null) {
            avatarInitial = replyData['authorDetails']['avatarInitial'].toString();
          }


          replies.add(ChatterPost(
            id: replyData['_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), // Fallback id
            username: username,
            content: replyData['textContent']?.toString() ?? '',
            timestamp: DateTime.tryParse(replyData['createdAt']?.toString() ?? '') ?? DateTime.now(),
            likes: (replyData['likeCount'] is num ? replyData['likeCount'] : int.tryParse(replyData['likeCount']?.toString() ?? '0'))?.toInt() ?? 0,
            reposts: (replyData['repostCount'] is num ? replyData['repostCount'] : int.tryParse(replyData['repostCount']?.toString() ?? '0'))?.toInt() ?? 0,
            views: (replyData['viewCount'] is num ? replyData['viewCount'] : int.tryParse(replyData['viewCount']?.toString() ?? '0'))?.toInt() ?? 0,
            attachments: attachments,
            avatarInitial: avatarInitial,
            useravatar: replyData['authorDetails']?['avatar']?.toString(), // Can be null
            replies: const [], // Replies to a reply are not typically fetched in this call
          ));
        }
        return replies;
      } else {
        print('Error fetching replies: ${response.statusCode} - ${response.data['message']}');
        throw Exception('Failed to fetch replies: ${response.data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Exception caught in fetchReplies: $e');
      throw Exception('An error occurred while fetching replies: $e');
    }
  }

  // Add a new post to the beginning of the list
  void addNewPost(Map<String, dynamic> newPost) {
    posts.insert(0, newPost);
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
          print('[DataController] User data saved to storage and in-memory state updated.');

          // Now, fetch feeds
          try {
            print('[DataController] Login successful. Fetching initial feeds...');
            await fetchFeeds();
            print('[DataController] Initial feeds fetched successfully after login.');
          } catch (feedError) {
            print('[DataController] Error fetching feeds immediately after login: ${feedError.toString()}. Login itself is still considered successful. Feeds can be fetched later.');
            // Optionally, you could set a flag here to indicate feeds failed to load,
            // so HomeFeedScreen could show a specific message or retry option.
            // For now, HomeFeedScreen will show its default empty/loading state for posts.
          }

          return {'success': true, 'message': 'User logged in successfully'};
        } catch (e) {
          // This catch is for errors during storage write or updating user.value
          print('[DataController] Error saving user data or updating state after login: ${e.toString()}');
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
      print('[DataController] Login API call failed: ${e.toString()}');
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  Future<List<Map<String, dynamic>>> uploadFilesToCloudinary(List<File> files) async {
    print('[DataController uploadFilesToCloudinary] Received ${files.length} files for upload.');

    // Validate input
    if (files.isEmpty) {
      return [{'success': false, 'message': 'No files provided', 'progress': 0.0}];
    }

    List<Map<String, dynamic>> results = [];

    // Define supported file extensions and their resource types
    const Map<String, String> extensionToResourceType = {
      'jpg': 'image',
      'jpeg': 'image',
      'png': 'image',
      'gif': 'image',
      'bmp': 'image',
      'webp': 'image',
      'mp4': 'video',
      'mov': 'video',
      'avi': 'video',
      'mkv': 'video',
      'webm': 'video',
      'm4a': 'video',
      'mp3': 'video',
      'wav': 'video',
      'aac': 'video',
      'ogg': 'video',
      'pdf': 'raw',
      'doc': 'raw',
      'docx': 'raw',
      'txt': 'raw',
    };

    for (File file in files) {
      final filePath = file.path;
      try {
        // Validate file existence and size
        if (!await file.exists()) {
          print('[DataController uploadFilesToCloudinary] File does not exist: $filePath');
          results.add({
            'success': false,
            'message': 'File does not exist: $filePath',
            'filePath': filePath,
            'progress': 0.0,
          });
          continue;
        }

        final fileSize = await file.length();
        if (fileSize == 0) {
          print('[DataController uploadFilesToCloudinary] Empty file: $filePath');
          results.add({
            'success': false,
            'message': 'Empty file: $filePath',
            'filePath': filePath,
            'progress': 0.0,
          });
          continue;
        }

        print('[DataController uploadFilesToCloudinary] Processing file: path=$filePath, size=$fileSize bytes');

        // Determine resource type
        final fileExtension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
        final resourceType = extensionToResourceType[fileExtension] ?? 'auto';
        print('[DataController uploadFilesToCloudinary] File: $filePath, extension: $fileExtension, resource_type: $resourceType');

        // Prepare form data
        final formData = dio.FormData.fromMap({
          'file': await dio.MultipartFile.fromFile(
            filePath,
            filename: path.basename(filePath),
          ),
          'upload_preset': 'chatterpiks', // Replace with your Cloudinary upload preset
          'resource_type': resourceType,
        });

        double uploadProgress = 0.0;

        // Perform upload
        final response = await _dio.post(
          'https://api.cloudinary.com/v1_1/djg6xjdrq/$resourceType/upload', // Replace with your Cloudinary cloud name
          data: formData,
          options: dio.Options(
            validateStatus: (status) => status != null && status >= 200 && status < 500,
          ),
          onSendProgress: (sent, total) {
            uploadProgress = (sent / total * 100).clamp(0.0, 100.0);
            print('[DataController uploadFilesToCloudinary] Upload progress for $filePath: ${uploadProgress.toStringAsFixed(2)}%');
          },
        );

        // Handle response
        if (response.statusCode == 200 && response.data != null) {
          results.add({
            'success': true,
            'url': response.data['secure_url'] as String? ?? '',
            'size': response.data['bytes'] as int? ?? fileSize,
            'type': response.data['format'] as String? ?? fileExtension,
            'filename': response.data['original_filename'] as String? ?? path.basename(filePath),
            'filePath': filePath,
            'progress': uploadProgress,
            'resource_type': response.data['resource_type'] as String? ?? resourceType,
          });
          print('[DataController uploadFilesToCloudinary] Successfully uploaded: $filePath, URL: ${response.data['secure_url']}');
        } else {
          final errorMessage = response.data?['error']?['message'] ?? 'Upload failed with status: ${response.statusCode}';
          print('[DataController uploadFilesToCloudinary] Upload failed for $filePath: $errorMessage');
          results.add({
            'success': false,
            'message': errorMessage,
            'filePath': filePath,
            'progress': uploadProgress,
          });
        }
      } catch (e, stackTrace) {
        print('[DataController uploadFilesToCloudinary] Exception for $filePath: $e\n$stackTrace');
        results.add({
          'success': false,
          'message': 'Upload failed for $filePath: ${e.toString()}',
          'filePath': filePath,
          'progress': 0.0,
        });
      }
    }

    print('[DataController uploadFilesToCloudinary] Upload completed. Results: ${results.length} files processed.');
    return results;
  }

  // Add these placeholder methods inside DataController class

  Future<void> fetchConversations() async {
    isLoadingConversations.value = true;
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network call
    // Placeholder data
    conversations.assignAll([
      {'id': 'conv1', 'username': 'AliceWonder', 'userAvatar': 'https://i.pravatar.cc/150?u=alice', 'lastMessage': 'Hey, how are you?', 'timestamp': '10:30 AM'},
      {'id': 'conv2', 'username': 'BobTheBuilder', 'userAvatar': 'https://i.pravatar.cc/150?u=bob', 'lastMessage': 'Project update is due.', 'timestamp': 'Yesterday'},
      {'id': 'conv3', 'username': 'CharlieChap', 'userAvatar': 'https://i.pravatar.cc/150?u=charlie', 'lastMessage': 'Okay, sounds good!', 'timestamp': 'Mon'},
    ]);
    isLoadingConversations.value = false;
    print('[DataController] Fetched conversations (placeholder).');
  }

  Future<void> fetchMessages(String conversationId) async {
    isLoadingMessages.value = true;
    currentConversationMessages.clear(); // Clear previous messages
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network call
    // Placeholder data - In real app, filter/fetch by conversationId
    // Assuming 'currentUser' is the ID of the logged-in user.
    // You should get this from your user object, e.g., user.value['id']
    final String currentUserId = user.value['id']?.toString() ?? 'currentUser';

    if (conversationId == 'conv1') {
      currentConversationMessages.assignAll([
        {'id': 'msg1', 'senderId': 'alice', 'text': 'Hey, how are you?', 'timestamp': '10:30 AM'},
        {'id': 'msg2', 'senderId': currentUserId, 'text': 'I am good, thanks! You?', 'timestamp': '10:31 AM'},
        {'id': 'msg3', 'senderId': 'alice', 'text': 'Doing well!', 'timestamp': '10:32 AM'},
      ]);
    } else if (conversationId == 'conv2') {
       currentConversationMessages.assignAll([
        {'id': 'msgA', 'senderId': 'bob', 'text': 'Project update is due.', 'timestamp': 'Yesterday'},
        {'id': 'msgB', 'senderId': currentUserId, 'text': 'Working on it!', 'timestamp': 'Yesterday'},
      ]);
    } else {
      // No messages for other convos in this placeholder
    }
    isLoadingMessages.value = false;
    print('[DataController] Fetched messages for $conversationId (placeholder).');
  }

  // Placeholder for sending a message
  void sendMessage(String conversationId, String text) {
    // Simulate sending message and receiving it back
    final String currentUserId = user.value['id']?.toString() ?? 'currentUser';
    final newMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // Temporary unique ID
      'senderId': currentUserId,
      'text': text,
      'timestamp': 'Now', // Simple timestamp
    };
    currentConversationMessages.add(newMessage);
    // In a real app, you'd also update the 'lastMessage' for the conversation in the conversations list
    final convIndex = conversations.indexWhere((c) => c['id'] == conversationId);
    if (convIndex != -1) {
      conversations[convIndex]['lastMessage'] = text;
      conversations[convIndex]['timestamp'] = 'Now';
      conversations.refresh(); // Notify listeners of change in list item
    }
    print('[DataController] Sent message "$text" to $conversationId (placeholder).');
  }

  // Add these placeholder methods inside DataController class

  Future<void> fetchFollowers(String userId) async {
    isLoadingFollowers.value = true;
    await Future.delayed(const Duration(milliseconds: 700)); // Simulate network call
    // Placeholder data - In real app, fetch for 'userId'
    followers.assignAll([
      {'id': 'userA', 'username': 'FollowerOne', 'name': 'F. One', 'avatar': 'https://i.pravatar.cc/150?u=follower1', 'isFollowing': true}, // You might follow back
      {'id': 'userB', 'username': 'FollowerTwo', 'name': 'F. Two', 'avatar': 'https://i.pravatar.cc/150?u=follower2', 'isFollowing': false},
    ]);
    isLoadingFollowers.value = false;
    print('[DataController] Fetched followers for $userId (placeholder).');
  }

  Future<void> fetchFollowing(String userId) async {
    isLoadingFollowing.value = true;
    await Future.delayed(const Duration(milliseconds: 600)); // Simulate network call
    // Placeholder data - In real app, fetch for 'userId'
    following.assignAll([
      {'id': 'userC', 'username': 'FollowingOne', 'name': 'Fol. One', 'avatar': 'https://i.pravatar.cc/150?u=following1', 'isFollowing': true},
      {'id': 'userD', 'username': 'FollowingTwo', 'name': 'Fol. Two', 'avatar': 'https://i.pravatar.cc/150?u=following2', 'isFollowing': true},
      {'id': 'userA', 'username': 'FollowerOne', 'name': 'F. One', 'avatar': 'https://i.pravatar.cc/150?u=follower1', 'isFollowing': true}, // Also in followers list
    ]);
    isLoadingFollowing.value = false;
    print('[DataController] Fetched following list for $userId (placeholder).');
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

    print('[DataController] Toggled follow status for $targetUserId to $follow (placeholder).');
  }

  // Add this method to the DataController class

  Future<void> logoutUser() async {
    try {
      // 1. Clear data from FlutterSecureStorage
      await _storage.delete(key: 'token');
      await _storage.delete(key: 'user');
      print('[DataController] Token and user data deleted from secure storage.');

      // 2. Reset reactive variables to initial states
      user.value = {};
      posts.clear();
      allUsers.clear(); // If you want to clear this list on logout
      conversations.clear();
      currentConversationMessages.clear();
      followers.clear();
      following.clear();
      print('[DataController] In-memory user state cleared.');

      // 3. Optionally, disconnect other services
      // Example: If SocketService is managed or accessible here
      // final SocketService socketService = Get.find<SocketService>();
      // socketService.disconnect();
      // print('[DataController] SocketService disconnected.');
      // Note: Ensure SocketService handles multiple disconnect calls gracefully if also called in app dispose.

      // Any other cleanup specific to your application's state
      isLoading.value = false;
      isLoadingConversations.value = false;
      isLoadingMessages.value = false;
      isLoadingFollowers.value = false;
      isLoadingFollowing.value = false;

    } catch (e) {
      print('[DataController] Error during logout: ${e.toString()}');
      // Even if an error occurs, try to clear in-memory data as a fallback
      user.value = {};
      posts.clear();
      allUsers.clear();
      conversations.clear();
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
      print(user.value['user']['_id']);
      print(user.value['token']);
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
        var updatedUser = Map<String, dynamic>.from(user.value);
        updatedUser['avatar'] = returnedAvatarUrl;
        user.value = updatedUser; // Update reactive user object

        // Save updated user object to secure storage
        await _storage.write(key: 'user', value: jsonEncode(updatedUser));

        print('[DataController] Avatar updated successfully on backend and locally. New URL: $returnedAvatarUrl');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Avatar updated successfully!',
          'avatarUrl': returnedAvatarUrl
        };
      } else {
        print('[DataController] Backend failed to update avatar. Status: ${response.statusCode}, Message: ${response.data['message']}');
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to update avatar on backend.'
        };
      }
    } catch (e) {
      isLoading.value = false;
      print('[DataController] Error in updateUserAvatar: ${e.toString()}');
      return {'success': false, 'message': 'An error occurred: ${e.toString()}'};
    }
  }
}