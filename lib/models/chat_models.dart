import 'package:chatter/models/feed_models.dart';
import 'package:objectid/objectid.dart';

enum MessageStatus { sending, sent, delivered, read, failed }

class VoiceNote {
  final String url;
  final Duration duration;
  final List<double>? waveform;

  VoiceNote({
    required this.url,
    required this.duration,
    this.waveform,
  });

  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    return VoiceNote(
      url: json['url'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      waveform: (json['waveform'] as List<dynamic>?)?.map((e) => e as double).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'duration': duration.inMilliseconds,
      'waveform': waveform,
    };
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final List<Attachment>? attachments;
  final VoiceNote? voiceNote;
  final MessageStatus status;
  final DateTime createdAt;
  final String? replyTo; // This will be the ID of the message being replied to

  ChatMessage({
    String? id,
    required this.chatId,
    required this.senderId,
    this.text,
    this.attachments,
    this.voiceNote,
    this.status = MessageStatus.sending,
    DateTime? createdAt,
    this.replyTo,
  })  : id = id ?? ObjectId().hexString,
        createdAt = createdAt ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] as String,
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String?,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      voiceNote: json['voiceNote'] != null
          ? VoiceNote.fromJson(json['voiceNote'] as Map<String, dynamic>)
          : null,
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${json['status']}',
        orElse: () => MessageStatus.sent,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      replyTo: json['replyTo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'attachments': attachments?.map((e) => e.toJson()).toList(),
      'voiceNote': voiceNote?.toJson(),
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'replyTo': replyTo,
    };
  }
}

class Chat {
  final String id;
  final List<User> participants;
  final bool isGroup;
  final String? groupName;
  final String? groupAvatar;
  final ChatMessage? lastMessage;
  final int unreadCount;

  Chat({
    String? id,
    required this.participants,
    this.isGroup = false,
    this.groupName,
    this.groupAvatar,
    this.lastMessage,
    this.unreadCount = 0,
  }) : id = id ?? ObjectId().hexString;

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['_id'] as String,
      participants: (json['participants'] as List<dynamic>)
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
      isGroup: json['isGroup'] as bool,
      groupName: json['groupName'] as String?,
      groupAvatar: json['groupAvatar'] as String?,
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'participants': participants.map((e) => e.toJson()).toList(),
      'isGroup': isGroup,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
    };
  }
}
