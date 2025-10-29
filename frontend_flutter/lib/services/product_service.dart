// lib/services/product_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../product_model.dart';

class ProductService {
  /// Busca productos en tu API Dart usando /search/text?q=
  static Future<List<Product>> search(String query, {int limit = 5}) async {
    final uri = Uri.parse('$kApiBase/search/text').replace(queryParameters: {
      'q': query,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Search ${res.statusCode}: ${res.body}');
    }
    final List<dynamic> raw = jsonDecode(res.body);
    final items = raw.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    if (items.length > limit) return items.take(limit).toList();
    return items;
  }
}
