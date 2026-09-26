import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:grocery_glide/database/grocery_database.dart';
import 'package:isar_community/isar.dart';

import '../model/grocery_item.dart';

/// Reads and writes grocery data for exactly one account.
///
/// The account is captured when the instance is built rather than passed into
/// every call. A uid argument is easy to leave off at one call site, and one
/// omission quietly shows an account another account's rows, so the uid lives
/// here where it cannot be forgotten.
///
/// While the uid is null the account is still being resolved. Reads come back
/// empty and writes throw, so nothing can cross accounts during that window.
class GroceryService {
  GroceryService(this._uid);

  final String? _uid;

  static final Isar _isar = GroceryDatabase.instance;

  /// Accounts whose pre-ownership rows have already been settled this launch.
  static final Set<String> _settledOwnership = <String>{};

  String get _owner {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'Grocery data was read or written with no signed-in account. The app '
        'gate should make this unreachable, so treat it as a bug.',
      );
    }
    return uid;
  }

  /// Hands rows that predate per-account ownership to the first account to sign
  /// in.
  ///
  /// Isar migrates them to an empty owner when the field is added. Left alone
  /// they would belong to nobody and be invisible to everyone, so an upgrade
  /// would look like it had lost the user's lists. Claiming is limited to an
  /// account that owns nothing yet, so once the rows are taken a second account
  /// on the same device starts empty instead of inheriting them.
  Future<void> ensureOwnership() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    if (_settledOwnership.contains(uid)) return;

    final orphans = await _isar.groceryItems
        .filter()
        .ownerUidEqualTo('')
        .findAll();
    final alreadyOwned = await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .findAll();

    if (orphans.isNotEmpty && alreadyOwned.isEmpty) {
      if (kDebugMode) {
        debugPrint('Claiming ${orphans.length} pre-ownership items for $uid');
      }
      await _isar.writeTxn(() async {
        for (final item in orphans) {
          item.ownerUid = uid;
        }
        await _isar.groceryItems.putAll(orphans);
      });
    }

    _settledOwnership.add(uid);
  }

  /// Rejects a row that belongs to another account.
  ///
  /// Needed for the id-based mutations: Isar ids are global auto-increments, so
  /// a stale id carried over from a previous account would otherwise mutate or
  /// delete that account's row.
  bool _owns(GroceryItem? item) => item != null && item.ownerUid == _uid;

  // Add a new grocery item
  Future<int> addItem(GroceryItem item) async {
    item.ownerUid = _owner;
    return await _isar.writeTxn(() async {
      return await _isar.groceryItems.put(item);
    });
  }

  // Get all grocery items
  Future<List<GroceryItem>> getAllItems() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const [];
    return await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .findAll();
  }

  // Get bought items
  Future<List<GroceryItem>> getBoughtItems() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const [];
    return await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .isBoughtEqualTo(true)
        .findAll();
  }

  // Get unbought items
  Future<List<GroceryItem>> getUnboughtItems() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const [];
    return await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .isBoughtEqualTo(false)
        .findAll();
  }

  // Update an item
  Future<int> updateItem(GroceryItem item) async {
    item.ownerUid = _owner;
    item.touch();
    return await _isar.writeTxn(() async {
      return await _isar.groceryItems.put(item);
    });
  }

  // Toggle bought status
  Future<void> toggleBoughtStatus(int id) async {
    await _isar.writeTxn(() async {
      final item = await _isar.groceryItems.get(id);
      if (item == null || !_owns(item)) return;
      item.isBought = !item.isBought;
      item.touch();
      await _isar.groceryItems.put(item);
    });
  }

  // Delete an item
  Future<bool> deleteItem(int id) async {
    return await _isar.writeTxn(() async {
      final item = await _isar.groceryItems.get(id);
      if (item == null || !_owns(item)) return false;
      return await _isar.groceryItems.delete(id);
    });
  }

  // Delete all items for this account
  Future<int> deleteAllItems() async {
    final uid = _owner;
    return await _isar.writeTxn(() async {
      return await _isar.groceryItems
          .filter()
          .ownerUidEqualTo(uid)
          .deleteAll();
    });
  }

  // Reset a month's items to unbought (master template is left untouched)
  Future<void> resetMonthlyItemsToUnbought(String monthKey) async {
    final uid = _owner;
    await _isar.writeTxn(() async {
      final items = await _isar.groceryItems
          .filter()
          .ownerUidEqualTo(uid)
          .and()
          .monthKeyEqualTo(monthKey)
          .and()
          .isMasterTemplateEqualTo(false)
          .findAll();
      for (final item in items) {
        item.isBought = false;
        item.touch();
      }
      await _isar.groceryItems.putAll(items);
    });
  }

  // Get total cost of all items
  Future<double> getTotalCost() async {
    final items = await getAllItems();
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Get total cost of bought items
  Future<double> getBoughtItemsCost() async {
    final items = await getBoughtItems();
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Get remaining cost (unbought items)
  Future<double> getRemainingCost() async {
    final items = await getUnboughtItems();
    return items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Search items by name
  Future<List<GroceryItem>> searchItems(String query) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const [];
    return await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .itemNameContains(query, caseSensitive: false)
        .findAll();
  }

  // Get shopping progress (percentage of bought items)
  Future<double> getShoppingProgress() async {
    final allItems = await getAllItems();
    if (allItems.isEmpty) return 0.0;

    final boughtCount = allItems.where((item) => item.isBought).length;
    return (boughtCount / allItems.length) * 100;
  }

  // Stream for real-time updates
  Stream<List<GroceryItem>> watchAllItems() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .watch(fireImmediately: true);
  }

  Stream<List<GroceryItem>> watchUnboughtItems() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .isBoughtEqualTo(false)
        .watch(fireImmediately: true);
  }

  // Master template methods
  Future<void> createMasterTemplate(List<GroceryItem> items) async {
    final uid = _owner;
    await _isar.writeTxn(() async {
      // Clear this account's existing master template
      await _isar.groceryItems
          .filter()
          .ownerUidEqualTo(uid)
          .and()
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

      for (final item in templateItems) {
        item.ownerUid = uid;
      }
      await _isar.groceryItems.putAll(templateItems);
    });
  }

  Stream<List<GroceryItem>> watchMasterTemplate() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .isMasterTemplateEqualTo(true)
        .watch(fireImmediately: true);
  }

  Stream<List<GroceryItem>> watchMonthlyItems(String monthKey) {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .monthKeyEqualTo(monthKey)
        .and()
        .isMasterTemplateEqualTo(false)
        .watch(fireImmediately: true);
  }

  Future<List<GroceryItem>> getMonthlyItems(String monthKey) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const [];
    return await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .monthKeyEqualTo(monthKey)
        .findAll();
  }

  Future<List<GroceryItem>> getMasterTemplateItems() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return const [];
    return await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .isMasterTemplateEqualTo(true)
        .findAll();
  }

  Future<void> createMonthlyListFromTemplate(String monthKey) async {
    final uid = _owner;
    final masterItems = await getMasterTemplateItems();

    await _isar.writeTxn(() async {
      // Clear this account's existing monthly items
      await _isar.groceryItems
          .filter()
          .ownerUidEqualTo(uid)
          .and()
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
        newItem.ownerUid = uid;
        return newItem;
      }).toList();

      await _isar.groceryItems.putAll(monthlyItems);
    });
  }

  Future<void> clearMonthlyItems(String monthKey) async {
    final uid = _owner;
    await _isar.writeTxn(() async {
      await _isar.groceryItems
          .filter()
          .ownerUidEqualTo(uid)
          .and()
          .monthKeyEqualTo(monthKey)
          .and()
          .isMasterTemplateEqualTo(false)
          .deleteAll();
    });
  }

  Future<void> ensureMonthlyItemsExist(String monthKey) async {
    // Read the owner before touching Isar, so the guard fires first and the
    // failure is the same whether or not the database happens to be open.
    final uid = _owner;
    if (kDebugMode) {
      debugPrint('Checking monthly items for month : $monthKey');
    }
    final existingItem = await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .monthKeyEqualTo(monthKey)
        .and()
        .isMasterTemplateEqualTo(false)
        .findAll();

    if (kDebugMode) {
      debugPrint('Found ${existingItem.length} existing items $monthKey');
    }

    if (existingItem.isEmpty) {
      final masterItems = await getMasterTemplateItems();

      if (kDebugMode) {
        debugPrint('Found ${masterItems.length} master template items');
      }

      if (masterItems.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('Creating monthly list from template for $monthKey');
        }
        await createMonthlyListFromTemplate(monthKey);
      } else {
        if (kDebugMode) {
          debugPrint('No master template items found');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('Monthly items already exist for $monthKey');
      }
      await addMissingTemplateItems(monthKey);
    }
  }

  // add missing template items to a month without affecting existing items
  Future<int> addMissingTemplateItems(String monthKey) async {
    final uid = _owner;
    final masterItems = await getMasterTemplateItems();

    final existingMonthlyItems = await _isar.groceryItems
        .filter()
        .ownerUidEqualTo(uid)
        .and()
        .monthKeyEqualTo(monthKey)
        .and()
        .isMasterTemplateEqualTo(false)
        .findAll();

    // Create a set of existing item names (lowercase) for quick lookup
    final existingNames = existingMonthlyItems
        .map((item) => item.itemName.toLowerCase())
        .toSet();

    var addedCount = 0;

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
          newItem.ownerUid = uid;
          await _isar.groceryItems.put(newItem);
          addedCount++;
        }
      }
    });

    return addedCount;
  }
}
