import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    tz.initializeTimeZones();
    // Set to Indian Standard Time (IST)
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Request permissions for Android
    final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledTime) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminder_channel',
          'Medicine Reminders',
          channelDescription: 'Channel for medication alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleDailyMedicineReminders({
    required String medicineName,
    required String dosage,
    required String timing,
    required String mealRelation,
    required Map<String, String> mealTimes,
  }) async {
    // Only schedule for "Before Food" medicines
    if (mealRelation != 'Before Food') return;

    String? mealTimeStr;
    int notificationId;

    // Determine which meal time to use based on timing
    switch (timing) {
      case 'Morning':
        mealTimeStr = mealTimes['breakfast'];
        notificationId = medicineName.hashCode.abs() % 10000; // Unique ID for breakfast
        break;
      case 'Afternoon':
        mealTimeStr = mealTimes['lunch'];
        notificationId = (medicineName.hashCode.abs() % 10000) + 10000; // Unique ID for lunch
        break;
      case 'Night':
        mealTimeStr = mealTimes['dinner'];
        notificationId = (medicineName.hashCode.abs() % 10000) + 20000; // Unique ID for dinner
        break;
      default:
        return;
    }

    if (mealTimeStr == null || mealTimeStr.isEmpty) return;

    // Parse meal time
    final parts = mealTimeStr.split(':');
    if (parts.length != 2) return;
    
    final mealHour = int.parse(parts[0]);
    final mealMinute = int.parse(parts[1]);

    // Calculate reminder time (15 minutes before meal)
    final now = DateTime.now();
    DateTime reminderTime = DateTime(
      now.year,
      now.month,
      now.day,
      mealHour,
      mealMinute,
    ).subtract(const Duration(minutes: 15));

    // If the time has passed today, schedule for tomorrow
    if (reminderTime.isBefore(now)) {
      reminderTime = reminderTime.add(const Duration(days: 1));
    }

    // Convert to TZDateTime
    final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

    print('Scheduling notification for $medicineName at ${tzReminderTime.toString()}');
    print('Notification ID: $notificationId');

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: '💊 Medicine Reminder',
      body: 'Time to take $medicineName ($dosage) - 15 minutes before ${timing.toLowerCase()}',
      scheduledDate: tzReminderTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminder_channel',
          'Medicine Reminders',
          channelDescription: 'Channel for medication alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Test notification - fires after 10 seconds
  Future<void> scheduleTestNotification() async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(seconds: 10));
    final tzTestTime = tz.TZDateTime.from(testTime, tz.local);

    print('Scheduling test notification at ${tzTestTime.toString()}');

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 99999,
      title: '🧪 Test Notification',
      body: 'If you see this, notifications are working!',
      scheduledDate: tzTestTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminder_channel',
          'Medicine Reminders',
          channelDescription: 'Channel for medication alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
