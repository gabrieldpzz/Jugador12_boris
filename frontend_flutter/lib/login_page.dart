// lib/login_page.dart
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'otp_page.dart';
import 'register_page.dart';
import 'main.dart'; // para currentUserEmail

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;

    if (email.isEmpty) {
      setState(() => error = 'Ingresa tu email');
      return;
    }
    if (pass.isEmpty) {
      setState(() => error = 'Ingresa tu contraseña');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Login -> envía OTP por correo y devuelve otpToken
      final otpToken = await AuthService.login(
        email: email,
        password: pass,
      );

      // Guarda el email para mostrarlo en Perfil
      currentUserEmail = email;

      if (!mounted) return;

      // Navega a OTP. Si OTP OK, regresa true a quien abrió el Login.
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => OtpPage(otpToken: otpToken)),
      );

      if (ok == true && mounted) {
        Navigator.pop(context, true); // volvemos con éxito
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Entrar'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
              child: const Text('¿No tienes cuenta? Regístrate'),
            ),
          ],
        ),
      ),
    );
  }
}
