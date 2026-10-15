class Movie {
  final String id;
  final String title;
  final String category;
  final String duration;
  final double rating;
  final String posterUrl;
  final String backdropUrl;
  final String description;
  final String videoUrl;
  final String releaseYear;
  final List<String> tags;

  Movie({
    required this.id,
    required this.title,
    required this.category,
    required this.duration,
    required this.rating,
    required this.posterUrl,
    required this.backdropUrl,
    required this.description,
    required this.videoUrl,
    required this.releaseYear,
    required this.tags,
  });

  bool get isYouTube =>
      videoUrl.contains('youtube.com') ||
      videoUrl.contains('youtu.be') ||
      category.toLowerCase().contains('youtube');

  String? get youTubeVideoId {
    final fromUrl = extractYouTubeVideoId(videoUrl);
    if (fromUrl != null) return fromUrl;
    if (id.startsWith('yt_') && id.length >= 14) {
      return id.substring(3);
    }
    return null;
  }
}

String? extractYouTubeVideoId(String? input) {
  if (input == null || input.trim().isEmpty) return null;
  final cleanInput = input.trim();

  if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanInput)) {
    return cleanInput;
  }

  final regExp = RegExp(
    r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|v\/|shorts\/|live\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );

  final match = regExp.firstMatch(cleanInput);
  if (match != null && match.groupCount >= 1) {
    return match.group(1);
  }
  return null;
}
