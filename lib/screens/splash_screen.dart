import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Re-establish a Firebase session while the splash is on screen. Firebase
    // keeps an account signed in across launches, so a returning user should
    // not be sent back to the login form. This is a no-op when Firebase is
    // not configured, and never clears an existing guest session.
    unawaited(AuthService.restoreSession());

    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      final nextRoute = AuthService.isSignedIn ? "/home" : "/login";
      Navigator.pushReplacementNamed(context, nextRoute);
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user,
              size: 120,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              "RoadSafe AI",
              style: TextStyle(
                fontSize: 34,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Blind Spot & Pothole Detection",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            const SizedBox(height: 60),
            const Text(
              "Powered by Flutter • Firebase",
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
