import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/movie.dart';
import '../services/mock_data_service.dart';
import 'movie_detail_modal.dart';
import 'watch_party_room_screen.dart';

class YouTubeScreen extends StatefulWidget {
  final String initialUrl;

  const YouTubeScreen({
    super.key,
    this.initialUrl = 'https://m.youtube.com',
  });

  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen> {
  WebViewController? _controller;
  int _loadingProgress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    try {
      final controller = WebViewController();
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setBackgroundColor(Colors.black);
      controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _hasError = false;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted && (error.isForMainFrame ?? true)) {
              setState(() {
                _hasError = true;
              });
            }
          },
        ),
      );
      // Giriş yapmadan doğrudan YouTube mobil sitesine gider
      controller.loadRequest(Uri.parse(widget.initialUrl));

      setState(() {
        _controller = controller;
      });
    } catch (_) {
      setState(() {
        _hasError = true;
      });
    }
  }

  void _openMovieDetail(Movie video) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.88,
        child: MovieDetailModal(movie: video),
      ),
    );
  }

  void _directStartParty(Movie video) async {
    try {
      await _controller?.runJavaScript('''
        (function() {
          var videos = document.querySelectorAll('video');
          videos.forEach(function(v) {
            v.pause();
            v.muted = true;
          });
        })();
      ''');
    } catch (_) {}

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchPartyRoomScreen(
          movie: video,
          invitedFriends: const [],
        ),
      ),
    );
  }

  Future<void> _transferCurrentVideoToRoom() async {
    String currentUrl = '';
    String title = 'YouTube Videosu';
    try {
      currentUrl = await _controller?.currentUrl() ?? '';
      title = await _controller?.getTitle() ?? 'YouTube Videosu';
    } catch (_) {}

    title = title.replaceAll('- YouTube', '').trim();
    if (title.isEmpty) title = 'YouTube Videosu';

    String? videoId;
    if (currentUrl.isNotEmpty) {
      final regExp = RegExp(
        r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|v\/|shorts\/)|youtu\.be\/)([\w-]{11})',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(currentUrl);
      if (match != null && match.groupCount >= 1) {
        videoId = match.group(1);
      }
    }

    final Movie videoToPlay;
    if (videoId != null && videoId.isNotEmpty) {
      final thumb = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      videoToPlay = Movie(
        id: 'yt_$videoId',
        title: title,
        category: 'YouTube',
        duration: 'YouTube',
        rating: 4.9,
        posterUrl: thumb,
        backdropUrl: thumb,
        description: 'YouTube üzerinden odaya aktarılan video',
        videoUrl: 'https://www.youtube.com/watch?v=$videoId',
        releaseYear: '2026',
        tags: ['YouTube', 'Canlı', 'Oda'],
      );
    } else {
      videoToPlay = MockDataService.youtubeVideos.first;
    }

    // Arka plandaki YouTube sesinin odaya geçtikten sonra çalmasını engelle
    try {
      await _controller?.runJavaScript('''
        (function() {
          var videos = document.querySelectorAll('video');
          videos.forEach(function(v) {
            v.pause();
            v.muted = true;
          });
        })();
      ''');
    } catch (_) {}

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchPartyRoomScreen(
          movie: videoToPlay,
          invitedFriends: const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Ana Gövde (Mobil Cihazda Gerçek WebView, Web/Masaüstü'nde Netflix tarzı YouTube kataloğu)
            Positioned.fill(
              child: (_controller != null && !_hasError)
                  ? WebViewWidget(controller: _controller!)
                  : _buildYouTubeAppUi(),
            ),

            // Sayfa Yüklenirken En Üstte İnce Kırmızı Yükleme Barı
            if (_loadingProgress < 100 && !_hasError)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  color: const Color(0xFFFF0000),
                  backgroundColor: Colors.transparent,
                  minHeight: 2.5,
                ),
              ),

            // Sol Üst Şeffaf Geri Butonu (Netflix ile birebir aynı)
            Positioned(
              top: 12,
              left: 12,
              child: GestureDetector(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  if (_controller != null && await _controller!.canGoBack()) {
                    _controller!.goBack();
                  } else {
                    navigator.pop();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.chevron_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

            // Web Görünümünde Altta Odaya Aktar Butonu
            if (_controller != null && !_hasError)
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: ElevatedButton.icon(
                  onPressed: _transferCurrentVideoToRoom,
                  icon: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 18),
                  label: const Text(
                    'Videoyu Odaya Aktar & İzle',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 6,
                    shadowColor: const Color(0xFFFF0000).withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Netflix Arayüzü Deneyimi ile YouTube Kataloğu
  Widget _buildYouTubeAppUi() {
    final featuredVideo = MockDataService.youtubeVideos.first;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // YouTube Üst Bar (Logo + Başlık)
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 14, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  'YouTube',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // Öne Çıkan Hero Video Afişi (Netflix'teki gibi Büyük Oynat & Bilgi Butonları)
          GestureDetector(
            onTap: () => _openMovieDetail(featuredVideo),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 260,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    image: DecorationImage(
                      image: NetworkImage(featuredVideo.backdropUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  height: 260,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ÖNE ÇIKAN VİDEO',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        featuredVideo.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _directStartParty(featuredVideo),
                            icon: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.black, size: 18),
                            label: const Text(
                              'Oynat',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _openMovieDetail(featuredVideo),
                            icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                            label: const Text(
                              'Bilgi',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Kategori 1: "YouTube Trendleri"
          _buildVideoRow(
            title: '🔥 YouTube Trendleri',
            videos: MockDataService.youtubeVideos,
          ),

          const SizedBox(height: 20),

          // Kategori 2: "Müzik & Fragmanlar"
          _buildVideoRow(
            title: '🎵 Popüler & Fragmanlar',
            videos: MockDataService.youtubeVideos.reversed.toList(),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVideoRow({required String title, required List<Movie> videos}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final video = videos[index];
              return GestureDetector(
                onTap: () => _openMovieDetail(video),
                child: SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video Kapağı
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                video.backdropUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFF202026),
                                  child: const Icon(CupertinoIcons.play_rectangle, size: 36, color: Colors.white30),
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                            ),
                            // Ortada Oynat Rozeti
                            Center(
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                                ),
                                child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 16),
                              ),
                            ),
                            // Sağ Alt Süre
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  video.duration,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Başlık
                      Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        video.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
