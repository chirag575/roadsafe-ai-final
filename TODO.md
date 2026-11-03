# TODO - RoadSafe AI Development

> **Read this first.** `README.md` describes the current behavior. Cloud sync
> requires Firebase setup, and blind-spot distance estimation is not available
> from the current camera model.

## Not done

- [ ] **Configure cloud report sync.** Local reports can be uploaded to a
      user's Firestore collection, but Firestore must be enabled and security
      rules deployed in the Firebase project. Photos are shared locally and
      are not uploaded.
- [ ] **Dedicated blind-spot detection.** The app currently uses a general
      COCO vehicle detector and can report vehicle class and image side. It
      does not infer physical blind spots, distance, or time-to-collision; a
      model trained for that task and suitable camera/sensor inputs are needed.
- [ ] **A real release keystore.** Release builds are debug-signed, so they
      install but cannot be uploaded to Play Store.
- [ ] **Automate report sync.** Reports persist locally and can be manually
      synced; retrying automatically when connectivity returns is not wired.
- [ ] **Route guard.** Every screen is registered in `AppRoutes` with no auth
      check in front of the authenticated ones.
- [ ] **Upgrade the toolchain.** Built against Flutter 3.24.0 (July 2024) with
      2025-era packages; it compiles, but it is far behind.

## Done

- [x] Bundle and integrate a pothole-trained YOLO11 TFLite detector.
- [x] Step 1: Generate missing web/ platform folder (`flutter create .`)
- [x] Step 2: Fix Firebase initialization crash in `lib/main.dart`
- [x] Step 3: Make the app web-compatible (verify top-level flow works)
- [x] Step 4: Run & verify the app on web (Chrome)
- [x] Step 5: Fix `flutter build web` - `tflite_flutter` needs `dart:ffi`, so
      the YOLO service is dispatched per platform

## GPS & Location

- [x] Step 1: Implement real GPS in `gps_service.dart` using `geolocator`
- [x] Step 2: Wire GPS into screens (camera, map) to display real coordinates
- [x] Step 3: Guard every `setState` after the async permission prompts

## IMU (G-Force) & Sensors

- [x] Step 1: Implement `ImuService` using `sensors_plus`
- [x] Step 2: Wire it into the camera screen for real-time G-Force display
- [x] Step 3: Add severity calculation based on G-Force magnitude
- [x] Step 4: Remove the never-assigned subscription and dead monitoring API

## Notifications & Alerts

- [x] Step 1: Implement `NotificationService` using
      `flutter_local_notifications`
- [x] Step 2: Configure Android channels for Pothole and Blind Spot alerts
- [x] Step 3: Trigger notifications on G-Force threshold breach
- [x] Step 4: Guard setup and posting so a denied permission does not break
      the screen

## Auth

- [x] Step 1: Register-first email/password flow with a real Firebase error map
- [x] Step 2: Google sign-in with actionable error messages
- [x] Step 3: Add a guest/demo session that needs no account
- [x] Step 4: Track the session so Home/Profile show real data, and add
      sign-out
- [x] Step 5: Apply the display name typed on the register form instead of
      discarding it

## Housekeeping

- [x] Step 1: Remove dead code and orphaned files (12 dead lib files,
      duplicate `models/*.dart`, stale build log, unused Capacitor setup)
- [x] Step 2: Fix the `pubspec.yaml` asset entry that pointed at an empty,
      untracked directory
- [x] Step 3: Stop screens presenting invented sensor values as live readings
- [x] Step 4: Wire Dark Mode to a real theme; delete the switches and rows
      that did nothing
- [x] Step 5: Remove the duplicate "Pothole" tile that opened the camera
      screen
- [x] Step 6: Add a `.markdownlint.json` and bring the docs in line with
      reality
