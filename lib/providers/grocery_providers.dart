
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/model/grocery_item.dart';
import 'package:grocery_glide/services/grocery_service.dart';
import 'package:intl/intl.dart';

// Provider for all grocery items stream
final groceryItemsProvider = StreamProvider<List<GroceryItem>>((ref) {
  return GroceryService.watchAllItems();
});

// // Provider for filtered items (unbought only)
// final unboughtItemsProvider = StreamProvider<List<GroceryItem>>((ref) {
//   return GroceryService.watchUnboughtItems();
// });

// Provider for search query
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// Provider for filter type
enum FilterType { all, bought, unbought }
class FilterTypeNotifier extends Notifier<FilterType> {
  @override
  FilterType build() => FilterType.all;

  void setFilter(FilterType filter) => state = filter;
}
final filterTypeProvider = NotifierProvider<FilterTypeNotifier, FilterType>(FilterTypeNotifier.new);

// Provider for filtered and searched items
final filteredGroceryItemsProvider = Provider<AsyncValue<List<GroceryItem>>>((ref) {
  // final groceryItemsAsync = ref.watch(groceryItemsProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final monthlyItemsAsync = ref.watch(monthlyGroceryItemsProvider(selectedMonth));
  final searchQuery = ref.watch(searchQueryProvider);
  final filterType = ref.watch(filterTypeProvider);

  return monthlyItemsAsync.when(
    data: (items) {
      var filteredItems = items;

      // Apply filter
      switch (filterType) {
        case FilterType.bought:
          filteredItems = items.where((item) => item.isBought).toList();
          break;
        case FilterType.unbought:
          filteredItems = items.where((item) => !item.isBought).toList();
          break;
        case FilterType.all:
          break;
      }

      // Apply search
      if (searchQuery.isNotEmpty) {
        filteredItems = filteredItems
            .where((item) =>
                item.itemName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                (item.notes?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false))
            .toList();
      }

      return AsyncValue.data(filteredItems);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Provider for grocery statistics
final groceryStatsProvider = Provider<AsyncValue<GroceryStats>>((ref) {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final monthlyItemsAsync = ref.watch(monthlyGroceryItemsProvider(selectedMonth));

  return monthlyItemsAsync.when(
    data: (items) {
      final stats = GroceryStats.fromItems(items);
      return AsyncValue.data(stats);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Provider for master template items
final masterTemplateProvider = StreamProvider<List<GroceryItem>>((ref) {
  return GroceryService.watchMasterTemplate();
});

// Provider for current month key
class CurrentMonthNotifier extends Notifier<String> {
  @override
  String build() => DateFormat('yyyy-MM').format(DateTime.now());
}
final currentMonthProvider = NotifierProvider<CurrentMonthNotifier, String>(CurrentMonthNotifier.new);

// Provider for selected month (for history viewing)
class SelectedMonthNotifier extends Notifier<String> {
  @override
  String build() => DateFormat('yyyy-MM').format(DateTime.now());

  void selectMonth(String monthKey) => state = monthKey;
}
final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, String>(SelectedMonthNotifier.new);

// Provider for monthly grocery items
final monthlyGroceryItemsProvider = StreamProvider.family<List<GroceryItem>, String>((ref, monthKey) {
  return GroceryService.watchMonthlyItems(monthKey);
});

// Statistics model
class GroceryStats {
  final int totalItems;
  final int boughtItems;
  final int unboughtItems;
  final double totalCost;
  final double boughtCost;
  final double remainingCost;
  final double completionPercentage;

  GroceryStats({
    required this.totalItems,
    required this.boughtItems,
    required this.unboughtItems,
    required this.totalCost,
    required this.boughtCost,
    required this.remainingCost,
    required this.completionPercentage,
  });

  factory GroceryStats.fromItems(List<GroceryItem> items) {
    final totalItems = items.length;
    final boughtItems = items.where((item) => item.isBought).length;
    final unboughtItems = totalItems - boughtItems;
    
    final totalCost = items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    final boughtCost = items
        .where((item) => item.isBought)
        .fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    final remainingCost = totalCost - boughtCost;
    
    final completionPercentage = totalItems > 0 ? (boughtItems / totalItems) * 100 : 0.0;

    return GroceryStats(
      totalItems: totalItems,
      boughtItems: boughtItems,
      unboughtItems: unboughtItems,
      totalCost: totalCost,
      boughtCost: boughtCost,
      remainingCost: remainingCost,
      completionPercentage: completionPercentage,
    );
  }
}