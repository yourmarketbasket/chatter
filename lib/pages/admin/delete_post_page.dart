import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/widgets/admin/post_search_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeletePostPage extends StatelessWidget {
  const DeletePostPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DataController dataController = Get.find<DataController>();
    return Scaffold(
      body: PostSearchWidget(
        onAction: (postId) async {
          final result = await dataController.deletePostByAdmin(postId);
          Get.snackbar(
            result['success'] ? 'Success' : 'Error',
            result['message'],
            snackPosition: SnackPosition.BOTTOM,
          );
        },
        actionText: 'Delete Post',
      ),
    );
  }
}
