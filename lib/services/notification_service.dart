import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

static Future<void> initialize() async {
  tz.initializeTimeZones(); // Initialiser les fuseaux horaires
  tz.setLocalLocation(tz.getLocation('Africa/Porto-Novo')); // ou ton fuseau

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Gérer les notifications reçues au premier plan
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });
}

  static Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }
  static Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
}) async {
  await _flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    title,
    body,
    tz.TZDateTime.from(scheduledTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'scheduled_channel',
        'Rappels de cours',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );
}
   static Future<NotificationService> initAndGet() async {
    final service = NotificationService();
    await NotificationService.initialize(); // Use the existing static initialize method
    return service;
  }

  static Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'default_channel_id',
      'Default Channel',
      channelDescription: 'This is the default channel for notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
  }
}
