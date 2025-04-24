import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  // Constructeur avec initialisation optionnelle pour les tests
  GoogleAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          scopes: ['email', 'profile'],
          // Optionnel : Forcer le compte sélectionné (pour les apps d'entreprise)
          // hostedDomain: 'votredomaine.com',
        );

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Démarrer le processus de connexion
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // 2. Obtenir les tokens d'authentification
      final googleAuth = await googleUser.authentication;

      // 3. Vérifier la présence des tokens critiques
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-tokens',
          message: 'Les tokens Google sont manquants',
        );
      }

      // 4. Créer les credentials Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Connexion à Firebase avec vérification de contexte
      if (_auth.currentUser != null) {
        await _auth.signOut(); // Éviter les conflits de session
      }

      return await _auth.signInWithCredential(credential);

    } on FirebaseAuthException catch (e) {
      print('Erreur Firebase: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Erreur inattendue: $e');
      throw FirebaseAuthException(
        code: 'operation-failed',
        message: 'Échec de la connexion Google',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      rethrow;
    }
  }
}