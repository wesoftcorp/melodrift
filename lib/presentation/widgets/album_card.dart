import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_route/auto_route.dart';
import '../../domain/entities/album.dart';
import '../../app/router/app_router.gr.dart';

class AlbumCard extends StatelessWidget {
  final Album album;
  final double size;
  final bool isGrid;

  const AlbumCard({
    required this.album,
    this.size = 120.0,
    this.isGrid = false,
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
            preloadedSongs: album.tracks.isNotEmpty ? album.tracks : null,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: isGrid ? double.infinity : size,
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Album Cover Artwork ──────────────────────────────────
            isGrid
                ? AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: album.artworkUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        memCacheHeight: 400,
                        errorWidget: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.album, size: 48),
                        ),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: album.artworkUrl,
                      width: size,
                      height: size,
                      memCacheWidth: (size * 2).toInt(),
                      memCacheHeight: (size * 2).toInt(),
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
            // ── Album Title & Artist Info ─────────────────────────────
            Container(
              width: isGrid ? double.infinity : size,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh.withAlpha(180),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(80),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.artist,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
