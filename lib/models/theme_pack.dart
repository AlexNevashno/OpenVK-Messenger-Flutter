import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class VKThemePack {
  final String id;
  final String name;
  final String author;
  final String baseTheme; // "classic", "day", "tinted", "night"

  // Core Interface Colors
  final Color accentColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color secondarySurfaceColor;
  final Color separatorColor;

  // Message Bubbles
  final Color bubbleIncomingColor;
  final Color bubbleOutgoingColor;
  final Color bubbleIncomingTextColor;
  final Color bubbleOutgoingTextColor;
  final Color? bubbleStrokeColor;
  final double bubbleStrokeWidth;

  // Chat Wallpaper
  final String wallpaperPattern; // "none", "telegram_doodles", "custom"
  final String? wallpaperPath;
  final String? wallpaperBase64;
  final double wallpaperOpacity;
  final double wallpaperBlur;

  Uint8List? _cachedWallpaperBytes;

  VKThemePack({
    required this.id,
    required this.name,
    this.author = 'OpenVK User',
    this.baseTheme = 'night',
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.secondarySurfaceColor,
    required this.separatorColor,
    required this.bubbleIncomingColor,
    required this.bubbleOutgoingColor,
    this.bubbleIncomingTextColor = Colors.white,
    this.bubbleOutgoingTextColor = Colors.white,
    this.bubbleStrokeColor,
    this.bubbleStrokeWidth = 0.8,
    this.wallpaperPattern = 'none',
    this.wallpaperPath,
    this.wallpaperBase64,
    this.wallpaperOpacity = 0.9,
    this.wallpaperBlur = 0.0,
    Uint8List? cachedWallpaperBytes,
  }) {
    if (cachedWallpaperBytes != null) {
      _cachedWallpaperBytes = cachedWallpaperBytes;
    }
  }

  Uint8List? get wallpaperBytes {
    if (_cachedWallpaperBytes != null) return _cachedWallpaperBytes;
    if (wallpaperBase64 != null && wallpaperBase64!.isNotEmpty) {
      try {
        _cachedWallpaperBytes = base64Decode(wallpaperBase64!);
      } catch (_) {}
    }
    return _cachedWallpaperBytes;
  }

  VKThemePack copyWith({
    String? id,
    String? name,
    String? author,
    String? baseTheme,
    Color? accentColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? secondarySurfaceColor,
    Color? separatorColor,
    Color? bubbleIncomingColor,
    Color? bubbleOutgoingColor,
    Color? bubbleIncomingTextColor,
    Color? bubbleOutgoingTextColor,
    Color? bubbleStrokeColor,
    bool clearBubbleStrokeColor = false,
    double? bubbleStrokeWidth,
    String? wallpaperPattern,
    String? wallpaperPath,
    String? wallpaperBase64,
    double? wallpaperOpacity,
    double? wallpaperBlur,
    Uint8List? cachedWallpaperBytes,
  }) {
    return VKThemePack(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      baseTheme: baseTheme ?? this.baseTheme,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      secondarySurfaceColor: secondarySurfaceColor ?? this.secondarySurfaceColor,
      separatorColor: separatorColor ?? this.separatorColor,
      bubbleIncomingColor: bubbleIncomingColor ?? this.bubbleIncomingColor,
      bubbleOutgoingColor: bubbleOutgoingColor ?? this.bubbleOutgoingColor,
      bubbleIncomingTextColor: bubbleIncomingTextColor ?? this.bubbleIncomingTextColor,
      bubbleOutgoingTextColor: bubbleOutgoingTextColor ?? this.bubbleOutgoingTextColor,
      bubbleStrokeColor: clearBubbleStrokeColor ? null : (bubbleStrokeColor ?? this.bubbleStrokeColor),
      bubbleStrokeWidth: bubbleStrokeWidth ?? this.bubbleStrokeWidth,
      wallpaperPattern: wallpaperPattern ?? this.wallpaperPattern,
      wallpaperPath: wallpaperPath ?? this.wallpaperPath,
      wallpaperBase64: wallpaperBase64 ?? this.wallpaperBase64,
      wallpaperOpacity: wallpaperOpacity ?? this.wallpaperOpacity,
      wallpaperBlur: wallpaperBlur ?? this.wallpaperBlur,
      cachedWallpaperBytes: cachedWallpaperBytes ?? _cachedWallpaperBytes,
    );
  }

  bool get isDark => baseTheme == 'night' || baseTheme == 'tinted';

  Color get chatBg => backgroundColor;
  Color get headerBg => surfaceColor;
  Color get bubbleInBg => bubbleIncomingColor;
  Color get bubbleOutBg => bubbleOutgoingColor;
  Color get bubbleInText => bubbleIncomingTextColor;
  Color get bubbleOutText => bubbleOutgoingTextColor;

  // MARK: - Built-in Presets from Mac Swift App
  static final VKThemePack telegramDark = VKThemePack(
    id: 'preset_telegram_dark',
    name: 'Telegram Dark',
    author: 'Telegram Design',
    baseTheme: 'night',
    accentColor: const Color(0xFFE25241),
    backgroundColor: const Color(0xFF1E2721),
    surfaceColor: const Color(0xFF242424),
    secondarySurfaceColor: const Color(0xFF2E2E2E),
    separatorColor: const Color(0xFF383838),
    bubbleIncomingColor: const Color(0xFF333333),
    bubbleOutgoingColor: const Color(0xFF463F38),
    bubbleIncomingTextColor: Colors.white,
    bubbleOutgoingTextColor: Colors.white,
    bubbleStrokeColor: const Color(0xFF3D3833),
    bubbleStrokeWidth: 0.8,
    wallpaperPattern: 'telegram_doodles',
    wallpaperOpacity: 0.92,
  );

  static final VKThemePack classicVK = VKThemePack(
    id: 'preset_classic_vk',
    name: 'Классический ВКонтакте',
    author: 'VK UI Design',
    baseTheme: 'classic',
    accentColor: const Color(0xFF2D81E0),
    backgroundColor: const Color(0xFFF0F1F4),
    surfaceColor: const Color(0xFFFFFFFF),
    secondarySurfaceColor: const Color(0xFFF2F3F5),
    separatorColor: const Color(0xFFE1E3E6),
    bubbleIncomingColor: const Color(0xFFFFFFFF),
    bubbleOutgoingColor: const Color(0xFFCCE4FF),
    bubbleIncomingTextColor: Colors.black,
    bubbleOutgoingTextColor: Colors.black,
    bubbleStrokeColor: const Color(0xFFDCE1E6),
    bubbleStrokeWidth: 0.8,
    wallpaperPattern: 'none',
    wallpaperOpacity: 1.0,
  );

  static final VKThemePack telegramDay = VKThemePack(
    id: 'preset_telegram_day',
    name: 'Telegram Day',
    author: 'Telegram Design',
    baseTheme: 'day',
    accentColor: const Color(0xFF3390EC),
    backgroundColor: const Color(0xFFD5E3CD),
    surfaceColor: const Color(0xFFFFFFFF),
    secondarySurfaceColor: const Color(0xFFF4F4F5),
    separatorColor: const Color(0xFFE4E4E6),
    bubbleIncomingColor: const Color(0xFFFFFFFF),
    bubbleOutgoingColor: const Color(0xFFEEFFDE),
    bubbleIncomingTextColor: Colors.black,
    bubbleOutgoingTextColor: Colors.black,
    bubbleStrokeColor: const Color(0xFFD8E4D0),
    bubbleStrokeWidth: 0.8,
    wallpaperPattern: 'telegram_doodles',
    wallpaperOpacity: 0.85,
  );

  static final VKThemePack tintedNavy = VKThemePack(
    id: 'preset_tinted_navy',
    name: 'Глубокий индиго',
    author: 'OpenVK Studio',
    baseTheme: 'tinted',
    accentColor: const Color(0xFF5288C1),
    backgroundColor: const Color(0xFF0E1621),
    surfaceColor: const Color(0xFF17212B),
    secondarySurfaceColor: const Color(0xFF202B36),
    separatorColor: const Color(0xFF242F3D),
    bubbleIncomingColor: const Color(0xFF182533),
    bubbleOutgoingColor: const Color(0xFF2B5278),
    bubbleIncomingTextColor: Colors.white,
    bubbleOutgoingTextColor: Colors.white,
    bubbleStrokeColor: const Color(0xFF203347),
    bubbleStrokeWidth: 0.8,
    wallpaperPattern: 'none',
  );

  static final VKThemePack cyberpunkNeon = VKThemePack(
    id: 'preset_cyberpunk',
    name: 'Киберпанк Неон',
    author: 'Cyberpunk 2077',
    baseTheme: 'night',
    accentColor: const Color(0xFFFF007F),
    backgroundColor: const Color(0xFF0B0C10),
    surfaceColor: const Color(0xFF1F2833),
    secondarySurfaceColor: const Color(0xFF2C3539),
    separatorColor: const Color(0xFF45A29E),
    bubbleIncomingColor: const Color(0xFF1F2833),
    bubbleOutgoingColor: const Color(0xFF6F2232),
    bubbleIncomingTextColor: const Color(0xFFE0F2F1),
    bubbleOutgoingTextColor: Colors.white,
    bubbleStrokeColor: const Color(0xFFFF007F),
    bubbleStrokeWidth: 1.2,
    wallpaperPattern: 'none',
  );

  static final VKThemePack emeraldForest = VKThemePack(
    id: 'preset_emerald_forest',
    name: 'Изумрудный лес',
    author: 'Nordic Green',
    baseTheme: 'night',
    accentColor: const Color(0xFF2ECC71),
    backgroundColor: const Color(0xFF0E1A14),
    surfaceColor: const Color(0xFF16281F),
    secondarySurfaceColor: const Color(0xFF1D3529),
    separatorColor: const Color(0xFF264435),
    bubbleIncomingColor: const Color(0xFF182C22),
    bubbleOutgoingColor: const Color(0xFF234C37),
    bubbleIncomingTextColor: Colors.white,
    bubbleOutgoingTextColor: Colors.white,
    bubbleStrokeColor: const Color(0xFF2E5A44),
    bubbleStrokeWidth: 0.8,
    wallpaperPattern: 'none',
  );

  static final List<VKThemePack> allPresets = [
    telegramDark,
    classicVK,
    telegramDay,
    tintedNavy,
    emeraldForest,
    cyberpunkNeon,
  ];

  static Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    String clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    final val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : fallback;
  }

  static String _colorToHex(Color color) {
    final hex8 = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    if (hex8.startsWith('FF')) {
      return '#${hex8.substring(2)}';
    }
    return '#$hex8';
  }

  factory VKThemePack.fromJson(Map<String, dynamic> json) {
    return VKThemePack(
      id: json['id']?.toString() ?? 'custom',
      name: json['name']?.toString() ?? 'Пользовательская тема',
      author: json['author']?.toString() ?? 'OpenVK User',
      baseTheme: json['baseTheme']?.toString() ?? json['base']?.toString() ?? 'night',
      accentColor: _parseHex(json['accentHex'] ?? json['accent'], const Color(0xFF5181B8)),
      backgroundColor: _parseHex(json['backgroundHex'] ?? json['background'], const Color(0xFF19191A)),
      surfaceColor: _parseHex(json['surfaceHex'] ?? json['surface'], const Color(0xFF232324)),
      secondarySurfaceColor: _parseHex(json['secondarySurfaceHex'] ?? json['secondary_surface'], const Color(0xFF2E2E2E)),
      separatorColor: _parseHex(json['separatorHex'] ?? json['separator'], const Color(0xFF383838)),
      bubbleIncomingColor: _parseHex(json['bubbleIncomingHex'] ?? json['bubble_incoming'], const Color(0xFF2C2D2E)),
      bubbleOutgoingColor: _parseHex(json['bubbleOutgoingHex'] ?? json['bubble_outgoing'], const Color(0xFF5181B8)),
      bubbleIncomingTextColor: _parseHex(json['bubbleIncomingTextHex'] ?? json['bubble_incoming_text'], Colors.white),
      bubbleOutgoingTextColor: _parseHex(json['bubbleOutgoingTextHex'] ?? json['bubble_outgoing_text'], Colors.white),
      bubbleStrokeColor: json['bubbleStrokeHex'] != null ? _parseHex(json['bubbleStrokeHex'], Colors.transparent) : null,
      bubbleStrokeWidth: (json['bubbleStrokeWidth'] as num?)?.toDouble() ?? 0.8,
      wallpaperPattern: json['wallpaperPattern']?.toString() ?? 'none',
      wallpaperPath: json['wallpaperPath']?.toString() ?? json['wallpaper_path']?.toString(),
      wallpaperBase64: json['wallpaperBase64']?.toString() ?? json['wallpaper_base64']?.toString(),
      wallpaperOpacity: (json['wallpaperOpacity'] as num?)?.toDouble() ?? 0.9,
      wallpaperBlur: (json['wallpaperBlur'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author': author,
        'baseTheme': baseTheme,
        'accentHex': _colorToHex(accentColor),
        'backgroundHex': _colorToHex(backgroundColor),
        'surfaceHex': _colorToHex(surfaceColor),
        'secondarySurfaceHex': _colorToHex(secondarySurfaceColor),
        'separatorHex': _colorToHex(separatorColor),
        'bubbleIncomingHex': _colorToHex(bubbleIncomingColor),
        'bubbleOutgoingHex': _colorToHex(bubbleOutgoingColor),
        'bubbleIncomingTextHex': _colorToHex(bubbleIncomingTextColor),
        'bubbleOutgoingTextHex': _colorToHex(bubbleOutgoingTextColor),
        'bubbleStrokeHex': bubbleStrokeColor != null ? _colorToHex(bubbleStrokeColor!) : null,
        'bubbleStrokeWidth': bubbleStrokeWidth,
        'wallpaperPattern': wallpaperPattern,
        'wallpaperPath': wallpaperPath,
        'wallpaperBase64': wallpaperBase64,
        'wallpaperOpacity': wallpaperOpacity,
        'wallpaperBlur': wallpaperBlur,
      };
}
