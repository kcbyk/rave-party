import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../services/mock_data_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _idController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  List<UserProfile> _foundProfiles = [];
  bool _isSearching = false;

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
    });
    _executeSearch(_searchQuery);
  }

  Future<void> _executeSearch(String query) async {
    final cleanQuery = query.trim().replaceAll('#', '');
    if (cleanQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _foundProfiles = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await ApiService().searchUsers(cleanQuery);
    if (!mounted) return;

    setState(() {
      _foundProfiles = results;
      _isSearching = false;
    });
  }

  // Panodan ID Yapıştır
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      final text = data.text!.trim();
      _idController.text = text;
      _onSearchChanged(text);
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundProfiles = _foundProfiles;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Üst Başlık & Geri Butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(
                        CupertinoIcons.chevron_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arkadaş Ekle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kullanıcı ID ile profil ara ve ekle',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arama & ID Yapıştırma Çubuğu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141418),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? const Color(0xFF3C3C49)
                        : const Color(0xFF26262E),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.search,
                      color: Color(0xFF9E9EA7),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _idController,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (val) {
                          _onSearchChanged(val);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Kullanıcı ID yapıştır veya yaz...',
                          hintStyle: TextStyle(
                            color: Color(0xFF6B6B7A),
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_idController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _idController.clear();
                          _onSearchChanged('');
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            CupertinoIcons.clear_circled_solid,
                            color: Colors.white38,
                            size: 18,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    // Yapıştır Butonu (Nötr / Beyaz Stil)
                    GestureDetector(
                      onTap: _pasteFromClipboard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.doc_on_clipboard,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Yapıştır',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Profil Listeleme Alanı
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CupertinoActivityIndicator(
                        color: AppTheme.ravePurple,
                        radius: 14,
                      ),
                    )
                  : (_searchQuery.isEmpty
                      ? _buildEmptySearchGuide()
                      : (foundProfiles.isEmpty
                          ? _buildNoResultView()
                          : _buildProfileResultsList(foundProfiles))),
            ),
          ],
        ),
      ),
    );
  }

  // Arama Rehberi (Kutu boşken)
  Widget _buildEmptySearchGuide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.search,
                color: AppTheme.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kullanıcı ID’si Girin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Arkadaşınızın profil ID’sini yukarıdaki kutucuğa yapıştırarak profilini bulabilir ve arkadaş olarak ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sonuç Bulunamadı
  Widget _buildNoResultView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.person_crop_circle_badge_xmark,
            color: Colors.white30,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            '"$_searchQuery" ID’sine ait profil bulunamadı',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lütfen ID’yi doğru yazdığınızdan emin olun.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Eşleşen Profil Listesi
  Widget _buildProfileResultsList(List<UserProfile> profiles) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        final isAdded = MockDataService.isFriend(profile.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF14141A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isAdded
                  ? AppTheme.neonGreen.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              // Avatar & Çevrimiçi Rozeti
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(profile.avatarUrl),
                    backgroundColor: AppTheme.surfaceLight,
                  ),
                  if (profile.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppTheme.neonGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF14141A), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // İsim & ID
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${profile.id}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Arkadaş Ekle Butonu
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isAdded) {
                      ApiService().removeFriend(profile.id);
                    } else {
                      ApiService().addFriend(profile);
                      HapticFeedback.lightImpact();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAdded
                        ? AppTheme.neonGreen.withValues(alpha: 0.15)
                        : AppTheme.netflixRed,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAdded
                          ? AppTheme.neonGreen.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdded ? Icons.check : CupertinoIcons.person_badge_plus,
                        color: isAdded ? AppTheme.neonGreen : Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAdded ? 'Eklendi' : 'Ekle',
                        style: TextStyle(
                          color: isAdded ? AppTheme.neonGreen : Colors.white,
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
        );
      },
    );
  }
}
