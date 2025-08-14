import 'package:chatter/models/user_model.dart';

class ParticipantModel extends UserModel {
  final bool online;
  final DateTime? lastSeen;

  ParticipantModel({
    required String id,
    required String name,
    required String avatar,
    required this.online,
    this.lastSeen,
  }) : super(id: id, name: name, avatar: avatar);

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['_id'],
      name: json['name'],
      avatar: json['avatar'],
      online: json['online'] ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['online'] = online;
    data['lastSeen'] = lastSeen?.toIso8601String();
    return data;
  }
}
