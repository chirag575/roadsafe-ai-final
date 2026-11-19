import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_bootstrap.dart';

/// How the active session was established.
enum AuthMode {
  /// A real Firebase account (email/password or Google).
  firebase,

  /// A local demo session created without any account.
  guest,
}

/// Who the app currently believes is using it.
///
/// The app previously never read `FirebaseAuth.currentUser`; the screens
/// showed hardcoded placeholder details instead. This object is the single
/// source of truth so every screen can render real data, and a guest session
/// can render honest "not signed in" values.
class AppSession {
  const AppSession({
    required this.mode,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.photoUrl,
  });

  final AuthMode mode;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? photoUrl;

  /// True when no real account backs this session.
  bool get isGuest => mode == AuthMode.guest;

  /// Primary name to show in the UI.
  String get label {
    if (isGuest) return 'Guest';
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email ?? 'RoadSafe User';
  }

  /// Secondary line for the drawer header and profile screen.
  String get subtitle {
    if (isGuest) return 'Demo mode - not signed in';
    return email ?? 'Signed in';
  }
}

class AuthService {
  /// The active session, or `null` when nobody is signed in.
  ///
  /// Exposed as a [ValueNotifier] so screens can rebuild when the session
  /// changes without pulling in a state-management package.
  static final ValueNotifier<AppSession?> session = ValueNotifier<AppSession?>(
    null,
  );

  static AppSession? get currentSession => session.value;

  static bool get isSignedIn => session.value != null;

  static bool get isGuest => session.value?.isGuest ?? false;

  /// Enters the app without an account, for demos and for devices with no
  /// Firebase configuration.
  ///
  /// Nothing is persisted: the session lives for this run only, so a guest
  /// never inherits another guest's data.
  static void signInAsGuest() {
    session.value = const AppSession(mode: AuthMode.guest);
  }

  /// Clears the session and, for a real account, ends the Firebase session.
  static Future<void> signOut() async {
    final wasFirebaseSession = session.value?.mode == AuthMode.firebase;
    session.value = null;

    if (!wasFirebaseSession || Firebase.apps.isEmpty) return;

    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (error) {
      // The local session is already cleared, so a failure here must not
      // leave the user stuck on a screen they have left.
      debugPrint(
        'Firebase sign-out failed (${error.code}): ${error.message}',
      );
    }
  }

  /// Re-establishes a Firebase session after an app restart.
  ///
  /// Firebase keeps the user signed in across launches, so without this the
  /// splash screen would ask a signed-in user to log in again.
  static Future<void> restoreSession() async {
    await FirebaseBootstrap.ready;
    if (session.value != null || Firebase.apps.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    session.value = AppSession(
      mode: AuthMode.firebase,
      displayName: user.displayName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
    );
  }

  /// Records the account behind a successful Firebase credential exchange.
  static void _setFirebaseSession(UserCredential credential) {
    final user = credential.user;
    session.value = AppSession(
      mode: AuthMode.firebase,
      displayName: user?.displayName,
      email: user?.email,
      phoneNumber: user?.phoneNumber,
      photoUrl: user?.photoURL,
    );
  }

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
    await FirebaseBootstrap.ready;
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

    final credential = await _auth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: trimmedPassword,
    );
    _setFirebaseSession(credential);
    return credential;
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseBootstrap.ready;
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      throw const AuthException('Please enter your email address first.');
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }

    await _auth.sendPasswordResetEmail(email: trimmedEmail);
  }

  /// Creates an account and records the session.
  ///
  /// [displayName] is applied with `updateDisplayName` when supplied, so the
  /// value typed on the register form is not silently discarded. Phone numbers
  /// are deliberately not collected: Firebase requires verified numbers, so
  /// storing an unverified one would be misleading.
  static Future<UserCredential> createAccount(
    String email,
    String password, {
    String? displayName,
  }) async {
    await FirebaseBootstrap.ready;
    final trimmedEmail = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Please enter your password.');
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    _setFirebaseSession(credential);

    final name = displayName?.trim();
    final user = credential.user;
    if (name != null && name.isNotEmpty && user != null) {
      try {
        await user.updateDisplayName(name);
        // Re-read the user so the session carries the new display name.
        _setFirebaseSession(credential);
      } on FirebaseAuthException catch (error) {
        // The account exists either way, so surface the reason but do not
        // fail the registration.
        debugPrint(
          'Could not set display name (${error.code}): ${error.message}',
        );
      }
    }

    return credential;
  }

  /// Signs in with a Google account and exchanges the result for a Firebase
  /// session.
  ///
  /// The Firebase configuration is resolved *before* the account chooser is
  /// shown, so a missing configuration fails fast instead of letting the user
  /// pick an account and only then failing.
  static Future<UserCredential> signInWithGoogle() async {
    await FirebaseBootstrap.ready;
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
      final userCredential = await auth.signInWithCredential(credential);
      _setFirebaseSession(userCredential);
      return userCredential;
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
