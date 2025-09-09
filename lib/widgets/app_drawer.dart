import 'package:chatter/pages/admin_actions_page.dart';
import 'package:chatter/pages/home-feed-screen.dart';
import 'package:chatter/pages/users_list_page.dart';
import 'package:chatter/pages/followers_page.dart';
import 'package:chatter/pages/login.dart';
import 'package:chatter/pages/terms_and_conditions_page.dart';
import 'package:chatter/pages/user_posts_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/controllers/update_controller.dart';
import 'package:chatter/helpers/verification_helper.dart';
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
                  maxLength: 280,
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
          Get.snackbar(
            'Avatar Updated!',
            backendUpdateResult['message'] ?? 'Your avatar has been successfully updated.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            'Profile Update Failed',
            backendUpdateResult['message'] ?? 'Could not save your new avatar to your profile.',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white,
          );
        }
      } else {
        String errorMessage = cloudinaryUploadResults.isNotEmpty ? cloudinaryUploadResults[0]['message'] : 'Unknown Cloudinary upload error.';
        Get.snackbar(
          'Cloud Upload Failed',
          'Could not upload new avatar to cloud: $errorMessage',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white,
        );
      }
    } catch (e) {
      if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
      Get.snackbar(
        'Upload Error',
        'An unexpected error occurred during the avatar update process: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white,
      );
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
    final UpdateController updateController = Get.find<UpdateController>();

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(0)),
      ),
      backgroundColor: const Color(0xFF121212),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                Obx(() {
                  final userMap = dataController.user.value;
                  final String? avatarUrl = userMap['user']?['avatar'];
                  final String username = userMap['user']?['name'] ?? 'User';
                  final String handle = userMap['user']?['name'] ?? 'username'; // Should likely be userMap['user']?['username']
                  final String aboutMe = userMap['user']?['about'] as String? ?? '';
                  // Use the DataController's dedicated RxLists for followers and following counts
                  final int followersCount = dataController.followers.length;
                  final int followingCount = dataController.following.length;
                  final String avatarInitial = username.isNotEmpty ? username[0].toUpperCase() : '?';
                  // print(userMap);
                  // print("[AppDrawer] Followers: ${dataController.followers.length}, Following: ${dataController.following.length}");

                  return Container(
                    padding: const EdgeInsets.only(top: 50.0, left: 20.0, right: 20.0, bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.tealAccent.withOpacity(0.3),
                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(avatarUrl, maxWidth: 150, maxHeight: 150)
                                  : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Text(
                                      avatarInitial,
                                      style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.tealAccent),
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
                                  onTap: () => _showImageSourceActionSheet(context),
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Icon(FeatherIcons.edit2, size: 16.0, color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              username,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            Icon(Icons.verified,
                                color: getVerificationBadgeColor(
                                    userMap['user']?['verification']?['entityType'],
                                    userMap['user']?['verification']?['level']),
                                size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "@$handle",
                          style: GoogleFonts.roboto(fontSize: 15, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$followingCount', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                            const SizedBox(width: 4),
                            Text('Following', style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14)),
                            const SizedBox(width: 20),
                            Text('$followersCount', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                            const SizedBox(width: 4),
                            Text('Followers', style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (aboutMe.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: aboutMe,
                                    style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[300], height: 1.4),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: IconButton(
                                      icon: Icon(FeatherIcons.edit3, color: Colors.grey[400], size: 15),
                                      onPressed: () => _showEditAboutDialog(context),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Edit About Info',
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No about information yet.',
                                style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[500], fontStyle: FontStyle.italic),
                              ),
                              IconButton(
                                icon: Icon(FeatherIcons.edit3, color: Colors.grey[400], size: 20),
                                onPressed: () => _showEditAboutDialog(context),
                                tooltip: 'Edit About Info',
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                }),
                // navigate to home
                ListTile(
                  leading: Icon(FeatherIcons.home, color: Colors.grey[300]),
                  title: Text('Home', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
                  onTap: () {
                    Get.back();
                    Get.to(() => const HomeFeedScreen());
                  },
                ),
                ListTile(
                  leading: Icon(FeatherIcons.userCheck, color: Colors.grey[300]),
                  title: Text('My Posts', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
                  onTap: () {
                    Get.back();
                    final String? currentUserId = dataController.user.value['user']?['_id'] as String?;
                    final String? currentUsername = dataController.user.value['user']?['username'] as String?;
                    final String displayUsername = currentUsername ?? dataController.user.value['user']?['name'] as String? ?? 'My';

                    if (currentUserId != null && displayUsername.isNotEmpty) {
                      if (Get.currentRoute == '/UserPostsPage' && (Get.arguments as Map?)?['userId'] == currentUserId) {
                        return;
                      }
                      Get.to(() => UserPostsPage(userId: currentUserId, username: displayUsername));
                    } else {
                      Get.snackbar('Error', 'Could not load your posts. User data missing.', snackPosition: SnackPosition.BOTTOM);
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
                    Get.to(() => const FollowersPage());
                  },
                ),
                Obx(() {
                  final userRole = dataController.user.value['user']?['role'];
                  if (userRole == 'admin' || userRole == 'superuser') {
                    return ListTile(
                      leading: Icon(FeatherIcons.shield, color: Colors.grey[300]),
                      title: Text('Admin Panel', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
                      onTap: () {
                        Get.back();
                        Get.to(() => const AdminActionsPage());
                      },
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }),
                const Divider(color: Color(0xFF303030)),
                ListTile(
                  leading: Icon(FeatherIcons.coffee, color: Colors.grey[300]),
                  title: Text('Buy Me a Coffee', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
                  onTap: () {
                    Get.back();
                    Get.toNamed('/buy-me-a-coffee');
                  },
                ),
                ListTile(
                  leading: Icon(FeatherIcons.fileText, color: Colors.grey[300]),
                  title: Text('Terms & Service', style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 16)),
                  onTap: () {
                    Get.back();
                    Get.to(() => const TermsAndConditionsPage());
                  },
                ),
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
              ],
            ),
          ),
          const Divider(color: Color(0xFF303030), height: 1),
          Obx(() {
            if (updateController.isUpdateAvailable.value) {
              return Column(
                children: [
                  ListTile(
                    leading: Icon(FeatherIcons.gift, color: Colors.tealAccent),
                    title: Text('Update Available', style: GoogleFonts.roboto(color: Colors.tealAccent, fontSize: 16)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('New', style: GoogleFonts.poppins(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    onTap: () {
                      updateController.upgrader.onUpdate();
                    },
                  ),
                  const Divider(color: Color(0xFF303030), height: 1),
                  Container(
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 1),
                    ),
                    child: InkWell(
                      onTap: () => updateController.upgrader.onUpdate(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FeatherIcons.gift, color: Colors.tealAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Tap to update to the latest version',
                            style: GoogleFonts.roboto(color: Colors.tealAccent, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
        ],
      ),
    );
  }
}