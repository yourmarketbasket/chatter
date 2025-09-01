import 'package:chatter/widgets/admin/post_search_widget.dart';
import 'package:flutter/material.dart';

class PostManagementPage extends StatelessWidget {
  const PostManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: PostSearchWidget(),
    );
  }
}
