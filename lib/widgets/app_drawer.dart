import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/users_list_page.dart';
import 'package:chatter/pages/direct_messages_page.dart';
import 'package:chatter/pages/followers_page.dart';
import 'package:chatter/pages/login.dart'; // Ensure this import is present
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io'; // For File class
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  // Add this method to the AppDrawer class
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F), // Dark theme for bottom sheet
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(FeatherIcons.image, color: Colors.grey[300]),
                title: Text('Pick from Gallery', style: GoogleFonts.roboto(color: Colors.grey[300])),
                onTap: () {
                  Get.back(); // Close the bottom sheet
                  // Call a method to handle image picking from gallery (will be implemented in next step)
                  _handleImageSelection(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(FeatherIcons.camera, color: Colors.grey[300]),
                title: Text('Take a Picture', style: GoogleFonts.roboto(color: Colors.grey[300])),
                onTap: () {
                  Get.back(); // Close the bottom sheet
                  // Call a method to handle image capturing from camera (will be implemented in next step)
                  _handleImageSelection(ImageSource.camera);
                },
              ),
              ListTile( // Optional: Cancel button
                leading: Icon(FeatherIcons.xCircle, color: Colors.redAccent),
                title: Text('Cancel', style: GoogleFonts.roboto(color: Colors.redAccent)),
                onTap: () {
                  Get.back(); // Close the bottom sheet
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Updated method to handle image picking and cropping
  Future<void> _handleImageSelection(ImageSource source) async { // Make it async
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      // If an image is picked, proceed to crop it
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        cropStyle: CropStyle.circle, // Common for avatars
        aspectRatioPresets: [
          CropAspectRatioPreset.square, // Enforces a square aspect ratio for the circle
        ],
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Crop Your Avatar',
              toolbarColor: Colors.teal, // Or your app's theme color
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true, // Lock to square for circular crop
              activeControlsWidgetColor: Colors.tealAccent
          ),
          IOSUiSettings(
            title: 'Crop Your Avatar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rectX: 20, // Example values, adjust as needed for initial crop rect
            rectY: 20,
            rectWidth: 300,
            rectHeight: 300,
          ),
          // WebUiSettings requires context to be passed if used.
          // For this example, assuming 'context' is available in this scope
          // If not, you might need to pass it or handle web differently.
          // WebUiSettings(
          //   context: Get.context!, // Assuming Get.context is available and valid
          //   presentStyle: CropperPresentStyle.dialog,
          //   size: const CropperSize(width: 400, height: 400),
          // )
        ],
      );

      if (croppedFile != null) {
        // If cropping is successful, proceed to upload (next step)
        print('Cropped image path: ${croppedFile.path}');
        // Call a new method to handle the upload
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

  // Updated method to handle image uploading
  Future<void> _handleImageUpload(File imageFile) async { // Make it async
    final DataController dataController = Get.find<DataController>(); // Get DataController instance

    // Show a loading indicator snackbar for Cloudinary upload
    Get.snackbar(
      'Uploading to Cloud...',
      'Please wait while your new avatar is being uploaded.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blueGrey[600], // Slightly different color for this phase
      colorText: Colors.white,
      showProgressIndicator: true,
      progressIndicatorBackgroundColor: Colors.white,
      progressIndicatorValueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
      duration: const Duration(seconds: 120),
      isDismissible: false,
    );

    try {
      List<Map<String, dynamic>> cloudinaryUploadResults = await dataController.uploadFilesToCloudinary([imageFile]);

      // Attempt to dismiss the "Uploading to Cloud..." snackbar
      // Using Get.closeCurrentSnackbar() is more robust for specific snackbar dismissal
      if (Get.isSnackbarOpen) {
         Get.closeCurrentSnackbar();
      }


      if (cloudinaryUploadResults.isNotEmpty && cloudinaryUploadResults[0]['success'] == true) {
        String newCloudinaryAvatarUrl = cloudinaryUploadResults[0]['url'];
        print('Avatar uploaded successfully to Cloudinary: $newCloudinaryAvatarUrl');

        // Now, show a new snackbar for updating the profile
        Get.snackbar(
          'Updating Profile...',
          'Saving your new avatar. Please wait.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blueGrey[700], // Different color for this phase
          colorText: Colors.white,
          showProgressIndicator: true,
          progressIndicatorBackgroundColor: Colors.white,
          progressIndicatorValueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrangeAccent),
          duration: const Duration(seconds: 120),
          isDismissible: false,
        );

        // Call updateUserAvatar with the URL from Cloudinary
        final Map<String, dynamic> backendUpdateResult = await dataController.updateUserAvatar(newCloudinaryAvatarUrl);

        if (Get.isSnackbarOpen) {
          Get.closeCurrentSnackbar(); // Dismiss the "Updating Profile..." snackbar
        }

        if (backendUpdateResult['success'] == true) {
          print('User avatar updated successfully on backend and locally.');
          Get.snackbar(
            'Avatar Updated!',
            backendUpdateResult['message'] ?? 'Your avatar has been successfully updated.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          // The UI in AppDrawer should reactively update due to user.value change in DataController
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
        Get.closeCurrentSnackbar(); // Dismiss any active loading snackbar in case of an unexpected error
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
    final DataController dataController = Get.find<DataController>(); // Keep this to access methods

    return Drawer(
      backgroundColor: const Color(0xFF121212),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Obx(() { // Wrap UserAccountsDrawerHeader (or just currentAccountPicture part) with Obx
            // Access reactive user data inside Obx for it to rebuild on change
            final userMap = dataController.user.value;
            final String? avatarUrl = userMap['avatar'];
            final String username = userMap['username'] ?? 'User';
            final String email = userMap['email'] ?? 'user@example.com';
            final String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';

            return UserAccountsDrawerHeader(
              accountName: Text(
                username,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              accountEmail: Text(
                email,
                style: GoogleFonts.roboto(fontSize: 14),
              ),
              currentAccountPicture: Stack(
                alignment: Alignment.bottomRight,
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
              decoration: BoxDecoration(
                color: Colors.teal[700],
              ),
            );
          }), // End of Obx
          // ... other ListTiles (they don't need to be in Obx unless they also depend on user.value directly)
          ListTile(
            leading: Icon(FeatherIcons.rss, color: Colors.grey[300]),
            title: Text(
              'My Feeds',
              style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16),
            ),
            onTap: () {
              Get.back(); // Close the drawer
              // Navigate to HomeFeedScreen, ensuring it's the main view
              // If already on HomeFeedScreen, just close drawer. Otherwise, navigate.
              if (Get.currentRoute != '/HomeFeedScreen') { // Check current route if defined
                Get.offAll(() => const HomeFeedScreen()); // Use offAll to clear stack if coming from elsewhere
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
              Get.back(); // Close the drawer
              // Navigate to UsersListPage - This page will be created in the next step
              // For now, this will throw an error if UsersListPage is not created.
              // We'll create UsersListPage in the next plan step.
               Get.to(() => const UsersListPage());
            },
          ),
          // New Items:
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
            leading: Icon(FeatherIcons.gitMerge, color: Colors.grey[300]), // Changed icon for Network to avoid clash
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
              // TODO: Implement settings page navigation
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
            onTap: () async { // Make onTap async
              Get.back(); // Close the drawer first

              // Show a confirmation dialog (optional, but good UX)
              bool? confirmLogout = await Get.dialog<bool>(
                AlertDialog(
                  backgroundColor: const Color(0xFF1F1F1F),
                  title: Text('Confirm Logout', style: GoogleFonts.poppins(color: Colors.white)),
                  content: Text('Are you sure you want to log out?', style: GoogleFonts.roboto(color: Colors.grey[300])),
                  actions: <Widget>[
                    TextButton(
                      child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.grey[400])),
                      onPressed: () {
                        Get.back(result: false); // Close dialog, return false
                      },
                    ),
                    TextButton(
                      child: Text('Logout', style: GoogleFonts.roboto(color: Colors.redAccent)),
                      onPressed: () {
                        Get.back(result: true); // Close dialog, return true
                      },
                    ),
                  ],
                ),
                barrierDismissible: false, // User must explicitly choose an action
              );

              if (confirmLogout == true) {
                // Find DataController instance. It should already be registered by Get.put in main.dart
                final DataController dataController = Get.find<DataController>();
                await dataController.logoutUser(); // Call the logout method

                // Navigate to LoginPage and clear navigation stack
                Get.offAll(() => const LoginPage());
              }
            },
          ),
        ],
      ),
    );
  }
}
