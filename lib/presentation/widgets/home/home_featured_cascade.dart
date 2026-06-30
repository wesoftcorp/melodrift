import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/entities/album.dart';
import '../../screens/details_screen.dart';

class HomeFeaturedCascade extends StatefulWidget {
  final List<Album> items;

  const HomeFeaturedCascade({required this.items});

  @override
  State<HomeFeaturedCascade> createState() => HomeFeaturedCascadeState();
}

class HomeFeaturedCascadeState extends State<HomeFeaturedCascade> {
  int _currentPage = 0;
  Timer? _timer;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (widget.items.isEmpty) return;
      setState(() {
        _currentPage = (_currentPage + 1) % widget.items.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final cardSize = width > 700 ? 240.0 : (width * 0.58).clamp(188.0, 230.0);
    final sideSize = cardSize * 0.72;
    final sideOffset = cardSize * 0.58;
    final leftIndex = _circularIndex(_currentPage - 1);
    final rightIndex = _circularIndex(_currentPage + 1);
    final farLeftIndex = _circularIndex(_currentPage - 2);
    final farRightIndex = _circularIndex(_currentPage + 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _timer?.cancel(),
          onHorizontalDragUpdate: (details) => _dragDx += details.primaryDelta ?? 0,
          onHorizontalDragEnd: (_) {
            if (_dragDx.abs() > 36) {
              _rotate(_dragDx < 0 ? 1 : -1);
            }
            _dragDx = 0;
            _startTimer();
          },
          child: SizedBox(
            height: cardSize + 54,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                if (widget.items.length > 3)
                  Positioned(
                    top: cardSize * 0.27,
                    child: Transform.translate(
                      offset: Offset(-sideOffset * 1.58, 0),
                      child: _CascadeTile(
                        album: widget.items[farLeftIndex],
                        size: sideSize * 0.82,
                        opacity: 0.28,
                        onTap: () => _setPage(farLeftIndex),
                      ),
                    ),
                  ),
                if (widget.items.length > 1)
                  Positioned(
                    top: cardSize * 0.18,
                    child: Transform.translate(
                      offset: Offset(-sideOffset, 0),
                      child: _CascadeTile(
                        album: widget.items[leftIndex],
                        size: sideSize,
                        opacity: 0.58,
                        onTap: () => _setPage(leftIndex),
                      ),
                    ),
                  ),
                if (widget.items.length > 4)
                  Positioned(
                    top: cardSize * 0.27,
                    child: Transform.translate(
                      offset: Offset(sideOffset * 1.58, 0),
                      child: _CascadeTile(
                        album: widget.items[farRightIndex],
                        size: sideSize * 0.82,
                        opacity: 0.28,
                        onTap: () => _setPage(farRightIndex),
                      ),
                    ),
                  ),
                if (widget.items.length > 2)
                  Positioned(
                    top: cardSize * 0.18,
                    child: Transform.translate(
                      offset: Offset(sideOffset, 0),
                      child: _CascadeTile(
                        album: widget.items[rightIndex],
                        size: sideSize,
                        opacity: 0.58,
                        onTap: () => _setPage(rightIndex),
                      ),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _CascadeTile(
                    key: ValueKey(widget.items[_currentPage].id),
                    album: widget.items[_currentPage],
                    size: cardSize,
                    opacity: 1,
                    showDetails: true,
                    onTap: () => _openDetails(
                      context,
                      DetailsScreen(
                        id: widget.items[_currentPage].id,
                        title: widget.items[_currentPage].title,
                        artworkUrl: widget.items[_currentPage].artworkUrl,
                        type: 'album',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: _currentPage == index ? 16 : 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _circularIndex(int index) => (index % widget.items.length + widget.items.length) % widget.items.length;

  void _rotate(int delta) => _setPage(_circularIndex(_currentPage + delta));

  void _setPage(int index) {
    if (!mounted || widget.items.isEmpty) return;
    setState(() {
      _currentPage = _circularIndex(index);
    });
  }
}

class _CascadeTile extends StatelessWidget {
  final Album album;
  final double size;
  final double opacity;
  final bool showDetails;
  final VoidCallback onTap;

  const _CascadeTile({
    required this.album,
    required this.size,
    required this.opacity,
    required this.onTap,
    this.showDetails = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(showDetails ? 0.35 : 0.18),
                blurRadius: showDetails ? 22 : 12,
                offset: Offset(0, showDetails ? 12 : 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                album.artworkUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: album.artworkUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.music_note, size: 56),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.music_note, size: 56),
                      ),
                if (showDetails)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.12),
                          Colors.black.withOpacity(0.82),
                        ],
                      ),
                    ),
                  ),
                if (showDetails)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'FEATURED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getSourceColor(album.source).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _getSourceColor(album.source).withOpacity(0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                _getSourceEmoji(album.source),
                                style: TextStyle(
                                  color: _getSourceColor(album.source),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          album.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (album.artist.isNotEmpty)
                          Text(
                            album.artist,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSourceEmoji(String source) {
    switch (source) {
      case 'Spotify':
        return '💚'; // Green heart for Spotify
      case 'SoundCloud':
        return '💜'; // Purple heart for SoundCloud
      case 'JioSaavn':
        return '💛'; // Yellow heart for JioSaavn
      default:
        return '❤️'; // Red heart for YouTube Music
    }
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'Spotify':
        return const Color(0xFF1DB954); // Spotify green
      case 'SoundCloud':
        return const Color(0xFFAA00FF); // SoundCloud purple
      case 'JioSaavn':
        return Colors.amberAccent; // JioSaavn yellow
      default:
        return Colors.redAccent;
    }
  }
}



void _openDetails(BuildContext context, Widget screen) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}
