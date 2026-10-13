import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/chat_message.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _currentRoomId;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;

  // Callback'ler
  void Function(List<UserProfile> participants)? onParticipantsUpdated;
  void Function(String action, double time, bool isPlaying, String senderId)? onVideoSync;
  void Function(ChatMessage message)? onChatMessage;
  void Function(String emoji, String senderId)? onReactionReceived;
  void Function(String userId, bool? isMicOn, bool? isSpeaking)? onMicStatusChanged;
  void Function(String action, dynamic payload, String senderId)? onWebSync;

  static String get serverUrl {
    if (kIsWeb) return 'http://localhost:3000';
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return 'http://localhost:3000';
  }

  /// Socket.IO sunucusuna bağlanır
  void initSocket() {
    if (_socket != null && _socket!.connected) return;

    try {
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('[SocketService] Sunucuya bağlandı: ${_socket!.id}');
        if (_currentRoomId != null) {
          _emitJoin();
        }
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('[SocketService] Bağlantı kesildi.');
      });

      _socket!.onConnectError((err) {
        _isConnected = false;
        debugPrint('[SocketService] Bağlantı hatası: $err');
      });

      // Oda Durumu (Yeni katıldığında)
      _socket!.on('room_state', (data) {
        debugPrint('[SocketService] room_state alındı: $data');
        if (data is Map && data['participants'] is List) {
          _handleParticipantsList(data['participants'] as List);
        }
        if (data is Map && data['playback'] is Map) {
          final pb = data['playback'];
          final isPlaying = pb['isPlaying'] == true;
          final time = (pb['currentSeconds'] as num?)?.toDouble() ?? 0.0;
          onVideoSync?.call(isPlaying ? 'play' : 'pause', time, isPlaying, 'server');
        }
      });

      // Yeni Kullanıcı Katıldı
      _socket!.on('room_user_joined', (data) {
        debugPrint('[SocketService] room_user_joined: $data');
        if (data is Map && data['participants'] is List) {
          _handleParticipantsList(data['participants'] as List);
        }
      });

      // Kullanıcı Ayrıldı
      _socket!.on('room_user_left', (data) {
        debugPrint('[SocketService] room_user_left: $data');
        if (data is Map && data['participants'] is List) {
          _handleParticipantsList(data['participants'] as List);
        }
      });

      // Video Senkronizasyonu
      _socket!.on('video_sync', (data) {
        if (data is Map) {
          final action = data['action']?.toString() ?? 'play';
          final time = (data['time'] as num?)?.toDouble() ?? 0.0;
          final isPlaying = data['isPlaying'] == true;
          final senderId = data['senderId']?.toString() ?? '';
          onVideoSync?.call(action, time, isPlaying, senderId);
        }
      });

      // Canlı Sohbet Mesajı
      _socket!.on('chat_message', (data) {
        if (data is Map) {
          final msg = ChatMessage(
            id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: data['senderId']?.toString() ?? data['userId']?.toString() ?? '',
            senderName: data['senderName']?.toString() ?? data['userName']?.toString() ?? 'Kullanıcı',
            senderAvatar: data['senderAvatar']?.toString() ?? data['userAvatar']?.toString() ?? '',
            content: data['content']?.toString() ?? data['text']?.toString() ?? '',
            timestamp: data['timestamp'] != null
                ? DateTime.tryParse(data['timestamp'].toString()) ?? DateTime.now()
                : DateTime.now(),
            isCurrentUser: (data['senderId'] ?? data['userId']) == MockDataService.currentUserId,
          );
          onChatMessage?.call(msg);
        }
      });

      // Ekranda Uçuşan Reaksiyon
      _socket!.on('reaction_received', (data) {
        if (data is Map) {
          final emoji = data['emoji']?.toString() ?? '❤️';
          final senderId = data['senderId']?.toString() ?? '';
          onReactionReceived?.call(emoji, senderId);
        }
      });

      // Mikrofon Durumu Değişikliği
      _socket!.on('mic_status_changed', (data) {
        if (data is Map) {
          final userId = data['userId']?.toString() ?? '';
          final isMicOn = data['isMicOn'] as bool?;
          final isSpeaking = data['isSpeaking'] as bool?;
          onMicStatusChanged?.call(userId, isMicOn, isSpeaking);
        }
      });

      // Web Senkronizasyonu
      _socket!.on('web_sync', (data) {
        if (data is Map) {
          final action = data['action']?.toString() ?? '';
          final payload = data['payload'];
          final senderId = data['senderId']?.toString() ?? '';
          onWebSync?.call(action, payload, senderId);
        }
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('[SocketService] Init error: $e');
    }
  }

  void _handleParticipantsList(List rawList) {
    final list = rawList.map((item) {
      if (item is! Map) return null;
      return UserProfile(
        id: item['id']?.toString() ?? '',
        name: item['name']?.toString() ?? '',
        avatarUrl: item['avatarUrl']?.toString() ?? '',
        isOnline: item['isOnline'] == true,
        currentWatching: item['currentWatching']?.toString(),
        isMicOn: item['isMicOn'] != false,
        isSpeaking: item['isSpeaking'] == true,
      );
    }).whereType<UserProfile>().toList();

    onParticipantsUpdated?.call(list);
  }

  void _emitJoin() {
    if (_socket == null || _currentRoomId == null) return;
    _socket!.emit('join_room', {
      'roomId': _currentRoomId,
      'user': {
        'id': MockDataService.currentUserId,
        'name': MockDataService.currentUserName,
        'avatarUrl': MockDataService.currentUserAvatar,
        'isMicOn': MockDataService.defaultMicOn,
        'isSpeaking': false,
      }
    });
  }

  /// Odaya Katıl
  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    initSocket();
    if (_socket != null && _socket!.connected) {
      _emitJoin();
    }
  }

  /// Odadan Ayrıl
  void leaveRoom() {
    if (_socket != null && _currentRoomId != null) {
      _socket!.emit('leave_room', {
        'roomId': _currentRoomId,
        'userId': MockDataService.currentUserId,
      });
    }
    _currentRoomId = null;
  }

  /// Video Senkron Sinyali Gönder (Play, Pause, Seek)
  void sendVideoSync({required String action, required double time}) {
    if (_socket == null || _currentRoomId == null) return;
    _socket!.emit('video_sync', {
      'roomId': _currentRoomId,
      'action': action,
      'time': time,
      'senderId': MockDataService.currentUserId,
    });
  }

  /// Sohbet Mesajı Gönder
  void sendChatMessage(ChatMessage message) {
    if (_socket == null || _currentRoomId == null) return;
    _socket!.emit('chat_message', {
      'roomId': _currentRoomId,
      'message': {
        'id': message.id,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'senderAvatar': message.senderAvatar,
        'content': message.content,
        'timestamp': message.timestamp.toIso8601String(),
      }
    });
  }

  /// Ekranda Uçuşan Reaksiyon Gönder
  void sendReaction(String emoji) {
    if (_socket == null || _currentRoomId == null) return;
    _socket!.emit('send_reaction', {
      'roomId': _currentRoomId,
      'emoji': emoji,
      'senderId': MockDataService.currentUserId,
    });
  }

  /// Mikrofon Durumu Değişikliği Bildir
  void sendMicStatus({required bool isMicOn, bool isSpeaking = false}) {
    if (_socket == null || _currentRoomId == null) return;
    _socket!.emit('mic_status', {
      'roomId': _currentRoomId,
      'userId': MockDataService.currentUserId,
      'isMicOn': isMicOn,
      'isSpeaking': isSpeaking,
    });
  }

  /// Web Senkronizasyon Bildir (Tab, Scroll, Arama)
  void sendWebSync({required String action, dynamic payload}) {
    if (_socket == null || _currentRoomId == null) return;
    _socket!.emit('web_sync', {
      'roomId': _currentRoomId,
      'action': action,
      'payload': payload,
      'senderId': MockDataService.currentUserId,
    });
  }

  /// Temizle
  void dispose() {
    leaveRoom();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
