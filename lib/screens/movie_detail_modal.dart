import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../theme/app_theme.dart';
import 'watch_party_room_screen.dart';

class MovieDetailModal extends StatelessWidget {
  final Movie movie;

  const MovieDetailModal({
    super.key,
    required this.movie,
  });

  void _startPartyImmediately(BuildContext context) {
    Navigator.pop(context); // Modalı kapat
    // DİREKT DİKEY RAVE PARTİ ODASI KUR!
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchPartyRoomScreen(
          movie: movie,
          invitedFriends: const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Backdrop with gradient
                Stack(
                  children: [
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        image: DecorationImage(
                          image: NetworkImage(movie.backdropUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF161616).withValues(alpha: 0.6),
                            const Color(0xFF161616),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık
                      Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Meta Bilgileri
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final isYouTube = movie.id.startsWith('yt') || movie.tags.contains('YouTube');
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isYouTube ? const Color(0xFFFF0000) : AppTheme.netflixRed,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isYouTube ? 'YOUTUBE' : 'NETFLIX',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(movie.releaseYear, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          const SizedBox(width: 8),
                          Text(movie.duration, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('18+', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ),
                          const Spacer(),
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 3),
                          Text(
                            '${movie.rating}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // BÜYÜK "▶ OYNAT & ODAYA BAŞLAT" BUTONU
                      Builder(
                        builder: (context) {
                          final isYouTube = movie.id.startsWith('yt') || movie.tags.contains('YouTube');
                          return SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => _startPartyImmediately(context),
                              icon: Icon(
                                CupertinoIcons.play_arrow_solid,
                                color: isYouTube ? Colors.white : Colors.black,
                                size: 22,
                              ),
                              label: Text(
                                isYouTube ? 'Oynat & Odaya Başlat' : 'Oynat & Parti Kur',
                                style: TextStyle(
                                  color: isYouTube ? Colors.white : Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isYouTube ? const Color(0xFFFF0000) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 4,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Açıklama
                      Text(
                        movie.description,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Türler
                      Wrap(
                        spacing: 8,
                        children: movie.tags.map((tag) {
                          return Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                            backgroundColor: AppTheme.cardDark,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            padding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Odadaki Arkadaşlar Önizleme
                      const Row(
                        children: [
                          Icon(CupertinoIcons.person_2_fill, color: AppTheme.ravePurple, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Arkadaşların Hazır • Sesli Sohbet Aktif Olacak',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
