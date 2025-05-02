import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Utilisez les émulateurs en mode debug
if (kDebugMode) {
  try {

    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080); // Le port par défaut de l'émulateur Firestore est 8080
    // Si vous utilisez l'émulateur Authentication, décommentez la ligne suivante
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099); // Le port par défaut est 9099
    // Bien que votre fonction soit déclenchée par Firestore, si vous avez besoin d'appeler des fonctions HTTP/Callable depuis Flutter,
    // vous devriez configurer l'émulateur Functions ici :
    // FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001); // Le port par défaut est 5001
  } catch (e) {
    // Gérer les erreurs si les émulateurs ne sont pas en cours d'exécution (facultatif)
    print('Erreur lors de la connexion aux émulateurs : $e');
  }
}

  runApp(const MyApp());
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
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Ou Colors.white
        colorScheme: ColorScheme.light(
          // Couleur de fond globale
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[700],
          selectedIconTheme: IconThemeData(color: Colors.black),
          unselectedIconTheme: IconThemeData(color: Colors.grey[700]),
        ),
      ),

      home: const Wrapper(),
    );
  }
}
