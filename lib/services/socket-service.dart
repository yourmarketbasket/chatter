import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:chatter/controllers/data-controller.dart';
import 'package:get/get.dart';

class SocketService {
  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final DataController _dataController = Get.find<DataController>();
  bool _isInitialized = false;
  String? _userId; // Store userId for joining rooms and emitting events

  SocketService() {
    // print('SocketService: Instance created.');
  }

  void initSocket() {
    if (_isInitialized) {
      // print('SocketService: Already initialized, skipping.');
      return;
    }

    try {
      // print('SocketService: Creating socket with http://192.168.1.104:3000');
      _socket = IO.io('http://192.168.1.104:3000', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 10,
        'reconnectionDelay': 3000,
        'forceNew': true,
        // Add authentication token for backend's socketAuthenticator
        'auth': {
          'token': _dataController.getAuthToken(), // Assume DataController provides JWT token
        },
      });

      _setupSocketListeners();
      _isInitialized = true;
      // print('SocketService: Initialization complete. Ready to connect.');
      // connect() will be called explicitly by the DataController after data is ready.
    } catch (e) {
      // print('SocketService: Failed to initialize socket: $e');
    }
  }

  void _setupSocketListeners() {
    if (_socket == null) {
      // print('SocketService: Cannot setup listeners, socket is null.');
      return;
    }

    _socket!.onConnect((_) {
      // print('SocketService: Connected to server');
      _userId = _dataController.getUserId(); // Assume DataController provides userId
      if (_userId != null) {
        // Join user's own room (matches backend's socket.join(userId))
        _socket!.emit('join', {'userId': _userId});
        // Fetch and join active chat rooms
        syncAllChatRooms();
      }
      _eventController.add({'event': 'connect', 'data': null});
    });

    _socket!.onDisconnect((_) {
      // print('SocketService: Disconnected from server');
      _eventController.add({'event': 'disconnect', 'data': null});
    });

    _socket!.onConnectError((error) {
      // print('SocketService: Connection error: $error');
      _eventController.add({'event': 'connect_error', 'data': error.toString()});
    });

    _socket!.onError((error) {
      // print('SocketService: Socket error: $error');
      _eventController.add({'event': 'error', 'data': error.toString()});
    });

    // Core event handlers (retained all existing handlers)
    final eventHandlers = {
      'user:online': (data) => _handleUserAction(data, 'user:online'),
      'user:offline': (data) => _handleUserAction(data, 'user:offline'),
      'user:new': (data) => _handleUserAction(data, 'user:new'),
      'post:new': (data) => _handleNewPost(data),
      'post:reply': (data) => _handleNewReply(data),
      'post:repost': (data) => _handlePostAction(data, 'post:repost'),
      'post:like': (data) => _handlePostAction(data, 'post:like'),
      'post:unlike': (data) => _handlePostAction(data, 'post:unlike'),
      'post:view': (data) => _handlePostAction(data, 'post:view'),
      'post:bookmark': (data) => _handleBookmarkAction(data, 'post:bookmark'),
      'post:unbookmark': (data) => _handleBookmarkAction(data, 'post:unbookmark'),
      'reply:new': (data) => _handleNewReplyToReply(data),
      'reply:like': (data) => _handleReplyAction(data, 'reply:like'),
      'reply:unlike': (data) => _handleReplyAction(data, 'reply:unlike'),
      'reply:repost': (data) => _handleReplyAction(data, 'reply:repost'),
      'reply:view': (data) => _handleReplyAction(data, 'reply:view'),
      'chat:new': (data) => _handleNewChat(data),
      'chat:updated': (data) => _handleChatUpdated(data),
      'message:new': (data) => _handleNewMessage(data),
      'message:update': (data) => _handleMessageUpdate(data),
      'message:delete': (data) => _handleMessageDelete(data),
      'message:statusUpdate': (data) => _handleMessageStatusUpdate(data),
      'message:reaction': (data) => _handleNewMessage(data),
      'chat:deletedForMe': (data) => _handleChatDeleted(data, 'chat:deletedForMe'),
      'chat:hardDeleted': (data) => _handleChatDeleted(data, 'chat:hardDeleted'),
      'typing:started': (data) => _handleTyping(data, true),
      'typing:stopped': (data) => _handleTyping(data, false),
    };

    eventHandlers.forEach((event, handler) {
      _socket!.on(event, (data) {
          // print('SocketService: Received event $event with data: $data');
        handler(data);
      });
    });
  }

  // Syncs all chat rooms by joining the socket room for each chat ID.
  void syncAllChatRooms() async {
    if (_socket == null || !_socket!.connected) return;
    try {
      // print('[SocketService] Starting sync of all chat rooms...');
      List<String> chatIds = await _dataController.getActiveChatIds();
      for (String chatId in chatIds) {
        // print('[SocketService] ==> Emitting join for chatId: $chatId');
        _socket!.emit('join', {'chatId': chatId});
      }
      // print('[SocketService] Finished syncing all chat rooms.');
    } catch (e) {
        // print('[SocketService] Error during syncAllChatRooms: $e');
    }
  }

  void _handleNewPost(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.addNewPost(data);
      _eventController.add({'event': 'post:new', 'data': data});
    } else {
        // print('SocketService: Invalid post:new data format: ${data.runtimeType}');
    }
  }

  void _handleNewReply(dynamic data) {
    if (data is Map<String, dynamic> &&
        data['parentPostId'] is String &&
        data['reply'] is Map<String, dynamic>) {
      _dataController.handleNewReply(data['parentPostId'], data['reply']);
      _eventController.add({'event': 'post:reply', 'data': data});
    } else {
        // print('SocketService: Invalid post:reply data format: ${data.runtimeType}');
    }
  }

  void _handleNewReplyToReply(dynamic data) {
    if (data is Map<String, dynamic> &&
        data['postId'] is String &&
        data['parentReplyId'] is String &&
        data['reply'] is Map<String, dynamic>) {
      _dataController.handleNewReplyToReply(data['postId'], data['parentReplyId'], data['reply']);
      _eventController.add({'event': 'reply:new', 'data': data});
    } else {
        // print('SocketService: Invalid reply:new data format: ${data.runtimeType}');
    }
  }

  void _handlePostAction(dynamic data, String event) {
    if (data is Map<String, dynamic> &&
        data['postId'] is String &&
        data['userId'] is String) {
      _dataController.fetchSinglePost(data['postId']);
      _eventController.add({'event': event, 'data': data});
    } else {
        // print('SocketService: Invalid $event data format: ${data.runtimeType}');
    }
  }

  void _handleBookmarkAction(dynamic data, String event) {
    if (data is Map<String, dynamic> &&
        data['post'] is Map<String, dynamic>) {
      _dataController.updatePostFromSocket(data['post']);
      _eventController.add({'event': event, 'data': data});
    } else {
        // print('SocketService: Invalid $event data format: ${data.runtimeType}');
    }
  }

  void _handleReplyAction(dynamic data, String event) {
    if (data is Map<String, dynamic> &&
        data['postId'] is String &&
        data['replyId'] is String &&
        data['userId'] is String) {
      _dataController.fetchSinglePost(data['postId']);
      _eventController.add({'event': event, 'data': data});
    } else {
        // print('SocketService: Invalid $event data format: ${data.runtimeType}');
    }
  }

  void _handleNewChat(dynamic data) {
    // print('SocketService: Received chat:new event with data: $data');
    if (data is Map<String, dynamic> && data['_id'] is String) {
      _dataController.handleNewChat(data);
      // Join the new chat room
      _socket!.emit('join', {'chatId': data['_id']});
      _eventController.add({'event': 'chat:new', 'data': data});
    } else {
        // print('SocketService: Invalid chat:new data format: ${data.runtimeType}');
    }
  }

  void _handleChatUpdated(dynamic data) {
    if (data is Map<String, dynamic> && data['_id'] is String) {
      _dataController.handleChatUpdated(data);
      _eventController.add({'event': 'chat:updated', 'data': data});
    } else {
        // print('SocketService: Invalid chat:updated data format: ${data.runtimeType}');
    }
  }

  void _handleMessageUpdate(dynamic data) {
    if (data is Map<String, dynamic> && data['_id'] is String) {
      _dataController.handleMessageUpdate(data);
      _eventController.add({'event': 'message:update', 'data': data});
    } else {
        // print('SocketService: Invalid message:update data format: ${data.runtimeType}');
    }
  }

  void _handleNewMessage(dynamic data) {
    if (data is Map<String, dynamic> && data['chatId'] is String) {
      _dataController.handleNewMessage(data);
      // Emit message:delivered to backend
      if (data['messageId'] is String && _userId != null) {
        _socket!.emit('message:delivered', {
          'messageId': data['messageId'],
          'userId': _userId,
        });
      }
      _eventController.add({'event': 'message:new', 'data': data});
    } else {
        // print('SocketService: Invalid message event data format: ${data.runtimeType}');
    }
  }

  void _handleMessageStatusUpdate(dynamic data) {
    if (data is Map<String, dynamic> &&
        data['messageId'] is String &&
        data['userId'] is String &&
        data['status'] is String) {
      _dataController.handleMessageStatusUpdate(data);
      _eventController.add({'event': 'message:statusUpdate', 'data': data});
    } else {
        // print('SocketService: Invalid message:statusUpdate data format: ${data.runtimeType}');
    }
  }

  void _handleMessageDelete(dynamic data) {
    if (data is Map<String, dynamic> && data['messageId'] is String) {
      _dataController.handleMessageDelete(data);
      _eventController.add({'event': 'message:delete', 'data': data});
    } else {
        // print('SocketService: Invalid message:delete data format: ${data.runtimeType}');
    }
  }

  void _handleChatDeleted(dynamic data, String event) {
    if (data is Map<String, dynamic> && data['chatId'] is String) {
      _dataController.handleChatDeleted(data['chatId']);
      _eventController.add({'event': event, 'data': data});
    } else {
      // print('SocketService: Invalid $event data format: ${data.runtimeType}');
    }
  }

  void _handleTyping(dynamic data, bool isStart) {
    if (data is Map<String, dynamic> &&
        data['chatId'] is String &&
        data['userId'] is String) {
      if (isStart) {
        _dataController.handleTypingStart(data);
      } else {
        _dataController.handleTypingStop(data);
      }
      _eventController.add({'event': isStart ? 'typing:start' : 'typing:stop', 'data': data});
    } else {
        // print('SocketService: Invalid typing:${isStart ? 'start' : 'stop'} data format: ${data.runtimeType}');
    }
  }

  void _handleUserAction(dynamic data, String event) {
    if (data is Map<String, dynamic> && data['userId'] is String) {
        if (event == 'user:online') {
            _dataController.handleUserOnlineStatus(data['userId'], true);
        } else if (event == 'user:offline') {
            _dataController.handleUserOnlineStatus(data['userId'], false, lastSeen: data['lastSeen']);
        } else if (event == 'user:new' &&
            data['_id'] is String &&
            data['name'] is String &&
            data['avatar'] is String &&
            data['createdAt'] != null) {
            _dataController.handleNewUser(data);
        }
        _eventController.add({'event': event, 'data': data});
    } else {
        // print('SocketService: Invalid $event data format: ${data.runtimeType}');
    }
  }

  void connect() {
    if (_socket == null) {
      // print('SocketService: Cannot connect, socket is null. Reinitializing...');
      initSocket();
    }
    if (_socket != null && !_socket!.connected) {
      // print('SocketService: Attempting to connect to ws://192.168.1.104:3000');
      _socket!.connect();
    } else {
      // print('SocketService: Socket is already connected or null');
    }
  }

  void disconnect() {
    if (_socket != null && _socket!.connected) {
      // print('SocketService: Disconnecting socket');
      _socket!.disconnect();
    } else {
      // print('SocketService: Cannot disconnect, socket is null or not connected');
    }
  }

  void emitEvent(String event, dynamic data) {
    if (_socket != null && _socket!.connected && data != null) {
        // print('SocketService: Emitting event $event with data: $data');
      _socket!.emit(event, data);
    } else {
        // print('SocketService: Cannot emit event: Socket not connected or data is null');
    }
  }

  void sendMessage(String chatId, String message, String clientMessageId) {
    if (_userId != null) {
      emitEvent('message:new', {
        'chatId': chatId,
        'content': message,
        'userId': _userId,
        'clientMessageId': clientMessageId, // Include clientMessageId for correlation
      });
    } else {
        // print('SocketService: Cannot send message, userId is null');
    }
  }

  void sendMessageDelivered(String messageId) {
    if (_userId != null) {
      emitEvent('message:delivered', {
        'messageId': messageId,
        'userId': _userId,
      });
    } else {
        // print('SocketService: Cannot send message:delivered, userId is null');
    }
  }

  void sendMessageRead(String messageId) {
    if (_userId != null) {
      emitEvent('message:read', {
        'messageId': messageId,
        'userId': _userId,
      });
    } else {
        // print('SocketService: Cannot send message:read, userId is null');
    }
  }

  void sendTypingStart(String chatId) {
    if (_userId != null) {
      emitEvent('typing:start', {'chatId': chatId, 'userId': _userId});
    } else {
        // print('SocketService: Cannot send typing:start, userId is null');
    }
  }

  void sendTypingStop(String chatId) {
    if (_userId != null) {
      emitEvent('typing:stop', {'chatId': chatId, 'userId': _userId});
    } else {
        // print('SocketService: Cannot send typing:stop, userId is null');
    }
  }

  void joinChatRoom(String chatId) {
    emitEvent('join', {'chatId': chatId});
      // print('SocketService: Joined chat room $chatId');
  }

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void addListener(String event, void Function(dynamic) handler) {
    if (_socket != null) {
        // print('SocketService: Adding listener for event $event');
      _socket!.on(event, handler);
    } else {
        // print('SocketService: Cannot add listener, socket is null');
    }
  }
// more
  void removeListener(String event, void Function(dynamic) handler) {
    if (_socket != null) {
        // print('SocketService: Removing listener for event $event');
      _socket!.off(event, handler);
    } else {
        // print('SocketService: Cannot remove listener, socket is null');
    }
  }

  void dispose() {
    // print('SocketService: Disposing socket service');
    disconnect();
    _socket?.clearListeners();
    _socket?.dispose();
    _socket = null;
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    _isInitialized = false;
    _userId = null;
  }
}