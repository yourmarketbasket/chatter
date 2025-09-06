import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'package:chatter/controllers/data-controller.dart';
import 'package:get/get.dart';

class SocketService {
  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final DataController _dataController = Get.find<DataController>();
  bool _isInitialized = false;
  String? _userId;

  SocketService();

  void initSocket() {
    if (_isInitialized) {
      return;
    }

    try {
      _socket = IO.io('https://chatter-api-little-field-3471.fly.dev', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 10,
        'reconnectionDelay': 3000,
        'forceNew': true,
        'auth': {
          'token': _dataController.getAuthToken(),
        },
      });

      _setupSocketListeners();
      _isInitialized = true;
      connect();
    } catch (e) {
      // Error handling for socket initialization can be added here.
    }
  }

  void _setupSocketListeners() {
    if (_socket == null) {
      return;
    }

    _socket!.onConnect((_) {
      _userId = _dataController.getUserId();
      _eventController.add({'event': 'connect', 'data': null});
    });

    _socket!.onDisconnect((_) {
      _eventController.add({'event': 'disconnect', 'data': null});
    });

    _socket!.onConnectError((error) {
      _eventController.add({'event': 'connect_error', 'data': error.toString()});
    });

    _socket!.onError((error) {
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
      'messages:deleted': (data) => _handleMessagesDeleted(data),
      'message:statusUpdate': (data) => _handleMessageStatusUpdate(data),
      'message:reaction': (data) => _handleMessageReaction(data),
      'message:reaction:removed': (data) => _handleMessageReactionRemoved(data),
      'chats:deletedForMe': (data) => _handleChatsDeletedForMe(data),
      'typing:started': (data) => _handleTyping(data, true),
      'typing:stopped': (data) => _handleTyping(data, false),
      'user:verified': (data) => _handleUserVerified(data),
      'chat:avatar_updated': (data) => _handleChatAvatarUpdated(data),
      'group:removedFrom': (data) => _handleGroupRemovedFrom(data),
      'member:joined': (data) => _handleMemberJoined(data),
      'member:added': (data) => _handleMemberJoined(data),
      'member:removed': (data) => _handleMemberRemoved(data),
      'member:promoted': (data) => _handleMemberPromoted(data),
      'member:demoted': (data) => _handleMemberDemoted(data),
      'member:muted': (data) => _handleMemberMuted(data),
      'member:unmuted': (data) => _handleMemberUnmuted(data),
      'chat:closed': (data) => _handleChatClosed(data),
      'user:unsuspended': (data) => _handleUserUnsuspended(data),
      'post:unflagged': (data) => _handlePostUnflagged(data),
      'post:flagged': (data) => _handlePostFlagged(data),
      'app:update_nudge': (data) => _handleAppUpdateNudge(data),
    };

    eventHandlers.forEach((event, handler) {
      _socket!.on(event, handler);
    });
  }

  void _handleChatAvatarUpdated(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleChatAvatarUpdated(data);
      _eventController.add({'event': 'chat:avatar_updated', 'data': data});
    }
  }

  void _handleGroupRemovedFrom(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleGroupRemovedFrom(data);
      _eventController.add({'event': 'group:removedFrom', 'data': data});
    }
  }

  void _handleMemberJoined(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMemberJoined(data);
      _eventController.add({'event': 'member:joined', 'data': data});
    }
  }

  void _handleMemberRemoved(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMemberRemoved(data);
      _eventController.add({'event': 'member:removed', 'data': data});
    }
  }

  void _handleMemberPromoted(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMemberPromoted(data);
      _eventController.add({'event': 'member:promoted', 'data': data});
    }
  }

  void _handleMemberDemoted(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMemberDemoted(data);
      _eventController.add({'event': 'member:demoted', 'data': data});
    }
  }
// yolo
  void _handleMemberMuted(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMemberMuted(data);
      _eventController.add({'event': 'member:muted', 'data': data});
    }
  }

  void _handleMemberUnmuted(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMemberUnmuted(data);
      _eventController.add({'event': 'member:unmuted', 'data': data});
    }
  }

  void _handleChatClosed(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleChatClosed(data);
      _eventController.add({'event': 'chat:closed', 'data': data});
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
    if (data is Map<String, dynamic> && data['_id'] is String) {
      _dataController.handleNewChat(data);
      _eventController.add({'event': 'chat:new', 'data': data});
    }
  }

  void _handleChatUpdated(dynamic data) {
    // print('[SocketService] Received chat:updated with data: $data');
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

  void _handleMessageReaction(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMessageReaction(data);
      _eventController.add({'event': 'message:reaction', 'data': data});
    }
  }

  void _handleMessageReactionRemoved(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMessageReactionRemoved(data);
      _eventController.add({'event': 'message:reaction:removed', 'data': data});
    }
  }
  // End of message events

  void _handleMessageDelete(dynamic data) {
    // The payload contains the ID of the deleted message.
    if (data is Map<String, dynamic> && data['messageId'] is String) {
      // The DataController needs the chatId to find the right conversation.
      // We assume the backend includes it in the payload.
      if (data['chatId'] != null) {
         _dataController.handleMessageDelete(data);
        _eventController.add({'event': 'message:delete', 'data': data});
      }
    } else {
        // print('SocketService: Invalid message:delete data format: ${data.runtimeType}');
    }
  }

  void _handleMessagesDeleted(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleMessagesDeleted(data);
      _eventController.add({'event': 'messages:deleted', 'data': data});
    } else {
      // print('SocketService: Invalid messages:deleted data format: ${data.runtimeType}');
    }
  }

  void _handleChatsDeletedForMe(dynamic data) {
    if (data is List) {
      final chatIds = List<String>.from(data.map((item) => item.toString()));
      _dataController.handleChatsDeletedForMe(chatIds);
      _eventController.add({'event': 'chats:deletedForMe', 'data': chatIds});
    } else {
        // print('SocketService: Invalid chats:deletedForMe data format: ${data.runtimeType}');
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

  void _handleUserVerified(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleUserVerified(data);
    }
  }

  void _handleUserUnsuspended(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleUserUnsuspended(data);
    }
  }

  void _handlePostUnflagged(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handlePostUnflagged(data);
    }
  }

  void _handlePostFlagged(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handlePostFlagged(data);
    }
  }

  void _handleAppUpdateNudge(dynamic data) {
    if (data is Map<String, dynamic>) {
      _dataController.handleAppUpdateNudge(data);
      _eventController.add({'event': 'app:update_nudge', 'data': data});
    } else {
      // print('SocketService: Invalid app:update_nudge data format: ${data.runtimeType}');
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
    _userId = null;
  }
}