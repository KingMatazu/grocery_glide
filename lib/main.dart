import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/database/grocery_database.dart';
import 'package:grocery_glide/services/grocery_service.dart';
import 'package:grocery_glide/views/first_time_setup_screen.dart';
import 'package:grocery_glide/views/grocery_list_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await GroceryDatabase.initialize();
  runApp(const ProviderScope(child:  MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grocery Glide',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:  ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.dark,
          surface: const Color(0xFF2D2D2D),
        ),
      ),
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
          return const Scaffold(
            backgroundColor: Color(0xFF2D2D2D),
            body: Center(
              child: CircularProgressIndicator(color: Colors.green,),
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