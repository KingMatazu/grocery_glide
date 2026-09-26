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
    await _useDeviceTimeZone();

    // Must be a resource that something references statically. The launcher
    // icon here is `@mipmap/launcher_icon`; this used to say
    // `@mipmap/ic_launcher`, which nothing in the manifest or resources
    // pointed at, so AGP's release-only resource optimization dropped it and
    // the lookup below returned 0. The plugin then threw `invalid_icon` from
    // `initialize()`, which ran before `runApp`, so the app sat on the launch
    // screen forever with no error and no crash. Debug and profile builds skip
    // resource optimization, which is why it only ever showed up in release.
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: settings);
  }

  /// Point `tz.local` at the device's timezone.
  ///
  /// `initializeTimeZones` only loads the database; without this, `tz.local`
  /// stays UTC and every reminder is scheduled at the wrong wall-clock time
  /// for everyone outside UTC. There is no timezone-name channel available
  /// without pulling in another plugin, so match a location by current offset.
  Future<void> _useDeviceTimeZone() async {
    final offset = DateTime.now().timeZoneOffset;
    tz.Location? match;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.currentTimeZone.offset == offset) {
        match = location;
        break;
      }
    }
    tz.setLocalLocation(match ?? tz.UTC);
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