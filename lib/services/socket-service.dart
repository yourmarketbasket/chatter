import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:chatter/controllers/data-controller.dart';
import 'package:get/get.dart';

class SocketService {
  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final DataController _dataController = Get.find<DataController>();
  bool _isInitialized = false;

  SocketService() {
    _initializeSocket();
    connect();
  }

  void _initializeSocket() {
    if (_isInitialized) return;

    _socket = IO.io('http://192.168.1.104:3000/', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 3000,
    });

    _setupSocketListeners();
    _isInitialized = true;
  }

  void _setupSocketListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      print('Socket connected');
      _eventController.add({'event': 'connect', 'data': null});
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
      _eventController.add({'event': 'disconnect', 'data': null});
    });

    _socket!.onConnectError((error) {
      print('Connection error: $error');
      _eventController.add({'event': 'connect_error', 'data': error});
    });

    _socket!.onError((error) {
      print('Socket error: $error');
      _eventController.add({'event': 'error', 'data': error});
    });

    // Core event handlers
    final eventHandlers = {
      'welcome': (data) {
        print('Welcome event received: $data');
        _eventController.add({'event': 'welcome', 'data': data});
      },
      'message': (data) {
        try {
          if (data is String) {
            _eventController.add({'event': 'message', 'data': data});
          } else {
            print('Invalid message format: $data');
          }
        } catch (e) {
          print('Error processing message: $e');
        }
      },
      'newPost': (data) => _handleNewPost(data),
      'newReply': (data) => _handleNewReply(data),
      'newReplyToReply': (data) => _handleNewReplyToReply(data),
      'postViewed': (data) => _handlePostAction(data, 'postViewed'),
      'postLiked': (data) => _handlePostAction(data, 'postLiked'),
      'postUnliked': (data) => _handlePostAction(data, 'postUnliked'),
      'postReposted': (data) => _handlePostAction(data, 'postReposted'),
      'replyLiked': (data) => _handleReplyAction(data, 'replyLiked'),
      'replyUnliked': (data) => _handleReplyAction(data, 'replyUnliked'),
      'replyReposted': (data) => _handleReplyAction(data, 'replyReposted'),
      'replyViewed': (data) => _handleReplyAction(data, 'replyViewed'),
      'newMessage': (data) => _handleNewMessage(data),
      'typing:start': (data) => _handleTyping(data, true),
      'typing:stop': (data) => _handleTyping(data, false),
      'userFollowed': (data) => _handleUserAction(data, 'userFollowed'),
      'userUnfollowed': (data) => _handleUserAction(data, 'userUnfollowed'),
    };

    eventHandlers.forEach((event, handler) {
      _socket!.on(event, handler);
    });
  }

  void _handleNewPost(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.addNewPost(data);
      _eventController.add({'event': 'newPost', 'data': data});
    } else {
      print('Invalid newPost data format: ${data.runtimeType}');
    }
  }

  void _handleNewReply(dynamic data) {
    if (data is Map<String, dynamic>) {
      final parentPostId = data['parentPostId'] as String?;
      final reply = data['reply'] as Map<String, dynamic>?;
      if (parentPostId != null && reply != null) {
        _dataController.handleNewReply(parentPostId, reply);
        _eventController.add({'event': 'newReply', 'data': data});
      } else {
        print('Invalid newReply data: $data');
      }
    } else {
      print('Invalid newReply data format: ${data.runtimeType}');
    }
  }

  void _handleNewReplyToReply(dynamic data) {
    if (data is Map<String, dynamic>) {
      final postId = data['postId'] as String?;
      final parentReplyId = data['parentReplyId'] as String?;
      final reply = data['reply'] as Map<String, dynamic>?;
      if (postId != null && parentReplyId != null && reply != null) {
        _dataController.handleNewReplyToReply(postId, parentReplyId, reply);
        _eventController.add({'event': 'newReplyToReply', 'data': data});
      } else {
        print('Invalid newReplyToReply data: $data');
      }
    } else {
      print('Invalid newReplyToReply data format: ${data.runtimeType}');
    }
  }

  void _handlePostAction(dynamic data, String event) {
    if (data is Map<String, dynamic>) {
      final postId = data['postId'] as String? ?? data['_id'] as String?;
      if (postId != null) {
        _dataController.fetchSinglePost(postId);
        _eventController.add({'event': event, 'data': data});
      } else {
        print('Invalid $event data: missing postId or _id');
      }
    } else {
      print('Invalid $event data format: ${data.runtimeType}');
    }
  }

  void _handleReplyAction(dynamic data, String event) {
    if (data is Map<String, dynamic>) {
      final rootPostId = data['postId'] as String?;
      if (rootPostId != null) {
        _dataController.fetchSinglePost(rootPostId);
        _eventController.add({'event': event, 'data': data});
      } else {
        print('Invalid $event data: missing postId');
      }
    } else {
      print('Invalid $event data format: ${data.runtimeType}');
    }
  }

  void _handleNewMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleNewMessage(data);
      _eventController.add({'event': 'newMessage', 'data': data});
    } else {
      print('Invalid newMessage data format: ${data.runtimeType}');
    }
  }

  void _handleTyping(dynamic data, bool isStart) {
    if (data is Map<String, dynamic>) {
      if (isStart) {
        _dataController.handleTypingStart(data);
      } else {
        _dataController.handleTypingStop(data);
      }
      _eventController.add({'event': isStart ? 'typing:start' : 'typing:stop', 'data': data});
    } else {
      print('Invalid typing:${isStart ? 'start' : 'stop'} data format: ${data.runtimeType}');
    }
  }

  void _handleUserAction(dynamic data, String event) {
    if (data is Map<String, dynamic>) {
      if (event == 'userFollowed') {
        _dataController.handleUserFollowedSocket(data);
      } else {
        _dataController.handleUserUnfollowedSocket(data);
      }
      _eventController.add({'event': event, 'data': data});
    } else {
      print('Invalid $event data format: ${data.runtimeType}');
    }
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

  void emitEvent(String event, dynamic data) {
    if (_socket != null && _socket!.connected && data != null) {
      _socket!.emit(event, data);
    } else {
      print('Cannot emit event: Socket not connected or data is null');
    }
  }

  void sendMessage(String message) {
    emitEvent('message', message);
  }

  void sendTypingStart(String chatId) {
    emitEvent('typing:start', {'chatId': chatId});
  }

  void sendTypingStop(String chatId) {
    emitEvent('typing:stop', {'chatId': chatId});
  }

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void addListener(String event, void Function(dynamic) handler) {
    if (_socket != null) {
      _socket!.on(event, handler);
    }
  }

  void removeListener(String event, void Function(dynamic) handler) {
    if (_socket != null) {
      _socket!.off(event, handler);
    }
  }

  void dispose() {
    disconnect();
    _socket?.clearListeners();
    _socket?.dispose();
    _socket = null;
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    _isInitialized = false;
  }
}