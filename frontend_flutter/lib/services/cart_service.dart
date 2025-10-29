import 'package:flutter/foundation.dart';
import '../product_model.dart';

class CartItem {
  final Product product;
  int qty;
  CartItem({required this.product, this.qty = 1});
}

class CartService {
  // Estado global reactivo
  static final ValueNotifier<List<CartItem>> items = ValueNotifier<List<CartItem>>([]);

  static void add(Product p, {int qty = 1}) {
    final list = List<CartItem>.from(items.value);
    final idx = list.indexWhere((e) => e.product.id == p.id);
    if (idx >= 0) {
      list[idx].qty += qty;
    } else {
      list.add(CartItem(product: p, qty: qty));
    }
    items.value = list;
  }

  static void remove(Product p) {
    final list = List<CartItem>.from(items.value)..removeWhere((e) => e.product.id == p.id);
    items.value = list;
  }

  static void clear() {
    items.value = [];
  }

  static int get totalCount => items.value.fold(0, (acc, e) => acc + e.qty);

  static double get totalPrice =>
      items.value.fold<double>(0, (acc, e) => acc + (e.product.price * e.qty));
}
