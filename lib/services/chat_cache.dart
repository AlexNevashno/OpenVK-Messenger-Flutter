import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/account.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatCache {
  static final ChatCache instance = ChatCache._internal();
  ChatCache._internal();

  Directory? _cacheDir;

  Future<Directory> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    try {
      final appSupport = await getApplicationSupportDirectory();
      _cacheDir = Directory('${appSupport.path}/openvk_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('[ChatCache] Error getting support directory: $e');
      _cacheDir = Directory.systemTemp.createTempSync('openvk_cache');
    }
    return _cacheDir!;
  }

  // MARK: - Accounts Cache
  Future<void> saveAccounts(List<VKAccount> accounts, String? activeId) async {
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/accounts.json');
      final data = {
        'activeId': activeId,
        'accounts': accounts.map((a) => a.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[ChatCache] Error saving accounts: $e');
    }
  }

  Future<Map<String, dynamic>?> loadAccounts() async {
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/accounts.json');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final rawAccounts = decoded['accounts'] as List<dynamic>? ?? [];
      final accounts = rawAccounts
          .map((item) => VKAccount.fromJson(item as Map<String, dynamic>))
          .toList();
      return {
        'activeId': decoded['activeId'] as String?,
        'accounts': accounts,
      };
    } catch (e) {
      debugPrint('[ChatCache] Error loading accounts: $e');
      return null;
    }
  }

  // MARK: - Conversations Cache
  Future<void> saveConversations(int accountId, List<VKConversation> conversations) async {
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/conversations_$accountId.json');
      final list = conversations.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('[ChatCache] Error saving conversations: $e');
    }
  }

  Future<List<VKConversation>?> loadConversations(int accountId) async {
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/conversations_$accountId.json');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((item) => VKConversation.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ChatCache] Error loading conversations: $e');
      return null;
    }
  }

  // MARK: - Messages Cache
  Future<void> saveMessages(int accountId, int peerId, List<VKMessage> messages) async {
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/messages_${accountId}_$peerId.json');
      // Save max latest 100 messages for fast startup
      final slice = messages.length > 100 ? messages.sublist(messages.length - 100) : messages;
      final list = slice.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('[ChatCache] Error saving messages: $e');
    }
  }

  Future<List<VKMessage>?> loadMessages(int accountId, int peerId) async {
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/messages_${accountId}_$peerId.json');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((item) => VKMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ChatCache] Error loading messages: $e');
      return null;
    }
  }

  // MARK: - Clear Cache
  Future<void> clearAll() async {
    try {
      final dir = await cacheDir;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('[ChatCache] Error clearing cache: $e');
    }
  }
}
