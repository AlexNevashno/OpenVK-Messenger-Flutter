import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Persistent disk and memory cache manager for OpenVK stickers, avatars and media
class VKImageCacheManager {
  static const String key = 'openvk_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 4000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
