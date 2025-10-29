import 'dart:convert';

// 1. Clase que define la estructura de un Producto
class Product {
  final int id;
  final String name;
  final String? team;
  final String? category;
  final double price;
  final String? imageUrl;
  final String? description;

  Product({
    required this.id,
    required this.name,
    this.team,
    this.category,
    required this.price,
    this.imageUrl,
    this.description,
  });

  // 2. Factory para crear un Producto desde el JSON de la API
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      team: json['team'],
      category: json['category'],
      price: (json['price'] as num).toDouble(), // Convertimos el precio
      imageUrl: json['image_url'],
      description: json['description'],
    );
  }
}

// 3. Función ayudante para convertir el string JSON en una Lista de Productos
List<Product> parseProducts(String responseBody) {
  final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();
  return parsed.map<Product>((json) => Product.fromJson(json)).toList();
}