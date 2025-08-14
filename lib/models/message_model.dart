import 'package:chatter/models/user_model.dart';

class MessageModel {
  final String id;
  final UserModel sender;
  final String content;
  final bool isRead;
  final bool edited;
  final bool deleted;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.sender,
    required this.content,
    required this.isRead,
    required this.edited,
    required this.deleted,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'],
      sender: UserModel.fromJson(json['sender']),
      content: json['content'],
      isRead: json['isRead'] ?? false,
      edited: json['edited'] ?? false,
      deleted: json['deleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

   Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender': sender.toJson(),
      'content': content,
      'isRead': isRead,
      'edited': edited,
      'deleted': deleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
