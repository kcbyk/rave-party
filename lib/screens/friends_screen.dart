import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/mock_data_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'add_friend_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _openAddFriendScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddFriendScreen(),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openInvitations() async {
    final invites = await ApiService().pendingInvitations();
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF1A1A22), builder: (sheetContext) => ListView(
      padding: const EdgeInsets.all(20),
      children: [const Text('Bekleyen Davetler', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
        if (invites.isEmpty) const Text('Bekleyen davet yok.', style: TextStyle(color: Colors.white70)),
        ...invites.map((invite) => ListTile(title: Text(invite['type'] == 'room' ? 'Oda daveti' : 'Arkadaşlık isteği', style: const TextStyle(color: Colors.white)), subtitle: Text('Gönderen: ${invite['fromUserId']}', style: const TextStyle(color: Colors.white60)), trailing: Wrap(children: [TextButton(onPressed: () async { await ApiService().respondToInvitation(invite['id'].toString(), false); if (sheetContext.mounted) Navigator.pop(sheetContext); }, child: const Text('Reddet')), ElevatedButton(onPressed: () async { await ApiService().respondToInvitation(invite['id'].toString(), true); if (sheetContext.mounted) Navigator.pop(sheetContext); }, child: const Text('Kabul'))]))),
      ],
    ));
    if (mounted) setState(() {});
  }

  void _removeFriend(UserProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Arkadaşı Çıkar',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${profile.name} adlı kullanıcıyı arkadaş listenizden çıkarmak istiyor musunuz?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.netflixRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                MockDataService.removeFriend(profile.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${profile.name} arkadaş listesinden çıkarıldı.'),
                  backgroundColor: const Color(0xFF22222C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final addedFriends = MockDataService.addedFriends;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Arkadaşlar',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Row(children: [IconButton(icon: const Icon(CupertinoIcons.bell_fill, color: Colors.white), onPressed: _openInvitations), IconButton(icon: const Icon(CupertinoIcons.person_add_solid, color: Colors.white), onPressed: _openAddFriendScreen)]),
                  ],
                ),
              ),
            ),

            if (addedFriends.isEmpty)
              _buildEmptyState()
            else ...[
              // Arkadaşlar Başlığı ve Sayısı
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Eklenen Arkadaşlar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${addedFriends.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Arkadaşlar Listesi
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final friend = addedFriends[index];
                      return _buildFriendCard(friend);
                    },
                    childCount: addedFriends.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Boş Durum (Empty State)
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.person_2,
                  color: AppTheme.textMuted,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Henüz Arkadaş Yok',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Birlikte dizi ve film izlemek için arkadaşlarını davet et.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openAddFriendScreen,
                icon: const Icon(CupertinoIcons.search, size: 16),
                label: const Text('ID ile Arkadaş Bul', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF141418),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF2A2A35), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // Arkadaş Kartı
  Widget _buildFriendCard(UserProfile friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Avatar & Çevrimiçi Göstergesi
          Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(friend.avatarUrl),
                backgroundColor: AppTheme.surfaceLight,
              ),
              if (friend.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF14141A), width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),

          // İsim & ID
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    friend.name,
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
                    '#${friend.id}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Seçenekler / Çıkar
          IconButton(
            icon: const Icon(CupertinoIcons.ellipsis_vertical, color: Colors.white54, size: 18),
            onPressed: () => _removeFriend(friend),
            tooltip: 'İşlemler',
          ),
        ],
      ),
    );
  }
}
