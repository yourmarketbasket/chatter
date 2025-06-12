import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;

class DataController extends GetxController {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  // url
  final String baseUrl = 'https://chatter-api.fly.dev/';
  final Dio _dio = Dio();

  @override
  void onInit() {
    super.onInit();
    // No write operation needed here; storage options are set in constructor
  }

  // create post
  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    try {
      var response = await _dio.post(
        '${baseUrl}api/posts',
        data: data,
      );
      if (response.statusCode == 201 && response.data['success'] == true) {
        return {'success': true, 'message': 'Post created successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Post creation failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // register user
  Future<Map<String, dynamic>> registerUser(Map<String, String> data) async {
    try {
      // send data to server using dio
      var response = await _dio.post(
        '${baseUrl}api/auth/register',
        data: data,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return {'success': true, 'message': 'User registered successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // login user
  Future<Map<String, dynamic>> loginUser(Map<String, String> data) async {
    try {
      // send data to server using dio
      var response = await _dio.post(
        '${baseUrl}api/auth/login',
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
            value: jsonEncode(response.data['user']), // Serialize user data to JSON
          );
          return {'success': true, 'message': 'User logged in successfully'};
        } catch (e) {
          return {'success': false, 'message': 'Failed to save user data securely: ${e.toString()}'};
        }
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  

  Future<List<Map<String, dynamic>>> uploadFilesToCloudinary(List<File> files) async {
    final Dio dio = Dio();

    // Validate input
    if (files.isEmpty) {
      return [{'success': false, 'message': 'No files provided'}];
    }

    List<Map<String, dynamic>> results = [];

    try {
      for (File file in files) {
        // Validate file
        if (!await file.exists()) {
          results.add({
            'success': false,
            'message': 'Non-existent file: ${file.path}',
            'filePath': file.path,
            'progress': 0.0,
          });
          continue;
        }

        try {
          double uploadProgress = 0.0;
          String fileExtension = path.extension(file.path).toLowerCase().replaceFirst('.', '');
          String filePath = file.path; // Store for logging
          // Determine resource type based on file extension
          String resourceType;
          if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension)) {
            resourceType = 'image';
          } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(fileExtension)) {
            resourceType = 'video';
          } else if (['m4a', 'mp3', 'wav', 'aac', 'ogg'].contains(fileExtension)) { // Added audio types
            resourceType = 'video'; // Cloudinary uses 'video' for audio
          } else if (['pdf', 'doc', 'docx', 'txt'].contains(fileExtension)) {
            resourceType = 'raw';
          } else {
            resourceType = 'auto'; // Let Cloudinary decide
          }

          print('Cloudinary Upload: Preparing to upload $filePath, extension: $fileExtension, resource_type: $resourceType');

          var formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              file.path,
              filename: path.basename(file.path),
            ),
            'upload_preset': 'ml_default', // Replace with your Cloudinary upload preset
            'resource_type': resourceType,
          });

          var response = await dio.post(
            'https://api.cloudinary.com/v1_1/djg6xjdrq/$resourceType/upload', // Replace with your Cloudinary cloud name
            data: formData,
            options: Options(
              validateStatus: (status) => status != null && status < 500,
            ),
            onSendProgress: (int sent, int total) {
              uploadProgress = (sent / total) * 100;
            },
          );

          if (response.statusCode == 200) {
            results.add({
              'success': true,
              'url': response.data['secure_url'] as String,
              'size': response.data['bytes'] as int,
              'filetype': response.data['format'] as String? ?? fileExtension,
              'filePath': file.path,
              'progress': uploadProgress,
              'resource_type': response.data['resource_type'] as String,
            });
          } else {
            print('Cloudinary Upload Error for $filePath: ${response.data}');
            results.add({
              'success': false,
              'message': response.data['message'] ?? 'Upload failed for $filePath',
              'filePath': filePath,
              'progress': uploadProgress,
            });
          }
        } catch (e) {
          print('Cloudinary Upload Exception for $filePath: ${e.toString()}');
          results.add({
            'success': false,
            'message': 'Upload failed for $filePath: ${e.toString()}',
            'filePath': filePath,
            'progress': 0.0,
          });
        }
      }
    } catch (e) {
      results.add({
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
        'progress': 0.0,
      });
    }

    return results;
  }
}