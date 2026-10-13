import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../models/movie.dart';
import 'mock_data_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Sunucu adresi: Emülatörde 10.0.2.2, Windows/Web/Masaüstünde localhost
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return 'http://localhost:3000';
  }

  /// Aktif kullanıcının profilini sunucuyla senkronize eder
  Future<bool> syncUserProfile() async {
    try {
      final url = Uri.parse('$baseUrl/api/users/sync');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': MockDataService.currentUserId,
          'name': MockDataService.currentUserName,
          'avatarUrl': MockDataService.currentUserAvatar,
          'bio': MockDataService.currentUserBio,
          'isMicOn': MockDataService.defaultMicOn,
        }),
      ).timeout(const Duration(seconds: 4));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Profil senkronizasyon hatası: $e');
      return false;
    }
  }

  /// Kullanıcı Arama (Klasik ID veya İsim ile gerçek kullanıcıları bulur)
  Future<List<UserProfile>> searchUsers(String query) async {
    final cleanQuery = query.trim().replaceAll('#', '');
    if (cleanQuery.isEmpty) return [];

    try {
      final url = Uri.parse('$baseUrl/api/users/search?q=$cleanQuery');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'] ?? [];
        return results.map((item) {
          return UserProfile(
            id: item['id'] ?? '',
            name: item['name'] ?? '',
            avatarUrl: item['avatarUrl'] ?? '',
            isOnline: item['isOnline'] ?? false,
            currentWatching: item['currentWatching'],
            isMicOn: item['isMicOn'] ?? true,
            isSpeaking: item['isSpeaking'] ?? false,
          );
        }).where((u) => u.id != MockDataService.currentUserId).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] Kullanıcı arama hatası: $e');
    }

    // Backend kapalıysa veya ulaşılamazsa kayıtlı yerel arkadaşlar arasından filtrele
    return MockDataService.friends.where((f) {
      final idMatch = f.id.toLowerCase().contains(cleanQuery.toLowerCase());
      final nameMatch = f.name.toLowerCase().contains(cleanQuery.toLowerCase());
      return idMatch || nameMatch;
    }).toList();
  }

  /// Arkadaş Ekle
  Future<bool> addFriend(UserProfile friend) async {
    MockDataService.addFriend(friend);
    try {
      final url = Uri.parse('$baseUrl/api/friends/add');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': MockDataService.currentUserId,
          'targetId': friend.id,
        }),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Arkadaş ekleme sunucu hatası: $e');
      return true; // Yerelde eklendi
    }
  }

  /// Arkadaş Çıkar
  Future<bool> removeFriend(String friendId) async {
    MockDataService.removeFriend(friendId);
    try {
      final url = Uri.parse('$baseUrl/api/friends/remove');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': MockDataService.currentUserId,
          'targetId': friendId,
        }),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Arkadaş çıkarma sunucu hatası: $e');
      return true;
    }
  }

  /// Oda Oluştur
  Future<String?> createRoom({required Movie movie}) async {
    try {
      final url = Uri.parse('$baseUrl/api/rooms/create');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hostUser': {
            'id': MockDataService.currentUserId,
            'name': MockDataService.currentUserName,
            'avatarUrl': MockDataService.currentUserAvatar,
            'isMicOn': MockDataService.defaultMicOn,
          },
          'movie': {
            'id': movie.id,
            'title': movie.title,
            'category': movie.category,
            'videoUrl': movie.videoUrl,
          }
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['roomId'] as String?;
      }
    } catch (e) {
      debugPrint('[ApiService] Oda oluşturma hatası: $e');
    }
    return null;
  }
}
