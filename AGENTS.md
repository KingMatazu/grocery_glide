# Grocery Glide

## Play review / policy strings (keep in sync with the app)

- **Play Store Data safety** self-assessment (per current impl — no server sync,
  grocery data is device-local Isar):
  Collected+Shared = Email, Name, User IDs, Search history, Device or other IDs
  (Firebase). Everything else **No**. Privacy policy URL points at the webpage
  repo (below). See AGENTS.md of that repo + `play_review_credentials.md`.
- **Google Sign-In & Play App Signing:** when the AAB is Play-re-signed, auth
  needs the **Play App Signing SHA-1** registered in Firebase (Auto screen HNA
  → SHA-1 fingerprint) or Google Sign-In fails in the production build.
- **App review access:** see `play_review_credentials.md` (local-only, gitignored).
- **Account deletion:** web page in the webpage repo:
  `...\grocery_glide_webpage\delete-account\index.html`,
  published at `https://grocery-glide-webpage.vercel.app/delete-account/index.html`.

## Android build notes

### isar_flutter_libs compileSdk patch (re-apply after `flutter pub get`)
`isar_flutter_libs` (v3.1.0+1, archived plugin) hardcodes `compileSdkVersion 30` in
its build script. AGP 9+ enforces AAR metadata checks: its androidx dependencies
(fragment 1.7.1, etc.) require compileSdk >= 34, so `checkDebugAarMetadata` /
`checkReleaseAarMetadata` fail and, if disabled, `bundleDebugAar` fails Gradle's
input-validation ("input file does not exist").

Fix: patch the pub-cache copy so the module compiles against 36:

```
C:\Users\matax\AppData\Local\Pub\Cache\hosted\pub.dev\isar_flutter_libs-3.1.0+1\android\build.gradle
```

Change line 31: `compileSdkVersion 30` -> `compileSdkVersion 36`.

The patch lives outside the repo and is wiped whenever the pub cache is refreshed
(`flutter pub get`, cache clean). Re-apply after any dependency refresh. Flutter's
root `android/build.gradle.kts` must NOT override compileSdk for subprojects on
AGP 9.1 (finalized too early -> "It is too late to set compileSdk").

## iOS sideload (SideStore) notes

- **This is a Windows dev box — no local `flutter build ipa`.** IPA is produced
  by CI on a macOS runner (`.github/workflows/ios.yml`) triggered by a tag
  `ios-v*`. Push tag `ios-v0.1.0` -> app kicks off -> download the IPA artifact
  from the Actions run -> install it with SideStore on the iPhone.
- **The workflow builds UNSIGNED** (`flutter build ipa --release --no-codesign`)
  specifically for sideloading. Sideload the resulting `Runner.ipa` with your
  Apple ID via SideStore/Sideloadly; it re-signs at install from the `.ipa`.
- **Bundle ID:** iOS uses `com.bvbyco.groceryGlide` (Android is
  `com.bvbyco.grocery_glide` — underscore not allowed in iOS bundle IDs, hence
  camelCase). Kept in sync in `project.pbxproj` (PRODUCT_BUNDLE_IDENTIFIER) and
  `GoogleService-Info.plist` (BUNDLE_ID) — keep the two in lockstep whenever
  either changes.
- **Firebase / Google Sign-In on iOS:** configured via `GoogleService-Info.plist`
  (BUNDLE_ID must match) + the `com.googleusercontent.apps.…` reversed client id
  URL scheme in `Info.plist` (`CFBundleURLTypes`). If a fresh
  `GoogleService-Info.plist` is ever downloaded from the Firebase iOS app, copy
  its `REVERSED_CLIENT_ID` into the Info.plist scheme list.
- **Podfile** is committed at `ios/Podfile` (iOS 13, `use_frameworks`, RunnerTests
  target) — do NOT rely on the gitignore. Board rotations may drop it.
- **App icon:** regenerate via `dart run flutter_launcher_icons` (config under
  `flutter_launcher_icons:` in pubspec; source master is the 1024px letterboxed
  `assets/icon/app_icon_master.png`). Simple asset PNG in
  `assets/GroceryGlide_logo.png`.
- **No Apple Developer account needed** for sideloading (free Apple ID signs it).
  Push notifications to the sideloaded build use local notifications only (iOS
  push/APNs entitlement will not be delivered when re-signed with a free ID).