import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:chatter/controllers/data-controller.dart';
import 'package:get/get.dart';

class SocketService {
  IO.Socket? _socket;
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  final DataController _dataController = Get.find<DataController>();

  SocketService() {
    _initializeSocket();
    connect(); // Automatically connect during initialization
  }

  void _initializeSocket() {
    _socket = IO.io('https://chatter-api.fly.dev/', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true, // Enable automatic reconnection
      'reconnectionAttempts': 10, // Number of reconnection attempts
      'reconnectionDelay': 3000, // Delay between reconnection attempts (ms)
    });

    // listen for welcome event
    

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket!.onConnectError((error) {
      print('Connection error: $error');
      // Additional reconnection handling if needed
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

    _socket!.on('message', (data) {
      try {
        if (data is String) {
          _messageController.add(data);
        } else {
          print('Invalid message format: $data');
        }
      } catch (e) {
        print('Error processing message: $e');
      }
    });
    // listen for welcome event
    _socket!.on('welcome', (data){
      print('Welcome event received: $data');
      // Handle welcome event data if needed
    });
    // listen fore newPost event
    _socket!.on('newPost', (data) {
      print('New post event received: $data');
      if (data is Map<String, dynamic>) {
        // Assuming 'data' is the post object in the correct format
        _dataController.addNewPost(data);
      } else {
        print('Received newPost event with unexpected data type: ${data.runtimeType}');
        // Optionally, attempt to convert or log more details if the structure is known but different
        // For example, if it's a JSON string:
        // if (data is String) {
        //   try {
        //     final Map<String, dynamic> parsedData = jsonDecode(data);
        //     _dataController.addNewPost(parsedData);
        //   } catch (e) {
        //     print('Error decoding newPost JSON string: $e');
        //   }
        // }
      }
    });
  }

  void connect() {
    if (_socket != null && !_socket!.connected) {
      _socket!.connect();
    }
  }

  void disconnect() {
    if (_socket != null && _socket!.connected) {
      _socket!.disconnect();
    }
  }

  void sendMessage(String message) {
    if (_socket != null && _socket!.connected && message.isNotEmpty) {
      _socket!.emit('message', message);
    } else {
      print('Cannot send message: Socket is not connected or message is empty');
    }
  }

  Stream<String> get messages => _messageController.stream;

  void dispose() {
    disconnect(); // Ensure socket is disconnected
    _socket?.dispose();
    _socket = null;
    if (!_messageController.isClosed) {
      _messageController.close();
    }
  }
}