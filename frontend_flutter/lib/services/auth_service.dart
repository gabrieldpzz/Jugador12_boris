// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cambia esto si prefieres centralizar en lib/config.dart
const String kAuthBase = 'http://192.168.1.5:8001';

class AuthService {
  static Uri _u(String path) => Uri.parse('$kAuthBase$path');

  /// REGISTRO
  /// return: true si ok; lanza Exception con el mensaje del server si falla
  static Future<bool> register({
    required String email,
    required String password,
  }) async {
    final res = await http
        .post(
          _u('/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) return true;

    try {
      final m = jsonDecode(res.body);
      throw Exception(m is Map && m['detail'] != null ? m['detail'].toString() : res.body);
    } catch (_) {
      throw Exception('Registro falló (${res.statusCode}): ${res.body}');
    }
  }

  /// LOGIN (envía OTP por correo)
  /// return: otpToken (string) para usar en verifyOtp
  static Future<String> login({
    required String email,
    required String password,
  }) async {
    final res = await http
        .post(
          _u('/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final otpToken = (data['otp_token'] as String?) ?? '';
      if (otpToken.isEmpty) {
        throw Exception('Respuesta inválida: falta otp_token');
      }
      return otpToken;
    }

    try {
      final m = jsonDecode(res.body);
      throw Exception(m is Map && m['detail'] != null ? m['detail'].toString() : res.body);
    } catch (_) {
      throw Exception('Login falló (${res.statusCode}): ${res.body}');
    }
  }

  /// VERIFICAR OTP
  /// return: jwt token (string)
  static Future<String> verifyOtp({
    required String otpToken,
    required String code,
  }) async {
    final res = await http
        .post(
          _u('/auth/verify-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'otp_token': otpToken, 'code': code}),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = (data['token'] as String?) ?? '';
      if (token.isEmpty) {
        throw Exception('Respuesta inválida: falta token');
      }
      return token;
    }

    try {
      final m = jsonDecode(res.body);
      throw Exception(m is Map && m['detail'] != null ? m['detail'].toString() : res.body);
    } catch (_) {
      throw Exception('Verificación OTP falló (${res.statusCode}): ${res.body}');
    }
  }
}
