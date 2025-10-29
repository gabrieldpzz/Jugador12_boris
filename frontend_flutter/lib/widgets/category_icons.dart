import 'package:flutter/material.dart';
import '../search_results_page.dart'; // Navega a SearchResultsPage

class CategoryIcons extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  const CategoryIcons({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final categoryName = category['name'] as String;
          final iconData = category['icon'] as IconData?;
          final logoUrl = category['logo_url'] as String?;

          return InkWell(
            onTap: () {
              print('Tapped icon, searching for: $categoryName');
              // Navega a SearchResultsPage, usando el nombre como query
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultsPage(query: categoryName),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    // --- ¡CÓDIGO RESTAURADO AQUÍ! ---
                    child: logoUrl != null
                        ? Image.network(
                            logoUrl, // Usa la URL del logo
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF57C00)))
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Error loading logo for $categoryName: $error');
                              return const Icon(Icons.error_outline, color: Colors.grey, size: 30);
                            },
                          )
                        : Icon( // Usa el IconData si no hay logoUrl
                            iconData ?? Icons.category, // Fallback a icono genérico
                            color: const Color(0xFFF57C00),
                            size: 30,
                          ),
                    // ---------------------------------
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categoryName,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
