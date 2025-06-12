import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Importez le package
import 'package:timezone/timezone.dart' as tz; // Importez timezone
import 'package:timezone/data/latest.dart' as tz; // Importez les données de fuseau horaire
import 'package:flutter_native_timezone/flutter_native_timezone.dart'; // Importez pour le fuseau horaire natif

import 'firebase_options.dart';
import 'wrapper.dart';

// Créez une instance globale du plugin de notification
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialisation des notifications locales
  await _configureLocalNotifications(); // Appelez la fonction d'initialisation

  // Utilisez les émulateurs en mode debug
  if (kDebugMode) {
    try {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    } catch (e) {
      print('Erreur lors de la connexion aux émulateurs : $e');
    }
  }

  runApp(const MyApp());
}

// Fonction d'initialisation des notifications locales
Future<void> _configureLocalNotifications() async {
  // Initialiser Timezone pour les notifications planifiées
  tz.initializeTimeZones();
  final String? timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName!));

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // Assurez-vous d'avoir cette icône

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
      // Gérer la réponse de la notification (quand l'utilisateur clique dessus)
      // Vous pouvez naviguer vers une page spécifique ou effectuer une action
      print('Notification cliquée ! Payload: ${notificationResponse.payload}');
      // Exemple: Navigator.push(context, MaterialPageRoute(builder: (context) => SomeDetailPage(payload: notificationResponse.payload)));
    },
    onDidReceiveBackgroundNotificationResponse: (NotificationResponse notificationResponse) async {
      // Gérer la réponse de la notification en arrière-plan (Android 12+)
      print('Notification cliquée en arrière-plan ! Payload: ${notificationResponse.payload}');
    }
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mon App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: const ColorScheme.light(
          // Couleur de fond globale
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[700],
          selectedIconTheme: const IconThemeData(color: Colors.black),
          unselectedIconTheme: const IconThemeData(color: Colors.black),
        ),
      ),
      home: const Wrapper(),
    );
  }
}