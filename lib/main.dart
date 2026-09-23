import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/database/grocery_database.dart';
import 'package:grocery_glide/services/grocery_service.dart';
import 'package:grocery_glide/services/notification_service.dart';
import 'package:grocery_glide/themes/app_theme.dart';
import 'package:grocery_glide/themes/theme_provider.dart';
import 'package:grocery_glide/views/grocery_list_screen.dart';
import 'package:grocery_glide/views/login_screen.dart';
import 'package:grocery_glide/views/onboarding_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery Glide',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<Map<String, bool>> _checkAppState() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();

    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    final firstTimeSetupComplete =
        prefs.getBool('first_time_setup_complete') ?? false;

    return {
      'onboarding_complete': onboardingComplete,
      'first_time_setup_complete': firstTimeSetupComplete,
    };
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: _checkAppState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          );
        }
        final appState = snapshot.data ?? {};
        final onboardingComplete = appState['onboarding_complete'] ?? false;
        final firstTimeSetupComplete = appState['first_time_setup_complete'] ?? false;

        // Ensure monthly items exist for returning users
        if (onboardingComplete && firstTimeSetupComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
            if (kDebugMode) {
              print('App startup: ensuring items for $currentMonth');
            } // debug log
            await GroceryService.ensureMonthlyItemsExist(currentMonth);
          });
        }
        
        // 1. First time ever -> Onboarding
        // 2. After onboarding (or logged-in returning users without setup) -> Login, then setup
        // 3. After setup -> Main app
        if (!onboardingComplete) {
          return const OnboardingScreen();
        } else if (!firstTimeSetupComplete){
          return const LoginScreen(canSkip: false);
        } else {
          return const GroceryListScreen();
        }
      },
    );
  }
}
