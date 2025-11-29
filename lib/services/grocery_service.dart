import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:grocery_glide/database/grocery_database.dart';
import 'package:isar/isar.dart';

import '../model/grocery_item.dart';

class GroceryService {
  static final Isar _isar = GroceryDatabase.instance;

  // Debug method to check whats in the database
  static Future<void> debugDatabaseContents() async {
    final allItems = await _isar.groceryItems.where().findAll();
    if (kDebugMode) {
      print('==== DATABASE CONTENTS ======');

      for (final item in allItems) {
        print('Item: ${item.itemName}');
        print('   - month: ${item.monthKey}');
        print('   - is master template: ${item.isMasterTemplate}');
        print('   - id: ${item.id}');
        print('   - is bought: ${item.isBought}');
        print('----');
      }
      print('Total items: ${allItems.length}');
      print('=================================');
    }
  }

  // Add a new grocery item
  static Future<int> addItem(GroceryItem item) async {
    return await _isar.writeTxn(() async {
      return await _isar.groceryItems.put(item);
    });
  }

  // Get all grocery items
  static Future<List<GroceryItem>> getAllItems() async {
    return await _isar.groceryItems.where().findAll();
  }

  // Get bought items
  static Future<List<GroceryItem>> getBoughtItems() async {
    return await _isar.groceryItems.filter().isBoughtEqualTo(true).findAll();
  }

  // Get unbought items
  static Future<List<GroceryItem>> getUnboughtItems() async {
    return await _isar.groceryItems.filter().isBoughtEqualTo(false).findAll();
  }

  // Update an item
  static Future<int> updateItem(GroceryItem item) async {
    item.touch();
    return await _isar.writeTxn(() async {
      return await _isar.groceryItems.put(item);
    });
  }

  // Toggle bought status
  static Future<void> toggleBoughtStatus(int id) async {
    await _isar.writeTxn(() async {
      final item = await _isar.groceryItems.get(id);
      if (item != null) {
        item.isBought = !item.isBought;
        item.touch();
        await _isar.groceryItems.put(item);
      }
    });
  }

  // Delete an item
  static Future<bool> deleteItem(int id) async {
    return await _isar.writeTxn(() async {
      return await _isar.groceryItems.delete(id);
    });
  }

  // Delete all items
  static Future<int> deleteAllItems() async {
    return await _isar.writeTxn(() async {
      return await _isar.groceryItems.where().deleteAll();
    });
  }

  // Reset all items to unbought (for monthly template reset)
  static Future<void> resetAllItemsToUnbought() async {
    await _isar.writeTxn(() async {
      final items = await _isar.groceryItems.where().findAll();
      for (final item in items) {
        item.isBought = false;
        item.touch();
      }
      await _isar.groceryItems.putAll(items);
    });
  }

  // Get total cost of all items
  static Future<double> getTotalCost() async {
    final items = await getAllItems();
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Get total cost of bought items
  static Future<double> getBoughtItemsCost() async {
    final items = await getBoughtItems();
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Get remaining cost (unbought items)
  static Future<double> getRemainingCost() async {
    final items = await getUnboughtItems();
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Search items by name
  static Future<List<GroceryItem>> searchItems(String query) async {
    return await _isar.groceryItems
        .filter()
        .itemNameContains(query, caseSensitive: false)
        .findAll();
  }

  // Get shopping progress (percentage of bought items)
  static Future<double> getShoppingProgress() async {
    final allItems = await getAllItems();
    if (allItems.isEmpty) return 0.0;

    final boughtCount = allItems.where((item) => item.isBought).length;
    return (boughtCount / allItems.length) * 100;
  }

  // Create monthly template from current list
  static Future<List<GroceryItem>> createMonthlyTemplate() async {
    final items = await getAllItems();
    final templateItems = <GroceryItem>[];

    await _isar.writeTxn(() async {
      // Clear existing items
      await _isar.groceryItems.where().deleteAll();

      // Create new template items (reset to unbought)
      for (final item in items) {
        final templateItem = GroceryItem.fromTemplate(item);
        templateItems.add(templateItem);
      }

      // Save template items
      await _isar.groceryItems.putAll(templateItems);
    });

    return templateItems;
  }

  // Stream for real-time updates
  static Stream<List<GroceryItem>> watchAllItems() {
    return _isar.groceryItems.where().watch(fireImmediately: true);
  }

  static Stream<List<GroceryItem>> watchUnboughtItems() {
    return _isar.groceryItems
        .filter()
        .isBoughtEqualTo(false)
        .watch(fireImmediately: true);
  }

  // Master template methods
  static Future<void> createMasterTemplate(List<GroceryItem> items) async {
    await _isar.writeTxn(() async {
      // Clear existing master template
      await _isar.groceryItems
          .filter()
          .isMasterTemplateEqualTo(true)
          .deleteAll();

      // Create new master template items
      final templateItems = items
          .map(
            (item) => GroceryItem.template(
              itemName: item.itemName,
              quantity: item.quantity,
              price: item.price,
              notes: item.notes,
            )..isMasterTemplate = true,
          )
          .toList();

      await _isar.groceryItems.putAll(templateItems);
    });
  }

  static Stream<List<GroceryItem>> watchMasterTemplate() {
    return _isar.groceryItems
        .filter()
        .isMasterTemplateEqualTo(true)
        .watch(fireImmediately: true);
  }

  static Stream<List<GroceryItem>> watchMonthlyItems(String monthKey) {
    return _isar.groceryItems
        .filter()
        .monthKeyEqualTo(monthKey)
        .and()
        .isMasterTemplateEqualTo(false)
        .watch(fireImmediately: true);
  }

  static Future<List<GroceryItem>> getMonthlyItems(String monthKey) async {
    return await _isar.groceryItems
        .filter()
        .monthKeyEqualTo(monthKey)
        .findAll();
  }

  // Add this method to services/grocery_service.dart

  static Future<List<GroceryItem>> getMasterTemplateItems() async {
    return await _isar.groceryItems
        .filter()
        .isMasterTemplateEqualTo(true)
        .findAll();
  }

  static Future<void> createMonthlyListFromTemplate(String monthKey) async {
    final masterItems = await _isar.groceryItems
        .filter()
        .isMasterTemplateEqualTo(true)
        .findAll();

    await _isar.writeTxn(() async {
      // Clear existing monthly items
      await _isar.groceryItems
          .filter()
          .monthKeyEqualTo(monthKey)
          .and()
          .isMasterTemplateEqualTo(false)
          .deleteAll();

      // Create monthly items from template
      final monthlyItems = masterItems.map((item) {
        final newItem = GroceryItem(
          itemName: item.itemName,
          quantity: item.quantity,
          price: item.price,
          notes: item.notes,
        );
        newItem.monthKey = monthKey;
        newItem.isMasterTemplate = false;
        return newItem;
      }).toList();

      await _isar.groceryItems.putAll(monthlyItems);
    });
  }

  static Future<void> clearMonthlyItems(String monthKey) async {
    await _isar.writeTxn(() async {
      await _isar.groceryItems
          .where()
          .filter()
          .monthKeyEqualTo(monthKey)
          .and()
          .isMasterTemplateEqualTo(false)
          .deleteAll();
    });
  }

  static Future<void> ensureMonthlyItemsExist(String monthKey) async {
    if (kDebugMode) {
      print('Checking monthly items for month : $monthKey');
    }
    final existingItem = await _isar.groceryItems
        .where()
        .filter()
        .monthKeyEqualTo(monthKey)
        .and()
        .isMasterTemplateEqualTo(false)
        .findAll();

    if (kDebugMode) {
      print('Found ${existingItem.length} existing items $monthKey');
    }

    if (existingItem.isEmpty) {
      final masterItems = await _isar.groceryItems
          .where()
          .filter()
          .isMasterTemplateEqualTo(true)
          .findAll();

      if (kDebugMode) {
        print('Found ${masterItems.length} master temolate items');
      }

      if (masterItems.isNotEmpty) {
        if (kDebugMode) {
          print('Creating monthly list from template for $monthKey');
        }
        await createMonthlyListFromTemplate(monthKey);
      } else {
        if (kDebugMode) {
          print('No master template items found');
        }
      }
    } else {
      if (kDebugMode) {
        print('Monthly items already exisit for $monthKey');
        await addMissingTemplateItems(monthKey);
      }
    }
  }

  static Future<void> syncMonthlyItemsWithTemplate(String monthKey) async{
    final masterItems = await _isar.groceryItems
    .filter()
    .isMasterTemplateEqualTo(true)
    .findAll();

    final existingMonthlyItems = await _isar.groceryItems
    .filter()
    .monthKeyEqualTo(monthKey)
    .and()
    .isMasterTemplateEqualTo(false)
    .findAll();

    await _isar.writeTxn(() async{
      // create a map of existing items for quick lookup
      final existingItemsMap = <String, GroceryItem>{};
      for (final item in existingMonthlyItems) {
        existingItemsMap[item.itemName.toLowerCase()] = item;
      }

      // process each master template item
      for (final masterItem in masterItems) {
        final existingItem = existingItemsMap[masterItem.itemName.toLowerCase()];

        if (existingItem != null) {
          // item exists - update quantity/price but preserve bought status
          existingItem.quantity = masterItem.quantity;
          existingItem.price = masterItem.price;
          existingItem.notes = masterItem.notes;
          existingItem.touch();
          await _isar.groceryItems.put(existingItem);
        } else {
          // Item doesnt exisit - create new one
          final newItem = GroceryItem(
            itemName: masterItem.itemName,
            quantity: masterItem.quantity,
            price: masterItem.price,
            notes: masterItem.notes,
          );
          newItem.monthKey = monthKey;
          newItem.isMasterTemplate = false;
          newItem.isBought = false;
          await _isar.groceryItems.put(newItem);
        }
      }
    });
  }

  // add missing template items to a month without affecting existing items
  static Future<int> addMissingTemplateItems(String monthKey) async{
    final masterItems = await _isar.groceryItems
    .filter()
    .isMasterTemplateEqualTo(true)
    .findAll();

    final existingMonthlyItems = await _isar.groceryItems
    .filter()
    .monthKeyEqualTo(monthKey)
    .and()
    .isMasterTemplateEqualTo(false)
    .findAll();

     // Create a set of existing item names (lowercase) for quick lookup
  final existingNames = existingMonthlyItems
      .map((item) => item.itemName.toLowerCase())
      .toSet();

  int addedCount = 0;

  await _isar.writeTxn(() async {
    for (final masterItem in masterItems) {
      // Only add if item doesn't exist
      if (!existingNames.contains(masterItem.itemName.toLowerCase())) {
        final newItem = GroceryItem(
          itemName: masterItem.itemName,
          quantity: masterItem.quantity,
          price: masterItem.price,
          notes: masterItem.notes,
        );
        newItem.monthKey = monthKey;
        newItem.isMasterTemplate = false;
        newItem.isBought = false;
        await _isar.groceryItems.put(newItem);
        addedCount++;
      }
    }
  });

  return addedCount;
  }
}
