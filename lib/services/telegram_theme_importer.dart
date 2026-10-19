import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import '../models/theme_pack.dart';

/// Universal parser and converter for Telegram themes:
/// - Telegram Desktop: `.tdesktop-theme`, `.palette`, `.tdesktop-palette`, `.zip`
/// - Telegram Android: `.attheme` (with signed/unsigned int32 colors & embedded WPS binary wallpaper)
/// - Telegram iOS: `.tgios-theme`, `.tgtheme`, `.palette`, `.txt` (hierarchical YAML format)
/// - Telegram X: `.tgx-theme` (comma-separated color lists)
class TelegramThemeImporter {
  /// Import a theme file from local File path or bytes
  static Future<VKThemePack> importThemeFromFile(File file) async {
    final bytes = await file.readAsBytes();
    return importThemeFromBytes(bytes, filename: file.path);
  }

  static VKThemePack importThemeFromBytes(Uint8List bytes, {String? filename}) {
    final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B; // "PK" zip signature

    String paletteText = '';
    String? wallpaperBase64;

    if (isZip) {
      final res = _extractFromZip(bytes);
      paletteText = res.palette;
      wallpaperBase64 = res.wallpaperBase64;
    } else {
      // Check for Android .attheme with attached WPS wallpaper binary data
      // Look for "WPS\n" or "WPS\r\n"
      int wpsIndex = -1;
      int wpsHeaderLen = 0;

      for (int i = 0; i < bytes.length - 5; i++) {
        if (bytes[i] == 0x57 && bytes[i + 1] == 0x50 && bytes[i + 2] == 0x53) { // 'W', 'P', 'S'
          if (bytes[i + 3] == 0x0A) {
            wpsIndex = i;
            wpsHeaderLen = 4;
            break;
          } else if (bytes[i + 3] == 0x0D && bytes[i + 4] == 0x0A) {
            wpsIndex = i;
            wpsHeaderLen = 5;
            break;
          }
        }
      }

      if (wpsIndex != -1) {
        final textBytes = bytes.sublist(0, wpsIndex);
        try {
          paletteText = utf8.decode(textBytes, allowMalformed: true);
        } catch (_) {
          paletteText = latin1.decode(textBytes);
        }
        final imgBytes = bytes.sublist(wpsIndex + wpsHeaderLen);
        if (imgBytes.isNotEmpty) {
          wallpaperBase64 = base64Encode(imgBytes);
        }
      } else {
        try {
          paletteText = utf8.decode(bytes, allowMalformed: true);
        } catch (_) {
          paletteText = latin1.decode(bytes);
        }
      }
    }

    // If no embedded wallpaper found and filename provided, check companion wallpaper
    if (wallpaperBase64 == null && filename != null) {
      wallpaperBase64 = _searchCompanionWallpaper(filename);
    }

    // Parse color variables
    final rawColors = _parseColorVariables(paletteText);
    if (rawColors.isEmpty) {
      throw Exception('В файле темы Telegram не найдено цветовых переменных.');
    }

    // Resolve aliases (e.g. msgInBg: windowBg;)
    final resolved = _resolveAliases(rawColors);

    // Extract theme name
    final themeName = _extractThemeName(filename, paletteText);

    return _buildThemePack(
      name: themeName,
      colors: resolved,
      wallpaperBase64: wallpaperBase64,
    );
  }

  // MARK: - Companion Wallpaper Search
  static String? _searchCompanionWallpaper(String filePath) {
    try {
      final file = File(filePath);
      final dir = file.parent;
      if (!dir.existsSync()) return null;

      final list = dir.listSync();
      // 1. Direct companion image
      for (final entity in list) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last.toLowerCase();
          final ext = name.split('.').last.toLowerCase();
          if ((ext == 'jpg' || ext == 'jpeg' || ext == 'png') &&
              (name.contains('background') || name.contains('wallpaper') || name.contains('tiled') || name.contains('bg'))) {
            final b = entity.readAsBytesSync();
            return base64Encode(b);
          }
        }
      }

      // 2. Companion .tdesktop-theme in same folder
      for (final entity in list) {
        if (entity is File && entity.path != filePath && entity.path.toLowerCase().endsWith('.tdesktop-theme')) {
          final res = _extractFromZip(entity.readAsBytesSync());
          if (res.wallpaperBase64 != null) {
            return res.wallpaperBase64;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // MARK: - Extract Theme Name
  static String _extractThemeName(String? filePath, String paletteText) {
    final lines = paletteText.split('\n').take(15);
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.toLowerCase().startsWith('name:')) {
        final val = line.substring(5).replaceAll(RegExp(r'''["';\s]'''), '');
        if (val.length > 1 && !val.toLowerCase().contains('unnamed')) {
          return val;
        }
      }
    }

    if (filePath != null) {
      final segments = filePath.split(Platform.pathSeparator);
      var base = segments.isNotEmpty ? segments.last : 'Telegram Theme';
      if (base.contains('.')) {
        base = base.substring(0, base.lastIndexOf('.'));
      }
      final generic = ['pc', 'colors', 'theme', 'iphone', 'telegram x', 'android', 'default'];
      if (generic.contains(base.toLowerCase()) && segments.length > 1) {
        base = segments[segments.length - 2];
      }
      return base.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    }

    return 'Telegram Theme';
  }

  // MARK: - ZIP Extraction (.tdesktop-theme)
  static ({String palette, String? wallpaperBase64}) _extractFromZip(Uint8List zipBytes) {
    String paletteContent = '';
    String? wallpaperBase64;

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.toLowerCase();

        // 1. Wallpaper check
        if (name.startsWith('background') ||
            name.startsWith('wallpaper') ||
            name.startsWith('tiled') ||
            name.endsWith('.jpg') ||
            name.endsWith('.png') ||
            name.endsWith('.jpeg')) {
          if (wallpaperBase64 == null) {
            final content = file.content as List<int>;
            wallpaperBase64 = base64Encode(content);
          }
        }

        // 2. Palette check
        final isPalette = name.contains('tdesktop-theme') ||
            name.contains('palette') ||
            name.contains('scheme') ||
            name.endsWith('.txt') ||
            name == 'colors' ||
            name == 'theme';

        if (isPalette) {
          final content = file.content as List<int>;
          try {
            final str = utf8.decode(content, allowMalformed: true);
            if (str.contains('windowBg') || str.contains('dialogsBg') || str.contains('msgInBg') || str.contains(':')) {
              paletteContent = str;
            } else if (paletteContent.isEmpty) {
              paletteContent = str;
            }
          } catch (_) {
            paletteContent = latin1.decode(content);
          }
        }
      }

      // If no palette matched by name, check any text file with ':' or '='
      if (paletteContent.isEmpty) {
        for (final file in archive) {
          if (!file.isFile) continue;
          final name = file.name.toLowerCase();
          if (!name.endsWith('.jpg') && !name.endsWith('.png') && !name.endsWith('.jpeg')) {
            try {
              final content = file.content as List<int>;
              final str = utf8.decode(content, allowMalformed: true);
              if ((str.contains(':') || str.contains('=')) &&
                  (str.contains('Bg') || str.contains('Fg') || str.contains('Color') || str.contains('chat'))) {
                paletteContent = str;
                break;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[TelegramThemeImporter] Zip decode error: $e');
    }

    return (palette: paletteContent, wallpaperBase64: wallpaperBase64);
  }

  // MARK: - Universal Palette Parsing
  static Map<String, String> _parseColorVariables(String text) {
    final Map<String, String> result = {};
    final lines = text.split('\n');
    final List<({int indent, String key})> indentStack = [];

    for (final rawLine in lines) {
      var line = rawLine;
      final commentIdx = line.indexOf('//');
      if (commentIdx != -1) {
        line = line.substring(0, commentIdx);
      }
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('!') || trimmed.startsWith('@')) {
        continue;
      }

      final leadingSpaces = line.length - line.trimLeft().length;
      while (indentStack.isNotEmpty && indentStack.last.indent >= leadingSpaces) {
        indentStack.removeLast();
      }

      if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        final rawKeyPart = parts[0].trim();
        var valPart = parts.sublist(1).join(':').trim();
        final cIdx = valPart.indexOf('//');
        if (cIdx != -1) {
          valPart = valPart.substring(0, cIdx);
        }
        valPart = valPart.replaceAll(RegExp(r'[;\s]+$'), '').trim();

        if (valPart.isEmpty) {
          indentStack.add((indent: leadingSpaces, key: rawKeyPart));
        } else {
          final pathPrefix = indentStack.map((e) => e.key).join('_');
          final subKeys = rawKeyPart.split(',').map((s) => s.trim());
          for (final subKey in subKeys) {
            final fullKey = pathPrefix.isEmpty ? subKey : '${pathPrefix}_$subKey';
            final normalized = _normalizeColor(valPart);
            if (normalized != null) {
              result[fullKey] = normalized;
              result[subKey] = normalized;
            } else {
              result[fullKey] = valPart;
              result[subKey] = valPart;
            }
          }
        }
      } else if (trimmed.contains('=')) {
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final rawKey = parts[0].trim();
          var valPart = parts.sublist(1).join('=').trim();
          final cIdx = valPart.indexOf('//');
          if (cIdx != -1) {
            valPart = valPart.substring(0, cIdx);
          }
          valPart = valPart.replaceAll(RegExp(r'[;\s]+$'), '').trim();

          final subKeys = rawKey.split(',').map((s) => s.trim());
          for (final subKey in subKeys) {
            final normalized = _normalizeColor(valPart);
            if (normalized != null) {
              result[subKey] = normalized;
            } else {
              result[subKey] = valPart;
            }
          }
        }
      }
    }

    return result;
  }

  // MARK: - Color Normalization
  static String? _normalizeColor(String raw) {
    final str = raw.trim();
    if (str == 'clear' || str == 'none') return '#00000000';

    // 1. Hex color
    final clean = str.replaceAll(RegExp(r'[#\s;,\t\r\n]'), '');
    final isHex = RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean);
    if (isHex) {
      if (clean.length == 6) {
        return '#${clean.toUpperCase()}';
      } else if (clean.length == 8) {
        // Telegram Desktop colors are RRGGBBAA
        final r = clean.substring(0, 2);
        final g = clean.substring(2, 4);
        final b = clean.substring(4, 6);
        final a = clean.substring(6, 8);
        if (a == '00') return '#00000000';
        if (a.toUpperCase() == 'FF') return '#$r$g$b'.toUpperCase();
        // Flutter ARGB hex format
        return '#$a$r$g$b'.toUpperCase();
      } else if (clean.length == 4) {
        final r = clean[0], g = clean[1], b = clean[2], a = clean[3];
        if (a == '0') return '#00000000';
        return '#$a$a$r$r$g$g$b$b'.toUpperCase();
      } else if (clean.length == 3) {
        final r = clean[0], g = clean[1], b = clean[2];
        return '#$r$r$g$g$b$b'.toUpperCase();
      }
    }

    // 2. Signed 32-bit integer (Android .attheme standard format)
    final intVal = int.tryParse(str);
    if (intVal != null) {
      final uintVal = intVal & 0xFFFFFFFF;
      final a = (uintVal >> 24) & 0xFF;
      if (a == 0 && intVal != 0) return '#00000000';
      final r = (uintVal >> 16) & 0xFF;
      final g = (uintVal >> 8) & 0xFF;
      final b = uintVal & 0xFF;
      return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
    }

    // 3. rgba(r, g, b, a) or rgb(r, g, b)
    if (str.toLowerCase().startsWith('rgb')) {
      final cleanRGB = str.replaceAll('rgba', '').replaceAll('rgb', '').replaceAll(RegExp(r'[()\s\t]'), '');
      final comps = cleanRGB.split(',').map((s) => s.trim()).toList();
      if (comps.length >= 3) {
        final r = int.tryParse(comps[0]);
        final g = int.tryParse(comps[1]);
        final b = int.tryParse(comps[2]);
        if (r != null && g != null && b != null) {
          if (comps.length >= 4) {
            final a = double.tryParse(comps[3]);
            if (a != null && a == 0) return '#00000000';
          }
          final rClamped = r.clamp(0, 255);
          final gClamped = g.clamp(0, 255);
          final bClamped = b.clamp(0, 255);
          return '#${rClamped.toRadixString(16).padLeft(2, '0')}${gClamped.toRadixString(16).padLeft(2, '0')}${bClamped.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
        }
      }
    }

    return null;
  }

  // MARK: - Resolve Aliases
  static Map<String, String> _resolveAliases(Map<String, String> dict) {
    final Map<String, String> resolved = Map.from(dict);

    for (final key in dict.keys) {
      var current = dict[key] ?? '';
      int hops = 0;
      while (!current.startsWith('#') && hops < 6) {
        final next = dict[current];
        if (next != null) {
          current = next;
          hops++;
        } else {
          break;
        }
      }
      if (current.startsWith('#')) {
        resolved[key] = current;
      }
    }

    return resolved;
  }

  // MARK: - Construct VKThemePack
  static VKThemePack _buildThemePack({
    required String name,
    required Map<String, String> colors,
    String? wallpaperBase64,
  }) {
    String findColor(List<String> keys, {required String fallback}) {
      for (final k in keys) {
        final val = colors[k];
        if (val != null && val.startsWith('#')) {
          if (val == '#00000000') continue;
          final hexBody = val.substring(1);
          if (hexBody.length == 6 || hexBody.length == 8) {
            final clean = '#${hexBody.toUpperCase()}';
            if (k == 'windowBgActive' && (clean == '#000000' || clean == '#FF000000')) continue;
            return clean;
          }
        }
      }
      return fallback;
    }

    // 1. Accent Color
    final accent = findColor([
      'root_navBar_accentText', 'root_navBar_control', 'root_tabBar_selectedIcon', 'list_accent',
      'chatList_unreadBadgeActiveBg', 'badge', 'controlActive', 'actionBarDefault', 'chats_actionBackground',
      'chats_unreadCounter', 'windowActiveTextFg', 'dialogsUnreadBg', 'historyPeer1NameFg', 'msgInDateFg',
      'dialogsNameFgActive', 'dialogsChatIconFg', 'chat_outBubble', 'chat_outTime',
      'accent_color', 'activeButtonBg', 'dialogsBgActive', 'windowBgActive'
    ], fallback: '#2B82E0');

    // 2. Background Color (Chat wallpaper / chat background)
    final background = findColor([
      'chat_defaultWallpaper', 'chatBackground', 'chat_background', 'chat_wallpaper', 'chatList_bg',
      'windowBackgroundWhite', 'windowBg', 'dialogsBg'
    ], fallback: '#18222D');

    // 3. Surface Color (Dialogs sidebar / headers / navigation bar)
    final surface = findColor([
      'root_navBar_background', 'root_tabBar_background', 'chatList_bg', 'headerBackground',
      'actionBarDefault', 'dialogsBg', 'windowBg', 'windowBackgroundWhite', 'chat_list_background'
    ], fallback: '#18222D');

    // 4. Secondary Surface
    final secondarySurface = findColor([
      'list_itemBlocksBg', 'headerLightBackground', 'windowBackgroundGray',
      'dialogsBgOver', 'windowBgOver', 'scrollBg', 'dialogsBgActive'
    ], fallback: '#212D3B');

    // 5. Separator
    final separator = findColor([
      'chatList_itemSeparator', 'root_navBar_separator', 'root_tabBar_separator',
      'list_plainSeparator', 'list_blocksSeparator', 'divider', 'dialogsSeparator', 'shadowFg', 'windowSubTextFg'
    ], fallback: '#2A3644');

    // 6. Incoming Bubble
    final bubbleIncoming = findColor([
      'chat_message_incoming_bubble_withWp_bg', 'chat_message_incoming_bubble_withoutWp_bg',
      'bubbleIn_background', 'chat_inBubble', 'msgInBg', 'chat_message_in', 'msgInShadow'
    ], fallback: '#212D3B');

    // 7. Outgoing Bubble
    final bubbleOutgoing = findColor([
      'chat_message_outgoing_bubble_withWp_bg', 'chat_message_outgoing_bubble_withoutWp_bg',
      'bubbleOut_background', 'chat_outBubble', 'msgOutBg', 'chat_message_out'
    ], fallback: accent);

    // 8. Incoming Text
    final bubbleIncomingText = findColor([
      'chat_message_incoming_primaryText', 'chat_messageTextIn', 'chat_inText',
      'historyTextInFg', 'msgInFg', 'chat_message_in_text', 'windowFg', 'primaryText'
    ], fallback: '#FFFFFF');

    // 9. Outgoing Text
    final bubbleOutgoingText = findColor([
      'chat_message_outgoing_primaryText', 'chat_messageTextOut', 'chat_outText',
      'historyTextOutFg', 'msgOutFg', 'chat_message_out_text', 'primaryText'
    ], fallback: '#FFFFFF');

    // 10. Bubble Stroke
    final bubbleStroke = findColor([
      'chat_message_incoming_bubble_withWp_stroke', 'chat_message_outgoing_bubble_withWp_stroke',
      'msgInShadow', 'chat_inBubbleSelected', 'msgOutShadow'
    ], fallback: '');
    final String? strokeHex = (bubbleStroke.startsWith('#') && bubbleStroke != bubbleIncoming) ? bubbleStroke : null;

    // Luminance & base theme
    final bgLum = _luminance(background);
    final surfLum = _luminance(surface);
    final avgLum = (bgLum + surfLum) / 2.0;

    final String baseTheme;
    if (avgLum < 0.22) {
      baseTheme = 'night';
    } else if (avgLum < 0.52) {
      baseTheme = 'tinted';
    } else if (avgLum > 0.82) {
      baseTheme = 'classic';
    } else {
      baseTheme = 'day';
    }

    final pattern = (wallpaperBase64 != null) ? 'custom' : (avgLum < 0.5 ? 'telegram_doodles' : 'none');

    return VKThemePack(
      id: 'tg_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      author: 'Telegram Port',
      baseTheme: baseTheme,
      accentColor: _hexToColor(accent),
      backgroundColor: _hexToColor(background),
      surfaceColor: _hexToColor(surface),
      secondarySurfaceColor: _hexToColor(secondarySurface),
      separatorColor: _hexToColor(separator),
      bubbleIncomingColor: _hexToColor(bubbleIncoming),
      bubbleOutgoingColor: _hexToColor(bubbleOutgoing),
      bubbleIncomingTextColor: _hexToColor(bubbleIncomingText),
      bubbleOutgoingTextColor: _hexToColor(bubbleOutgoingText),
      bubbleStrokeColor: strokeHex != null ? _hexToColor(strokeHex) : null,
      bubbleStrokeWidth: strokeHex != null ? 0.8 : 0.0,
      wallpaperPattern: pattern,
      wallpaperBase64: wallpaperBase64,
      wallpaperOpacity: 0.9,
      wallpaperBlur: 0.0,
    );
  }

  static double _luminance(String hex) {
    try {
      final color = _hexToColor(hex);
      return 0.299 * (color.r * 255) / 255.0 +
          0.587 * (color.g * 255) / 255.0 +
          0.114 * (color.b * 255) / 255.0;
    } catch (_) {
      return 0.5;
    }
  }

  static Color _hexToColor(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) clean = 'FF$clean';
    final val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : Colors.blue;
  }
}
