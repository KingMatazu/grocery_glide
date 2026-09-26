import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/database/grocery_database.dart';
import 'package:grocery_glide/providers/auth_provider.dart';
import 'package:grocery_glide/providers/startup_provider.dart';
import 'package:grocery_glide/services/grocery_service.dart';
import 'package:grocery_glide/services/notification_service.dart';
import 'package:grocery_glide/themes/app_theme.dart';
import 'package:grocery_glide/themes/theme_provider.dart';
import 'package:grocery_glide/views/first_time_setup_screen.dart';
import 'package:grocery_glide/views/grocery_list_screen.dart';
import 'package:grocery_glide/views/login_screen.dart';
import 'package:grocery_glide/views/onboarding_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Surface *every* error instead of white-screening. Sideloaded builds have
  // no crash reporter, so route exceptions to an on-screen error widget and a
  // debug print.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}');
    debugPrint('${details.stack}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PLATFORM/MISSING-PLUGIN ERROR: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) => _StartupErrorView(
        message: details.exceptionAsString(),
      );

  // Initialize Firebase (best-effort; sideloads should not die on a missing
  // GoogleService-Info or reversed client mismatch).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, s) {
    debugPrint('Firebase init skipped: $e\n$s');
  }

  // Initialize notifications (best-effort).
  try {
    await NotificationService.instance.initialize();
  } catch (e, s) {
    debugPrint('Notifications init skipped: $e\n$s');
  }

  // Check for Shorebird over-the-air updates (best-effort; not installed on
  // plain `flutter build ipa` sideloads → checkForUpdate is a no-op).
  try {
    final updater = ShorebirdUpdater();
    if (updater.isAvailable) {
      final status = await updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        try {
          await updater.update();
        } on UpdateException catch (error) {
          debugPrint('Shorebird update failed: ${error.message}');
        }
      }
    }
  } catch (e, s) {
    debugPrint('Shorebird check skipped: $e\n$s');
  }

  try {
    await GroceryDatabase.initialize();
  } catch (e, s) {
    debugPrint('Isar init failed: $e\n$s');
    rethrow;
  }

  runApp(const ProviderScope(child: MainApp()));
  unawaited(NotificationService.instance.ensureDefaultReminders());
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF101418),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Grocery Glide hit an error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  message,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Used by the app gate to drop pushed routes when the signed-in account
/// changes. See [_AppGateState.build].
final rootNavigatorKey = GlobalKey<NavigatorState>();

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Grocery Glide',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: const AppGate(),
    );
  }
}

/// Decides which screen the app root shows, and keeps the navigation stack in
/// step with the signed-in account.
///
/// The check lives here rather than inside each screen because a per-screen
/// guard is only as strong as the next screen somebody adds, and a signed-out
/// user previously had every screen but onboarding within one tap of the
/// grocery data.
///
/// Gating the root also has to collapse pushed routes, not just swap this
/// widget's child: profile and the master template are pushed *above* the
/// root, so changing `home` on its own would leave them on screen and
/// reachable with the back gesture.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> {
  String? _ensuredMonth;

  /// Populate the current month once per launch.
  ///
  /// Guarded by month so a rollover re-runs it. Deliberately does not call
  /// setState: scheduling the post-frame callback must not be able to loop the
  /// build, which is what the previous unconditional callback did.
  void _ensureCurrentMonth() {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    if (_ensuredMonth == month) return;
    _ensuredMonth = month;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (kDebugMode) {
        debugPrint('App startup: ensuring items for $month');
      }
      await GroceryService.ensureMonthlyItemsExist(month);
    });
  }

  Widget _signedInScreen(StartupState startup) {
    if (!startup.firstTimeSetupComplete) {
      return const FirstTimeSetupScreen();
    }
    _ensureCurrentMonth();
    return const GroceryListScreen();
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(authStatusProvider);
    final startup = ref.watch(startupStateProvider);

    // Signing in or out changes which screen the root should be showing, and
    // every route pushed above the root belongs to the session that just
    // ended.
    ref.listen<AuthStatus>(authStatusProvider, (previous, next) {
      if (previous == null || previous == next) return;
      if (ref.read(signOutCelebrationProvider)) return;
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    });

    return startup.when(
      loading: () => const _SplashView(),
      error: (error, _) {
        debugPrint('Startup prefs unavailable: $error');
        return _GateMessageView(
          icon: Icons.error_outline,
          iconColor: Theme.of(context).colorScheme.error,
          title: "Couldn't read your settings",
          message:
              'Grocery Glide could not load its saved preferences, so it '
              'cannot tell which step of setup to show.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(startupStateProvider),
        );
      },
      data: (state) {
        // Onboarding precedes any account, so it is the one screen a
        // signed-out user is allowed to reach.
        if (!state.onboardingComplete) {
          return const OnboardingScreen();
        }

        return switch (authStatus) {
          // Still deciding. Rendering the sign-in screen here would flash it
          // on every cold start for users who are already signed in.
          AuthStatus.loading => const _SplashView(),
          AuthStatus.error => _GateMessageView(
              icon: Icons.wifi_off_rounded,
              iconColor: Theme.of(context).colorScheme.error,
              title: "Couldn't check your sign-in",
              message:
                  'Grocery Glide could not reach the sign-in service. Check '
                  'your connection and try again.',
              actionLabel: 'Try again',
              onAction: () {
                debugPrint('Retrying auth after a stream error');
                ref.invalidate(authStateProvider);
              },
            ),
          AuthStatus.signedOut => const LoginScreen(),
          AuthStatus.signedIn => _signedInScreen(state),
        };
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Blocking state for when the gate cannot make a decision. Always offers a
/// way forward, because the alternative is stranding the user on a screen
/// that cannot help them.
class _GateMessageView extends StatelessWidget {
  const _GateMessageView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: iconColor),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
