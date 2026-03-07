import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../screens/tasks/task_detail_screen.dart';
import '../screens/meetings/meeting_detail_screen.dart';
import 'notification_store.dart';
import 'navigation_service.dart';
import 'supabase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  int _taskNotifId(String taskId) => taskId.hashCode.abs() % 100000000;
  int _meetingNotifId(String meetingId) =>
      500000000 + (meetingId.hashCode.abs() % 100000000);
  static const int _digestId = 1000000000;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_launcher_foreground');

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'ellena_tasks',
            'Task Reminders',
            description: 'Reminders for upcoming task deadlines',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'ellena_meetings',
            'Meeting Alerts',
            description: 'Alerts for upcoming meetings',
            importance: Importance.max,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'ellena_daily_digest',
            'Daily Digest',
            description: 'Daily summary of pending tasks and meetings',
            importance: Importance.defaultImportance,
          ),
        );

        await androidPlugin.requestNotificationsPermission();
      }

      await NotificationStore().initialize();
      _initialized = true;
      debugPrint('NotificationService: initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Error during initialization: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;

      final parts = payload.split(':');
      if (parts.length < 2) return;

      final type = parts[0];
      final id = parts.sublist(1).join(':');

      if (type == 'task') {
        NavigationService().navigateTo(TaskDetailScreen(taskId: id));
      } else if (type == 'meeting') {
        NavigationService().navigateTo(MeetingDetailScreen(meetingId: id));
      }
    } catch (e) {
      debugPrint('NotificationService: Error handling notification tap: $e');
    }
  }

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    String? description,
  }) async {
    try {
      final now = DateTime.now();
      if (dueDate.isBefore(now)) return;

      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('notif_master_enabled') ?? true)) return;
      if (!(prefs.getBool('notif_tasks_enabled') ?? true)) return;

      final id = _taskNotifId(taskId);

      final dayBefore = dueDate.subtract(const Duration(days: 1));
      if (dayBefore.isAfter(now) &&
          (prefs.getBool('notif_tasks_day_before') ?? true)) {
        await _plugin.zonedSchedule(
          id,
          '📋 Task Due Tomorrow',
          '$taskTitle is due tomorrow',
          tz.TZDateTime.from(dayBefore.toLocal(), tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'ellena_tasks',
              'Task Reminders',
              channelDescription: 'Reminders for upcoming task deadlines',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@drawable/ic_launcher_foreground',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task:$taskId',
        );

        await NotificationStore().addNotification(
          AppNotification(
            id: '${taskId}_day_before',
            title: 'Scheduled: Task Due Tomorrow',
            body: '$taskTitle is due tomorrow',
            type: AppNotificationType.task,
            referenceId: taskId,
            createdAt: DateTime.now(),
          ),
        );
      }

      await _plugin.zonedSchedule(
        id + 1,
        '⏰ Task Due Now',
        '$taskTitle is due now',
        tz.TZDateTime.from(dueDate.toLocal(), tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'ellena_tasks',
            'Task Reminders',
            channelDescription: 'Reminders for upcoming task deadlines',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_launcher_foreground',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task:$taskId',
      );
    } catch (e) {
      debugPrint('NotificationService: Error scheduling task reminder: $e');
    }
  }

  Future<void> cancelTaskNotification(String taskId) async {
    try {
      final id = _taskNotifId(taskId);
      await _plugin.cancel(id);
      await _plugin.cancel(id + 1);
    } catch (e) {
      debugPrint('NotificationService: Error cancelling task notification: $e');
    }
  }

  Future<void> scheduleMeetingReminder({
    required String meetingId,
    required String meetingTitle,
    required DateTime meetingDate,
    String? meetingUrl,
  }) async {
    try {
      final now = DateTime.now();
      if (meetingDate.isBefore(now)) return;

      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('notif_master_enabled') ?? true)) return;
      if (!(prefs.getBool('notif_meetings_enabled') ?? true)) return;

      final id = _meetingNotifId(meetingId);

      final fifteenBefore = meetingDate.subtract(const Duration(minutes: 15));
      if (fifteenBefore.isAfter(now) &&
          (prefs.getBool('notif_meetings_15min') ?? true)) {
        final body = meetingUrl != null && meetingUrl.isNotEmpty
            ? '$meetingTitle starts in 15 minutes\nJoin: $meetingUrl'
            : '$meetingTitle starts in 15 minutes';

        await _plugin.zonedSchedule(
          id,
          '📅 Meeting Starting Soon',
          body,
          tz.TZDateTime.from(fifteenBefore.toLocal(), tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'ellena_meetings',
              'Meeting Alerts',
              channelDescription: 'Alerts for upcoming meetings',
              importance: Importance.max,
              priority: Priority.max,
              fullScreenIntent: true,
              icon: '@drawable/ic_launcher_foreground',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'meeting:$meetingId',
        );

        await NotificationStore().addNotification(
          AppNotification(
            id: '${meetingId}_15min',
            title: 'Scheduled: Meeting Starting Soon',
            body: '$meetingTitle starts in 15 minutes',
            type: AppNotificationType.meeting,
            referenceId: meetingId,
            createdAt: DateTime.now(),
          ),
        );
      }

      await _plugin.zonedSchedule(
        id + 1,
        '🎯 Meeting Starting Now',
        '$meetingTitle is starting now',
        tz.TZDateTime.from(meetingDate.toLocal(), tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'ellena_meetings',
            'Meeting Alerts',
            channelDescription: 'Alerts for upcoming meetings',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            icon: '@drawable/ic_launcher_foreground',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'meeting:$meetingId',
      );
    } catch (e) {
      debugPrint(
          'NotificationService: Error scheduling meeting reminder: $e');
    }
  }

  Future<void> cancelMeetingNotification(String meetingId) async {
    try {
      final id = _meetingNotifId(meetingId);
      await _plugin.cancel(id);
      await _plugin.cancel(id + 1);
    } catch (e) {
      debugPrint(
          'NotificationService: Error cancelling meeting notification: $e');
    }
  }

  Future<void> scheduleDailyDigest({
    required int pendingTaskCount,
    required int upcomingMeetingCount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('notif_master_enabled') ?? true)) return;
      if (!(prefs.getBool('notif_daily_digest_enabled') ?? true)) return;

      await _plugin.cancel(_digestId);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        8,
        0,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final body = '$pendingTaskCount pending tasks, '
          '$upcomingMeetingCount upcoming meetings';

      await _plugin.zonedSchedule(
        _digestId,
        '📊 Daily Digest',
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'ellena_daily_digest',
            'Daily Digest',
            channelDescription: 'Daily summary of pending tasks and meetings',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@drawable/ic_launcher_foreground',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('NotificationService: Error scheduling daily digest: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService: Error cancelling all notifications: $e');
    }
  }

  Future<void> rescheduleAll({
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> meetings,
  }) async {
    try {
      await cancelAll();

      final now = DateTime.now();
      int pendingTaskCount = 0;
      int upcomingMeetingCount = 0;

      for (final task in tasks) {
        final status = task['status']?.toString() ?? '';
        if (status == 'completed') continue;

        final dueStr = task['due_date']?.toString();
        if (dueStr == null) continue;
        final dueDate = DateTime.tryParse(dueStr)?.toLocal();
        if (dueDate == null || dueDate.isBefore(now)) continue;

        pendingTaskCount++;
        await scheduleTaskReminder(
          taskId: task['id']?.toString() ?? '',
          taskTitle: task['title']?.toString() ?? 'Task',
          dueDate: dueDate,
          description: task['description']?.toString(),
        );
      }

      for (final meeting in meetings) {
        final dateStr = meeting['meeting_date']?.toString();
        if (dateStr == null) continue;
        final meetingDate = DateTime.tryParse(dateStr)?.toLocal();
        if (meetingDate == null || meetingDate.isBefore(now)) continue;

        upcomingMeetingCount++;
        await scheduleMeetingReminder(
          meetingId: meeting['id']?.toString() ?? '',
          meetingTitle: meeting['title']?.toString() ?? 'Meeting',
          meetingDate: meetingDate,
          meetingUrl: meeting['meeting_url']?.toString(),
        );
      }

      await scheduleDailyDigest(
        pendingTaskCount: pendingTaskCount,
        upcomingMeetingCount: upcomingMeetingCount,
      );
    } catch (e) {
      debugPrint(
          'NotificationService: Error rescheduling all notifications: $e');
    }
  }

  /// Fetches tasks and meetings from Supabase and reschedules all notifications.
  Future<void> rescheduleFromSupabase() async {
    try {
      final tasks = await SupabaseService().getTasks();
      final meetings = await SupabaseService().getMeetings();
      await rescheduleAll(
        tasks: List<Map<String, dynamic>>.from(tasks),
        meetings: List<Map<String, dynamic>>.from(meetings),
      );
    } catch (e) {
      debugPrint('NotificationService: Error in rescheduleFromSupabase: $e');
    }
  }
}
