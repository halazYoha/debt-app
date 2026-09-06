import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sends a password-reset email to [email].
  /// Throws a localized [Exception] on failure.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('ይህ ኢሜይል አልተመዘገበም። ኢሜይሉን ያረጋግጡ።');
        case 'invalid-email':
          throw Exception('ትክክለኛ ኢሜይል ያስገቡ።');
        case 'too-many-requests':
          throw Exception('ብዙ ሙከራ አድርገዋል። ትንሽ ቆይተው ደግሜ ሞክሩ።');
        case 'network-request-failed':
          throw Exception('ኢንተርኔት ግንኙነት የለም። ኔትወርክዎን ያረጋግጡ።');
        default:
          throw Exception('ስህተት ተከስቷል። ደግሜ ሞክሩ።');
      }
    } catch (_) {
      throw Exception('ስህተት ተከስቷል። ደግሜ ሞክሩ።');
    }
  }
}
