import 'package:flutter/material.dart';
import '../banner_model.dart'; // Importa el modelo

// --- WIDGET: BANNER DE PROMOCIÓN ---
class PromoBanner extends StatelessWidget {
  final bool isLoading;
  final ActiveBanner? banner;

  const PromoBanner({
    super.key,
    required this.isLoading,
    this.banner,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Muestra un 'cargando'
    if (isLoading) {
      return Container(
        height: 150.0,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 2. Si no hay banner, no muestra nada
    if (banner == null) {
      return const SizedBox.shrink();
    }

    // 3. Si SÍ hay banner, lo muestra
    return Container(
      height: 150.0,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack( 
        fit: StackFit.expand,
        children: [
          Image.network(
            banner!.imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error cargando imagen del banner: $error');
              return const Center(child: Icon(Icons.error_outline, color: Colors.white, size: 40));
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end, 
              children: [
                Text(
                  banner!.subtitle ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  banner!.title ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
