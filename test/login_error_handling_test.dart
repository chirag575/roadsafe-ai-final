import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_ai/services/auth_service.dart';

void main() {
  group('Firebase auth message mapping', () {
    test('maps wrong password error to user-friendly message', () {
      expect(
        AuthService.getFriendlyMessage('wrong-password'),
        'Incorrect password. Please check your password and try again.',
      );
    });

    test('maps unregistered user to register-first guidance', () {
      expect(
        AuthService.getFriendlyMessage('user-not-found'),
        'No account found for this email. Tap "Create Account" below '
        'to register first.',
      );
    });

    test('maps invalid email to valid email guidance', () {
      expect(
        AuthService.getFriendlyMessage('invalid-email'),
        'Please enter a valid email address.',
      );
    });

    test('tells the user to register for the generic invalid-credential code',
        () {
      expect(
        AuthService.getFriendlyMessage('invalid-credential'),
        contains('Create Account'),
      );
      expect(
        AuthService.getFriendlyMessage('INVALID_LOGIN_CREDENTIALS'),
        contains('Create Account'),
      );
    });

    test('distinguishes a credential collision from a missing account', () {
      expect(
        AuthService.getFriendlyMessage(
            'account-exists-with-different-credential'),
        contains('different sign-in method'),
      );
    });

    test('reports a missing Firebase configuration', () {
      expect(
        AuthService.getFriendlyMessage('no-app'),
        contains('Firebase is not configured'),
      );
    });
  });

  group('Google sign-in message mapping', () {
    test('reports a cancelled Google sign-in', () {
      expect(
        AuthService.getGoogleErrorMessage('sign_in_canceled'),
        'Google sign-in was cancelled.',
      );
    });

    test('explains how to fix a Play Services or SHA-1 problem', () {
      expect(
        AuthService.getGoogleErrorMessage('status'),
        contains('SHA-1'),
      );
    });

    test('suggests checking the connection on a network error', () {
      expect(
        AuthService.getGoogleErrorMessage('network_error'),
        contains('internet connection'),
      );
    });

    test('falls back to a retry message for other failures', () {
      expect(
        AuthService.getGoogleErrorMessage('sign_in_failed'),
        'Google sign-in failed. Please try again.',
      );
      expect(
        AuthService.getGoogleErrorMessage('something_unknown'),
        'Google sign-in failed. Please try again.',
      );
    });
  });
}
