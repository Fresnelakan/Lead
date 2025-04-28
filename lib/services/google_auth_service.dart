import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // ID client Android uniquement (le web utilise le meta-tag HTML)
  static const String _androidClientId = '796388366674-o0rp4jmlq61lja3bl7r8j95hi1qod4c0.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final bool _isWeb;

  // Constructeur privé
  GoogleAuthService._internal({
    required FirebaseAuth auth,
    required GoogleSignIn googleSignIn,
    required bool isWeb,
  })  : _auth = auth,
        _googleSignIn = googleSignIn,
        _isWeb = isWeb;

  // Factory constructor
  factory GoogleAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    bool? isWeb,
  }) {
    final isWebPlatform = !(identical(0, 0.0)); // Détection fiable
    final resolvedIsWeb = isWeb ?? isWebPlatform;

    return GoogleAuthService._internal(
      auth: auth ?? FirebaseAuth.instance,
      googleSignIn: googleSignIn ?? GoogleSignIn(
        clientId: resolvedIsWeb ? null : _androidClientId, // null pour web
        scopes: ['email', 'profile'],
      ),
      isWeb: resolvedIsWeb,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Plateforme: ${_isWeb ? "WEB" : "MOBILE"}');

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'ID Token manquant',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signOut(); // Nettoyage de session
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