import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/database/grocery_database.dart';
import 'package:grocery_glide/model/app_user.dart';
import 'package:grocery_glide/providers/auth_provider.dart';
import 'package:grocery_glide/providers/grocery_providers.dart';
import 'package:grocery_glide/providers/startup_provider.dart';
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

  final failure = await _bootstrap();

  // Unconditional. Anything thrown before here left the user staring at the
  // launch screen forever: no first frame, no crash, no error. One bad
  // notification icon shipped that way to the Play Store, so startup is now
  // reported on screen rather than thrown.
  runApp(ProviderScope(child: _MainApp(startupFailure: failure)));

  if (failure == null) {
    unawaited(NotificationService.instance.ensureDefaultReminders());
  }
}

/// A startup step that did not finish, and why.
class _StartupFailure {
  const _StartupFailure(this.step, this.error);

  final String step;
  final Object error;
}

/// Caps how long any one step may take.
///
/// A plugin that never answers its platform channel would otherwise hang
/// startup indefinitely, which is indistinguishable from a crash to the user.
const _startupStepTimeout = Duration(seconds: 20);

/// Runs one startup step, turning any failure into a value.
///
/// The timeout matters as much as the catch: a plugin that simply stops
/// responding is exactly as invisible as one that throws.
Future<_StartupFailure?> _attempt(
  String step,
  Future<void> Function() action,
) async {
  try {
    await action().timeout(_startupStepTimeout);
    return null;
  } catch (error) {
    debugPrint('$step init failed: $error');
    return _StartupFailure(step, error);
  }
}

/// Prepares everything the app needs, reporting rather than throwing.
///
/// Steps are split by whether the app can still do its job without them.
/// Notifications and the Shorebird check are conveniences, so they only log.
/// Firebase and the database are not: sign-in is mandatory and every screen
/// reads from Isar, so failing either has to be visible instead of leaving
/// the user on a splash screen.
Future<_StartupFailure?> _bootstrap() async {
  await _attempt(
    'Notifications',
    NotificationService.instance.initialize,
  );

  await _attempt('Shorebird', () async {
    final updater = ShorebirdUpdater();
    if (!updater.isAvailable) return;
    final status = await updater.checkForUpdate();
    if (status == UpdateStatus.outdated) {
      try {
        await updater.update();
      } on UpdateException catch (error) {
        debugPrint('Shorebird update failed: ${error.message}');
      }
    }
  });

  final firebase = await _attempt(
    'Firebase',
    () => Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
  if (firebase != null) return firebase;

  return _attempt('The grocery database', GroceryDatabase.initialize);
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.message, this.step});

  final String message;

  /// Which startup step failed, when it is known.
  final String? step;

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
                Text(
                  step == null
                      ? 'Grocery Glide hit an error'
                      : 'Grocery Glide could not start: $step',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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

class _MainApp extends ConsumerWidget {
  const _MainApp({this.startupFailure});

  /// Set when a startup step failed. The app is still built, but it renders the
  /// failure instead of the gate, so the user is told what broke rather than
  /// being left on the launch screen.
  final _StartupFailure? startupFailure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final failure = startupFailure;

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Grocery Glide',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: failure == null
          ? const AppGate()
          : _StartupErrorView(step: failure.step, message: '${failure.error}'),
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

  /// Claims of pre-ownership rows, one per account per launch.
  final Map<String, Future<void>> _ownershipClaims = {};

  /// Hands rows that predate per-account ownership to the account signing in.
  ///
  /// Awaited before the grocery list appears, otherwise the first render would
  /// query for rows the account does not own yet and show an empty list for a
  /// frame before the claim landed.
  Future<void> _claimOwnership(String uid) => _ownershipClaims.putIfAbsent(
        uid,
        () => ref.read(groceryServiceProvider).ensureOwnership(),
      );

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
      await ref.read(groceryServiceProvider).ensureMonthlyItemsExist(month);
    });
  }

  Widget _signedInScreen(StartupState state, AppUser? user) {
    if (user == null) return const _SplashView();

    return FutureBuilder<void>(
      future: _claimOwnership(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashView();
        }
        if (!state.firstTimeSetupComplete) {
          return const FirstTimeSetupScreen();
        }
        _ensureCurrentMonth();
        return const GroceryListScreen();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(authStatusProvider);
    final currentUser = ref.watch(currentUserProvider);
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
          AuthStatus.signedIn => _signedInScreen(state, currentUser),
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
