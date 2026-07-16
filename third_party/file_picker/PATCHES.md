# River patches for file_picker

This directory vendors `file_picker` 11.0.2 under its MIT license.

River keeps this stable release because it contains the upstream path-traversal
security fix and still supports the product's iOS 13 deployment target. The only
local source change is in `android/build.gradle`: Kotlin plugin selection checks
Flutter's `android.builtInKotlin` Gradle property as well as the Android Gradle
Plugin version. This is the compatibility fix released upstream in the 12.0.0
beta series.

Remove the vendored copy when a stable upstream release contains the same AGP 9
fix without requiring a higher iOS deployment target, or when River intentionally
raises its minimum iOS version.
