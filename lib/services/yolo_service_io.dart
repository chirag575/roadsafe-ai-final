/// TFLite-backed implementation of [YoloService].
///
/// Selected on every platform that has `dart:io` (Android, iOS, desktop).
/// The web build imports `yolo_service_web.dart` instead, because
/// `tflite_flutter` is built on `dart:ffi`, which the web compiler rejects.
library;

import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/detection_result.dart';

class YoloService {
  static const String potholeModelAsset = 'models/pothole_model.tflite';
  static const String blindSpotModelAsset = 'models/blindspot_model.tflite';
  static const String defaultModelAsset = potholeModelAsset;
  static const double _confidenceThreshold = 0.25;

  /// Whether on-device YOLO inference is available on this platform.
  static const bool isInferenceSupported = true;

  Interpreter? _interpreter;
  String _activeModelAsset = defaultModelAsset;
  int _inputWidth = 640;
  int _inputHeight = 640;
  bool _inputChannelsFirst = false;
  double _inputScale = 1;
  double _paddingX = 0;
  double _paddingY = 0;
  int _sourceWidth = 1;
  int _sourceHeight = 1;
  bool _loading = false;

  bool get isLoaded => _interpreter != null;

  Future<void> loadPotholeModel() => loadModel(modelAsset: potholeModelAsset);

  Future<void> loadBlindSpotModel() =>
      loadModel(modelAsset: blindSpotModelAsset);

  Future<void> loadModel({String modelAsset = defaultModelAsset}) async {
    if (_loading) return;
    if (_interpreter != null && _activeModelAsset == modelAsset) return;

    _loading = true;
    try {
      if (_interpreter != null) {
        _interpreter!.close();
        _interpreter = null;
      }

      _interpreter = await Interpreter.fromAsset(modelAsset);
      _activeModelAsset = modelAsset;

      final shape = _interpreter!.getInputTensor(0).shape;
      if (shape.length == 4) {
        _inputChannelsFirst = shape[1] == 3;
        _inputHeight = shape[_inputChannelsFirst ? 2 : 1];
        _inputWidth = shape[_inputChannelsFirst ? 3 : 2];
      }
      debugPrint('YOLO model loaded from $modelAsset');
    } on Object catch (error) {
      debugPrint('YOLO model unavailable: $error');
      rethrow;
    } finally {
      _loading = false;
    }
  }

  Future<List<DetectionResult>> detect(CameraImage image) async {
    final interpreter = _interpreter;
    if (interpreter == null) return const [];

    if (_activeModelAsset == blindSpotModelAsset) {
      return _detectVehicles(image, interpreter);
    }

    final input = _createInput(image);
    final outputTensor = interpreter.getOutputTensor(0);
    final output = List.filled(
      outputTensor.shape.reduce((a, b) => a * b),
      0.0,
    ).reshape(outputTensor.shape);
    interpreter.run(input, output);
    return _parseOutput(output, outputTensor.shape);
  }

  /// EfficientDet Lite0 COCO export: uint8 RGB [1,320,320,3], with outputs
  /// [ymin,xmin,ymax,xmax], [scores], [classes], [count] (the order exposed
  /// by this Google metadata model).
  List<DetectionResult> _detectVehicles(
    CameraImage image,
    Interpreter interpreter,
  ) {
    final inputShape = interpreter.getInputTensor(0).shape;
    final height = inputShape[1];
    final width = inputShape[2];
    final input = List.generate(
      1,
      (_) => List.generate(
        height,
        (y) => List.generate(width, (x) {
          final sourceX = min(image.width - 1, x * image.width ~/ width);
          final sourceY = min(image.height - 1, y * image.height ~/ height);
          return _yuvToRgb(image, sourceX, sourceY);
        }),
      ),
    );
    final outputs = <int, Object>{};
    for (var index = 0;
        index < interpreter.getOutputTensors().length;
        index++) {
      final tensor = interpreter.getOutputTensor(index);
      outputs[index] = _zeroTensor(tensor.shape);
    }
    interpreter.runForMultipleInputs([input], outputs);

    final boxes = _flatten(outputs[0]!);
    final scores = _flatten(outputs[1]!);
    final classes = _flatten(outputs[2]!);
    final count = _flatten(outputs[3]!).first.round().clamp(0, 25).toInt();
    const vehicleClassIndices = {0, 2, 3, 5, 7}; // person, car, motorcycle, bus, truck
    const classNames = {
      0: 'Person',
      2: 'Car',
      3: 'Motorcycle',
      5: 'Bus',
      7: 'Truck',
    };
    final detections = <DetectionResult>[];
    for (var index = 0; index < count; index++) {
      final classIndex = classes[index].round();
      final confidence = scores[index];
      if (!vehicleClassIndices.contains(classIndex) ||
          confidence < _confidenceThreshold) {
        continue;
      }
      final offset = index * 4;
      final top = boxes[offset].clamp(0.0, 1.0).toDouble();
      final left = boxes[offset + 1].clamp(0.0, 1.0).toDouble();
      final bottom = boxes[offset + 2].clamp(0.0, 1.0).toDouble();
      final right = boxes[offset + 3].clamp(0.0, 1.0).toDouble();
      detections.add(DetectionResult(
        id: 'vehicle_${DateTime.now().microsecondsSinceEpoch}_$index',
        type: DetectionType.blindSpot,
        label: classNames[classIndex]!,
        confidence: confidence.clamp(0.0, 1.0).toDouble(),
        x: left,
        y: top,
        width: (right - left).clamp(0.0, 1.0).toDouble(),
        height: (bottom - top).clamp(0.0, 1.0).toDouble(),
        timestamp: DateTime.now(),
      ));
    }
    return detections;
  }

  Object _zeroTensor(List<int> shape) {
    if (shape.length == 1) return List<double>.filled(shape[0], 0);
    return List.generate(shape[0], (_) => _zeroTensor(shape.sublist(1)));
  }

  Object _createInput(CameraImage image) {
    if (_inputChannelsFirst) {
      _sourceWidth = image.width;
      _sourceHeight = image.height;
      _inputScale = min(
        _inputWidth / image.width,
        _inputHeight / image.height,
      );
      final resizedWidth = (image.width * _inputScale).round();
      final resizedHeight = (image.height * _inputScale).round();
      _paddingX = (_inputWidth - resizedWidth) / 2;
      _paddingY = (_inputHeight - resizedHeight) / 2;
      final channels = List.generate(
        3,
        (_) => List.generate(
          _inputHeight,
          (_) => List<double>.filled(_inputWidth, 0),
        ),
      );
      for (var y = 0; y < _inputHeight; y++) {
        for (var x = 0; x < _inputWidth; x++) {
          final resizedX = x - _paddingX;
          final resizedY = y - _paddingY;
          if (resizedX < 0 ||
              resizedY < 0 ||
              resizedX >= resizedWidth ||
              resizedY >= resizedHeight) {
            for (var channel = 0; channel < 3; channel++) {
              channels[channel][y][x] = 114 / 255.0;
            }
            continue;
          }
          final sourceX = min(
            image.width - 1,
            (resizedX / _inputScale).floor(),
          );
          final sourceY = min(
            image.height - 1,
            (resizedY / _inputScale).floor(),
          );
          final rgb = _yuvToRgb(image, sourceX, sourceY);
          for (var channel = 0; channel < 3; channel++) {
            channels[channel][y][x] = rgb[channel] / 255.0;
          }
        }
      }
      return [channels];
    }

    final pixels = List.generate(
      1,
      (_) => List.generate(
        _inputHeight,
        (y) => List.generate(
          _inputWidth,
          (x) {
            final sourceX =
                min(image.width - 1, x * image.width ~/ _inputWidth);
            final sourceY =
                min(image.height - 1, y * image.height ~/ _inputHeight);
            final rgb = _yuvToRgb(image, sourceX, sourceY);
            return <double>[
              rgb[0] / 255.0,
              rgb[1] / 255.0,
              rgb[2] / 255.0,
            ];
          },
        ),
      ),
    );
    return pixels;
  }

  List<int> _yuvToRgb(CameraImage image, int x, int y) {
    final yPlane = image.planes[0];
    final uPlane = image.planes.length > 1 ? image.planes[1] : yPlane;
    final vPlane = image.planes.length > 2 ? image.planes[2] : yPlane;
    final yValue =
        yPlane.bytes[y * yPlane.bytesPerRow + x * (yPlane.bytesPerPixel ?? 1)];
    final uvX = x ~/ 2;
    final uvY = y ~/ 2;
    final u = uPlane
        .bytes[uvY * uPlane.bytesPerRow + uvX * (uPlane.bytesPerPixel ?? 1)];
    final v = vPlane
        .bytes[uvY * vPlane.bytesPerRow + uvX * (vPlane.bytesPerPixel ?? 1)];
    final red = (yValue + 1.402 * (v - 128)).round().clamp(0, 255);
    final green = (yValue - 0.344136 * (u - 128) - 0.714136 * (v - 128))
        .round()
        .clamp(0, 255);
    final blue = (yValue + 1.772 * (u - 128)).round().clamp(0, 255);
    return [red, green, blue];
  }

  List<DetectionResult> _parseOutput(Object output, List<int> shape) {
    final values = _flatten(output);
    if (values.isEmpty) return const [];
    final channelFirst = shape.length == 3 && shape[1] <= 10;
    final candidateCount = shape.length == 3
        ? (channelFirst ? shape[2] : shape[1])
        : values.length ~/ 6;
    final channelCount =
        shape.length == 3 ? (channelFirst ? shape[1] : shape[2]) : 6;
    final detections = <DetectionResult>[];

    for (var index = 0; index < candidateCount; index++) {
      double value(int channel) {
        if (channelFirst) return values[channel * candidateCount + index];
        return values[index * channelCount + channel];
      }

      if (channelCount < 5) continue;
      final confidence = value(4);
      if (confidence < 0.92) continue; // Require 92%+ confidence for true potholes

      var x = value(0);
      var y = value(1);
      var width = value(2);
      var height = value(3);
      if (x > 1 || y > 1 || width > 1 || height > 1) {
        x /= _inputWidth;
        y /= _inputHeight;
        width /= _inputWidth;
        height /= _inputHeight;
      }
      if (_inputChannelsFirst) {
        final left = (x - width / 2) * _inputWidth;
        final top = (y - height / 2) * _inputHeight;
        width = width * _inputWidth / _inputScale / _sourceWidth;
        height = height * _inputHeight / _inputScale / _sourceHeight;
        x = (left - _paddingX) / _inputScale / _sourceWidth + width / 2;
        y = (top - _paddingY) / _inputScale / _sourceHeight + height / 2;
      }

      final boxLeft = (x - width / 2).clamp(0.0, 1.0);
      final boxTop = (y - height / 2).clamp(0.0, 1.0);
      final boxWidth = width.clamp(0.0, 1.0);
      final boxHeight = height.clamp(0.0, 1.0);

      // Strict geometric and road-surface filters (reject sky/horizon, tiny noise, or full-screen false positives)
      if (boxWidth < 0.04 || boxWidth > 0.75 || boxHeight < 0.04 || boxHeight > 0.75) continue;
      if (boxTop < 0.15) continue; // Potholes are on the road surface, not in the sky/horizon
      final aspectRatio = boxWidth / (boxHeight == 0 ? 0.001 : boxHeight);
      if (aspectRatio < 0.2 || aspectRatio > 5.0) continue;

      detections.add(
        DetectionResult(
          id: 'pothole_${DateTime.now().microsecondsSinceEpoch}_$index',
          type: DetectionType.pothole,
          label: 'Pothole',
          confidence: confidence.clamp(0.0, 1.0).toDouble(),
          x: boxLeft,
          y: boxTop,
          width: boxWidth,
          height: boxHeight,
          timestamp: DateTime.now(),
        ),
      );
    }
    return _suppressOverlaps(detections);
  }

  List<DetectionResult> _suppressOverlaps(List<DetectionResult> detections) {
    final sorted = [...detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <DetectionResult>[];
    for (final candidate in sorted) {
      final overlaps = kept.any(
        (selected) => _intersectionOverUnion(candidate, selected) > 0.45,
      );
      if (!overlaps) kept.add(candidate);
    }
    return kept;
  }

  double _intersectionOverUnion(DetectionResult a, DetectionResult b) {
    final left = max(a.x, b.x);
    final top = max(a.y, b.y);
    final right = min(a.x + a.width, b.x + b.width);
    final bottom = min(a.y + a.height, b.y + b.height);
    final intersection = max(0.0, right - left) * max(0.0, bottom - top);
    final union = a.width * a.height + b.width * b.height - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  List<double> _flatten(Object value) {
    if (value is num) return [value.toDouble()];
    if (value is List) {
      return value.expand<double>((item) => _flatten(item)).toList();
    }
    if (value is Float32List) return value.toList();
    return const [];
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }
}
