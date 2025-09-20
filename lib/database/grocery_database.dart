import 'package:grocery_glide/model/grocery_item.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class GroceryDatabase {
  static late Isar _isar;
  
  // Initialize the database
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    // print('Isar is storing data at: ${dir.path}\\isar');
    _isar = await Isar.open(
      [GroceryItemSchema],
      directory: dir.path,
    );
  }
  
  // Get the Isar instance
  static Isar get instance => _isar;
  
  // Close the database
  static Future<void> close() async {
    await _isar.close();
  }
}