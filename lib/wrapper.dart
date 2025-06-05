import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding.dart';
import 'auth_screen.dart';
import 'home_page.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  bool _loading = true;
  bool _onboardingSeen = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _initChecks();
  }

  Future<void> _initChecks() async {
    // 1. Vérifie l'état de l'onboarding en parallèle avec l'état d'authentification
    final prefs = await SharedPreferences.getInstance();
    final authState = FirebaseAuth.instance.authStateChanges().first;

    final results = await Future.wait([
      Future.value(prefs.getBool('onboarding_seen') ?? false),
      authState,
    ]);

    setState(() {
      _onboardingSeen = results[0] as bool;
      _user = results[1] as User?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Logique combinée :
    if (!_onboardingSeen) {
      return const OnboardingScreen(); // Priorité à l'onboarding
    } else if (_user != null) {
      return const HomePage(); // Utilisateur déjà connecté
    } else {
      return const AuthScreen(); // Onboarding vu mais non connecté
    }
  }
}