import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/providers/startup_provider.dart';
import 'package:grocery_glide/views/master_template_screen.dart';

class FirstTimeSetupScreen extends ConsumerWidget {
  const FirstTimeSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
              const SizedBox(height: 24),
              Text(
                'Welcome to Grocery Glide!',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Create your master grocery template to get started. This will be your monthly shopping list.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Create Template Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToMasterTemplate(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create Master Template',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Skip Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _skipSetup(ref),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),
                    ),
                  ),
                  child: Text(
                    'Skip for Now',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goToMasterTemplate(BuildContext context, WidgetRef ref) async {
    await completeFirstTimeSetup(ref);
    if (!context.mounted) return;
    // Pushed, not pushed-and-replaced: the gate stays underneath as the root
    // route, and it will already be showing the grocery list by the time this
    // screen is popped.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MasterTemplateScreen()),
    );
  }

  Future<void> _skipSetup(WidgetRef ref) async {
    // No navigation. Invalidating the setup flags is enough: the gate swaps
    // its own child to the grocery list.
    await completeFirstTimeSetup(ref);
  }
}
