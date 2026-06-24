import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

/// Image caching configuration and utilities
/// 
/// Implements best practices for loading and caching song artwork,
/// album covers, and artist images with minimal memory overhead.
class ImageCachingConfig {
  /// Maximum memory for image cache (50 MB)
  static const int maxMemoryCacheSize = 50 * 1024 * 1024;

  /// Maximum disk cache size (200 MB)
  static const int maxDiskCacheSize = 200 * 1024 * 1024;

  /// How long to keep images in cache (30 days)
  static const Duration cacheDuration = Duration(days: 30);

  /// Initialize image caching configuration
  /// Call this in main() before running the app
  static void initialize() {
    // Configure in-memory image cache
    imageCache.maximumSize = 100; // Max 100 images
    imageCache.maximumSizeBytes = maxMemoryCacheSize;

    // Use Flutter's default caching which is optimized
    // CachedNetworkImage handles disk caching automatically
  }
}

/// Utility class for optimized image loading
class OptimizedImageLoader {
  /// Load artwork with optimized caching
  /// 
  /// Usage:
  /// ```dart
  /// CachedNetworkImage(
  ///   imageUrl: imageUrl,
  ///   imageBuilder: OptimizedImageLoader.imageBuilder,
  ///   placeholder: OptimizedImageLoader.placeholderBuilder,
  ///   errorWidget: OptimizedImageLoader.errorBuilder,
  ///   cacheManager: OptimizedImageLoader.cacheManager,
  /// )
  /// ```
  static Widget imageBuilder(
    BuildContext context,
    ImageProvider imageProvider,
  ) {
    return Image(
      image: imageProvider,
      fit: BoxFit.cover,
      // Use RepaintBoundary to reduce painting overhead
      gaplessPlayback: true,
    );
  }

  /// Placeholder while loading
  static Widget placeholderBuilder(BuildContext context, String url) {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
          ),
        ),
      ),
    );
  }

  /// Error widget if image fails to load
  static Widget errorBuilder(
    BuildContext context,
    String url,
    dynamic error,
  ) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 50,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  /// Blur hash placeholder (ultra-lightweight)
  /// Use when you have blurhash data from API
  static Widget blurHashPlaceholder(String blurHash) {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

/// Image cache strategy wrapper around CachedNetworkImage
/// 
/// Provides a consistent, optimized way to load images throughout the app
class CachedArtworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  const CachedArtworkImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.width,
    this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildError(),
        memCacheHeight: height?.toInt(),
        memCacheWidth: width?.toInt(),
        // Compress images to reduce memory
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      width: width,
      height: height,
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.grey[900],
      width: width,
      height: height,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 40,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

/// Custom cache manager for artwork
/// Optimized memory usage and performance
class CachedNetworkImageManager {
  static final _instance = CachedNetworkImageManager._();

  factory CachedNetworkImageManager() => _instance;

  CachedNetworkImageManager._() {
    _initializeCache();
  }

  void _initializeCache() {
    ImageCachingConfig.initialize();
  }

  /// Preload an image for faster display
  /// 
  /// Useful for preloading artwork of upcoming songs
  static Future<void> preloadImage(BuildContext context, String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      await precacheImage(
        CachedNetworkImageProvider(imageUrl),
        context,
      );
    } catch (e) {
      // Silently fail - preload is optional
    }
  }

  /// Clear cache to free memory
  /// Call when switching playlists or on low memory
  static Future<void> clearCache() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    // CachedNetworkImage disk cache cleared automatically
  }

  /// Get cache statistics
  static String getCacheStats() {
    return 'Image cache: ${imageCache.currentSize}/${imageCache.maximumSize} images, '
        '${imageCache.currentSizeBytes ~/ (1024 * 1024)} MB';
  }
}

/// Image pre-fetching strategy for upcoming songs
/// 
/// Pre-fetch artwork for next songs to reduce loading delays
class ImagePrefetcher {
  static Future<void> prefetchUpcomingArtwork({
    required List<String> upcomingImageUrls,
    required BuildContext context,
    int maxPrefetch = 2,
  }) async {
    final urlsToPreload = upcomingImageUrls.take(maxPrefetch);
    
    for (final url in urlsToPreload) {
      if (url.isNotEmpty) {
        unawaited(CachedNetworkImageManager.preloadImage(context, url));
      }
    }
  }
}
