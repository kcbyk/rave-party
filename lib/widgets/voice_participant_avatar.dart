import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';

class VoiceParticipantAvatar extends StatefulWidget {
  final UserProfile user;
  final bool isHost;
  final VoidCallback? onTap;

  const VoiceParticipantAvatar({
    super.key,
    required this.user,
    this.isHost = false,
    this.onTap,
  });

  @override
  State<VoiceParticipantAvatar> createState() => _VoiceParticipantAvatarState();
}

class _VoiceParticipantAvatarState extends State<VoiceParticipantAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isSpeaking = user.isSpeaking && user.isMicOn;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Konuşurken dışarıya yayılan dalga animasyonu
                if (isSpeaking)
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final waveScale = 1.0 + (_animController.value * 0.28);
                      final waveOpacity = (1.0 - _animController.value).clamp(0.0, 0.7);

                      return Transform.scale(
                        scale: waveScale,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.ravePurple.withValues(alpha: waveOpacity),
                              width: 2.0,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Avatar Çerçevesi
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSpeaking
                          ? AppTheme.ravePurple
                          : (user.isMicOn
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1)),
                      width: isSpeaking ? 2.5 : 1.5,
                    ),
                    boxShadow: isSpeaking
                        ? [
                            BoxShadow(
                              color: AppTheme.ravePurple.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: Image.network(
                      user.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppTheme.surfaceLight,
                        child: const Icon(Icons.person, size: 22, color: Colors.white70),
                      ),
                    ),
                  ),
                ),

                // Oda Sahibi Tacı (Host)
                if (widget.isHost)
                  Positioned(
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Text(
                        '👑',
                        style: TextStyle(fontSize: 8),
                      ),
                    ),
                  ),

                // Durum Rozeti (Mikrofon açık/kapalı — Açıkken siyahımsı UI uyumlu)
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: user.isMicOn ? const Color(0xFF1E1F26) : const Color(0xFF16161C),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: user.isMicOn ? const Color(0xFF383844) : const Color(0xFF2A2A33),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      user.isMicOn ? Icons.mic : Icons.mic_off,
                      size: 9.5,
                      color: user.isMicOn ? Colors.white : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // İsim ve Ses Dalga Çizgileri
          SizedBox(
            width: 54,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSpeaking) ...[
                  _MiniWaveIndicator(controller: _animController),
                  const SizedBox(width: 2.5),
                ],
                Flexible(
                  child: Text(
                    user.name.split(' ').first,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isSpeaking ? AppTheme.ravePurple : AppTheme.textPrimary,
                      fontWeight: isSpeaking ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
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

class _MiniWaveIndicator extends StatelessWidget {
  final AnimationController controller;

  const _MiniWaveIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(6.0 + sin(controller.value * 2 * pi) * 2.5),
            const SizedBox(width: 1.5),
            _buildBar(8.0 + cos(controller.value * 2 * pi) * 3.0),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2,
      height: height.clamp(3.0, 9.0),
      decoration: BoxDecoration(
        color: AppTheme.ravePurple,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
