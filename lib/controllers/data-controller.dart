import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' as dio; // Use prefix for dio to avoid conflicts
import 'dart:convert';
// import 'package:path/path.dart' as path; // path is used by UploadService
import '../models/feed_models.dart'; // Added import for ChatterPost
import '../services/upload_service.dart'; // Import the UploadService

class DataController extends GetxController {
  final UploadService _uploadService = UploadService(); // Instantiate UploadService

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

  // For managing single media playback (video or audio)
  final Rxn<String> currentlyPlayingMediaId = Rxn<String>();
  final Rxn<String> currentlyPlayingMediaType = Rxn<String>(); // 'video' or 'audio'
  final Rxn<Object> activeMediaController = Rxn<Object>(); // Can be VideoPlayerController, BetterPlayerController, or AudioPlayer

  // Progress tracking for post creation
  final RxDouble uploadProgress = 0.0.obs;
  // Constants for progress allocation
  static const double _uploadPhaseProportion = 0.8; // 80% for file uploads
  static const double _savePhaseProportion = 0.2; // 20% for saving post to DB

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
        print('[DataController] createPost success, but no post data returned from backend.');
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
      uploadProgress.value = 0.0; // Reset progress on error
      return {'success': false, 'message': e.toString()};
    }
  }

  // view post - THIS IS THE ORIGINAL METHOD PROVIDED BY THE USER
  Future<Map<String, dynamic>> viewPost(String postId) async {
    try {
      String? token = user.value['token'];
      var response = await _dio.post(
        'api/posts/view-post', // Endpoint from the user's original method
        data: {'postId': postId, 'userId': user.value['user']['_id']},
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          }
        )
      );
      // print(response.data);
      if (response.statusCode == 200 && response.data['success'] == true) {
        // No local state update for views here; that will be handled by socket event.
        print('[DataController] Post view for $postId recorded successfully via original method.');
        return {'success': true, 'message': 'Post viewed successfully'};
      } else {
        print('[DataController] Failed to record post view for $postId via original method: ${response.data['message'] ?? 'Unknown error'}');
        return {'success': false, 'message': response.data['message'] ?? 'Post view failed'};
      }
    } catch (e) {
      print('[DataController] Error recording post view for $postId via original method: $e');
      return {'success': false, 'message': e.toString()};
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
      // print(response.data);
      if (response.statusCode == 200 && response.data['success'] == true) {
        // Update local post data
        int postIndex = posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          var postToUpdate = Map<String, dynamic>.from(posts[postIndex]);
          var likesList = List<dynamic>.from(postToUpdate['likes'] ?? []);

          // Add user's ID to likes list if not already present
          if (!likesList.any((like) => (like is Map ? like['_id'] == currentUserId : like == currentUserId))) {
            // Assuming backend might store simple user IDs or objects with an _id.
            // For simplicity, adding the ID. Adjust if backend returns full like objects.
            likesList.add(currentUserId);
          }
          postToUpdate['likes'] = likesList;
          posts[postIndex] = postToUpdate;
          posts.refresh();
        }
        return {'success': true, 'message': 'Post liked successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Post like failed'};
      }
    } catch (e) {
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
      // print(response.data);
      if (response.statusCode == 200 && response.data['success'] == true) {
        // Update local post data
        int postIndex = posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          var postToUpdate = Map<String, dynamic>.from(posts[postIndex]);
          var likesList = List<dynamic>.from(postToUpdate['likes'] ?? []);

          // Remove user's ID from likes list
          likesList.removeWhere((like) => (like is Map ? like['_id'] == currentUserId : like == currentUserId));
          postToUpdate['likes'] = likesList;
          posts[postIndex] = postToUpdate;
          posts.refresh();
        }
        return {'success': true, 'message': 'Post unliked successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Post unlike failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Method to reply to a post
  Future<Map<String, dynamic>> replyToPost({
    required String postId,
    required String content,
    List<Map<String, dynamic>> attachments = const [],
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
        // For now, assuming att['url'] will be populated by earlier upload step
        if (att['url'] == null) {
          print('Warning: Attachment URL is null for ${att['filename']}. This attachment might not be saved correctly.');
        }
        return {
          'type': att['type'],
          'url': att['url'] ?? '', // Or handle more gracefully if a URL is always expected
          'filename': att['filename'],
          'size': att['size'],
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
        final rawReplyData = response.data['reply'];
        if (rawReplyData != null && rawReplyData is Map<String, dynamic>) {
          // Perform mapping similar to fetchReplies to ensure consistent object structure
          List<Map<String, dynamic>> mappedAttachments = [];
          if (rawReplyData['mediaAttachments'] != null && rawReplyData['mediaAttachments'] is List) {
            for (var attData in (rawReplyData['mediaAttachments'] as List<dynamic>)) {
              if (attData is Map<String, dynamic>) {
                mappedAttachments.add({
                  'type': attData['type']?.toString() ?? 'unknown',
                  'url': attData['url']?.toString() ?? '',
                  'filename': attData['fileName']?.toString() ?? attData['filename']?.toString() ?? '', // Allow both fileName and filename
                  'size': (attData['fileSize'] is num ? attData['fileSize'] : int.tryParse(attData['fileSize']?.toString() ?? '0'))?.toInt() ??
                          (attData['size'] is num ? attData['size'] : int.tryParse(attData['size']?.toString() ?? '0'))?.toInt() ?? 0, // Allow both fileSize and size
                });
              }
            }
          }

          String repUsername = rawReplyData['authorDetails']?['username']?.toString() ??
                               rawReplyData['username']?.toString() ?? // Fallback to direct username
                               'Unknown User';
          String repAvatarInitial = repUsername.isNotEmpty ? repUsername[0].toUpperCase() : '?';
          if (rawReplyData['authorDetails']?['avatarInitial'] != null) {
            repAvatarInitial = rawReplyData['authorDetails']['avatarInitial'].toString();
          } else if (rawReplyData['avatarInitial'] != null) {
            repAvatarInitial = rawReplyData['avatarInitial'].toString();
          }

          final mappedReply = {
            'id': rawReplyData['_id']?.toString() ?? rawReplyData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'username': repUsername,
            'content': rawReplyData['textContent']?.toString() ?? rawReplyData['content']?.toString() ?? '',
            'timestamp': (DateTime.tryParse(rawReplyData['createdAt']?.toString() ?? rawReplyData['timestamp']?.toString() ?? '') ?? DateTime.now()).toIso8601String(),
            'likes': (rawReplyData['likeCount'] is num ? rawReplyData['likeCount'] : int.tryParse(rawReplyData['likeCount']?.toString() ?? '0'))?.toInt() ?? 0,
            'reposts': (rawReplyData['repostCount'] is num ? rawReplyData['repostCount'] : int.tryParse(rawReplyData['repostCount']?.toString() ?? '0'))?.toInt() ?? 0,
            'views': (rawReplyData['viewCount'] is num ? rawReplyData['viewCount'] : int.tryParse(rawReplyData['viewCount']?.toString() ?? '0'))?.toInt() ?? 0,
            'attachments': mappedAttachments,
            'avatarInitial': repAvatarInitial,
            'useravatar': rawReplyData['authorDetails']?['avatar']?.toString() ?? rawReplyData['useravatar']?.toString(),
            'replies': const [], // Replies to a reply are not typically included here
          };
          return {
            'success': true,
            'message': response.data['message'] ?? 'Reply posted successfully!',
            'reply': mappedReply // Return the mapped reply
          };
        } else {
          // Success but no reply data, or reply data is not in expected format
          return {
            'success': true,
            'message': response.data['message'] ?? 'Reply posted successfully (no detailed reply data returned)!',
            'reply': null
          };
        }
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
        print(response.data);
        final List<dynamic> repliesData = response.data['replies'];
        List<Map<String, dynamic>> replies = [];

        for (var replyData in repliesData) {
          // Safely extract and parse attachments
          List<Map<String, dynamic>> attachments = [];
          if (replyData['mediaAttachments'] != null && replyData['mediaAttachments'] is List) {
            for (var attData in (replyData['mediaAttachments'] as List<dynamic>)) {
              if (attData is Map<String, dynamic>) {
                attachments.add({
                  'type': attData['type']?.toString() ?? 'unknown',
                  'url': attData['url']?.toString() ?? '',
                  'filename': attData['fileName']?.toString() ?? '', // Adjusted to fileName
                  'size': (attData['fileSize'] is num ? attData['fileSize'] : int.tryParse(attData['fileSize']?.toString() ?? '0'))?.toInt() ?? 0, // Adjusted to fileSize
                });
              }
            }
          }

          // Safely extract username and generate avatarInitial
          String username = replyData['authorDetails']?['username']?.toString() ?? 'Unknown User';
          String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';
          if (replyData['authorDetails']?['avatarInitial'] != null) {
            avatarInitial = replyData['authorDetails']['avatarInitial'].toString();
          }

          replies.add({
            'id': replyData['_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(), // Fallback id
            'username': username,
            'content': replyData['textContent']?.toString() ?? '',
            'timestamp': (DateTime.tryParse(replyData['createdAt']?.toString() ?? '') ?? DateTime.now()).toIso8601String(),
            'likes': (replyData['likeCount'] is num ? replyData['likeCount'] : int.tryParse(replyData['likeCount']?.toString() ?? '0'))?.toInt() ?? 0,
            'reposts': (replyData['repostCount'] is num ? replyData['repostCount'] : int.tryParse(replyData['repostCount']?.toString() ?? '0'))?.toInt() ?? 0,
            'views': (replyData['viewCount'] is num ? replyData['viewCount'] : int.tryParse(replyData['viewCount']?.toString() ?? '0'))?.toInt() ?? 0,
            'attachments': attachments,
            'avatarInitial': avatarInitial,
            'useravatar': replyData['authorDetails']?['avatar']?.toString(), // Can be null
            'replies': const [], // Replies to a reply are not typically fetched in this call
          });
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

  // Add a new post to the beginning of the list, preventing duplicates
  void addNewPost(Map<String, dynamic> newPost) {
    final String? newPostId = newPost['_id'] as String?;

    if (newPostId == null) {
      // If no ID, can't reliably check for duplicates based on ID.
      // Depending on policy, either add it, log an error, or use another unique property if available.
      // For now, let's log and add it to maintain previous behavior for posts without _id.
      print("Warning: Adding a new post without an '_id'. Cannot check for duplicates by ID. Post data: $newPost");
      posts.insert(0, newPost);
      return;
    }

    // Check if a post with this ID already exists
    final bool alreadyExists = posts.any((existingPost) {
      final String? existingPostId = existingPost['_id'] as String?;
      return existingPostId != null && existingPostId == newPostId;
    });

    if (!alreadyExists) {
      posts.insert(0, newPost);
      print("New post with ID $newPostId added to the list.");
    } else {
      // Post already exists. Optionally, update if newPost is "fresher" or different.
      // For now, just preventing duplicates by not adding again.
      print("Post with ID $newPostId already exists in the list. Skipping add.");

      // Optional: If you want to replace the existing post with the new one (e.g., if socket data is more canonical)
      // final int existingPostIndex = posts.indexWhere((p) => (p['_id'] as String?) == newPostId);
      // if (existingPostIndex != -1) {
      //   print("Replacing existing post with ID $newPostId with new data.");
      //   posts[existingPostIndex] = newPost;
      //   posts.refresh(); // Notify listeners if replacing an item. insert usually notifies.
      // }
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
          print('[DataController] Error: User data structure is not as expected. Cannot update avatar in nested map.');
          // Potentially return an error or don't update if structure is broken
        }

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

  void mediaDidStartPlaying(String mediaId, String mediaType, Object controller) {
    if (currentlyPlayingMediaId.value != mediaId || currentlyPlayingMediaType.value != mediaType) {
      // If another media is playing, we might need to stop it here or ensure it's stopped by its own listener.
      // For now, this method just sets the new active media.
      // The widgets themselves should pause if currentlyPlayingMediaId changes to something else.
      currentlyPlayingMediaId.value = mediaId;
      currentlyPlayingMediaType.value = mediaType;
      activeMediaController.value = controller;
      print("[DataController] Media $mediaId (type: $mediaType) started playing. Setting global lock.");
    }
  }

  void mediaDidStopPlaying(String mediaId, String mediaType) {
    if (currentlyPlayingMediaId.value == mediaId && currentlyPlayingMediaType.value == mediaType) {
      currentlyPlayingMediaId.value = null;
      currentlyPlayingMediaType.value = null;
      activeMediaController.value = null;
      print("[DataController] Media $mediaId (type: $mediaType) stopped playing. Releasing global lock.");
    }
  }

  // Method to update post views reactively from socket event
  void updatePostViews(String postId, int viewsCount) {
    try {
      int postIndex = posts.indexWhere((p) => p['_id'] == postId);
      if (postIndex != -1) {
        // Create a new map with the updated views count
        var updatedPost = Map<String, dynamic>.from(posts[postIndex]);

        // Assuming the backend sends the total views count.
        // The 'views' field in the local post map might be a list of user IDs or just a count.
        // For simplicity and based on the Mongoose schema, 'views' is an array of user IDs.
        // The `viewsCount` from the socket event directly reflects `post.views.length` on the backend.
        // We can store this count directly if the UI only needs the number.
        // Or, if the local 'views' field is expected to be a list, this logic might differ.
        // Let's assume for now we want to store the count in a field like 'viewsCount'
        // or update the length of a 'views' list if that's how it's structured locally.

        // If your local post map has a 'viewsCount' field:
        updatedPost['viewsCount'] = viewsCount; // If you add a specific field for the count

        // Or, if your local post map has a 'views' field that is a list (as per schema)
        // and you want to reflect the count there, you might need to adjust.
        // However, the socket is sending 'viewsCount', so using/adding a field for it is direct.
        // Let's ensure the post map has a 'views' field that can store this count,
        // or a new dedicated field. If 'views' is an array of user IDs, updating it
        // with just a count would change its meaning.
        //
        // The original schema has `views: [ObjectId]`.
        // The socket event sends `viewsCount`.
        // For the UI to update the *number* of views, we need a field that holds this number.
        // If the `ChatterPost` model (or the map structure in `posts`) has a field like `viewsCount`
        // or if the number of views is derived from `post['views'].length`, we update accordingly.

        // Let's assume the post map directly stores the list of viewers in `post['views']`
        // and the UI is (or will be) responsible for displaying `post['views'].length`.
        // The socket event provides `viewsCount`. If the local `views` array isn't being updated
        // with actual viewer IDs through the socket (which it isn't, per current plan),
        // then storing `viewsCount` in a dedicated field is cleaner.

        // If the post objects in `posts` are expected to have a `views` field that is a List,
        // and a separate `viewsCount` field for display:
        if (updatedPost.containsKey('views') && updatedPost['views'] is List) {
             // We don't have the actual list of viewer IDs from this event, only the count.
             // So, we can't directly update the 'views' list to match the count without dummy data.
             // It's better to have a dedicated 'viewsCount' field or ensure the UI uses .length.
        }
        // Add or update a 'viewsCount' field. Many UI models have a separate field for counts.
        // If the original post map from `fetchFeeds` doesn't include `viewsCount` explicitly,
        // this adds it. If it does, this updates it.
        updatedPost['viewsCount'] = viewsCount; // This is the most straightforward.


        // To ensure reactivity, replace the old post map with the updated one.
        posts[postIndex] = updatedPost;
        // posts.refresh(); // Call refresh if the list itself or its items are replaced.
                           // Replacing an item by index should trigger GetX reactivity.
        print('[DataController] Updated views for post $postId to $viewsCount');
      } else {
        print('[DataController] updatePostViews: Post with ID $postId not found in local list.');
      }
    } catch (e) {
      print('[DataController] Error updating post views for $postId: $e');
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
    print("[DataController] Legacy videoDidStartPlaying called for $videoId. Consider updating call site to mediaDidStartPlaying.");
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
    print("[DataController] Legacy videoDidStopPlaying called for $videoId. Consider updating call site to mediaDidStopPlaying.");
    if (currentlyPlayingMediaId.value == videoId && currentlyPlayingMediaType.value == 'video') {
      mediaDidStopPlaying(videoId, 'video');
    }
  }
}