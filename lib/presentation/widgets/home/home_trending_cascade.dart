import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../domain/entities/song.dart';

class HomeTrendingCascade extends StatefulWidget {
  final List<Song> songs;
  final ValueChanged<Song> onSongTap;

  const HomeTrendingCascade({required this.songs, required this.onSongTap, super.key});

  @override
  State<HomeTrendingCascade> createState() => HomeTrendingCascadeState();
}

class HomeTrendingCascadeState extends State<HomeTrendingCascade> {
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
      if (widget.songs.isEmpty) return;
      setState(() {
        _currentPage = (_currentPage + 1) % widget.songs.length;
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
    if (widget.songs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final cardSize = width > 700 ? 240.0 : (width * 0.58).clamp(188.0, 230.0);
    final sideSize = cardSize * 0.72;
    final sideOffset = cardSize * 0.58;
    final leftIndex = _tcCircularIndex(_currentPage - 1);
    final rightIndex = _tcCircularIndex(_currentPage + 1);
    final farLeftIndex = _tcCircularIndex(_currentPage - 2);
    final farRightIndex = _tcCircularIndex(_currentPage + 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _timer?.cancel(),
          onHorizontalDragUpdate: (details) =>
              _dragDx += details.primaryDelta ?? 0,
          onHorizontalDragEnd: (_) {
            if (_dragDx.abs() > 36) {
              _tcRotate(_dragDx < 0 ? 1 : -1);
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
                if (widget.songs.length > 3)
                  Positioned(
                    top: cardSize * 0.27,
                    child: Transform.translate(
                      offset: Offset(-sideOffset * 1.58, 0),
                      child: HomeTrendingCascadeTile(
                        song: widget.songs[farLeftIndex],
                        size: sideSize * 0.82,
                        opacity: 0.28,
                        onTap: () => _tcSetPage(farLeftIndex),
                      ),
                    ),
                  ),
                if (widget.songs.length > 1)
                  Positioned(
                    top: cardSize * 0.18,
                    child: Transform.translate(
                      offset: Offset(-sideOffset, 0),
                      child: HomeTrendingCascadeTile(
                        song: widget.songs[leftIndex],
                        size: sideSize,
                        opacity: 0.58,
                        onTap: () => _tcSetPage(leftIndex),
                      ),
                    ),
                  ),
                if (widget.songs.length > 4)
                  Positioned(
                    top: cardSize * 0.27,
                    child: Transform.translate(
                      offset: Offset(sideOffset * 1.58, 0),
                      child: HomeTrendingCascadeTile(
                        song: widget.songs[farRightIndex],
                        size: sideSize * 0.82,
                        opacity: 0.28,
                        onTap: () => _tcSetPage(farRightIndex),
                      ),
                    ),
                  ),
                if (widget.songs.length > 2)
                  Positioned(
                    top: cardSize * 0.18,
                    child: Transform.translate(
                      offset: Offset(sideOffset, 0),
                      child: HomeTrendingCascadeTile(
                        song: widget.songs[rightIndex],
                        size: sideSize,
                        opacity: 0.58,
                        onTap: () => _tcSetPage(rightIndex),
                      ),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: HomeTrendingCascadeTile(
                    key: ValueKey(widget.songs[_currentPage].id),
                    song: widget.songs[_currentPage],
                    size: cardSize,
                    opacity: 1,
                    showDetails: true,
                    onTap: () => widget.onSongTap(widget.songs[_currentPage]),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.songs.length,
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

  int _tcCircularIndex(int index) =>
      (index % widget.songs.length + widget.songs.length) % widget.songs.length;

  void _tcRotate(int delta) => _tcSetPage(_tcCircularIndex(_currentPage + delta));

  void _tcSetPage(int index) {
    if (!mounted || widget.songs.isEmpty) return;
    setState(() {
      _currentPage = _tcCircularIndex(index);
    });
  }
}

class HomeTrendingCascadeTile extends StatelessWidget {
  final Song song;
  final double size;
  final double opacity;
  final bool showDetails;
  final VoidCallback onTap;

  const HomeTrendingCascadeTile({
    required this.song,
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
                song.artworkUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: song.artworkUrl,
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'TRENDING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: _getSourceColor(song.source),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _getSourceColor(song.source).withOpacity(0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          song.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (song.artist.isNotEmpty)
                          Text(
                            song.artist,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
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

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'jiosaavn':
        return const Color(0xFF00E676); // JioSaavn Green Dot
      case 'spotify':
        return const Color(0xFF1DB954);
      case 'soundcloud':
        return const Color(0xFF9B5DE5);
      default:
        return const Color(0xFFFF3333); // YouTube Music Red Dot
    }
  }

}

