import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// MemoryManager enforces strict RAM constraints (target: 150-200 MB max)
/// by configuring Flutter's engine image caches, evicting stale decoded bitmaps,
/// and maintaining periodic cleanup cycles.
class MemoryManager {
  static final MemoryManager instance = MemoryManager._internal();
  MemoryManager._internal();

  Timer? _cleanupTimer;
  bool _initialized = false;

  /// Max image cache size in bytes (40 MB)
  static const int kMaxImageCacheBytes = 40 * 1024 * 1024;

  /// Max number of raster image objects retained in memory
  static const int kMaxImageCacheCount = 60;

  void init() {
    if (_initialized) return;
    _initialized = true;

    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.maximumSizeBytes = kMaxImageCacheBytes;
      cache.maximumSize = kMaxImageCacheCount;

      debugPrint('[MemoryManager] Enforced RAM limits: max ${kMaxImageCacheBytes ~/ (1024 * 1024)}MB / $kMaxImageCacheCount images in imageCache');
    } catch (e) {
      debugPrint('[MemoryManager] Error initializing imageCache limits: $e');
    }

    // Run periodic cleanup every 45 seconds to evict unreferenced textures
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      trimMemory();
    });
  }

  /// Trims unused image bitmaps and live textures from RAM
  void trimMemory() {
    try {
      final cache = PaintingBinding.instance.imageCache;
      // Discard unreferenced live images
      cache.clearLiveImages();
      
      // If current cache size exceeds 30MB, clear stale entries
      if (cache.currentSizeBytes > 30 * 1024 * 1024) {
        cache.clear();
      }
      
      debugPrint('[MemoryManager] Trimmed memory. Current imageCache: ${(cache.currentSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB (${cache.currentSize} images)');
    } catch (e) {
      debugPrint('[MemoryManager] trimMemory error: $e');
    }
  }

  /// Complete cache purge (invoked from Settings)
  void purgeAllMemoryCaches() {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      debugPrint('[MemoryManager] All memory caches completely purged.');
    } catch (e) {
      debugPrint('[MemoryManager] purgeAllMemoryCaches error: $e');
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
}
