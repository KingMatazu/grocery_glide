import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_glide/services/auth_errors.dart';
import 'package:google_sign_in/google_sign_in.dart';

PlatformException _noActiveConfig() => PlatformException(
      code: 'google_sign_in',
      message:
          'No active configuration. Make sure GIDClientID is set in Info.plist.',
      details: 'NSInvalidArgumentException',
    );

void main() {
  group('platform errors (the real iOS failure mode)', () {
    test('missing GIDClientID on the google flow is user friendly', () {
      final msg = AuthErrors.message(
        _noActiveConfig(),
        flow: AuthFlow.google,
      );
      expect(msg, "Google sign-in isn't available right now. "
          'Please use email and password.');
      expect(msg, isNot(contains('GIDClientID')));
      expect(msg, isNot(contains('Info.plist')));
      expect(msg, isNot(contains('NSInvalidArgument')));
    });

    test('missing plugin is reported as unavailable', () {
      final msg = AuthErrors.message(
        MissingPluginException('no impl'),
        flow: AuthFlow.google,
      );
      expect(msg, contains("isn't available"));
    });

    test('other platform errors never leak the raw message', () {
      final msg = AuthErrors.message(
        PlatformException(code: 'google_sign_in', message: 'raw detail here'),
        flow: AuthFlow.google,
      );
      expect(msg, isNot(contains('raw detail here')));
    });
  });

  group('google sign-in codes', () {
    test('cancellation is recognised', () {
      expect(
        AuthErrors.isCancellation(const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        )),
        isTrue,
      );
      expect(
        AuthErrors.isCancellation(const GoogleSignInException(
          code: GoogleSignInExceptionCode.interrupted,
        )),
        isFalse,
      );
    });

    test('config errors point at email and password', () {
      expect(
        AuthErrors.message(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
          ),
          flow: AuthFlow.google,
        ),
        contains('email and password'),
      );
    });
  });

  group('firebase codes', () {
    FirebaseAuthException err(String code) =>
        FirebaseAuthException(code: code, message: 'RAW FIREBASE TEXT');

    test('email-already-in-use suggests signing in', () {
      expect(
        AuthErrors.message(err('email-already-in-use')),
        'An account already exists with that email. Try signing in instead.',
      );
    });

    test('unknown codes do not leak the firebase message', () {
      final msg = AuthErrors.message(err('some-brand-new-code'));
      expect(msg, 'Something went wrong. Please try again.');
      expect(msg, isNot(contains('RAW FIREBASE TEXT')));
    });

    test('invalid-credential differs by flow', () {
      expect(
        AuthErrors.message(err('invalid-credential'), flow: AuthFlow.google),
        'That email is registered with email and password. '
            'Try signing in that way.',
      );
      expect(
        AuthErrors.message(err('invalid-credential'), flow: AuthFlow.email),
        'Incorrect email or password.',
      );
    });

    test('network failure is reported offline', () {
      expect(
        AuthErrors.message(err('network-request-failed')),
        'No internet connection. Check your network and try again.',
      );
    });
  });

  test('unknown types fall back to something safe', () {
    expect(AuthErrors.message(StateError('boom')), 'Something went wrong. '
        'Please try again.');
    expect(AuthErrors.message('a raw string throw'), 'Something went wrong. '
        'Please try again.');
  });
}
