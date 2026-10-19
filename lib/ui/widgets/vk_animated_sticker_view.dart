import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../services/image_cache_manager.dart';
import '../../services/theme_manager.dart';

/// Reusable widget for rendering OpenVK animated stickers with Lottie,
/// with disk caching and smooth fallback to static PNG if the sticker has no animation or fails to load.
class VKAnimatedStickerView extends StatelessWidget {
  final String? url;
  final String? animationUrl;
  final double size;
  final bool loop;

  const VKAnimatedStickerView({
    super.key,
    this.url,
    this.animationUrl,
    this.size = 140,
    this.loop = true,
  });

  @override
  Widget build(BuildContext context) {
    if (animationUrl != null && animationUrl!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Lottie.network(
          animationUrl!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          repeat: loop,
          animate: loop,
          frameBuilder: (context, child, composition) {
            if (composition == null) {
              return _buildStaticImage(context);
            }
            return child;
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildStaticImage(context);
          },
        ),
      );
    }

    return _buildStaticImage(context);
  }

  Widget _buildStaticImage(BuildContext context) {
    final theme = ThemeManager.instance;
    final validUrl = url != null && url!.isNotEmpty ? url! : '';

    if (validUrl.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: validUrl,
          cacheManager: VKImageCacheManager.instance,
          width: size,
          height: size,
          memCacheWidth: (size * 2).clamp(64, 512).toInt(),
          memCacheHeight: (size * 2).clamp(64, 512).toInt(),
          fit: BoxFit.contain,
          placeholder: (ctx, u) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: theme.getSecondarySurfaceColor(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          errorWidget: (ctx, u, err) => Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: (size * 0.4).clamp(20.0, 48.0),
              color: theme.getSecondaryTextColor(context),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          Icons.sentiment_satisfied_outlined,
          size: (size * 0.4).clamp(20.0, 48.0),
          color: theme.getSecondaryTextColor(context),
        ),
      ),
    );
  }
}
