import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/database/grocery_database.dart';
import 'package:grocery_glide/services/grocery_service.dart';
import 'package:grocery_glide/themes/app_theme.dart';
import 'package:grocery_glide/themes/theme_provider.dart';
import 'package:grocery_glide/views/first_time_setup_screen.dart';
import 'package:grocery_glide/views/grocery_list_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await GroceryDatabase.initialize();
  runApp(const ProviderScope(child:  MainApp()));
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

  Future<bool> _checkFirstTimeUser() async{
    await Future.delayed(const Duration(milliseconds: 500));
    final pref = await SharedPreferences.getInstance();
    return !(pref.getBool('first_time_setup_complete') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFirstTimeUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary,),
            ),
          );
        }
        final isFirstTime = snapshot.data ?? false;
        // Ensure monthly items exist for returning users
        if (!isFirstTime) {
          WidgetsBinding.instance.addPostFrameCallback((_) async{
            final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
            if (kDebugMode) {
              print('App startup: ensuring items for $currentMonth');
            } // debug log
            await GroceryService.ensureMonthlyItemsExist(currentMonth);
          });
        }
        return isFirstTime
        ? const FirstTimeSetupScreen()
        : const GroceryListScreen();
      },
    );
  }
}