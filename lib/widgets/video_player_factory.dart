import 'dart:io';
import 'package:chatter/services/device_info_service.dart';
import 'package:chatter/widgets/better_player_widget.dart';
import 'package:chatter/widgets/video_player_widget.dart';
import 'package:flutter/material.dart';

class VideoPlayerFactory {
  static Future<Widget> createPlayer({
    String? url,
    File? file,
    String? thumbnailUrl,
    required String displayPath,
    bool isFeedContext = false,
    double? videoAspectRatioProp,
  }) async {
    int sdkVersion = await DeviceInfoService.getAndroidSDKVersion();

    if (Platform.isAndroid && sdkVersion < 33) { // Android 13 is API level 33
      return BetterPlayerWidget(
        url: url,
        file: file,
        thumbnailUrl: thumbnailUrl,
        displayPath: displayPath,
        isFeedContext: isFeedContext,
        videoAspectRatioProp: videoAspectRatioProp,
      );
    } else {
      return VideoPlayerWidget(
        url: url,
        file: file,
      );
    }
  }
}
