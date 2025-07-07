import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:intl/intl.dart'; // For formatting join date

class ProfilePage extends StatefulWidget {
  final String userId;
  final String username;
  final String? userAvatarUrl; // Initial avatar, can be updated from fetched data

  const ProfilePage({
    Key? key,
    required this.userId, // Still useful for context, even if username is primary key for fetch
    required this.username,
    this.userAvatarUrl,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DataController _dataController = Get.find<DataController>();

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String? _error;
  bool _isFollowProcessing = false; // For Follow/Unfollow button loading state

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final result = await _dataController.fetchUserProfile(widget.username);

    if (!mounted) return;

    if (result['success'] == true && result['user'] != null) {
      setState(() {
        _profileData = result['user'] as Map<String, dynamic>;
        if (showLoading) _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message'] as String? ?? 'Failed to load profile.';
        if (showLoading) _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowProcessing || _profileData == null) return;

    setState(() {
      _isFollowProcessing = true;
    });

    final String loggedInUserId = _dataController.user.value['user']?['_id'] ?? '';
    final String targetUserId = _profileData!['_id'] as String; // ID of the profile being viewed

    // Determine if currently following
    final List<dynamic> followersList = _profileData!['followers'] as List<dynamic>? ?? [];
    // Assuming followersList contains user IDs or objects with an _id field
    final bool isCurrentlyFollowing = followersList.any((follower) {
        if (follower is String) return follower == loggedInUserId;
        if (follower is Map && follower.containsKey('_id')) return follower['_id'] == loggedInUserId;
        return false;
    });

    Map<String, dynamic> result;
    if (isCurrentlyFollowing) {
      result = await _dataController.unfollowUser(targetUserId);
    } else {
      result = await _dataController.followUser(targetUserId);
    }

    if (mounted) {
      setState(() {
        _isFollowProcessing = false;
      });
      if (result['success'] == true) {
        // Refresh profile data to get updated follower counts and button state
        _loadProfileData(showLoading: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Action successful!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Action failed.'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Determine display values: fetched data takes precedence, fallback to widget props
    final String displayName = _profileData?['name'] as String? ?? widget.username;
    final String? displayAvatarUrl = _profileData?['avatar'] as String? ?? widget.userAvatarUrl;
    final String avatarInitial = (displayName.isNotEmpty) ? displayName[0].toUpperCase() : '?';

    String joinDateFormatted = 'Join date not available';
    if (_profileData?['createdAt'] != null) {
      try {
        final DateTime joinDate = DateTime.parse(_profileData!['createdAt'] as String);
        joinDateFormatted = 'Joined: ${DateFormat('MMM d, yyyy').format(joinDate.toLocal())}';
      } catch (e) {
        print("Error parsing join date: $e");
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          displayName,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FeatherIcons.alertTriangle, color: Colors.redAccent, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: Icon(FeatherIcons.refreshCw, size: 18),
                          label: Text('Retry'),
                          onPressed: _loadProfileData,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                        )
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.tealAccent.withOpacity(0.2),
                          backgroundImage: displayAvatarUrl != null && displayAvatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(displayAvatarUrl)
                              : null,
                          child: (displayAvatarUrl == null || displayAvatarUrl.isEmpty)
                              ? Text(
                                  avatarInitial,
                                  style: GoogleFonts.poppins(
                                    color: Colors.tealAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 50,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '@$displayName',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_profileData?['createdAt'] != null)
                          Text(
                            joinDateFormatted,
                            style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
                          ),
                        const SizedBox(height: 20),
                        // Followers and Following Counts
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                // ignore: prefer_interpolation_to_compose_strings
                                'Followers: ' + (_profileData?['followers'] as List<dynamic>? ?? []).length.toString(),
                                style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 14),
                              ),
                              Text(
                                '  ·  ',
                                style: GoogleFonts.roboto(color: Colors.grey[500], fontSize: 14),
                              ),
                              Text(
                                // ignore: prefer_interpolation_to_compose_strings
                                'Following: ' + (_profileData?['following'] as List<dynamic>? ?? []).length.toString(),
                                style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Follow/Unfollow and DM Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (_dataController.user.value['user']?['_id'] != _profileData?['_id']) // Don't show follow button for own profile
                              ElevatedButton.icon(
                                icon: Icon(
                                  (_profileData?['followers'] as List<dynamic>? ?? []).any((f) => (f is String ? f : f?['_id']) == _dataController.user.value['user']?['_id'])
                                    ? FeatherIcons.userMinus // Already following: show Unfollow
                                    : FeatherIcons.userPlus, // Not following: show Follow
                                  color: (_profileData?['followers'] as List<dynamic>? ?? []).any((f) => (f is String ? f : f?['_id']) == _dataController.user.value['user']?['_id'])
                                    ? Colors.black
                                    : Colors.black, // Icon color
                                  size: 18,
                                ),
                                label: Text(
                                  _isFollowProcessing
                                    ? 'Processing...'
                                    : (_profileData?['followers'] as List<dynamic>? ?? []).any((f) => (f is String ? f : f?['_id']) == _dataController.user.value['user']?['_id'])
                                      ? 'Unfollow'
                                      : 'Follow',
                                  style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (_profileData?['followers'] as List<dynamic>? ?? []).any((f) => (f is String ? f : f?['_id']) == _dataController.user.value['user']?['_id'])
                                    ? Colors.grey[400] // Style for "Unfollow"
                                    : Colors.tealAccent, // Style for "Follow"
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isFollowProcessing ? null : _toggleFollow,
                              ),
                            ElevatedButton.icon(
                              icon: Icon(FeatherIcons.messageCircle, color: Colors.black, size: 18),
                              label: Text(
                                'Message',
                                style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                print('Direct Message button tapped for user ${widget.userId} ($displayName)');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Direct Message functionality coming soon for $displayName!', style: GoogleFonts.roboto()),
                                    backgroundColor: Colors.tealAccent.withOpacity(0.8),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey[800], thickness: 0.5),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'About', // Changed from "About Me" to "About"
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _profileData?['about'] as String? ?? 'No bio yet.', // Display actual 'about' text or fallback
                            style: GoogleFonts.roboto(
                              color: Colors.grey[300],
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
