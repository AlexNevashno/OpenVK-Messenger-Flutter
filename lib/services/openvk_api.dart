import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/attachment.dart';

typedef OpenVKApi = OpenVKAPIService;

class OpenVKAPIService {
  static final OpenVKAPIService instance = OpenVKAPIService._();
  OpenVKAPIService._();

  String serverURL = 'https://openvk.org';
  String token = '';
  int? currentUserId;
  VKUser? currentUser;
  String? chandlerSessCookie;
  String? savedLogin;
  String? savedPassword;

  final Map<int, VKUser> cachedUsers = {};
  final Map<int, VKGroup> cachedGroups = {};
  final Map<int, int> peerOutRead = {};
  final Map<int, int> peerInRead = {};

  bool get isAuthenticated => token.isNotEmpty;

  void setCredentials({
    required String token,
    required String serverURL,
    String? chandlerCookie,
    int? userId,
  }) {
    this.token = token;
    if (userId != null && userId > 0) {
      currentUserId = userId;
    }
    if (serverURL.isNotEmpty) {
      this.serverURL = serverURL.startsWith('http') ? serverURL : 'https://$serverURL';
    }
    if (chandlerCookie != null) {
      chandlerSessCookie = chandlerCookie;
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('openvk_token') ?? '';
    serverURL = prefs.getString('openvk_server') ?? 'https://openvk.org';
    chandlerSessCookie = prefs.getString('openvk_chandlersess');
    savedLogin = prefs.getString('openvk_saved_login');
    savedPassword = prefs.getString('openvk_saved_password');

    if (savedLogin != null && savedPassword != null) {
      ensureWebSession(savedLogin!, savedPassword!).catchError((_) {});
    }

    if (isAuthenticated) {
      try {
        await refreshCurrentUser();
      } catch (_) {}
    }
  }

  void saveCredentials(String newToken, String newServer) async {
    token = newToken;
    serverURL = newServer;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openvk_token', newToken);
    await prefs.setString('openvk_server', newServer);
  }

  Future<void> logout() async {
    token = '';
    currentUser = null;
    chandlerSessCookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('openvk_token');
    await prefs.remove('openvk_chandlersess');
  }

  // MARK: - Auth
  Future<Map<String, dynamic>> authWithPassword({
    required String serverURL,
    required String login,
    required String password,
  }) async {
    String sUrl = serverURL.trim();
    if (!sUrl.startsWith('http')) sUrl = 'https://$sUrl';
    this.serverURL = sUrl;

    final url = Uri.parse('$sUrl/oauth/token').replace(queryParameters: {
      'grant_type': 'password',
      'client_id': '2274003',
      'client_secret': 'hHbZxrka2uZ6jB1inYsH',
      'username': login,
      'password': password,
      'scope': 'messages,offline,wall,photos,audio,docs',
    });

    final res = await http.post(url, headers: {'User-Agent': 'OpenVKMessenger-Desktop/1.0'});
    if (res.statusCode != 200) {
      try {
        final errJson = jsonDecode(res.body);
        throw Exception(errJson['error_description'] ?? errJson['error'] ?? 'Ошибка авторизации');
      } catch (_) {
        throw Exception('Ошибка авторизации (HTTP ${res.statusCode})');
      }
    }

    final data = jsonDecode(res.body);
    final accessToken = data['access_token']?.toString() ?? '';
    final userId = data['user_id'] is int ? data['user_id'] : int.tryParse('${data['user_id']}') ?? 0;
    if (accessToken.isEmpty) throw Exception('Не получен access_token');

    token = accessToken;
    await ensureWebSession(login, password);

    return {
      'token': accessToken,
      'userId': userId,
      'cookie': chandlerSessCookie,
    };
  }

  Future<void> login(String login, String password, [String? server]) async {
    await authWithPassword(
      serverURL: server ?? serverURL,
      login: login,
      password: password,
    );
    await refreshCurrentUser();
  }

  Future<void> loginWithToken(String t, [String? server]) async {
    if (server != null && server.isNotEmpty) {
      serverURL = server.trim();
      if (!serverURL.startsWith('http')) serverURL = 'https://$serverURL';
    }
    saveCredentials(t.trim(), serverURL);
    await refreshCurrentUser();
  }

  Future<void> ensureWebSession(String login, String password) async {
    try {
      final client = http.Client();
      final loginUrl = Uri.parse('$serverURL/login.php');
      final res = await client.post(
        loginUrl,
        body: {'login': login, 'password': password},
        headers: {'User-Agent': 'Mozilla/5.0 OpenVKMessenger'},
      );

      final rawCookies = res.headers['set-cookie'];
      if (rawCookies != null) {
        final match = RegExp(r'chandlersess=([^;,\s]+)').firstMatch(rawCookies);
        if (match != null) {
          chandlerSessCookie = match.group(1);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('openvk_chandlersess', chandlerSessCookie!);
        }
      }
    } catch (_) {}
  }

  // MARK: - Generic Call
  Future<dynamic> callMethod(String method, Map<String, String> params) async {
    final query = Map<String, String>.from(params);
    query['access_token'] = token;
    query['v'] = '5.131';

    final uri = Uri.parse('$serverURL/method/$method').replace(queryParameters: query);
    final res = await http.get(uri, headers: {'User-Agent': 'OpenVKMessenger-Desktop/1.0'});

    if (res.statusCode != 200) {
      throw Exception('Ошибка сервера ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data['error'] != null) {
      final e = data['error'];
      throw Exception('[${e['error_code']}] ${e['error_msg']}');
    }

    return data['response'];
  }

  Future<VKUser?> fetchUserProfile(int userId) async {
    final params = {'fields': 'photo_100,photo_200,photo_max,verified,online,sex,last_seen'};
    if (userId > 0) {
      params['user_ids'] = '$userId';
    }
    final resp = await callMethod('users.get', params);
    if (resp is List && resp.isNotEmpty) {
      final user = VKUser.fromJson(resp.first);
      if (userId == 0 || user.id == currentUser?.id) {
        currentUser = user;
      }
      cachedUsers[user.id] = user;
      return user;
    }
    return null;
  }

  Future<List<VKUser>> getUsers(List<int> userIds) async {
    if (userIds.isEmpty) return [];
    final params = {
      'user_ids': userIds.join(','),
      'fields': 'photo_100,photo_200,photo_max,verified,online,sex,last_seen',
    };
    final resp = await callMethod('users.get', params);
    final List<VKUser> users = [];
    if (resp is List) {
      for (final item in resp) {
        if (item is Map<String, dynamic>) {
          final u = VKUser.fromJson(item);
          cachedUsers[u.id] = u;
          users.add(u);
        }
      }
    }
    return users;
  }

  Future<List<VKGroup>> getGroups(List<int> groupIds) async {
    if (groupIds.isEmpty) return [];
    try {
      final resp = await callMethod('groups.getById', {
        'group_ids': groupIds.map((id) => id.abs()).join(','),
        'fields': 'photo_50,photo_100,photo_200',
      });
      final List<VKGroup> groups = [];
      dynamic items;
      if (resp is List) {
        items = resp;
      } else if (resp is Map) {
        items = resp['items'] ?? resp['response'] ?? [resp];
      }
      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            final g = VKGroup.fromJson(Map<String, dynamic>.from(item));
            cachedGroups[g.id] = g;
            groups.add(g);
          }
        }
      }
      return groups;
    } catch (_) {
      return [];
    }
  }

  Future<VKUser> refreshCurrentUser() async {
    final u = await fetchUserProfile(0);
    if (u != null) return u;
    throw Exception('Не удалось загрузить профиль пользователя');
  }

  // MARK: - Conversations
  Future<List<VKConversation>> fetchConversations({int offset = 0, int count = 40}) async {
    return getConversations(offset: offset, count: count);
  }

  Future<List<VKConversation>> getConversations({int offset = 0, int count = 40}) async {
    final resp = await callMethod('messages.getConversations', {
      'offset': '$offset',
      'count': '$count',
      'extended': '1',
      'fields': 'photo_100,photo_200,verified,online,online_mobile,last_seen,sex',
    });

    final profiles = <int, VKUser>{};
    if (resp['profiles'] is List) {
      for (final p in resp['profiles']) {
        final u = VKUser.fromJson(p);
        profiles[u.id] = u;
        cachedUsers[u.id] = u;
      }
    }

    if (resp['groups'] is List) {
      for (final g in resp['groups']) {
        final gr = VKGroup.fromJson(g);
        cachedGroups[gr.id] = gr;
        profiles[-gr.id] = VKUser(
          id: -gr.id,
          firstName: gr.name,
          lastName: '',
          photo100: gr.photo100,
          photo200: gr.photo200,
        );
      }
    }

    final items = resp['items'] as List? ?? [];
    final List<VKConversation> convList = [];

    for (final item in items) {
      final conv = item['conversation'] as Map<String, dynamic>? ?? {};
      final peer = conv['peer'] as Map<String, dynamic>? ?? {};
      final int peerId = peer['id'] is int ? peer['id'] : int.tryParse('${peer['id']}') ?? 0;
      final int unread = conv['unread_count'] is int ? conv['unread_count'] : int.tryParse('${conv['unread_count']}') ?? 0;

      final int outReadId = conv['out_read'] is int ? conv['out_read'] : int.tryParse('${conv['out_read']}') ?? 0;
      final int inReadId = conv['in_read'] is int ? conv['in_read'] : int.tryParse('${conv['in_read']}') ?? 0;
      peerOutRead[peerId] = outReadId;
      peerInRead[peerId] = inReadId;

      VKMessage? lastMsg;
      if (item['last_message'] != null) {
        lastMsg = _mapRawMessage(item['last_message'] as Map<String, dynamic>, profiles, peerId);
      }

      VKMessage? pinnedMsg;
      final chatSettings = conv['chat_settings'];
      if (chatSettings is Map && chatSettings['pinned_message'] != null) {
        pinnedMsg = _mapRawMessage(chatSettings['pinned_message'] as Map<String, dynamic>, profiles, peerId);
      }

      String title = 'Диалог';
      String? avatarURL;
      bool isOnline = false;
      bool isMobile = false;
      DateTime? lastSeen;
      int? sex;

      if (peerId >= 2000000000) {
        if (chatSettings is Map) {
          title = chatSettings['title']?.toString() ?? 'Беседа';
          final photo = chatSettings['photo'];
          if (photo is Map) {
            avatarURL = photo['photo_200']?.toString() ?? photo['photo_100']?.toString();
          }
        }
      } else if (peerId < 0) {
        final gr = cachedGroups[-peerId];
        title = gr?.name ?? 'Сообщество';
        avatarURL = gr?.avatarUrl;
      } else {
        final isSaved = (currentUser != null && peerId == currentUser!.id) || title == 'Избранное';
        if (isSaved) {
          title = 'Избранное';
        } else {
          final u = profiles[peerId] ?? cachedUsers[peerId];
          if (u != null) {
            title = u.fullName;
            avatarURL = u.avatarUrl;
            isOnline = u.isOnline;
            isMobile = u.isMobile;
            lastSeen = u.lastSeen;
            sex = u.sex;
          }
        }
      }

      convList.add(VKConversation(
        peerId: peerId,
        title: title,
        avatarURL: avatarURL,
        unreadCount: unread,
        lastMessage: lastMsg,
        pinnedMessage: pinnedMsg,
        isOnline: isOnline,
        isMobile: isMobile,
        lastSeen: lastSeen,
        sex: sex,
      ));
    }

    return convList;
  }

  // MARK: - History
  Future<List<VKMessage>> fetchHistory({required int peerId, int offset = 0, int count = 40}) async {
    return getHistory(peerId: peerId, offset: offset, count: count);
  }

  Future<List<VKMessage>> getHistory({required int peerId, int offset = 0, int count = 40}) async {
    final resp = await callMethod('messages.getHistory', {
      'peer_id': '$peerId',
      'offset': '$offset',
      'count': '$count',
      'extended': '1',
      'fields': 'photo_100,photo_200,verified,online,online_mobile,last_seen,sex',
    });

    final profiles = <int, VKUser>{};
    if (resp['profiles'] is List) {
      for (final p in resp['profiles']) {
        final u = VKUser.fromJson(p);
        profiles[u.id] = u;
        cachedUsers[u.id] = u;
      }
    }

    if (resp['groups'] is List) {
      for (final g in resp['groups']) {
        final gr = VKGroup.fromJson(g);
        cachedGroups[gr.id] = gr;
        profiles[-gr.id] = VKUser(
          id: -gr.id,
          firstName: gr.name,
          lastName: '',
          photo100: gr.photo100,
          photo200: gr.photo200,
        );
      }
    }

    final items = resp['items'] as List? ?? [];

    final missingUserIds = <int>{};
    final missingGroupIds = <int>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final fid = raw['from_id'] is int ? raw['from_id'] : int.tryParse('${raw['from_id']}') ?? 0;
      if (fid != 0 && !profiles.containsKey(fid) && !cachedUsers.containsKey(fid)) {
        if (fid > 0) {
          missingUserIds.add(fid);
        } else {
          missingGroupIds.add(-fid);
        }
      }
      // Check reply/fwd sender
      int repFid = 0;
      if (raw['reply_message'] is Map) {
        repFid = raw['reply_message']['from_id'] is int
            ? raw['reply_message']['from_id']
            : int.tryParse('${raw['reply_message']['from_id']}') ?? 0;
      } else if (raw['fwd_messages'] is List && (raw['fwd_messages'] as List).isNotEmpty && (raw['fwd_messages'] as List).first is Map) {
        repFid = (raw['fwd_messages'] as List).first['from_id'] is int
            ? (raw['fwd_messages'] as List).first['from_id']
            : int.tryParse('${(raw['fwd_messages'] as List).first['from_id']}') ?? 0;
      }
      if (repFid != 0 && !profiles.containsKey(repFid) && !cachedUsers.containsKey(repFid)) {
        if (repFid > 0) {
          missingUserIds.add(repFid);
        } else {
          missingGroupIds.add(-repFid);
        }
      }
    }
    if (missingUserIds.isNotEmpty) {
      try {
        final fetched = await getUsers(missingUserIds.toList());
        for (final u in fetched) {
          profiles[u.id] = u;
          cachedUsers[u.id] = u;
        }
      } catch (_) {}
    }
    if (missingGroupIds.isNotEmpty) {
      try {
        final fetchedG = await getGroups(missingGroupIds.toList());
        for (final g in fetchedG) {
          cachedGroups[g.id] = g;
          profiles[-g.id] = VKUser(
            id: -g.id,
            firstName: g.name,
            lastName: '',
            photo100: g.photo100,
            photo200: g.photo200,
          );
        }
      } catch (_) {}
    }

    final List<VKMessage> list = [];
    for (final raw in items) {
      list.add(_mapRawMessage(raw, profiles, peerId));
    }

    list.sort((a, b) {
      if (a.date == b.date) return a.id.compareTo(b.id);
      return a.date.compareTo(b.date);
    });

    return list;
  }

  VKMessage _mapRawMessage(Map<String, dynamic> raw, Map<int, VKUser> profiles, int defaultPeerId) {
    final int fromId = raw['from_id'] is int ? raw['from_id'] : int.tryParse('${raw['from_id']}') ?? 0;
    final int id = raw['id'] is int ? raw['id'] : int.tryParse('${raw['id']}') ?? 0;
    final int peerId = raw['peer_id'] is int ? raw['peer_id'] : (int.tryParse('${raw['peer_id']}') ?? defaultPeerId);

    DateTime date = DateTime.now();
    if (raw['date'] != null) {
      final sec = raw['date'] is int ? raw['date'] : int.tryParse('${raw['date']}') ?? 0;
      if (sec > 0) date = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    }

    final bool out = raw['out'] == 1 || raw['out'] == true || (currentUser != null && fromId == currentUser!.id);

    VKUser? sender = profiles[fromId] ?? cachedUsers[fromId];
    if (sender == null && fromId < 0) {
      final gr = cachedGroups[-fromId];
      if (gr != null) {
        sender = VKUser(id: -gr.id, firstName: gr.name, lastName: '', photo100: gr.photo100, photo200: gr.photo200);
      }
    }

    VKReplyMessage? reply;
    final repMap = raw['reply_message'] is Map
        ? raw['reply_message']
        : (raw['fwd_messages'] is List && (raw['fwd_messages'] as List).isNotEmpty && (raw['fwd_messages'] as List).first is Map
            ? (raw['fwd_messages'] as List).first
            : null);
    if (repMap is Map) {
      final repRaw = Map<String, dynamic>.from(repMap);
      final repFrom = repRaw['from_id'] is int ? repRaw['from_id'] : int.tryParse('${repRaw['from_id']}') ?? 0;
      final repSender = profiles[repFrom] ?? cachedUsers[repFrom];
      DateTime? repDate;
      if (repRaw['date'] != null) {
        final sec = repRaw['date'] is int ? repRaw['date'] : int.tryParse('${repRaw['date']}') ?? 0;
        if (sec > 0) repDate = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
      }
      String? rPhotoUrl;
      bool rHasPhoto = false;
      if (repRaw['attachments'] is List) {
        for (final att in repRaw['attachments']) {
          if (att is Map && (att['type'] == 'photo' || att['photo'] != null)) {
            rHasPhoto = true;
            final p = att['photo'] is Map ? att['photo'] : att;
            rPhotoUrl = p['photo_604']?.toString() ?? p['photo_130']?.toString() ?? p['photo_75']?.toString();
            break;
          }
        }
      }
      reply = VKReplyMessage(
        id: repRaw['id'] is int ? repRaw['id'] : int.tryParse('${repRaw['id']}') ?? 0,
        fromId: repFrom,
        senderName: repSender?.fullName ?? 'id$repFrom',
        senderAvatarURL: repSender?.photoURL,
        date: repDate,
        text: repRaw['text']?.toString() ?? '',
        photoURL: rPhotoUrl,
        hasPhoto: rHasPhoto,
      );
    }

    VKMessageAction? action;
    if (raw['action'] is Map) {
      action = VKMessageAction.fromJson(raw['action'] as Map<String, dynamic>);
    }

    VKSticker? sticker;
    VKPhotoAttachment? photo;
    List<VKPhotoAttachment> photos = [];
    VKDocAttachment? doc;
    VKVoiceAttachment? voice;
    VKAudioAttachment? audio;
    VKVideoAttachment? video;
    VKGiftAttachment? gift;
    VKMoneyTransferAttachment? transfer;
    VKWallPost? wallPost;

    if (raw['attachments'] is List) {
      for (final att in raw['attachments']) {
        if (att is! Map) continue;
        final type = att['type']?.toString();
        if (type == 'sticker' && att['sticker'] != null) {
          sticker = VKSticker.fromJson(att['sticker']);
        } else if (type == 'photo' && att['photo'] != null) {
          final p = VKPhotoAttachment.fromJson(att['photo']);
          photo ??= p;
          photos.add(p);
        } else if (type == 'doc' && att['doc'] != null) {
          doc = VKDocAttachment.fromJson(att['doc']);
        } else if ((type == 'audio_message' || type == 'voice') && (att['audio_message'] != null || att['voice'] != null)) {
          final vMap = att['audio_message'] is Map ? att['audio_message'] : (att['voice'] is Map ? att['voice'] : att);
          voice = VKVoiceAttachment.fromJson(Map<String, dynamic>.from(vMap), serverUrl: serverURL);
        } else if (type == 'audio' && att['audio'] != null) {
          audio = VKAudioAttachment.fromJson(Map<String, dynamic>.from(att['audio']), serverUrl: serverURL);
        } else if (type == 'video' && att['video'] != null) {
          video = VKVideoAttachment.fromJson(Map<String, dynamic>.from(att['video']), serverUrl: serverURL);
        } else if (type == 'gift' || att['gift'] != null) {
          final gMap = att['gift'] is Map ? att['gift'] : att;
          gift = VKGiftAttachment.fromJson(Map<String, dynamic>.from(gMap));
        } else if (type == 'money_transfer' || type == 'transfer' || type == 'money_request' || att['money_transfer'] != null || att['transfer'] != null) {
          final mMap = att['money_transfer'] is Map ? att['money_transfer'] : (att['transfer'] is Map ? att['transfer'] : att);
          transfer = VKMoneyTransferAttachment.fromJson(Map<String, dynamic>.from(mMap));
        } else if ((type == 'wall' || type == 'wall_reply') && att['wall'] != null) {
          wallPost = VKWallPost.fromJson(Map<String, dynamic>.from(att['wall']));
        }
      }
    }

    final rawText = raw['text']?.toString() ?? '';
    if (transfer == null && VKMessage.isMoneyTransferText(rawText)) {
      final digitsMatch = RegExp(r'\d+').allMatches(rawText);
      final parsedAmount = digitsMatch.isNotEmpty ? int.tryParse(digitsMatch.first.group(0) ?? '') ?? 0 : 0;
      transfer = VKMoneyTransferAttachment(
        id: id,
        fromId: fromId,
        toId: 0,
        amount: parsedAmount,
        currency: 'голосов',
        comment: rawText,
      );
    }

    return VKMessage(
      id: id,
      peerId: peerId,
      fromId: fromId,
      date: date,
      text: raw['text']?.toString() ?? '',
      out: out,
      isRead: raw['read_state'] == 1 || raw['is_read'] == true,
      sender: sender,
      replyMessage: reply,
      action: action,
      sticker: sticker,
      photo: photo,
      photos: photos,
      doc: doc,
      voiceMessage: voice,
      audio: audio,
      video: video,
      gift: gift,
      moneyTransfer: transfer,
      wallPost: wallPost,
    );
  }

  // MARK: - Send Message
  Future<int> sendMessage({
    required int peerId,
    String message = '',
    String text = '',
    String? attachmentStr,
    String? attachment,
    int? replyTo,
    int? stickerId,
    int? groupId,
  }) async {
    final msg = message.isNotEmpty ? message : text;
    final att = attachmentStr ?? attachment;

    final params = {
      'peer_id': '$peerId',
      'random_id': '${DateTime.now().millisecondsSinceEpoch}',
      'message': msg,
    };
    if (att != null && att.isNotEmpty) {
      params['attachment'] = att;
      params['attachments'] = att;
    }
    if (replyTo != null && replyTo > 0) {
      params['reply_to'] = '$replyTo';
    }
    if (stickerId != null && stickerId > 0) {
      params['sticker_id'] = '$stickerId';
    }
    if (groupId != null && groupId > 0) {
      params['group_id'] = '$groupId';
    }

    final resp = await callMethod('messages.send', params);
    if (resp is int) return resp;
    if (resp is Map && resp['message_id'] != null) {
      return resp['message_id'] is int ? resp['message_id'] : int.tryParse('${resp['message_id']}') ?? 0;
    }
    return int.tryParse('$resp') ?? 0;
  }

  // MARK: - Document Upload with Format Bypass (.themepack -> .txt)
  Future<VKDocAttachment> uploadDocument({
    required File file,
    required int peerId,
    int? groupId,
  }) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    final bytes = await file.readAsBytes();

    String safeFilename = filename;
    final lower = filename.toLowerCase();
    if (lower.endsWith('.themepack') || lower.endsWith('.attheme') || lower.endsWith('.tdesktop-theme') || lower.endsWith('.tgios-theme')) {
      if (!lower.endsWith('.txt')) {
        safeFilename = '$filename.txt';
      }
    }

    // 1. Try web upload via chandlersess cookie
    if (chandlerSessCookie != null && chandlerSessCookie!.isNotEmpty) {
      try {
        final webUrl = Uri.parse('$serverURL/upload.php?act=a_add_doc');
        final req = http.MultipartRequest('POST', webUrl);
        req.headers['Cookie'] = 'chandlersess=$chandlerSessCookie';
        req.headers['User-Agent'] = 'Mozilla/5.0 OpenVKMessenger';
        req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: safeFilename));

        final streamRes = await req.send();
        final bodyStr = await streamRes.stream.bytesToString();

        try {
          final resJson = jsonDecode(bodyStr);
          final docData = resJson['document'] ?? resJson['doc'];
          if (docData != null) {
            final owner = docData['owner_id'] ?? currentUser?.id ?? 0;
            final docId = docData['id'] ?? docData['doc_id'] ?? 0;
            final accessKey = docData['access_key'];
            if (docId != 0) {
              return VKDocAttachment(
                id: docId,
                ownerId: owner,
                title: filename,
                size: bytes.length,
                ext: filename.contains('.') ? filename.split('.').last : 'bin',
                url: docData['url']?.toString(),
                accessKey: accessKey?.toString(),
              );
            }
          }
        } catch (_) {}
      } catch (_) {}
    }

    // 2. Standard API fallback
    final params = {'type': 'doc', 'peer_id': '$peerId'};
    if (groupId != null && groupId > 0) params['group_id'] = '$groupId';
    final serverResp = await callMethod('docs.getMessagesUploadServer', params);
    final uploadUrl = Uri.parse(serverResp['upload_url']?.toString() ?? '');

    final req = http.MultipartRequest('POST', uploadUrl);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: safeFilename));
    final streamRes = await req.send();
    final bodyStr = await streamRes.stream.bytesToString();
    final uploadResult = jsonDecode(bodyStr);

    final saveParams = <String, String>{
      'file': uploadResult['file']?.toString() ?? '',
      'title': safeFilename,
    };
    final saveResp = await callMethod('docs.save', saveParams);
    final rawDoc = (saveResp is Map && saveResp['doc'] != null)
        ? saveResp['doc']
        : (saveResp is List && saveResp.isNotEmpty ? saveResp.first : saveResp);
    final Map<String, dynamic> docItem = rawDoc is Map ? Map<String, dynamic>.from(rawDoc) : <String, dynamic>{};
    if (docItem['owner_id'] == null || docItem['owner_id'] == 0) {
      docItem['owner_id'] = currentUser?.id ?? 0;
    }

    return VKDocAttachment.fromJson(docItem);
  }

  // MARK: - Photo Upload
  Future<VKPhotoAttachment> uploadPhoto({
    required File file,
    required int peerId,
    int? groupId,
  }) async {
    final bytes = await file.readAsBytes();
    final filename = file.path.split(Platform.pathSeparator).last;

    final params = {'peer_id': '$peerId'};
    if (groupId != null && groupId > 0) params['group_id'] = '$groupId';
    final serverResp = await callMethod('photos.getMessagesUploadServer', params);
    final uploadUrl = Uri.parse(serverResp['upload_url']?.toString() ?? '');

    final req = http.MultipartRequest('POST', uploadUrl);
    req.files.add(http.MultipartFile.fromBytes('photo', bytes, filename: filename));
    final streamRes = await req.send();
    final bodyStr = await streamRes.stream.bytesToString();
    final uploadResult = jsonDecode(bodyStr);

    final saveParams = <String, String>{
      'photo': uploadResult['photo']?.toString() ?? '',
      'server': '${uploadResult['server']}',
      'hash': uploadResult['hash']?.toString() ?? '',
    };
    final saveResp = await callMethod('photos.saveMessagesPhoto', saveParams);
    final rawPhoto = (saveResp is List && saveResp.isNotEmpty) ? saveResp.first : saveResp;
    final Map<String, dynamic> photoItem = rawPhoto is Map ? Map<String, dynamic>.from(rawPhoto) : <String, dynamic>{};
    if (photoItem['owner_id'] == null || photoItem['owner_id'] == 0) {
      photoItem['owner_id'] = currentUser?.id ?? 0;
    }

    return VKPhotoAttachment.fromJson(photoItem);
  }

  // MARK: - Admin Groups
  Future<List<VKGroup>> fetchAdminGroups() async {
    final resp = await callMethod('groups.get', {
      'filter': 'admin,editor',
      'extended': '1',
      'fields': 'photo_100,photo_200',
    });
    final items = resp['items'] as List? ?? [];
    return items.map((g) => VKGroup.fromJson(g)).toList();
  }

  // MARK: - Stickers
  List<VKStickerPack>? _cachedPacks;

  Future<List<VKStickerPack>> fetchStickerPacks() async {
    final base = serverURL.replaceAll(RegExp(r'/+$'), '');

    // 1. Return in-memory cache if available
    if (_cachedPacks != null && _cachedPacks!.isNotEmpty) {
      _fetchStickerPacksNetwork(base);
      return _cachedPacks!;
    }

    // 2. Try loading from persistent disk cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('openvk_cached_sticker_packs');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as List;
        final packs = decoded
            .whereType<Map>()
            .map((m) => VKStickerPack.fromJson(Map<String, dynamic>.from(m), baseUrl: base))
            .where((p) => p.stickers.isNotEmpty)
            .toList();
        if (packs.isNotEmpty) {
          _cachedPacks = packs;
          _fetchStickerPacksNetwork(base);
          return packs;
        }
      }
    } catch (_) {}

    // 3. Fallback to network
    final networkPacks = await _fetchStickerPacksNetwork(base);
    if (networkPacks.isNotEmpty) return networkPacks;

    return defaultStickerPacks(base);
  }

  Future<List<VKStickerPack>> _fetchStickerPacksNetwork(String base) async {
    if (!isAuthenticated) return [];
    List<VKStickerPack> packs = [];
    try {
      final resp = await callMethod('stickers.get', {'count': '50'});
      final items = resp['items'] as List? ?? (resp is List ? resp : []);
      packs = _parseStickerPacks(items, base);
    } catch (_) {
      try {
        final resp = await callMethod('stickers.getAll', {'count': '50'});
        final items = resp['items'] as List? ?? (resp is List ? resp : []);
        packs = _parseStickerPacks(items, base);
      } catch (_) {}
    }

    if (packs.isNotEmpty) {
      _cachedPacks = packs;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'openvk_cached_sticker_packs',
          jsonEncode(packs.map((p) => p.toJson()).toList()),
        );
      } catch (_) {}
    }
    return packs;
  }

  List<VKStickerPack> _parseStickerPacks(List items, String base) {
    final List<VKStickerPack> packs = [];
    for (final item in items) {
      if (item is Map) {
        final p = item['product'] ?? item;
        if (p is Map) {
          final pack = VKStickerPack.fromJson(Map<String, dynamic>.from(p), baseUrl: base);
          if (pack.stickers.isNotEmpty) {
            packs.add(pack);
          }
        }
      }
    }
    return packs;
  }

  List<VKStickerPack> defaultStickerPacks(String base) {
    final cleanBase = base.replaceAll(RegExp(r'/+$'), '');
    final persikStickers = List.generate(32, (i) {
      final id = i + 1;
      return VKStickerItem(
        id: id,
        packId: 1,
        url: '$cleanBase/images/stickers/$id/256b.png',
      );
    });

    final spottyStickers = List.generate(32, (i) {
      final id = i + 49;
      return VKStickerItem(
        id: id,
        packId: 2,
        url: '$cleanBase/images/stickers/$id/256b.png',
      );
    });

    final senyaStickers = List.generate(32, (i) {
      final id = i + 81;
      return VKStickerItem(
        id: id,
        packId: 3,
        url: '$cleanBase/images/stickers/$id/256b.png',
      );
    });

    return [
      VKStickerPack(
        id: 1,
        title: 'Персик',
        iconURL: '$cleanBase/images/stickers/1/256b.png',
        stickers: persikStickers,
      ),
      VKStickerPack(
        id: 2,
        title: 'Спотти',
        iconURL: '$cleanBase/images/stickers/49/256b.png',
        stickers: spottyStickers,
      ),
      VKStickerPack(
        id: 3,
        title: 'Сеня',
        iconURL: '$cleanBase/images/stickers/81/256b.png',
        stickers: senyaStickers,
      ),
    ];
  }

  // MARK: - Mark as read, Pin, Unpin, Delete
  Future<void> markAsRead({required int peerId, required int startMessageId}) async {
    await callMethod('messages.markAsRead', {
      'peer_id': '$peerId',
      'start_message_id': '$startMessageId',
    });
  }

  Future<void> deleteMessage({required int messageId, bool forAll = true}) async {
    await callMethod('messages.delete', {
      'message_ids': '$messageId',
      'delete_for_all': forAll ? '1' : '0',
    });
  }

  Future<void> editMessage({
    required int peerId,
    required int messageId,
    required String message,
  }) async {
    await callMethod('messages.edit', {
      'peer_id': '$peerId',
      'message_id': '$messageId',
      'message': message,
      'keep_forward_messages': '1',
      'keep_snippets': '1',
    });
  }

  Future<void> pinMessage({required int peerId, required int messageId}) async {
    await callMethod('messages.pin', {
      'peer_id': '$peerId',
      'message_id': '$messageId',
    });
  }

  Future<void> unpinMessage({required int peerId}) async {
    await callMethod('messages.unpin', {
      'peer_id': '$peerId',
    });
  }

  // MARK: - Friends & Search
  Future<List<VKUser>> getFriends({int count = 100, int offset = 0}) async {
    try {
      final resp = await callMethod('friends.get', {
        'count': '$count',
        'offset': '$offset',
        'fields': 'photo_100,photo_200,verified,online',
      });
      final items = resp['items'] as List? ?? [];
      final List<VKUser> users = [];
      for (final item in items) {
        if (item is Map) {
          final u = VKUser.fromJson(item as Map<String, dynamic>);
          cachedUsers[u.id] = u;
          users.add(u);
        }
      }
      return users;
    } catch (_) {
      return [];
    }
  }

  Future<List<VKUser>> searchUsers({required String query, int count = 30}) async {
    try {
      final resp = await callMethod('users.search', {
        'q': query,
        'count': '$count',
        'fields': 'photo_100,photo_200,verified,online',
      });
      final items = resp['items'] as List? ?? [];
      final List<VKUser> users = [];
      for (final item in items) {
        if (item is Map) {
          final u = VKUser.fromJson(item as Map<String, dynamic>);
          cachedUsers[u.id] = u;
          users.add(u);
        }
      }
      return users;
    } catch (_) {
      return [];
    }
  }

  // MARK: - Group Chat Management
  Future<int> createChat({required List<int> userIds, required String title}) async {
    final resp = await callMethod('messages.createChat', {
      'user_ids': userIds.join(','),
      'title': title,
    });
    if (resp is int) return resp;
    if (resp is Map && resp['chat_id'] != null) {
      return resp['chat_id'] is int ? resp['chat_id'] : int.tryParse('${resp['chat_id']}') ?? 0;
    }
    return int.tryParse('$resp') ?? 0;
  }

  Future<Map<String, dynamic>> getConversationMembers({required int peerId}) async {
    try {
      final resp = await callMethod('messages.getConversationMembers', {
        'peer_id': '$peerId',
        'extended': '1',
        'fields': 'photo_100,photo_200,online,online_mobile,verified,sex',
      });

      final profiles = <int, VKUser>{};
      if (resp['profiles'] is List) {
        for (final p in resp['profiles']) {
          final u = VKUser.fromJson(p as Map<String, dynamic>);
          profiles[u.id] = u;
          cachedUsers[u.id] = u;
        }
      }

      final items = resp['items'] as List? ?? [];
      final List<Map<String, dynamic>> members = [];
      for (final item in items) {
        if (item is Map) {
          final memberId = item['member_id'] is int ? item['member_id'] : int.tryParse('${item['member_id']}') ?? 0;
          final isOwner = item['is_owner'] == true || item['is_owner'] == 1;
          final isAdmin = item['is_admin'] == true || item['is_admin'] == 1;
          members.add({
            'memberId': memberId,
            'isOwner': isOwner,
            'isAdmin': isAdmin,
            'user': profiles[memberId] ?? cachedUsers[memberId],
          });
        }
      }

      // Fetch missing users if any member lacks user profile
      final missingIds = members
          .where((m) => m['user'] == null && (m['memberId'] as int) > 0)
          .map((m) => m['memberId'] as int)
          .toList();
      if (missingIds.isNotEmpty) {
        try {
          final fetchedUsers = await getUsers(missingIds);
          for (final u in fetchedUsers) {
            profiles[u.id] = u;
            cachedUsers[u.id] = u;
          }
          for (final m in members) {
            if (m['user'] == null && profiles.containsKey(m['memberId'])) {
              m['user'] = profiles[m['memberId']];
            }
          }
        } catch (_) {}
      }

      // Sort: owner first, then admins, then alphabetically
      members.sort((a, b) {
        if (a['isOwner'] != b['isOwner']) return (b['isOwner'] == true) ? -1 : 1;
        if (a['isAdmin'] != b['isAdmin']) return (b['isAdmin'] == true) ? -1 : 1;
        final nameA = (a['user'] as VKUser?)?.fullName ?? '';
        final nameB = (b['user'] as VKUser?)?.fullName ?? '';
        return nameA.compareTo(nameB);
      });

      return {
        'count': resp['count'] ?? members.length,
        'members': members,
        'chatSettings': resp['chat_settings'],
      };
    } catch (e) {
      return {'count': 0, 'members': []};
    }
  }

  Future<void> removeChatUser({required int chatId, required int userId}) async {
    await callMethod('messages.removeChatUser', {
      'chat_id': '$chatId',
      'user_id': '$userId',
    });
  }

  Future<void> editChatTitle({required int chatId, required String title}) async {
    await callMethod('messages.editChat', {
      'chat_id': '$chatId',
      'title': title,
    });
  }

  Future<void> setActivity({required int peerId, String type = 'typing'}) async {
    try {
      await callMethod('messages.setActivity', {
        'peer_id': '$peerId',
        'type': type,
      });
    } catch (_) {}
  }

  // MARK: - Materials & History Attachments
  Future<List<Map<String, dynamic>>> getHistoryAttachments({
    required int peerId,
    required String mediaType, // 'photo', 'video', 'audio', 'doc'
    int count = 40,
    String? startFrom,
  }) async {
    try {
      final params = {
        'peer_id': '$peerId',
        'media_type': mediaType,
        'count': '$count',
      };
      if (startFrom != null && startFrom.isNotEmpty) {
        params['start_from'] = startFrom;
      }
      final resp = await callMethod('messages.getHistoryAttachments', params);
      final items = resp['items'] as List? ?? [];
      final List<Map<String, dynamic>> result = [];
      for (final item in items) {
        if (item is Map && item['attachment'] is Map) {
          result.add(Map<String, dynamic>.from(item['attachment'] as Map));
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserMedia({
    required String type, // 'photo', 'video', 'audio', 'doc'
    int count = 40,
  }) async {
    try {
      String method = 'photos.get';
      Map<String, String> params = {'count': '$count'};
      if (type == 'photo') {
        method = 'photos.getAll';
        params['extended'] = '1';
      } else if (type == 'video') {
        method = 'video.get';
      } else if (type == 'audio') {
        method = 'audio.get';
      } else if (type == 'doc') {
        method = 'docs.get';
      }

      final resp = await callMethod(method, params);
      final items = resp['items'] as List? ?? (resp is List ? resp : []);
      return items.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getVideoDetails({
    required int ownerId,
    required int videoId,
    String? accessKey,
  }) async {
    try {
      final vidStr = (accessKey != null && accessKey.isNotEmpty)
          ? '${ownerId}_${videoId}_$accessKey'
          : '${ownerId}_$videoId';

      final resp = await callMethod('video.get', {
        'videos': vidStr,
        'extended': '1',
      });

      final items = resp['items'] as List? ?? (resp is List ? resp : []);
      if (items.isNotEmpty && items.first is Map) {
        return Map<String, dynamic>.from(items.first as Map);
      }
    } catch (e) {
      debugPrint('[OpenVKApi] getVideoDetails error: $e');
    }
    return null;
  }
}
