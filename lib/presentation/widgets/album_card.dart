import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/album.dart';
import 'item_details_sheet.dart';

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
        ItemDetailsSheet.show(
          context,
          id: album.id,
          title: album.title,
          artworkUrl: album.artworkUrl,
          type: 'album',
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
            Text(
              album.title,
              style: theme.textTheme.labelLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              album.artist,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
