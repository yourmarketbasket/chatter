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
  Widget _buildPostItem(Map<String, dynamic> post) {
    // Use a _HomeFeedScreenState instance to call _buildPostContent.
    // This is a workaround. Ideally, _buildPostContent should be a static method or in a separate widget.
    // Creating a dummy _HomeFeedScreenState or refactoring _buildPostContent is necessary.
    // For now, let's build a simplified version here.

    // Accessing _HomeFeedScreenState's methods directly is not clean.
    // Let's try to replicate the necessary parts or make it static/reusable.
    // As a quick solution, we'll mimic the structure.
    // This is a known limitation of this approach and should be refactored in a real scenario.

    final String username = post['username'] as String? ?? 'Unknown User';
    final String content = post['content'] as String? ?? '';
    final DateTime timestamp = post['createdAt'] is String
        ? DateTime.parse(post['createdAt'] as String)
        : DateTime.now(); // Default to now if parsing fails or type is wrong
    // final int likes = post['likes'] as int? ?? 0; // Not displayed in this simplified view
    // final int reposts = post['reposts'] as int? ?? 0; // Not displayed
    // final int views = post['views'] as int? ?? 0; // Not displayed
    final String? useravatar = post['useravatar'] as String?;
    final String avatarInitial = (username.isNotEmpty) ? username[0].toUpperCase() : '?';
    final List<dynamic> attachments = post['attachments'] as List<dynamic>? ?? [];


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.tealAccent.withOpacity(0.2),
                backgroundImage: useravatar != null && useravatar.isNotEmpty
                    ? CachedNetworkImageProvider(useravatar)
                    : null,
                child: useravatar == null || useravatar.isEmpty
                    ? Text(
                        avatarInitial,
                        style: GoogleFonts.poppins(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      )
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
                        Text(
                          '@$username',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          DateFormat('h:mm a · MMM d').format(timestamp),
                          style: GoogleFonts.roboto(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      // _buildAttachmentGrid should be used here.
                      // For simplicity, we'll just indicate attachments exist.
                      // This part needs the full _HomeFeedScreenState context or a refactor.
                       Text(
                        '${attachments.length} attachment(s)',
                        style: GoogleFonts.roboto(color: Colors.tealAccent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Action buttons (like, reply, repost, views) would go here.
                    // Omitting for brevity in this search page example.
                    // You would need to replicate or refactor the action button row from HomeFeedScreen.
                  ],
                ),
              ),
            ],
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
                    // Use the adapted _buildPostItem
                    return _buildPostItem(post);
                  },
                ),
    );
  }
}
