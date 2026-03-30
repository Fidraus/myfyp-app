import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _keyUserId    = 'user_id';
  static const _keyUserName  = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyAvatarPath = 'avatar_path';

  static Future<void> saveSession({
    required int userId,
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  static Future<String?> getAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAvatarPath);
  }

  static Future<void> saveAvatarPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarPath, path);
  }

  static Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyUserId);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyAvatarPath);
  }
}
