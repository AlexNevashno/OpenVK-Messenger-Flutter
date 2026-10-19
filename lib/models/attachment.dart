import '../services/openvk_api.dart';

class VKPhotoAttachment {
  final int id;
  final int ownerId;
  final String? url;
  final String text;
  final int? width;
  final int? height;
  final String? localPath; // For instant optimistic preview before upload finishes
  final String? accessKey;

  VKPhotoAttachment({
    required this.id,
    this.ownerId = 0,
    String? url,
    String? previewUrl,
    String? fullUrl,
    this.text = '',
    this.width,
    this.height,
    this.localPath,
    this.accessKey,
  }) : url = url ?? fullUrl ?? previewUrl;

  String get bestUrl {
    final raw = url ?? '';
    if (raw.isEmpty) return '';
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      final base = OpenVKAPIService.instance.serverURL.replaceAll(RegExp(r'/+$'), '');
      final clean = raw.replaceAll(RegExp(r'^/+'), '');
      return '$base/$clean';
    }
    return raw;
  }
  String get previewUrl => bestUrl;
  String get attachmentString {
    final oid = ownerId != 0 ? ownerId : (OpenVKAPIService.instance.currentUser?.id ?? 0);
    return 'photo${oid}_$id${accessKey != null && accessKey!.isNotEmpty ? "_$accessKey" : ""}';
  }

  factory VKPhotoAttachment.fromJson(Map<String, dynamic> json) {
    String? bestUrl;
    if (json['sizes'] is List) {
      final sizes = json['sizes'] as List;
      if (sizes.isNotEmpty) {
        final last = sizes.last;
        if (last is Map) {
          bestUrl = last['url']?.toString() ?? last['src']?.toString();
        }
      }
    }
    bestUrl ??= json['url']?.toString() ??
        json['photo_604']?.toString() ??
        json['photo_807']?.toString() ??
        json['photo_1280']?.toString() ??
        json['photo_130']?.toString();

    return VKPhotoAttachment(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      ownerId: json['owner_id'] is int ? json['owner_id'] : int.tryParse('${json['owner_id']}') ?? 0,
      url: bestUrl,
      text: json['text']?.toString() ?? '',
      width: json['width'] is int ? json['width'] : int.tryParse('${json['width']}'),
      height: json['height'] is int ? json['height'] : int.tryParse('${json['height']}'),
      localPath: json['local_path']?.toString(),
      accessKey: json['access_key']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'url': url,
        'text': text,
        'width': width,
        'height': height,
        'local_path': localPath,
        'access_key': accessKey,
      };
}

class VKDocAttachment {
  final int id;
  final int ownerId;
  String title;
  int size;
  String ext;
  String url;
  final String? localPath;
  final String? accessKey;

  VKDocAttachment({
    required this.id,
    this.ownerId = 0,
    required this.title,
    required this.size,
    required this.ext,
    String? url,
    this.localPath,
    this.accessKey,
  }) : url = url ?? '';

  String get downloadUrl {
    final raw = url;
    if (raw.isNotEmpty) {
      if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
        final base = OpenVKAPIService.instance.serverURL.replaceAll(RegExp(r'/+$'), '');
        final clean = raw.replaceAll(RegExp(r'^/+'), '');
        return '$base/$clean';
      }
      return raw;
    }
    final base = OpenVKAPIService.instance.serverURL.replaceAll(RegExp(r'/+$'), '');
    final oid = ownerId != 0 ? ownerId : (OpenVKAPIService.instance.currentUser?.id ?? 0);
    if (accessKey != null && accessKey!.isNotEmpty) {
      return '$base/doc${oid}_$id?key=$accessKey';
    }
    return '$base/doc${oid}_$id';
  }

  String get attachmentString {
    final oid = ownerId != 0 ? ownerId : (OpenVKAPIService.instance.currentUser?.id ?? 0);
    return 'doc${oid}_$id${accessKey != null && accessKey!.isNotEmpty ? "_$accessKey" : ""}';
  }

  VKDocAttachment copyWith({
    int? id,
    int? ownerId,
    String? title,
    int? size,
    String? ext,
    String? url,
    String? localPath,
    String? accessKey,
  }) {
    return VKDocAttachment(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      size: size ?? this.size,
      ext: ext ?? this.ext,
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      accessKey: accessKey ?? this.accessKey,
    );
  }

  factory VKDocAttachment.fromJson(Map<String, dynamic> json) {
    return VKDocAttachment(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      ownerId: json['owner_id'] is int ? json['owner_id'] : int.tryParse('${json['owner_id']}') ?? 0,
      title: json['title']?.toString() ?? 'Документ',
      size: json['size'] is int ? json['size'] : int.tryParse('${json['size']}') ?? 0,
      ext: json['ext']?.toString() ?? '',
      url: json['url']?.toString(),
      localPath: json['local_path']?.toString(),
      accessKey: json['access_key']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'size': size,
        'ext': ext,
        'url': url,
        'local_path': localPath,
        'access_key': accessKey,
      };
}

class VKVoiceAttachment {
  final String id;
  final int duration;
  final String audioURL;
  final List<int>? waveform;

  VKVoiceAttachment({
    required this.id,
    required this.duration,
    String? audioURL,
    this.waveform,
  }) : audioURL = audioURL ?? '';

  String get linkOgg => audioURL;
  String get linkMp3 => audioURL;

  factory VKVoiceAttachment.fromJson(Map<String, dynamic> json, {String? serverUrl}) {
    // macOS / iOS AVFoundation does not support OGG; link_mp3 must take priority
    String? rawUrl = json['link_mp3']?.toString() ??
        json['link_ogg']?.toString() ??
        json['url']?.toString();

    if (rawUrl != null && rawUrl.isNotEmpty && !rawUrl.startsWith('http') && serverUrl != null && serverUrl.isNotEmpty) {
      final cleanBase = serverUrl.replaceAll(RegExp(r'/+$'), '');
      final cleanPath = rawUrl.replaceAll(RegExp(r'^/+'), '');
      rawUrl = '$cleanBase/$cleanPath';
    }

    return VKVoiceAttachment(
      id: json['id']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] : int.tryParse('${json['duration']}') ?? 0,
      audioURL: rawUrl,
      waveform: json['waveform'] is List
          ? (json['waveform'] as List).map((e) => (e is int ? e : int.tryParse('$e') ?? 0)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'duration': duration,
        'url': audioURL,
      };
}

class VKAudioAttachment {
  final int id;
  final int ownerId;
  final String artist;
  final String title;
  final int duration;
  final String url;

  VKAudioAttachment({
    required this.id,
    required this.ownerId,
    required this.artist,
    required this.title,
    required this.duration,
    String? url,
  }) : url = url ?? '';

  factory VKAudioAttachment.fromJson(Map<String, dynamic> json, {String? serverUrl}) {
    String? rawUrl = json['url']?.toString();
    if (rawUrl != null && rawUrl.isNotEmpty && !rawUrl.startsWith('http') && serverUrl != null && serverUrl.isNotEmpty) {
      final cleanBase = serverUrl.replaceAll(RegExp(r'/+$'), '');
      final cleanPath = rawUrl.replaceAll(RegExp(r'^/+'), '');
      rawUrl = '$cleanBase/$cleanPath';
    }

    return VKAudioAttachment(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      ownerId: json['owner_id'] is int ? json['owner_id'] : int.tryParse('${json['owner_id']}') ?? 0,
      artist: json['artist']?.toString() ?? 'Неизвестный исполнитель',
      title: json['title']?.toString() ?? 'Аудиозапись',
      duration: json['duration'] is int ? json['duration'] : int.tryParse('${json['duration']}') ?? 0,
      url: rawUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'artist': artist,
        'title': title,
        'duration': duration,
        'url': url,
      };
}

class VKVideoAttachment {
  final int id;
  final int ownerId;
  final String title;
  final String description;
  final int duration;
  final String? imageURL;
  final String? playerURL;
  final String? directVideoURL;
  final String? accessKey;

  VKVideoAttachment({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description = '',
    this.duration = 0,
    this.imageURL,
    this.playerURL,
    this.directVideoURL,
    this.accessKey,
  });

  factory VKVideoAttachment.fromJson(Map<String, dynamic> json, {String? serverUrl}) {
    String? img;
    if (json['image'] is List && (json['image'] as List).isNotEmpty) {
      final list = json['image'] as List;
      img = list.last['url']?.toString();
    }
    img ??= json['photo_800']?.toString() ??
        json['photo_640']?.toString() ??
        json['photo_320']?.toString() ??
        json['photo_130']?.toString();

    final base = (serverUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    if (img != null && !img.startsWith('http') && base.isNotEmpty) {
      img = '$base/${img.replaceFirst(RegExp(r'^/+'), '')}';
    }

    String? player = json['player']?.toString();
    if (player != null && player.isNotEmpty && !player.startsWith('http') && base.isNotEmpty) {
      player = '$base/${player.replaceFirst(RegExp(r'^/+'), '')}';
    }

    String? direct = json['direct_url']?.toString();
    if (direct == null && json['files'] is Map) {
      final files = json['files'] as Map;
      for (final key in [
        'mp4_1080',
        '1080',
        'mp4_720',
        '720',
        'mp4_480',
        '480',
        'mp4_360',
        '360',
        'mp4_240',
        '240',
        'external',
      ]) {
        if (files[key] != null && files[key].toString().isNotEmpty) {
          var u = files[key].toString();
          if (!u.startsWith('http') && base.isNotEmpty) {
            u = '$base/${u.replaceFirst(RegExp(r'^/+'), '')}';
          }
          direct = u;
          break;
        }
      }
    }

    final oid = json['owner_id'] is int ? json['owner_id'] as int : int.tryParse('${json['owner_id']}') ?? 0;
    final vid = json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0;

    if ((player == null || player.isEmpty) && (direct == null || direct.isEmpty) && vid != 0) {
      if (base.isNotEmpty) {
        player = '$base/video${oid}_$vid';
      }
    }

    return VKVideoAttachment(
      id: vid,
      ownerId: oid,
      title: json['title']?.toString().isNotEmpty == true ? json['title'].toString() : 'Видеозапись',
      description: json['description']?.toString() ?? '',
      duration: json['duration'] is int ? json['duration'] as int : int.tryParse('${json['duration']}') ?? 0,
      imageURL: img,
      playerURL: player,
      directVideoURL: direct,
      accessKey: json['access_key']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'title': title,
        'description': description,
        'duration': duration,
        'image': imageURL,
        'player': playerURL,
        'direct_url': directVideoURL,
        'access_key': accessKey,
      };
}

class VKSticker {
  final int id;
  final int? productId;
  final String? url;
  final String? animationURL;

  VKSticker({
    required this.id,
    int? stickerId,
    int? packId,
    List<VKStickerImage>? images,
    this.productId,
    this.url,
    String? animationURL,
    String? animationUrl,
  }) : animationURL = animationURL ?? animationUrl;

  String get bestUrl => url ?? '';

  factory VKSticker.fromJson(Map<String, dynamic> json) {
    String? sUrl;
    if (json['images'] is List && (json['images'] as List).isNotEmpty) {
      sUrl = (json['images'] as List).last['url']?.toString();
    }
    sUrl ??= json['photo_352']?.toString() ?? json['photo_256']?.toString() ?? json['photo_128']?.toString();

    String? animStr = json['animation_url']?.toString() ??
        json['animation']?.toString();
    if ((animStr == null || animStr.isEmpty) && json['animations'] is List) {
      final anims = json['animations'] as List;
      if (anims.isNotEmpty && anims.first is Map) {
        animStr = anims.first['url']?.toString();
      }
    }

    return VKSticker(
      id: json['sticker_id'] is int ? json['sticker_id'] : (json['id'] is int ? json['id'] : int.tryParse('${json['sticker_id'] ?? json['id']}') ?? 0),
      productId: json['product_id'] is int ? json['product_id'] : int.tryParse('${json['product_id']}'),
      url: sUrl,
      animationURL: animStr,
    );
  }

  Map<String, dynamic> toJson() => {
        'sticker_id': id,
        'product_id': productId,
        'url': url,
        'animation_url': animationURL,
      };
}

class VKStickerImage {
  final String url;
  final int width;
  final int height;

  VKStickerImage({required this.url, required this.width, required this.height});
}

class VKStickerItem {
  final int id;
  final int packId;
  final String url;
  final String? animationURL;

  VKStickerItem({
    required this.id,
    required this.packId,
    String? url,
    this.animationURL,
  }) : url = url ?? '';

  String? get animationUrl => animationURL;

  factory VKStickerItem.fromJson(Map<String, dynamic> json, {String? baseUrl, int packId = 0}) {
    final sid = json['sticker_id'] is int
        ? json['sticker_id']
        : (json['id'] is int ? json['id'] : int.tryParse('${json['sticker_id'] ?? json['id']}') ?? 0);
    final pid = json['pack_id'] is int
        ? json['pack_id']
        : (int.tryParse('${json['pack_id']}') ?? packId);

    String? uStr = json['url']?.toString();
    if (uStr == null || uStr.isEmpty) {
      uStr = json['photo_352']?.toString() ??
          json['photo_256']?.toString() ??
          json['photo_512']?.toString() ??
          json['photo_128']?.toString() ??
          json['photo_64']?.toString();
    }
    if ((uStr == null || uStr.isEmpty) && json['images'] is List) {
      final imgs = json['images'] as List;
      if (imgs.isNotEmpty) {
        final lastImg = imgs.last;
        if (lastImg is Map) {
          uStr = lastImg['url']?.toString();
        }
      }
    }
    if ((uStr == null || uStr.isEmpty) && json['images_with_background'] is List) {
      final imgs = json['images_with_background'] as List;
      if (imgs.isNotEmpty) {
        final lastImg = imgs.last;
        if (lastImg is Map) {
          uStr = lastImg['url']?.toString();
        }
      }
    }

    String resolvedUrl = '';
    if (uStr != null && uStr.isNotEmpty) {
      if (uStr.startsWith('http')) {
        resolvedUrl = uStr;
      } else if (baseUrl != null && baseUrl.isNotEmpty) {
        final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
        final cleanPath = uStr.replaceAll(RegExp(r'^/+'), '');
        resolvedUrl = '$cleanBase/$cleanPath';
      } else {
        resolvedUrl = uStr;
      }
    }

    if (resolvedUrl.isEmpty && sid > 0) {
      if (baseUrl != null && baseUrl.isNotEmpty) {
        final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
        resolvedUrl = '$cleanBase/images/stickers/$sid/256b.png';
      } else {
        resolvedUrl = 'https://vk.com/sticker/1-$sid-256.png';
      }
    }

    // Animation URL parsing
    String? animStr = json['animation_url']?.toString() ??
        json['animation']?.toString();
    if ((animStr == null || animStr.isEmpty) && json['animations'] is List) {
      final anims = json['animations'] as List;
      if (anims.isNotEmpty && anims.first is Map) {
        animStr = anims.first['url']?.toString();
      }
    }

    String? resolvedAnimUrl;
    if (animStr != null && animStr.isNotEmpty) {
      if (animStr.startsWith('http')) {
        resolvedAnimUrl = animStr;
      } else if (baseUrl != null && baseUrl.isNotEmpty) {
        final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
        final cleanPath = animStr.replaceAll(RegExp(r'^/+'), '');
        resolvedAnimUrl = '$cleanBase/$cleanPath';
      } else {
        resolvedAnimUrl = animStr;
      }
    }

    return VKStickerItem(
      id: sid,
      packId: pid,
      url: resolvedUrl,
      animationURL: resolvedAnimUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pack_id': packId,
        'url': url,
        'animation_url': animationURL,
      };
}

class VKStickerPack {
  final int id;
  final String title;
  final String? iconURL;
  final List<VKStickerItem> stickers;

  VKStickerPack({
    required this.id,
    required this.title,
    this.iconURL,
    required this.stickers,
  });

  String? get previewUrl => iconURL;

  factory VKStickerPack.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    final packId = json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0;
    List<VKStickerItem> list = [];
    if (json['stickers'] is List) {
      list = (json['stickers'] as List)
          .whereType<Map>()
          .map((e) => VKStickerItem.fromJson(Map<String, dynamic>.from(e), baseUrl: baseUrl, packId: packId))
          .toList();
    }

    String? icon = json['icon_url']?.toString() ??
        json['photo_140']?.toString() ??
        json['photo_70']?.toString() ??
        json['photo_35']?.toString() ??
        json['photo']?.toString();

    if (icon != null && icon.isNotEmpty && !icon.startsWith('http') && baseUrl != null && baseUrl.isNotEmpty) {
      final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
      final cleanPath = icon.replaceAll(RegExp(r'^/+'), '');
      icon = '$cleanBase/$cleanPath';
    }

    if ((icon == null || icon.isEmpty) && list.isNotEmpty) {
      icon = list.first.url;
    }

    return VKStickerPack(
      id: packId,
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Стикеры',
      iconURL: icon,
      stickers: list,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon_url': iconURL,
        'stickers': stickers.map((e) => e.toJson()).toList(),
      };
}

class VKGiftAttachment {
  final int id;
  final String? thumbURL;
  final String? description;

  VKGiftAttachment({
    required this.id,
    this.thumbURL,
    this.description,
  });

  factory VKGiftAttachment.fromJson(Map<String, dynamic> json) {
    return VKGiftAttachment(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      thumbURL: json['thumb_256']?.toString() ?? json['thumb_96']?.toString() ?? json['thumb']?.toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'thumb': thumbURL,
        'description': description,
      };
}

class VKMoneyTransferAttachment {
  final int id;
  final int amount;
  final String currency;
  final String? comment;
  final int? fromId;
  final int? toId;

  VKMoneyTransferAttachment({
    required this.id,
    required this.amount,
    required this.currency,
    this.comment,
    this.fromId,
    this.toId,
  });

  factory VKMoneyTransferAttachment.fromJson(Map<String, dynamic> json) {
    final curr = json['currency']?.toString().trim();
    return VKMoneyTransferAttachment(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      amount: json['amount'] is int ? json['amount'] : int.tryParse('${json['amount']}') ?? 0,
      currency: (curr != null && curr.isNotEmpty && curr != 'RUB') ? curr : 'голосов',
      comment: json['text']?.toString() ?? json['comment']?.toString(),
      fromId: json['from_id'] is int ? json['from_id'] : int.tryParse('${json['from_id']}'),
      toId: json['to_id'] is int ? json['to_id'] : int.tryParse('${json['to_id']}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'currency': currency,
        if (comment != null) 'comment': comment,
        if (fromId != null) 'from_id': fromId,
        if (toId != null) 'to_id': toId,
      };
}

class VKWallPost {
  final int id;
  final int ownerId;
  final String text;
  final DateTime date;

  VKWallPost({
    required this.id,
    required this.ownerId,
    required this.text,
    required this.date,
  });

  factory VKWallPost.fromJson(Map<String, dynamic> json) {
    DateTime d;
    final rawDate = json['date'];
    if (rawDate is int) {
      d = DateTime.fromMillisecondsSinceEpoch(rawDate * 1000);
    } else {
      final sec = int.tryParse('$rawDate') ?? 0;
      d = sec > 0 ? DateTime.fromMillisecondsSinceEpoch(sec * 1000) : DateTime.now();
    }
    return VKWallPost(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      ownerId: json['owner_id'] is int ? json['owner_id'] : int.tryParse('${json['owner_id']}') ?? 0,
      text: json['text']?.toString() ?? '',
      date: d,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'text': text,
        'date': date.millisecondsSinceEpoch ~/ 1000,
      };
}
