import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();

  factory OneSignalService() {
    return _instance;
  }

  OneSignalService._internal();

  Future<void> init() async {
    OneSignal.initialize('YOUR_ONESIGNAL_APP_ID');
    OneSignal.Notifications.requestPermission(true);

    // Sauvegarder l'identifiant du joueur
    OneSignal.User.getOnesignalId().then((playerId) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && playerId != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'onesignalPlayerId': playerId},
          SetOptions(merge: true),
        );
        print('OneSignal Player ID sauvegardé: $playerId');
      }
    });

    // Gérer les notifications reçues
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
      print('Notification reçue: ${event.notification.title}');
    });
  }
}