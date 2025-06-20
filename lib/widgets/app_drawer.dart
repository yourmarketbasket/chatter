import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/users_list_page.dart';
import 'package:chatter/pages/direct_messages_page.dart';
import 'package:chatter/pages/followers_page.dart';
import 'package:chatter/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(FeatherIcons.image, color: Colors.grey[300]),
                title: Text('Pick from Gallery', style: GoogleFonts.roboto(color: Colors.grey[300])),
                onTap: () {
                  Get.back();
                  _handleImageSelection(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(FeatherIcons.camera, color: Colors.grey[300]),
                title: Text('Take a Picture', style: GoogleFonts.roboto(color: Colors.grey[300])),
                onTap: () {
                  Get.back();
                  _handleImageSelection(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(FeatherIcons.xCircle, color: Colors.redAccent),
                title: Text('Cancel', style: GoogleFonts.roboto(color: Colors.redAccent)),
                onTap: () {
                  Get.back();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleImageSelection(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Crop Your Avatar',
              toolbarColor: Colors.teal,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              activeControlsWidgetColor: Colors.tealAccent),
          IOSUiSettings(
            title: 'Crop Your Avatar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rectX: 20,
            rectY: 20,
            rectWidth: 300,
            rectHeight: 300,
          ),
        ],
      );

      if (croppedFile != null) {
        print('Cropped image path: ${croppedFile.path}');
        _handleImageUpload(File(croppedFile.path));
      } else {
        print('Image cropping cancelled.');
        Get.snackbar('Cancelled', 'Image cropping was cancelled.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange[700], colorText: Colors.white);
      }
    } else {
      print('Image picking cancelled.');
      Get.snackbar('Cancelled', 'Image selection was cancelled.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange[700], colorText: Colors.white);
    }
  }

  Future<void> _handleImageUpload(File imageFile) async {
    final DataController dataController = Get.find<DataController>();

    Get.snackbar(
      'Uploading to Cloud...',
      'Please wait while your new avatar is being uploaded.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blueGrey[600],
      colorText: Colors.white,
      showProgressIndicator: true,
      progressIndicatorBackgroundColor: Colors.white,
      progressIndicatorValueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
      isDismissible: false,
    );

    try {
      List<Map<String, dynamic>> cloudinaryUploadResults = await dataController.uploadFiles([imageFile]);

      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }

      if (cloudinaryUploadResults.isNotEmpty && cloudinaryUploadResults[0]['success'] == true) {
        String newCloudinaryAvatarUrl = cloudinaryUploadResults[0]['url'];
        print('Avatar uploaded successfully to Cloudinary: $newCloudinaryAvatarUrl');

        Get.snackbar(
          'Updating Profile...',
          'Saving your new avatar. Please wait.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blueGrey[700],
          colorText: Colors.white,
          showProgressIndicator: true,
          progressIndicatorBackgroundColor: Colors.white,
          progressIndicatorValueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrangeAccent),
          duration: const Duration(seconds: 120),
          isDismissible: false,
        );

        final Map<String, dynamic> backendUpdateResult = await dataController.updateUserAvatar(newCloudinaryAvatarUrl);

        if (Get.isSnackbarOpen) {
          Get.closeCurrentSnackbar();
        }

        if (backendUpdateResult['success'] == true) {
          Get.snackbar(
            'Avatar Updated!',
            backendUpdateResult['message'] ?? 'Your avatar has been successfully updated.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } else {
          print('Backend failed to update avatar: ${backendUpdateResult['message']}');
          Get.snackbar(
            'Profile Update Failed',
            backendUpdateResult['message'] ?? 'Could not save your new avatar to your profile.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        String errorMessage = cloudinaryUploadResults.isNotEmpty ? cloudinaryUploadResults[0]['message'] : 'Unknown Cloudinary upload error.';
        print('Cloudinary avatar upload failed: $errorMessage');
        Get.snackbar(
          'Cloud Upload Failed',
          'Could not upload new avatar to cloud: $errorMessage',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
      print('Error during avatar upload process: ${e.toString()}');
      Get.snackbar(
        'Upload Error',
        'An unexpected error occurred during the avatar update process: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(0)),
      ),
      backgroundColor: const Color(0xFF121212),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Obx(() {
            final userMap = dataController.user.value;
            final String? avatarUrl = userMap['user']['avatar'];
            final String username = userMap['user']['name'] ?? 'User';
            final String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';

            return DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.teal[700],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.tealAccent.withOpacity(0.3),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                avatarInitial,
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.tealAccent,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Colors.tealAccent,
                          shape: const CircleBorder(),
                          elevation: 2.0,
                          child: InkWell(
                            onTap: () {
                              _showImageSourceActionSheet(context);
                            },
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(
                                FeatherIcons.edit2,
                                size: 16.0,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    username,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "@$username",
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
          ListTile(
            leading: Icon(FeatherIcons.rss, color: Colors.grey[300]),
            title: Text(
              'My Feeds',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back();
              if (Get.currentRoute != '/HomeFeedScreen') {
                Get.offAll(() => const HomeFeedScreen());
              }
            },
          ),
          ListTile(
            leading: Icon(FeatherIcons.users, color: Colors.grey[300]),
            title: Text(
              'Browse Users',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back();
              Get.to(() => const UsersListPage());
            },
          ),
          ListTile(
            leading: Icon(FeatherIcons.messageSquare, color: Colors.grey[300]),
            title: Text(
              'Direct Messages',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back();
              Get.to(() => const DirectMessagesPage());
            },
          ),
          ListTile(
            leading: Icon(FeatherIcons.gitMerge, color: Colors.grey[300]),
            title: Text(
              'Network',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back();
              Get.to(() => const FollowersPage());
            },
          ),
          const Divider(color: Color(0xFF303030)),
          ListTile(
            leading: Icon(FeatherIcons.settings, color: Colors.grey[300]),
            title: Text(
              'Settings',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back();
              Get.snackbar('Coming Soon!', 'Settings page is under development.',
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.amber[700], colorText: Colors.black);
            },
          ),
          ListTile(
            leading: Icon(FeatherIcons.logOut, color: Colors.grey[300]),
            title: Text(
              'Logout',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () async {
              Get.back();

              bool? confirmLogout = await Get.dialog<bool>(
                AlertDialog(
                  backgroundColor: const Color(0xFF1F1F1F),
                  title: Text('Confirm Logout', style: GoogleFonts.poppins(color: Colors.white)),
                  content: Text('Are you sure you want to log out?', style: GoogleFonts.roboto(color: Colors.grey[300])),
                  actions: <Widget>[
                    TextButton(
                      child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.grey[400])),
                      onPressed: () {
                        Get.back(result: false);
                      },
                    ),
                    TextButton(
                      child: Text('Logout', style: GoogleFonts.roboto(color: Colors.redAccent)),
                      onPressed: () {
                        Get.back(result: true);
                      },
                    ),
                  ],
                ),
                barrierDismissible: false,
              );

              if (confirmLogout == true) {
                final DataController dataController = Get.find<DataController>();
                await dataController.logoutUser();
                Get.offAll(() => const LoginPage());
              }
            },
          ),
        ],
      ),
    );
  }
}