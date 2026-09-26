import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery_glide/providers/auth_provider.dart';

/// Full-screen confirmation shown after a successful sign-out.
///
/// The user asked to see this rather than a toast because signing out is
/// destructive from their point of view: everything they were looking at is
/// about to be replaced by a sign-in form. A banner that slides away in a few
/// seconds gives them no chance to register that it happened.
///
/// Back navigation is disabled deliberately. Popping here would reveal the
/// settings screen underneath while signed out, which is precisely the state
/// the app gate exists to prevent.
class SignOutSuccessScreen extends ConsumerWidget {
  const SignOutSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 84,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "You're signed out",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your grocery lists are still saved on this device. '
                    'Sign in to pick up where you left off.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        // Release the gate before popping so the root widget is
                        // free to manage the stack again.
                        ref
                            .read(signOutCelebrationProvider.notifier)
                            .end();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
