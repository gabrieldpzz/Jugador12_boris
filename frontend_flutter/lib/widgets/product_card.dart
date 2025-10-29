import 'package:flutter/material.dart';
import '../product_model.dart';
import '../product_detail_page.dart'; // <-- Import the new detail page

// --- WIDGET: TARJETA DE PRODUCTO (AHORA CLICKEABLE) ---
class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    // --- Wrap Card with InkWell for tap effect and navigation ---
    return InkWell(
      onTap: () {
        print('Tapped product: ${product.name}'); // Debug print
        Navigator.push(
          context,
          MaterialPageRoute(
            // Navigate to ProductDetailPage, passing the product data
            builder: (context) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Hero( // Optional: Add Hero animation for image transition
                tag: 'product_image_${product.id}', // Unique tag for animation
                child: Image.network(
                  product.imageUrl ?? 'https://via.placeholder.com/150',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.error));
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}