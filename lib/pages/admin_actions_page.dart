import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminActionsPage extends StatelessWidget {
  const AdminActionsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Admin Actions',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.white),
            title: Text('Delete a Post', style: GoogleFonts.roboto(color: Colors.white)),
            onTap: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('Delete a Post'),
                  content: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Post ID',
                    ),
                    onSubmitted: (postId) async {
                      Get.back();
                      final result = await dataController.deletePostByAdmin(postId);
                      Get.snackbar(
                        result['success'] ? 'Success' : 'Error',
                        result['message'],
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user, color: Colors.white),
            title: Text('Update User Verification', style: GoogleFonts.roboto(color: Colors.white)),
            onTap: () {
              final userIdController = TextEditingController();
              final entityTypeController = TextEditingController();
              final levelController = TextEditingController();
              bool paid = false;

              Get.dialog(
                AlertDialog(
                  title: const Text('Update User Verification'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: userIdController,
                        decoration: const InputDecoration(labelText: 'User ID'),
                      ),
                      TextField(
                        controller: entityTypeController,
                        decoration: const InputDecoration(labelText: 'Entity Type (e.g., individual)'),
                      ),
                      TextField(
                        controller: levelController,
                        decoration: const InputDecoration(labelText: 'Level (e.g., premium)'),
                      ),
                      StatefulBuilder(
                        builder: (context, setState) {
                          return CheckboxListTile(
                            title: const Text('Paid'),
                            value: paid,
                            onChanged: (value) {
                              setState(() {
                                paid = value ?? false;
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Get.back();
                        final result = await dataController.updateUserVerification(
                          userIdController.text,
                          entityTypeController.text,
                          levelController.text,
                          paid,
                        );
                        Get.snackbar(
                          result['success'] ? 'Success' : 'Error',
                          result['message'],
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      child: const Text('Update'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag, color: Colors.white),
            title: Text('Flag a Post for Review', style: GoogleFonts.roboto(color: Colors.white)),
            onTap: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('Flag a Post for Review'),
                  content: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Post ID',
                    ),
                    onSubmitted: (postId) async {
                      Get.back();
                      final result = await dataController.flagPostForReview(postId);
                      Get.snackbar(
                        result['success'] ? 'Success' : 'Error',
                        result['message'],
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.white),
            title: Text('Suspend a User', style: GoogleFonts.roboto(color: Colors.white)),
            onTap: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('Suspend a User'),
                  content: TextField(
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                    ),
                    onSubmitted: (userId) async {
                      Get.back();
                      final result = await dataController.suspendUser(userId);
                      Get.snackbar(
                        result['success'] ? 'Success' : 'Error',
                        result['message'],
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
