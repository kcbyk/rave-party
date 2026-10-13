class UserProfile {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isOnline;
  final String? currentWatching;
  bool isMicOn;
  bool isSpeaking;

  UserProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isOnline = true,
    this.currentWatching,
    this.isMicOn = false,
    this.isSpeaking = false,
  });
}
