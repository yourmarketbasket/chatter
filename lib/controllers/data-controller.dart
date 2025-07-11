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

  // For User's Posts Page
  final RxList<Map<String, dynamic>> userPosts = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingUserPosts = false.obs;

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
        'api/users/get-all-users/$currentUserId', // Appending currentUserId as per common REST practice for parameters in path
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['users'] != null && response.data['users'] is List) {
          List<dynamic> fetchedUsersDynamic = response.data['users'];
          // Process users: ensure all necessary fields are present and correctly typed.
          // Add 'isFollowingCurrentUser' based on the main user's following list.
          final List<String> currentUserFollowingIds = List<String>.from(
            (user.value['user']?['following'] as List<dynamic>? ?? []).map((e) => e.toString())
          );

          List<Map<String, dynamic>> fetchedUsers = fetchedUsersDynamic.map((userData) {
            if (userData is Map<String, dynamic>) {
              // Ensure required fields (avatar, username, followers, following)
              // The backend should provide followersCount and followingCount directly.
              // For 'isFollowingCurrentUser', we check if the user's ID is in the current user's following list.
              String userId = userData['_id']?.toString() ?? '';
              bool isFollowing = currentUserFollowingIds.contains(userId);

              return {
                '_id': userId,
                'avatar': userData['avatar']?.toString() ?? '',
                'username': userData['username']?.toString() ?? 'N/A',
                'name': userData['name']?.toString() ?? 'Unknown User', // Added name for consistency
                'followersCount': userData['followersCount'] ?? 0,
                'followingCount': userData['followingCount'] ?? 0,
                'isFollowingCurrentUser': isFollowing, // Determine if current user is following this user
                // Add other fields if the API provides them and they are needed
              };
            }
            return <String, dynamic>{}; // Return empty map for invalid data
          }).where((userMap) => userMap.isNotEmpty && userMap['_id'] != currentUserId).toList(); // Filter out empty maps and the current user

          allUsers.assignAll(fetchedUsers);
          print('[DataController] Fetched all users successfully. Count: ${allUsers.length}');
        } else {
          allUsers.clear();
          print('[DataController] Fetched all users but the user list is null or not a list.');
          throw Exception('User list not found in response or invalid format.');
        }
      } else {
        allUsers.clear();
        print('[DataController] Failed to fetch all users. Status: ${response.statusCode}, Message: ${response.data?['message']}');
        throw Exception('Failed to fetch all users: ${response.data?['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
      allUsers.clear(); // Clear on error
      print('[DataController] Error in fetchAllUsers: ${e.toString()}');
      // Optionally rethrow or handle as per UI requirements (e.g., show snackbar)
      // For now, UsersListPage will show an error based on allUsers being empty + isLoading false.
    } finally {
      isLoading.value = false; // Reset loading state
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
      uploadProgress.value = -1; // Indicate error state
      String errorMessage = e.toString();
      if (e is dio.DioException && e.response?.data != null && e.response!.data['message'] != null) {
        errorMessage = 'Failed to create post: ${e.response!.data['message']}';
      } else if (e is dio.DioException) {
        errorMessage = 'Failed to create post: ${e.message ?? e.toString()}';
      }
      print('[DataController] Error creating post: $errorMessage');
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
          // print('[DataController] Reply $replyId in post $postId updated with data: $updateData.');
        } else {
          print('[DataController] handleReplyUpdate: Target reply $replyId not found in post $postId.');
          // Optionally, fetch the post as a fallback
          // fetchSinglePost(postId);
        }
      } else {
        print('[DataController] handleReplyUpdate: Post $postId not found.');
      }
    } catch (e) {
      print('[DataController] Error handling reply update for reply $replyId in post $postId: $e');
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
          print('[DataController] New nested reply added to reply $parentReplyId in post $postId.');
        } else {
          print('[DataController] handleNewReplyToReply: Parent reply $parentReplyId not found in post $postId.');
          // Optionally, fetch the post as a fallback if consistency is critical
          // fetchSinglePost(postId);
        }
      } else {
        print('[DataController] handleNewReplyToReply: Post $postId not found.');
      }
    } catch (e) {
      print('[DataController] Error handling new reply to reply for post $postId: $e');
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
        // Fetch the full post to ensure data consistency
        await fetchSinglePost(postId);
        return {'success': true, 'message': response.data['message'] ?? 'Post liked successfully'};
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
      print('[DataController] Error reposting post $postId: $e');
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

    return processedItem;
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
        List<Map<String, dynamic>> fetchedPostsRaw = List<Map<String, dynamic>>.from(response.data['posts']);
        List<Map<String, dynamic>> processedFetchedPosts = [];
        for (var postData in fetchedPostsRaw) {
          processedFetchedPosts.add(_processPostOrReply(postData));
        }
        posts.assignAll(processedFetchedPosts);
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
        // print("[DataController] Raw replies data from API for post $postId: ${response.data}");
        final List<dynamic> repliesData = response.data['replies'];
        List<Map<String, dynamic>> processedReplies = [];

        for (var replyData in repliesData) {
          if (replyData == null || replyData is! Map<String,dynamic>) {
            // print("[DataController] Skipping invalid reply data item: $replyData");
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
        // print("[DataController] Processed replies for post $postId: $processedReplies");
        return processedReplies;
      } else {
        print('[DataController] Error fetching replies for post $postId: ${response.statusCode} - ${response.data?['message']}');
        throw Exception('Failed to fetch replies: ${response.data?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('[DataController] Exception caught in fetchReplies for post $postId: $e');
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
      // print("Warning: Adding a new post without an '_id'. Cannot check for duplicates by ID. Post data: $processedNewPost");
      posts.insert(0, processedNewPost);
      return;
    }

    final bool alreadyExists = posts.any((existingPost) {
      final String? existingPostId = existingPost['_id'] as String?;
      return existingPostId != null && existingPostId == newPostId;
    });

    if (!alreadyExists) {
      posts.insert(0, processedNewPost);
      print("New post with ID $newPostId added to the list.");
    } else {
      print("Post with ID $newPostId already exists in the list. Attempting to update.");
      final int existingPostIndex = posts.indexWhere((p) => (p['_id'] as String?) == newPostId);
      if (existingPostIndex != -1) {
        // Replace with new data, as it might be an update (e.g. from socket)
        posts[existingPostIndex] = processedNewPost;
        posts.refresh();
        print("Updating existing post with ID $newPostId with new data.");
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
    try {
      final String? token = user.value['token'];
      final String? loggedInUserId = user.value['user']?['_id'];

      if (token == null || loggedInUserId == null) {
        followers.clear();
        throw Exception('User not authenticated. Cannot fetch followers.');
      }

      // API call to users/get-followers/:userid
      // userId is the ID of the user whose followers are being requested.
      final response = await _dio.get(
        'api/users/get-followers/$userId',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['followers'] != null && response.data['followers'] is List) {
          List<dynamic> fetchedFollowersDynamic = response.data['followers'];

          final List<String> loggedInUserFollowingIds = List<String>.from(
            (user.value['user']?['following'] as List<dynamic>? ?? []).map((e) => e.toString())
          );

          List<Map<String, dynamic>> processedFollowers = fetchedFollowersDynamic.map((followerData) {
            if (followerData is Map<String, dynamic>) {
              String followerId = followerData['_id']?.toString() ?? '';
              // Determine if the logged-in user is following this follower.
              bool isFollowingThisFollower = loggedInUserFollowingIds.contains(followerId);

              return {
                '_id': followerId,
                'avatar': followerData['avatar']?.toString() ?? '',
                'username': followerData['username']?.toString() ?? 'N/A',
                'name': followerData['name']?.toString() ?? 'Unknown User',
                // The backend should ideally provide 'isFollowingCurrentUser' directly
                // This field indicates if the *currently logged-in user* is following the person in this list item.
                'isFollowingCurrentUser': isFollowingThisFollower,
                // followersCount and followingCount for THIS follower, if provided by backend, useful for their profile preview
                'followersCount': followerData['followersCount'] ?? 0,
                'followingCount': followerData['followingCount'] ?? 0,
              };
            }
            return <String, dynamic>{};
          }).where((userMap) => userMap.isNotEmpty).toList();

          followers.assignAll(processedFollowers);
          print('[DataController] Fetched followers for user $userId successfully. Count: ${followers.length}');
        } else {
          followers.clear();
          print('[DataController] Fetched followers for user $userId but the list is null or not a list.');
          throw Exception('Followers list not found or invalid format.');
        }
      } else {
        followers.clear();
        print('[DataController] Failed to fetch followers for user $userId. Status: ${response.statusCode}, Message: ${response.data?['message']}');
        throw Exception('Failed to fetch followers: ${response.data?['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
      followers.clear();
      print('[DataController] Error in fetchFollowers for user $userId: ${e.toString()}');
      // Rethrow or handle as needed
      rethrow;
    } finally {
      isLoadingFollowers.value = false;
    }
  }

  Future<void> fetchFollowing(String userId) async {
    isLoadingFollowing.value = true;
    try {
      final String? token = user.value['token'];
      final String? loggedInUserId = user.value['user']?['_id'];

      if (token == null || loggedInUserId == null) {
        following.clear();
        throw Exception('User not authenticated. Cannot fetch following list.');
      }

      // API call to users/get-following/:userid
      // userId is the ID of the user whose "following" list is being requested.
      final response = await _dio.get(
        'api/users/get-following/$userId',
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['following'] != null && response.data['following'] is List) {
          List<dynamic> fetchedFollowingDynamic = response.data['following'];

          final List<String> loggedInUserFollowingIds = List<String>.from(
            (user.value['user']?['following'] as List<dynamic>? ?? []).map((e) => e.toString())
          );

          List<Map<String, dynamic>> processedFollowing = fetchedFollowingDynamic.map((followingUserData) {
            if (followingUserData is Map<String, dynamic>) {
              String followingUserId = followingUserData['_id']?.toString() ?? '';
              // Determine if the logged-in user is following this user (who is in the targetUser's following list).
              bool isFollowingThisUser = loggedInUserFollowingIds.contains(followingUserId);

              return {
                '_id': followingUserId,
                'avatar': followingUserData['avatar']?.toString() ?? '',
                'username': followingUserData['username']?.toString() ?? 'N/A',
                'name': followingUserData['name']?.toString() ?? 'Unknown User',
                'isFollowingCurrentUser': isFollowingThisUser, // Critical for button state
                'followersCount': followingUserData['followersCount'] ?? 0, // if available
                'followingCount': followingUserData['followingCount'] ?? 0, // if available
              };
            }
            return <String, dynamic>{};
          }).where((userMap) => userMap.isNotEmpty).toList();

          following.assignAll(processedFollowing);
          print('[DataController] Fetched following list for user $userId successfully. Count: ${following.length}');
        } else {
          following.clear();
          print('[DataController] Fetched following list for user $userId but the list is null or not a list.');
          throw Exception('Following list not found or invalid format.');
        }
      } else {
        following.clear();
        print('[DataController] Failed to fetch following list for user $userId. Status: ${response.statusCode}, Message: ${response.data?['message']}');
        throw Exception('Failed to fetch following list: ${response.data?['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
      following.clear();
      print('[DataController] Error in fetchFollowing for user $userId: ${e.toString()}');
      rethrow;
    } finally {
      isLoadingFollowing.value = false;
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

    print('[DataController] Toggled follow status for $targetUserId to $follow (placeholder).');
  }

  // Add this method to the DataController class
  // some test changes

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
    String? eventPostId = updatedPostData['_id'] as String?;
    if (eventPostId == null) {
      eventPostId = updatedPostData['postId'] as String?; // Check for 'postId'
    }

    if (eventPostId == null) {
      print('[DataController] updatePostFromSocket: Received post data without a usable ID (_id or postId). Cannot update. Data: $updatedPostData');
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
        // print('[DataController] Post $finalPostId updated from socket event. New data: $fullyProcessedUpdatedPost');
      } else {
        // This is a new post not seen before.
        print('[DataController] updatePostFromSocket: Post with ID $finalPostId not found. Assuming new post and adding.');

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
      print('[DataController] Error updating post $finalPostId from socket: $e. Data: $updatedPostData'); // Used finalPostId
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
        print('[DataController] New reply added to post $parentPostId. Post updated.');
      } else {
        print('[DataController] handleNewReply: Parent post with ID $parentPostId not found.');
        // Optionally, fetch the post if it's critical that it should exist
        // fetchSinglePost(parentPostId);
      }
    } catch (e) {
      print('[DataController] Error handling new reply for post $parentPostId: $e');
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
        print('[DataController] Reply to reply successful: ${response.data}');
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
      print('[DataController] Error in replyToReply: $e');
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
        // print('[DataController] Like reply successful, root post $postId fetched: ${response.data}');
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
      print('[DataController] Error in likeReply: $e');
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
        // print('[DataController] Unlike reply successful, root post $postId fetched: ${response.data}');
        return {
          'success': true,
          'message': response.data['message'] ?? 'Reply unliked successfully',
          'likesCount': response.data['likesCount']
        };
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to unlike reply'};
      }
    } catch (e) {
      print('[DataController] Error in unlikeReply: $e');
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
        // print('[DataController] View reply successful: ${response.data}');
        // Socket event 'replyViewed' or similar would ideally update counts if displayed.
        return {'success': true, 'message': response.data['message'] ?? 'Reply viewed successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to view reply'};
      }
    } catch (e) {
      print('[DataController] Error in viewReply: $e');
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
        // print('[DataController] Repost reply successful, root post $postId fetched: ${response.data}');
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
      print('[DataController] Error in repostReply: $e');
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
        // print("[DataController] Raw replies data from API for parent reply $parentReplyId: ${response.data}");
        final List<dynamic> repliesData = response.data['replies'] ?? []; // Default to empty list if null
        List<Map<String, dynamic>> processedReplies = [];

        for (var replyData in repliesData) {
          if (replyData == null || replyData is! Map<String,dynamic>) {
            // print("[DataController] Skipping invalid reply data item for parent reply $parentReplyId: $replyData");
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
        // print("[DataController] Processed replies for parent reply $parentReplyId: $processedReplies");
        return processedReplies;
      } else {
        print('[DataController] Error fetching replies for parent reply $parentReplyId: ${response.statusCode} - ${response.data?['message']}');
        throw Exception('Failed to fetch replies for reply: ${response.data?['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('[DataController] Exception caught in fetchRepliesForReply (parent reply $parentReplyId): $e');
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
      print('[DataController] Error fetching user profile for $username: $e');
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

  Future<Map<String, dynamic>> followUser(String userIdToFollow) async {
    final String? token = user.value['token'];
    final String? currentUserId = user.value['user']?['_id'];

    if (token == null || currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated.'};
    }

    try {
      final response = await _dio.post(
        '/api/users/follow-user', // As per plan, backend needs this route
        data: {
          'thisUserId': currentUserId, // The user performing the action
          'UserToFollowId': userIdToFollow // The user to be followed
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Update local state
        if (user.value['user'] is Map) {
          var userDetail = Map<String, dynamic>.from(user.value['user']);
          var followingList = List<String>.from((userDetail['following'] as List<dynamic>? ?? []).map((e) => e.toString()));
          if (!followingList.contains(userIdToFollow)) {
            followingList.add(userIdToFollow);
          }
          userDetail['following'] = followingList;

          var mainUserMap = Map<String, dynamic>.from(user.value);
          mainUserMap['user'] = userDetail;
          user.value = mainUserMap;
          await _storage.write(key: 'user', value: jsonEncode(user.value));
          user.refresh(); // Notify listeners of the nested change
          print('[DataController] User $currentUserId now following $userIdToFollow. Local state updated.');
        }
        return {'success': true, 'message': response.data['message'] ?? 'Successfully followed user.'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to follow user.'};
      }
    } catch (e) {
      print('[DataController] Error following user $userIdToFollow: $e');
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

    try {
      final response = await _dio.post(
        '/api/users/unfollow-user', // As per plan, backend needs this route
        data: {
          'thisUserId': currentUserId, // The user performing the action
          'UserToUnfollowId': userIdToUnfollow // The user to be unfollowed
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Update local state
        if (user.value['user'] is Map) {
          var userDetail = Map<String, dynamic>.from(user.value['user']);
          var followingList = List<String>.from((userDetail['following'] as List<dynamic>? ?? []).map((e) => e.toString()));
          if (followingList.contains(userIdToUnfollow)) {
            followingList.remove(userIdToUnfollow);
          }
          userDetail['following'] = followingList;

          var mainUserMap = Map<String, dynamic>.from(user.value);
          mainUserMap['user'] = userDetail;
          user.value = mainUserMap;
          await _storage.write(key: 'user', value: jsonEncode(user.value));
          user.refresh(); // Notify listeners of the nested change
          print('[DataController] User $currentUserId now unfollowed $userIdToUnfollow. Local state updated.');
        }
        return {'success': true, 'message': response.data['message'] ?? 'Successfully unfollowed user.'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to unfollow user.'};
      }
    } catch (e) {
      print('[DataController] Error unfollowing user $userIdToUnfollow: $e');
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

  Future<void> fetchUserPosts(String targetUserId) async {
    isLoadingUserPosts.value = true;
    userPosts.clear(); // Clear previous posts

    try {
      final String? token = user.value['token'];
      if (token == null) {
        throw Exception('User not authenticated. Cannot fetch user posts.');
      }

      final response = await _dio.get(
        'api/posts/fetch-user-posts/$targetUserId',
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        if (response.data['posts'] != null && response.data['posts'] is List) {
          List<dynamic> fetchedPostsDynamic = response.data['posts'];
          List<Map<String, dynamic>> processedPosts = fetchedPostsDynamic.map((postData) {
            if (postData is Map<String, dynamic>) {
              // Use the existing _processPostOrReply to ensure consistent data structure
              return _processPostOrReply(postData);
            }
            return <String, dynamic>{};
          }).where((postMap) => postMap.isNotEmpty).toList();

          userPosts.assignAll(processedPosts);
          print('[DataController] Fetched posts for user $targetUserId successfully. Count: ${userPosts.length}');
        } else {
          print('[DataController] Fetched posts for user $targetUserId but the list is null or not a list.');
          // Keep userPosts empty, UI will show empty message
        }
      } else {
        print('[DataController] Failed to fetch posts for user $targetUserId. Status: ${response.statusCode}, Message: ${response.data?['message']}');
        throw Exception('Failed to fetch user posts: ${response.data?['message'] ?? "Unknown server error"}');
      }
    } catch (e) {
      print('[DataController] Error in fetchUserPosts for user $targetUserId: ${e.toString()}');
      // userPosts remains empty, UI will show error/empty message.
      // Rethrow so the calling UI can catch it for specific error messages if needed.
      rethrow;
    } finally {
      isLoadingUserPosts.value = false;
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
          print('[DataController] "About" info updated locally and in storage.');
        }
        return {'success': true, 'message': response.data['message'] ?? 'About information updated successfully.'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to update about information.'};
      }
    } catch (e) {
      print('[DataController] Error updating about info: $e');
      String errorMessage = 'An error occurred while updating about information.';
      if (e is dio.DioException && e.response?.data != null && e.response!.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      } else if (e is dio.DioException) {
        errorMessage = e.message ?? errorMessage;
      }
      return {'success': false, 'message': errorMessage};
    }
  }
}