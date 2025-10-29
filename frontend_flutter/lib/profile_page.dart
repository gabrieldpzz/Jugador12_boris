// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'services/session_service.dart';
import 'services/cart_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = SessionService.email ?? 'email no disponible';

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sesión iniciada como:', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(email, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Correo'),
              subtitle: Text(email),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                onPressed: () async {
                  // limpiar carrito (opcional)
                  try { CartService.clear(); } catch (_) {}
                  // limpiar sesión persistida
                  await SessionService.clear();
                  // volver al inicio
                  if (context.mounted) {
                    Navigator.popUntil(context, (route) => route.isFirst);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Has cerrado sesión')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
