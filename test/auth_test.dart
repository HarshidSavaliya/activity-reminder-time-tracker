import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:activity_reminder_tracker/core/services/auth_service.dart';
import 'package:activity_reminder_tracker/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late AuthService authService;
  late AuthController authController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    authService = AuthService(prefs);
    authController = AuthController(authService);
  });

  group('Authentication Unit Tests', () {
    test('1. Initial state has no authenticated user', () {
      expect(authController.isAuthenticated, isFalse);
      expect(authController.currentUser, isNull);
    });

    test('2. Successful user registration', () async {
      final success = await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
        college: 'Faculty of CS',
      );

      expect(success, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentUser?.email, 'alex@college.edu');
      expect(authController.currentUser?.name, 'Alex Johnson');
      expect(authController.currentUser?.username, 'alex_j');
    });

    test('3. Prevents duplicate email registration', () async {
      await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      final secondRegister = await authController.register(
        name: 'Another Alex',
        username: 'another_alex',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      expect(secondRegister, isFalse);
      expect(authController.errorMessage, contains('email already exists'));
    });

    test('4. Prevents duplicate username registration', () async {
      await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      final secondRegister = await authController.register(
        name: 'Another Alex',
        username: 'alex_j',
        email: 'different@college.edu',
        password: 'Password123',
      );

      expect(secondRegister, isFalse);
      expect(authController.errorMessage, contains('username is already taken'));
    });

    test('5. Valid login with correct credentials', () async {
      await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      // Sign out first
      await authController.logout();
      expect(authController.isAuthenticated, isFalse);

      // Sign back in
      final loginSuccess = await authController.login(
        email: 'alex@college.edu',
        password: 'Password123',
      );

      expect(loginSuccess, isTrue);
      expect(authController.isAuthenticated, isTrue);
      expect(authController.currentUser?.name, 'Alex Johnson');
    });

    test('6. Invalid login with incorrect password', () async {
      await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      await authController.logout();

      final loginSuccess = await authController.login(
        email: 'alex@college.edu',
        password: 'WrongPassword999',
      );

      expect(loginSuccess, isFalse);
      expect(authController.isAuthenticated, isFalse);
      expect(authController.errorMessage, contains('Incorrect password'));
    });

    test('7. Invalid login with non-existent email', () async {
      final loginSuccess = await authController.login(
        email: 'unknown@college.edu',
        password: 'Password123',
      );

      expect(loginSuccess, isFalse);
      expect(authController.errorMessage, contains('No account found'));
    });

    test('8. Logout clears active session', () async {
      await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      expect(authController.isAuthenticated, isTrue);
      await authController.logout();

      expect(authController.isAuthenticated, isFalse);
      expect(authController.currentUser, isNull);
    });

    test('9. Profile editing updates user details', () async {
      await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      final current = authController.currentUser!;
      final updated = current.copyWith(
        name: 'Alexander Johnson PhD',
        bio: 'Updated bio information',
        studentId: 'CSE-999',
      );

      final updateSuccess = await authController.updateProfile(updated);
      expect(updateSuccess, isTrue);
      expect(authController.currentUser?.name, 'Alexander Johnson PhD');
      expect(authController.currentUser?.bio, 'Updated bio information');
      expect(authController.currentUser?.studentId, 'CSE-999');
    });

    test('10. Change password verification and update', () async {
      await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      // Wrong old password fails
      final wrongOld = await authController.changePassword(
        currentPassword: 'WrongOldPassword',
        newPassword: 'NewPassword456',
      );
      expect(wrongOld, isFalse);

      // Correct old password succeeds
      final correctChange = await authController.changePassword(
        currentPassword: 'Password123',
        newPassword: 'NewPassword456',
      );
      expect(correctChange, isTrue);

      // Can now login with new password
      await authController.logout();
      final newLogin = await authController.login(
        email: 'alex@college.edu',
        password: 'NewPassword456',
      );
      expect(newLogin, isTrue);
    });

    test('11. Password reset flow (Forgot Password)', () async {
      await authController.register(
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
      );

      await authController.logout();

      final resetSuccess = await authController.resetPassword(
        email: 'alex@college.edu',
        newPassword: 'ResetPassword789',
      );
      expect(resetSuccess, isTrue);

      final loginWithReset = await authController.login(
        email: 'alex@college.edu',
        password: 'ResetPassword789',
      );
      expect(loginWithReset, isTrue);
    });
  });
}
