import 'dart:convert';

// Helper function to decode a list of posts
List<Post> postsFromJson(String str) =>
    List<Post>.from((json.decode(str) as List<dynamic>).map((x) => Post.fromJson(x as Map<String, dynamic>)));

// Helper function to encode a list of posts
String postsToJson(List<Post> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class User {
  final String id;
  final String name;
  final String? avatar;
  final bool? online;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.name,
    this.avatar,
    this.online,
    this.lastSeen,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      online: json['online'] as bool?,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'avatar': avatar,
      'online': online,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? avatar,
    bool? online,
    DateTime? lastSeen,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class Attachment {
  final String filename;
  final String url;
  final num size;
  final String? type;
  final String? thumbnailUrl;

  Attachment({
    required this.filename,
    required this.url,
    required this.size,
    this.type,
    this.thumbnailUrl,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      filename: json['filename'] as String,
      url: json['url'] as String,
      size: json['size'] as num,
      type: json['type'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'url': url,
      'size': size,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

class Reply {
  final String id;
  final String content;
  final User author;
  final List<String> likes;
  final List<Reply> replies; // Nested replies
  final bool edited;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reply({
    required this.id,
    required this.content,
    required this.author,
    this.likes = const [],
    this.replies = const [],
    this.edited = false,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['_id'] as String,
      content: json['content'] as String? ?? '',
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      likes: (json['likes'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      replies: (json['replies'] as List<dynamic>? ?? [])
          .map((r) => Reply.fromJson(r as Map<String, dynamic>))
          .toList(),
      edited: json['edited'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'content': content,
      'author': author.toJson(),
      'likes': likes,
      'replies': replies.map((r) => r.toJson()).toList(),
      'edited': edited,
      'deleted': deleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class Post {
  final String id;
  final String? content;
  final User author;
  final List<Attachment> attachments;
  final List<String> likes;
  final List<String> reposts;
  final List<String> views;
  final List<Reply> replies;
  final bool edited;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    this.content,
    required this.author,
    this.attachments = const [],
    this.likes = const [],
    this.reposts = const [],
    this.views = const [],
    this.replies = const [],
    this.edited = false,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] as String,
      content: json['content'] as String?,
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
          .toList(),
      likes: (json['likes'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      reposts: (json['reposts'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      views: (json['views'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      replies: (json['replies'] as List<dynamic>? ?? [])
          .map((r) => Reply.fromJson(r as Map<String, dynamic>))
          .toList(),
      edited: json['edited'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'content': content,
      'author': author.toJson(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'likes': likes,
      'reposts': reposts,
      'views': views,
      'replies': replies.map((r) => r.toJson()).toList(),
      'edited': edited,
      'deleted': deleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
