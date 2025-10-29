// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'config.dart'; // <--- Usar esta para la URL base
import 'product_model.dart';
import 'banner_model.dart';

// Import widgets
import './widgets/custom_app_bar.dart';
import './widgets/promo_banner.dart';
import './widgets/category_icons.dart';
import './widgets/product_grid.dart';
import './widgets/bottom_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // States for products, banner, categories (no changes)
  bool _productsLoading = true;
  String _productsError = '';
  List<Product> _products = [];
  bool _bannerLoading = true;
  ActiveBanner? _activeBanner;
  final List<Map<String, dynamic>> _mockCategories = [
    {'name': 'Actual', 'icon': Icons.checkroom},
    {'name': 'Retro', 'icon': Icons.history},
    {'name': 'Barcelona', 'logo_url': 'https://upload.wikimedia.org/wikipedia/sco/thumb/4/47/FC_Barcelona_%28crest%29.svg/1010px-FC_Barcelona_%28crest%29.svg.png'},
    {'name': 'Real Madrid', 'logo_url': 'https://upload.wikimedia.org/wikipedia/sco/thumb/5/56/Real_Madrid_CF.svg/1464px-Real_Madrid_CF.svg.png'},
    {'name': 'Argentina', 'logo_url': 'https://upload.wikimedia.org/wikipedia/fr/thumb/c/c4/Logo_de_l%27%C3%A9quipe_d%27Argentine_de_football.svg/692px-Logo_de_l%27%C3%A9quipe_d%27Argentine_de_football.svg.png'},
    {'name': 'España', 'logo_url': 'https://upload.wikimedia.org/wikipedia/commons/6/6a/Escudo_selecci%C3%B3n_espa%C3%B1ola.png'},
  ];

  int _selectedIndex = 0; // Home is index 0

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    _fetchProducts();
    _fetchActiveBanner();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _productsLoading = true;
      _productsError = '';
    });

    final String url = '$kApiBase/products';  // Usando kApiBase
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _productsLoading = false;
          _products = parseProducts(response.body);
        });
      } else {
        setState(() {
          _productsLoading = false;
          _productsError = 'Error del servidor: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _productsLoading = false;
        _productsError = 'Error de conexión: $e';
      });
    }
  }

  Future<void> _fetchActiveBanner() async {
    setState(() {
      _bannerLoading = true;
    });

    final String url = '$kApiBase/active-banner'; // Usando kApiBase
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _bannerLoading = false;
          _activeBanner = parseActiveBanner(response.body);
        });
      } else {
        setState(() {
          _bannerLoading = false;
          _activeBanner = null;
        });
      }
    } catch (e) {
      setState(() {
        _bannerLoading = false;
        _activeBanner = null;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) return; // Ignore tap on the middle spacer
    setState(() { _selectedIndex = index; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: () async => _fetchData(),
        child: ListView(
          children: [
            PromoBanner(isLoading: _bannerLoading, banner: _activeBanner),
            const SizedBox(height: 24),
            CategoryIcons(categories: _mockCategories),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Productos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () {
                      // TODO: Navigate to a "See All Products" page
                      print("Ver más tapped!");
                    },
                    child: Text(
                      'Ver más',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ProductGrid(isLoading: _productsLoading, errorMessage: _productsError, products: _products),
            const SizedBox(height: 80), // Space for bottom content overlap
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
