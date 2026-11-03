/// Platform-dispatched entry point for the YOLO pothole detector.
///
/// The concrete implementation is chosen at compile time:
///
/// * `yolo_service_io.dart`  - real TensorFlow Lite inference (Android, iOS,
///   desktop). It pulls in `tflite_flutter`, which needs `dart:ffi`.
/// * `yolo_service_web.dart` - a stub, because the web compiler has no
///   `dart:ffi` and `dart2js` fails hard on `package:tflite_flutter`.
///
/// Both expose the same `YoloService` API, so `camera_screen.dart` can import
/// this file unconditionally.
library;

export 'yolo_service_web.dart' if (dart.library.io) 'yolo_service_io.dart';
