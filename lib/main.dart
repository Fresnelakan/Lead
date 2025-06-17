import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'wrapper.dart';
// import 'services/notification_service.dart'; // Si vous avez un service dédié, assurez-vous qu'il est à jour.
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


// Global key pour accéder au Navigator pour les modales en dehors du contexte d'un widget
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

// Fonction de gestion des messages FCM en arrière-plan (hors de l'app ou en veille)
@pragma('vm:entry-point') // Nécessaire pour les fonctions en arrière-plan sur certaines plateformes
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background FCM message: ${message.messageId}");

  if (!kIsWeb) { // Notifications locales uniquement pour mobile
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsDarwin);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    flutterLocalNotificationsPlugin.show(
      message.messageId.hashCode,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? 'Vous avez un nouveau message.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'activity_channel',
          'Activity Notifications',
          channelDescription: 'Notifications pour les activités à venir',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker', // Pour les anciens Android
        ),
      ),
      payload: message.data['page'], // Payload pour la navigation
    );
  }
  // Mettre à jour Firestore pour marquer la notification comme livrée par le backend
  // Si cette logique est dans la Cloud Function après l'envoi FCM, elle n'a pas besoin d'être ici.
  // Cependant, pour être sûr que l'état 'delivered' est mis à jour même si le message
  // est reçu par le client, vous pouvez ajouter une logique ici pour le background.
  // Cela nécessiterait des permissions pour écrire dans Firestore depuis le client en background.
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  tz.initializeTimeZones(); // Initialiser les fuseaux horaires

  // Initialisation de flutter_local_notifications
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
  const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsDarwin);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
      // Gérer la réponse quand l'utilisateur clique sur la notification locale (foreground)
      print('Local Notification cliquée (Foreground): ${notificationResponse.payload}');
      if (notificationResponse.payload != null && navigatorKey.currentState != null) {
        // Exemple de navigation, adaptez à votre structure de routes
        // navigatorKey.currentState!.pushNamed(notificationResponse.payload!);
      }
    },
    onDidReceiveBackgroundNotificationResponse: (NotificationResponse notificationResponse) {
      // Gérer la réponse quand l'utilisateur clique sur la notification locale (background/terminated)
      print('Local Notification cliquée (Background): ${notificationResponse.payload}');
    },
  );


  // Initialisation et configuration des émulateurs Firebase
  if (kDebugMode) {
    try {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      // FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001); // Décommentez si vous utilisez des fonctions HTTP/Callable
      print('Connexion aux émulateurs Firebase tentée.');
    } catch (e) {
      print('Erreur lors de la connexion aux émulateurs : $e');
    }
  }

  // Initialisation de Firebase Cloud Messaging (FCM)
  await _initFirebaseMessaging();

  runApp(const MyApp());
}

// Fonction pour initialiser et configurer Firebase Messaging
Future<void> _initFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Demander la permission pour les notifications
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  print('Permission de notification accordée par l\'utilisateur: ${settings.authorizationStatus}');

  // Écouter les changements de token FCM (ex: rafraîchissement du token)
  messaging.onTokenRefresh.listen((token) async {
    print('Jeton FCM rafraîchi: $token');
    await _saveFcmToken(token); // Sauvegarder le nouveau jeton
  });

  // Écouter les changements d'état d'authentification pour sauvegarder le token
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      String? currentToken = await messaging.getToken();
      if (currentToken != null) {
        print('Utilisateur connecté: ${user.uid}. Tentative de sauvegarde du jeton FCM.');
        await _saveFcmToken(currentToken);
      } else {
        print('Utilisateur connecté: ${user.uid} mais jeton FCM est nul. Impossible de sauvegarder le jeton.');
      }
    } else {
      print('Utilisateur déconnecté. Le jeton FCM ne sera pas sauvegardé.');
    }
  });

  // Tenter de récupérer et sauvegarder le token une fois au démarrage si un utilisateur est déjà connecté
  final initialUser = FirebaseAuth.instance.currentUser;
  if (initialUser != null) {
    String? initialToken = await messaging.getToken();
    if (initialToken != null) {
      print('Utilisateur déjà connecté au démarrage: ${initialUser.uid}. Tentative de sauvegarde du jeton FCM initial.');
      await _saveFcmToken(initialToken);
    } else {
      print('Jeton FCM initial est nul pour l\'utilisateur déjà connecté.');
    }
  }

  // Gérer les messages quand l'app est au premier plan (Foreground)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Message FCM reçu en premier plan !');
    print('Données du message FCM: ${message.data}');

    // Débogage: Vérifier si le champ notification est présent
    if (message.notification == null) {
      print('ATTENTION: Le message FCM ne contient PAS de champ "notification". Affichage basé sur les données.');
    } else {
      print('Champ "notification" présent: Titre="${message.notification!.title}", Corps="${message.notification!.body}"');
    }

    if (message.notification != null) {
      final String? title = message.notification!.title;
      final String? body = message.notification!.body;

      if (!kIsWeb) {
        // Pour les plateformes mobiles, afficher une notification locale
        flutterLocalNotificationsPlugin.show(
          message.messageId.hashCode,
          title ?? 'Notification',
          body ?? 'Nouveau message.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'activity_channel',
              'Activity Notifications',
              channelDescription: 'Notifications pour les activités à venir',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: message.data['page'],
        );
        print('Notification locale affichée sur mobile.');
      } else {
        // Pour le web, afficher une modale directement
        if (navigatorKey.currentState != null && navigatorKey.currentState!.overlay != null && navigatorKey.currentState!.overlay!.context.mounted) {
          showDialog(
            context: navigatorKey.currentState!.overlay!.context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title ?? 'Notification',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: Text(body ?? 'Détails de la notification.'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
          print('Modale de notification affichée sur le Web (premier plan).');
        } else {
          print('Impossible d\'afficher la modale: navigatorKey ou son contexte n\'est pas prêt/monté.');
        }
      }
    } else {
      // Si le message FCM n'a pas de champ 'notification', mais seulement des 'data'
      // Vous pouvez choisir d'afficher une modale générique ou de ne rien faire.
      if (message.data.isNotEmpty && kIsWeb) {
        print('Message FCM sans champ "notification" mais avec "data".');
        if (navigatorKey.currentState != null && navigatorKey.currentState!.overlay != null && navigatorKey.currentState!.overlay!.context.mounted) {
            showDialog(
                context: navigatorKey.currentState!.overlay!.context,
                builder: (BuildContext context) {
                    return AlertDialog(
                        title: const Text("Nouvel Événement"),
                        content: Text("Un événement a eu lieu: ${message.data['activity'] ?? 'Détails non spécifiés'}"),
                        actions: <Widget>[
                            TextButton(
                                child: const Text('OK'),
                                onPressed: () {
                                    Navigator.of(context).pop();
                                },
                            ),
                        ],
                    );
                },
            );
        }
      }
    }
  });

  // Gérer les interactions avec les notifications FCM (quand l'app est en arrière-plan ou fermée)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Un nouvel événement onMessageOpenedApp a été publié ! (FCM)');
    print('Données du message FCM: ${message.data}');
    // Logique de navigation ici si nécessaire
  });

  // Assurez-vous que le gestionnaire d'arrière-plan est enregistré
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}

// Fonction pour sauvegarder le jeton FCM dans Firestore
Future<void> _saveFcmToken(String token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token, 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      print('Jeton FCM sauvegardé/mis à jour pour l\'utilisateur: ${user.uid}');
    } catch (e) {
      print('Erreur lors de la sauvegarde du jeton FCM pour l\'utilisateur ${user.uid}: $e');
    }
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Assignation de la GlobalKey au MaterialApp
      debugShowCheckedModeBanner: false,
      title: 'Mon App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blueAccent,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[700],
          selectedIconTheme: const IconThemeData(color: Colors.black),
          unselectedIconTheme: IconThemeData(color: Colors.grey[700]),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(8),
        ),
        fontFamily: 'Inter',
      ),
      home: const Wrapper(),
    );
  }
}
