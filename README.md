# RoadSafe AI

RoadSafe AI - Pothole and Blind Spot Detection System.

A Flutter app with on-device pothole and vehicle detection, live GPS and IMU
readings, and local notifications.

## Detection model status

`models/blindspot_model.tflite` is Google's pretrained EfficientDet-Lite0
object detector for COCO categories. It can identify common vehicle classes
(car, motorcycle, bus and truck) from camera frames. The blind-spot and Live
Detection screens run this model on-device and report the detected class and
its side of the image. The model does not identify a vehicle as being in a
physical blind spot, and this monocular camera setup does not measure distance
or time-to-collision. See Google's [TensorFlow Lite object detection
guide](https://ai.google.dev/edge/litert/libraries/object_detection) and
[official model download script](https://github.com/tensorflow/examples/blob/master/lite/examples/object_detection/raspberry_pi/setup.sh).

`models/pothole_model.tflite` is a YOLO11n model fine-tuned to detect potholes
and sewage manholes. The app filters for the pothole class. Model attribution:
Taha Ugan, [pothole-yolo11n](https://huggingface.co/tahaUgan/pothole-yolo11n),
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The expected asset paths are asserted by `test/model_asset_test.dart`.

The app does not fabricate detection readings. The blind-spot screen leaves
distance and collision time unmeasured, and its simulation button labels sample
values explicitly. Pothole detections are stored locally with available GPS
coordinates; users can review, photograph, share, and manually sync reports.
Cloud sync needs Firebase Firestore configured and a signed-in account. Settings
are stored on device, and spoken pothole alerts are optional. `test/honest_data_test.dart`
protects against invented readings.

### 2. Authentication is not configured

There is no `google-services.json` in the repository, so email/password and
Google sign-in cannot work until you add one - see
[Authentication setup](#authentication-setup). Until then, use
[Demo mode](#demo-mode).

The `pothole/` training dataset is git-ignored, so a fresh clone does not
contain it.

## Getting started

Built and verified against Flutter **3.24.0** (Dart **3.5.0**) on Windows.

```powershell
flutter pub get
flutter run                 # pick a connected device with `flutter devices`
```

`flutter analyze` and `flutter test` are both clean and should stay that way.

| Command | Notes |
| --- | --- |
| `flutter run` | Needs a device or emulator |
| `flutter test` | 30 tests, no device required |
| `flutter build apk --debug` | Debug APK (large; not for distribution) |
| `flutter build apk --release` | Fat release APK, all ABIs (~84 MB) |
| `flutter build apk --release --split-per-abi` | One APK per ABI (~27-34 MB) |
| `flutter build appbundle --release` | AAB for Play Store |
| `flutter build web` | Builds, but detection is off |

A browser works for the UI, but pothole and blind-spot detection does not -
see the next section.

## Platform support

`camera`, `geolocator`, `sensors_plus`, `flutter_local_notifications`,
`permission_handler`, `image_picker`, `google_maps_flutter` and the Firebase
packages all support web. **`tflite_flutter` does not**: it binds to the native
TensorFlow Lite runtime through `dart:ffi`, which does not exist in a browser.

Importing it from shared code therefore breaks `flutter build web` outright, so
the YOLO service is dispatched at compile time in
`lib/services/yolo_service.dart`:

```dart
export 'yolo_service_web.dart' if (dart.library.io) 'yolo_service_io.dart';
```

| Platform | Implementation | Detection |
| --- | --- | --- |
| Android, iOS, macOS, Linux, Windows | `yolo_service_io.dart` | Yes |
| Web | `yolo_service_web.dart` (stub) | No |

The IO implementation reaches TensorFlow Lite through `dart:ffi`. The web stub
keeps the same public API, so callers need no conditional logic, but
`loadModel` throws `UnsupportedError`. The camera screen already catches that
and reports "AI model not available", leaving the rest of the screen usable.

Note that `dart analyze` targets the VM, where `dart:ffi` is valid, so it will
**not** catch a web build break. Verify with `flutter build web`.

## Demo mode

The login screen offers **Continue as Guest (Demo Mode)**, which opens the app
with no Firebase account, no email and no password. Use it for demos, or on a
build with no Firebase configuration - real sign-in cannot work there at all.

A guest session is held in memory only. It is never written to Firestore, never
restored after an app restart, and never leaks into a real account. Home and
Profile show `Guest` / `Demo mode - not signed in` rather than placeholder
account details, and fields with no data source report `Not set` instead of
invented values. Sign out from the navigation drawer or from Profile.

A real Firebase session *is* restored across launches, so a signed-in user skips
the login form on the next start.

## Authentication setup

Sign-in uses Firebase Authentication and supports email/password plus Google.
Users must create an account through **Register** before they can sign in with
email/password; an unregistered address is reported as such.

### 1. Add the Firebase Android configuration

Download `google-services.json` for this app from the Firebase console and
place it at `android/app/google-services.json`. The file is git-ignored.

`android/app/build.gradle` applies the Google Services plugin only when that
file exists, so the project still builds without it (authentication is then
disabled and the UI reports "Firebase is not configured").

### 2. Enable the sign-in providers

Firebase console -> Authentication -> Sign-in method:

- **Email/Password** -> Enable
- **Google** -> Enable, then choose a support email

For report cloud sync, also create a Firestore database in the Firebase console
and deploy rules that allow each authenticated user to access only their own
`users/{uid}/road_reports` collection. Reports remain local if Firebase is not
configured or a sync attempt fails.

### 3. Register the Android SHA-1 fingerprint

Firebase console -> Project settings -> Your apps -> the Android app ->
*Add fingerprint*.

Print **your own** debug keystore fingerprint with:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -alias androiddebugkey -keypass android
```

For reference, the machine this was last developed on produced:

```text
SHA-1   41:57:4F:26:AC:B0:40:E9:6E:51:57:45:0E:A9:AA:5A:CE:05:3D:E5
SHA-256 94:6F:0C:43:EE:18:D5:36:23:6B:1A:CA:78:9B:BA:4D:C8:7A:5A:36:22:63:5F:9B:EC:61:DB:39:CF:54:28:BA
```

A debug keystore is per-machine, so your values will differ and you must
register your own. A release build signed with a different keystore needs
*that* keystore's fingerprint registered as well.

After changing any fingerprint, uninstall the app from the device and install
the new build: Google Play Services caches the certificate per install.

## Android setup

Maps needs a Google Maps Android API key. Add this line to
`android/local.properties`, the git-ignored file Flutter already uses for your
machine-specific SDK paths:

```properties
MAPS_API_KEY=your_key
```

Keep the key out of `android/gradle.properties`: that file is tracked by git,
so anything added there is committed. Passing `-PMAPS_API_KEY=your_key` on the
Gradle command line also works.

`android/app/build.gradle` reads the key from `android/local.properties` and
falls back to the placeholder `REPLACE_WITH_ANDROID_MAPS_API_KEY` when it is
absent, so a missing key never breaks the build - the map simply stays blank
until a real key is supplied. The value is injected into the manifest as
`com.google.android.geo.API_KEY`.

To keep the key restricted, enable the Maps SDK for Android in the Google Cloud
console and allowlist this app's package name (`com.roadsafe.ai.program2`) plus
the matching SHA-1 from the step above.

## Release builds

A release build is signed with the **debug** certificate unless
`android/key.properties` exists - `build.gradle` falls back to
`signingConfigs.debug` so local release builds stay possible. Debug-signed
builds install fine but **cannot be uploaded to Play Store**, and their
certificate expires in 30 years from creation. To sign properly, create
`android/key.properties` (git-ignored) with:

```properties
storeFile=../upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Then re-run the build. The SHA-1 of that keystore must be registered in the
Firebase console as described above.

Prefer `--split-per-abi` for anything you hand to someone: the default fat APK
bundles four ABIs when a phone uses only one.

## Project layout

```text
lib/
  main.dart        Entry point; starts the UI before Firebase finishes
  app.dart         MaterialApp, theme mode, route table
  models/          DetectionResult and DetectionType
  screens/         One file per screen
  services/        Auth, settings, GPS, IMU, notifications, YOLO
  utils/           Route table
  theme/           Light and dark themes, colours, text styles
models/            TFLite assets (pothole and COCO vehicle detectors)
test/              30 tests
```

`lib/services/yolo_service*.dart` is the three-file platform dispatch described
above. Unused scaffolding has been removed, so nothing in `lib/` is dead code.

`pothole/` is a git-ignored training dataset and is not part of the checkout.
