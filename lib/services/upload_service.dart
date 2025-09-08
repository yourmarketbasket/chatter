import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'compression_service.dart'; // Import the new compression service

class UploadService {
  final dio.Dio _dio = dio.Dio(dio.BaseOptions(
    // Assuming you might want a generic dio instance or specific for uploads
    // Adjust timeouts as necessary for file uploads
    connectTimeout: const Duration(seconds: 60), // Longer for potential larger files
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
  ));
  final CompressionService _compressionService = CompressionService(); // Instantiate CompressionService

  Future<List<Map<String, dynamic>>> uploadFilesToCloudinary(
    List<Map<String, dynamic>> attachmentsData,
    Function(int sentBytes, int totalBytes) onProgress,
  ) async {
    print('[UploadService uploadFilesToCloudinary] Received ${attachmentsData.length} attachments for upload.');

    if (attachmentsData.isEmpty) {
      // If there are no attachments, report completion of this phase immediately.
      onProgress(0, 0); // Indicates no data to send, effectively 100% of "nothing"
      return []; // Return empty list as no files were processed.
    }

    List<Map<String, dynamic>> results = [];
    int grandTotalBytes = 0;
    int cumulativeSentBytes = 0;

    // Calculate grandTotalBytes first
    for (var attachmentMap in attachmentsData) {
      final File file = attachmentMap['file'] as File;
      if (await file.exists()) {
        grandTotalBytes += await file.length();
      }
    }

    // If grandTotalBytes is 0 (e.g., all files are empty or don't exist),
    // report progress as complete for the upload phase.
    if (grandTotalBytes == 0 && attachmentsData.isNotEmpty) {
        onProgress(0,0); // Or onProgress(1,1) to signify completion of an empty task.
                         // DataController handles 0 totalBytes by not dividing.
        // Still proceed to return failure messages for each non-existent/empty file.
    }


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

    for (Map<String, dynamic> attachmentMap in attachmentsData) {
      final File originalFile = attachmentMap['file'] as File;
      final originalFilePath = originalFile.path;
      final int? width = attachmentMap['width'] as int?;
      final int? height = attachmentMap['height'] as int?;
      final String? orientation = attachmentMap['orientation'] as String?;
      final int? duration = attachmentMap['duration'] as int?; // For videos
      final String? aspectRatio = attachmentMap['aspectRatio'] as String?; // Extract aspectRatio
      final String attachmentType = attachmentMap['type'] as String? ?? 'unknown'; // e.g., 'image', 'video', 'audio', 'document'


      File fileToUpload = originalFile; // Initialize with original file
      int originalFileSize = await originalFile.length();
      String? uploadedThumbnailUrl;
      File? tempThumbnailFile; // To keep track of thumbnail file for deletion

      try {
        // --- Call CompressionService ---
        if (kDebugMode) {
          print('[UploadService] Attempting compression for ${originalFile.path} of type $attachmentType');
        }
        File compressedFile = await _compressionService.compressFile(originalFile, attachmentType);
        if (compressedFile.path != originalFile.path) {
          if (kDebugMode) {
            print('[UploadService] Compression successful. Original size: $originalFileSize, Compressed size: ${await compressedFile.length()}');
          }
          fileToUpload = compressedFile;
        } else {
          if (kDebugMode) {
            print('[UploadService] Compression did not reduce size or was not applied. Using original file.');
          }
          fileToUpload = originalFile; // Ensure it's set back if no compression occurred or was worse
        }
        // --- End CompressionService call ---


        if (!await fileToUpload.exists()) { // Check existence of the file we intend to upload
          print('[UploadService uploadFilesToCloudinary] File does not exist: $originalFilePath');
          results.add({
            'success': false,
            'message': 'File does not exist: $originalFilePath',
            'filePath': originalFilePath,
            'progress': 0.0,
            'width': width, // Carry over metadata even on early failure
            'height': height,
            'orientation': orientation,
            'duration': duration,
            'aspectRatio': aspectRatio, // Carry over aspectRatio
            'type': attachmentType, // Use 'type' from attachmentMap as primary type
            'filename': path.basename(originalFilePath),
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
            'width': width,
            'height': height,
            'orientation': orientation,
            'duration': duration,
            'aspectRatio': aspectRatio, // Carry over aspectRatio
            'type': attachmentType,
            'filename': path.basename(originalFilePath),
          });
          continue;
        }

        print('[UploadService uploadFilesToCloudinary] Processing file: path=$originalFilePath, size=$originalFileSize bytes, type: $attachmentType, width: $width, height: $height, orientation: $orientation, duration: $duration, aspectRatio: $aspectRatio');

        final fileExtension = path.extension(originalFilePath).toLowerCase().replaceFirst('.', '');
        final resourceType = extensionToResourceType[fileExtension] ?? 'auto'; // Cloudinary resource type
        print('[UploadService uploadFilesToCloudinary] File: $originalFilePath, extension: $fileExtension, attachmentType: $attachmentType, cloudinary_resource_type: $resourceType');

        // Thumbnail generation for videos. This should happen AFTER our CompressionService has run.
        // The fileToUpload variable now holds the (potentially) compressed file.
        if (attachmentType == 'video') { // Check against the type determined by app logic
          try {
            final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
              video: fileToUpload.path, // Use the file determined by CompressionService
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
                'upload_preset': 'testpreset1', // Your Cloudinary upload preset
                'resource_type': 'image', // Thumbnails are images
              });
              final thumbResponse = await _dio.post(
                'https://api.cloudinary.com/v1_1/dxhz5k4zz/image/upload', // Replace YOUR_CLOUD_NAME
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
          'upload_preset': 'testpreset1',
          'resource_type': resourceType,
          'filename_override': path.basename(originalFilePath),
        });

        // This local 'uploadProgress' variable is not used for the callback, so it can be removed.
        // double uploadProgress = 0.0;

        final int finalFileSize = await fileToUpload.length(); // Size of the file that was actually uploaded

        // Corrected: This is the main file upload call.
        final dio.Response response = await _dio.post( // Explicitly type response
          'https://api.cloudinary.com/v1_1/dxhz5k4zz/$resourceType/upload',
          data: formData,
          options: dio.Options(
            validateStatus: (status) => status != null && status >= 200 && status < 500,
          ),
          onSendProgress: (sent, total) {
            if (total > 0) {
              onProgress(cumulativeSentBytes + sent, grandTotalBytes);
            }
          },
        );
        // testing comment

        // After this file is uploaded (successfully or not), add its total size to cumulativeSentBytes
        // This ensures the next file's progress is calculated correctly relative to the grand total.
        // If the upload failed mid-way, currentFileSentBytesForProgress will be less than finalFileSize.
        // For simplicity in cumulative tracking, we add finalFileSize if successful,
        // or the last known sent amount if failed.
        // However, it's more robust to add finalFileSize to cumulativeSentBytes *after* a successful upload,
        // and rely on the onSendProgress callback to have reported the final sent bytes for a failed one.

        if (response.statusCode == 200 && response.data != null) {
          cumulativeSentBytes += finalFileSize; // Add successfully uploaded file's size
          onProgress(cumulativeSentBytes, grandTotalBytes); // Ensure final progress for this file is reported

          results.add({
            'success': true,
            'url': response.data['secure_url'] as String? ?? '',
            'thumbnailUrl': uploadedThumbnailUrl,
            'size': response.data['bytes'] as int? ?? finalFileSize,
            'type': attachmentType,
            'filename': response.data['original_filename'] as String? ?? path.basename(originalFilePath),
            'filePath': originalFilePath,
            // 'progress': 100.0, // No longer individual progress here
            'resource_type': response.data['resource_type'] as String? ?? resourceType,
            'width': width,
            'height': height,
            'orientation': orientation,
            'duration': duration,
            'aspectRatio': aspectRatio,
          });
          print('[UploadService uploadFilesToCloudinary] Successfully uploaded: $originalFilePath, URL: ${response.data['secure_url']}, Thumbnail: $uploadedThumbnailUrl');
        } else {
          // Don't add to cumulativeSentBytes if it failed, as onSendProgress would have reported the last state.
          // If onSendProgress didn't fire (e.g. network error before sending), cumulativeSentBytes remains unchanged for this file.
          final errorMessage = response.data?['error']?['message'] ?? 'Upload failed with status: ${response.statusCode}';
          print('[UploadService uploadFilesToCloudinary] Upload failed for $originalFilePath: $errorMessage');
          results.add({
            'success': false,
            'message': errorMessage,
            'filePath': originalFilePath,
            // 'progress': uploadProgress, // No longer individual progress
            'thumbnailUrl': uploadedThumbnailUrl,
            'type': attachmentType,
            'filename': path.basename(originalFilePath),
            'width': width,
            'height': height,
            'orientation': orientation,
            'duration': duration,
            'aspectRatio': aspectRatio,
          });
        }
      } catch (e, stackTrace) {
        // Similar to failure, don't add to cumulativeSentBytes for exceptions.
        print('[UploadService uploadFilesToCloudinary] Exception for $originalFilePath: $e\n$stackTrace');
        results.add({
          'success': false,
          'message': 'Upload failed for $originalFilePath: ${e.toString()}',
          'filePath': originalFilePath,
          // 'progress': 0.0, // No longer individual progress
          'thumbnailUrl': uploadedThumbnailUrl,
          'type': attachmentType,
          'filename': path.basename(originalFilePath),
          'width': width,
          'height': height,
          'orientation': orientation,
          'duration': duration,
          'aspectRatio': aspectRatio,
        });
      } finally {
        // Cleanup: Delete the file that was uploaded if it's a temporary compressed file.
        // The CompressionService creates files in a temporary directory.
        bool isTempCompressedFile = fileToUpload.path != originalFile.path && fileToUpload.path.contains((await getTemporaryDirectory()).path);

        if (isTempCompressedFile && await fileToUpload.exists()) {
          try {
            await fileToUpload.delete();
            if (kDebugMode) {
              print('[UploadService] Deleted temporary compressed file from CompressionService: ${fileToUpload.path}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('[UploadService] Error deleting temporary compressed file ${fileToUpload.path}: $e');
            }
          }
        }

        // Cleanup: Delete temporary thumbnail file
        if (tempThumbnailFile != null && await tempThumbnailFile.exists()) {
          try {
            await tempThumbnailFile.delete();
            if (kDebugMode) {
              print('[UploadService uploadFilesToCloudinary] Deleted temporary thumbnail file: ${tempThumbnailFile.path}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('[UploadService uploadFilesToCloudinary] Error deleting temporary thumbnail file ${tempThumbnailFile.path}: $e');
            }
          }
        }
      }
    }
    if (kDebugMode) {
      print('[UploadService uploadFilesToCloudinary] Upload completed. Results: ${results.length} files processed.');
    }
    return results;
  }

  // Call this method to clean up the Dio instance when the service is no longer needed.
  void dispose() {
    _dio.close();
    VideoCompress.dispose(); // Clean up VideoCompress resources
  }
}
