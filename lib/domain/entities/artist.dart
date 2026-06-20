class Artist {
  final String id;
  final String name;
  final String artworkUrl;
  final String? subscribers;
  final bool isVerified;

  const Artist({
    required this.id,
    required this.name,
    required this.artworkUrl,
    this.subscribers,
    this.isVerified = false,
  });
}
