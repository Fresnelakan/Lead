import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz; // `latest.dart` ou `latest_all.dart`

class NotificationService {
  // L'instance de FlutterLocalNotificationsPlugin doit être passée ou initialisée
  // Vous l'avez déjà initialisée globalement dans main.dart, c'est bien.
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  NotificationService(this._flutterLocalNotificationsPlugin);

  // Configure le fuseau horaire (appelé dans main.dart)
  static Future<void> configureTimeZone() async {
    tz.initializeTimeZones();
  }

  // Fonction pour afficher une notification immédiate (utile pour FCM au premier plan sur mobile)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload, // Ajout du payload pour le lien profond
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'activity_channel', // Doit correspondre à l'ID de canal utilisé dans scheduleNotification
      'Activity Notifications',
      channelDescription: 'Notifications for upcoming activities',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Planifie une notification locale (principalement pour mobile)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload, // Ajout du payload
    int minutesBefore = 15, // Permet de définir combien de minutes avant
  }) async {
    final tzScheduledTime = tz.TZDateTime.from(
      scheduledTime.subtract(Duration(minutes: minutesBefore)),
      tz.local,
    );

    // Vérifier si la date est dans le futur
    if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      print('Skipping scheduling notification for past time: $title at $tzScheduledTime');
      return;
    }

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
      // `matchDateTimeComponents` peut être utile pour des rappels quotidiens/hebdomadaires,
      // mais attention à ne pas l'utiliser pour des rappels uniques précis.
      // matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
    print('Notification locale planifiée: $title pour $tzScheduledTime');
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Ces callbacks sont gérées dans main.dart pour une meilleure centralisation
  // static void onDidReceiveNotificationResponseCallback(NotificationResponse response) {
  //   print('Notification cliquée : ${response.payload}');
  // }
  // static void onDidReceiveBackgroundNotificationResponseCallback(NotificationResponse response) {
  //   print('Notification en arrière-plan : ${response.payload}');
  // }
}
