import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ImuData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const ImuData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  double get totalAcceleration {
    return sqrt(
      (x * x) + (y * y) + (z * z),
    );
  }

  double get gForce {
    // Standard gravity ≈ 9.81 m/s²
    return totalAcceleration / 9.81;
  }
}

class ImuService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Marks the service ready.
  ///
  /// The accelerometer plugin needs no explicit start-up call, so this only
  /// records state; stream errors surface from [getImuStream] instead.
  Future<void> initialize() async {
    _isInitialized = true;
    debugPrint('IMU initialized');
  }

  /// Accelerometer readings, converted to [ImuData].
  ///
  /// The caller owns the subscription and must cancel it - see
  /// `CameraScreen.dispose`.
  Stream<ImuData> getImuStream() {
    return accelerometerEventStream().map((event) => ImuData(
          x: event.x,
          y: event.y,
          z: event.z,
          timestamp: DateTime.now(),
        ));
  }

  /// Buckets a G-force reading into a severity label.
  String calculateSeverity(double gForce) {
    if (gForce >= 3.5) {
      return 'High';
    }
    if (gForce >= 2.5) {
      return 'Medium';
    }
    if (gForce >= 1.5) {
      return 'Low';
    }
    return 'Normal';
  }

  Future<void> dispose() async {
    _isInitialized = false;
    debugPrint('IMU disposed');
  }
}
