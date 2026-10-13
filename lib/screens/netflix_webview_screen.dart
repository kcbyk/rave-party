import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/movie.dart';
import '../services/mock_data_service.dart';
import '../theme/app_theme.dart';
import 'movie_detail_modal.dart';
import 'watch_party_room_screen.dart';

class NetflixWebViewScreen extends StatefulWidget {
  final String initialUrl;

  const NetflixWebViewScreen({
    super.key,
    this.initialUrl = 'https://www.netflix.com/browse',
  });

  @override
  State<NetflixWebViewScreen> createState() => _NetflixWebViewScreenState();
}

class _NetflixWebViewScreenState extends State<NetflixWebViewScreen> {
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

      // Desktop Chrome User-Agent vererek Netflix'in "Uygulamayı Aç / Hesabı Yönet"
      // mobil engelleyici ekranını göstermesini engelliyoruz.
      controller.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      );

      controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // Native uygulama açma girişimlerini engelle (webde kalsın)
            if (url.startsWith('netflix:') || url.startsWith('intent:') || url.startsWith('market:')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
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
            // Eğer giriş sonrası doğrudan mobil 'your-account' ekranına yönlenirse browse sayfasına al
            if (url.contains('/youraccount') || url.contains('/your-account') || url.contains('/app')) {
              controller.loadRequest(Uri.parse('https://www.netflix.com/browse'));
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
            // Sayfa açıldığında mobil uygulama engelleyici mesaj varsa otomatik olarak browse'a geç
            controller.runJavaScript('''
              (function() {
                var body = document.body ? document.body.innerText : '';
                if (body.indexOf('Netflix uygulamasıyla daha güzel') !== -1 ||
                    body.indexOf('Uygulamayı aç') !== -1 ||
                    body.indexOf('Hesabı yönet') !== -1) {
                  window.location.href = 'https://www.netflix.com/browse';
                }
                var banners = document.querySelectorAll('.app-redirect, [data-uia="app-banner"], .mobile-app-banner');
                banners.forEach(function(el) { el.remove(); });
              })();
            ''');
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
      controller.loadRequest(Uri.parse(widget.initialUrl));

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  void _openMovieDetail(Movie movie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.88,
        child: MovieDetailModal(movie: movie),
      ),
    );
  }

  void _directStartParty(Movie movie) {
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

  Future<void> _transferCurrentContentToRoom() async {
    String currentUrl = '';
    String title = 'Netflix';
    try {
      currentUrl = await _controller?.currentUrl() ?? '';
      title = await _controller?.getTitle() ?? 'Netflix';
    } catch (_) {}

    title = title.replaceAll('- Netflix', '').replaceAll('| Netflix', '').trim();
    if (title.isEmpty || title == 'Netflix') title = 'Netflix İçeriği';

    // Netflix'te bir içerik izleniyorsa o URL'i, izlenmiyorsa browse sayfasını al
    // Rave gibi: oda ekranı aynı URL'i kendi WebView'ında açacak
    final String videoUrl;
    if (currentUrl.contains('netflix.com/watch/') || currentUrl.contains('netflix.com/title/')) {
      videoUrl = currentUrl;
    } else {
      // İzlenecek içerik seçilmemişse browse'a gönder, kullanıcı seçsin
      videoUrl = 'https://www.netflix.com/browse';
      title = 'Netflix';
    }

    final contentToPlay = Movie(
      id: 'netflix_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: 'Netflix',
      duration: 'Netflix Yayını',
      rating: 4.8,
      posterUrl: 'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=600&auto=format&fit=crop&q=80',
      backdropUrl: 'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=1200&auto=format&fit=crop&q=80',
      description: 'Netflix üzerinden odaya aktarılan içerik',
      videoUrl: videoUrl,
      releaseYear: '2026',
      tags: ['Netflix', 'Canlı', 'Oda'],
    );

    // Netflix videosunu duraklat
    try {
      await _controller?.runJavaScript('''
        (function() {
          var v = document.querySelectorAll('video');
          v.forEach(function(video) { video.pause(); });
        })();
      ''');
    } catch (_) {}

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchPartyRoomScreen(
          movie: contentToPlay,
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
            // Ana Gövde (Mobil Cihazda Gerçek WebView, Web'de Netflix Arayüzü)
            Positioned.fill(
              child: (_controller != null && !_hasError)
                  ? WebViewWidget(controller: _controller!)
                  : _buildNetflixAppUi(),
            ),

            // Sayfa Yüklenirken En Üstte İnce Kırmızı Yükleme Barı
            if (_loadingProgress < 100 && !_hasError)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  color: AppTheme.netflixRed,
                  backgroundColor: Colors.transparent,
                  minHeight: 2.5,
                ),
              ),

            // Sol Üst Şeffaf Geri Butonu
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
                    size: 26,
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
                  onPressed: _transferCurrentContentToRoom,
                  icon: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white, size: 18),
                  label: const Text(
                    'İçeriği Odaya Aktar & Birlikte İzle',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.netflixRed,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 6,
                    shadowColor: AppTheme.netflixRed.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Birebir Netflix Mobil Uygulama Deneyimi
  Widget _buildNetflixAppUi() {
    final featuredMovie = MockDataService.netflixMovies.first;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Netflix Üst Başlık Barı (Logo + Diziler / Filmler / Kategoriler)
          Padding(
            padding: const EdgeInsets.fromLTRB(54, 14, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.netflixRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'N',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text('Diziler', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(width: 18),
                    Text('Filmler', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(width: 18),
                    Text('Kategoriler', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),

          // Öne Çıkan Hero Afiş (Netflix Featured Banner)
          GestureDetector(
            onTap: () => _openMovieDetail(featuredMovie),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 380,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    image: DecorationImage(
                      image: NetworkImage(featuredMovie.posterUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Gradient Karartma
                Container(
                  height: 380,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                ),
                // Hero Banner Butonları
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.netflixRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TOP 10',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Türkiye'de Bugün 1 Numara",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // BÜYÜK BEYAZ OYNAT BUTONU (DOĞRUDAN PARTİ KURAR)
                          ElevatedButton.icon(
                            onPressed: () => _directStartParty(featuredMovie),
                            icon: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.black, size: 20),
                            label: const Text(
                              'Oynat',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // LİSTEM BUTONU
                          OutlinedButton.icon(
                            onPressed: () => _openMovieDetail(featuredMovie),
                            icon: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                            label: const Text(
                              'Bilgi',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

          // Kategori 1: "Netflix'te Popüler"
          _buildMovieRow(
            title: "Netflix'te Popüler",
            movies: MockDataService.netflixMovies,
          ),

          const SizedBox(height: 20),

          // Kategori 2: "Gündemdekiler"
          _buildMovieRow(
            title: "Gündemdekiler",
            movies: MockDataService.netflixMovies.reversed.toList(),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMovieRow({required String title, required List<Movie> movies}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return GestureDetector(
                onTap: () => _openMovieDetail(movie),
                child: Container(
                  width: 118,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(movie.posterUrl),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
