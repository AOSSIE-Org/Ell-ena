import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _masterEnabled = true;
  bool _tasksEnabled = true;
  bool _meetingsEnabled = true;
  bool _dailyDigestEnabled = true;
  bool _tasksDayBefore = true;
  bool _meetings15min = true;
  bool _loaded = false;
  bool _isRescheduling = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _masterEnabled = prefs.getBool('notif_master_enabled') ?? true;
        _tasksEnabled = prefs.getBool('notif_tasks_enabled') ?? true;
        _meetingsEnabled = prefs.getBool('notif_meetings_enabled') ?? true;
        _dailyDigestEnabled =
            prefs.getBool('notif_daily_digest_enabled') ?? true;
        _tasksDayBefore = prefs.getBool('notif_tasks_day_before') ?? true;
        _meetings15min = prefs.getBool('notif_meetings_15min') ?? true;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('NotificationSettings: Error loading prefs: $e');
      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('NotificationSettings: Error saving pref $key: $e');
    }
  }

  Future<void> _onMasterToggled(bool value) async {
    setState(() => _masterEnabled = value);
    await _saveBool('notif_master_enabled', value);
    if (!value) {
      await NotificationService().cancelAll();
    } else {
      await _reschedule();
    }
  }

  Future<void> _reschedule() async {
    if (_isRescheduling) return;
    setState(() => _isRescheduling = true);
    try {
      await NotificationService().rescheduleFromSupabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications rescheduled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationSettings: Error rescheduling: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rescheduling: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRescheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Settings',
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
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Push Notifications'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildToggle(
                        icon: _isRescheduling
                            ? Icons.sync
                            : Icons.notifications_active_outlined,
                        color: Colors.red.shade400,
                        title: 'Enable Notifications',
                        subtitle: _isRescheduling ? 'Rescheduling...' : null,
                        value: _masterEnabled,
                        onChanged: _isRescheduling ? null : _onMasterToggled,
                      ),
                      _divider(),
                      _buildToggle(
                        icon: Icons.task_alt,
                        color: Colors.green.shade600,
                        title: 'Task Reminders',
                        value: _tasksEnabled,
                        enabled: _masterEnabled,
                        onChanged: (v) async {
                          setState(() => _tasksEnabled = v);
                          await _saveBool('notif_tasks_enabled', v);
                          await _reschedule();
                        },
                      ),
                      _divider(),
                      _buildToggle(
                        icon: Icons.people,
                        color: Colors.blue.shade600,
                        title: 'Meeting Alerts',
                        value: _meetingsEnabled,
                        enabled: _masterEnabled,
                        onChanged: (v) async {
                          setState(() => _meetingsEnabled = v);
                          await _saveBool('notif_meetings_enabled', v);
                          await _reschedule();
                        },
                      ),
                      _divider(),
                      _buildToggle(
                        icon: Icons.wb_sunny_outlined,
                        color: Colors.orange.shade600,
                        title: 'Daily Digest (8:00 AM)',
                        value: _dailyDigestEnabled,
                        enabled: _masterEnabled,
                        onChanged: (v) async {
                          setState(() => _dailyDigestEnabled = v);
                          await _saveBool('notif_daily_digest_enabled', v);
                          await _reschedule();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Reminder Timing'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildToggle(
                        icon: Icons.access_time,
                        color: Colors.purple.shade400,
                        title: 'Day Before Task Deadline',
                        value: _tasksDayBefore,
                        enabled: _masterEnabled,
                        onChanged: (v) async {
                          setState(() => _tasksDayBefore = v);
                          await _saveBool('notif_tasks_day_before', v);
                          await _reschedule();
                        },
                      ),
                      _divider(),
                      _buildToggle(
                        icon: Icons.alarm,
                        color: Colors.teal,
                        title: '15 Min Before Meeting',
                        value: _meetings15min,
                        enabled: _masterEnabled,
                        onChanged: (v) async {
                          setState(() => _meetings15min = v);
                          await _saveBool('notif_meetings_15min', v);
                          await _reschedule();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle('About'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.info_outline,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    title: Text(
                      'How notifications work',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant),
                    onTap: () => _showAboutDialog(context),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _divider() {
    return Divider(
      color: Theme.of(context).colorScheme.outlineVariant,
      height: 1,
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required bool value,
    bool enabled = true,
    ValueChanged<bool>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveOpacity = enabled ? 1.0 : 0.4;

    return Opacity(
      opacity: effectiveOpacity,
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(color: colorScheme.onSurfaceVariant))
            : null,
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: Colors.green.shade400,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How notifications work'),
        content: const Text(
          'Ell-ena schedules notifications locally on your device. '
          'They work fully offline and are rescheduled each time you '
          'open the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
