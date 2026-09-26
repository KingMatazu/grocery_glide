import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_glide/model/grocery_item.dart';
import 'package:grocery_glide/services/grocery_service.dart';

/// The gate resolves the signed-in account asynchronously, so there is a window
/// where screens exist but no account is known yet. Reads during that window
/// have to come back empty rather than returning every account's rows, and
/// writes have to fail loudly rather than storing unowned rows nobody can ever
/// reach again.
///
/// These run without Isar because a null uid returns before the instance is
/// touched, which is the point being pinned down here.
void main() {
  GroceryItem sampleItem() =>
      GroceryItem(itemName: 'Milk', quantity: 2, price: 1.5);

  group('with no signed-in account', () {
    final service = GroceryService(null);

    test('reads return empty rather than every account\'s rows', () async {
      expect(await service.getAllItems(), isEmpty);
      expect(await service.getBoughtItems(), isEmpty);
      expect(await service.getUnboughtItems(), isEmpty);
      expect(await service.getMonthlyItems('2026-09'), isEmpty);
      expect(await service.getMasterTemplateItems(), isEmpty);
      expect(await service.searchItems('milk'), isEmpty);
    });

    test('aggregate reads are zero rather than throwing', () async {
      expect(await service.getTotalCost(), 0);
      expect(await service.getBoughtItemsCost(), 0);
      expect(await service.getRemainingCost(), 0);
      expect(await service.getShoppingProgress(), 0);
    });

    test('streams emit empty instead of waiting forever', () async {
      expect(await service.watchAllItems().first, isEmpty);
      expect(await service.watchUnboughtItems().first, isEmpty);
      expect(await service.watchMasterTemplate().first, isEmpty);
      expect(await service.watchMonthlyItems('2026-09').first, isEmpty);
    });

    test('writes throw instead of storing rows nobody owns', () async {
      await expectLater(
        service.addItem(sampleItem()),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.updateItem(sampleItem()),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.createMasterTemplate([sampleItem()]),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.deleteAllItems(),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.resetMonthlyItemsToUnbought('2026-09'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.clearMonthlyItems('2026-09'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.ensureMonthlyItemsExist('2026-09'),
        throwsA(isA<StateError>()),
      );
    });

    test('claiming ownership is a no-op rather than a crash', () async {
      await expectLater(service.ensureOwnership(), completes);
    });
  });

  group('with a signed-in account', () {
    test('a new item is not owned until the service writes it', () {
      // The service is the single place ownership is assigned, so an item built
      // by a screen starts unowned and is only claimed on the way to Isar.
      expect(sampleItem().ownerUid, isEmpty);
    });
  });
}
