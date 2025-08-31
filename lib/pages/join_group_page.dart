import 'package:chatter/pages/main_chats.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatter/controllers/data-controller.dart';

class JoinGroupPage extends StatefulWidget {
  final String inviteCode;

  const JoinGroupPage({Key? key, required this.inviteCode}) : super(key: key);

  @override
  _JoinGroupPageState createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final DataController _dataController = Get.find<DataController>();
  Map<String, dynamic>? _groupDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
  }

  Future<void> _fetchGroupDetails() async {
    // This method and endpoint are assumed
    final details = await _dataController.getGroupDetailsFromInvite(widget.inviteCode);
    if (mounted) {
      setState(() {
        if (details != null) {
          _groupDetails = details;
        } else {
          _error = 'Could not find group for this invite link.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGroup() async {
    // This method and endpoint are assumed
    final success = await _dataController.joinGroupFromInvite(widget.inviteCode);
    if (success) {
      Get.offAll(() => const MainChatsPage()); // Navigate to chats page on success
      Get.snackbar('Success', 'You have joined the group!');
    } else {
      setState(() {
        _error = 'Failed to join group. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Group')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.red))
                : _groupDetails != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _groupDetails!['groupAvatar'] != null && _groupDetails!['groupAvatar'].isNotEmpty
                                ? NetworkImage(_groupDetails!['groupAvatar'])
                                : null,
                            child: _groupDetails!['groupAvatar'] == null || _groupDetails!['groupAvatar'].isEmpty
                                ? const Icon(Icons.group, size: 50)
                                : null,
                          ),
                          const SizedBox(height: 20),
                          Text('You have been invited to join', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Text(_groupDetails!['name'] ?? 'Unnamed Group', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text('${_groupDetails!['participants']?.length ?? 0} members'),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _joinGroup,
                            child: const Text('Join Group'),
                          ),
                        ],
                      )
                    : const Text('Something went wrong.'),
      ),
    );
  }
}
