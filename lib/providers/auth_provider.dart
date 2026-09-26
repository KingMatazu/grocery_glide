import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/model/app_user.dart';
import 'package:grocery_glide/services/auth_service.dart';

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Current User Stream Provider
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.user;
});

/// Coarse authentication state.
///
/// The app root needs to keep "still deciding" and "the auth stream broke"
/// apart from "signed out". A single bool cannot express that, and the app
/// gates every screen behind it, so collapsing the two would leave a user
/// staring at the sign-in screen after a transient failure with no way back
/// into their lists.
enum AuthStatus { loading, signedIn, signedOut, error }

final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => (user != null && !user.isAnonymous)
        ? AuthStatus.signedIn
        : AuthStatus.signedOut,
    loading: () => AuthStatus.loading,
    error: (_, _) => AuthStatus.error,
  );
});

// Get current user (or null)
final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// True while the sign-out success screen is on display.
///
/// The app root watches the auth stream and drops the navigation stack
/// whenever the signed-in user changes. Signing out emits a signed-out user
/// immediately, which would replace the success screen the instant it
/// appeared, so the sign-out flow raises this flag before it calls sign out
/// and lowers it once the user continues to the sign-in screen.
class SignOutCelebrationNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void begin() => state = true;

  void end() => state = false;
}

final signOutCelebrationProvider =
    NotifierProvider<SignOutCelebrationNotifier, bool>(
  SignOutCelebrationNotifier.new,
);
