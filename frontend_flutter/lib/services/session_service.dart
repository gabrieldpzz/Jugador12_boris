// lib/services/session_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SessionService {
  static const _kToken = 'auth_token';
  static const _kEmail = 'auth_email';

  static final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
  static String? email;
  static String? token;

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    token = _prefs!.getString(_kToken);
    email = _prefs!.getString(_kEmail);
    isLoggedIn.value = token != null && token!.isNotEmpty;
  }

  static Future<void> saveSession({
    required String emailValue,
    required String tokenValue,
  }) async {
    email = emailValue;
    token = tokenValue;
    isLoggedIn.value = true;
    await _prefs?.setString(_kEmail, emailValue);
    await _prefs?.setString(_kToken, tokenValue);
  }

  static Future<void> clear() async {
    email = null;
    token = null;
    isLoggedIn.value = false;
    await _prefs?.remove(_kEmail);
    await _prefs?.remove(_kToken);
  }
}
