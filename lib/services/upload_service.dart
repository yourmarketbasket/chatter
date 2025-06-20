import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class UploadService {
  final dio.Dio _dio = dio.Dio(dio.BaseOptions(
    // Assuming you might want a generic dio instance or specific for uploads
    // Adjust timeouts as necessary for file uploads
    connectTimeout: const Duration(seconds: 60), // Longer for potential larger files
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
  ));

  Future<List<Map<String, dynamic>>> uploadFilesToCloudinary(List<File> files) async {
    print('[UploadService uploadFilesToCloudinary] Received ${files.length} files for upload.');

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
      'm4a': 'video', // Often audio, but Cloudinary might class as video for processing
      'mp3': 'video', // Same as above
      'wav': 'video', // Same as above
      'aac': 'video', // Same as above
      'ogg': 'video', // Same as above
      'pdf': 'raw',   // For documents
      'doc': 'raw',
      'docx': 'raw',
      'txt': 'raw',
    };

    final Set<String> videoExtensionsForCompression = {'mp4', 'mov', 'avi', 'mkv', 'webm'};

    for (File originalFile in files) {
      final originalFilePath = originalFile.path;
      File fileToUpload = originalFile; // By default, upload the original file
      int originalFileSize = await originalFile.length();
      String? uploadedThumbnailUrl;
      File? tempThumbnailFile; // To keep track of thumbnail file for deletion

      try {
        if (!await originalFile.exists()) {
          print('[UploadService uploadFilesToCloudinary] File does not exist: $originalFilePath');
          results.add({
            'success': false,
            'message': 'File does not exist: $originalFilePath',
            'filePath': originalFilePath,
            'progress': 0.0,
          });
          continue;
        }

        if (originalFileSize == 0) {
          print('[UploadService uploadFilesToCloudinary] Empty file: $originalFilePath');
          results.add({
            'success': false,
            'message': 'Empty file: $originalFilePath',
            'filePath': originalFilePath,
            'progress': 0.0,
          });
          continue;
        }

        print('[UploadService uploadFilesToCloudinary] Processing file: path=$originalFilePath, size=$originalFileSize bytes');

        final fileExtension = path.extension(originalFilePath).toLowerCase().replaceFirst('.', '');
        final resourceType = extensionToResourceType[fileExtension] ?? 'auto';
        print('[UploadService uploadFilesToCloudinary] File: $originalFilePath, extension: $fileExtension, resource_type: $resourceType');

        if (videoExtensionsForCompression.contains(fileExtension)) {
          // Compress Video
          MediaInfo? mediaInfo;
          try {
            mediaInfo = await VideoCompress.compressVideo(
              originalFilePath,
              quality: VideoQuality.MediumQuality,
              deleteOrigin: false, // Keep original for fallback and thumbnail generation
              includeAudio: true,
            );
            if (mediaInfo?.file != null) {
              fileToUpload = mediaInfo!.file!;
              print('Video compressed: original_size=${originalFileSize}B, new_size=${fileToUpload.lengthSync()}B');
            } else {
              print('[UploadService uploadFilesToCloudinary] Video compression failed, using original: $originalFilePath');
            }
          } catch (e) {
            print('[UploadService uploadFilesToCloudinary] Error compressing video $originalFilePath: $e. Using original.');
          }

          // Generate Thumbnail
          try {
            final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
              video: fileToUpload.path, // Use compressed video path if available, else original
              thumbnailPath: (await getTemporaryDirectory()).path,
              imageFormat: ImageFormat.PNG,
              maxHeight: 300,
              quality: 75,
            );
            if (thumbnailPath != null) {
              tempThumbnailFile = File(thumbnailPath);
              if (kDebugMode) {
                print('[UploadService uploadFilesToCloudinary] Thumbnail generated for $originalFilePath at $thumbnailPath, size: ${tempThumbnailFile.lengthSync()}B');
              }

              // Upload thumbnail
              final thumbnailFormData = dio.FormData.fromMap({
                'file': await dio.MultipartFile.fromFile(
                  tempThumbnailFile.path,
                  filename: path.basename(tempThumbnailFile.path),
                ),
                'upload_preset': 'chatterpiks', // Your Cloudinary upload preset
                'resource_type': 'image', // Thumbnails are images
              });
              final thumbResponse = await _dio.post(
                'https://api.cloudinary.com/v1_1/djg6xjdrq/image/upload', // Replace YOUR_CLOUD_NAME
                data: thumbnailFormData,
                 options: dio.Options(
                    validateStatus: (status) => status != null && status >= 200 && status < 500,
                 ),
              );
              if (thumbResponse.statusCode == 200 && thumbResponse.data != null) {
                uploadedThumbnailUrl = thumbResponse.data['secure_url'] as String?;
                print('[UploadService uploadFilesToCloudinary] Thumbnail uploaded for $originalFilePath: $uploadedThumbnailUrl');
              } else {
                print('[UploadService uploadFilesToCloudinary] Thumbnail upload failed for $originalFilePath: ${thumbResponse.data?['error']?['message']}');
              }
            }
          } catch (e) {
            print('[UploadService uploadFilesToCloudinary] Error generating or uploading thumbnail for $originalFilePath: $e');
          }
        }

        // Prepare main file form data (original or compressed)
        final formData = dio.FormData.fromMap({
          'file': await dio.MultipartFile.fromFile(
            fileToUpload.path,
            filename: path.basename(originalFilePath), // Use original filename
          ),
          'upload_preset': 'chatterpiks',
          'resource_type': resourceType,
        });

        double uploadProgress = 0.0;
        final response = await _dio.post(
          'https://api.cloudinary.com/v1_1/djg6xjdrq/$resourceType/upload', // Replace YOUR_CLOUD_NAME
          data: formData,
          options: dio.Options(
            validateStatus: (status) => status != null && status >= 200 && status < 500,
          ),
          onSendProgress: (sent, total) {
            if (total > 0) {
              uploadProgress = (sent / total * 100).clamp(0.0, 100.0);
              // Optional: more detailed progress logging if needed
            }
          },
        );

        final int finalFileSize = await fileToUpload.length(); // Size of the file that was actually uploaded

        if (response.statusCode == 200 && response.data != null) {
          results.add({
            'success': true,
            'url': response.data['secure_url'] as String? ?? '',
            'thumbnailUrl': uploadedThumbnailUrl, // Add thumbnail URL here
            'size': response.data['bytes'] as int? ?? finalFileSize,
            'type': response.data['format'] as String? ?? fileExtension,
            'filename': response.data['original_filename'] as String? ?? path.basename(originalFilePath),
            'filePath': originalFilePath, // Path of the original file
            'progress': 100.0,
            'resource_type': response.data['resource_type'] as String? ?? resourceType,
          });
          print('[UploadService uploadFilesToCloudinary] Successfully uploaded: $originalFilePath, URL: ${response.data['secure_url']}, Thumbnail: $uploadedThumbnailUrl');
        } else {
          final errorMessage = response.data?['error']?['message'] ?? 'Upload failed with status: ${response.statusCode}';
          print('[UploadService uploadFilesToCloudinary] Upload failed for $originalFilePath: $errorMessage');
          results.add({
            'success': false,
            'message': errorMessage,
            'filePath': originalFilePath,
            'progress': uploadProgress,
            'thumbnailUrl': uploadedThumbnailUrl, // Still include if thumbnail succeeded but main file failed
          });
        }
      } catch (e, stackTrace) {
        print('[UploadService uploadFilesToCloudinary] Exception for $originalFilePath: $e\n$stackTrace');
        results.add({
          'success': false,
          'message': 'Upload failed for $originalFilePath: ${e.toString()}',
          'filePath': originalFilePath,
          'progress': 0.0,
          'thumbnailUrl': uploadedThumbnailUrl, // Include if available even on main error
        });
      } finally {
        // Cleanup: Delete compressed file if it's different from original and not null
        if (fileToUpload.path != originalFilePath && await fileToUpload.exists()) {
            // This check is a bit problematic because VideoCompress library might manage its own cache.
            // If mediaInfo.deleteOrigin = true was used, this wouldn't be needed.
            // For now, let's assume VideoCompress cleans its own temp files or stores them in a cache.
            // If we created fileToUpload from mediaInfo.file, and deleteOrigin was false,
            // then mediaInfo.file points to a temporary location.
            // The VideoCompress documentation should be consulted for its temporary file management.
            // For safety, if we are sure `fileToUpload` is a temporary compressed file we created, we'd delete it.
            // await fileToUpload.delete();
            // print('[UploadService uploadFilesToCloudinary] Deleted temporary compressed file: ${fileToUpload.path}');
        }
        // Cleanup: Delete temporary thumbnail file
        if (tempThumbnailFile != null && await tempThumbnailFile.exists()) {
          try {
            await tempThumbnailFile.delete();
            if (kDebugMode) {
              print('[UploadService uploadFilesToCloudinary] Deleted temporary thumbnail file: ${tempThumbnailFile.path}');
            }
          } catch (e) {
            print('[UploadService uploadFilesToCloudinary] Error deleting temporary thumbnail file ${tempThumbnailFile.path}: $e');
          }
        }
      }
    }

    print('[UploadService uploadFilesToCloudinary] Upload completed. Results: ${results.length} files processed.');
    return results;
  }

  // Call this method to clean up the Dio instance when the service is no longer needed.
  void dispose() {
    _dio.close();
    VideoCompress.dispose(); // Clean up VideoCompress resources
  }
}
