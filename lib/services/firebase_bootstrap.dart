import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Starts Firebase once and lets Firebase-backed actions wait for it.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static final Future<void> ready = _initialize();

  static Future<void> _initialize() async {
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase initialized successfully');
    } on FirebaseException catch (error) {
      debugPrint(
        'Firebase initialization failed (${error.code}): ${error.message}',
      );
    } catch (error, stackTrace) {
      debugPrint('Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
