import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'openvk_api.dart';

typedef LongPollService = OpenVKLongPollService;
typedef OnNewMessageCallback = void Function(Map<String, dynamic> data);
typedef OnUserTypingCallback = void Function(int peerId, int userId);
typedef OnUserStoppedTypingCallback = void Function(int peerId);
typedef OnUserOnlineChangedCallback = void Function(int userId, bool isOnline);
typedef OnMessagesReadCallback = void Function(int peerId, int messageId, bool isOut);

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v != null) return int.tryParse('$v') ?? 0;
  return 0;
}

class OpenVKLongPollService {
  static final OpenVKLongPollService instance = OpenVKLongPollService._internal();
  OpenVKLongPollService._internal();

  OpenVKLongPollService({OpenVKAPIService? api}) {
    if (api != null) _api = api;
  }

  OpenVKAPIService _api = OpenVKAPIService.instance;

  String? server;
  String? key;
  int? ts;

  bool _isRunning = false;
  http.Client? _client;

  OnNewMessageCallback? _onNewMessage;
  OnMessagesReadCallback? _onMessagesRead;
  OnUserTypingCallback? _onTyping;
  OnUserStoppedTypingCallback? _onStoppedTyping;
  OnUserOnlineChangedCallback? _onUserOnlineChanged;

  void start({
    OpenVKAPIService? api,
    OnNewMessageCallback? onNewMessage,
    OnMessagesReadCallback? onMessagesRead,
    OnUserTypingCallback? onTyping,
    OnUserStoppedTypingCallback? onStoppedTyping,
    OnUserOnlineChangedCallback? onUserOnlineChanged,
  }) {
    if (api != null) _api = api;
    if (onNewMessage != null) _onNewMessage = onNewMessage;
    if (onMessagesRead != null) _onMessagesRead = onMessagesRead;
    if (onTyping != null) _onTyping = onTyping;
    if (onStoppedTyping != null) _onStoppedTyping = onStoppedTyping;
    if (onUserOnlineChanged != null) _onUserOnlineChanged = onUserOnlineChanged;

    if (_isRunning) return;
    _isRunning = true;
    _pollLoop();
  }

  void stop() {
    _isRunning = false;
    _client?.close();
    _client = null;
    server = null;
    key = null;
    ts = null;
  }

  Future<void> _updateServerParams() async {
    final resp = await _api.callMethod('messages.getLongPollServer', {'need_pts': '0', 'lp_version': '3'});
    server = resp['server']?.toString();
    key = resp['key']?.toString();
    ts = resp['ts'] is int ? resp['ts'] : int.tryParse('${resp['ts']}');
  }

  Future<void> _pollLoop() async {
    while (_isRunning) {
      if (!_api.isAuthenticated) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      if (server == null || key == null || ts == null) {
        try {
          await _updateServerParams();
        } catch (_) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
      }

      try {
        String base = server!;
        if (!base.startsWith('http')) base = 'https://$base';

        final uri = Uri.parse('$base?act=a_check&key=$key&ts=$ts&wait=25&mode=2&version=3');
        _client = http.Client();
        final res = await _client!.get(uri);

        if (res.statusCode != 200) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        final data = jsonDecode(res.body);
        if (data['failed'] != null) {
          final code = data['failed'];
          if (code == 1) {
            ts = data['ts'];
          } else {
            server = null;
            key = null;
            ts = null;
          }
          continue;
        }

        if (data['ts'] != null) {
          ts = data['ts'] is int ? data['ts'] : int.tryParse('${data['ts']}');
        }

        final updates = data['updates'] as List? ?? [];
        for (final u in updates) {
          if (u is! List || u.isEmpty) continue;
          final int code = _toInt(u[0]);

          if (code == 4) {
            // [4, message_id, flags, peer_id, timestamp, text, extra, attachments]
            final int msgId = u.length > 1 ? _toInt(u[1]) : 0;
            final int flags = u.length > 2 ? _toInt(u[2]) : 0;
            final int peerId = u.length > 3 ? _toInt(u[3]) : 0;
            final int timeSec = u.length > 4 ? _toInt(u[4]) : 0;

            String text = '';
            Map<String, dynamic>? extra;
            if (u.length > 6) {
              if (u[6] is Map) {
                text = u.length > 5 ? u[5].toString() : '';
                extra = Map<String, dynamic>.from(u[6] as Map);
              } else if (u[6] is String) {
                text = u[6].toString();
                if (u.length > 7 && u[7] is Map) {
                  extra = Map<String, dynamic>.from(u[7] as Map);
                }
                if (text.isEmpty && u.length > 5) {
                  text = u[5].toString();
                }
              }
            } else if (u.length > 5) {
              text = u[5].toString();
            }

            int fromId = (flags & 2) != 0 ? (_api.currentUser?.id ?? 0) : peerId;
            if (extra != null && extra['from'] != null) {
              fromId = _toInt(extra['from']);
            }

            _onNewMessage?.call({
              'id': msgId,
              'flags': flags,
              'peerId': peerId,
              'fromId': fromId,
              'timestamp': timeSec,
              'text': text,
              'extra': extra,
            });
          } else if (code == 6) {
            final int peerId = u.length > 1 ? _toInt(u[1]) : 0;
            final int upToId = u.length > 2 ? _toInt(u[2]) : 0;
            _onMessagesRead?.call(peerId, upToId, false);
          } else if (code == 7) {
            final int peerId = u.length > 1 ? _toInt(u[1]) : 0;
            final int upToId = u.length > 2 ? _toInt(u[2]) : 0;
            _onMessagesRead?.call(peerId, upToId, true);
          } else if (code == 8) {
            // [8, -user_id, flags, timestamp]
            if (u.length > 1) {
              final int uid = _toInt(u[1]).abs();
              _onUserOnlineChanged?.call(uid, true);
            }
          } else if (code == 9) {
            // [9, -user_id, flags, timestamp]
            if (u.length > 1) {
              final int uid = _toInt(u[1]).abs();
              _onUserOnlineChanged?.call(uid, false);
            }
          } else if (code == 61) {
            // [61, user_id, flags]
            final int userId = u.length > 1 ? _toInt(u[1]) : 0;
            _onTyping?.call(userId, userId);
          } else if (code == 62) {
            // [62, user_id, chat_id]
            final int userId = u.length > 1 ? _toInt(u[1]) : 0;
            final int chatId = u.length > 2 ? _toInt(u[2]) : 0;
            final int peerId = 2000000000 + chatId;
            _onTyping?.call(peerId, userId);
          } else if (code == 63) {
            // [63, peer_id, user_ids, total_count, timestamp]
            final int peerId = u.length > 1 ? _toInt(u[1]) : 0;
            final int totalCount = u.length > 3 ? _toInt(u[3]) : 1;
            if (totalCount == 0) {
              _onStoppedTyping?.call(peerId);
            } else {
              int userId = peerId;
              if (u.length > 2) {
                final uids = u[2];
                if (uids is List && uids.isNotEmpty) {
                  userId = _toInt(uids.first);
                } else if (uids is int || uids is num) {
                  userId = _toInt(uids);
                }
              }
              _onTyping?.call(peerId, userId);
            }
          } else if (code == 64) {
            // [64, peer_id, user_ids, total_count, timestamp] (Audio recording)
            final int peerId = u.length > 1 ? _toInt(u[1]) : 0;
            _onTyping?.call(peerId, peerId);
          }
        }
      } catch (e) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }
}
