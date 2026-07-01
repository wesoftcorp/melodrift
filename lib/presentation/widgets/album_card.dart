import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_route/auto_route.dart';
import '../../domain/entities/album.dart';
import '../../app/router/app_router.gr.dart';

class AlbumCard extends StatelessWidget {
  final Album album;
  final double size;

  const AlbumCard({
    required this.album,
    this.size = 120.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        context.router.push(
          DetailsRoute(
            id: album.id,
            title: album.title,
            artworkUrl: album.artworkUrl,
            type: 'album',
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: album.artworkUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: size,
                  height: size,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.album, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: size,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh.withAlpha(200),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(100),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    style: theme.textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _getSourceColor(album.source).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getSourceColor(album.source).withOpacity(0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          _getSourceText(album.source),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getSourceColor(album.source),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          album.artist,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  String _getSourceText(String source) {
    switch (source.toLowerCase()) {
      case 'jiosaavn':
        return 'JioSaavn';
      case 'spotify':
        return 'Spotify';
      case 'soundcloud':
        return 'SoundCloud';
      default:
        return 'YT Music';
    }
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'jiosaavn':
        return Colors.amberAccent; // Amber Gold Accent
      case 'spotify':
        return const Color(0xFF1DB954); // Spotify Green
      case 'soundcloud':
        return const Color(0xFF9B5DE5); // SoundCloud Purple
      default:
        return Colors.redAccent; // YouTube Music Red
    }
  }
}


