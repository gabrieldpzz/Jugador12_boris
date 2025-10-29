import 'package:flutter/material.dart';
import '../chat_screen.dart';
import '../cart_page.dart';
import '../services/cart_service.dart';
import '../login_page.dart';
import '../profile_page.dart';
import '../main.dart'; // isLoggedIn

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color customOrange = Color(0xFFF57C00);

    return ValueListenableBuilder(
      valueListenable: CartService.items,
      builder: (context, list, _) {
        final count = CartService.totalCount;

        return BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
            const BottomNavigationBarItem(
              icon: SizedBox.shrink(), // espacio para el FAB central
              label: '',
            ),
            // Carrito con badge
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (count > 0)
                    Positioned(
                      right: -6,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: customOrange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: currentIndex,
          selectedItemColor: customOrange,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 10,
          onTap: (index) async {
            if (index == 3) {
              // Carrito
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
              return;
            }

            if (index == 4) {
              // Perfil: si no está logeado, ir a Login; si está, ir a Perfil.
              if (!isLoggedIn) {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                // si el login fue exitoso, ok == true y ya marcaste isLoggedIn en tu flujo
                if (ok == true && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              }
              return;
            }

            // El resto de tabs los maneja quien usa el BottomNavBar
            onTap(index);
          },
        );
      },
    );
  }
}

// FAB central -> Chat
Widget buildFloatingActionButton(BuildContext context) {
  const Color customOrange = Color(0xFFF57C00);
  return FloatingActionButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    },
    backgroundColor: customOrange,
    shape: const CircleBorder(),
    elevation: 4.0,
    child: const Icon(Icons.message_outlined, color: Colors.white, size: 28),
  );
}
