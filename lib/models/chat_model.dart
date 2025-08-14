import 'package:chatter/models/message_model.dart';
import 'package.chatter/models/participant_model.dart';

class ChatModel {
  final String id;
  final List<ParticipantModel> participants;
  final MessageModel? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['_id'],
      participants: (json['participants'] as List)
          .map((p) => ParticipantModel.fromJson(p))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

   Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'participants': participants.map((p) => p.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
