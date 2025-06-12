import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart'; // Pour obtenir le fuseau horaire natif

// Récupérez l'instance globale du plugin de notification
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  // Méthode pour planifier une notification
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // S'assurer que le fuseau horaire local est bien initialisé
    final String? timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName!));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local), // Utilise le fuseau horaire local
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lead_schedule_channel', // ID du canal (doit être unique)
          'Rappels de Planning Lead', // Nom du canal visible par l'utilisateur
          channelDescription: 'Notifications pour les rappels de cours et activités.',
          importance: Importance.max,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification_sound'), // Optionnel: son personnalisé
        ),
        iOS: DarwinNotificationDetails(
          sound: 'notification_sound.caf', // Optionnel: son personnalisé
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Important pour Android pour déclencher même en mode veille
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime, // Planifie à une date et heure précise
      payload: payload, // Données supplémentaires à passer au clic de la notification
    );
  }

  // Méthode pour annuler une notification spécifique
  static Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // Méthode pour annuler toutes les notifications
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Méthode pour obtenir les notifications en attente
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }
}