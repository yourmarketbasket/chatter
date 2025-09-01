import 'package:chatter/controllers/data-controller.dart';
import 'package:chatter/widgets/reply/post_content.dart';
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

  void _handleFlagPost(Map<String, dynamic> post) async {
    final String postId = post['_id'];
    final int postIndex = _filteredPosts.indexWhere((p) => p['_id'] == postId);
    if (postIndex == -1) return;

    final bool originalFlagStatus = _filteredPosts[postIndex]['isFlagged'] ?? false;

    // 1. Optimistic UI update
    setState(() {
      _filteredPosts[postIndex]['isFlagged'] = !originalFlagStatus;
    });

    // 2. API call
    final result = !originalFlagStatus
        ? await dataController.flagPostForReview(postId)
        : await dataController.unflagPost(postId);

    // 3. Handle result
    if (result['success']) {
      Get.snackbar('Success', result['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
      // Also update the main list to be sure
      final int mainListIndex = _userPosts.indexWhere((p) => p['_id'] == postId);
      if (mainListIndex != -1) {
        _userPosts[mainListIndex]['isFlagged'] = !originalFlagStatus;
      }
    } else {
      // 4. Rollback on failure
      setState(() {
        _filteredPosts[postIndex]['isFlagged'] = originalFlagStatus;
      });
      Get.snackbar('Error', result['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }

  void _handleDeletePost(Map<String, dynamic> post) {
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
              final String postId = post['_id'];
              final int postIndex = _filteredPosts.indexWhere((p) => p['_id'] == postId);
              if (postIndex == -1) return;

              // Optimistic removal
              final removedPost = _filteredPosts.removeAt(postIndex);
              final int mainListIndex = _userPosts.indexWhere((p) => p['_id'] == postId);
              if (mainListIndex != -1) {
                _userPosts.removeAt(mainListIndex);
              }
              setState(() {});

              final result = await dataController.deletePostByAdmin(postId);

              if (result['success']) {
                Get.snackbar('Success', result['message'],
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                    colorText: Colors.white);
              } else {
                // Rollback
                setState(() {
                  _filteredPosts.insert(postIndex, removedPost);
                  if (mainListIndex != -1) {
                    _userPosts.insert(mainListIndex, removedPost);
                  }
                });
                Get.snackbar('Error', result['message'],
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red,
                    colorText: Colors.white);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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

  Future<void> _fetchUserAndPosts(String username) async {
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
        Get.snackbar('Error', postsResult['message'],
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    } else {
      Get.snackbar('Error', userResult['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              labelText: 'Search User by Username',
              labelStyle: GoogleFonts.roboto(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.tealAccent),
              ),
            ),
            style: GoogleFonts.roboto(color: Colors.white),
            onSubmitted: _fetchUserAndPosts,
          ),
          if (_foundUser != null) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _postSearchController,
              decoration: InputDecoration(
                labelText: 'Search Posts by Content',
                labelStyle: GoogleFonts.roboto(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.tealAccent),
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
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        PostContent(
                          postData: post,
                          isReply: false,
                          isPreview: true,
                          showSnackBar: (title, message, color) {
                            Get.snackbar(title, message,
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: color,
                                colorText: Colors.white);
                          },
                          onSharePost: (postData) {
                            // Implement share functionality or leave empty for admin
                          },
                          onReplyToItem: (parentReplyId) {
                            // Implement reply functionality or leave empty for admin
                          },
                          refreshReplies: () {
                            // Implement refresh or leave empty for admin
                          },
                          onReplyDataUpdated: (updatedData) {
                            setState(() {
                              _filteredPosts[index] = updatedData;
                            });
                          },
                          postDepth: 0,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                post['isFlagged'] ?? false ? 'Flagged' : 'Not Flagged',
                                style: GoogleFonts.roboto(
                                  color: post['isFlagged'] ?? false ? Colors.orangeAccent : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 10),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'flag') {
                                    _handleFlagPost(post);
                                  } else if (value == 'delete') {
                                    _handleDeletePost(post);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'flag',
                                    child: Text(post['isFlagged'] ?? false ? 'Unflag Post' : 'Flag for Review'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text('Delete Post', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
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
