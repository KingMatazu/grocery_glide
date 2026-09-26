import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The persisted setup flags that decide what the app gate shows.
class StartupState {
  const StartupState({
    required this.onboardingComplete,
    required this.firstTimeSetupComplete,
  });

  final bool onboardingComplete;
  final bool firstTimeSetupComplete;
}

/// Read when the gate builds.
///
/// Invalidating this re-reads the flags, which is how the screens that finish
/// a setup step hand control back to the gate. They used to navigate instead,
/// but the gate owns the root route: a screen that replaces or wipes that
/// route takes the gate out of the navigator entirely, and with it the only
/// thing standing between a signed-out user and the grocery list.
final startupStateProvider = FutureProvider<StartupState>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return StartupState(
    onboardingComplete: prefs.getBool('onboarding_complete') ?? false,
    firstTimeSetupComplete: prefs.getBool('first_time_setup_complete') ?? false,
  );
});

/// Records that onboarding finished, so the gate moves on to sign-in.
Future<void> completeOnboarding(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_complete', true);
  ref.invalidate(startupStateProvider);
}

/// Records that the master template step is done, so the gate moves on to the
/// grocery list.
Future<void> completeFirstTimeSetup(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('first_time_setup_complete', true);
  ref.invalidate(startupStateProvider);
}
