import 'dart:convert';

enum AppNotificationType { task, meeting, system }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationType type;
  final String? referenceId;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: AppNotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AppNotificationType.system,
      ),
      referenceId: json['referenceId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  
  static String encodeList(List<AppNotification> notifications) {
    return jsonEncode(notifications.map((n) => n.toJson()).toList());
  }

  
  static List<AppNotification> decodeList(String jsonString) {
    final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
