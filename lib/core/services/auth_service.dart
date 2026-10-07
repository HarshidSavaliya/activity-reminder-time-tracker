import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_keys.dart';
import '../../models/user_model.dart';
import 'storage_service.dart';

/// AuthService handles local user registration, credential authentication,
/// session persistence, and profile modifications.
class AuthService {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  AuthService(dynamic storage)
      : _storage = storage is StorageService
            ? storage
            : (storage is SharedPreferences
                ? SharedPreferencesStorageService(storage)
                : storage as StorageService);

  /// Load current active session user if exists
  UserModel? getCurrentUser() {
    final sessionUserId = _storage.getString(AppKeys.sessionUserId);
    if (sessionUserId == null) return null;

    final userJson = _storage.getString('${AppKeys.userPrefix}$sessionUserId');
    if (userJson == null) return null;

    try {
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Register a new user
  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? college,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Check if user already exists
    final existingUser = _findUserByEmail(normalizedEmail);
    if (existingUser != null) {
      throw Exception('An account with this email already exists.');
    }

    // Check if username is taken
    final existingUsername = _findUserByUsername(username.trim().toLowerCase());
    if (existingUsername != null) {
      throw Exception('This username is already taken. Please choose another.');
    }

    final newUser = UserModel(
      id: _uuid.v4(),
      name: name.trim(),
      username: username.trim(),
      email: normalizedEmail,
      password: password,
      college: college?.trim() ?? 'College of Engineering & Technology',
      createdAt: DateTime.now(),
    );

    // Save user record
    await _saveUser(newUser);

    // Set active session
    await _storage.setString(AppKeys.sessionUserId, newUser.id);

    return newUser;
  }

  /// Login with email & password
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = _findUserByEmail(normalizedEmail);

    if (user == null) {
      throw Exception('No account found with this email.');
    }

    if (user.password != password) {
      throw Exception('Incorrect password. Please verify and try again.');
    }

    // Set active session
    await _storage.setString(AppKeys.sessionUserId, user.id);
    return user;
  }

  /// Sign out current user
  Future<void> logout() async {
    await _storage.remove(AppKeys.sessionUserId);
  }

  /// Update user profile details
  Future<UserModel> updateProfile(UserModel updatedUser) async {
    await _saveUser(updatedUser);
    return updatedUser;
  }

  /// Change password
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final userJson = _storage.getString('${AppKeys.userPrefix}$userId');
    if (userJson == null) throw Exception('User not found.');

    final user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    if (user.password != currentPassword) {
      throw Exception('Current password does not match.');
    }

    final updated = user.copyWith(password: newPassword);
    await _saveUser(updated);
  }

  /// Reset password by email (Forgot Password flow)
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final user = _findUserByEmail(normalizedEmail);
    if (user == null) {
      throw Exception('No user found with the provided email.');
    }

    final updated = user.copyWith(password: newPassword);
    await _saveUser(updated);
  }

  /// Helper to save user & update index
  Future<void> _saveUser(UserModel user) async {
    // Save user object
    await _storage.setString(
      '${AppKeys.userPrefix}${user.id}',
      jsonEncode(user.toJson()),
    );

    // Update index of all registered user IDs
    final registeredIds = _storage.getStringList(AppKeys.usersList) ?? [];
    if (!registeredIds.contains(user.id)) {
      registeredIds.add(user.id);
      await _storage.setStringList(AppKeys.usersList, registeredIds);
    }
  }

  UserModel? _findUserByEmail(String email) {
    final registeredIds = _storage.getStringList(AppKeys.usersList) ?? [];
    for (final id in registeredIds) {
      final userJson = _storage.getString('${AppKeys.userPrefix}$id');
      if (userJson != null) {
        try {
          final user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
          if (user.email.toLowerCase() == email.toLowerCase()) {
            return user;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  UserModel? _findUserByUsername(String username) {
    final registeredIds = _storage.getStringList(AppKeys.usersList) ?? [];
    for (final id in registeredIds) {
      final userJson = _storage.getString('${AppKeys.userPrefix}$id');
      if (userJson != null) {
        try {
          final user = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
          if (user.username.toLowerCase() == username.toLowerCase()) {
            return user;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Seed initial demo college account if no accounts exist yet
  Future<void> seedInitialDemoUserIfNeeded() async {
    final registeredIds = _storage.getStringList(AppKeys.usersList) ?? [];
    if (registeredIds.isEmpty) {
      final demoUser = UserModel(
        id: 'demo-user-id',
        name: 'Alex Johnson',
        username: 'alex_j',
        email: 'alex@college.edu',
        password: 'Password123',
        college: 'Faculty of Computer Science & Engineering',
        studentId: 'CSE-2026-084',
        bio: '3rd Year Computer Science | AI & Systems specialization',
        avatarSeed: '1',
        createdAt: DateTime.now(),
      );
      await _saveUser(demoUser);
    }
  }
}
