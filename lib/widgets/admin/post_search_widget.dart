import 'package:chatter/controllers/data-controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class PostSearchWidget extends StatefulWidget {
  const PostSearchWidget({Key? key}) : super(key: key);

  @override
  _PostSearchWidgetState createState() => _PostSearchWidgetState();
}

class _PostSearchWidgetState extends State<PostSearchWidget> {
  final DataController dataController = Get.find<DataController>();
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _postSearchController = TextEditingController();
  Map<String, dynamic>? _foundUser;
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _filteredPosts = [];

  void _filterPosts() {
    final query = _postSearchController.text.toLowerCase();
    setState(() {
      _filteredPosts = _userPosts.where((post) {
        final content = post['content']?.toLowerCase() ?? '';
        return content.contains(query);
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _postSearchController.addListener(_filterPosts);
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _postSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              labelText: 'Search User by Username',
              labelStyle: GoogleFonts.roboto(color: Colors.white),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            style: GoogleFonts.roboto(color: Colors.white),
            onSubmitted: (username) async {
              final userResult = await dataController.searchUserByUsername(username);
              if (userResult['success']) {
                setState(() {
                  _foundUser = userResult['user'];
                });
                final postsResult = await dataController.fetchPostsByUsername(username);
                if (postsResult['success']) {
                  setState(() {
                    _userPosts = List<Map<String, dynamic>>.from(postsResult['posts']);
                    _filteredPosts = _userPosts;
                  });
                } else {
                  Get.snackbar('Error', postsResult['message']);
                }
              } else {
                Get.snackbar('Error', userResult['message']);
              }
            },
          ),
          if (_foundUser != null) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _postSearchController,
              decoration: InputDecoration(
                labelText: 'Search Posts by Content',
                labelStyle: GoogleFonts.roboto(color: Colors.white),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: GoogleFonts.roboto(color: Colors.white),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredPosts.length,
                itemBuilder: (context, index) {
                  final post = _filteredPosts[index];
                  return Card(
                    color: Colors.grey[900],
                    child: ListTile(
                      title: Text(post['content'] ?? '', style: GoogleFonts.roboto(color: Colors.white)),
                      subtitle: Text('By: ${post['username'] ?? ''}', style: GoogleFonts.roboto(color: Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: post['isFlagged'] ?? false,
                            onChanged: (value) async {
                              final result = value
                                  ? await dataController.flagPostForReview(post['_id'])
                                  : await dataController.unflagPost(post['_id']);
                              Get.snackbar(
                                result['success'] ? 'Success' : 'Error',
                                result['message'],
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            if (result['success'] && _foundUser != null) {
                              final postsResult = await dataController.fetchPostsByUsername(_foundUser!['name']);
                              if (postsResult['success']) {
                                setState(() {
                                  _userPosts = List<Map<String, dynamic>>.from(postsResult['posts']);
                                  _filterPosts(); // Re-apply content filter
                                });
                              }
                            }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Get.dialog(
                                AlertDialog(
                                  title: const Text('Delete Post'),
                                  content: const Text('Are you sure you want to delete this post?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Get.back(),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Get.back();
                                        final result = await dataController.deletePostByAdmin(post['_id']);
                                        Get.snackbar(
                                          result['success'] ? 'Success' : 'Error',
                                          result['message'],
                                          snackPosition: SnackPosition.BOTTOM,
                                        );
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
