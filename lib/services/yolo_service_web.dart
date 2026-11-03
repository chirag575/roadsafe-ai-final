/// Browser fallback for [YoloService].
///
/// `tflite_flutter` binds to the native TensorFlow Lite runtime through
/// `dart:ffi`, and `dart:ffi` does not exist on the web. Importing it from the
/// shared code path therefore breaks `flutter build web` outright, so the web
/// build gets this stub instead (see `yolo_service.dart`).
///
/// The stub keeps the public surface identical so callers need no conditional
/// logic of their own. It never reports a loaded model, and `loadModel`
/// throws an [UnsupportedError]; `CameraScreen._initYolo` already catches that
/// and surfaces "AI model not available", so the rest of the screen - camera
/// preview, GPS, IMU, notifications - keeps working in the browser.
library;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/detection_result.dart';

class YoloService {
  static const String potholeModelAsset = 'models/pothole_model.tflite';
  static const String blindSpotModelAsset = 'models/blindspot_model.tflite';
  static const String defaultModelAsset = potholeModelAsset;

  /// Always `false` on the web: no interpreter can be created here.
  bool get isLoaded => false;

  /// Whether on-device YOLO inference is available on this platform.
  static const bool isInferenceSupported = false;

  Future<void> loadPotholeModel() => loadModel(modelAsset: potholeModelAsset);

  Future<void> loadBlindSpotModel() =>
      loadModel(modelAsset: blindSpotModelAsset);

  /// Always fails on the web.
  ///
  /// Throwing keeps the failure visible to the caller instead of silently
  /// returning zero detections, which would look like a working detector.
  Future<void> loadModel({String modelAsset = defaultModelAsset}) async {
    debugPrint(
      'YOLO model unavailable: $modelAsset cannot be loaded on the web '
      '(tflite_flutter requires dart:ffi).',
    );
    throw UnsupportedError(
      'On-device YOLO inference is not available on the web. '
      'Build for Android or iOS to run the $modelAsset model.',
    );
  }

  /// Always returns no detections; [YoloService.isLoaded] is `false` so
  /// callers are expected to skip inference entirely.
  Future<List<DetectionResult>> detect(CameraImage image) async => const [];

  Future<void> dispose() async {}
}
