import 'package:flutter/material.dart';
import 'services/cart_service.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color customOrange = Color(0xFFF57C00);

    return Scaffold(
      appBar: AppBar(title: const Text('Tu carrito')),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: CartService.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const Center(child: Text('Tu carrito está vacío'));
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final it = items[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          it.product.imageUrl ?? 'https://via.placeholder.com/60x60',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                        ),
                      ),
                      title: Text(it.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('x${it.qty}  •  \$${it.product.price.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => CartService.remove(it.product),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total: \$${CartService.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customOrange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Checkout no implementado (demo)')),
                        );
                      },
                      child: const Text('Pagar'),
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
