import '../services/openvk_api.dart';
import 'message.dart';

class VKConversation {
  final int peerId;
  final String title;
  final String? avatarURL;
  int unreadCount;
  bool hasUnreadMention;
  VKMessage? lastMessage;
  int? lastMessageId;
  VKMessage? pinnedMessage;
  bool isOnline;
  bool isMobile;
  DateTime? lastSeen;
  int? sex;
  int membersCount;

  VKConversation({
    required this.peerId,
    required this.title,
    this.avatarURL,
    this.unreadCount = 0,
    this.hasUnreadMention = false,
    this.lastMessage,
    this.lastMessageId,
    this.pinnedMessage,
    this.isOnline = false,
    this.isMobile = false,
    this.lastSeen,
    this.sex,
    this.membersCount = 0,
  });

  String? get photoUrl => isSavedMessages ? null : avatarURL;

  bool get isSavedMessages {
    final curUid = OpenVKAPIService.instance.currentUserId ?? OpenVKAPIService.instance.currentUser?.id;
    if (curUid != null && curUid > 0 && peerId == curUid) {
      return true;
    }
    return peerId > 0 && peerId < 2000000000 && (title == 'Избранное' || title == 'Saved Messages');
  }

  String get displayTitle => isSavedMessages ? 'Избранное' : title;

  bool get isGroupChat => peerId >= 2000000000;

  VKConversation copyWith({
    int? peerId,
    String? title,
    String? avatarURL,
    int? unreadCount,
    bool? hasUnreadMention,
    VKMessage? lastMessage,
    int? lastMessageId,
    VKMessage? pinnedMessage,
    bool clearPinnedMessage = false,
    bool? isOnline,
    bool? isMobile,
    DateTime? lastSeen,
    int? sex,
    int? membersCount,
  }) {
    return VKConversation(
      peerId: peerId ?? this.peerId,
      title: title ?? this.title,
      avatarURL: avatarURL ?? this.avatarURL,
      unreadCount: unreadCount ?? this.unreadCount,
      hasUnreadMention: hasUnreadMention ?? this.hasUnreadMention,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      pinnedMessage: clearPinnedMessage ? null : (pinnedMessage ?? this.pinnedMessage),
      isOnline: isOnline ?? this.isOnline,
      isMobile: isMobile ?? this.isMobile,
      lastSeen: lastSeen ?? this.lastSeen,
      sex: sex ?? this.sex,
      membersCount: membersCount ?? this.membersCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'peer_id': peerId,
        'title': title,
        'avatar_url': avatarURL,
        'unread_count': unreadCount,
        'last_message': lastMessage?.toJson(),
        'last_message_id': lastMessageId,
        'pinned_message': pinnedMessage?.toJson(),
        'is_online': isOnline,
        'is_mobile': isMobile,
        'last_seen': lastSeen != null ? lastSeen!.millisecondsSinceEpoch ~/ 1000 : null,
        'sex': sex,
        'members_count': membersCount,
      };

  factory VKConversation.fromJson(Map<String, dynamic> json) {
    DateTime? ls;
    if (json['last_seen'] != null) {
      final sec = json['last_seen'] is int ? json['last_seen'] : int.tryParse('${json['last_seen']}') ?? 0;
      if (sec > 0) ls = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    }

    return VKConversation(
      peerId: json['peer_id'] is int ? json['peer_id'] : int.tryParse('${json['peer_id']}') ?? 0,
      title: json['title']?.toString() ?? 'Диалог',
      avatarURL: json['avatar_url']?.toString(),
      unreadCount: json['unread_count'] is int ? json['unread_count'] : int.tryParse('${json['unread_count']}') ?? 0,
      lastMessage: json['last_message'] != null ? VKMessage.fromJson(json['last_message']) : null,
      lastMessageId: json['last_message_id'] is int ? json['last_message_id'] : null,
      pinnedMessage: json['pinned_message'] != null ? VKMessage.fromJson(json['pinned_message']) : null,
      isOnline: json['is_online'] == true || json['is_online'] == 1,
      isMobile: json['is_mobile'] == true || json['is_mobile'] == 1,
      lastSeen: ls,
      sex: json['sex'] is int ? json['sex'] : int.tryParse('${json['sex']}'),
      membersCount: json['members_count'] is int ? json['members_count'] : int.tryParse('${json['members_count']}') ?? 0,
    );
  }
}

class VKChatFolder {
  final String id;
  String name;
  String icon;
  List<int> peerIds;

  VKChatFolder({
    required this.id,
    required this.name,
    this.icon = 'folder',
    this.peerIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'peer_ids': peerIds,
      };

  factory VKChatFolder.fromJson(Map<String, dynamic> json) {
    List<int> ids = [];
    if (json['peer_ids'] is List) {
      ids = (json['peer_ids'] as List).map((e) => (e is int ? e : int.tryParse('$e') ?? 0)).toList();
    }
    return VKChatFolder(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Папка',
      icon: json['icon']?.toString() ?? 'folder',
      peerIds: ids,
    );
  }
}
