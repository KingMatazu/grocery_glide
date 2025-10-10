import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:grocery_glide/model/grocery_item.dart';
import 'package:grocery_glide/providers/grocery_providers.dart';
import 'package:grocery_glide/services/grocery_service.dart';
import 'package:grocery_glide/views/profile_and_settings_screen.dart';
import 'package:grocery_glide/widgets/month_picker_widget.dart';
import 'package:intl/intl.dart';

class GroceryListScreen extends ConsumerStatefulWidget {
  const GroceryListScreen({super.key});

  @override
  ConsumerState<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends ConsumerState<GroceryListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteItem(GroceryItem item) async {
    try {
      await GroceryService.deleteItem(item.id);
      _showSnackBar('${item.itemName} deleted');
    } catch (e) {
      _showErrorSnackBar('Failed to delete item: $e');
    }
  }

  Future<void> _toggleItemBought(GroceryItem item) async {
    try {
      await GroceryService.toggleBoughtStatus(item.id);
    } catch (e) {
      _showErrorSnackBar('Failed to update item: $e');
    }
  }

  Future<void> _editItem(GroceryItem item) async {
    final result = await showDialog<GroceryItem>(
      context: context,
      builder: (context) => AddEditGroceryDialog(item: item),
    );

    if (result != null) {
      _showSnackBar('Item updated successfully');
    }
  }

  Future<void> _addItem() async {
    final result = await showDialog<GroceryItem>(
      context: context,
      builder: (context) => const AddEditGroceryDialog(),
    );

    if (result != null) {
      _showSnackBar('Item added successfully');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItemsAsync = ref.watch(filteredGroceryItemsProvider);
    final statsAsync = ref.watch(groceryStatsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D),
      body: SafeArea(
        child: Column(
          children: [
            // Header with stats
            statsAsync.when(
              data: (stats) => GroceryHeader(stats: stats, onMonthTap: () => _showMonthPicker(context, ref),),
              loading: () => const GroceryHeader(stats: null),
              error: (_, _) => const GroceryHeader(stats: null),
            ),
            //
            SearchAndFilterBar(
              searchController: _searchController,
              onSearchChanged: (query) {
                ref.read(searchQueryProvider.notifier).state = query;
              },
              onFilterChanged: (filter) {
                ref.read(filterTypeProvider.notifier).state = filter;
              },
            ),
            // List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Refresh is automatic with streams, but we can add haptic feedback
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: filteredItemsAsync.when(
                  data: (items) => items.isEmpty
                      ? const EmptyStateWidget()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return GroceryListItem(
                              key: ValueKey(item.id),
                              item: item,
                              onEdit: () => _editItem(item),
                              onDelete: () => _deleteItem(item),
                              onToggleBought: () => _toggleItemBought(item),
                            );
                          },
                        ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $error',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(groceryItemsProvider);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}

// Header with real-time stats
class GroceryHeader extends ConsumerWidget {
  final GroceryStats? stats;
  final VoidCallback? onMonthTap;

  const GroceryHeader({super.key, required this.stats, this.onMonthTap});

  String get currentMonth => DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top row with month and profile
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _showMonthPicker(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMM yyyy').format(DateTime.parse('${ref.watch(selectedMonthProvider)}-01')),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white,),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToProfile(context),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 1)),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row with progress indicator
          if (stats != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items: ${stats!.totalItems}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bought: ${stats!.boughtItems}',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ${NumberFormat('#,##0.00').format(stats!.boughtCost)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats!.completionPercentage.toStringAsFixed(1)}% Complete',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 1.5),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            LinearProgressIndicator(
              value: stats!.completionPercentage / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade300),
              minHeight: 4,
            ),
          ] else
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
        ],
      ),
    );
  }
}

void _navigateToProfile(BuildContext context){
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ProfileAndSettingsScreen()),
  );
}

void _showMonthPicker(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    builder: (context) => MonthPickerWidget(
      onMonthSelected: (monthKey) async{
        if (kDebugMode) {
          print('Month selected: $monthKey');
        } // debug log
        // Ensure items exist for the selected month
        await GroceryService.ensureMonthlyItemsExist(monthKey);
        ref.read(selectedMonthProvider.notifier).state = monthKey;
        Navigator.pop(context);
      },
    ),
  );
}

// Search and Filter Bar
class SearchAndFilterBar extends ConsumerWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<FilterType> onFilterChanged;

  const SearchAndFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(filterTypeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 1)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 1)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<FilterType>(
              value: currentFilter,
              onChanged: (value) => onFilterChanged(value!),
              dropdownColor: const Color(0xFF2D2D2D),
              underline: const SizedBox(),
              padding: EdgeInsets.symmetric(horizontal: 10,),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: FilterType.all,
                  child: Text('All', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: FilterType.unbought,
                  child: Text('Todo', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: FilterType.bought,
                  child: Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Empty State Widget
class EmptyStateWidget extends ConsumerWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthName = DateFormat('MMMM yyyy').format(DateTime.parse('$selectedMonth-01'));
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No items found for $monthName',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.15),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switch to current month or create from template',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 1),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Slideable List Item Component
class GroceryListItem extends StatelessWidget {
  final GroceryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleBought;

  const GroceryListItem({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleBought,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(item.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: const Color(0xFFf44336),
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.isBought
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isBought
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggleBought,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.isBought ? Colors.green : Colors.transparent,
                    border: Border.all(
                      color: item.isBought
                          ? Colors.green
                          : Colors.white.withValues(alpha: 0.25),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: item.isBought
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: TextStyle(
                        color: item.isBought
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        decoration: item.isBought
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'price: ${item.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: item.isBought
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                        decoration: item.isBought
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Qty: ${item.quantity}',
                    style: TextStyle(
                      color: item.isBought
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      decoration: item.isBought
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ${item.totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: item.isBought
                          ? Colors.green.shade300
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      decoration: item.isBought
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add/Edit Item Dialog Component
class AddEditGroceryDialog extends StatefulWidget {
  final GroceryItem? item;

  const AddEditGroceryDialog({super.key, this.item});

  bool get isEditing => item != null;

  @override
  State<AddEditGroceryDialog> createState() => _AddEditGroceryDialogState();
}

class _AddEditGroceryDialogState extends State<AddEditGroceryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _nameController.text = widget.item!.itemName;
      _quantityController.text = widget.item!.quantity.toString();
      _priceController.text = widget.item!.price.toString();
      _notesController.text = widget.item!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final item = widget.isEditing
          ? widget.item!
          : GroceryItem(
              itemName: _nameController.text.trim(),
              quantity: int.parse(_quantityController.text),
              price: double.parse(_priceController.text),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

      if (widget.isEditing) {
        item.itemName = _nameController.text.trim();
        item.quantity = int.parse(_quantityController.text);
        item.price = double.parse(_priceController.text);
        item.notes = _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim();

        await GroceryService.updateItem(item);
      } else {
        await GroceryService.addItem(item);
      }

      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2D2D2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing ? 'Edit Item' : 'Add Item',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              _buildTextField(
                controller: _nameController,
                label: 'Item Name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _quantityController,
                      label: 'Quantity',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter quantity';
                        }
                        if (int.tryParse(value) == null ||
                            int.parse(value) <= 0) {
                          return 'Enter valid quantity';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'Price',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter price';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'Enter valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _notesController,
                label: 'Notes (Optional)',
                maxLines: 2,
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        widget.isEditing ? 'Update' : 'Add',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4CAF50)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}
