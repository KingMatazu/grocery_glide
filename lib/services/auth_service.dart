import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:grocery_glide/model/app_user.dart';
import 'package:grocery_glide/services/auth_errors.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Convert Firebase User to AppUser
  AppUser? _userFromFirebase(User? user) {
    return user != null ? AppUser.fromFirebaseUser(user) : null;
  }

  // Stream of AppUser
  Stream<AppUser?> get user {
    return authStateChanges.map(_userFromFirebase);
  }

  /// Firebase Auth matches email addresses case-sensitively, so a user typing
  /// "GroceryGlide.Review@Gmail.com" would not find the account created as
  /// "groceryglide.review@gmail.com" and would be told it does not exist.
  /// Normalising here keeps every caller consistent and stops one person
  /// creating a second account that differs only by case.
  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  // Sign Up with Email and Password
  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: _normalizeEmail(email),
      password: password,
    );

    final user = result.user;

    if (user != null && displayName != null && displayName.isNotEmpty) {
      try {
        await user.updateDisplayName(displayName);
        // The id token goes stale after a profile update on Apple platforms, so
        // force a refresh instead of reloading the user.
        await user.getIdToken(true);
      } catch (e, s) {
        // The account already exists at this point. Reporting a failure here
        // would tell the user sign-up failed when it succeeded, and their
        // retry would then be rejected as an address already in use.
        debugPrint('Display name not set after sign-up: $e\n$s');
      }
    }

    return _userFromFirebase(user);
  }

  // Sign In with Email and Password
  Future<AppUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final UserCredential result = await _auth.signInWithEmailAndPassword(
      email: _normalizeEmail(email),
      password: password,
    );

    return _userFromFirebase(result.user);
  }

  // Sign In with Google
  Future<AppUser?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      final result = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return _userFromFirebase(result.user);
    } on GoogleSignInException catch (e) {
      // Dismissing the account chooser is not an error worth reporting.
      if (AuthErrors.isCancellation(e)) return null;
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Failed to sign out: $e';
    }
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: _normalizeEmail(email));
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to send reset email: $e';
    }
  }

  // Update Display Name
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.reload();
      }
    } catch (e) {
      throw 'Failed to update display name: $e';
    }
  }

  // Update Email
  Future<void> updateEmail(String newEmail) async {
    final user = currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(_normalizeEmail(newEmail));
    }
  }

  // Update Password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to update password: $e';
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to delete account: $e';
    }
  }

  // Reauthenticate (needed for sensitive operations)
  Future<void> reauthenticate(String password) async {
    try {
      final user = currentUser;
      if (user != null && user.email != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to reauthenticate: $e';
    }
  }

  // Handle Firebase Auth Exceptions
  String _handleAuthException(FirebaseAuthException e) =>
      AuthErrors.message(e, flow: AuthFlow.email);
}