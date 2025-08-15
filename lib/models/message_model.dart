import 'package:chatter/models/user_model.dart';

enum MessageStatus { sending, sent, delivered, read }

class Message {
  final String id;
  final String? content;
  final List<String>? attachments;
  final DateTime createdAt;
  final MessageStatus status;
  final User sender;

  Message({
    required this.id,
    this.content,
    this.attachments,
    required this.createdAt,
    required this.status,
    required this.sender,
  });
}
