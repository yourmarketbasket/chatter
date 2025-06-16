import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart' as dio; // Use prefix for dio to avoid conflicts
import 'dart:convert';
import 'package:path/path.dart' as path;

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
      // print(response.data);
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
          await _storage.write(
            key: 'token',
            value: response.data['user']['token']?.toString(),
          );
          await _storage.write(
            key: 'user',
            value: jsonEncode(response.data['user']),
          );
          return {'success': true, 'message': 'User logged in successfully'};
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to save user data securely: ${e.toString()}'
          };
        }
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

  Future<List<Map<String, dynamic>>> uploadFilesToCloudinary(List<File> files) async {
    // print('[DataController uploadFilesToCloudinary] Received ${files.length} files for upload.');

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
          // print('[DataController uploadFilesToCloudinary] File does not exist: $filePath');
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
          // print('[DataController uploadFilesToCloudinary] Empty file: $filePath');
          results.add({
            'success': false,
            'message': 'Empty file: $filePath',
            'filePath': filePath,
            'progress': 0.0,
          });
          continue;
        }

        // print('[DataController uploadFilesToCloudinary] Processing file: path=$filePath, size=$fileSize bytes');

        // Determine resource type
        final fileExtension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
        final resourceType = extensionToResourceType[fileExtension] ?? 'auto';
        // print('[DataController uploadFilesToCloudinary] File: $filePath, extension: $fileExtension, resource_type: $resourceType');

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
            // print('[DataController uploadFilesToCloudinary] Upload progress for $filePath: ${uploadProgress.toStringAsFixed(2)}%');
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
          // print('[DataController uploadFilesToCloudinary] Successfully uploaded: $filePath, URL: ${response.data['secure_url']}');
        } else {
          final errorMessage = response.data?['error']?['message'] ?? 'Upload failed with status: ${response.statusCode}';
          // print('[DataController uploadFilesToCloudinary] Upload failed for $filePath: $errorMessage');
          results.add({
            'success': false,
            'message': errorMessage,
            'filePath': filePath,
            'progress': uploadProgress,
          });
        }
      } catch (e, stackTrace) {
        // print('[DataController uploadFilesToCloudinary] Exception for $filePath: $e\n$stackTrace');
        results.add({
          'success': false,
          'message': 'Upload failed for $filePath: ${e.toString()}',
          'filePath': filePath,
          'progress': 0.0,
        });
      }
    }

    // print('[DataController uploadFilesToCloudinary] Upload completed. Results: ${results.length} files processed.');
    return results;
  }
}