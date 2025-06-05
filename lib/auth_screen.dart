import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showLoginPage = true;

  void _toggleAuthView() {
    setState(() {
      _showLoginPage = !_showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showLoginPage
            ? LoginPage(
                key: const ValueKey('LoginPage'),
                onToggleAuthMode: _toggleAuthView,
              )
            : RegisterPage(
                key: const ValueKey('RegisterPage'),
                onToggle: _toggleAuthView,
              ),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
}