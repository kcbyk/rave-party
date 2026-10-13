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
}
