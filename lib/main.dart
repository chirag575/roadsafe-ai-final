import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/app_settings.dart';
import 'services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandling();

  // Do not keep the native launch window visible while Firebase starts. Some
  // Android builds without google-services.json fail asynchronously here.
  runApp(const RoadSafeAI());
  unawaited(AppSettings.initialize());
  unawaited(FirebaseBootstrap.ready);
}

/// Keeps a failed build or an uncaught async error from leaving the user
/// staring at a blank white window.
///
/// A release build renders an unhandled error as an empty frame, which is
/// indistinguishable from a hang. Surfacing the failure in-app makes any
/// future regression obvious instead of silent.
void _installErrorHandling() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFFDE7E9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Color(0xFFB3261E),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB3261E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Errors that escape the widget tree, e.g. a rejected Future in main().
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  };
}
