import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationStore extends ChangeNotifier {
  static final NotificationStore _instance = NotificationStore._internal();
  factory NotificationStore() => _instance;
  NotificationStore._internal();

  static const String _storageKey = 'ellena_notifications';
  static const int _maxNotifications = 50;

  List<AppNotification> _notifications = [];
  bool _initialized = false;


  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        _notifications = AppNotification.decodeList(raw);
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationStore: Error loading notifications: $e');
    }
  }


  List<AppNotification> getAll() {
    final list = List<AppNotification>.from(_notifications);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

 
  Future<void> addNotification(AppNotification notif) async {
    try {
      _notifications.insert(0, notif);
      
      if (_notifications.length > _maxNotifications) {
        _notifications = _notifications.sublist(0, _maxNotifications);
      }
      await _persist();
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationStore: Error adding notification: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      for (final n in _notifications) {
        n.isRead = true;
      }
      await _persist();
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationStore: Error marking all as read: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index].isRead = true;
        await _persist();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NotificationStore: Error marking notification as read: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      _notifications.clear();
      await _persist();
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationStore: Error clearing notifications: $e');
    }
  }

  
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        AppNotification.encodeList(_notifications),
      );
    } catch (e) {
      debugPrint('NotificationStore: Error persisting notifications: $e');
    }
  }
}
