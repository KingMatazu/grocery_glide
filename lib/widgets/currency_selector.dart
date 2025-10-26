import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/providers/currency_provider.dart';

class CurrencySelector extends ConsumerWidget {
  const CurrencySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCurrency = ref.watch(currencyProvider);

    return ListTile(
      leading: Icon(
        Icons.attach_money,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        'Currency',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${selectedCurrency.code} - ${selectedCurrency.name}',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontSize: 14,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selectedCurrency.symbol,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            size: 16,
          ),
        ],
      ),
      onTap: () => _showCurrencyPicker(context, ref, selectedCurrency),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, CurrencyData currentCurrency) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Select Currency',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Currency list
            Expanded(
              child: ListView.builder(
                itemCount: AppCurrencies.currencies.length,
                itemBuilder: (context, index) {
                  final currency = AppCurrencies.currencies[index];
                  final isSelected = currency.code == currentCurrency.code;
                  
                  return ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          currency.symbol,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      currency.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      currency.code,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      ref.read(currencyProvider.notifier).setCurrency(currency);
                      Navigator.pop(context);
                    },
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