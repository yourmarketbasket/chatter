import 'package:chatter/models/chat_model.dart';
import 'package:chatter/models/message_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://chatter-api.fly.dev/api',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  Future<String?> _getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<List<ChatModel>> getChats() async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token not found');
      }
      final response = await _dio.get(
        '/chats',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ChatModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load chats');
      }
    } catch (e) {
      print(e);
      throw Exception('Failed to load chats');
    }
  }

  Future<ChatModel> createChat(String receiverId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token not found');
      }
      final response = await _dio.post(
        '/chats',
        data: {'receiverId': receiverId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatModel.fromJson(response.data);
      } else {
        throw Exception('Failed to create chat');
      }
    } catch (e) {
      print(e);
      throw Exception('Failed to create chat');
    }
  }

  Future<List<MessageModel>> getMessages(String chatId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token not found');
      }
      final response = await _dio.get(
        '/chats/$chatId/messages',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => MessageModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      print(e);
      throw Exception('Failed to load messages');
    }
  }

  Future<MessageModel> editMessage(String chatId, String messageId, String content) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token not found');
      }
      final response = await _dio.put(
        '/chats/$chatId/messages/$messageId',
        data: {'content': content},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode == 200) {
        return MessageModel.fromJson(response.data);
      } else {
        throw Exception('Failed to edit message');
      }
    } catch (e) {
      print(e);
      throw Exception('Failed to edit message');
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token not found');
      }
      final response = await _dio.delete(
        '/chats/$chatId/messages/$messageId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete message');
      }
    } catch (e) {
      print(e);
      throw Exception('Failed to delete message');
    }
  }
}
