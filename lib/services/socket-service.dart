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
      // print('New post event received: $data');
      if (data is Map<String, dynamic>) {
        // Assuming 'data' is the post object in the correct format
        _dataController.addNewPost(data);
      } else {
        // print('Received newPost event with unexpected data type: ${data.runtimeType}');
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

    _socket!.on('newReplyToReply', (data) {
      // print('[SocketService] newReplyToReply event received: $data');
      if (data is Map<String, dynamic>) {
        final String? postId = data['postId'] as String?;
        final String? parentReplyId = data['parentReplyId'] as String?;
        final Map<String, dynamic>? reply = data['reply'] as Map<String, dynamic>?;

        if (postId != null && parentReplyId != null && reply != null) {
          _dataController.handleNewReplyToReply(postId, parentReplyId, reply);
        } else {
          print('[SocketService] newReplyToReply event missing required data (postId, parentReplyId, or reply). Data: $data');
        }
      } else {
        print('[SocketService] Received newReplyToReply event with unexpected data type: ${data.runtimeType}');
      }
    });

    // Listen for postViewed event
    _socket!.on('postViewed', (data) {
      // print('postViewed event received by SocketService: $data');
      if (data is Map<String, dynamic>) {
        final String? eventPostId = data['postId'] as String?; // Correctly use 'postId'

        if (eventPostId != null) {
          print('[SocketService] postViewed event for $eventPostId. Triggering fetchSinglePost.');
          // Trigger fetching the full post to get the most up-to-date view count and other data.
          // fetchSinglePost internally uses updatePostFromSocket which now handles both '_id' and 'postId'.
          _dataController.fetchSinglePost(eventPostId);
        } else {
          print('[SocketService] Received postViewed event with missing postId field: $data');
        }
      } else {
        print('[SocketService] Received postViewed event with unexpected data type: ${data.runtimeType}');
      }
    });

    // Listen for postLiked event
    _socket!.on('postLiked', (data) {
      // print('[SocketService] postLiked event received: $data');
      if (data is Map<String, dynamic>) {
        final String? postId = data['postId'] as String? ?? data['_id'] as String?;
        if (postId != null) {
          print('[SocketService] postLiked event for $postId. Triggering fetchSinglePost.');
          _dataController.fetchSinglePost(postId);
        } else {
          print('[SocketService] Received postLiked event with missing postId or _id: $data');
        }
      } else {
        print('[SocketService] Received postLiked event with unexpected data type: ${data.runtimeType}. Expected Map<String, dynamic>.');
      }
    });

    // Listen for postUnliked event
    _socket!.on('postUnliked', (data) {
      // print('[SocketService] postUnliked event received: $data');
      if (data is Map<String, dynamic>) {
        final String? postId = data['postId'] as String? ?? data['_id'] as String?;
        if (postId != null) {
          print('[SocketService] postUnliked event for $postId. Triggering fetchSinglePost.');
          _dataController.fetchSinglePost(postId);
        } else {
          print('[SocketService] Received postUnliked event with missing postId or _id: $data');
        }
      } else {
        print('[SocketService] Received postUnliked event with unexpected data type: ${data.runtimeType}. Expected Map<String, dynamic>.');
      }
    });

    // postReposted event
    _socket!.on('postReposted', (data) {
      // print('[SocketService] postReposted event received: $data');
      if (data is Map<String, dynamic>) {
        final String? postId = data['postId'] as String? ?? data['_id'] as String?;
        if (postId != null) {
          print('[SocketService] postReposted event for $postId. Triggering fetchSinglePost.');
          _dataController.fetchSinglePost(postId);
        } else {
          print('[SocketService] Received postReposted event with missing postId or _id: $data');
        }
      } else {
        print('[SocketService] Received postReposted event with unexpected data type: ${data.runtimeType}. Expected Map<String, dynamic>.');
      }
    });

    // --- Reply Specific Event Handlers ---

    _socket!.on('newReply', (data) {
      // print('[SocketService] newReply event received: $data');
      if (data is Map<String, dynamic>) {
        // Data should contain { parentPostId: "...", parentReplyId: "..." (optional), reply: {...} }
        final String? parentPostId = data['parentPostId'] as String?;
        // final String? parentReplyId = data['parentReplyId'] as String?; // ID of the direct parent if it's a nested reply
        final Map<String, dynamic>? reply = data['reply'] as Map<String, dynamic>?;

        if (parentPostId != null && reply != null) {
          // Call the new method in DataController to handle the new reply directly
          _dataController.handleNewReply(parentPostId, reply);
        } else {
          print('[SocketService] newReply event missing parentPostId or reply data. Data: $data');
        }
      } else {
        print('[SocketService] Received newReply event with unexpected data type: ${data.runtimeType}');
      }
    });

    _socket!.on('replyLiked', (data) {
      // print('[SocketService] replyLiked event received: $data');
      if (data is Map<String, dynamic>) {
        final String? rootPostId = data['postId'] as String?; // This should be the root post ID
        if (rootPostId != null) {
          print('[SocketService] replyLiked event for a reply in root post $rootPostId. Triggering fetchSinglePost for root post.');
          _dataController.fetchSinglePost(rootPostId);
        } else {
          print('[SocketService] Received replyLiked event with missing root postId. Data: $data');
        }
      } else {
        print('[SocketService] Received replyLiked event with unexpected data type: ${data.runtimeType}');
      }
    });

    _socket!.on('replyUnliked', (data) {
      // print('[SocketService] replyUnliked event received: $data');
      if (data is Map<String, dynamic>) {
        final String? rootPostId = data['postId'] as String?; // This should be the root post ID
        if (rootPostId != null) {
          print('[SocketService] replyUnliked event for a reply in root post $rootPostId. Triggering fetchSinglePost for root post.');
          _dataController.fetchSinglePost(rootPostId);
        } else {
          print('[SocketService] Received replyUnliked event with missing root postId. Data: $data');
        }
      } else {
        print('[SocketService] Received replyUnliked event with unexpected data type: ${data.runtimeType}');
      }
    });

    _socket!.on('replyReposted', (data) {
      // print('[SocketService] replyReposted event received: $data');
      if (data is Map<String, dynamic>) {
        final String? rootPostId = data['postId'] as String?; // This should be the root post ID
        // final String? replyId = data['replyId'] as String?;
        // final int? repostsCount = data['repostsCount'] as int?;
        if (rootPostId != null) {
          print('[SocketService] replyReposted event for a reply in root post $rootPostId. Triggering fetchSinglePost for root post.');
          _dataController.fetchSinglePost(rootPostId);
        } else {
          print('[SocketService] Received replyReposted event with missing root postId. Data: $data');
        }
      } else {
        print('[SocketService] Received replyReposted event with unexpected data type: ${data.runtimeType}');
      }
    });

    _socket!.on('replyViewed', (data) {
      // print('[SocketService] replyViewed event received: $data');
      if (data is Map<String, dynamic>) {
        final String? rootPostId = data['postId'] as String?; // This should be the root post ID
        // final String? replyId = data['replyId'] as String?;
        // final int? viewsCount = data['viewsCount'] as int?;
        if (rootPostId != null) {
          print('[SocketService] replyViewed event for a reply in root post $rootPostId. Triggering fetchSinglePost for root post.');
          _dataController.fetchSinglePost(rootPostId);
        } else {
          print('[SocketService] Received replyViewed event with missing root postId. Data: $data');
        }
      } else {
        print('[SocketService] Received replyViewed event with unexpected data type: ${data.runtimeType}');
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