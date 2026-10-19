import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/attachment.dart';
import '../models/conversation.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/pending_upload_item.dart';
import '../models/user.dart';
import 'chat_cache.dart';
import 'longpoll_service.dart';
import 'memory_manager.dart';
import 'notification_service.dart';
import 'openvk_api.dart';

class MessengerStore extends ChangeNotifier {
  static final MessengerStore instance = MessengerStore._internal();
  MessengerStore._internal();

  final OpenVKApi _api = OpenVKApi.instance;
  final LongPollService _longPoll = LongPollService.instance;
  final ChatCache _cache = ChatCache.instance;
  final Uuid _uuid = const Uuid();

  // Multi-Account
  List<VKAccount> _accounts = [];
  List<VKAccount> get accounts => _accounts;
  VKAccount? _activeAccount;
  VKAccount? get activeAccount => _activeAccount;

  // Admin Groups (communities managed by user)
  List<VKGroup> _adminGroups = [];
  List<VKGroup> get adminGroups => _adminGroups;
  VKGroup? _activeAdminGroup;
  VKGroup? get activeAdminGroup => _activeAdminGroup;

  // Conversations & History
  List<VKConversation> _conversations = [];
  List<VKConversation> get conversations => _getFilteredConversations();

  int? _selectedPeerId;
  int? get selectedPeerId => _selectedPeerId;
  VKConversation? get selectedConversation {
    if (_selectedPeerId == null) return null;
    try {
      return _conversations.firstWhere((c) => c.peerId == _selectedPeerId);
    } catch (_) {
      return null;
    }
  }

  final Map<int, List<VKMessage>> _messagesByPeer = {};
  Map<int, List<VKMessage>> get messages => _messagesByPeer;
  List<VKMessage> get currentMessages => _selectedPeerId != null ? (_messagesByPeer[_selectedPeerId!] ?? []) : [];

  // Pinned & Muted Chats
  final Set<int> _pinnedPeerIds = {};
  bool isPinned(int peerId) => _pinnedPeerIds.contains(peerId);

  final Set<int> _mutedPeerIds = {};
  bool isMuted(int peerId) => _mutedPeerIds.contains(peerId);

  // Filters
  bool _onlyUnread = false;
  bool get onlyUnread => _onlyUnread;

  bool _isCommunityFilterActive = false;
  bool get isCommunityFilterActive => _isCommunityFilterActive;

  // Replying
  VKMessage? _replyingToMessage;
  VKMessage? get replyingToMessage => _replyingToMessage;
  void setReplyingTo(VKMessage? msg) {
    _replyingToMessage = msg;
    notifyListeners();
  }

  // Folder filtering
  String? _selectedFolderId; // null = all
  String? get selectedFolderId => _selectedFolderId;
  List<VKChatFolder> _folders = [];
  List<VKChatFolder> get folders => _folders;

  // Stickers management (matching macOS Swift reference)
  List<int> _recentStickerIds = [];
  List<int> get recentStickerIds => _recentStickerIds;

  List<int> _favoriteStickerIds = [];
  List<int> get favoriteStickerIds => _favoriteStickerIds;

  List<VKStickerPack> _stickerPacks = [];
  List<VKStickerPack> get stickerPacks => _stickerPacks;

  Future<void> loadStickerPacks() async {
    final packs = await _api.fetchStickerPacks();
    _stickerPacks = packs;
    notifyListeners();
  }

  bool isFavoriteSticker(int id) => _favoriteStickerIds.contains(id);

  Future<void> toggleFavoriteSticker(int id) async {
    if (_favoriteStickerIds.contains(id)) {
      _favoriteStickerIds.remove(id);
    } else {
      _favoriteStickerIds.insert(0, id);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('openvk_favorite_stickers', _favoriteStickerIds.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  Future<void> addRecentSticker(int id) async {
    _recentStickerIds.remove(id);
    _recentStickerIds.insert(0, id);
    if (_recentStickerIds.length > 60) {
      _recentStickerIds = _recentStickerIds.take(60).toList();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('openvk_recent_stickers', _recentStickerIds.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  VKStickerItem stickerItem(int id) {
    for (final pack in _stickerPacks) {
      for (final s in pack.stickers) {
        if (s.id == id) return s;
      }
    }
    final base = _api.serverURL.replaceAll(RegExp(r'/+$'), '');
    return VKStickerItem(
      id: id,
      packId: 0,
      url: '$base/images/stickers/$id/256b.png',
    );
  }

  // Pending Uploads (Attachment Tray matching macOS reference)
  final List<PendingUploadItem> _pendingUploads = [];
  List<PendingUploadItem> get pendingUploads => _pendingUploads;

  void removePendingUpload(String id) {
    _pendingUploads.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clearPendingUploads() {
    _pendingUploads.clear();
    notifyListeners();
  }

  Future<void> addPendingFile(File file, {bool? isPhoto}) async {
    if (_selectedPeerId == null) return;
    final peerId = _selectedPeerId!;
    final filename = file.path.split(Platform.pathSeparator).last;
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    final bool photoFlag = isPhoto ?? ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(ext);

    final itemId = _uuid.v4();
    final item = PendingUploadItem(
      id: itemId,
      filename: filename,
      type: photoFlag ? PendingUploadType.photo : PendingUploadType.document,
      localFile: file,
      progress: 0.15,
      isUploading: true,
    );

    _pendingUploads.add(item);
    notifyListeners();

    try {
      if (photoFlag) {
        final uploaded = await _api.uploadPhoto(
          file: file,
          peerId: peerId,
          groupId: _activeAdminGroup?.id,
        );
        final idx = _pendingUploads.indexWhere((u) => u.id == itemId);
        if (idx != -1) {
          _pendingUploads[idx].progress = 1.0;
          _pendingUploads[idx].isUploading = false;
          _pendingUploads[idx].attachmentCode = uploaded.attachmentString;
          notifyListeners();
        }
      } else {
        final uploaded = await _api.uploadDocument(
          file: file,
          peerId: peerId,
          groupId: _activeAdminGroup?.id,
        );
        final idx = _pendingUploads.indexWhere((u) => u.id == itemId);
        if (idx != -1) {
          _pendingUploads[idx].progress = 1.0;
          _pendingUploads[idx].isUploading = false;
          _pendingUploads[idx].attachmentCode = uploaded.attachmentString;
          notifyListeners();
        }
      }
    } catch (e) {
      final idx = _pendingUploads.indexWhere((u) => u.id == itemId);
      if (idx != -1) {
        _pendingUploads[idx].isUploading = false;
        _pendingUploads[idx].error = 'Ошибка: $e';
        notifyListeners();
      }
    }
  }

  void addPendingInstanceMedia({
    required String type,
    required String attachmentCode,
    required String title,
    String? thumbnailUrl,
    String? subtitle,
  }) {
    PendingUploadType uploadType = PendingUploadType.document;
    if (type == 'photo') uploadType = PendingUploadType.photo;
    if (type == 'video') uploadType = PendingUploadType.video;
    if (type == 'audio') uploadType = PendingUploadType.audio;

    final item = PendingUploadItem(
      id: _uuid.v4(),
      filename: title,
      type: uploadType,
      remoteThumbnailUrl: thumbnailUrl,
      subtitle: subtitle,
      progress: 1.0,
      isUploading: false,
      attachmentCode: attachmentCode,
    );

    _pendingUploads.add(item);
    notifyListeners();
  }

  // State flags
  bool _isLoadingConversations = false;
  bool get isLoadingConversations => _isLoadingConversations;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  // Typing users per peer: peerId -> Set of userIds
  final Map<int, Set<int>> _typingUsers = {};
  Set<int> typingUsers(int peerId) => _typingUsers[peerId] ?? {};

  String? typingStatus(int peerId) {
    final users = _typingUsers[peerId];
    if (users == null || users.isEmpty) return null;
    final isGroup = peerId >= 2000000000 || peerId < 0;

    if (isGroup) {
      final names = users.map((uid) {
        final u = _api.cachedUsers[uid];
        return u?.firstName ?? '';
      }).where((n) => n.isNotEmpty).toList();

      if (names.length == 1) {
        return '${names[0]} печатает...';
      } else if (names.length == 2) {
        return '${names[0]} и ${names[1]} печатают...';
      } else if (names.length > 2) {
        return '${names[0]} и ещё ${names.length - 1} печатают...';
      } else {
        return 'кто-то печатает...';
      }
    } else {
      return 'печатает...';
    }
  }

  // Audio/Voice recording state
  final bool _isRecordingVoice = false;
  bool get isRecordingVoice => _isRecordingVoice;

  // Total unread count across all conversations
  int get totalUnreadCount {
    int total = 0;
    for (final c in _conversations) {
      total += c.unreadCount;
    }
    return total;
  }

  int unreadCountForFolder(VKChatFolder folder) {
    int count = 0;
    for (final c in _conversations) {
      if (folder.peerIds.contains(c.peerId)) {
        count += c.unreadCount;
      }
    }
    return count;
  }

  // Initializer
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load pinned
    final pinnedList = prefs.getStringList('openvk_pinned_peers') ?? [];
    _pinnedPeerIds.addAll(pinnedList.map((e) => int.tryParse(e) ?? 0).where((e) => e != 0));

    // Load muted
    final mutedList = prefs.getStringList('openvk_muted_peers') ?? [];
    _mutedPeerIds.addAll(mutedList.map((e) => int.tryParse(e) ?? 0).where((e) => e != 0));

    // Load custom folders
    final foldersJson = prefs.getString('openvk_custom_folders');
    if (foldersJson != null) {
      try {
        final list = (jsonDecode(foldersJson) as List).map((e) => VKChatFolder.fromJson(e)).toList();
        if (list.isNotEmpty) _folders = list;
      } catch (_) {}
    }

    // Load recent stickers
    final recents = prefs.getStringList('openvk_recent_stickers') ?? [];
    _recentStickerIds = recents.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();

    // Load favorite stickers
    final favorites = prefs.getStringList('openvk_favorite_stickers') ?? [];
    _favoriteStickerIds = favorites.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();

    final cached = await _cache.loadAccounts();
    if (cached != null) {
      _accounts = cached['accounts'] as List<VKAccount>? ?? [];
      final activeId = cached['activeId'] as String?;
      if (_accounts.isNotEmpty) {
        _activeAccount = _accounts.firstWhere(
          (a) => a.id == activeId,
          orElse: () => _accounts.first,
        );
      }
    }

    if (_activeAccount != null) {
      await _activateAccount(_activeAccount!);
    }
  }

  Future<void> _activateAccount(VKAccount account) async {
    _activeAccount = account;
    _api.currentUserId = account.userId;
    _api.currentUser = VKUser(
      id: account.userId,
      firstName: account.name,
      lastName: '',
      photo100: account.avatarUrl,
      photo200: account.avatarUrl,
    );
    _api.setCredentials(
      token: account.token,
      serverURL: account.serverURL,
      chandlerCookie: account.chandlerSessCookie,
      userId: account.userId,
    );

    // Load cached conversations first for immediate UI
    final cachedConvs = await _cache.loadConversations(account.userId);
    if (cachedConvs != null && cachedConvs.isNotEmpty) {
      _conversations = cachedConvs;
      notifyListeners();
    }

    // Start LongPoll immediately
    _startLongPoll();

    // Refresh from network in background without blocking UI startup
    unawaited(fetchConversations());
    unawaited(_fetchAdminGroups());
  }

  void _startLongPoll() {
    _longPoll.start(
      api: _api,
      onNewMessage: _handleNewMessageEvent,
      onMessagesRead: _handleMessagesReadEvent,
      onTyping: _handleTypingEvent,
      onStoppedTyping: _handleStoppedTypingEvent,
      onUserOnlineChanged: _handleUserOnlineChanged,
    );
  }

  // MARK: - Account Management
  Future<void> loginWithPassword({
    required String serverURL,
    required String login,
    required String password,
  }) async {
    final authResult = await _api.authWithPassword(
      serverURL: serverURL,
      login: login,
      password: password,
    );

    final token = authResult['token'] as String;
    final userId = authResult['userId'] as int;
    final cookie = authResult['cookie'] as String?;

    // Fetch user profile info
    _api.setCredentials(token: token, serverURL: serverURL, chandlerCookie: cookie);
    final user = await _api.fetchUserProfile(userId);

    final account = VKAccount(
      id: _uuid.v4(),
      userId: userId,
      token: token,
      chandlerSessCookie: cookie,
      name: user != null ? '${user.firstName} ${user.lastName}' : 'Пользователь $userId',
      avatarUrl: user?.photoMaxUrl,
      serverURL: serverURL,
    );

    _accounts.removeWhere((a) => a.userId == userId && a.serverURL == serverURL);
    _accounts.add(account);
    await _cache.saveAccounts(_accounts, account.id);
    await _activateAccount(account);
  }

  Future<void> loginWithToken({
    required String serverURL,
    required String token,
  }) async {
    _api.setCredentials(token: token, serverURL: serverURL);
    final user = await _api.fetchUserProfile(0); // 0 or current
    final userId = user?.id ?? 1;

    final account = VKAccount(
      id: _uuid.v4(),
      userId: userId,
      token: token,
      name: user != null ? '${user.firstName} ${user.lastName}' : 'Пользователь $userId',
      avatarUrl: user?.photoMaxUrl,
      serverURL: serverURL,
    );

    _accounts.removeWhere((a) => a.userId == userId && a.serverURL == serverURL);
    _accounts.add(account);
    await _cache.saveAccounts(_accounts, account.id);
    await _activateAccount(account);
  }

  Future<void> switchAccount(VKAccount account) async {
    if (_activeAccount?.id == account.id) return;
    _longPoll.stop();
    _selectedPeerId = null;
    _conversations = [];
    _messagesByPeer.clear();
    await _cache.saveAccounts(_accounts, account.id);
    await _activateAccount(account);
    notifyListeners();
  }

  Future<void> logout(VKAccount account) async {
    _accounts.removeWhere((a) => a.id == account.id);
    if (_activeAccount?.id == account.id) {
      _longPoll.stop();
      _selectedPeerId = null;
      _conversations = [];
      _messagesByPeer.clear();
      _activeAccount = _accounts.isNotEmpty ? _accounts.first : null;
      if (_activeAccount != null) {
        await _activateAccount(_activeAccount!);
      }
    }
    await _cache.saveAccounts(_accounts, _activeAccount?.id);
    notifyListeners();
  }

  void setActiveAdminGroup(VKGroup? group) {
    _activeAdminGroup = group;
    notifyListeners();
  }

  Future<void> _fetchAdminGroups() async {
    try {
      _adminGroups = await _api.fetchAdminGroups();
      notifyListeners();
    } catch (e) {
      debugPrint('[MessengerStore] fetchAdminGroups error: $e');
    }
  }

  // MARK: - Conversations
  Future<void> fetchConversations({bool forceRefresh = false}) async {
    if (_activeAccount == null) return;
    if (_isLoadingConversations && !forceRefresh) return;

    _isLoadingConversations = true;
    notifyListeners();

    try {
      final fetched = await _api.fetchConversations();
      _conversations = fetched;
      await _cache.saveConversations(_activeAccount!.userId, _conversations);
    } catch (e) {
      debugPrint('[MessengerStore] Error fetching conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  void selectFolder(String? folderId) {
    _selectedFolderId = folderId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  void toggleOnlyUnread() {
    _onlyUnread = !_onlyUnread;
    notifyListeners();
  }

  void setOnlyUnread(bool val) {
    _onlyUnread = val;
    notifyListeners();
  }

  void toggleCommunityFilter() {
    _isCommunityFilterActive = !_isCommunityFilterActive;
    notifyListeners();
  }

  void setCommunityFilter(bool val) {
    _isCommunityFilterActive = val;
    notifyListeners();
  }

  void switchToAdminGroup(VKGroup? group) {
    _activeAdminGroup = group;
    notifyListeners();
  }

  void togglePin(int peerId) async {
    if (_pinnedPeerIds.contains(peerId)) {
      _pinnedPeerIds.remove(peerId);
    } else {
      _pinnedPeerIds.add(peerId);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('openvk_pinned_peers', _pinnedPeerIds.map((e) => '$e').toList());
  }

  void toggleMute(int peerId) async {
    if (_mutedPeerIds.contains(peerId)) {
      _mutedPeerIds.remove(peerId);
    } else {
      _mutedPeerIds.add(peerId);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('openvk_muted_peers', _mutedPeerIds.map((e) => '$e').toList());
  }

  Future<void> createFolder(String name, {String icon = 'folder', List<int> peerIds = const []}) async {
    final folder = VKChatFolder(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
      peerIds: List<int>.from(peerIds),
    );
    _folders.add(folder);
    notifyListeners();
    await _saveFolders();
  }

  Future<void> updateFolder(VKChatFolder updated) async {
    final idx = _folders.indexWhere((f) => f.id == updated.id);
    if (idx != -1) {
      _folders[idx] = updated;
      notifyListeners();
      await _saveFolders();
    }
  }

  Future<void> deleteFolder(String id) async {
    _folders.removeWhere((f) => f.id == id);
    if (_selectedFolderId == id) {
      _selectedFolderId = null;
    }
    notifyListeners();
    await _saveFolders();
  }

  Future<void> toggleChatInFolder(int peerId, String folderId) async {
    final folder = _folders.firstWhere((f) => f.id == folderId, orElse: () => VKChatFolder(id: '', name: ''));
    if (folder.id.isNotEmpty) {
      final list = List<int>.from(folder.peerIds);
      if (list.contains(peerId)) {
        list.remove(peerId);
      } else {
        list.add(peerId);
      }
      folder.peerIds = list;
      notifyListeners();
      await _saveFolders();
    }
  }

  bool isChatInFolder(int peerId, String folderId) {
    final folder = _folders.firstWhere((f) => f.id == folderId, orElse: () => VKChatFolder(id: '', name: ''));
    return folder.peerIds.contains(peerId);
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openvk_custom_folders', jsonEncode(_folders.map((f) => f.toJson()).toList()));
  }

  List<VKConversation> _getFilteredConversations() {
    List<VKConversation> list = List.from(_conversations);

    // Only unread toggle
    if (_onlyUnread) {
      list = list.where((c) => c.unreadCount > 0).toList();
    }

    // Community filter (only groups / communities)
    if (_isCommunityFilterActive) {
      list = list.where((c) => c.peerId < 0).toList();
    }

    // Filter by custom user folder (null = All Chats)
    if (_selectedFolderId != null) {
      final folder = _folders.firstWhere(
        (f) => f.id == _selectedFolderId,
        orElse: () => VKChatFolder(id: '', name: ''),
      );
      if (folder.id.isNotEmpty) {
        list = list.where((c) => folder.peerIds.contains(c.peerId)).toList();
      }
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      list = list.where((c) {
        final title = c.title.toLowerCase();
        final text = (c.lastMessage?.text ?? '').toLowerCase();
        return title.contains(_searchQuery) || text.contains(_searchQuery);
      }).toList();
    }

    // Sort: Pinned chats on top!
    list.sort((a, b) {
      final aPinned = _pinnedPeerIds.contains(a.peerId);
      final bPinned = _pinnedPeerIds.contains(b.peerId);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });

    return list;
  }

  // MARK: - Select Chat & History
  void selectPeer(int peerId) => selectConversation(peerId);

  Future<void> selectConversation(int peerId) async {
    if (_selectedPeerId == peerId) return;
    _selectedPeerId = peerId;
    _pendingUploads.clear();
    _replyingToMessage = null;

    // Prune messages of inactive chats and discard unreferenced textures (150-200MB RAM cap)
    _pruneInactiveMessagesMemory();
    MemoryManager.instance.trimMemory();

    notifyListeners();

    // Load cached history first for instant display
    if (_activeAccount != null) {
      final cached = await _cache.loadMessages(_activeAccount!.userId, peerId);
      if (cached != null && cached.isNotEmpty) {
        _messagesByPeer[peerId] = cached;
        notifyListeners();
      }
    }

    // Fetch fresh from network
    await fetchHistory(peerId);
    markAsRead(peerId);
  }

  void _pruneInactiveMessagesMemory() {
    for (final key in _messagesByPeer.keys.toList()) {
      if (key != _selectedPeerId) {
        final list = _messagesByPeer[key];
        if (list != null && list.length > 40) {
          _messagesByPeer[key] = list.sublist(list.length - 40);
        }
      }
    }
  }

  Future<void> fetchHistory(int peerId, {bool loadOlder = false}) async {
    if (_activeAccount == null) return;
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final currentList = _messagesByPeer[peerId] ?? [];
      final offset = loadOlder ? currentList.length : 0;
      final fetched = await _api.fetchHistory(peerId: peerId, offset: offset, count: 40);

      if (loadOlder) {
        // Prepend older messages
        final existingIds = currentList.map((m) => m.id).toSet();
        final newOlder = fetched.where((m) => !existingIds.contains(m.id)).toList();
        _messagesByPeer[peerId] = [...newOlder, ...currentList];
      } else {
        final currentMap = {for (final m in currentList) m.id: m};
        final merged = fetched.map((fMsg) {
          final existing = currentMap[fMsg.id];
          if (existing != null) {
            return fMsg.copyWith(
              replyMessage: fMsg.replyMessage ?? existing.replyMessage,
              photo: fMsg.photo ?? existing.photo,
              photos: fMsg.photos.isNotEmpty ? fMsg.photos : existing.photos,
              doc: fMsg.doc ?? existing.doc,
            );
          }
          return fMsg;
        }).toList();
        _messagesByPeer[peerId] = merged;
      }

      if (_activeAccount != null && _messagesByPeer[peerId] != null) {
        await _cache.saveMessages(_activeAccount!.userId, peerId, _messagesByPeer[peerId]!);
      }

      // Update conversation online status from cached user
      if (peerId > 0 && peerId < 2000000000) {
        final u = _api.cachedUsers[peerId];
        final convIdx = _conversations.indexWhere((c) => c.peerId == peerId);
        if (u != null && convIdx != -1) {
          _conversations[convIdx] = _conversations[convIdx].copyWith(
            isOnline: u.isOnline,
            isMobile: u.isMobile,
            lastSeen: u.lastSeen,
            sex: u.sex,
          );
        }
      }
    } catch (e) {
      debugPrint('[MessengerStore] Error fetching history for $peerId: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int peerId) async {
    if (_activeAccount == null) return;
    final msgs = _messagesByPeer[peerId];
    if (msgs == null || msgs.isEmpty) return;

    final convIndex = _conversations.indexWhere((c) => c.peerId == peerId);
    if (convIndex != -1) {
      _conversations[convIndex] = _conversations[convIndex].copyWith(
        unreadCount: 0,
        hasUnreadMention: false,
      );
      notifyListeners();
    }

    try {
      final lastMsg = msgs.last;
      await _api.markAsRead(peerId: peerId, startMessageId: lastMsg.id);
    } catch (e) {
      debugPrint('[MessengerStore] markAsRead error: $e');
    }
  }

  // MARK: - Sending Messages
  Future<void> sendMessage(String text, {int? replyToMsgId, String? attachmentStr}) async {
    if (_selectedPeerId == null || _activeAccount == null) return;
    final hasPending = _pendingUploads.isNotEmpty;
    if (text.trim().isEmpty && (attachmentStr == null || attachmentStr.isEmpty) && !hasPending) return;
    final peerId = _selectedPeerId!;
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    // 1. Wait for in-progress uploads if any (up to 15 seconds)
    int waitCount = 0;
    while (_pendingUploads.any((u) => u.isUploading) && waitCount < 150) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    // 2. Collect attachments from pendingUploads
    final readyCodes = _pendingUploads
        .map((u) => u.attachmentCode)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toList();

    final allCodes = [
      if (attachmentStr != null && attachmentStr.isNotEmpty) attachmentStr,
      ...readyCodes,
    ];
    final finalAttachmentStr = allCodes.isNotEmpty ? allCodes.join(',') : null;

    // Optimistic attachments
    final localPhotos = _pendingUploads
        .where((u) => u.isPhoto)
        .map((u) => VKPhotoAttachment(
              id: tempId,
              ownerId: _activeAccount!.userId,
              previewUrl: u.localFile?.path ?? u.remoteThumbnailUrl,
              fullUrl: u.localFile?.path ?? u.remoteThumbnailUrl,
              localPath: u.localFile?.path,
            ))
        .toList();

    final localDocs = _pendingUploads
        .where((u) => u.isDocument)
        .map((u) => VKDocAttachment(
              id: tempId,
              ownerId: _activeAccount!.userId,
              title: u.filename,
              size: (u.localFile != null && u.localFile!.existsSync()) ? u.localFile!.lengthSync() : 0,
              ext: u.fileExtension.toLowerCase(),
              localPath: u.localFile?.path,
            ))
        .toList();

    // Clear pending uploads immediately so input bar clears smoothly
    _pendingUploads.clear();
    notifyListeners();

    // Resolve reply message if exists
    VKReplyMessage? reply;
    if (replyToMsgId != null) {
      final matches = _messagesByPeer[peerId]?.where((m) => m.id == replyToMsgId);
      final target = (matches != null && matches.isNotEmpty) ? matches.first : null;
      if (target != null) {
        reply = VKReplyMessage(
          id: target.id,
          fromId: target.fromId,
          senderName: target.sender?.fullName ?? 'Пользователь',
          senderAvatarURL: target.sender?.photoURL,
          text: target.text,
          date: target.date,
          photoURL: target.photo?.bestUrl,
          hasPhoto: target.photo != null,
        );
      }
    }

    // Optimistic Message
    final optimistic = VKMessage(
      id: tempId,
      peerId: peerId,
      fromId: _activeAdminGroup != null ? -_activeAdminGroup!.id : _activeAccount!.userId,
      date: DateTime.now(),
      text: text.trim().isNotEmpty ? text.trim() : (finalAttachmentStr != null ? '' : ''),
      isOut: true,
      readState: false,
      replyMessage: reply,
      photos: localPhotos,
      docs: localDocs,
    );

    _appendMessage(peerId, optimistic);
    _updateConversationLastMessage(peerId, optimistic);

    try {
      final realId = await _api.sendMessage(
        peerId: peerId,
        message: text.trim(),
        attachmentStr: finalAttachmentStr,
        replyTo: replyToMsgId,
        groupId: _activeAdminGroup?.id,
      );

      _replaceMessageId(peerId, tempId, realId);
      fetchHistory(peerId);
    } catch (e) {
      debugPrint('[MessengerStore] Error sending message: $e');
    }
  }

  // Upload and Send Photo (Optimistic with local preview!)
  Future<void> uploadAndSendPhoto(File file, {int? replyToMsgId}) async {
    if (_selectedPeerId == null || _activeAccount == null) return;
    final peerId = _selectedPeerId!;
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    // Local optimistic photo attachment so user immediately sees image!
    final optimisticPhoto = VKPhotoAttachment(
      id: tempId,
      ownerId: _activeAccount!.userId,
      previewUrl: file.path,
      fullUrl: file.path,
      localPath: file.path,
    );

    final optimistic = VKMessage(
      id: tempId,
      peerId: peerId,
      fromId: _activeAdminGroup != null ? -_activeAdminGroup!.id : _activeAccount!.userId,
      date: DateTime.now(),
      text: '',
      isOut: true,
      readState: false,
      photos: [optimisticPhoto],
    );

    _appendMessage(peerId, optimistic);
    _updateConversationLastMessage(peerId, optimistic);

    try {
      final uploaded = await _api.uploadPhoto(
        file: file,
        peerId: peerId,
        groupId: _activeAdminGroup?.id,
      );

      final realId = await _api.sendMessage(
        peerId: peerId,
        attachmentStr: uploaded.attachmentString,
        replyTo: replyToMsgId,
        groupId: _activeAdminGroup?.id,
      );

      _replaceMessage(
        peerId,
        tempId,
        optimistic.copyWith(
          id: realId,
          photos: [uploaded],
        ),
      );

      // Sync history to ensure all attachments and server states match
      fetchHistory(peerId);
    } catch (e) {
      debugPrint('[MessengerStore] Error uploading photo: $e');
    }
  }

  // Upload and Send Document (Maintains title and size! Never flashes 0 KB!)
  Future<void> uploadAndSendDocument(File file, {int? replyToMsgId}) async {
    if (_selectedPeerId == null || _activeAccount == null) return;
    final peerId = _selectedPeerId!;
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();

    // Optimistic doc attachment with exact file size and title
    final optimisticDoc = VKDocAttachment(
      id: tempId,
      ownerId: _activeAccount!.userId,
      title: fileName,
      size: fileSize,
      ext: fileName.contains('.') ? fileName.split('.').last : 'bin',
      url: file.path,
      localPath: file.path,
    );

    final optimistic = VKMessage(
      id: tempId,
      peerId: peerId,
      fromId: _activeAdminGroup != null ? -_activeAdminGroup!.id : _activeAccount!.userId,
      date: DateTime.now(),
      text: '',
      isOut: true,
      readState: false,
      docs: [optimisticDoc],
    );

    _appendMessage(peerId, optimistic);
    _updateConversationLastMessage(peerId, optimistic);

    try {
      final uploaded = await _api.uploadDocument(
        file: file,
        peerId: peerId,
        groupId: _activeAdminGroup?.id,
      );

      // Preserving original title & size in case backend returns 0 or sanitized name
      final finalDoc = uploaded.copyWith(
        title: uploaded.title.isNotEmpty ? uploaded.title : fileName,
        size: uploaded.size > 0 ? uploaded.size : fileSize,
      );

      final realId = await _api.sendMessage(
        peerId: peerId,
        attachmentStr: finalDoc.attachmentString,
        replyTo: replyToMsgId,
        groupId: _activeAdminGroup?.id,
      );

      _replaceMessage(
        peerId,
        tempId,
        optimistic.copyWith(
          id: realId,
          docs: [finalDoc],
        ),
      );

      // Sync history to ensure all attachments and server states match
      fetchHistory(peerId);
    } catch (e) {
      debugPrint('[MessengerStore] Error uploading doc: $e');
    }
  }

  // Send Sticker
  Future<void> sendSticker(dynamic stickerOrId) async {
    if (_selectedPeerId == null || _activeAccount == null) return;
    final peerId = _selectedPeerId!;
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    final int stickerId = stickerOrId is int ? stickerOrId : (stickerOrId as VKStickerItem).id;
    addRecentSticker(stickerId);
    final String stickerUrl = stickerOrId is VKStickerItem
        ? stickerOrId.url
        : 'https://vk.com/sticker/1-$stickerId-256.png';

    final optimisticSticker = VKSticker(
      id: stickerId,
      stickerId: stickerId,
      packId: stickerOrId is VKStickerItem ? stickerOrId.packId : 0,
      images: [VKStickerImage(url: stickerUrl, width: 256, height: 256)],
      animationUrl: stickerOrId is VKStickerItem ? stickerOrId.animationUrl : null,
    );

    final optimistic = VKMessage(
      id: tempId,
      peerId: peerId,
      fromId: _activeAdminGroup != null ? -_activeAdminGroup!.id : _activeAccount!.userId,
      date: DateTime.now(),
      text: '',
      isOut: true,
      readState: false,
      sticker: optimisticSticker,
    );

    _appendMessage(peerId, optimistic);
    _updateConversationLastMessage(peerId, optimistic);

    try {
      final realId = await _api.sendMessage(
        peerId: peerId,
        stickerId: stickerId,
        groupId: _activeAdminGroup?.id,
      );
      _replaceMessageId(peerId, tempId, realId);
    } catch (e) {
      debugPrint('[MessengerStore] Error sending sticker: $e');
    }
  }

  // Delete message
  Future<void> deleteMessage(int peerId, int messageId, {bool forAll = true}) async {
    try {
      await _api.deleteMessage(messageId: messageId, forAll: forAll);
      final list = _messagesByPeer[peerId];
      if (list != null) {
        list.removeWhere((m) => m.id == messageId);
        notifyListeners();
        if (_activeAccount != null) {
          await _cache.saveMessages(_activeAccount!.userId, peerId, list);
        }
      }
    } catch (e) {
      debugPrint('[MessengerStore] Error deleting message: $e');
    }
  }

  // Edit message
  Future<void> editMessage(int peerId, int messageId, String newText) async {
    try {
      await _api.editMessage(peerId: peerId, messageId: messageId, message: newText);
      final list = _messagesByPeer[peerId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.id == messageId);
        if (idx >= 0) {
          list[idx].text = newText;
          notifyListeners();
          if (_activeAccount != null) {
            await _cache.saveMessages(_activeAccount!.userId, peerId, list);
          }
        }
      }
      final convIndex = _conversations.indexWhere((c) => c.peerId == peerId);
      if (convIndex >= 0 && _conversations[convIndex].lastMessage?.id == messageId) {
        _conversations[convIndex].lastMessage?.text = newText;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MessengerStore] Error editing message: $e');
      rethrow;
    }
  }

  // Pin & Unpin message
  Future<void> pinMessage(int peerId, int messageId) async {
    try {
      await _api.pinMessage(peerId: peerId, messageId: messageId);
      final convIndex = _conversations.indexWhere((c) => c.peerId == peerId);
      final msg = _messagesByPeer[peerId]?.firstWhere((m) => m.id == messageId);
      if (convIndex != -1 && msg != null) {
        _conversations[convIndex] = _conversations[convIndex].copyWith(pinnedMessage: msg);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MessengerStore] Error pinning message: $e');
    }
  }

  Future<void> unpinMessage(int peerId) async {
    try {
      await _api.unpinMessage(peerId: peerId);
      final convIndex = _conversations.indexWhere((c) => c.peerId == peerId);
      if (convIndex != -1) {
        _conversations[convIndex] = _conversations[convIndex].copyWith(clearPinnedMessage: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MessengerStore] Error unpinning message: $e');
    }
  }

  // MARK: - Friends & Chat Management
  Future<List<VKUser>> fetchFriends() async {
    return _api.getFriends();
  }

  Future<int?> createGroupChat(List<int> userIds, String title) async {
    try {
      final chatId = await _api.createChat(userIds: userIds, title: title);
      final peerId = 2000000000 + chatId;
      await fetchConversations(forceRefresh: true);
      selectConversation(peerId);
      return peerId;
    } catch (e) {
      debugPrint('[MessengerStore] Error creating chat: $e');
      return null;
    }
  }

  Future<void> leaveChat(int peerId) async {
    if (peerId < 2000000000 || _activeAccount == null) return;
    final chatId = peerId - 2000000000;
    try {
      await _api.removeChatUser(chatId: chatId, userId: _activeAccount!.userId);
      _conversations.removeWhere((c) => c.peerId == peerId);
      if (_selectedPeerId == peerId) {
        _selectedPeerId = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MessengerStore] Error leaving chat: $e');
    }
  }

  Future<void> editChatTitle(int peerId, String newTitle) async {
    if (peerId < 2000000000) return;
    final chatId = peerId - 2000000000;
    try {
      await _api.editChatTitle(chatId: chatId, title: newTitle);
      final idx = _conversations.indexWhere((c) => c.peerId == peerId);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWith(title: newTitle);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MessengerStore] Error editing chat title: $e');
    }
  }

  Future<void> removeChatMember(int peerId, int memberId) async {
    if (peerId < 2000000000) return;
    final chatId = peerId - 2000000000;
    try {
      await _api.removeChatUser(chatId: chatId, userId: memberId);
    } catch (e) {
      debugPrint('[MessengerStore] Error removing chat member: $e');
    }
  }

  DateTime? _lastTypingSentDate;

  void sendTypingActivity() {
    if (_selectedPeerId == null || !_api.isAuthenticated) return;
    final now = DateTime.now();
    if (_lastTypingSentDate != null && now.difference(_lastTypingSentDate!).inMilliseconds < 4500) {
      return;
    }
    _lastTypingSentDate = now;
    _api.setActivity(peerId: _selectedPeerId!, type: 'typing');
  }

  // MARK: - Internal Message Manipulation
  void _appendMessage(int peerId, VKMessage message) {
    if (_messagesByPeer[peerId] == null) {
      _messagesByPeer[peerId] = [];
    }
    _messagesByPeer[peerId]!.add(message);
    notifyListeners();
  }

  void _replaceMessageId(int peerId, int oldId, int newId) {
    final list = _messagesByPeer[peerId];
    if (list != null) {
      final index = list.indexWhere((m) => m.id == oldId);
      if (index != -1) {
        list[index] = list[index].copyWith(id: newId);
        notifyListeners();
      }
    }
  }

  void _replaceMessage(int peerId, int oldId, VKMessage newMessage) {
    final list = _messagesByPeer[peerId];
    if (list != null) {
      final index = list.indexWhere((m) => m.id == oldId || (newMessage.id > 0 && m.id == newMessage.id));
      if (index != -1) {
        list[index] = newMessage;
        notifyListeners();
      }
    }
  }

  void _updateConversationLastMessage(int peerId, VKMessage message) {
    final index = _conversations.indexWhere((c) => c.peerId == peerId);
    if (index != -1) {
      final old = _conversations[index];
      _conversations.removeAt(index);
      _conversations.insert(
        0,
        old.copyWith(
          lastMessage: message,
          lastMessageId: message.id,
        ),
      );
      notifyListeners();
    }
  }

  // MARK: - LongPoll Handlers
  void _handleNewMessageEvent(Map<String, dynamic> data) {
    final int messageId = data['id'] as int;
    final int flags = data['flags'] as int;
    final int peerId = data['peerId'] as int;
    final int timestamp = data['timestamp'] as int;
    final String text = data['text'] as String;
    final bool isOut = (flags & 2) != 0;

    // Check if we already have this message (or optimistic one)
    final list = _messagesByPeer[peerId] ?? [];
    if (list.any((m) => m.id == messageId)) return;

    final int fromId = data['fromId'] as int? ?? (isOut ? (_activeAccount?.userId ?? 0) : peerId);

    // If it's outgoing, check if we had a pending negative ID message
    if (isOut) {
      final pendingIndex = list.indexWhere((m) =>
          (m.id < 0 || m.id == messageId) &&
          (m.text == text ||
              (m.text.isEmpty && text.isEmpty) ||
              DateTime.now().difference(m.date).inSeconds.abs() < 30));
      if (pendingIndex != -1) {
        final existing = list[pendingIndex];
        list[pendingIndex] = existing.copyWith(
          id: messageId,
          text: text.isNotEmpty ? text : existing.text,
          replyMessage: existing.replyMessage,
          photo: existing.photo,
          photos: existing.photos,
          doc: existing.doc,
        );
        notifyListeners();
        return;
      }
    }

    VKUser? sender = _api.cachedUsers[fromId];
    if (sender == null && fromId < 0) {
      final gr = _api.cachedGroups[-fromId];
      if (gr != null) {
        sender = VKUser(id: -gr.id, firstName: gr.name, lastName: '', photo100: gr.photo100, photo200: gr.photo200);
      }
    }

    final newMsg = VKMessage(
      id: messageId,
      peerId: peerId,
      fromId: fromId,
      date: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
      text: text,
      isOut: isOut,
      readState: false,
      sender: sender,
    );

    _appendMessage(peerId, newMsg);

    if (sender == null && fromId != 0) {
      _resolveMissingUser(fromId, peerId, messageId);
    }

    // Clear typing indicator when message received
    final senderId = isOut ? (_activeAccount?.userId ?? 0) : peerId;
    _typingUsers[peerId]?.remove(senderId);
    if (_typingUsers[peerId]?.isEmpty == true) {
      _typingUsers.remove(peerId);
    }

    // Update conversation
    final convIndex = _conversations.indexWhere((c) => c.peerId == peerId);
    if (convIndex != -1) {
      final old = _conversations[convIndex];
      final curUid = _activeAccount?.userId;
      final isMention = !isOut && curUid != null && curUid > 0 && text.contains('[id$curUid|');
      final newHasMention = (_selectedPeerId != peerId) ? (old.hasUnreadMention || isMention) : false;
      final newUnread = (!isOut && _selectedPeerId != peerId) ? old.unreadCount + 1 : old.unreadCount;
      _conversations.removeAt(convIndex);
      _conversations.insert(
        0,
        old.copyWith(
          lastMessage: newMsg,
          lastMessageId: messageId,
          unreadCount: newUnread,
          hasUnreadMention: newHasMention,
        ),
      );
    } else {
      // Re-fetch conversations if unseen chat
      fetchConversations();
    }

    // Auto mark as read and fetch full message data if this chat is open
    if (_selectedPeerId == peerId && !isOut) {
      markAsRead(peerId);
      fetchHistory(peerId);
    }

    // Trigger desktop system notification for incoming messages
    if (!isOut && !isMuted(peerId) && _selectedPeerId != peerId) {
      final conv = _conversations.where((c) => c.peerId == peerId).firstOrNull;
      final senderName = sender?.fullName ?? (conv?.title ?? 'Пользователь $fromId');
      final chatTitle = (conv != null && conv.isGroupChat) ? conv.title : null;

      String notificationBody = text.trim();
      if (notificationBody.isEmpty) {
        final extra = data['extra'] as Map<String, dynamic>?;
        final attachType = extra?['attach1_type']?.toString();
        if (attachType == 'sticker') {
          notificationBody = 'Стикер';
        } else if (attachType == 'photo') {
          notificationBody = 'Фотография';
        } else if (attachType == 'doc') {
          notificationBody = 'Документ';
        } else if (attachType == 'audio' || attachType == 'audiomsg') {
          notificationBody = 'Голосовое сообщение';
        } else {
          notificationBody = 'Новое сообщение';
        }
      }

      NotificationService.instance.showMessageNotification(
        peerId: peerId,
        senderName: senderName,
        text: notificationBody,
        chatTitle: chatTitle,
      );
    }

    notifyListeners();
  }

  void _handleMessagesReadEvent(int peerId, int messageId, bool isOut) {
    final list = _messagesByPeer[peerId];
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].id <= messageId && list[i].isOut == isOut) {
          list[i] = list[i].copyWith(readState: true);
        }
      }
      notifyListeners();
    }
  }

  final Map<String, Timer> _typingTimers = {};

  void _handleTypingEvent(int peerId, int userId) {
    if (_typingUsers[peerId] == null) {
      _typingUsers[peerId] = {};
    }
    _typingUsers[peerId]!.add(userId);
    notifyListeners();

    final timerKey = '$peerId-$userId';
    _typingTimers[timerKey]?.cancel();
    _typingTimers[timerKey] = Timer(const Duration(seconds: 6), () {
      _typingUsers[peerId]?.remove(userId);
      if (_typingUsers[peerId]?.isEmpty == true) {
        _typingUsers.remove(peerId);
      }
      _typingTimers.remove(timerKey);
      notifyListeners();
    });
  }

  void _handleStoppedTypingEvent(int peerId) {
    _typingUsers.remove(peerId);
    notifyListeners();
  }

  void _handleUserOnlineChanged(int userId, bool isOnline) {
    final idx = _conversations.indexWhere((c) => c.peerId == userId);
    if (idx != -1) {
      _conversations[idx] = _conversations[idx].copyWith(
        isOnline: isOnline,
        lastSeen: isOnline ? DateTime.now() : _conversations[idx].lastSeen,
      );
      notifyListeners();
    }
  }

  void _resolveMissingUser(int fromId, int peerId, int messageId) async {
    try {
      if (fromId > 0) {
        final users = await _api.getUsers([fromId]);
        if (users.isNotEmpty) {
          final u = users.first;
          final list = _messagesByPeer[peerId];
          if (list != null) {
            final idx = list.indexWhere((m) => m.id == messageId);
            if (idx != -1 && list[idx].sender == null) {
              list[idx] = list[idx].copyWith(sender: u);
              notifyListeners();
            }
          }
        }
      } else if (fromId < 0) {
        final groups = await _api.getGroups([-fromId]);
        if (groups.isNotEmpty) {
          final gr = groups.first;
          final u = VKUser(id: -gr.id, firstName: gr.name, lastName: '', photo100: gr.photo100, photo200: gr.photo200);
          final list = _messagesByPeer[peerId];
          if (list != null) {
            final idx = list.indexWhere((m) => m.id == messageId);
            if (idx != -1 && list[idx].sender == null) {
              list[idx] = list[idx].copyWith(sender: u);
              notifyListeners();
            }
          }
        }
      }
    } catch (_) {}
  }
}
