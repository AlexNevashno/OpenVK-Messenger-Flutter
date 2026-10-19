import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'messenger_store.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  bool _initialized = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;

  static const String _kPrefNotificationsEnabled = 'openvk_notifications_enabled';
  static const String _kPrefSoundEnabled = 'openvk_notification_sound_enabled';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(_kPrefNotificationsEnabled) ?? true;
      _soundEnabled = prefs.getBool(_kPrefSoundEnabled) ?? true;

      await localNotifier.setup(
        appName: 'OpenVK Messenger',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      debugPrint('[NotificationService] Desktop notification service initialized successfully.');
    } catch (e) {
      debugPrint('[NotificationService] Initialization error (continuing without breaking): $e');
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefNotificationsEnabled, value);
    } catch (e) {
      debugPrint('[NotificationService] Error saving notifications setting: $e');
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefSoundEnabled, value);
    } catch (e) {
      debugPrint('[NotificationService] Error saving sound setting: $e');
    }
  }

  /// Displays desktop system notification for an incoming message
  Future<void> showMessageNotification({
    required int peerId,
    required String senderName,
    required String text,
    String? chatTitle,
  }) async {
    if (!_notificationsEnabled) return;

    try {
      String displayTitle;
      String? displaySubtitle;

      if (chatTitle != null && chatTitle.isNotEmpty && chatTitle != senderName) {
        displayTitle = chatTitle;
        displaySubtitle = senderName;
      } else {
        displayTitle = senderName.isNotEmpty ? senderName : 'OpenVK Messenger';
      }

      String body = text.trim();
      if (body.isEmpty) {
        body = 'Новое сообщение';
      }

      final notification = LocalNotification(
        identifier: 'openvk_${peerId}_${DateTime.now().millisecondsSinceEpoch}',
        title: displayTitle,
        subtitle: displaySubtitle,
        body: body,
        silent: !_soundEnabled,
      );

      notification.onClick = () {
        debugPrint('[NotificationService] Notification clicked for peerId: $peerId');
        MessengerStore.instance.selectPeer(peerId);
      };

      await notification.show();
    } catch (e) {
      debugPrint('[NotificationService] Error showing notification: $e');
    }
  }
}
