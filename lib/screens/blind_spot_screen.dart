import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import '../services/notification_service.dart';
import '../services/yolo_service.dart';

/// A detection produced by the explicit simulation button.
///
/// Values from the explicit simulation control are kept separate from live
/// vehicle detections so sample values cannot be mistaken for measured data.
class _SimulatedDetection {
  const _SimulatedDetection({
    required this.side,
    required this.distance,
    required this.ttc,
  });

  final String side;
  final double distance;
  final double ttc;
}

class BlindSpotScreen extends StatefulWidget {
  const BlindSpotScreen({super.key});

  @override
  State<BlindSpotScreen> createState() => _BlindSpotScreenState();
}

class _BlindSpotScreenState extends State<BlindSpotScreen>
    with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final YoloService _yoloService = YoloService();

  bool _checkingModel = true;
  bool _modelReady = false;
  String _modelStatus = 'Loading detection model...';

  _SimulatedDetection? _simulated;
  CameraController? _cameraController;
  String _cameraStatus = 'Starting camera...';
  List<DetectionResult> _vehicleDetections = const [];
  bool _processingFrame = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
    unawaited(_initialize());
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera found');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _cameraController = controller;
      await controller.initialize();
      await controller.startImageStream(_onCameraImage);
      if (!mounted) return;
      setState(() => _cameraStatus = 'Camera preview active');
    } catch (error) {
      debugPrint('Blind spot camera unavailable: $error');
      if (mounted) setState(() => _cameraStatus = 'Camera unavailable');
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (_processingFrame || !_modelReady || !_yoloService.isLoaded) return;
    _processingFrame = true;
    try {
      final results = await _yoloService.detect(image);
      if (!mounted) return;
      setState(() => _vehicleDetections = results);
    } catch (error) {
      debugPrint('Vehicle detection frame failed: $error');
    } finally {
      _processingFrame = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      _cameraController = null;
      if (mounted) setState(() => _cameraStatus = 'Camera paused');
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initialize() async {
    // Notification permission can be denied or unsupported; that must not stop
    // the screen from rendering.
    try {
      await _notificationService.initialize();
    } catch (error) {
      debugPrint('Notification setup unavailable: $error');
    }

    String status;
    var ready = false;
    try {
      await _yoloService.loadBlindSpotModel();
      ready = _yoloService.isLoaded;
      status = ready
          ? 'Detection model loaded'
          : 'Detection model could not be loaded';
    } catch (error) {
      debugPrint('Blind spot model unavailable: $error');
      status = 'AI model not available';
    }

    if (!mounted) return;
    setState(() {
      _modelReady = ready;
      _modelStatus = status;
      _checkingModel = false;
    });
  }

  /// Fires a real notification, but from clearly labelled sample values.
  Future<void> _simulateDetection() async {
    const sample = _SimulatedDetection(
      side: 'Left',
      distance: 3.2,
      ttc: 1.5,
    );

    try {
      await _notificationService.showBlindSpotAlert(
        side: sample.side,
        distance: sample.distance,
        ttc: sample.ttc,
      );
    } catch (error) {
      debugPrint('Could not post blind spot notification: $error');
    }

    if (!mounted) return;
    setState(() => _simulated = sample);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Simulated alert fired. These values are sample data, '
            'not a real detection.',
          ),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _yoloService.dispose();
    _notificationService.dispose();
    super.dispose();
  }

  /// A metric cell. Shows a value only when one genuinely exists.
  Widget _metric({
    required IconData icon,
    required String label,
    required String? value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value ?? 'No detection'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final simulated = _simulated;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Blind Spot Detection"),
        centerTitle: true,
      ),

      // Scrollable. The previous fixed Column overflowed by ~270px on a
      // 600px-tall viewport, which also breaks on short phones and at large
      // system text scales.
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // CAMERA PREVIEW
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: _cameraController?.value.isInitialized == true
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        if (_vehicleDetections.isNotEmpty)
                          CustomPaint(
                            painter: _VehicleOverlayPainter(_vehicleDetections),
                          ),
                      ],
                    )
                  : ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt,
                                color: Colors.white, size: 64),
                            const SizedBox(height: 8),
                            Text(_cameraStatus,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 15),

          // Status banner. Never claims a detection is running when the
          // model could not be loaded.
          Card(
            color: _modelReady ? Colors.green.shade50 : Colors.amber.shade50,
            child: ListTile(
              leading: Icon(
                _modelReady ? Icons.check_circle : Icons.info_outline,
                color: _modelReady ? Colors.green : Colors.amber.shade800,
              ),
              title: Text(_checkingModel
                  ? 'Checking detection model...'
                  : _modelReady
                      ? 'Live vehicle detection active'
                      : _modelStatus),
              subtitle: Text(
                _modelReady
                    ? 'Vehicle classes come from a general COCO model. '
                        'Side of frame is shown; distance and collision '
                        'time are not measured.'
                    : 'Camera preview: $_cameraStatus. Nothing is being '
                        'detected until a valid model is available.',
              ),
            ),
          ),

          const SizedBox(height: 15),

          _metric(
            icon: Icons.warning,
            label: "Status",
            value: simulated != null
                ? 'Simulated vehicle in ${simulated.side} blind spot'
                : _vehicleDetections.isEmpty
                    ? null
                    : 'Vehicle on ${_frameSide(_vehicleDetections.first)} '
                        'side of frame',
          ),

          const SizedBox(height: 10),

          _metric(
            icon: Icons.two_wheeler,
            label: "Vehicle",
            value: simulated != null
                ? 'Motorcycle (simulated)'
                : _vehicleDetections.isEmpty
                    ? null
                    : _vehicleDetections.first.label,
          ),

          const SizedBox(height: 10),

          _metric(
            icon: Icons.straighten,
            label: "Distance",
            value: simulated != null
                ? '${simulated.distance.toStringAsFixed(1)} m (simulated)'
                : _vehicleDetections.isNotEmpty
                    ? 'Not measured by this model'
                    : null,
          ),

          const SizedBox(height: 10),

          _metric(
            icon: Icons.timer,
            label: "TTC",
            value: simulated != null
                ? '${simulated.ttc.toStringAsFixed(1)} s (simulated)'
                : _vehicleDetections.isNotEmpty
                    ? 'Not measured by this model'
                    : null,
          ),

          const SizedBox(height: 20),

          // SIMULATE BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _simulateDetection,
              icon: const Icon(Icons.bug_report),
              label: const Text("Simulate Detection (sample data)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ALERT BUTTON - disabled until there is something to alert on.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: simulated == null
                  ? null
                  : () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              'Alert re-armed for the simulated '
                              '${simulated.side} detection.',
                            ),
                          ),
                        );
                    },
              icon: const Icon(Icons.notifications_active),
              label: const Text("Activate Alert"),
            ),
          ),
        ],
      ),
    );
  }

  String _frameSide(DetectionResult detection) {
    final center = detection.x + detection.width / 2;
    if (center < 0.4) return 'left';
    if (center > 0.6) return 'right';
    return 'center';
  }
}

class _VehicleOverlayPainter extends CustomPainter {
  const _VehicleOverlayPainter(this.detections);

  final List<DetectionResult> detections;

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final labelPaint = Paint()..color = Colors.black.withOpacity(0.7);
    for (final detection in detections) {
      final rect = Rect.fromLTWH(
        detection.x * size.width,
        detection.y * size.height,
        detection.width * size.width,
        detection.height * size.height,
      );
      canvas.drawRect(rect, boxPaint);
      final text = TextPainter(
        text: TextSpan(
          text:
              '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      final labelRect = Rect.fromLTWH(
        rect.left,
        (rect.top - text.height - 4).clamp(0.0, size.height).toDouble(),
        text.width + 8,
        text.height + 4,
      );
      canvas.drawRect(labelRect, labelPaint);
      text.paint(canvas, Offset(labelRect.left + 4, labelRect.top + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _VehicleOverlayPainter oldDelegate) =>
      oldDelegate.detections != detections;
}
