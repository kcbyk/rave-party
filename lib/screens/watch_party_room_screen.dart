import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/chat_message.dart';
import '../models/movie.dart';
import '../models/user_profile.dart';
import '../services/mock_data_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reaction_overlay.dart';
import 'add_friend_screen.dart';

class WatchPartyRoomScreen extends StatefulWidget {
  final Movie movie;
  final List<UserProfile> invitedFriends;
  final String? roomId;

  const WatchPartyRoomScreen({
    super.key,
    required this.movie,
    required this.invitedFriends,
    this.roomId,
  });

  @override
  State<WatchPartyRoomScreen> createState() => _WatchPartyRoomScreenState();
}

class _WatchPartyRoomScreenState extends State<WatchPartyRoomScreen>
    with TickerProviderStateMixin {
  String? _roomId;
  VoiceService? _voice;
  VideoPlayerController? _videoController;
  WebViewController? _webPlayerController;
  bool _isWebVideo = false;
  bool _isVideoInitialized = false;
  bool _isPlaying = true;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  String _activeSubtitle = 'TR'; // 'KAPALI', 'TR', 'EN'
  String _activeVideoQuality = 'Otomatik (1080p)';
  bool _isLandscape = false;

  // Google Web Modu & Web Tarayıcı Durumları
  bool _isGoogleWebMode = false;
  WebViewController? _googleWebController;

  // Sohbet Aç/Kapat & 10 Saniyelik Otomatik Gizleme
  bool _isChatVisible = true;
  bool _showChatOverlayControl = true;
  Timer? _chatOverlayHideTimer;

  // Eşzamanlı Web Gezintisi Senkronizasyonu (Scroll, Arama, Sekme)
  final ScrollController _googleScrollController = ScrollController();
  String _activeWebTab = 'Tümü';

  void _toggleOrientation() {
    HapticFeedback.lightImpact();
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // Video Playback Duration Simulation
  double _currentSeconds = 870.0; // 14:30
  final double _totalSeconds = 3300.0; // 55:00
  Timer? _playbackTimer;
  bool _showControls = true;
  Timer? _controlsHideTimer;

  // Voice Chat States
  bool _isMyMicOn = true;
  late List<UserProfile> _allParticipants;

  // Live Chat States
  late List<ChatMessage> _messages;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Floating Reactions State
  final List<FloatingReactionModel> _activeReactions = [];
  final Random _random = Random();

  // Current User Profile
  late UserProfile _currentUser;
  final Set<String> _pendingInviteIds = {};

  @override
  void initState() {
    super.initState();
    _inputFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _currentUser = UserProfile(
      id: MockDataService.currentUserId,
      name: MockDataService.currentUserName,
      avatarUrl: MockDataService.currentUserAvatar,
      isMicOn: MockDataService.defaultMicOn,
      isSpeaking: false,
    );

    final initialFriends = widget.invitedFriends;
    _allParticipants = [_currentUser, ...initialFriends];

    if (widget.movie.id.startsWith('google') || widget.movie.tags.contains('Google')) {
      _isGoogleWebMode = true;
      _initGoogleWebView();
      _messages = [];
    } else {
      _messages = MockDataService.getInitialMessages();
    }

    _initVideoPlayer();
    _startPlaybackTimer();
    _startControlsTimer();
    _initSocketSync();
    _resetChatOverlayTimer();
    _googleScrollController.addListener(_onGoogleScroll);
  }

  Future<void> _initSocketSync() async {
    _roomId = widget.roomId ?? await ApiService().createRoom(movie: widget.movie);
    if (!mounted || _roomId == null) return;
    final roomId = _roomId!;
    final socket = SocketService();
    socket.joinRoom(roomId);
    _voice = VoiceService(socket);
    _voice!.start(const []).catchError((_) {});
    socket.onWebRtcSignal = (fromUserId, signal) => _voice?.handleSignal(fromUserId, signal);

    // Gerçek Zamanlı Katılımcı Listesi Güncelleme
    socket.onParticipantsUpdated = (participants) {
      if (!mounted) return;
      setState(() {
        final otherParticipants = participants.where((p) => p.id != _currentUser.id).toList();
        _allParticipants = [_currentUser, ...otherParticipants];
      });
      // Deterministic initiator prevents two peers from creating competing offers.
      _voice?.start(participants.where((p) => p.id.compareTo(_currentUser.id) > 0).map((p) => p.id)).catchError((_) {});
    };

    // Video Senkronizasyonu (Oynatma / Duraklatma / Sarma)
    socket.onVideoSync = (action, time, isPlaying, senderId) {
      if (!mounted || senderId == _currentUser.id) return;
      setState(() {
        _currentSeconds = time.clamp(0.0, _totalSeconds);
        _isPlaying = isPlaying;
        if (_isWebVideo && _webPlayerController != null) {
          final cmd = isPlaying ? 'playVideo' : 'pauseVideo';
          _webPlayerController?.runJavaScript('''
            (function() {
              var iframe = document.getElementById('player');
              if (iframe && iframe.contentWindow) {
                iframe.contentWindow.postMessage('{"event":"command","func":"seekTo","args":[${time.toInt()}, true]}', '*');
                iframe.contentWindow.postMessage('{"event":"command","func":"$cmd","args":""}', '*');
              }
              var v = document.querySelector('video');
              if (v) {
                v.currentTime = ${time.toInt()};
                if ('$cmd' === 'playVideo') { v.play(); } else { v.pause(); }
              }
            })();
          ''');
        } else if (_videoController != null && _isVideoInitialized) {
          _videoController!.seekTo(Duration(seconds: time.toInt()));
          if (isPlaying) {
            _videoController!.play();
          } else {
            _videoController!.pause();
          }
        }
      });
    };

    // Canlı Sohbet Mesajı
    socket.onChatMessage = (msg) {
      if (!mounted) return;
      if (msg.senderId == _currentUser.id) return;
      _triggerEmojiAnimationIfEmoji(msg.content);
      setState(() {
        _messages.add(msg);
      });
      _scrollToBottom();
    };

    // Ekranda Uçuşan Reaksiyon
    socket.onReactionReceived = (emoji, senderId) {
      if (!mounted) return;
      _triggerEmojiAnimationIfEmoji(emoji);
    };

    // Mikrofon ve Konuşma Durumu Senkronizasyonu
    socket.onMicStatusChanged = (userId, isMicOn, isSpeaking) {
      if (!mounted) return;
      setState(() {
        for (final p in _allParticipants) {
          if (p.id == userId) {
            if (isMicOn != null) p.isMicOn = isMicOn;
            if (isSpeaking != null) p.isSpeaking = isSpeaking;
          }
        }
      });
    };

    // Google Web Sayfa Senkronizasyonu
    socket.onWebSync = (action, payload, senderId) {
      if (!mounted || senderId == _currentUser.id) return;
      if (action == 'scroll' && payload is Map && payload['offset'] != null) {
        final offset = (payload['offset'] as num).toDouble();
        if (_googleScrollController.hasClients) {
          _googleScrollController.jumpTo(
            offset.clamp(0.0, _googleScrollController.position.maxScrollExtent),
          );
        }
      } else if (action == 'tab' && payload is Map && payload['tab'] != null) {
        setState(() {
          _activeWebTab = payload['tab'].toString();
        });
      }
    };
  }

  void _initVideoPlayer() {
    final movie = widget.movie;
    final isYt = movie.isYouTube || movie.youTubeVideoId != null;
    final isWeb = isYt || movie.videoUrl.contains('netflix.com');

    if (isWeb) {
      _isWebVideo = true;
      _initWebPlayer(movie);
      return;
    }

    _isWebVideo = false;
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.movie.videoUrl),
    )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController?.play();
          _videoController?.setLooping(true);
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = false;
          });
        }
      });

    _videoController?.addListener(() {
      if (mounted && _isVideoInitialized) {
        setState(() {
          _isPlaying = _videoController?.value.isPlaying ?? false;
        });
      }
    });
  }

  void _initWebPlayer(Movie movie) {
    try {
      final controller = WebViewController();
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setBackgroundColor(Colors.black);
      controller.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      );

      final ytId = movie.youTubeVideoId;
      if (ytId != null && ytId.isNotEmpty) {
        final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; background:#000; overflow:hidden; }
    html, body { width:100%; height:100%; }
    iframe { width:100%; height:100%; border:none; }
  </style>
</head>
<body>
  <iframe id="player"
          src="https://www.youtube.com/embed/$ytId?autoplay=1&playsinline=1&enablejsapi=1&rel=0&controls=1"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen>
  </iframe>
</body>
</html>
''';
        controller.loadHtmlString(html, baseUrl: 'https://www.youtube.com');
      } else {
        controller.loadRequest(Uri.parse(movie.videoUrl));
      }

      setState(() {
        _webPlayerController = controller;
        _isVideoInitialized = true;
      });
    } catch (_) {}
  }

  void _startPlaybackTimer() {
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_isPlaying) {
        setState(() {
          if (_currentSeconds < _totalSeconds) {
            _currentSeconds += 1.0;
          }
        });
      }
    });
  }

  void _startControlsTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    } else {
      _controlsHideTimer?.cancel();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _playbackTimer?.cancel();
    _controlsHideTimer?.cancel();
    _chatOverlayHideTimer?.cancel();
    SocketService().leaveRoom();
    _voice?.dispose();
    _googleScrollController.dispose();
    _videoController?.dispose();
    try {
      _webPlayerController?.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    _textController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onGoogleScroll() {
    if (_googleScrollController.hasClients) {
      _triggerSyncNotification('⚡ Kaydırma senkronize ediliyor');
      SocketService().sendWebSync(
        action: 'scroll',
        payload: {'offset': _googleScrollController.offset},
      );
    }
  }

  void _resetChatOverlayTimer() {
    _chatOverlayHideTimer?.cancel();
    if (!_showChatOverlayControl) {
      setState(() {
        _showChatOverlayControl = true;
      });
    }
    _chatOverlayHideTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showChatOverlayControl = false;
        });
      }
    });
  }

  void _toggleChatVisibility() {
    HapticFeedback.lightImpact();
    setState(() {
      _isChatVisible = !_isChatVisible;
    });
    _triggerSyncNotification(
      _isChatVisible
          ? '💬 Sohbet açıldı'
          : '💬 Sohbet gizlendi — Her iki cihazda tam ekran',
    );
  }

  void _triggerSyncNotification(String message) {
    // Ekranda beliren uyarı ve toast bildirimleri kullanıcı isteğiyle kaldırıldı
  }

  void _initGoogleWebView() {
    try {
      final controller = WebViewController();
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setBackgroundColor(Colors.black);
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _triggerSyncNotification('Sayfa Yükleniyor: $url');
          },
          onPageFinished: (url) {
            _triggerSyncNotification('Sayfa Senkronize Edildi');
            // Inject scroll synchronization listener
            controller.runJavaScript('''
              window.addEventListener('scroll', function() {
                var max = document.documentElement.scrollHeight - window.innerHeight;
                if (max > 0) {
                  var p = (window.scrollY / max).toFixed(2);
                  if (window.WatchPartySync) {
                    WatchPartySync.postMessage('scroll:' + p);
                  }
                }
              });
            ''');
          },
        ),
      );
      controller.addJavaScriptChannel(
        'WatchPartySync',
        onMessageReceived: (message) {
          if (mounted) {
            _triggerSyncNotification('⚡ Kaydırma senkronize ediliyor');
          }
        },
      );
      controller.loadRequest(Uri.parse('https://www.google.com'));
      setState(() {
        _googleWebController = controller;
      });
    } catch (_) {}
  }

  void _startMovieInRoom(Movie selectedMovie) {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    try {
      _webPlayerController?.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}
    _webPlayerController = null;

    setState(() {
      _isVideoInitialized = false;
      _isGoogleWebMode = false;
      _currentSeconds = 0;
    });

    final isYt = selectedMovie.isYouTube || selectedMovie.youTubeVideoId != null;
    final isWeb = isYt || selectedMovie.videoUrl.contains('netflix.com');

    if (isWeb) {
      _isWebVideo = true;
      _initWebPlayer(selectedMovie);
      return;
    }

    _isWebVideo = false;
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(selectedMovie.videoUrl),
    )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _isPlaying = true;
          });
          _videoController?.play();
          _videoController?.setLooping(true);
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = false;
          });
        }
      });
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isWebVideo && _webPlayerController != null) {
        final cmd = _isPlaying ? 'playVideo' : 'pauseVideo';
        _webPlayerController?.runJavaScript('''
          (function() {
            var iframe = document.getElementById('player');
            if (iframe && iframe.contentWindow) {
              iframe.contentWindow.postMessage('{"event":"command","func":"$cmd","args":""}', '*');
            }
            var v = document.querySelector('video');
            if (v) {
              if ('$cmd' === 'playVideo') { v.play(); } else { v.pause(); }
            }
          })();
        ''');
      } else if (_videoController != null && _isVideoInitialized) {
        if (_isPlaying) {
          _videoController!.play();
        } else {
          _videoController!.pause();
        }
      }
      _showControls = true;
      _startControlsTimer();
    });
    SocketService().sendVideoSync(
      action: _isPlaying ? 'play' : 'pause',
      time: _currentSeconds,
    );
  }

  void _seekRelative(int seconds) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentSeconds = (_currentSeconds + seconds).clamp(0.0, _totalSeconds);
      if (_isWebVideo && _webPlayerController != null) {
        _webPlayerController?.runJavaScript('''
          (function() {
            var iframe = document.getElementById('player');
            if (iframe && iframe.contentWindow) {
              iframe.contentWindow.postMessage('{"event":"command","func":"seekTo","args":[${_currentSeconds.toInt()}, true]}', '*');
            }
            var v = document.querySelector('video');
            if (v) { v.currentTime = ${_currentSeconds.toInt()}; }
          })();
        ''');
      } else if (_videoController != null && _isVideoInitialized) {
        _videoController!.seekTo(Duration(seconds: _currentSeconds.toInt()));
      }
      _showControls = true;
      _startControlsTimer();
    });
    SocketService().sendVideoSync(
      action: 'seek',
      time: _currentSeconds,
    );
  }

  String _formatDuration(int totalSecs) {
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String? _getCurrentSubtitleText() {
    if (_activeSubtitle == 'KAPALI') return null;

    final sec = _currentSeconds.toInt() % 28;
    if (_activeSubtitle == 'TR') {
      if (sec < 7) return 'Duyuyor musun bunu? Bir şeyler yaklaşıyor.';
      if (sec < 14) return 'Hawkins artık eskisi gibi güvenli değil.';
      if (sec < 21) return 'Birlikte kalırsak bunu durdurabiliriz.';
      return 'Işıkları açık tutun, kapıyı kapatın!';
    } else if (_activeSubtitle == 'EN') {
      if (sec < 7) return 'Do you hear that? Something is coming.';
      if (sec < 14) return 'Hawkins is not safe anymore.';
      if (sec < 21) return 'If we stick together, we can stop this.';
      return 'Keep the lights on, lock the door!';
    }
    return null;
  }

  void _toggleMyMic() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isMyMicOn = !_isMyMicOn;
      _currentUser.isMicOn = _isMyMicOn;
      _currentUser.isSpeaking = _isMyMicOn;
    });
    SocketService().sendMicStatus(
      isMicOn: _isMyMicOn,
      isSpeaking: _isMyMicOn,
    );
    _voice?.setMuted(!_isMyMicOn);
  }

  void _triggerEmojiAnimationIfEmoji(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 4 && trimmed.runes.length <= 2) {
      final reaction = FloatingReactionModel(
        key: UniqueKey(),
        emoji: trimmed,
        startX: 120.0 + _random.nextDouble() * 160.0,
        swayAmount: 20.0 + _random.nextDouble() * 25.0,
        size: 30.0 + _random.nextDouble() * 8.0,
      );
      setState(() {
        _activeReactions.add(reaction);
      });
    }
  }

  void _sendMessage(String text, {bool isEmojiReaction = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _triggerEmojiAnimationIfEmoji(trimmed);

    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      senderId: _currentUser.id,
      senderName: _currentUser.name,
      senderAvatar: _currentUser.avatarUrl,
      content: trimmed,
      timestamp: DateTime.now(),
      isCurrentUser: true,
      type: isEmojiReaction ? MessageType.reaction : MessageType.text,
    );

    setState(() {
      _messages.add(newMsg);
    });

    SocketService().sendChatMessage(newMsg);

    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // VİDEO VE OYNATICI AYARLARI MODALI (Görüntü Kalitesi & Altyazı Kapatma)
  void _showVideoPlayerSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(CupertinoIcons.gear_alt, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Video ve Oynatıcı Ayarları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 1. GÖRÜNTÜ AYARLARI (Görüntü Kalitesi)
                const Text(
                  'Görüntü Kalitesi',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQualityChip('Otomatik (1080p)', setSheetState),
                    _buildQualityChip('4K UHD (2160p)', setSheetState),
                    _buildQualityChip('1080p Full HD', setSheetState),
                    _buildQualityChip('720p HD', setSheetState),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. ALTYAZI AYARLARI (KAPATMA & DİLLER)
                const Text(
                  'Altyazı',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSubtitleChip('KAPALI', 'Altyazıyı Kapat', setSheetState),
                    _buildSubtitleChip('TR', 'Türkçe (Varsayılan)', setSheetState),
                    _buildSubtitleChip('EN', 'İngilizce', setSheetState),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. OYNATMA HIZI AYARLARI
                const Text(
                  'Oynatma Hızı',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSpeedChip(0.75, '0.75x (Yavaş)', setSheetState),
                    _buildSpeedChip(1.0, '1.0x (Normal)', setSheetState),
                    _buildSpeedChip(1.25, '1.25x', setSheetState),
                    _buildSpeedChip(1.5, '1.5x (Hızlı)', setSheetState),
                    _buildSpeedChip(2.0, '2.0x', setSheetState),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualityChip(String quality, StateSetter setSheetState) {
    final isSelected = _activeVideoQuality == quality;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _activeVideoQuality = quality);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.ravePurple.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.ravePurple : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, color: Colors.white, size: 14),
              const SizedBox(width: 5),
            ],
            Text(
              quality,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleChip(String code, String label, StateSetter setSheetState) {
    final isSelected = _activeSubtitle == code;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _activeSubtitle = code);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (code == 'KAPALI'
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : AppTheme.ravePurple.withValues(alpha: 0.25))
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (code == 'KAPALI' ? Colors.redAccent : AppTheme.ravePurple)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                code == 'KAPALI' ? CupertinoIcons.xmark : Icons.check,
                color: code == 'KAPALI' ? Colors.redAccent : Colors.white,
                size: 14,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedChip(double speed, String label, StateSetter setSheetState) {
    final isSelected = _playbackSpeed == speed;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _playbackSpeed = speed);
        _videoController?.setPlaybackSpeed(speed);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.ravePurple.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.ravePurple : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, color: Colors.white, size: 14),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showParticipantsModal({int initialView = 0}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        int currentView = initialView;
        String searchQuery = '';
        final searchController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (currentView == 0) ...[
                    // VIEW 0: KATILIMCILAR LİSTESİ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(CupertinoIcons.person_2_fill, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Katılımcılar (${_allParticipants.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              currentView = 1;
                              searchQuery = '';
                              searchController.clear();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.ravePurple.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.ravePurple.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.person_badge_plus, color: AppTheme.ravePurple, size: 14),
                                SizedBox(width: 5),
                                Text(
                                  'Davet Et',
                                  style: TextStyle(
                                    color: AppTheme.ravePurple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _allParticipants.isEmpty
                          ? const Center(
                              child: Text(
                                'Odada henüz kimse yok.',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _allParticipants.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final participant = _allParticipants[index];
                                final isMe = participant.id == _currentUser.id;
                                final isMicOn = isMe ? _isMyMicOn : participant.isMicOn;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isMe
                                          ? AppTheme.ravePurple.withValues(alpha: 0.25)
                                          : Colors.white.withValues(alpha: 0.04),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundImage: MockDataService.getAvatarProvider(participant.avatarUrl, isMe: isMe),
                                            backgroundColor: AppTheme.surfaceLight,
                                          ),
                                          if (participant.isSpeaking)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.ravePurple,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.black, width: 2),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    participant.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.ravePurple.withValues(alpha: 0.18),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'ODA SAHİBİ',
                                                      style: TextStyle(
                                                        color: AppTheme.ravePurple,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              participant.isSpeaking
                                                  ? 'Konuşuyor...'
                                                  : (isMicOn ? 'Mikrofon Açık' : 'Sessizde'),
                                              style: TextStyle(
                                                color: participant.isSpeaking
                                                    ? AppTheme.ravePurple
                                                    : (isMicOn ? Colors.white70 : AppTheme.textMuted),
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Mikrofon Durumu & Kontrolü (Açıkken siyahımsı UI uyumlu)
                                      GestureDetector(
                                        onTap: () {
                                          if (isMe) {
                                            _toggleMyMic();
                                            setModalState(() {});
                                          } else {
                                            setModalState(() {
                                              participant.isMicOn = !participant.isMicOn;
                                              if (!participant.isMicOn) {
                                                participant.isSpeaking = false;
                                              }
                                            });
                                            setState(() {});
                                          }
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isMicOn
                                                ? const Color(0xFF22232A)
                                                : Colors.white.withValues(alpha: 0.05),
                                            border: Border.all(
                                              color: isMicOn
                                                  ? const Color(0xFF383844)
                                                  : Colors.transparent,
                                              width: 1.0,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isMicOn ? Icons.mic : Icons.mic_off,
                                            color: isMicOn ? Colors.white : AppTheme.textMuted,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      // Odadan Çıkar Butonu (Sadece oda sahibi dışındakiler için)
                                      if (!isMe) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              _allParticipants.removeWhere((p) => p.id == participant.id);
                                            });
                                            setState(() {});
                                          },
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              CupertinoIcons.xmark,
                                              color: Colors.redAccent,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ] else ...[
                    // VIEW 1: ARKADAŞLARI DAVET ET
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              currentView = 0;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Katılımcılar (${_allParticipants.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Text(
                          'Arkadaş Davet Et',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Arama Kutusu
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.search, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              onChanged: (val) {
                                setModalState(() {
                                  searchQuery = val.trim().toLowerCase();
                                });
                              },
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'İsimle ara veya yeni davet et...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ),
                          ),
                          if (searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                searchController.clear();
                                setModalState(() => searchQuery = '');
                              },
                              child: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white38, size: 16),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Kaynak liste: Eklediğimiz arkadaşlar
                          final friendsSource = MockDataService.addedFriends;

                          // Arama varsa: hem ekli arkadaşlar hem kayıtlı kullanıcılar arasında ara
                          final List<UserProfile> filteredFriends;
                          if (searchQuery.isNotEmpty) {
                            final query = searchQuery.toLowerCase();
                            final addedMatches = friendsSource.where((f) =>
                                f.name.toLowerCase().contains(query) ||
                                f.id.toLowerCase().contains(query)).toList();
                            final otherMatches = MockDataService.friends.where((f) =>
                                !friendsSource.any((af) => af.id == f.id) &&
                                (f.name.toLowerCase().contains(query) ||
                                 f.id.toLowerCase().contains(query))).toList();
                            filteredFriends = [...addedMatches, ...otherMatches];
                          } else {
                            filteredFriends = friendsSource;
                          }

                          final isExactMatchFound = filteredFriends.any(
                            (f) => f.name.toLowerCase() == searchQuery || f.id.toLowerCase() == searchQuery,
                          );

                          if (filteredFriends.isEmpty && searchQuery.isEmpty) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.person_2,
                                        color: Colors.white38,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Henüz Ekli Arkadaş Yok',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Eklediğin arkadaşlar burada listelenir. Yukarıdaki arama kutusuna isim veya ID yazarak da davet edebilirsin.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const AddFriendScreen(),
                                          ),
                                        );
                                        setState(() {});
                                      },
                                      icon: const Icon(CupertinoIcons.person_add, size: 14),
                                      label: const Text('ID ile Arkadaş Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E1E26),
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white12),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView(
                            children: [
                              ...filteredFriends.map((f) {
                                final bool isAlreadyIn = _allParticipants.any((p) => p.id == f.id || p.name == f.name);
                                final bool isPending = _pendingInviteIds.contains(f.id);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundImage: NetworkImage(f.avatarUrl),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    f.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '#${f.id}',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              f.isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                                              style: TextStyle(
                                                color: f.isOnline ? AppTheme.neonGreen : AppTheme.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isAlreadyIn)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check, color: AppTheme.neonGreen, size: 14),
                                              SizedBox(width: 4),
                                              Text(
                                                'Odada',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (isPending)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(CupertinoIcons.paperplane_fill, color: AppTheme.ravePurple, size: 12),
                                              SizedBox(width: 5),
                                              Text(
                                                'Davet Edildi',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: () async {
                                            final sent = _roomId != null && await ApiService().inviteToRoom(roomId: _roomId!, targetId: f.id);
                                            if (!sent || !context.mounted) return;
                                            setModalState(() {
                                              _pendingInviteIds.add(f.id);
                                            });
                                            HapticFeedback.lightImpact();
                                            setState(() {});
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(CupertinoIcons.paperplane_fill, color: AppTheme.ravePurple, size: 16),
                                                    const SizedBox(width: 8),
                                                    Text('${f.name} adlı kullanıcıya davet gönderildi.'),
                                                  ],
                                                ),
                                                backgroundColor: const Color(0xFF1B1B22),
                                                duration: const Duration(seconds: 2),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.ravePurple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          child: const Text(
                                            'Davet Et',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                              if (searchQuery.isNotEmpty && !isExactMatchFound && filteredFriends.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      '"$searchQuery" adlı arkadaşınız bulunamadı.',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final isLandscape = _isLandscape || MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildCinematicVideoPlayer(movie, isFullScreen: true),
            ..._activeReactions.map((reaction) {
              return ReactionItemWidget(
                key: reaction.key,
                item: reaction,
                onComplete: () {
                  setState(() {
                    _activeReactions.removeWhere((r) => r.key == reaction.key);
                  });
                },
              );
            }),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Üst Profesyonel Başlık Çubuğu
                _buildModernHeader(movie),

                // 2. Sinematik Video Oynatıcı / Google Web Alanı
                if (_isChatVisible) ...[
                  _buildCinematicVideoPlayer(movie, isFullScreen: false),

                  // İnce Ayırıcı
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),

                  // 3. Canlı Sosyal Sohbet Akışı (Genişletilmiş ve Ferah)
                  Expanded(
                    child: _buildLiveStreamChat(),
                  ),

                  // 4. Sade & Modern Mesaj Giriş Barı
                  _buildBottomInteractiveBar(),
                ] else ...[
                  // Sohbet Kapatıldığında Her İki Cihazda da Tam Ekran Web / Video
                  Expanded(
                    child: _buildCinematicVideoPlayer(movie, isFullScreen: false),
                  ),
                ],
              ],
            ),

            // Uçuşan Reaksiyon Emojileri Katmanı
            ..._activeReactions.map((reaction) {
              return ReactionItemWidget(
                key: reaction.key,
                item: reaction,
                onComplete: () {
                  setState(() {
                    _activeReactions.removeWhere((r) => r.key == reaction.key);
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // 1. MODERN HEADER
  Widget _buildModernHeader(Movie movie) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Geri Butonu
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                CupertinoIcons.chevron_down,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Başlık
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final isGoogle = movie.id.startsWith('google') || movie.tags.contains('Google');
                    final isYouTube = movie.id.startsWith('yt') || movie.tags.contains('YouTube');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isGoogle
                            ? const Color(0xFF4285F4)
                            : (isYouTube ? const Color(0xFFFF0000) : AppTheme.netflixRed),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isGoogle ? 'GOOGLE WEB' : (isYouTube ? 'YOUTUBE' : 'NETFLIX'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Katılımcı Sayısı Butonu (Sadece İkon ve Sayı - Tıklayınca Katılımcıları Gösterir)
          GestureDetector(
            onTap: _showParticipantsModal,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.person_2_fill,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_allParticipants.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. CİNEMATİK VİDEO OYNATICI
  Widget _buildCinematicVideoPlayer(Movie movie, {bool isFullScreen = false}) {
    final isGoogle = movie.id.startsWith('google') || movie.tags.contains('Google');
    if (isGoogle && _isGoogleWebMode) {
      final googleBody = _buildGoogleWebSection(movie, isFullScreen: isFullScreen || !_isChatVisible);
      if (isFullScreen || !_isChatVisible) return googleBody;
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: googleBody,
      );
    }

    final playerBody = GestureDetector(
      onTap: _toggleControlsVisibility,
      behavior: HitTestBehavior.opaque,
      child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Video Akışı veya Arka Plan Görseli
              if (_isWebVideo && _webPlayerController != null)
                WebViewWidget(controller: _webPlayerController!)
              else if (_isVideoInitialized && _videoController != null)
                VideoPlayer(_videoController!)
              else
                Image.network(
                  movie.backdropUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF141414),
                    child: const Center(
                      child: Icon(Icons.movie_creation_outlined, size: 48, color: Colors.white24),
                    ),
                  ),
                ),

              // Karartma Katmanı
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: _showControls
                    ? Colors.black.withValues(alpha: 0.5)
                    : (_isWebVideo ? Colors.transparent : Colors.black.withValues(alpha: 0.1)),
              ),

              // Üst Detay Bilgileri & Kontroller (Yatay modda sol üst mikrofon, sağ üst çark ayarları)
              if (_showControls)
                Positioned(
                  top: isFullScreen ? 18 : 10,
                  left: isFullScreen ? 20 : 12,
                  right: isFullScreen ? 20 : 12,
                  child: Row(
                    children: [
                      // Sol Taraf: Yatay Modda Geri Butonu & Sol Üst Mikrofon Butonu
                      if (isFullScreen) ...[
                        GestureDetector(
                          onTap: _toggleOrientation,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Yatay Modda Sol Üst Mikrofon Butonu (Açıp Kapatılabilir — Siyahımsı UI Uyumlu)
                        GestureDetector(
                          onTap: _toggleMyMic,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isMyMicOn
                                  ? const Color(0xFF1E1F26)
                                  : Colors.black.withValues(alpha: 0.65),
                              border: Border.all(
                                color: _isMyMicOn
                                    ? const Color(0xFF383844)
                                    : Colors.white24,
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isMyMicOn ? Icons.mic : Icons.mic_off,
                              color: _isMyMicOn ? Colors.white : const Color(0xFFEF4444),
                              size: 19,
                            ),
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Google Web Moduna Dönüş Butonu (Google Odasında İken)
                      if (isGoogle) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isGoogleWebMode = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4285F4).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.globe, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Google Web',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Görüntü Kalitesi Rozeti
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Text(
                          _activeVideoQuality.contains('4K')
                              ? '4K UHD'
                              : (_activeVideoQuality.contains('720p') ? '720p HD' : '1080p FHD'),
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sağ Üst Taraf: Çark İkonu (Görüntü Kalitesi & Altyazı Kapatma Ayarları)
                      GestureDetector(
                        onTap: _showVideoPlayerSettingsModal,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(
                            CupertinoIcons.gear_alt,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Orta Oynatma Kontrolleri (-10s / Play-Pause / +10s)
              if (_showControls)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSeekButton(
                        icon: CupertinoIcons.gobackward_10,
                        onTap: () => _seekRelative(-10),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.netflixRed, Color(0xFFB8000A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.netflixRed.withValues(alpha: 0.5),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      _buildSeekButton(
                        icon: CupertinoIcons.goforward_10,
                        onTap: () => _seekRelative(10),
                      ),
                    ],
                  ),
                ),

              // Canlı Altyazı Katmanı
              Builder(
                builder: (context) {
                  final subtitle = _getCurrentSubtitleText();
                  if (subtitle == null) return const SizedBox.shrink();
                  return Positioned(
                    bottom: _showControls ? 58 : 16,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Alt Oynatıcı Çubuğu (Scrubber + Süre + Ses)
              if (_showControls)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // İnce & Hassas Zaman Çubuğu
                      SizedBox(
                        height: 16,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                            thumbColor: AppTheme.netflixRed,
                            activeTrackColor: AppTheme.netflixRed,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            overlayColor: AppTheme.netflixRed.withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: _currentSeconds.clamp(0.0, _totalSeconds),
                            min: 0.0,
                            max: _totalSeconds,
                            onChangeStart: (val) {
                              _controlsHideTimer?.cancel();
                            },
                            onChanged: (val) {
                              setState(() {
                                _currentSeconds = val;
                              });
                            },
                            onChangeEnd: (val) {
                              _videoController?.seekTo(Duration(seconds: val.toInt()));
                              _startControlsTimer();
                            },
                          ),
                        ),
                      ),

                    // Süre ve Araç Düğmeleri
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Text(
                            '${_formatDuration(_currentSeconds.toInt())} / ${_formatDuration(_totalSeconds.toInt())}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const Spacer(),

                          // Hız Rozeti
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _playbackSpeed = _playbackSpeed == 1.0 ? 1.25 : (_playbackSpeed == 1.25 ? 1.5 : 1.0);
                                _videoController?.setPlaybackSpeed(_playbackSpeed);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Yatay Mod / Tam Ekran Butonu
                          GestureDetector(
                            onTap: _toggleOrientation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: _isLandscape
                                    ? AppTheme.netflixRed.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                _isLandscape
                                    ? CupertinoIcons.fullscreen_exit
                                    : CupertinoIcons.fullscreen,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Ses Mute
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isMuted = !_isMuted;
                                _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
                              });
                            },
                            child: Icon(
                              _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

    if (isFullScreen || !_isChatVisible) {
      return playerBody;
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: playerBody,
    );
  }

  Widget _buildGoogleWebSection(Movie movie, {bool isFullScreen = false}) {
    return GestureDetector(
      onTap: _resetChatOverlayTimer,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: const Color(0xFF101014),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_googleWebController != null)
              WebViewWidget(controller: _googleWebController!)
            else
              _buildGoogleInteractivePortal(),

            // Sol Alt: Sohbet Aç/Kapat Butonu (10 Saniyede Otomatik Gizlenir, Tıklanınca Tekrar Gelir)
            Positioned(
              left: 12,
              bottom: 10,
              child: AnimatedOpacity(
                opacity: _showChatOverlayControl ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showChatOverlayControl,
                  child: GestureDetector(
                    onTap: () {
                      _toggleChatVisibility();
                      _resetChatOverlayTimer();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _isChatVisible
                              ? const Color(0xFF4285F4).withValues(alpha: 0.6)
                              : Colors.white30,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isChatVisible
                                ? CupertinoIcons.chat_bubble_2_fill
                                : CupertinoIcons.chat_bubble_2,
                            color: _isChatVisible ? const Color(0xFF4285F4) : Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isChatVisible ? 'Sohbeti Gizle' : 'Sohbeti Aç',
                            style: TextStyle(
                              color: _isChatVisible ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildGoogleInteractivePortal() {
    return SingleChildScrollView(
      controller: _googleScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          // Renkli Google Başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 24, fontWeight: FontWeight.w900)),
              Text('o', style: TextStyle(color: Color(0xFFEA4335), fontSize: 24, fontWeight: FontWeight.w900)),
              Text('o', style: TextStyle(color: Color(0xFFFBBC05), fontSize: 24, fontWeight: FontWeight.w900)),
              Text('g', style: TextStyle(color: Color(0xFF4285F4), fontSize: 24, fontWeight: FontWeight.w900)),
              Text('l', style: TextStyle(color: Color(0xFF34A853), fontSize: 24, fontWeight: FontWeight.w900)),
              Text('e', style: TextStyle(color: Color(0xFFEA4335), fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),

          // Senkronize Arama Çubuğu
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F27),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.search, color: Colors.white54, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: "Google'da ara veya film/video bul...",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 11.5),
                    ),
                    onSubmitted: (query) {
                      if (query.trim().isNotEmpty) {
                        _triggerSyncNotification('Ortak Arama Senkronize Edildi: "$query"');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Sekme Değiştirici (Tümü, Videolar, Görseller, Haberler)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildWebTabChip('Tümü'),
                const SizedBox(width: 6),
                _buildWebTabChip('Videolar'),
                const SizedBox(width: 6),
                _buildWebTabChip('Görseller'),
                const SizedBox(width: 6),
                _buildWebTabChip('Haberler'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Hızlı Film / Video Önerileri
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '🎥 Odada İzlenebilecek Popüler Videolar & Filmler',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          // Örnek Oynatılabilir Videolar
          ...MockDataService.youtubeVideos.take(3).map((video) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF181922),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      video.backdropUrl,
                      width: 50,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 50,
                        height: 32,
                        color: Colors.white10,
                        child: const Icon(Icons.play_arrow, color: Colors.white30, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          video.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _startMovieInRoom(video);
                      _triggerSyncNotification('Film Başlatıldı: ${video.title}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Oynat',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWebTabChip(String title) {
    final isSelected = _activeWebTab == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeWebTab = title;
        });
        _triggerSyncNotification('Sekme Değiştirildi: $title — İki cihazda da açıldı');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4285F4) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSeekButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // 3. CANLI SOSYAL SOHBET AKIŞI
  Widget _buildLiveStreamChat() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];

        // Sistem Mesajları Tamamen Gizlendi
        if (msg.type == MessageType.system) {
          return const SizedBox.shrink();
        }

        final isMe = msg.isCurrentUser;

        // Yayın Tarzı Modern Mesaj Öğesi
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 14,
                backgroundImage: MockDataService.getAvatarProvider(msg.senderAvatar, isMe: isMe),
                backgroundColor: AppTheme.surfaceLight,
              ),
              const SizedBox(width: 10),

              // Mesaj Gövdesi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          msg.senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white : const Color(0xFFA78BFA),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (msg.type == MessageType.reaction)
                      Text(
                        msg.content,
                        style: const TextStyle(fontSize: 26),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppTheme.ravePurple.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                          border: Border.all(
                            color: isMe
                                ? AppTheme.ravePurple.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(
                          msg.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. ETKİLEŞİM & MESAJ GİRİŞ BARI (chat_input.dart referans tasarımına göre)
  Widget _buildBottomInteractiveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mikrofon Butonu (Input tasarımına tam uyumlu)
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: _InteractiveMicButton(
              isMicOn: _isMyMicOn,
              onTap: _toggleMyMic,
            ),
          ),
          const SizedBox(width: 8),

          // Chat Input Alanı (#000000 arka plan, dikey olarak küçültülmüş, emojisiz)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.fromLTRB(14, 4, 5, 4),
              decoration: BoxDecoration(
                color: const Color(0xFF000000), // #000000
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _inputFocus.hasFocus
                      ? const Color(0xFF3C3C49)
                      : const Color(0xFF2A2A33),
                  width: 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _inputFocus,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        _sendMessage(_textController.text);
                        _inputFocus.requestFocus();
                      },
                      cursorColor: const Color(0xFFECEFF4),
                      cursorRadius: const Radius.circular(2),
                      style: const TextStyle(
                        color: Color(0xFFECEFF4),
                        fontSize: 14,
                        height: 1.3,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Mesaj yaz…',
                        hintStyle: TextStyle(
                          color: Color(0xFF6B6B7A),
                          fontSize: 14,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _SendButton(
                    onTap: () {
                      _sendMessage(_textController.text);
                      _inputFocus.requestFocus();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  MİKROFON BUTONU — Input alanına tam uyumlu 44px daire
// ---------------------------------------------------------------------------
class _InteractiveMicButton extends StatefulWidget {
  final bool isMicOn;
  final VoidCallback onTap;

  const _InteractiveMicButton({
    required this.isMicOn,
    required this.onTap,
  });

  @override
  State<_InteractiveMicButton> createState() => _InteractiveMicButtonState();
}

class _InteractiveMicButtonState extends State<_InteractiveMicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.92 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isMicOn ? const Color(0xFF1E1F26) : const Color(0xFF101014),
            border: Border.all(
              color: widget.isMicOn
                  ? const Color(0xFF383844)
                  : const Color(0xFF26262F),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            widget.isMicOn ? Icons.mic : Icons.mic_off,
            color: widget.isMicOn ? Colors.white : const Color(0xFFEF4444),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  GÖNDER BUTONU — 34px daire, #242528, beyaz yukarı ok
// ---------------------------------------------------------------------------
class _SendButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _pressed ? 0.92 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered ? const Color(0xFF2C2D31) : const Color(0xFF242528),
            ),
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
