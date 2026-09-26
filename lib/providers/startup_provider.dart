import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grocery_glide/providers/auth_provider.dart';

/// The persisted setup flags that decide what the app gate shows.
class StartupState {
  const StartupState({
    required this.onboardingComplete,
    required this.firstTimeSetupComplete,
  });

  final bool onboardingComplete;
  final bool firstTimeSetupComplete;
}

/// Flag written before setup was per-account.
const _legacyFirstTimeSetupKey = 'first_time_setup_complete';

/// The master template step is recorded per account, not per device.
///
/// It used to be a single device-wide flag, so a second account signing in on
/// the same device skipped the step and landed on an empty grocery list with
/// no template and no obvious way to build one.
String _firstTimeSetupKey(String uid) => 'first_time_setup_complete_$uid';

/// Read when the gate builds.
///
/// Invalidating this re-reads the flags, which is how the screens that finish
/// a setup step hand control back to the gate. They used to navigate instead,
/// but the gate owns the root route: a screen that replaces or wipes that
/// route takes the gate out of the navigator entirely, and with it the only
/// thing standing between a signed-out user and the grocery list.
final startupStateProvider = FutureProvider<StartupState>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final user = ref.watch(currentUserProvider);

  // Onboarding runs before any account exists, so it stays device-wide.
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  if (user == null) {
    // Nobody is signed in, so there is no account to scope the setup step to.
    // Reporting it incomplete sends a returning account through the step rather
    // than dropping it on an empty list.
    return StartupState(
      onboardingComplete: onboardingComplete,
      firstTimeSetupComplete: false,
    );
  }

  final key = _firstTimeSetupKey(user.uid);
  var complete = prefs.getBool(key) ?? false;

  if (!complete && (prefs.getBool(_legacyFirstTimeSetupKey) ?? false)) {
    // Hand the device-wide flag to the first account that signs in, then
    // delete it. Leaving it in place would let every later account inherit it
    // and skip the step.
    complete = true;
    await prefs.setBool(key, true);
    await prefs.remove(_legacyFirstTimeSetupKey);
  }

  return StartupState(
    onboardingComplete: onboardingComplete,
    firstTimeSetupComplete: complete,
  );
});

/// Records that onboarding finished, so the gate moves on to sign-in.
Future<void> completeOnboarding(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_complete', true);
  ref.invalidate(startupStateProvider);
}

/// Records that the master template step is done for the signed-in account, so
/// the gate moves on to the grocery list.
Future<void> completeFirstTimeSetup(WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_firstTimeSetupKey(user.uid), true);
  ref.invalidate(startupStateProvider);
}

/// Sends the signed-in account back through the master template step.
///
/// Used by "Clear All Data", which removes the lists and therefore has to
/// remove the claim that there is a template to build a list from.
Future<void> resetFirstTimeSetup(WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_firstTimeSetupKey(user.uid));
  ref.invalidate(startupStateProvider);
}
