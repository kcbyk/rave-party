import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/movie.dart';
import '../models/user_profile.dart';
import '../models/chat_message.dart';

class MockDataService {
  static Future<void> initializeIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString('user_id');
    if (storedId == null) {
      currentUserId = (100000 + Random.secure().nextInt(900000)).toString();
      await prefs.setString('user_id', currentUserId);
    } else { currentUserId = storedId; }
    currentUserName = prefs.getString('user_name') ?? currentUserName;
    currentUserBio = prefs.getString('user_bio') ?? currentUserBio;
    currentUserAvatar = prefs.getString('user_avatar') ?? currentUserAvatar;
  }

  static Future<bool> isRegistered() async => (await SharedPreferences.getInstance()).getBool('registered') ?? false;

  static Future<void> register({required String name, String bio = ''}) async {
    currentUserName = name.trim();
    currentUserBio = bio.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', currentUserName);
    await prefs.setString('user_bio', currentUserBio);
    await prefs.setBool('registered', true);
  }

  static Future<void> persistProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', currentUserId);
    await prefs.setString('user_name', currentUserName);
    await prefs.setString('user_bio', currentUserBio);
    await prefs.setString('user_avatar', currentUserAvatar);
  }
  static bool isNetflixConnected = true;
  static String? connectedUserEmail = 'senol@netflix.com';
  static String currentUserName = 'Şenol';
  static String currentUserId = '849201';
  static String currentUserAvatar =
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80';
  static Uint8List? currentUserAvatarBytes;
  static String currentUserBio = 'Film & Dizi Tutkunu 🍿';
  static bool defaultMicOn = true;
  static bool receiveInvites = true;

  static ImageProvider get currentUserImageProvider {
    if (currentUserAvatarBytes != null) {
      return MemoryImage(currentUserAvatarBytes!);
    }
    return NetworkImage(currentUserAvatar);
  }

  static ImageProvider getAvatarProvider(String? avatarUrl, {bool isMe = false}) {
    if (isMe || avatarUrl == currentUserAvatar || avatarUrl == 'me' || avatarUrl == currentUserId) {
      return currentUserImageProvider;
    }
    if (avatarUrl != null && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      return NetworkImage(avatarUrl);
    }
    return currentUserImageProvider;
  }

  static final List<Movie> netflixMovies = [
    Movie(
      id: 'm1',
      title: 'Stranger Things 5',
      category: 'Bilim Kurgu • Gerilim • Gizem',
      duration: '55 dk / Bölüm',
      rating: 8.7,
      releaseYear: '2024',
      tags: ['Popüler', 'Doğaüstü', 'Retro', 'Grup İzleme'],
      posterUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      // Hawkins / Retro Neon Sinematik Sahne
      backdropUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1200&auto=format&fit=crop&q=80',
      description: 'Hawkins kasabasında gizemli olaylar ve baş aşağı dünya yeniden uyanıyor. Arkadaş grubu son büyük savaş için birleşiyor.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    Movie(
      id: 'm2',
      title: 'Cyberpunk: Edgerunners',
      category: 'Aksiyon • Anime • Bilim Kurgu',
      duration: '24 dk / Bölüm',
      rating: 8.3,
      releaseYear: '2023',
      tags: ['Neon', 'Night City', 'Yüksek Tempo'],
      posterUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=1200&auto=format&fit=crop&q=80',
      description: 'Geleceğin distopik metropolü Night City sokaklarında hayatta kalmaya çalışan bir sokak çocuğunun hikayesi.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    ),
    Movie(
      id: 'm3',
      title: 'Squid Game 2',
      category: 'Gerilim • Dram • Psikolojik',
      duration: '60 dk / Bölüm',
      rating: 8.0,
      releaseYear: '2024',
      tags: ['Trend #1', 'Gizem', 'Ödüllü'],
      posterUrl: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1518173946687-a4c8a383392e?w=1200&auto=format&fit=crop&q=80',
      description: '45.6 milyar wonluk ölümcül oyunlar geri dönüyor. Gi-hun sistemin merkezine inmeye kararlı.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    ),
    Movie(
      id: 'm4',
      title: 'Interstellar (Yıldızlararası)',
      category: 'Macera • Bilim Kurgu • Dram',
      duration: '2 sa 49 dk',
      rating: 8.7,
      releaseYear: '2014',
      tags: ['Kült', 'Uzay', 'Zaman'],
      posterUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=1200&auto=format&fit=crop&q=80',
      description: 'İnsanlığın geleceği tehlikedeyken solucan deliğinden geçerek yaşanabilir yeni bir gezegen arayan astronot ekibi.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
    ),
    Movie(
      id: 'm5',
      title: 'Dark',
      category: 'Gizem • Zaman Yolculuğu',
      duration: '50 dk / Bölüm',
      rating: 8.8,
      releaseYear: '2020',
      tags: ['Zihin Bükücü', 'Almanya'],
      posterUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1514565131-fce0801e5785?w=1200&auto=format&fit=crop&q=80',
      description: 'Winden kasabasında kaybolan iki çocuk, dört ailenin karmaşık geçmişini ve 33 yıllık döngüleri ortaya çıkarır.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
    ),
  ];

  static final List<Movie> youtubeVideos = [
    Movie(
      id: 'yt1',
      title: 'Grand Theft Auto VI — Official Trailer 1',
      category: 'Oyun • Fragman • Trend #1',
      duration: '1:31',
      rating: 9.9,
      releaseYear: '2025',
      tags: ['Rockstar Games', 'GTA 6', '4K 60FPS', 'YouTube'],
      posterUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=1200&auto=format&fit=crop&q=80',
      description: 'Vice City sokaklarına geri dönüyoruz. Jason ve Lucia’nın hikayesi başlıyor. 100M+ izlenme ile rekor kıran resmi fragman.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    ),
    Movie(
      id: 'yt2',
      title: 'Dua Lipa — Houdini (Official Music Video)',
      category: 'Müzik • Pop • 4K',
      duration: '3:05',
      rating: 9.4,
      releaseYear: '2024',
      tags: ['Müzik', 'Dua Lipa', 'Dans', 'YouTube'],
      posterUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=1200&auto=format&fit=crop&q=80',
      description: 'Dua Lipa’nın hit single şarkısı Houdini resmi video klibi. Dans provaları ve nefes kesen stüdyo koreografisi.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    ),
    Movie(
      id: 'yt3',
      title: 'Oppenheimer — 5 Dakikalık Özel Ön Bakış',
      category: 'Sinema • Belgesel • Fragman',
      duration: '5:02',
      rating: 9.6,
      releaseYear: '2023',
      tags: ['Christopher Nolan', 'IMAX', 'Cillian Murphy', 'YouTube'],
      posterUrl: 'https://images.unsplash.com/photo-1440404653325-ab127d49abc1?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1200&auto=format&fit=crop&q=80',
      description: 'Atom bombasının babası J. Robert Oppenheimer’ın hikayesi. Christopher Nolan’ın ödüllü başyapıtından özel sahneler.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    ),
    Movie(
      id: 'yt4',
      title: 'Tears of Steel (4K Bilim Kurgu Projesi)',
      category: 'Bilim Kurgu • Kısa Film • VFX',
      duration: '12:14',
      rating: 8.9,
      releaseYear: '2024',
      tags: ['CGI', 'Gelecek', 'Robotlar', 'YouTube'],
      posterUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=1200&auto=format&fit=crop&q=80',
      description: 'Kıyamet sonrası distopik Amsterdam sokaklarında geçen aksiyon dolu açık kaynaklı görsel efekt harikası.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
    ),
    Movie(
      id: 'yt5',
      title: 'League of Legends — 2024 Sezon Sinematiği: Still Here',
      category: 'Oyun • Animasyon • Müzik',
      duration: '4:15',
      rating: 9.8,
      releaseYear: '2024',
      tags: ['Riot Games', 'LoL', 'Sinematik', 'YouTube'],
      posterUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=1200&auto=format&fit=crop&q=80',
      description: 'Runeterra şampiyonlarının kader mücadeleleri. Yasuo, Kayle, Morgana, Tryndamere ve Aatrox ile epik sinematik.',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
    ),
  ];

  static final Movie googleWebMovie = Movie(
    id: 'google_web_1',
    title: 'Google Web & Video Oynatıcı',
    category: 'Canlı Web Tarayıcı',
    duration: 'Canlı',
    rating: 9.9,
    releaseYear: '2026',
    tags: ['Google', 'Web', 'Canlı Gezinti', 'Video'],
    posterUrl: 'https://images.unsplash.com/photo-1572945753563-8049567821c4?w=600&auto=format&fit=crop&q=80',
    backdropUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=1200&auto=format&fit=crop&q=80',
    description: 'Arkadaşınla birlikte Google Web üzerinden gezin, istediğiniz film ve videoları odada eşzamanlı izleyin.',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  );

  // Gerçek Arkadaşlar Listesi (Başlangıçta sahte botlar yok, kullanıcı ekledikçe dolar)
  static final List<UserProfile> friends = [];

  // Kullanıcının Eklediği Arkadaşlar Listesi
  static final List<UserProfile> addedFriends = [];

  static bool isFriend(String id) {
    return addedFriends.any((f) => f.id == id);
  }

  static void addFriend(UserProfile profile) {
    if (!isFriend(profile.id)) {
      addedFriends.add(profile);
    }
  }

  static void removeFriend(String id) {
    addedFriends.removeWhere((f) => f.id == id);
  }

  static List<ChatMessage> getInitialMessages() {
    return [];
  }
}
