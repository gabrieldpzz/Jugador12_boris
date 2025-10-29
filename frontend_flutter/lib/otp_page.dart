// lib/otp_page.dart
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/session_service.dart';
import 'main.dart'; // para currentUserEmail / compat

class OtpPage extends StatefulWidget {
  final String otpToken;
  const OtpPage({super.key, required this.otpToken});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final codeCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => error = 'Ingresa el código que te enviamos');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final jwt = await AuthService.verifyOtp(
        otpToken: widget.otpToken,
        code: code,
      );

      // Persistir sesión
      final email = (currentUserEmail ?? '').trim();
      await SessionService.saveSession(emailValue: email, tokenValue: jwt);

      // Mantener compat con tu flag global
      isLoggedIn = true;

      if (!mounted) return;
      Navigator.pop(context, true); // volvemos indicando éxito
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar código')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Te enviamos un código a tu email.'),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Código de 6 dígitos',
                hintText: '123456',
              ),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _verify,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verificar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
