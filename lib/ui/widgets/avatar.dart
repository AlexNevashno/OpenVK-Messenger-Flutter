import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/image_cache_manager.dart';
import '../theme/colors.dart';

class VKAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final bool isOnline;
  final bool isMobile;
  final bool isSavedMessages;
  final VoidCallback? onTap;

  const VKAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = 48,
    this.isOnline = false,
    this.isMobile = false,
    this.isSavedMessages = false,
    this.onTap,
  });

  String _getInitials(String str) {
    final parts = str.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _getDeterministicColor(String str) {
    final colors = [
      const Color(0xFFE64646), // Red
      const Color(0xFFF27B13), // Orange
      const Color(0xFFE2A000), // Yellow
      const Color(0xFF4BB34B), // Green
      const Color(0xFF00A2E8), // Cyan
      const Color(0xFF2D81E0), // Blue
      const Color(0xFF8B51E3), // Purple
      const Color(0xFFE84393), // Pink
    ];
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget;

    if (isSavedMessages) {
      avatarWidget = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF529EF4), Color(0xFF2A6CD2)],
          ),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.bookmark_rounded,
          color: Colors.white,
          size: size * 0.52,
        ),
      );
    } else {
      final validUrl = url != null && url!.isNotEmpty && !url!.contains('camera_');
      if (validUrl) {
        final cacheDim = (size * 2).clamp(32, 256).toInt();
        avatarWidget = CachedNetworkImage(
          imageUrl: url!,
          cacheManager: VKImageCacheManager.instance,
          width: size,
          height: size,
          memCacheWidth: cacheDim,
          memCacheHeight: cacheDim,
          fit: BoxFit.cover,
          placeholder: (ctx, _) => Container(
            width: size,
            height: size,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          errorWidget: (ctx, _, err) => _buildInitials(),
        );
      } else {
        avatarWidget = _buildInitials();
      }
    }

    Widget content = ClipOval(child: avatarWidget);

    if (isOnline && !isSavedMessages) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned(
            right: 0,
            bottom: 0,
            child: isMobile ? _buildMobileBadge() : _buildDotBadge(),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }

  Widget _buildInitials() {
    final bgColor = _getDeterministicColor(name);
    return Container(
      width: size,
      height: size,
      color: bgColor,
      alignment: Alignment.center,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDotBadge() {
    final badgeSize = size * 0.28;
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: VKColors.onlineGreen,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF222223),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildMobileBadge() {
    final badgeSize = size * 0.32;
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: VKColors.onlineGreen,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF222223),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.phone_android,
        size: badgeSize * 0.65,
        color: Colors.white,
      ),
    );
  }
}
