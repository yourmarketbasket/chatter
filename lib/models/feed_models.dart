// Contents for lib/models/feed_models.dart
import 'dart:convert';

class Attachment {
  final String filename;
  final String url;
  final num size;
  final String? type;
  final String? thumbnailUrl;
  final String? aspectRatio; // Can be derived or stored
  final num? height;
  final num? width;
  final num? duration; // For videos
  final String? orientation; // e.g., "landscape", "portrait"

  Attachment({
    required this.filename,
    required this.url,
    required this.size,
    this.type,
    this.thumbnailUrl,
    this.aspectRatio,
    this.height,
    this.width,
    this.duration,
    this.orientation,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      filename: json['filename'] as String,
      url: json['url'] as String,
      size: json['size'] as num,
      type: json['type'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      aspectRatio: json['aspectRatio'] as String?,
      height: json['height'] as num?,
      width: json['width'] as num?,
      duration: json['duration'] as num?,
      orientation: json['orientation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'url': url,
      'size': size,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
      'aspectRatio': aspectRatio,
      'height': height,
      'width': width,
      'duration': duration,
      'orientation': orientation,
    };
  }
}

class Post {
  final String id;
  final String username;
  final String userId;
  final String? content;
  final List<String> likes;
  final List<String> reposts; // Changed from num to List<String>
  final List<String> views;   // Changed from num to List<String>
  final List<Attachment> attachments;
  final String? useravatar;
  final List<Post> replies; // Changed to List<Post> for nested replies
  final String? originalPostId;
  final String? repostedBy;
  final bool isRepost;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.username,
    required this.userId,
    this.content,
    this.likes = const [],
    this.reposts = const [], // Initialize with an empty list
    this.views = const [],   // Initialize with an empty list
    this.attachments = const [],
    this.useravatar,
    this.replies = const [],
    this.originalPostId,
    this.repostedBy,
    this.isRepost = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    var attachmentsList = <Attachment>[];
    if (json['attachments'] != null) {
      attachmentsList = (json['attachments'] as List)
          .map((i) => Attachment.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    var repliesList = <Post>[];
    if (json['replies'] != null && json['replies'] is List) {
      repliesList = (json['replies'] as List)
          .map((r) => Post.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    return Post(
      id: json['_id'] as String, // Assuming backend uses _id
      username: json['username'] as String,
      userId: json['userId'] as String,
      content: json['content'] as String?,
      likes: json['likes'] != null ? List<String>.from(json['likes'].map((x) => x.toString())) : [],
      reposts: json['reposts'] != null ? List<String>.from(json['reposts'].map((x) => x.toString())) : [],
      views: json['views'] != null ? List<String>.from(json['views'].map((x) => x.toString())) : [],
      attachments: attachmentsList,
      useravatar: json['useravatar'] as String?,
      replies: repliesList,
      originalPostId: json['originalPostId'] as String?,
      repostedBy: json['repostedBy'] as String?,
      isRepost: json['isRepost'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'userId': userId,
      'content': content,
      'likes': likes,
      'reposts': reposts,
      'views': views,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'useravatar': useravatar,
      'replies': replies.map((r) => r.toJson()).toList(),
      'originalPostId': originalPostId,
      'repostedBy': repostedBy,
      'isRepost': isRepost,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// Helper function for decoding a list of posts if needed elsewhere
List<Post> postsFromJson(String str) =>
    List<Post>.from((json.decode(str) as List<dynamic>).map((x) => Post.fromJson(x as Map<String,dynamic>)));

String postsToJson(List<Post> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));
