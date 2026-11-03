import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsafe_ai/screens/home_screen.dart';
import 'package:roadsafe_ai/screens/login_screen.dart';
import 'package:roadsafe_ai/services/auth_service.dart';
import 'package:roadsafe_ai/utils/routes.dart';

void main() {
  // The session is app-global static state, so each test starts from a known
  // signed-out state.
  setUp(() => AuthService.session.value = null);
  tearDown(() => AuthService.session.value = null);

  group('Guest session', () {
    test('signInAsGuest creates a session with no account details', () {
      AuthService.signInAsGuest();

      final session = AuthService.currentSession;
      expect(session, isNotNull);
      expect(session!.mode, AuthMode.guest);
      expect(session.isGuest, isTrue);
      expect(AuthService.isSignedIn, isTrue);
      expect(AuthService.isGuest, isTrue);
    });

    test('a guest session claims no email, phone or display name', () {
      AuthService.signInAsGuest();

      final session = AuthService.currentSession!;
      expect(session.email, isNull);
      expect(session.phoneNumber, isNull);
      expect(session.displayName, isNull);
    });

    test('a guest session is labelled Guest and marked as demo mode', () {
      AuthService.signInAsGuest();

      final session = AuthService.currentSession!;
      expect(session.label, 'Guest');
      expect(session.subtitle, contains('Demo mode'));
    });

    test('nobody is signed in before guest sign-in', () {
      expect(AuthService.isSignedIn, isFalse);
      expect(AuthService.isGuest, isFalse);
      expect(AuthService.currentSession, isNull);
    });

    test('signOut clears a guest session without touching Firebase', () async {
      AuthService.signInAsGuest();

      // No Firebase app is configured in the test environment. If signOut
      // tried to reach FirebaseAuth it would throw, so completing here proves
      // the guest path short-circuits.
      await AuthService.signOut();

      expect(AuthService.currentSession, isNull);
      expect(AuthService.isSignedIn, isFalse);
      expect(AuthService.isGuest, isFalse);
    });
  });

  group('Firebase session labels', () {
    test('prefers the display name and uses the email as the subtitle', () {
      AuthService.session.value = const AppSession(
        mode: AuthMode.firebase,
        displayName: 'Asha',
        email: 'asha@example.com',
      );

      final session = AuthService.currentSession!;
      expect(session.isGuest, isFalse);
      expect(session.label, 'Asha');
      expect(session.subtitle, 'asha@example.com');
    });

    test('falls back to the email when Firebase has no display name', () {
      AuthService.session.value = const AppSession(
        mode: AuthMode.firebase,
        email: 'nameless@example.com',
      );

      expect(AuthService.currentSession!.label, 'nameless@example.com');
    });

    test('ignores a blank display name rather than rendering empty', () {
      AuthService.session.value = const AppSession(
        mode: AuthMode.firebase,
        displayName: '   ',
        email: 'blank@example.com',
      );

      expect(AuthService.currentSession!.label, 'blank@example.com');
    });

    test('a Firebase session is never reported as a guest', () {
      AuthService.session.value = const AppSession(mode: AuthMode.firebase);

      expect(AuthService.isGuest, isFalse);
      expect(AuthService.isSignedIn, isTrue);
    });
  });

  group('Guest login button', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          // Start on the login screen directly: the splash delay is already
          // covered by widget_test.dart.
          initialRoute: AppRoutes.login,
          routes: AppRoutes.routes,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is offered on the login screen', (tester) async {
      await pumpLogin(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.text('Continue as Guest (Demo Mode)'),
        findsOneWidget,
      );
    });

    testWidgets('enters the app and opens Home with no credentials typed',
        (tester) async {
      await pumpLogin(tester);

      final guestButton = find.text('Continue as Guest (Demo Mode)');
      // The login column is long enough that the guest button sits below the
      // fold in the test viewport, so scroll it into view before tapping.
      await tester.ensureVisible(guestButton);
      await tester.pumpAndSettle();

      await tester.tap(guestButton);
      await tester.pumpAndSettle();

      // A guest session exists purely from the tap - no email or password
      // field was touched.
      expect(AuthService.isSignedIn, isTrue);
      expect(AuthService.isGuest, isTrue);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
