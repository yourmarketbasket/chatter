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
  final Set<String> _joinedChatRooms = {};

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
      _socket = IO.io('https://chatter-api-little-field-3471.fly.dev', <String, dynamic>{
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
      // print('SocketService: Initialization complete.');
      connect();
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

    // The new architecture moves event handling to the widgets themselves.
    // This service is now only responsible for connection and broadcasting raw events.
    // A list of all possible events the app might listen to.
    const allEvents = [
      'user:online', 'user:offline', 'user:new', 'post:new', 'post:reply',
      'post:repost', 'post:like', 'post:unlike', 'post:view', 'post:bookmark',
      'post:unbookmark', 'reply:new', 'reply:like', 'reply:unlike', 'reply:repost',
      'reply:view', 'chat:new', 'chat:updated', 'message:new', 'message:update',
      'message:delete', 'messages:deleted', 'message:statusUpdate', 'message:reaction',
      'message:reaction:removed', 'chats:deletedForMe', 'chat:hardDeleted',
      'typing:started', 'typing:stopped', 'user:verified', 'group:updated',
      'group:removedFrom', 'member:joined', 'member:removed', 'member:promoted',
      'member:demoted', 'member:muted', 'member:unmuted', 'group:closed',
      'user:unsuspended', 'post:unflagged', 'post:flagged'
    ];

    // Listen to all events and push them into the broadcast stream.
    for (final event in allEvents) {
      _socket!.on(event, (data) {
        // print('SocketService: Received event $event with data: $data');
        _eventController.add({'event': event, 'data': data});
      });
    }
  }
  // more changes

  // Syncs all chat rooms by joining the socket room for each chat ID.
  void syncAllChatRooms() async {
    if (_socket == null || !_socket!.connected) return;
    try {
      List<String> chatIds = await _dataController.getActiveChatIds();
      for (String chatId in chatIds) {
        joinChatRoom(chatId);
      }
    } catch (e) {
        // print('[SocketService] Error during syncAllChatRooms: $e');
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
    if (_socket != null && _socket!.connected) {
      if (_joinedChatRooms.contains(chatId)) {
        // Already in the room, no need to join again.
        return;
      }
      _socket!.emit('join', {'chatId': chatId});
      _joinedChatRooms.add(chatId);
    } else {
      // print('[SocketService] Cannot join room. Socket is null or not connected.');
    }
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