import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'wrapper.dart';
import 'services/notification_service.dart';

late NotificationService notificationService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    try {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    } catch (e) {
      print('Erreur émulateurs : $e');
    }
  }

  // Initialiser le fuseau horaire et les notifications locales
  await NotificationService.configureTimeZone();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidInitialization =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInitialization =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidInitialization,
    iOS: iosInitialization,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: NotificationService.onDidReceiveNotificationResponseCallback,
    onDidReceiveBackgroundNotificationResponse: NotificationService.onDidReceiveBackgroundNotificationResponseCallback,
  );

  // Initialiser NotificationService
  notificationService = NotificationService(flutterLocalNotificationsPlugin);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lead',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: const ColorScheme.light(),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[700],
          selectedIconTheme: const IconThemeData(color: Colors.black),
          unselectedIconTheme: const IconThemeData(color: Colors.grey),
        ),
      ),
      home: const Wrapper(),
    );
  }
}