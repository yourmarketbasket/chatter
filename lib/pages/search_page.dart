import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';


// Helper method to build post content, adapted from HomeFeedScreen
// We need to make _buildPostContent accessible or duplicate/refactor it.
// For now, let's assume we'll adapt parts of _HomeFeedScreenState's build logic.
// This is a simplified version for demonstration.
// Ideally, the post rendering logic should be in a reusable widget.

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
    // Initially, show all posts or an empty list
    // _performSearch(); // Uncomment if you want to load all posts initially
  }

  void _performSearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = []; // Clear results if search is empty
      });
      return;
    }

    final allPosts = _dataController.posts.toList();

    final filteredPosts = allPosts.where((post) {
      final content = post['content'] as String? ?? '';
      final username = post['username'] as String? ?? '';
      final contentMatches = content.toLowerCase().contains(_searchQuery.toLowerCase());
      final usernameMatches = username.toLowerCase().contains(_searchQuery.toLowerCase());
      // Add more criteria if needed, e.g., search in attachment filenames
      return contentMatches || usernameMatches;
    }).toList();

    setState(() {
      _searchResults = filteredPosts;
    });
  }

  // This widget is a simplified version of _buildPostContent from HomeFeedScreen.
  // For a full implementation, this should be refactored into a common widget.
import 'package:chatter/pages/reply_page.dart';
import 'package:timeago/timeago.dart' as timeago;


// Helper method to build post content, adapted from HomeFeedScreen
// We need to make _buildPostContent accessible or duplicate/refactor it.
// For now, let's assume we'll adapt parts of _HomeFeedScreenState's build logic.
// This is a simplified version for demonstration.
// Ideally, the post rendering logic should be in a reusable widget.

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
    // Initially, show all posts or an empty list
    // _performSearch(); // Uncomment if you want to load all posts initially
  }

  void _performSearch() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = []; // Clear results if search is empty
      });
      return;
    }

    final allPosts = _dataController.posts.toList(); // Make sure to use a copy

    final filteredPosts = allPosts.where((post) {
      final content = post['content'] as String? ?? '';
      final username = post['username'] as String? ?? '';
      final contentMatches = content.toLowerCase().contains(_searchQuery.toLowerCase());
      final usernameMatches = username.toLowerCase().contains(_searchQuery.toLowerCase());
      return contentMatches || usernameMatches;
    }).toList();

    setState(() {
      _searchResults = filteredPosts;
    });
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
    Color iconColor = Colors.white70; // Default color for non-dynamic icons like views, bookmark
    if (isLiked) {
      iconColor = Colors.redAccent;
    } else if (isReposted) {
      iconColor = Colors.tealAccent;
    } else if (isBookmarked) {
      iconColor = Colors.amber; // Example color for bookmarked
    }


    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: iconColor, size: 14), // Consistent with HomeFeedScreen
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.only(right: 2.0, left: 5.0),
          onPressed: onPressed,
        ),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: Text(
              text,
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 12), // Consistent
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
    // Potentially update view count or other metrics here if needed
    // _dataController.viewPost(post['_id']); // This might be done in ReplyPage itself
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
    // final String currentUserId = _dataController.user.value['user']?['_id'] ?? ''; // Needed for isLiked, isReposted
    // final bool isLikedByCurrentUser = likesList.any((like) => (like is Map ? like['_id'] == currentUserId : like.toString() == currentUserId));
    // final List<dynamic> repostsDynamicList = post['reposts'] as List<dynamic>? ?? [];
    // final List<String> repostsList = repostsDynamicList.map((e) => e.toString()).toList();
    final int repostsCount = (post['reposts'] as List<dynamic>? ?? []).length;
    // final bool isRepostedByCurrentUser = repostsList.contains(currentUserId);

    int viewsCount = 0;
    if (post.containsKey('viewsCount') && post['viewsCount'] is int) {
      viewsCount = post['viewsCount'] as int;
    } else if (post.containsKey('views') && post['views'] is List) {
      viewsCount = (post['views'] as List<dynamic>).length;
    }

    final int replyCount = (post['replies'] as List<dynamic>?)?.length ?? post['replyCount'] as int? ?? 0;
    final List<Map<String, dynamic>> attachments = (post['attachments'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

    // Placeholder: isLiked, isReposted, isBookmarked would come from post data or user state
    bool isLikedByCurrentUser = false;
    bool isRepostedByCurrentUser = false;
    bool isBookmarkedByCurrentUser = false; // Placeholder


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
                          Icon(Icons.verified, color: Colors.amber, size: 15), // Consistent with HomeFeedScreen
                          const SizedBox(width: 4.0),
                           // Using a simplified timestamp for search results for now, can be expanded
                          Expanded( // Wrap the time string in Expanded
                            child: Text(
                              '· ${timeago.format(timestamp.toLocal())}', // Simpler time for search results
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, yyyy').format(timestamp.toLocal()), // Date on the far right
                      style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (content.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      children: _buildTextSpans(content, isReply: false), // isReply is false for main posts
                    ),
                  ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${attachments.length} attachment(s)', // Simplified attachment display
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
                      () { print("Search: Reply to $postId"); /* Placeholder */ }
                    ),
                    _buildActionButton(
                      FeatherIcons.repeat,
                      '$repostsCount',
                      () { print("Search: Repost $postId"); /* Placeholder */ },
                      isReposted: isRepostedByCurrentUser
                    ),
                    _buildActionButton(
                      isLikedByCurrentUser ? Icons.favorite : FeatherIcons.heart,
                      '$likesCount',
                      () { print("Search: Like $postId"); /* Placeholder */ },
                      isLiked: isLikedByCurrentUser
                    ),
                    _buildActionButton(
                      FeatherIcons.eye,
                      '$viewsCount',
                      () { print("Search: View $postId"); /* Placeholder */ }
                    ),
                    _buildActionButton(
                      FeatherIcons.bookmark,
                      '',
                      () { print("Search: Bookmark $postId"); /* Placeholder */ },
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
                      setState(() {
                        _searchQuery = '';
                        _searchResults = [];
                      });
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
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
