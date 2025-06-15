// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'dart:convert';
import 'dart:async'; // Added for Completer

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  Completer<void>? _initializeCompleter; // To track async initialization completion

  static const AndroidNotificationDetails _androidSettings = AndroidNotificationDetails(
    'lead_channel_id',
    'Lead Notifications',
    channelDescription: 'Notifications pour les rappels de Lead App',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
  );

  static const DarwinNotificationDetails _iosSettings = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  // Initialize method now returns a Future that completes when the plugin is fully ready
  Future<void> initialize() async {
    // If initialization is already in progress, return the existing completer's future
    if (_initializeCompleter != null && !_initializeCompleter!.isCompleted) {
      return _initializeCompleter!.future;
    }
    // If already initialized, return immediately (plugin exists and completer is completed)
    if (_notificationsPlugin != null && _initializeCompleter?.isCompleted == true) {
      return;
    }

    _initializeCompleter = Completer<void>(); // Create a new completer
    _notificationsPlugin = FlutterLocalNotificationsPlugin(); // Instantiate the plugin

    try {
      await _configureTimeZone();
      await _initializeNotifications();
      print('NotificationService initialized successfully.');
      _initializeCompleter!.complete(); // Mark completion
    } catch (e) {
      print('Error during NotificationService initialization: $e');
      _initializeCompleter!.completeError(e); // Mark error completion
      rethrow; // Re-throw the error to the caller
    }
    return _initializeCompleter!.future;
  }

  Future<void> _configureTimeZone() async {
    tz.initializeTimeZones();
    final String? timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(timeZoneName != null ? tz.getLocation(timeZoneName) : tz.getLocation('UTC'));
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidInitialization =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitialization =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitialization,
      iOS: iosInitialization,
    );

    await _notificationsPlugin!.initialize( // Assert non-null here
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          _handleNotification(data);
        }
      },
      onDidReceiveBackgroundNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          _handleNotification(data);
        }
      },
    );
  }

  // Helper to ensure the plugin is ready before any operation
  Future<void> _ensureInitialized() async {
    // If _notificationsPlugin is null, or if initialization is still in progress (completer not completed),
    // then call initialize() and wait for it.
    // The initialize() method will handle if it's already in progress or completed.
    if (_notificationsPlugin == null || (_initializeCompleter != null && !_initializeCompleter!.isCompleted)) {
      await initialize();
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    await _ensureInitialized(); // Wait until plugin is fully ready

    if (scheduledDate.isBefore(DateTime.now())) {
      print('La date de planification est déjà passée pour la notification ID: $id. Non planifiée.');
      return;
    }

    try {
      await _notificationsPlugin!.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: _androidSettings,
          iOS: _iosSettings,
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      print('Notification planifiée : ID $id, Titre: $title, À: $scheduledDate');
    } catch (e) {
      print('Erreur lors de la planification de la notification ID: $id. Erreur: $e');
    }
  }

  void _handleNotification(Map<String, dynamic> data) {
    print('Notification reçue (payload) : $data');
  }

  Future<void> cancelNotification(int id) async {
    await _ensureInitialized(); // Wait until plugin is fully ready
    await _notificationsPlugin!.cancel(id);
    print('Notification ID $id annulée.');
  }

  Future<void> cancelAllNotifications() async {
    await _ensureInitialized(); // Wait until plugin is fully ready
    await _notificationsPlugin!.cancelAll();
    print('Toutes les notifications annulées.');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Notification FCM en arrière-plan reçue: ${message.notification?.title}');
}
