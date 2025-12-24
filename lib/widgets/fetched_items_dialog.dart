import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/model/grocery_item.dart';
import 'package:grocery_glide/providers/currency_provider.dart';
import 'package:grocery_glide/services/fetched_service.dart';
import 'package:grocery_glide/services/grocery_service.dart';

class FetchedItemsDialog extends ConsumerStatefulWidget {
  final String currentMonthKey;

  const FetchedItemsDialog({
    super.key,
    required this.currentMonthKey,
  });

  @override
  ConsumerState<FetchedItemsDialog> createState() => _FetchedItemsDialogState();
}

class _FetchedItemsDialogState extends ConsumerState<FetchedItemsDialog> {
  List<FetchedProduct>? products;
  List<FetchedProduct>? filteredProducts;
  bool isLoading = true;
  String? errorMessage;
  final Set<int> addedToMonth = {};
  final Set<int> addedToTemplate = {};
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase().trim();
      _filterProducts();
    });
  }

  void _filterProducts() {
    if (products == null) {
      filteredProducts = null;
      return;
    }

    if (searchQuery.isEmpty) {
      filteredProducts = products;
    } else {
      filteredProducts = products!
          .where((product) =>
              product.name.toLowerCase().contains(searchQuery))
          .toList();
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final fetchedProducts = await FetchedService.fetchGroceries();
      setState(() {
        products = fetchedProducts;
        filteredProducts = fetchedProducts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _addToCurrentMonth(FetchedProduct product, int index) async {
    try {
      // Check for duplicate
      final existingItems = await GroceryService.getMonthlyItems(widget.currentMonthKey);
      final isDuplicate = existingItems.any(
        (item) => item.itemName.toLowerCase() == product.name.toLowerCase(),
      );

      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} already exists in current month'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final newItem = GroceryItem(
        itemName: product.name,
        quantity: 1,
        price: product.price,
        monthKey: widget.currentMonthKey,
      );

      await GroceryService.addItem(newItem);

      // Give the database stream a moment to emit the change
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {
        addedToMonth.add(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added to current month'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addToMasterTemplate(FetchedProduct product, int index) async {
    try {
      // Check for duplicate in master template
      final existingTemplateItems = await GroceryService.getMasterTemplateItems();
      final isDuplicate = existingTemplateItems.any(
        (item) => item.itemName.toLowerCase().trim() == product.name.toLowerCase().trim(),
      );

      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} already exists in master template'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Check if already in current month BEFORE adding template
      final existingMonthItems = await GroceryService.getMonthlyItems(widget.currentMonthKey);
      final alreadyInMonth = existingMonthItems.any(
        (item) => item.itemName.toLowerCase().trim() == product.name.toLowerCase().trim(),
      );

      // Add to master template
      final templateItem = GroceryItem.template(
        itemName: product.name,
        quantity: 1,
        price: product.price,
      );
      templateItem.isMasterTemplate = true;

      await GroceryService.addItem(templateItem);

      // Add to current month if not already there
      if (!alreadyInMonth) {
        final monthItem = GroceryItem(
          itemName: product.name,
          quantity: 1,
          price: product.price,
          isBought: false,
        );
        monthItem.monthKey = widget.currentMonthKey;
        monthItem.isMasterTemplate = false;
        
        await GroceryService.addItem(monthItem);
      }

      // Give streams time to update
      await Future.delayed(const Duration(milliseconds: 200));

      setState(() {
        addedToTemplate.add(index);
        addedToMonth.add(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alreadyInMonth 
                ? '${product.name} added to master template'
                : '${product.name} added to template & current month'
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to template: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = ref.watch(currencyFormatterProvider);

    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Grocery Ideas',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Fetching items from Jumia...',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    )
                  : errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to fetch items',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please connect to Internet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _fetchProducts,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : products == null || products!.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No items found',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filteredProducts!.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_off,
                                          size: 48,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No items match "$searchQuery"',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: filteredProducts!.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts![index];
                                // Find the original index for tracking added items
                                final originalIndex = products!.indexOf(product);
                                final isAddedToMonth = addedToMonth.contains(originalIndex);
                                final isAddedToTemplate = addedToTemplate.contains(originalIndex);

                                return Card(
                                  color: Theme.of(context).colorScheme.surface,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                product.price.formatCurrency(currencyFormatter),
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Qty: 1',
                                                style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            // Add to current month button
                                                                                          SizedBox(
                                              width: 100,
                                              child: ElevatedButton(
                                                onPressed: isAddedToMonth
                                                    ? null
                                                    : () => _addToCurrentMonth(product, originalIndex),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isAddedToMonth
                                                      ? Colors.grey
                                                      : Theme.of(context).colorScheme.primary,
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isAddedToMonth ? Icons.check : Icons.add,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Month',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            // Add to template button
                                                                                          SizedBox(
                                              width: 100,
                                              child: OutlinedButton(
                                                onPressed: isAddedToTemplate
                                                    ? null
                                                    : () => _addToMasterTemplate(product, originalIndex),
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color: isAddedToTemplate
                                                        ? Colors.grey
                                                        : Theme.of(context).colorScheme.primary,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isAddedToTemplate ? Icons.check : Icons.bookmark_add,
                                                      size: 16,
                                                      color: isAddedToTemplate
                                                          ? Colors.grey
                                                          : Theme.of(context).colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Template',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isAddedToTemplate
                                                            ? Colors.grey
                                                            : Theme.of(context).colorScheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}