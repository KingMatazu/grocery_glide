
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/model/grocery_item.dart';
import 'package:grocery_glide/providers/grocery_providers.dart';
import 'package:grocery_glide/services/grocery_service.dart';

class MasterTemplateScreen extends ConsumerWidget {
  const MasterTemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterItemsAsync = ref.watch(masterTemplateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D),
      appBar: AppBar(
        title: const Text('Master Template'),
        backgroundColor: Colors.transparent,
        actions: [
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
            ],
            onSelected: (value) {
              if (value == 'import_default') {
                _importDefaultTemplate(context);
              } else if (value == 'create_from_current') {
                _createFromCurrentMonth(context, ref);
              }
            },
          ),
        ],
      ),
      body: masterItemsAsync.when(
        data: (items) => items.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) => Card(
                  child: ListTile(
                    title: Text(items[index].itemName),
                    subtitle: Text('Qty: ${items[index].quantity}, Price: ${items[index].price}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteTemplateItem(items[index]),
                    ),
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTemplateItem(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.list_alt, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No master template created'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _importDefaultTemplate(context),
            child: const Text('Import Default Template'),
          ),
        ],
      ),
    );
  }

  void _importDefaultTemplate(BuildContext context) {
    final defaultItems = [
      GroceryItem.template(itemName: 'Milk', quantity: 1, price: 3.50),
      GroceryItem.template(itemName: 'Bread', quantity: 1, price: 2.00),
      GroceryItem.template(itemName: 'Eggs', quantity: 12, price: 4.00),
      // Add more default items
    ];
    
    GroceryService.createMasterTemplate(defaultItems);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default template imported!')),
    );
  }

  void _createFromCurrentMonth(BuildContext context, WidgetRef ref) async {
    final currentMonth = ref.read(currentMonthProvider);
    final currentItems = await GroceryService.getMonthlyItems(currentMonth);
    
    await GroceryService.createMasterTemplate(currentItems);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template created from current month!')),
      );
    }
  }

  void _addTemplateItem(BuildContext context) {
    // Show dialog to add new template item
    // Use your existing AddEditGroceryDialog
  }

  void _deleteTemplateItem(GroceryItem item) {
    GroceryService.deleteItem(item.id);
  }
}