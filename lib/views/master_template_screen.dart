import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/model/grocery_item.dart';
import 'package:grocery_glide/providers/currency_provider.dart';
import 'package:grocery_glide/providers/grocery_providers.dart';
import 'package:grocery_glide/services/grocery_service.dart';
import 'package:grocery_glide/views/grocery_list_screen.dart';
import 'package:grocery_glide/widgets/currency_selector.dart';
import 'package:intl/intl.dart';

class MasterTemplateScreen extends ConsumerStatefulWidget {
  const MasterTemplateScreen({super.key});

  @override
  ConsumerState<MasterTemplateScreen> createState() =>
      _MasterTemplateScreenState();
}

class _MasterTemplateScreenState extends ConsumerState<MasterTemplateScreen> {
  List<GroceryItem> stagingItems = [];
  bool hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadExistingTemplate();
  }

  Future<void> _loadExistingTemplate() async {
    final existingItems = await GroceryService.getMasterTemplateItems();
    setState(() {
      stagingItems = List.from(existingItems);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = ref.watch(currencyFormatterProvider);
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Master Template'),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () async {
              if (hasUnsavedChanges) {
                // Show dialog via PopScope
                Navigator.pop(context);
              } else {
                // No unsaved changes?, go directly to grocery list
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const GroceryListScreen()),
                  (route) => false,
                );
              }
            },
          ),
          actions: [
            if (hasUnsavedChanges)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: const Icon(Icons.circle, color: Colors.orange, size: 8),
              ),
            TextButton(
              onPressed: _saveTemplate,
              child: Text(
                'Done',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import_default',
                  child: Text('Import Default Template'),
                ),
                const PopupMenuItem(
                  value: 'create_from_current',
                  child: Text('Create from Current Month'),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear All Items'),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'import_default':
                    _importDefaultTemplate();
                    break;
                  case 'create_from_current':
                    _createFromCurrentMonth();
                    break;
                  case 'clear_all':
                    _clearAllItems();
                    break;
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: const CurrencySelector(),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: stagingItems.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 0,
                        bottom: 75,
                      ),
                      itemCount: stagingItems.length,
                      itemBuilder: (context, index) => Card(
                        color: Theme.of(context).colorScheme.surface,
                        child: ListTile(
                          title: Text(
                            stagingItems[index].itemName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            'Qty: ${stagingItems[index].quantity}, Price: ${stagingItems[index].price.formatCurrency(currencyFormatter)}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _editItem(index),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () => _deleteItem(index),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewItem,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.add, size: 30),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.list_alt, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No master template items',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items or import a default template',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _importDefaultTemplate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'Import Default Template',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _importDefaultTemplate() {
    final defaultItems = [
      GroceryItem.template(itemName: 'Milk', quantity: 1, price: 3.50),
      GroceryItem.template(itemName: 'Bread', quantity: 1, price: 2.50),
      GroceryItem.template(itemName: 'Eggs', quantity: 12, price: 4.00),
      GroceryItem.template(itemName: 'Bananas', quantity: 6, price: 2.00),
      GroceryItem.template(itemName: 'Chicken Breast', quantity: 1, price: 8.00),
      GroceryItem.template(itemName: 'Rice', quantity: 1, price: 3.00),
      GroceryItem.template(itemName: 'Apples', quantity: 4, price: 3.50),
      GroceryItem.template(itemName: 'Yogurt', quantity: 4, price: 5.00),
      GroceryItem.template(itemName: 'Cheese', quantity: 1, price: 4.50),
      GroceryItem.template(itemName: 'Tomatoes', quantity: 3, price: 2.50),
    ];

    int addedCount = 0;
    int skippedCount = 0;

    setState(() {
      // Add default items to staging, avoiding duplicates
      for (final defaultItem in defaultItems) {
        // Checks for duplicate (case insensitive)
        final exists = stagingItems.any(
          (item) =>
              item.itemName.toLowerCase() == defaultItem.itemName.toLowerCase(),
        );
        if (!exists) {
          stagingItems.add(defaultItem);
          addedCount++;
        } else {
          skippedCount++;
        }
      }
      if (addedCount > 0) {
        hasUnsavedChanges = true;
      }
    });

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skippedCount > 0 
            ? 'Added $addedCount items. Skipped $skippedCount duplicates.'
            : 'Added $addedCount default items to template.'
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All default items already exist in your template'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _createFromCurrentMonth() async {
    final currentMonth = ref.read(currentMonthProvider);
    final currentItems = await GroceryService.getMonthlyItems(currentMonth);

    if (currentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items found in current month'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Create Template from Current Month',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'This will update your maaster template with ${currentItems.length} items from the cureent month. Your current month\'s shopping progress will be preserved.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Create Template'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int addedCount = 0;
    int skippedCount = 0;

    setState(() {
      // Add items from the current month, check for duplicates
      for (final item in currentItems) {
        // check if item already exists in staging (case insensitive)
        final exists = stagingItems.any(
          (existingItem) =>
              existingItem.itemName.toLowerCase() ==
              item.itemName.toLowerCase(),
        );

        if (!exists) {
          // create template items without the bought status
          stagingItems.add(
            GroceryItem.template(
              itemName: item.itemName,
              quantity: item.quantity,
              price: item.price,
              notes: item.notes,
            ),
          );
          addedCount++;
        } else {
          skippedCount++;
        }
      }

      if (addedCount > 0) {
        hasUnsavedChanges = true;
      }
    });

    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skippedCount > 0
                ? 'Added $addedCount items. Skipped $skippedCount duplicates. Click Done to save!'
                : 'Added $addedCount items to template. Click Done to save!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All items from current month alreay exist in template'),
          backgroundColor: Colors.orange,
        )
      );
    }
  }

  void _clearAllItems() async {
    if (stagingItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Clear All Items',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to remove all items from the template?',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        stagingItems.clear();
        hasUnsavedChanges = true;
      });
    }
  }

  void _deleteItem(int index) {
    setState(() {
      stagingItems.removeAt(index);
      hasUnsavedChanges = true;
    });
  }

  void _editItem(int index) async {
    final item = stagingItems[index];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TemplateItemDialog(
        initialName: item.itemName,
        initialQuantity: item.quantity,
        initialPrice: item.price,
        initialNotes: item.notes,
        existingItems: stagingItems,
        currentItemIndex: index,
      ),
    );

    if (result != null) {
      setState(() {
        stagingItems[index] = GroceryItem.template(
          itemName: result['name'],
          quantity: result['quantity'],
          price: result['price'],
          notes: result['notes'],
        );
        hasUnsavedChanges = true;
      });
    }
  }

  void _addNewItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TemplateItemDialog(existingItems: stagingItems),
    );

    if (result != null) {
      setState(() {
        stagingItems.add(
          GroceryItem.template(
            itemName: result['name'],
            quantity: result['quantity'],
            price: result['price'],
            notes: result['notes'],
          ),
        );
        hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveTemplate() async {
    try {
      // Save all staging items as the master template
      // This will clear existing master template and save new ones
      await GroceryService.createMasterTemplate(stagingItems);

      // Create monthly items for current month
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      // Clear exisitng monthly items for current month
      await GroceryService.clearMonthlyItems(currentMonth);
      // Create fresh monthly itmes for current month
      await GroceryService.createMonthlyListFromTemplate(currentMonth);

      setState(() {
        hasUnsavedChanges = false;
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const GroceryListScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving template: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Unsaved Changes',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'You have unsaved changes. Do you want to discard them?',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (shouldDiscard == true && mounted) {
      // Navigate to grocery List Screen instead
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GroceryListScreen()),
        (route) => false,
      );
      return false;
    }

    return shouldDiscard ?? false;
  }
}

// Enhanced dialog with editing capability
class _TemplateItemDialog extends StatefulWidget {
  final String? initialName;
  final int? initialQuantity;
  final double? initialPrice;
  final String? initialNotes;
  final List<GroceryItem> existingItems;
  final int? currentItemIndex;

  const _TemplateItemDialog({
    this.initialName,
    this.initialQuantity,
    this.initialPrice,
    this.initialNotes,
    this.existingItems = const [],
    this.currentItemIndex,
  });

  @override
  State<_TemplateItemDialog> createState() => __TemplateItemDialogState();
}

class __TemplateItemDialogState extends State<_TemplateItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _quantityController = TextEditingController(
      text: widget.initialQuantity?.toString() ?? '1',
    );
    _priceController = TextEditingController(
      text: widget.initialPrice?.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;

    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  bool _isDuplicate(String itemName) {
    final normalizedName = itemName.trim().toLowerCase();

    for (int i = 0; i < widget.existingItems.length; i++) {
      // Skip the current item when editing
      if (widget.currentItemIndex != null && i == widget.currentItemIndex) {
        continue;
      }
      if (widget.existingItems[i].itemName.toLowerCase() == normalizedName) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(
        widget.initialName != null ? 'Edit Template Item' : 'Add Template Item',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Item Name',
                labelStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity',
                labelStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter quantity';
                }
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Please enter valid quantity';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Price',
                labelStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter price';
                }
                if (double.tryParse(value) == null ||
                    double.parse(value) <= 0) {
                  return 'Please enter valid price';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                labelStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final capitalizedName = _capitalizeWords(
                _nameController.text.trim(),
              );

              // Check for duplicate
              if (_isDuplicate(capitalizedName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item "$capitalizedName" already exists!'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'name': capitalizedName,
                // 'name': _nameController.text.trim(),
                'quantity': int.parse(_quantityController.text),
                'price': double.parse(_priceController.text),
                'notes': _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
              });
            }
          },
          child: Text(widget.initialName != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
