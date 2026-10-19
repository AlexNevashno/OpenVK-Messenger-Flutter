import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_pack.dart';

enum AppThemeMode {
  system,
  light,
  dark,
  amoled,
}

class ThemeManager extends ChangeNotifier {
  static final ThemeManager instance = ThemeManager._internal();
  ThemeManager._internal() {
    _loadPreferences();
  }

  AppThemeMode _mode = AppThemeMode.dark;
  AppThemeMode get mode => _mode;

  ImageProvider? _wallpaperImageProvider;
  ImageProvider? get wallpaperImageProvider => _wallpaperImageProvider;

  void _updateWallpaperProvider() {
    if (_customTheme == null) {
      _wallpaperImageProvider = null;
      return;
    }
    if (_customTheme!.wallpaperPattern == 'telegram_doodles') {
      _wallpaperImageProvider = const AssetImage('assets/images/telegram_doodles.png');
      return;
    }
    final bytes = _customTheme!.wallpaperBytes;
    if (bytes != null && bytes.isNotEmpty) {
      _wallpaperImageProvider = MemoryImage(bytes);
    } else if (_customTheme!.wallpaperPath != null && _customTheme!.wallpaperPath!.isNotEmpty) {
      _wallpaperImageProvider = FileImage(File(_customTheme!.wallpaperPath!));
    } else {
      _wallpaperImageProvider = null;
    }
  }

  VKThemePack? _customTheme;
  VKThemePack? get customTheme => _customTheme;

  Color _accentColor = const Color(0xFFE25241); // Telegram dark red accent by default
  Color get accentColor => _customTheme?.accentColor ?? _accentColor;

  double _fontSizeScale = 1.0;
  double get fontSizeScale => _fontSizeScale;

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode') ?? 'dark';
    switch (modeStr) {
      case 'light':
        _mode = AppThemeMode.light;
        break;
      case 'amoled':
        _mode = AppThemeMode.amoled;
        break;
      case 'system':
        _mode = AppThemeMode.system;
        break;
      default:
        _mode = AppThemeMode.dark;
    }

    final customThemeJson = prefs.getString('custom_theme');
    if (customThemeJson != null) {
      try {
        _customTheme = VKThemePack.fromJson(jsonDecode(customThemeJson));
      } catch (_) {}
    } else {
      // Default to Telegram Dark preset if no custom theme set
      _customTheme = VKThemePack.telegramDark;
    }

    final accentHex = prefs.getString('accent_color');
    if (accentHex != null) {
      try {
        _accentColor = Color(int.parse(accentHex, radix: 16));
      } catch (_) {}
    }

    _fontSizeScale = prefs.getDouble('font_scale') ?? 1.0;
    _useSquareBubbles = prefs.getBool('use_square_bubbles') ?? false;
    _updateWallpaperProvider();
    notifyListeners();
  }

  bool _useSquareBubbles = false;
  bool get useSquareBubbles => _useSquareBubbles;
  double get bubbleRadius => _useSquareBubbles ? 3.0 : 10.0;

  BorderRadius getBubbleBorderRadius({bool isOut = false}) {
    if (_useSquareBubbles) {
      return BorderRadius.circular(3.0);
    }
    return BorderRadius.circular(10.0);
  }

  Future<void> setUseSquareBubbles(bool val) async {
    _useSquareBubbles = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_square_bubbles', val);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _mode = mode;
    _customTheme = null;
    _updateWallpaperProvider();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    await prefs.remove('custom_theme');
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_color', color.toARGB32().toRadixString(16));
  }

  Future<void> applyThemePack(VKThemePack pack) async {
    _customTheme = pack;
    _accentColor = pack.accentColor;
    _updateWallpaperProvider();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_theme', jsonEncode(pack.toJson()));
  }

  Future<void> setFontScale(double scale) async {
    _fontSizeScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', scale);
  }

  // Resolved Colors
  bool isDark(BuildContext context) {
    if (_customTheme != null) return _customTheme!.isDark;
    if (_mode == AppThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _mode == AppThemeMode.dark || _mode == AppThemeMode.amoled;
  }

  Color getBackgroundColor(BuildContext context) {
    if (_customTheme?.backgroundColor != null) return _customTheme!.backgroundColor;
    if (_mode == AppThemeMode.amoled) return Colors.black;
    return isDark(context) ? const Color(0xFF1E2721) : const Color(0xFFF0F1F4);
  }

  Color getSurfaceColor(BuildContext context) {
    if (_customTheme?.surfaceColor != null) return _customTheme!.surfaceColor;
    if (_mode == AppThemeMode.amoled) return const Color(0xFF121212);
    return isDark(context) ? const Color(0xFF242424) : Colors.white;
  }

  Color getSecondarySurfaceColor(BuildContext context) {
    if (_customTheme?.secondarySurfaceColor != null) return _customTheme!.secondarySurfaceColor;
    if (_mode == AppThemeMode.amoled) return const Color(0xFF1E1E1E);
    return isDark(context) ? const Color(0xFF2E2E2E) : const Color(0xFFF2F3F5);
  }

  Color getSidebarColor(BuildContext context) {
    return getSurfaceColor(context);
  }

  Color getFoldersSidebarColor(BuildContext context) {
    if (_customTheme?.secondarySurfaceColor != null) return _customTheme!.secondarySurfaceColor;
    return isDark(context) ? const Color(0xFF1E1E1E) : const Color(0xFFE5E7EB);
  }

  Color getSeparatorColor(BuildContext context) {
    if (_customTheme?.separatorColor != null) return _customTheme!.separatorColor;
    return isDark(context) ? const Color(0xFF383838) : const Color(0xFFE1E3E6);
  }

  Color getBubbleInColor(BuildContext context) {
    if (_customTheme?.bubbleIncomingColor != null) return _customTheme!.bubbleIncomingColor;
    if (_mode == AppThemeMode.amoled) return const Color(0xFF1C1C1E);
    return isDark(context) ? const Color(0xFF333333) : Colors.white;
  }

  Color getBubbleOutColor(BuildContext context) {
    if (_customTheme?.bubbleOutgoingColor != null) return _customTheme!.bubbleOutgoingColor;
    return isDark(context) ? const Color(0xFF463F38) : const Color(0xFFCCE4FF);
  }

  Color getBubbleInTextColor(BuildContext context) {
    if (_customTheme?.bubbleIncomingTextColor != null) return _customTheme!.bubbleIncomingTextColor;
    return isDark(context) ? Colors.white : Colors.black;
  }

  Color getBubbleOutTextColor(BuildContext context) {
    if (_customTheme?.bubbleOutgoingTextColor != null) return _customTheme!.bubbleOutgoingTextColor;
    return isDark(context) ? Colors.white : Colors.black;
  }

  Color? getBubbleStrokeColor(BuildContext context) {
    return _customTheme?.bubbleStrokeColor;
  }

  double getBubbleStrokeWidth(BuildContext context) {
    return _customTheme?.bubbleStrokeWidth ?? 0.8;
  }

  Color? get bubbleStrokeColor => _customTheme?.bubbleStrokeColor;
  double get bubbleStrokeWidth => _customTheme?.bubbleStrokeWidth ?? 0.8;

  Color getTextColor(BuildContext context) {
    return isDark(context) ? Colors.white : const Color(0xFF000000);
  }

  Color getSecondaryTextColor(BuildContext context) {
    return isDark(context) ? const Color(0xFF909499) : const Color(0xFF818C99);
  }

  Color textOnColor(Color color) {
    return color.computeLuminance() < 0.52 ? Colors.white : const Color(0xFF19191A);
  }

  Color getAccentColor(BuildContext context) => accentColor;

  Color textOnAccentColor(BuildContext context) {
    return textOnColor(accentColor);
  }

  Future<void> applyCustomTheme(VKThemePack pack) => applyThemePack(pack);

  String get wallpaperPattern => _customTheme?.wallpaperPattern ?? 'telegram_doodles';
  double get wallpaperOpacity => _customTheme?.wallpaperOpacity ?? 0.9;
  double get wallpaperBlur => _customTheme?.wallpaperBlur ?? 0.0;

  Future<void> setCustomWallpaper({String? filePath, String? base64}) async {
    if (_customTheme == null) return;
    final current = _customTheme!;
    final updated = VKThemePack(
      id: current.id,
      name: current.name,
      author: current.author,
      baseTheme: current.baseTheme,
      accentColor: current.accentColor,
      backgroundColor: current.backgroundColor,
      surfaceColor: current.surfaceColor,
      secondarySurfaceColor: current.secondarySurfaceColor,
      separatorColor: current.separatorColor,
      bubbleIncomingColor: current.bubbleIncomingColor,
      bubbleOutgoingColor: current.bubbleOutgoingColor,
      bubbleIncomingTextColor: current.bubbleIncomingTextColor,
      bubbleOutgoingTextColor: current.bubbleOutgoingTextColor,
      bubbleStrokeColor: current.bubbleStrokeColor,
      bubbleStrokeWidth: current.bubbleStrokeWidth,
      wallpaperPattern: 'custom',
      wallpaperPath: filePath,
      wallpaperBase64: base64,
      wallpaperOpacity: current.wallpaperOpacity,
      wallpaperBlur: current.wallpaperBlur,
    );
    await applyThemePack(updated);
  }

  Future<void> setTelegramDoodlesWallpaper() async {
    if (_customTheme == null) return;
    final current = _customTheme!;
    final updated = VKThemePack(
      id: current.id,
      name: current.name,
      author: current.author,
      baseTheme: current.baseTheme,
      accentColor: current.accentColor,
      backgroundColor: current.backgroundColor,
      surfaceColor: current.surfaceColor,
      secondarySurfaceColor: current.secondarySurfaceColor,
      separatorColor: current.separatorColor,
      bubbleIncomingColor: current.bubbleIncomingColor,
      bubbleOutgoingColor: current.bubbleOutgoingColor,
      bubbleIncomingTextColor: current.bubbleIncomingTextColor,
      bubbleOutgoingTextColor: current.bubbleOutgoingTextColor,
      bubbleStrokeColor: current.bubbleStrokeColor,
      bubbleStrokeWidth: current.bubbleStrokeWidth,
      wallpaperPattern: 'telegram_doodles',
      wallpaperPath: null,
      wallpaperBase64: null,
      wallpaperOpacity: current.wallpaperOpacity,
      wallpaperBlur: current.wallpaperBlur,
    );
    await applyThemePack(updated);
  }

  Future<void> removeWallpaper() async {
    if (_customTheme == null) return;
    final current = _customTheme!;
    final updated = VKThemePack(
      id: current.id,
      name: current.name,
      author: current.author,
      baseTheme: current.baseTheme,
      accentColor: current.accentColor,
      backgroundColor: current.backgroundColor,
      surfaceColor: current.surfaceColor,
      secondarySurfaceColor: current.secondarySurfaceColor,
      separatorColor: current.separatorColor,
      bubbleIncomingColor: current.bubbleIncomingColor,
      bubbleOutgoingColor: current.bubbleOutgoingColor,
      bubbleIncomingTextColor: current.bubbleIncomingTextColor,
      bubbleOutgoingTextColor: current.bubbleOutgoingTextColor,
      bubbleStrokeColor: current.bubbleStrokeColor,
      bubbleStrokeWidth: current.bubbleStrokeWidth,
      wallpaperPattern: 'none',
      wallpaperPath: null,
      wallpaperBase64: null,
      wallpaperOpacity: current.wallpaperOpacity,
      wallpaperBlur: current.wallpaperBlur,
    );
    await applyThemePack(updated);
  }

  void setWallpaperOpacity(double opacity, {bool persist = true}) {
    if (_customTheme == null) return;
    _customTheme = _customTheme!.copyWith(wallpaperOpacity: opacity.clamp(0.05, 1.0));
    notifyListeners();
    if (persist) {
      _persistCustomTheme();
    }
  }

  void setWallpaperBlur(double blur, {bool persist = true}) {
    _customTheme ??= VKThemePack.telegramDark;
    _customTheme = _customTheme!.copyWith(wallpaperBlur: blur.clamp(0.0, 30.0));
    notifyListeners();
    if (persist) {
      _persistCustomTheme();
    }
  }

  Future<void> setBubbleStroke({Color? color, double? width}) async {
    _customTheme ??= VKThemePack.telegramDark;
    final current = _customTheme!;
    final updated = current.copyWith(
      bubbleStrokeColor: color,
      clearBubbleStrokeColor: color == null,
      bubbleStrokeWidth: width ?? current.bubbleStrokeWidth,
    );
    await applyThemePack(updated);
  }

  Future<void> setBubbleColors({Color? incoming, Color? outgoing}) async {
    _customTheme ??= VKThemePack.telegramDark;
    final current = _customTheme!;
    final updated = current.copyWith(
      bubbleIncomingColor: incoming ?? current.bubbleIncomingColor,
      bubbleOutgoingColor: outgoing ?? current.bubbleOutgoingColor,
    );
    await applyThemePack(updated);
  }

  Future<void> _persistCustomTheme() async {
    if (_customTheme == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_theme', jsonEncode(_customTheme!.toJson()));
    } catch (_) {}
  }
}
