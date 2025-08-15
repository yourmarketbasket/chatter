import 'package:chatter/models/user_model.dart';
import 'package:chatter/models/message_model.dart';

class Chat {
  final String id;
  final List<User> participants;
  final List<Message> messages;

  Chat({
    required this.id,
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
