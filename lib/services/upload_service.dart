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
      final String attachmentType = attachmentMap['type'] as String? ?? 'unknown';


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
        int currentFileSentBytesForProgress = 0; // For this specific file's progress reporting

        final response = await _dio.post(
          'https://api.cloudinary.com/v1_1/djg6xjdrq/$resourceType/upload', // Replace YOUR_CLOUD_NAME
          data: formData,
          options: dio.Options(
            validateStatus: (status) => status != null && status >= 200 && status < 500,
          ),
          onSendProgress: (sent, total) {
            if (total > 0) {
              currentFileSentBytesForProgress = sent;
              onProgress(cumulativeSentBytes + currentFileSentBytesForProgress, grandTotalBytes);
              // uploadProgress = (sent / total * 100).clamp(0.0, 100.0); // This is per-file progress
            }
          },
        );

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
