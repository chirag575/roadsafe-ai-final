import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  /// Scopes requested from Google. `email` is what Firebase maps onto the
  /// Firebase user account, `profile` provides the display name and photo.
  static const List<String> _googleScopes = <String>['email', 'profile'];

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _googleScopes,
  );

  /// Resolves FirebaseAuth lazily and reports a readable [AuthException] when
  /// the local Firebase configuration is missing.
  ///
  /// Reading `FirebaseAuth.instance` before `Firebase.initializeApp()` has
  /// completed throws a `core/no-app` FirebaseException, which is opaque to
  /// the user.
  static FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw const AuthException(
        'Firebase is not configured. Add the Firebase Android configuration '
        'and try again.',
      );
    }

    return FirebaseAuth.instance;
  }

  static Future<UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    if (trimmedEmail.isEmpty) {
      throw const AuthException('Please enter your Gmail/email.');
    }

    if (trimmedPassword.isEmpty) {
      throw const AuthException('Please enter your password.');
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }

    return _auth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: trimmedPassword,
    );
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      throw const AuthException('Please enter your email address first.');
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }

    await _auth.sendPasswordResetEmail(email: trimmedEmail);
  }

  static Future<UserCredential> createAccount(
    String email,
    String password,
  ) async {
    final trimmedEmail = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Please enter your password.');
    }
    return _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
  }

  /// Signs in with a Google account and exchanges the result for a Firebase
  /// session.
  ///
  /// The Firebase configuration is resolved *before* the account chooser is
  /// shown, so a missing configuration fails fast instead of letting the user
  /// pick an account and only then failing.
  static Future<UserCredential> signInWithGoogle() async {
    final auth = _auth;

    final GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } on PlatformException catch (error) {
      throw AuthException(getGoogleErrorMessage(error.code));
    }

    // A null account means the user dismissed the chooser without picking.
    if (account == null) {
      throw const AuthException('Google sign-in was cancelled.');
    }

    final GoogleSignInAuthentication tokens;
    try {
      tokens = await account.authentication;
    } on PlatformException catch (error) {
      throw AuthException(getGoogleErrorMessage(error.code));
    }

    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        'Google did not return an ID token. Please try again.',
      );
    }

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: tokens.accessToken,
    );

    try {
      return await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthException(
        getFriendlyMessage(error.code, message: error.message),
      );
    }
  }

  /// Translates a Google Sign-In failure into guidance the user can act on.
  ///
  /// The codes come from `google_sign_in_android`, which reports Google Play
  /// Services status codes as the generic `status` / `exception` reasons.
  static String getGoogleErrorMessage(String? code) {
    switch (code) {
      case 'sign_in_canceled':
      case GoogleSignInAccount.kUserRecoverableAuthError:
        return 'Google sign-in was cancelled.';
      case 'sign_in_required':
        return 'Google sign-in is required. Please try again.';
      case 'network_error':
        return 'Network error. Please check your internet connection.';
      case 'sign_in_failed':
        return 'Google sign-in failed. Please try again.';
      case GoogleSignInAccount.kFailedToRecoverAuthError:
        return 'Google sign-in could not be completed. Please try again.';
      case 'status':
      case 'exception':
        return "Google sign-in failed. Make sure Google Play Services is up "
            "to date and that this app's SHA-1 fingerprint is registered in "
            "the Firebase console, then reinstall the app.";
      default:
        return 'Google sign-in failed. Please try again.';
    }
  }

  static String getFriendlyMessage(String? code, {String? message}) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'email-not-found':
        return 'No account found for this email. Tap "Create Account" below '
            'to register first.';
      case 'account-exists-with-different-credential':
        return 'An account already exists for this email using a different '
            'sign-in method. Try signing in with that method instead.';
      case 'wrong-password':
        return 'Incorrect password. Please check your password and try again.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Email or password is incorrect. If you have not registered '
            'yet, tap "Create Account" first.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'expired-action-code':
        return 'This password reset link has expired. Request a new one.';
      case 'invalid-action-code':
        return 'This password reset link is invalid. Request a new one.';
      case 'missing-email':
        return 'Please enter your email address.';
      case 'app-not-authorized':
        return 'This app is not authorized for the Firebase project.';
      case 'no-app':
      case 'core/no-app':
        return 'Firebase is not configured. Add the Firebase Android configuration and try again.';
      default:
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
        return 'Firebase authentication failed ($code). Please try again.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
