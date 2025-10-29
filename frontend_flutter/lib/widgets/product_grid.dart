import 'package:flutter/material.dart';
import '../product_model.dart'; // Importa el modelo
import './product_card.dart';  // Importa la tarjeta

// --- WIDGET: CUADRÍCULA DE PRODUCTOS ---
class ProductGrid extends StatelessWidget {
  final bool isLoading;
  final String errorMessage;
  final List<Product> products;

  const ProductGrid({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          errorMessage,
          style: const TextStyle(color: Colors.red, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    }
    return GridView.builder(
      // Padding y Physics/shrinkWrap se manejan mejor en la página principal
      // que contiene este Grid. Se quitaron de aquí.
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      physics: const NeverScrollableScrollPhysics(), 
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.7,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        // Usa el widget ProductCard importado
        return ProductCard(product: product); 
      },
    );
  }
}