import 'attachment.dart';
import 'user.dart';

class VKMessageAction {
  final String type;
  final int? memberId;
  final String? memberName;
  final String? text;

  VKMessageAction({
    required this.type,
    this.memberId,
    this.memberName,
    this.text,
  });

  factory VKMessageAction.fromJson(Map<String, dynamic> json) {
    return VKMessageAction(
      type: json['type']?.toString() ?? '',
      memberId: json['member_id'] is int ? json['member_id'] : int.tryParse('${json['member_id']}'),
      memberName: json['member_name']?.toString(),
      text: json['text']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'member_id': memberId,
        'member_name': memberName,
        'text': text,
      };

  String displayText(String authorName, [int authorId = 0]) {
    final bool isSelf = (memberId != null && memberId == authorId) || (memberId == null);
    switch (type) {
      case 'chat_invite_user':
        if (isSelf) return '$authorName вернулся(лась) в беседу';
        if (memberName != null && memberName!.isNotEmpty) return '$authorName пригласил(а) $memberName';
        return '$authorName вернулся(лась) в беседу';
      case 'chat_invite_user_by_link':
        return '$authorName присоединился(лась) к беседе по ссылке';
      case 'chat_kick_user':
        if (isSelf) return '$authorName покинул(а) беседу';
        if (memberName != null && memberName!.isNotEmpty) return '$authorName исключил(а) $memberName';
        return '$authorName покинул(а) беседу';
      case 'chat_title_update':
        final t = (text != null && text!.isNotEmpty) ? ' «$text»' : '';
        return '$authorName изменил(а) название беседы$t';
      case 'chat_photo_update':
        return '$authorName обновил(а) фотографию беседы';
      case 'chat_photo_remove':
        return '$authorName удалил(а) фотографию беседы';
      case 'chat_pin_message':
        return '$authorName закрепил(а) сообщение';
      case 'chat_unpin_message':
        return '$authorName открепил(а) сообщение';
      case 'chat_create':
        final t = (text != null && text!.isNotEmpty) ? ' «$text»' : '';
        return '$authorName создал(а) беседу$t';
      case 'chat_screenshot':
        return '$authorName сделал(а) скриншот';
      default:
        return text ?? 'Действие в беседе';
    }
  }
}

class VKReplyMessage {
  final int id;
  final int fromId;
  final String senderName;
  final String? senderAvatarURL;
  final DateTime? date;
  final String text;
  final String? photoURL;
  final bool hasPhoto;

  VKReplyMessage({
    required this.id,
    required this.fromId,
    String? senderName,
    this.senderAvatarURL,
    this.date,
    required this.text,
    this.photoURL,
    this.hasPhoto = false,
  }) : senderName = senderName ?? 'Пользователь';

  factory VKReplyMessage.fromJson(Map<String, dynamic> json) {
    DateTime? d;
    if (json['date'] != null) {
      final sec = json['date'] is int ? json['date'] : int.tryParse('${json['date']}') ?? 0;
      if (sec > 0) d = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    }
    return VKReplyMessage(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      fromId: json['from_id'] is int ? json['from_id'] : int.tryParse('${json['from_id']}') ?? 0,
      senderName: json['sender_name']?.toString() ?? 'Пользователь',
      senderAvatarURL: json['sender_avatar_url']?.toString(),
      date: d,
      text: json['text']?.toString() ?? '',
      photoURL: json['photo_url']?.toString(),
      hasPhoto: json['has_photo'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'from_id': fromId,
        'sender_name': senderName,
        'sender_avatar_url': senderAvatarURL,
        'date': date != null ? date!.millisecondsSinceEpoch ~/ 1000 : null,
        'text': text,
        'photo_url': photoURL,
        'has_photo': hasPhoto,
      };
}

class VKMessage {
  int id;
  final int peerId;
  final int fromId;
  final DateTime date;
  String text;
  bool out;
  bool isRead;

  // Attachments
  VKSticker? sticker;
  VKPhotoAttachment? photo;
  List<VKPhotoAttachment> photos;
  VKVoiceAttachment? voiceMessage;
  VKDocAttachment? doc;
  VKAudioAttachment? audio;
  VKVideoAttachment? video;
  VKGiftAttachment? gift;
  VKMoneyTransferAttachment? moneyTransfer;
  VKWallPost? wallPost;
  VKMessageAction? action;
  VKUser? sender;
  VKReplyMessage? replyMessage;
  bool isPinned;
  bool isFailed;
  String? sendError;

  VKMessage({
    required this.id,
    required this.peerId,
    required this.fromId,
    required this.date,
    required this.text,
    bool? out,
    bool? isOut,
    bool? isRead,
    bool? readState,
    this.sticker,
    this.photo,
    List<VKPhotoAttachment>? photos,
    VKVoiceAttachment? voiceMessage,
    VKVoiceAttachment? voice,
    VKDocAttachment? doc,
    List<VKDocAttachment>? docs,
    VKAudioAttachment? audio,
    List<VKAudioAttachment>? audioList,
    this.video,
    this.gift,
    this.moneyTransfer,
    this.wallPost,
    this.action,
    this.sender,
    this.replyMessage,
    this.isPinned = false,
    this.isFailed = false,
    this.sendError,
  })  : out = out ?? isOut ?? false,
        isRead = isRead ?? readState ?? false,
        photos = photos ?? (photo != null ? [photo] : const []),
        voiceMessage = voiceMessage ?? voice,
        doc = doc ?? (docs != null && docs.isNotEmpty ? docs.first : null),
        audio = audio ?? (audioList != null && audioList.isNotEmpty ? audioList.first : null);

  bool get isOut => out;
  set isOut(bool v) => out = v;

  bool get readState => isRead;
  set readState(bool v) => isRead = v;

  VKVoiceAttachment? get voice => voiceMessage;
  List<VKDocAttachment> get docs => doc != null ? [doc!] : [];
  List<VKAudioAttachment> get audioList => audio != null ? [audio!] : [];
  bool get isPending => id < 0;

  bool get isMoneyTransfer =>
      moneyTransfer != null || isMoneyTransferText(text);

  static bool isMoneyTransferText(String t) {
    final lower = t.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return lower.contains('передал вам') ||
        lower.contains('передала вам') ||
        lower.contains('передал(а) вам') ||
        (lower.contains('голос') && (lower.contains('перевод') || lower.contains('передал') || lower.contains('перевёл')));
  }

  int get parsedTransferAmount {
    if (moneyTransfer != null && moneyTransfer!.amount > 0) {
      return moneyTransfer!.amount;
    }
    final digitsMatch = RegExp(r'\d+').allMatches(text);
    return digitsMatch.isNotEmpty ? int.tryParse(digitsMatch.first.group(0) ?? '') ?? 0 : 0;
  }

  bool get isGiftOrStickerpack =>
      gift != null || isGiftOrStickerpackText(text);

  static bool isGiftOrStickerpackText(String t) {
    final lower = t.trim().toLowerCase();
    if (lower.isEmpty) return false;
    return lower.contains('подарил вам стикерпак') ||
        lower.contains('подарила вам стикерпак') ||
        lower.contains('подарил(а) вам стикерпак') ||
        lower.contains('вам подарили стикерпак') ||
        lower.contains('подарил стикерпак') ||
        lower.contains('подарила стикерпак') ||
        lower.contains('подарили стикерпак') ||
        lower.contains('отправил вам подарок') ||
        lower.contains('отправила вам подарок') ||
        lower.contains('отправил(а) вам подарок') ||
        lower.contains('вам отправили подарок') ||
        lower.contains('вам подарили подарок');
  }

  bool get isServiceAction {
    if (isMoneyTransfer || isGiftOrStickerpack) return false;
    if (action != null) return true;
    final t = text.trim().toLowerCase();
    return t.contains('присоединился к беседе') ||
        t.contains('присоединилась к беседе') ||
        t.contains('вернулся в беседу') ||
        t.contains('вернулась в беседу') ||
        t.contains('покинул беседу') ||
        t.contains('покинула беседу') ||
        t.contains('исключил из беседы') ||
        t.contains('исключила из беседы') ||
        t.contains('изменил название беседы') ||
        t.contains('изменила название беседы') ||
        t.contains('обновил фотографию беседы') ||
        t.contains('обновила фотографию беседы') ||
        t.contains('удалил фотографию беседы') ||
        t.contains('удалила фотографию беседы') ||
        t.contains('закрепил сообщение') ||
        t.contains('закрепила сообщение');
  }

  String get serviceDisplayText {
    final author = sender?.fullName ?? 'Пользователь';
    if (action != null) {
      return action!.displayText(author, fromId);
    }
    final trimmed = text.trim();
    if (trimmed.toLowerCase().startsWith(author.toLowerCase())) {
      return trimmed;
    }
    return '$author $trimmed';
  }

  bool get hasAttachments =>
      photos.isNotEmpty ||
      photo != null ||
      voiceMessage != null ||
      doc != null ||
      audio != null ||
      video != null ||
      sticker != null ||
      gift != null ||
      moneyTransfer != null ||
      wallPost != null;

  VKMessage copyWith({
    int? id,
    int? peerId,
    int? fromId,
    DateTime? date,
    String? text,
    bool? isOut,
    bool? readState,
    VKSticker? sticker,
    VKPhotoAttachment? photo,
    List<VKPhotoAttachment>? photos,
    VKVoiceAttachment? voice,
    VKDocAttachment? doc,
    List<VKDocAttachment>? docs,
    VKAudioAttachment? audio,
    List<VKAudioAttachment>? audioList,
    VKVideoAttachment? video,
    VKGiftAttachment? gift,
    VKMoneyTransferAttachment? moneyTransfer,
    VKWallPost? wallPost,
    VKMessageAction? action,
    VKUser? sender,
    VKReplyMessage? replyMessage,
    bool? isPinned,
    bool? isFailed,
    String? sendError,
  }) {
    return VKMessage(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      fromId: fromId ?? this.fromId,
      date: date ?? this.date,
      text: text ?? this.text,
      isOut: isOut ?? out,
      readState: readState ?? isRead,
      sticker: sticker ?? this.sticker,
      photo: photo ?? this.photo,
      photos: photos ?? this.photos,
      voice: voice ?? voiceMessage,
      doc: doc ?? this.doc,
      docs: docs ?? this.docs,
      audio: audio ?? this.audio,
      audioList: audioList ?? this.audioList,
      video: video ?? this.video,
      gift: gift ?? this.gift,
      moneyTransfer: moneyTransfer ?? this.moneyTransfer,
      wallPost: wallPost ?? this.wallPost,
      action: action ?? this.action,
      sender: sender ?? this.sender,
      replyMessage: replyMessage ?? this.replyMessage,
      isPinned: isPinned ?? this.isPinned,
      isFailed: isFailed ?? this.isFailed,
      sendError: sendError ?? this.sendError,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'peer_id': peerId,
        'from_id': fromId,
        'date': date.millisecondsSinceEpoch ~/ 1000,
        'text': text,
        'out': out ? 1 : 0,
        'is_read': isRead,
        'sticker': sticker?.toJson(),
        'photo': photo?.toJson(),
        'photos': photos.map((p) => p.toJson()).toList(),
        'voice': voiceMessage?.toJson(),
        'doc': doc?.toJson(),
        'audio': audio?.toJson(),
        'video': video?.toJson(),
        'gift': gift?.toJson(),
        'transfer': moneyTransfer?.toJson(),
        'action': action?.toJson(),
        'sender': sender?.toJson(),
        'reply': replyMessage?.toJson(),
        'is_pinned': isPinned,
      };

  factory VKMessage.fromJson(Map<String, dynamic> json) {
    DateTime d;
    final rawDate = json['date'];
    if (rawDate is int) {
      d = DateTime.fromMillisecondsSinceEpoch(rawDate * 1000);
    } else {
      final sec = int.tryParse('$rawDate') ?? 0;
      d = sec > 0 ? DateTime.fromMillisecondsSinceEpoch(sec * 1000) : DateTime.now();
    }

    VKMoneyTransferAttachment? transfer = json['transfer'] != null ? VKMoneyTransferAttachment.fromJson(json['transfer']) : null;
    final msgText = json['text']?.toString() ?? '';
    final msgId = json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0;
    final msgFromId = json['from_id'] is int ? json['from_id'] : int.tryParse('${json['from_id']}') ?? 0;
    if (transfer == null && VKMessage.isMoneyTransferText(msgText)) {
      final digitsMatch = RegExp(r'\d+').allMatches(msgText);
      final parsedAmount = digitsMatch.isNotEmpty ? int.tryParse(digitsMatch.first.group(0) ?? '') ?? 0 : 0;
      transfer = VKMoneyTransferAttachment(
        id: msgId,
        fromId: msgFromId,
        toId: 0,
        amount: parsedAmount,
        currency: 'голосов',
        comment: msgText,
      );
    }

    return VKMessage(
      id: msgId,
      peerId: json['peer_id'] is int ? json['peer_id'] : int.tryParse('${json['peer_id']}') ?? 0,
      fromId: msgFromId,
      date: d,
      text: msgText,
      out: json['out'] == 1 || json['out'] == true,
      isRead: json['is_read'] == true,
      sticker: json['sticker'] != null ? VKSticker.fromJson(json['sticker']) : null,
      photo: json['photo'] != null ? VKPhotoAttachment.fromJson(json['photo']) : null,
      photos: json['photos'] is List ? (json['photos'] as List).map((p) => VKPhotoAttachment.fromJson(p)).toList() : [],
      voiceMessage: json['voice'] != null ? VKVoiceAttachment.fromJson(json['voice']) : null,
      doc: json['doc'] != null ? VKDocAttachment.fromJson(json['doc']) : null,
      audio: json['audio'] != null ? VKAudioAttachment.fromJson(json['audio']) : null,
      video: json['video'] != null ? VKVideoAttachment.fromJson(json['video']) : null,
      gift: json['gift'] != null ? VKGiftAttachment.fromJson(json['gift']) : null,
      moneyTransfer: transfer,
      action: json['action'] != null ? VKMessageAction.fromJson(json['action']) : null,
      sender: json['sender'] != null ? VKUser.fromJson(json['sender']) : null,
      replyMessage: json['reply'] != null ? VKReplyMessage.fromJson(json['reply']) : null,
      isPinned: json['is_pinned'] == true,
    );
  }
}
