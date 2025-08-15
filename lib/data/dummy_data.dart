import 'package:chatter/models/user_model.dart';
import 'package:chatter/models/message_model.dart';
import 'package:chatter/models/chat_model.dart';
import 'package:chatter/models/group_model.dart';
import 'package:objectid/objectid.dart';

// Dummy Users
final User currentUser = User(
  id: 'you',
  name: 'You',
  avatar: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
);

final User user1 = User(
  id: ObjectId().hexString,
  name: 'Alice',
  avatar: 'https://i.pravatar.cc/150?u=a042581f4e29026704e',
);

final User user2 = User(
  id: ObjectId().hexString,
  name: 'Bob',
  avatar: 'https://i.pravatar.cc/150?u=a042581f4e29026704f',
);

final User user3 = User(
  id: ObjectId().hexString,
  name: 'Charlie',
  avatar: 'https://i.pravatar.cc/150?u=a042581f4e29026704a',
);

final User user4 = User(
  id: ObjectId().hexString,
  name: 'David',
  avatar: 'https://i.pravatar.cc/150?u=a042581f4e29026704b',
);

final List<User> users = [user1, user2, user3, user4];

// Dummy Messages
final List<Message> messages1 = [
  Message(
    id: ObjectId().hexString,
    content: 'Hey, how are you?',
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    status: MessageStatus.read,
    sender: user1,
  ),
  Message(
    id: ObjectId().hexString,
    content: 'I am good, thanks! How about you?',
    createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
    status: MessageStatus.read,
    sender: currentUser,
  ),
];

final List<Message> messages2 = [
  Message(
    id: ObjectId().hexString,
    content: 'Let\'s catch up later.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    status: MessageStatus.read,
    sender: user2,
  ),
];

final List<Message> messages3 = [
  Message(
    id: ObjectId().hexString,
    content: 'See you at the meeting.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    status: MessageStatus.delivered,
    sender: user3,
  ),
];

// Dummy Chats
final List<Chat> chats = [
  Chat(
    id: ObjectId().hexString,
    participants: [currentUser, user1],
    messages: messages1,
  ),
  Chat(
    id: ObjectId().hexString,
    participants: [currentUser, user2],
    messages: messages2,
  ),
  Chat(
    id: ObjectId().hexString,
    participants: [currentUser, user3],
    messages: messages3,
  ),
];

// Dummy Groups
final List<Group> groups = [
  Group(
    id: ObjectId().hexString,
    name: 'Flutter Devs',
    avatar: 'https://i.pravatar.cc/150?u=a042581f4e29026704g',
    participants: [currentUser, user1, user2, user4],
    messages: [
      Message(
        id: ObjectId().hexString,
        content: 'Welcome to the Flutter Devs group!',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        status: MessageStatus.read,
        sender: user1,
      ),
      Message(
        id: ObjectId().hexString,
        content: 'Anyone working on a new project?',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        status: MessageStatus.read,
        sender: user4,
      ),
    ],
  ),
  Group(
    id: ObjectId().hexString,
    name: 'Design Team',
    avatar: 'https://i.pravatar.cc/150?u=a042581f4e29026704h',
    participants: [currentUser, user3],
    messages: [
      Message(
        id: ObjectId().hexString,
        content: 'Here are the new mockups.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        status: MessageStatus.read,
        sender: user3,
      ),
    ],
  ),
];
