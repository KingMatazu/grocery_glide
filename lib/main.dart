import 'dart:async';

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

  // Initialize firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications and schedule daily reminders after setup.
  await NotificationService.instance.initialize();

  // Check for Shorebird over-the-air updates before launching.
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

  await GroceryDatabase.initialize();
  runApp(const ProviderScope(child: MainApp()));
  unawaited(NotificationService.instance.ensureDefaultReminders());
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
