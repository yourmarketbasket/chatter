import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatter/controllers/data-controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feather_icons/feather_icons.dart';

class GroupDetailsPage extends StatefulWidget {
  final String chatId;

  const GroupDetailsPage({Key? key, required this.chatId}) : super(key: key);

  @override
  _GroupDetailsPageState createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final DataController _dataController = Get.find<DataController>();
  // Placeholder for group details
  Map<String, dynamic> _groupDetails = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
  }

  Future<void> _fetchGroupDetails() async {
    setState(() {
      _isLoading = true;
    });
    final result = await _dataController.getGroupDetails(widget.chatId);
    if (result['success']) {
      setState(() {
        _groupDetails = result['group'];
        _isLoading = false;
      });
    } else {
      Get.snackbar(
        'Error',
        result['message'] ?? 'Failed to load group details.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text('Group Info', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.edit),
            onPressed: () {
              // TODO: Implement edit group info
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: CachedNetworkImageProvider(_groupDetails['groupAvatar']),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _groupDetails['groupName'],
                            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      '${_groupDetails['participants'].length} Members',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _groupDetails['participants'].length,
                    itemBuilder: (context, index) {
                      final participant = _groupDetails['participants'][index];
                      final bool isAdmin = _groupDetails['admins'].any((admin) => admin['name'] == participant['name']);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(participant['avatar']),
                        ),
                        title: Text(participant['name'], style: GoogleFonts.roboto(color: Colors.white)),
                        trailing: isAdmin ? Text('Admin', style: GoogleFonts.roboto(color: Colors.tealAccent)) : null,
                        onLongPress: () {
                          // Show options for this participant
                          _showParticipantOptions(context, participant, isAdmin);
                        },
                      );
                    },
                  ),
                  const Divider(color: Colors.grey),
                  ListTile(
                    leading: const Icon(FeatherIcons.userPlus, color: Colors.tealAccent),
                    title: Text('Add Members', style: GoogleFonts.roboto(color: Colors.tealAccent)),
                    onTap: () {
                      // Navigate to a new page to select users to add
                    },
                  ),
                  ListTile(
                    leading: const Icon(FeatherIcons.link, color: Colors.tealAccent),
                    title: Text('Invite via Link', style: GoogleFonts.roboto(color: Colors.tealAccent)),
                    onTap: () async {
                      final result = await _dataController.createGroupInviteLink(widget.chatId);
                      if (result['success']) {
                        // Show the invite link in a dialog
                        Get.defaultDialog(
                          title: 'Invite Link',
                          middleText: 'Share this link to invite others to the group: ${result['inviteToken']}',
                        );
                      } else {
                        Get.snackbar('Error', result['message'] ?? 'Failed to create invite link.');
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(FeatherIcons.logOut, color: Colors.redAccent),
                    title: Text('Leave Group', style: GoogleFonts.roboto(color: Colors.redAccent)),
                    onTap: () async {
                      final result = await _dataController.leaveGroup(widget.chatId);
                      if (result['success']) {
                        Get.back(); // Go back to conversation list
                      } else {
                        Get.snackbar('Error', result['message'] ?? 'Failed to leave group.');
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }

  void _showParticipantOptions(BuildContext context, Map<String, dynamic> participant, bool isAdmin) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(participant['name'], style: GoogleFonts.poppins(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isAdmin)
                ListTile(
                  leading: const Icon(FeatherIcons.star, color: Colors.white),
                  title: Text('Make Admin', style: GoogleFonts.roboto(color: Colors.white)),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final result = await _dataController.promoteMemberToAdmin(widget.chatId, participant['_id']);
                    if (result['success']) {
                      _fetchGroupDetails(); // Refresh details
                    } else {
                      Get.snackbar('Error', result['message'] ?? 'Failed to promote member.');
                    }
                  },
                ),
              ListTile(
                leading: const Icon(FeatherIcons.userX, color: Colors.redAccent),
                title: Text('Remove from Group', style: GoogleFonts.roboto(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.of(context).pop();
                  final result = await _dataController.removeMemberFromGroup(widget.chatId, participant['_id']);
                  if (result['success']) {
                    _fetchGroupDetails(); // Refresh details
                  } else {
                    Get.snackbar('Error', result['message'] ?? 'Failed to remove member.');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
