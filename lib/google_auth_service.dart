// lib/services/google_auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'], // Scopes optionnels
  );

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Lancer le flux de connexion Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // 2. Obtenir les authentifications
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // 3. Créer les credentials Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Connexion Firebase
      return await _auth.signInWithCredential(credential);
      
    } catch (e) {
      print("Erreur lors de la connexion Google: $e");
      rethrow; // Permet de gérer l'erreur dans les pages
    }
  }

  Future<void> signOutFromGoogle() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}