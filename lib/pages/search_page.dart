import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatter/pages/reply_page.dart';
import 'package:timeago/timeago.dart' as timeago;

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final DataController _dataController = Get.find<DataController>();
  List<Map<String, dynamic>> _searchResults = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // _performSearch(); // Uncomment if you want to load all posts initially
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    if (_searchQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
      return;
    }

    final allPosts = _dataController.posts.toList();
    final Set<String> addedPostIds = {}; // To track IDs of posts already added
    final List<Map<String, dynamic>> postsToDisplay = [];
    final String query = _searchQuery.toLowerCase();

    for (var post in allPosts) {
      final String postId = post['_id'] as String? ?? '';
      if (postId.isEmpty || addedPostIds.contains(postId)) {
        continue; // Skip if no ID or already added
      }

      // Check main post content and username
      final String postContent = post['content'] as String? ?? '';
      final String postUsername = post['username'] as String? ?? '';
      bool matches = postContent.toLowerCase().contains(query) ||
                     postUsername.toLowerCase().contains(query);

      if (matches) {
        postsToDisplay.add(post);
        addedPostIds.add(postId);
        continue; // Move to next post
      }

      // Check replies if main post didn't match
      final List<dynamic> repliesRaw = post['replies'] as List<dynamic>? ?? [];
      if (repliesRaw.isNotEmpty) {
        for (var replyRaw in repliesRaw) {
          if (replyRaw is Map<String, dynamic>) {
            final String replyContent = replyRaw['content'] as String? ?? '';
            final String replyUsername = replyRaw['username'] as String? ?? ''; // Assuming replies also have a username

            if (replyContent.toLowerCase().contains(query) || replyUsername.toLowerCase().contains(query)) {
              postsToDisplay.add(post); // Add the parent post
              addedPostIds.add(postId);
              break; // Found a matching reply, no need to check other replies for this post
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = postsToDisplay;
      });
    }
  }

  List<TextSpan> _buildTextSpans(String text, {required bool isReply}) {
    final List<TextSpan> spans = [];
    final RegExp hashtagRegExp = RegExp(r"(#\w+)");
    final TextStyle defaultStyle = GoogleFonts.roboto(
        fontSize: isReply ? 13 : 14,
        color: const Color.fromARGB(255, 255, 255, 255),
        height: 1.5);
    final TextStyle hashtagStyle = GoogleFonts.roboto(
        fontSize: isReply ? 13 : 14,
        color: Colors.tealAccent,
        fontWeight: FontWeight.bold,
        height: 1.5);

    text.splitMapJoin(
      hashtagRegExp,
      onMatch: (Match match) {
        spans.add(TextSpan(text: match.group(0), style: hashtagStyle));
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: defaultStyle));
        return '';
      },
    );
    return spans;
  }

  Widget _buildActionButton(IconData icon, String text, VoidCallback onPressed, {bool isLiked = false, bool isReposted = false, bool isBookmarked = false}) {
    Color iconColor = Colors.white70;
    if (isLiked) {
      iconColor = Colors.redAccent;
    } else if (isReposted) {
      iconColor = Colors.tealAccent;
    } else if (isBookmarked) {
      iconColor = Colors.amber;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: iconColor, size: 14),
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.only(right: 2.0, left: 5.0),
          onPressed: onPressed,
        ),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: Text(
              text,
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _navigateToReplyPage(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyPage(post: post, postDepth: 0),
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    final String postId = post['_id'] as String? ?? post.hashCode.toString();
    final String username = post['username'] as String? ?? 'Unknown User';
    final String content = post['content'] as String? ?? '';
    final String? userAvatar = post['useravatar'] as String?;
    final String avatarInitial = (username.isNotEmpty ? username[0].toUpperCase() : '?');

    DateTime timestamp = DateTime.now().toUtc();
    if (post['createdAt'] is String) {
      timestamp = DateTime.tryParse(post['createdAt'] as String)?.toUtc() ?? DateTime.now().toUtc();
    } else if (post['createdAt'] is DateTime) {
      timestamp = (post['createdAt'] as DateTime).toUtc();
    }

    final List<dynamic> likesList = post['likes'] as List<dynamic>? ?? [];
    final int likesCount = likesList.length;
    final int repostsCount = (post['reposts'] as List<dynamic>? ?? []).length;

    int viewsCount = 0;
    if (post.containsKey('viewsCount') && post['viewsCount'] is int) {
      viewsCount = post['viewsCount'] as int;
    } else if (post.containsKey('views') && post['views'] is List) {
      viewsCount = (post['views'] as List<dynamic>).length;
    }

    final int replyCount = (post['replies'] as List<dynamic>?)?.length ?? post['replyCount'] as int? ?? 0;
    final List<Map<String, dynamic>> attachments = (post['attachments'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

    bool isLikedByCurrentUser = false;
    bool isRepostedByCurrentUser = false;
    bool isBookmarkedByCurrentUser = false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.tealAccent.withOpacity(0.2),
            backgroundImage: userAvatar != null && userAvatar.isNotEmpty ? CachedNetworkImageProvider(userAvatar) : null,
            child: userAvatar == null || userAvatar.isEmpty
                ? Text(avatarInitial, style: GoogleFonts.poppins(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: 16))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(username, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis),
                          const SizedBox(width: 4.0),
                          Icon(Icons.verified, color: Colors.amber, size: 15),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Text(
                              '· ${timeago.format(timestamp.toLocal())}',
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(timestamp.toLocal()),
                      style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (content.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      children: _buildTextSpans(content, isReply: false),
                    ),
                  ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${attachments.length} attachment(s)',
                     style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                      FeatherIcons.messageCircle,
                      '$replyCount',
                      () { print("Search: Reply to $postId"); }
                    ),
                    _buildActionButton(
                      FeatherIcons.repeat,
                      '$repostsCount',
                      () { print("Search: Repost $postId"); },
                      isReposted: isRepostedByCurrentUser
                    ),
                    _buildActionButton(
                      isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart,
                      '$likesCount',
                      () { print("Search: Like $postId"); },
                      isLiked: isLikedByCurrentUser
                    ),
                    _buildActionButton(
                      FeatherIcons.eye,
                      '$viewsCount',
                      () { print("Search: View $postId"); }
                    ),
                    _buildActionButton(
                      FeatherIcons.bookmark,
                      '',
                      () { print("Search: Bookmark $postId"); },
                      isBookmarked: isBookmarkedByCurrentUser
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.roboto(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search Chatter...',
            hintStyle: GoogleFonts.roboto(color: Colors.grey[500]),
            border: InputBorder.none,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(FeatherIcons.x, color: Colors.grey[500]),
                    onPressed: () {
                      _searchController.clear();
                      if(mounted){
                        setState(() {
                          _searchQuery = '';
                          _searchResults = [];
                        });
                      }
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            if(mounted){
              setState(() {
                _searchQuery = value;
              });
            }
            _performSearch();
          },
          onSubmitted: (value) {
            _performSearch();
          },
        ),
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: _searchQuery.isEmpty && _searchResults.isEmpty
          ? Center(
              child: Text(
                'Search for posts by content or username.',
                style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
          : _searchResults.isEmpty && _searchQuery.isNotEmpty
              ? Center(
                  child: Text(
                    'No results found for "$_searchQuery"',
                    style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.grey[850],
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final post = _searchResults[index];
                    return GestureDetector(
                      onTap: () => _navigateToReplyPage(post),
                      behavior: HitTestBehavior.opaque,
                      child: _buildPostItem(post),
                    );
                  },
                ),
    );
  }
}
