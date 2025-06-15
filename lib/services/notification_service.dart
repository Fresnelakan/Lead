import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  NotificationService(this._flutterLocalNotificationsPlugin);

  static Future<void> configureTimeZone() async {
    tz.initializeTimeZones();
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final tzScheduledTime = tz.TZDateTime.from(
      scheduledTime.subtract(const Duration(minutes: 15)),
      tz.local,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'activity_channel',
          'Activity Notifications',
          channelDescription: 'Notifications for upcoming activities',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  static void onDidReceiveNotificationResponseCallback(NotificationResponse response) {
    // Gérer l'interaction avec la notification (ex. : clic)
    print('Notification cliquée : ${response.payload}');
    // TODO: Naviguer vers une page spécifique (ex. : détails de l'activité)
  }

  static void onDidReceiveBackgroundNotificationResponseCallback(NotificationResponse response) {
    // Gérer les notifications en arrière-plan
    print('Notification en arrière-plan : ${response.payload}');
    // TODO: Actions spécifiques si l'app est en arrière-plan
  }
}