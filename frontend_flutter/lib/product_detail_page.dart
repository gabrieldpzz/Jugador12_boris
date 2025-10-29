import 'package:flutter/material.dart';
import 'product_model.dart';
import 'widgets/bottom_nav_bar.dart';
import 'login_page.dart';
import 'main.dart'; // isLoggedIn
import 'services/cart_service.dart';
import 'cart_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    if (index == 2) return; // FAB central (lo maneja el FAB)
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    if (index == 3) {
      // Carrito
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleAddToCart() async {
    if (isLoggedIn) {
      CartService.add(widget.product, qty: 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.product.name} añadido al carrito')),
      );
      return;
    }

    // No logeado -> ir a login y luego intentar de nuevo
    final loginResult = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
    if (loginResult == true && mounted) {
      setState(() => isLoggedIn = true);
      CartService.add(widget.product, qty: 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.product.name} añadido al carrito')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color customOrange = Color(0xFFF57C00);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // Badge simple del carrito
          ValueListenableBuilder(
            valueListenable: CartService.items,
            builder: (context, list, _) {
              final count = CartService.totalCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartPage()),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: customOrange,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.network(
                widget.product.imageUrl ?? 'https://via.placeholder.com/400x400',
                height: 350,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 350,
                    color: Colors.grey.shade300,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 350,
                    color: Colors.grey.shade300,
                    child: const Center(child: Icon(Icons.error, size: 50)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.product.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${widget.product.price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: customOrange,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'Descripción',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product.description ?? 'No hay descripción disponible.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: _handleAddToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar al Carrito'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: customOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: buildFloatingActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      extendBody: true,
    );
  }
}
