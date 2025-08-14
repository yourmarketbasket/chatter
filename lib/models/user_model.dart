class UserModel {
  final String id;
  final String name;
  final String avatar;

  UserModel({
    required this.id,
    required this.name,
    required this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'],
      name: json['name'],
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'avatar': avatar,
    };
  }
}
