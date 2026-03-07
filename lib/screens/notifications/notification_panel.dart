import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../services/notification_store.dart';
import '../tasks/task_detail_screen.dart';
import '../meetings/meeting_detail_screen.dart';

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            tooltip: 'Mark all as read',
            onPressed: () => NotificationStore().markAllAsRead(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            tooltip: 'Clear all',
            onPressed: () => _confirmClearAll(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: NotificationStore(),
        builder: (context, _) {
          final notifications = NotificationStore().getAll();
          if (notifications.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) =>
                _buildNotificationItem(context, notifications[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Task reminders and meeting alerts\nwill appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, AppNotification notif) {
    final IconData icon = _iconDataForType(notif.type);
    final Color color = _colorForType(notif.type);
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      tileColor: notif.isRead
          ? null
          : colorScheme.primaryContainer.withOpacity(0.15),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        notif.title,
        style: TextStyle(
          fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notif.body.isNotEmpty)
            Text(
              notif.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            _relativeTime(notif.createdAt),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: notif.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
      onTap: () {
        NotificationStore().markAsRead(notif.id);
        if (notif.referenceId != null) {
          if (notif.type == AppNotificationType.task) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TaskDetailScreen(taskId: notif.referenceId!),
              ),
            );
          } else if (notif.type == AppNotificationType.meeting) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MeetingDetailScreen(meetingId: notif.referenceId!),
              ),
            );
          }
        }
      },
    );
  }

  IconData _iconDataForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.task:
        return Icons.task_alt;
      case AppNotificationType.meeting:
        return Icons.people;
      case AppNotificationType.system:
        return Icons.info_outline;
    }
  }

  Color _colorForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.task:
        return Colors.green.shade600;
      case AppNotificationType.meeting:
        return Colors.blue.shade600;
      case AppNotificationType.system:
        return Colors.grey.shade600;
    }
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.isNegative) return 'just now';
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content:
            const Text('This will remove all notifications. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              NotificationStore().clearAll();
              Navigator.pop(ctx);
            },
            child: Text(
              'Clear All',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
