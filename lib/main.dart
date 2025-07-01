import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Si tu utilises les fonctions
// import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_options.dart';
import 'wrapper.dart';


const String firebaseEmulatorHost = '10.0.2.2'; // Ton IP local

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Utilisez les émulateurs en mode debug
if (kDebugMode) {
  try {
    // MODIFIE CES LIGNES POUR UTILISER firebaseEmulatorHost
    FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080); // Le port par défaut de l'émulateur Firestore est 8080
    FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099); // Le port par défaut est 9099
    // Si vous utilisez l'émulateur Functions, décommentez et utilisez également firebaseEmulatorHost
    // FirebaseFunctions.instance.useFunctionsEmulator(firebaseEmulatorHost, 5001); // Le port par défaut est 5001
  } catch (e) {
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
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: const ColorScheme.light(
          // Couleur de fond globale
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[700],
          selectedIconTheme: const IconThemeData(color: Colors.black),
          unselectedIconTheme: IconThemeData(color: Colors.grey[700]),
        ),
      ),

      home: const Wrapper(),
    );
  }
}