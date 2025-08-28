import 'package:flutter/material.dart';
import 'package:grocery_glide/database/grocery_database.dart';
import 'package:grocery_glide/views/grocery_list_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await GroceryDatabase.initialize();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GroceryListScreen(),
    );
  }
}
