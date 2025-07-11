import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/users_list_page.dart';
// import 'package:chatter/pages/direct_messages_page.dart'; // Removed
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
import 'package:url_launcher/url_launcher.dart';


class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  void _showEditAboutDialog(BuildContext context) {
    final DataController dataController = Get.find<DataController>();
    final TextEditingController aboutController = TextEditingController(
      text: dataController.user.value['user']?['about'] as String? ?? '',
    );
    bool isSaving = false;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Edit Your "About" Info', style: GoogleFonts.poppins(color: Colors.white)),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: aboutController,
                  style: GoogleFonts.roboto(color: Colors.white),
                  maxLines: 4,
                  maxLength: 280, // As per schema
                  decoration: InputDecoration(
                    hintText: 'Tell us about yourself...',
                    hintStyle: GoogleFonts.roboto(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: Colors.tealAccent, width: 1.5),
                    ),
                     counterStyle: GoogleFonts.roboto(color: Colors.grey[500]),
                  ),
                ),
                if (isSaving) const Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent)),
                )
              ],
            );
          }
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.grey[400])),
            onPressed: () => Get.back(),
          ),
          StatefulBuilder(
             builder: (BuildContext context, StateSetter setDialogState) {
              return TextButton(
                child: Text(isSaving ? 'Saving...' : 'Save', style: GoogleFonts.roboto(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                onPressed: isSaving ? null : () async {
                  setDialogState(() => isSaving = true);
                  final result = await dataController.updateAboutInfo(aboutController.text.trim());
                  if (Get.isDialogOpen ?? false) Get.back();

                  if (result['success'] == true) {
                    Get.snackbar(
                      'Success',
                      result['message'] ?? 'Your "About" information has been updated.',
                      snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white,
                    );
                  } else {
                    Get.snackbar(
                      'Error',
                       result['message'] ?? 'Failed to update "About" information.',
                       snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white,
                    );
                  }
                },
              );
            }
          ),
        ],
      ),
      barrierDismissible: !isSaving,
    );
  }


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
        _handleImageUpload(File(croppedFile.path));
      } else {
        Get.snackbar('Cancelled', 'Image cropping was cancelled.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange[700], colorText: Colors.white);
      }
    } else {
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
      List<Map<String, dynamic>> cloudinaryUploadResults = await dataController.uploadFiles([{'file': imageFile}]);
      if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();

      if (cloudinaryUploadResults.isNotEmpty && cloudinaryUploadResults[0]['success'] == true) {
        String newCloudinaryAvatarUrl = cloudinaryUploadResults[0]['url'];
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
        if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();

        if (backendUpdateResult['success'] == true) {
          Get.snackbar('Avatar Updated!', backendUpdateResult['message'] ?? 'Your avatar has been successfully updated.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          Get.snackbar('Profile Update Failed', backendUpdateResult['message'] ?? 'Could not save your new avatar to your profile.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
        }
      } else {
        String errorMessage = cloudinaryUploadResults.isNotEmpty ? cloudinaryUploadResults[0]['message'] : 'Unknown Cloudinary upload error.';
        Get.snackbar('Cloud Upload Failed', 'Could not upload new avatar to cloud: $errorMessage',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
      Get.snackbar('Upload Error', 'An unexpected error occurred: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      Get.snackbar('Error', 'Could not launch $urlString', snackPosition: SnackPosition.BOTTOM);
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
      child: Obx(() { // Wrap ListView with Obx to react to user data changes
        final userDetail = dataController.user.value['user'] ?? {};
        final String? avatarUrl = userDetail['avatar'] as String?;
        final String username = userDetail['name'] ?? 'User';
        final String aboutMe = userDetail['about'] as String? ?? '';
        final int followersCount = (userDetail['followers'] as List<dynamic>? ?? []).length;
        final int followingCount = (userDetail['following'] as List<dynamic>? ?? []).length;
        final String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';

        return ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal[700]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Align content to the start
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row( // Row for Avatar and Edit Avatar button
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                       CircleAvatar(
                        radius: 28, // Slightly smaller avatar
                        backgroundColor: Colors.tealAccent.withOpacity(0.3),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(avatarUrl, maxWidth: 120, maxHeight: 120)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(avatarInitial, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.tealAccent))
                            : null,
                      ),
                      const SizedBox(width: 8), // Space between avatar and its edit button
                      Material(
                        color: Colors.black.withOpacity(0.3), // Semi-transparent background
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => _showImageSourceActionSheet(context),
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Icon(FeatherIcons.camera, size: 14.0, color: Colors.white70),
                          ),
                        ),
                      ),
                       const Spacer(), // Pushes content to the right
                        // Followers/Following counts
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Followers: $followersCount', style: GoogleFonts.roboto(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                            Text('Following: $followingCount', style: GoogleFonts.roboto(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text( // Username
                    username,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white),
                  ),
                  Text( // @username
                    "@$username",
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 6),
                   Row( // About me and Edit Icon
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Expanded(
                         child: Text(
                           aboutMe.isNotEmpty ? aboutMe : 'No bio yet.',
                           style: GoogleFonts.roboto(fontSize: 12, color: Colors.white.withOpacity(0.8), fontStyle: aboutMe.isNotEmpty ? FontStyle.normal : FontStyle.italic),
                           maxLines: 2,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       const SizedBox(width: 4),
                       InkWell(
                         onTap: () {
                           // Get.back(); // Close drawer if open, then show dialog
                           _showEditAboutDialog(context);
                         },
                         child: Padding(
                           padding: const EdgeInsets.all(4.0), // Make tap area larger
                           child: Icon(FeatherIcons.edit2, size: 15.0, color: Colors.white.withOpacity(0.8)),
                         ),
                       ),
                     ],
                   ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(FeatherIcons.rss, color: Colors.grey[300]),
              title: Text('My Feeds', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
              onTap: () {
                Get.back();
                if (Get.currentRoute != '/HomeFeedScreen') {
                  Get.offAll(() => const HomeFeedScreen());
                }
              },
            ),
            ListTile(
              leading: Icon(FeatherIcons.users, color: Colors.grey[300]),
              title: Text('Browse Users', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
              onTap: () {
                Get.back();
                Get.to(() => const UsersListPage());
              },
            ),
            ListTile(
              leading: Icon(FeatherIcons.gitMerge, color: Colors.grey[300]),
              title: Text('Network', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
              onTap: () {
                Get.back();
                // Navigate to FollowersPage, viewing current user's network
                Get.to(() => FollowersPage(viewUserId: userDetail['_id'] as String?));
              },
            ),
            // Removed Direct Messages and Settings
            const Divider(color: Color(0xFF303030)),
            ListTile(
              leading: Icon(FeatherIcons.logOut, color: Colors.grey[300]),
              title: Text('Logout', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
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
                        onPressed: () => Get.back(result: false),
                      ),
                      TextButton(
                        child: Text('Logout', style: GoogleFonts.roboto(color: Colors.redAccent)),
                        onPressed: () => Get.back(result: true),
                      ),
                    ],
                  ),
                  barrierDismissible: false,
                );
                if (confirmLogout == true) {
                  await dataController.logoutUser();
                  Get.offAll(() => const LoginPage());
                }
              },
            ),
            const Spacer(), // Pushes the update link to the bottom
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              child: InkWell(
                onTap: () {
                  _launchURL('https://codethelabs.com/#downloads');
                },
                child: Text(
                  'To update to the latest version of the app, click here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: Colors.tealAccent.withOpacity(0.8),
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.tealAccent.withOpacity(0.8)
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}