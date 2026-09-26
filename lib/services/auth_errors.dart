import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Which sign-in flow produced an error.
///
/// Firebase reports some codes differently depending on the flow, and the
/// message that helps the user most depends on which flow they used.
///
/// Named [AuthFlow] rather than `AuthProvider` to avoid colliding with the
/// `AuthProvider` class exported by `package:firebase_auth`.
enum AuthFlow { email, google }

/// Turns any failure from the auth layer into a short message that is safe to
/// show in the UI.
///
/// The raw error is always logged with [debugPrint] so it stays available when
/// debugging a sideloaded build, but it is never returned: plugin and Firebase
/// messages are developer-facing and can name plist keys, exception classes and
/// platform channels, which is meaningless to a user.
class AuthErrors {
  const AuthErrors._();

  static const String _generic = 'Something went wrong. Please try again.';
  static const String _offline =
      'No internet connection. Check your network and try again.';
  static const String _googleUnavailable =
      "Google sign-in isn't available right now. Please use email and password.";

  /// Returns a user-facing message for [error].
  ///
  /// Pass the [flow] the error came from, because the same Firebase code means
  /// different things for a password attempt and a Google attempt.
  static String message(
    Object error, {
    AuthFlow flow = AuthFlow.email,
  }) {
    debugPrint('AUTH ERROR [$flow] ${_describe(error)}');

    if (_isOffline(error)) return _offline;
    if (error is GoogleSignInException) return _googleSignIn(error);
    if (error is MissingPluginException) return _googleUnavailable;
    if (error is PlatformException) return _platform(error, flow);
    if (error is FirebaseAuthException) return _firebase(error, flow);
    return _generic;
  }

  /// Whether [error] is the user deliberately dismissing the flow, in which
  /// case the caller should stay silent rather than report a failure.
  static bool isCancellation(Object error) =>
      error is GoogleSignInException &&
      error.code == GoogleSignInExceptionCode.canceled;

  static String _googleSignIn(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted =>
        'Sign-in was interrupted. Please try again.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        _googleUnavailable,
      GoogleSignInExceptionCode.uiUnavailable =>
        "Couldn't open the Google sign-in screen. Please try again.",
      GoogleSignInExceptionCode.userMismatch =>
        "You're signed in with a different Google account. Sign out and try again.",
      _ => 'Google sign-in failed. Please try again.',
    };
  }

  static String _platform(PlatformException error, AuthFlow flow) {
    final text = '${error.code} ${error.message ?? ''}'.toLowerCase();

    if (flow == AuthFlow.google) {
      // The iOS SDK reports a missing client id by raising an NSException,
      // which the plugin rethrows as a PlatformException rather than as a typed
      // failure, so it never reaches the GoogleSignInException branch above.
      if (text.contains('no active configuration') ||
          text.contains('gidclientid')) {
        return _googleUnavailable;
      }
      return "Google sign-in didn't complete. Please try again.";
    }

    return 'Sign-in failed. Please try again.';
  }

  static String _firebase(
    FirebaseAuthException error,
    AuthFlow flow,
  ) {
    switch (error.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with that email. Try signing in instead.';
      case 'invalid-email':
        return "That email address doesn't look right.";
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'invalid-credential':
        // Google reports this when the address already has a password account.
        return flow == AuthFlow.google
            ? 'That email is registered with email and password. Try signing in that way.'
            : 'Incorrect email or password.';
      case 'account-exists-with-different-credential':
        return 'That email is already registered with a different sign-in method.';
      case 'network-request-failed':
        return _offline;
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return "This sign-in method isn't enabled.";
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      case 'invalid-verification-code':
        return "That verification code isn't valid.";
      default:
        // Never surface Firebase's own message: it is written for developers
        // and can contain raw error codes and request details.
        return _generic;
    }
  }

  static bool _isOffline(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseAuthException) {
      return error.code == 'network-request-failed';
    }
    // Matched by name so this stays free of dart:io and still compiles for web.
    const networkTypes = {
      'SocketException',
      'HttpException',
      'HandshakeException',
      'TlsException',
    };
    if (networkTypes.contains(error.runtimeType.toString())) return true;
    if (error is PlatformException) {
      final text = '${error.code} ${error.message ?? ''}'.toLowerCase();
      return text.contains('network') || text.contains('unreachable');
    }
    return false;
  }

  static String _describe(Object error) {
    if (error is PlatformException) {
      return 'PlatformException(code: ${error.code}, '
          'message: ${error.message}, details: ${error.details})';
    }
    if (error is FirebaseAuthException) {
      return 'FirebaseAuthException(code: ${error.code}, '
          'message: ${error.message})';
    }
    if (error is GoogleSignInException) {
      return 'GoogleSignInException(code: ${error.code}, '
          'description: ${error.description}, details: ${error.details})';
    }
    return '$error';
  }
}
