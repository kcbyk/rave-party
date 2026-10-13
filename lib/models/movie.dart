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
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|v\/|shorts\/)|youtu\.be\/)([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(videoUrl);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }
}
