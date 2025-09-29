import 'package:intl/intl.dart';
import 'package:isar/isar.dart';

part 'grocery_item.g.dart'; // This will be generated

@Collection()
class GroceryItem {
  Id id = Isar.autoIncrement; // Auto-increment ID
  
  @Index()
  late String itemName;
  
  late int quantity;
  
  late double price;
  
  
  bool isBought = false;
  bool isMasterTemplate = false;

  @Index()
  String? monthKey;
  
  @Index()
  late DateTime createdAt;
  
  late DateTime updatedAt;
  
  // Optional notes
  String? notes;
  
  // Constructor
  GroceryItem({
    required this.itemName,
    required this.quantity,
    required this.price,
    this.isBought = false,
    this.notes,
    this.monthKey,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
    monthKey ??= DateFormat('yyyy-MM').format(DateTime.now());
  }
  
  // Named constructor for template creation
  GroceryItem.template({
    required this.itemName,
    required this.quantity,
    required this.price,
    this.notes,
    this.monthKey,
  }) : isBought = false {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
    monthKey ??= DateFormat('yyyy-MM').format(DateTime.now());
  }
  
  // Copy constructor for creating new instances from template
  GroceryItem.fromTemplate(GroceryItem template) :
    itemName = template.itemName,
    quantity = template.quantity,
    price = template.price,
    isBought = false,
    notes = template.notes,
    monthKey = template.monthKey {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
    monthKey ??= DateFormat('yyyy-MM').format(DateTime.now());
  }
  
  // Calculate total price for this item
  double get totalPrice => quantity * price;
  
  // Update the updatedAt timestamp
  void touch() {
    updatedAt = DateTime.now();
  }
  
  @override
  String toString() {
    return 'GroceryItem{id: $id, itemName: $itemName, quantity: $quantity, price: $price, isBought: $isBought}';
  }
}
