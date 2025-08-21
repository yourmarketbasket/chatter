import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/data-controller.dart';

class RateLimitInterceptor extends Interceptor {
  bool _isDialogVisible = false;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 429) {
      if (!_isDialogVisible) {
        _isDialogVisible = true;
        _showRateLimitDialog();
      }
      // We are not calling handler.next(err) because we want to swallow the error
      // and let the user handle it via the dialog.
      // If you wanted to propagate the error after showing the dialog, you would call handler.next(err).
      return;
    }
    super.onError(err, handler);
  }

  void _showRateLimitDialog() {
    final DataController dataController = Get.find<DataController>();

    Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // Make it non-dismissible
        child: AlertDialog(
          title: const Text('Too Many Requests'),
          content: const Text('You have made too many requests. Please wait a moment and try again.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Refresh'),
              onPressed: () async {
                try {
                  // Attempt to refresh the FCM token
                  String? fcmToken = await FirebaseMessaging.instance.getToken();
                  if (fcmToken != null) {
                    await dataController.updateFcmToken(fcmToken);
                  } else {
                    // Handle case where FCM token is null
                    Get.snackbar(
                      'Error',
                      'Could not retrieve FCM token. Please try again.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                    return;
                  }

                  // If the refresh is successful, close the dialog
                  if (_isDialogVisible) {
                    Get.back();
                    _isDialogVisible = false;
                  }
                } catch (e) {
                  // If refreshing the token also fails with a 429, the dialog remains open.
                  // You might want to show a message to the user here.
                  if (e is DioException && e.response?.statusCode == 429) {
                    // Optionally, show a snackbar or update the dialog content
                    Get.snackbar(
                      'Still Rate Limited',
                      'Please wait a bit longer before trying to refresh again.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } else {
                    // Handle other errors during token refresh if necessary
                    Get.snackbar(
                      'Error',
                      'An unexpected error occurred while trying to refresh.',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }
}
