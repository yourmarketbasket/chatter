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

  // Set to keep track of post IDs for which view registration is in progress
  final Set<String> _pendingViewRegistrations = <String>{};

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
    if (_pendingViewRegistrations.contains(postId)) {
      print('[DataController] View registration for post $postId is already in progress. Skipping.');
      return {'success': false, 'message': 'View registration already in progress.'};
    }

    try {
      _pendingViewRegistrations.add(postId);
      String? token = user.value['token'];
      // Ensure user and user ID exist
      if (user.value['user'] == null || user.value['user']['_id'] == null) {
        print('[DataController] User data or user ID is null. Cannot record view for post $postId.');
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
        print('[DataController] Post view for $postId recorded successfully.');
        return {'success': true, 'message': 'Post viewed successfully'};
      } else {
        print('[DataController] Failed to record post view for $postId: ${response.data['message'] ?? 'Unknown error'}');
        return {'success': false, 'message': response.data['message'] ?? 'Post view failed'};
      }
    } catch (e) {
      print('[DataController] Error recording post view for $postId: $e');
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
          postToUpdate['likesCount'] = likesList.length; // Update likesCount
          posts[postIndex] = postToUpdate;
          // posts.refresh(); // Usually not needed for item replacement if RxList is used correctly
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
          postToUpdate['likesCount'] = likesList.length; // Update likesCount
          posts[postIndex] = postToUpdate;
          // posts.refresh(); // Usually not needed for item replacement
        }
        return {'success': true, 'message': 'Post unliked successfully'};
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
  //     // print(response.data);
  //     if (response.statusCode == 200 && response.data['success'] == true) {
  //       return {'success': true, 'message': 'Post viewed successfully'};
  //     } else {
  //       return {'success': false, 'message': response.data['message'] ?? 'Post view failed'};
  //     }
  //   } catch (e) {
  //     return {'success': false, 'message': e.toString()};
  //   }
  // }

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

  // Method to fetch a single post by its ID and update it in the local list
  Future<void> fetchSinglePost(String postId) async {
    if (postId.isEmpty) {
      print('[DataController] fetchSinglePost: postId is empty. Cannot fetch.');
      return;
    }
    // Optional: Add a loading state for this specific post if needed for UI
    // isLoadingPost[postId] = true; (would require managing a map of loading states)
    print('[DataController] Fetching single post: $postId');

    try {
      var token = user.value['token'];
      if (token == null) {
        print('[DataController] fetchSinglePost: User token not found. Cannot fetch post $postId.');
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
        print('[DataController] Successfully fetched and updated post $postId.');
      } else {
        print('[DataController] Failed to fetch post $postId. Status: ${response.statusCode}, Message: ${response.data['message']}');
        throw Exception('Failed to fetch post $postId: ${response.data['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
      print('[DataController] Error fetching single post $postId: $e');
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
    try {
      var token = user.value['token'];
      var userid = user.value['user']['_id'];
      // var user = user.value['user'];
      if (token == null) {
        throw Exception('User token not found');
      }
      var response = await _dio.post(
        '/api/posts/repost-post',
        data: {'postId': postId, 'userId': userid},
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        // Successful repost, now update local post data
        final String currentUserId = user.value['user']['_id'];
        int postIndex = posts.indexWhere((p) => p['_id'] == postId);
        if (postIndex != -1) {
          var postToUpdate = Map<String, dynamic>.from(posts[postIndex]);

          // Update reposts list and count
          var repostsList = List<dynamic>.from(postToUpdate['reposts'] ?? []);
          if (!repostsList.any((reposterId) => reposterId == currentUserId)) {
            repostsList.add(currentUserId); // Add current user's ID to reposts
          }
          postToUpdate['reposts'] = repostsList;
          postToUpdate['repostsCount'] = repostsList.length;

          posts[postIndex] = postToUpdate;
          posts.refresh(); // Force UI update

          // If the backend sends back the updated post, we could use that directly:
          // e.g., if response.data['post'] exists and is the updated post
          // updatePostFromSocket(response.data['post']);
          // For now, manual update is implemented above.
        }
        // Return the original backend response which might contain useful data or messages
        return {'success': true, 'message': response.data['message'] ?? 'Post reposted successfully', 'data': response.data};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to repost post'};
      }
    } catch (e) {
      print('[DataController] Error reposting post $postId: $e');
      return {'success': false, 'message': 'An error occurred while reposting post: ${e.toString()}'};
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
        List<Map<String, dynamic>> fetchedPosts = List<Map<String, dynamic>>.from(response.data['posts']);
        // Ensure count fields are present
        for (var post in fetchedPosts) {
          post['likesCount'] = (post['likes'] as List?)?.length ?? 0;
          post['repostsCount'] = (post['reposts'] as List?)?.length ?? 0;
          post['viewsCount'] = (post['views'] as List?)?.length ?? 0;
        }
        posts.assignAll(fetchedPosts);
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
    // Ensure count fields are present for the new post
    newPost['likesCount'] = (newPost['likes'] as List?)?.length ?? 0;
    newPost['repostsCount'] = (newPost['reposts'] as List?)?.length ?? 0;
    // For views, a new post typically starts with 0 or a very small number.
    // If the backend sends a 'views' array, use its length. Otherwise, default to 0.
    // The `updatePostViews` method will update `viewsCount` based on socket events.
    newPost['viewsCount'] = (newPost['views'] as List?)?.length ?? newPost['viewsCount'] ?? 0;


    final String? newPostId = newPost['_id'] as String?;

    if (newPostId == null) {
      print("Warning: Adding a new post without an '_id'. Cannot check for duplicates by ID. Post data: $newPost");
      posts.insert(0, newPost);
      return;
    }

    final bool alreadyExists = posts.any((existingPost) {
      final String? existingPostId = existingPost['_id'] as String?;
      return existingPostId != null && existingPostId == newPostId;
    });

    if (!alreadyExists) {
      posts.insert(0, newPost);
      print("New post with ID $newPostId added to the list.");
    } else {
      print("Post with ID $newPostId already exists in the list. Attempting to update if different.");
      // Optional: If you want to replace the existing post with the new one
      final int existingPostIndex = posts.indexWhere((p) => (p['_id'] as String?) == newPostId);
      if (existingPostIndex != -1) {
         // Simple check: if string representations are different. Could be more sophisticated.
        if (posts[existingPostIndex].toString() != newPost.toString()) {
          print("Updating existing post with ID $newPostId with new data from socket/event.");
          posts[existingPostIndex] = newPost;
          // posts.refresh(); // GetX usually handles list item replacement reactively.
        } else {
          print("Post with ID $newPostId received but data is identical to local. Skipping update.");
        }
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

  // Method to update a post in the local list with data from a socket event (e.g. like, unlike, view)
  void updatePostFromSocket(Map<String, dynamic> updatedPostData) {
    final String? postId = updatedPostData['_id'] as String?;
    if (postId == null) {
      print('[DataController] updatePostFromSocket: Received post data without an ID. Cannot update. Data: $updatedPostData');
      return;
    }

    try {
      int postIndex = posts.indexWhere((p) => p['_id'] == postId);
      if (postIndex != -1) {
        // Ensure count fields are derived correctly from the updated post data's arrays
        // before replacing the local post.
        Map<String, dynamic> processedPostData = Map<String, dynamic>.from(updatedPostData);
        processedPostData['likesCount'] = (processedPostData['likes'] as List?)?.length ?? 0;
        processedPostData['repostsCount'] = (processedPostData['reposts'] as List?)?.length ?? 0;
        processedPostData['viewsCount'] = (processedPostData['views'] as List?)?.length ?? 0;
        // If the backend also sends counts directly (e.g. viewsCount from a view event),
        // we can prioritize that if needed, but deriving from the array length is safer if the array is the source of truth.
        // For 'postViewed' specifically, if it only sends 'viewsCount' and not the full 'views' array,
        // then `fetchSinglePost` (next step) will be more robust.
        // For now, this method assumes the socket event provides the full updated post, including arrays.

        posts[postIndex] = processedPostData;
        posts.refresh(); // Force UI update
        print('[DataController] Post $postId updated from socket event.');
      } else {
        print('[DataController] updatePostFromSocket: Post with ID $postId not found in local list. It might be a new post not yet added or an issue with ID matching.');
        // Optionally, if it's a new post (e.g. from another user), we might want to add it here
        // addNewPost(updatedPostData); // Consider if this is appropriate or if new posts are handled by a different event
      }
    } catch (e) {
      print('[DataController] Error updating post $postId from socket: $e. Data: $updatedPostData');
    }
  }


  // The old updatePostViews method is now removed.
  // View updates are handled by the postViewed socket event triggering fetchSinglePost,
  // which then calls updatePostFromSocket with the full, authoritative post data.


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