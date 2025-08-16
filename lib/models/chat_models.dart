import 'package:chatter/models/feed_models.dart';
import 'package:objectid/objectid.dart';

enum MessageStatus { sending, sent, delivered, read, failed }
// forced

class Attachment {
  final String id;
  final String filename;
  final String url;
  final int size;
  final String? type;
  final bool isUploading;
  final double uploadProgress;
  final bool isDownloading;
  final double downloadProgress;

  Attachment({
    String? id,
    required this.filename,
    required this.url,
    required this.size,
    this.type,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  }) : id = id ?? ObjectId().hexString;

  Attachment copyWith({
    String? id,
    String? filename,
    String? url,
    int? size,
    String? type,
    bool? isUploading,
    double? uploadProgress,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return Attachment(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      url: url ?? this.url,
      size: size ?? this.size,
      type: type ?? this.type,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['_id'] as String,
      filename: json['filename'] as String,
      url: json['url'] as String,
      size: json['size'] as int,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'filename': filename,
      'url': url,
      'size': size,
      'type': type,
    };
  }
}

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
  final bool edited;
  final bool deleted;

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
    this.edited = false,
    this.deleted = false,
  })  : id = id ?? ObjectId().hexString,
        createdAt = createdAt ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    List<Attachment>? attachments,
    VoiceNote? voiceNote,
    MessageStatus? status,
    DateTime? createdAt,
    String? replyTo,
    bool? edited,
    bool? deleted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      voiceNote: voiceNote ?? this.voiceNote,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      replyTo: replyTo ?? this.replyTo,
      edited: edited ?? this.edited,
      deleted: deleted ?? this.deleted,
    );
  }

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
      edited: json['edited'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
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
      'edited': edited,
      'deleted': deleted,
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
