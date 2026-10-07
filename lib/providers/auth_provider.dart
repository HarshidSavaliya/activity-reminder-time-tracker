import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../models/user_model.dart';

/// AuthProvider coordinates authentication state across the app.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authService) {
    _init();
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _init() {
    _currentUser = _authService.getCurrentUser();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.login(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? college,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.register(
        name: name,
        username: username,
        email: email,
        password: password,
        college: college,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile(UserModel updatedUser) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.updateProfile(updatedUser);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    String? currentPassword,
    String? oldPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    final effectiveCurrent = currentPassword ?? oldPassword ?? '';

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.changePassword(
        userId: _currentUser!.id,
        currentPassword: effectiveCurrent,
        newPassword: newPassword,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email: email, newPassword: newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

/// Backwards compatibility alias
typedef AuthController = AuthProvider;
