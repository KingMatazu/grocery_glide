import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);
  }

  Future<bool?> requestPermission() async {
    return _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> ensureDefaultReminders() async {
    const prefsKey = 'daily_reminders_enabled';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefsKey) == false) return;

    final grantedAndroid = await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    final grantedIos = await _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted = grantedAndroid ?? grantedIos ?? false;
    await prefs.setBool(prefsKey, granted);

    if (granted) {
      await scheduleDailyReminders();
    } else {
      await cancelAllReminders();
    }
  }

  Future<void> scheduleDailyReminders() async {
    await _scheduleReminder(
      id: 1001,
      channelId: 'morning_reminder',
      channelName: 'Morning Shopping Reminder',
      hour: 10,
      minute: 0,
      title: 'Good morning!',
      body: 'Time to plan today\'s grocery run.',
    );
    await _scheduleReminder(
      id: 1002,
      channelId: 'afternoon_reminder',
      channelName: 'Afternoon Shopping Reminder',
      hour: 16,
      minute: 0,
      title: 'Afternoon check-in',
      body: 'Don\'t forget to update your list before you head to the store.',
    );
    await _scheduleReminder(
      id: 1003,
      channelId: 'evening_reminder',
      channelName: 'Evening Shopping Reminder',
      hour: 19,
      minute: 30,
      title: 'Evening wrap-up',
      body: 'Did you get everything on your list today?',
    );
  }

  Future<void> _scheduleReminder({
    required int id,
    required String channelId,
    required String channelName,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final details = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If today's time has already passed, schedule for tomorrow instead.
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }
}