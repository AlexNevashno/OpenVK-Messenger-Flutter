import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/theme_manager.dart';

class ChatWallpaperBackground extends StatelessWidget {
  final Widget? child;

  const ChatWallpaperBackground({
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeManager>();
    final bgColor = theme.getBackgroundColor(context);
    final pattern = theme.wallpaperPattern;
    final opacity = theme.wallpaperOpacity;
    final blur = theme.wallpaperBlur;
    final imageProvider = theme.wallpaperImageProvider;

    Widget backgroundContent;

    if (imageProvider != null && pattern != 'none') {
      backgroundContent = RepaintBoundary(
        child: Container(
          color: bgColor,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Image(
              image: imageProvider,
              fit: BoxFit.cover,
              repeat: pattern == 'telegram_doodles' ? ImageRepeat.repeat : ImageRepeat.noRepeat,
              gaplessPlayback: true,
              errorBuilder: (ctx, err, stack) => const SizedBox(),
            ),
          ),
        ),
      );
    } else {
      backgroundContent = Container(color: bgColor);
    }

    if (blur > 0.5) {
      backgroundContent = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: backgroundContent,
      );
    }

    if (child == null) return backgroundContent;

    return Stack(
      fit: StackFit.expand,
      children: [
        backgroundContent,
        child!,
      ],
    );
  }
}
