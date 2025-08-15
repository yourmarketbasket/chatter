import 'package:chatter/models/user_model.dart';
import 'package:chatter/models/message_model.dart';

class Group {
  final String id;
  final String name;
  final String avatar;
  final List<User> participants;
  final List<Message> messages;

  Group({
    required this.id,
    required this.name,
    required this.avatar,
    required this.participants,
    required this.messages,
  });

  Message? get lastMessage {
    if (messages.isEmpty) {
      return null;
    }
    return messages.last;
  }
}
