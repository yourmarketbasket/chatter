import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Verify User'),
            onTap: () {
              // TODO: Implement user verification UI
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Suspend User'),
            onTap: () {
              // TODO: Implement user suspension UI
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Flagged Posts'),
            onTap: () {
              // TODO: Implement flagged posts UI
            },
          ),
        ],
      ),
    );
  }
}
