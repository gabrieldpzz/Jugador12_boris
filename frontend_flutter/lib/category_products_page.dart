import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'product_model.dart';
import 'widgets/product_grid.dart';
import 'widgets/custom_app_bar.dart'; // Re-use AppBar
import 'widgets/bottom_nav_bar.dart'; // Re-use BottomNavBar

class CategoryProductsPage extends StatefulWidget {
  final String categoryName; // Receives the category name

  const CategoryProductsPage({super.key, required this.categoryName});

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Product> _products = [];
  int _selectedIndex = 0; // State for bottom bar

  @override
  void initState() {
    super.initState();
    _fetchCategoryProducts(); // Call API when the page loads
  }

  Future<void> _fetchCategoryProducts() async {
    setState(() { _isLoading = true; _errorMessage = ''; });

    const String miIpLocal = '192.168.1.5';
    // Use the category name in the URL path, ensuring it's URL-safe
    final encodedCategory = Uri.encodeComponent(widget.categoryName);
    final String url = 'http://$miIpLocal:8080/products/category/$encodedCategory';

    print('-----> [Category Page] Calling API: $url');

    try {
      final response = await http.get(Uri.parse(url));
      print('-----> [Category Page] API Response Status: ${response.statusCode}');

      if (!mounted) return; // Check if widget is still active

      if (response.statusCode == 200) {
        final List<Product> results = parseProducts(response.body);
        print('-----> [Category Page] Parsed ${results.length} products');

        setState(() {
          _isLoading = false;
          _products = results;
          if (_products.isEmpty) {
            _errorMessage = 'No hay productos en la categoría "${widget.categoryName}"';
          }
        });
      } else {
        print('-----> [Category Page] API Error Status: ${response.statusCode}');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error del servidor: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('-----> [Category Page] Connection Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error de conexión: $e';
        });
      }
    }
  }

  // Bottom Nav Bar Handler (same as SearchResultsPage)
  void _onItemTapped(int index) {
     if (index == 2) return;
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      setState(() { _selectedIndex = index; });
      print('CategoryProductsPage Nav Tapped: $index');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Re-use the AppBar (maybe without initial query?)
      appBar: CustomAppBar(key: ValueKey(widget.categoryName)), // Use ValueKey if AppBar needs rebuild on category change

      body: _buildCategoryBody(),

      // Re-use the BottomNavBar
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: buildFloatingActionButton(context), // Re-use FAB
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      extendBody: true,
    );
  }

  Widget _buildCategoryBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty || _products.isEmpty) {
      // Message when no results or error
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
             _errorMessage.isNotEmpty ? _errorMessage : 'No hay productos en la categoría "${widget.categoryName}"',
            style: TextStyle(
              fontSize: 18,
              color: _errorMessage.isNotEmpty ? Colors.red : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Results Grid
    return Column( // Use Column to add Title before the Grid
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 8.0),
            child: Text(
              'Categoría: ${widget.categoryName}', // Add a title
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded( // Make the Grid fill remaining space
            child: SingleChildScrollView( // Allow Grid to scroll if needed
               padding: const EdgeInsets.only(bottom: 80.0), // Space for FAB/Nav
               child: ProductGrid(
                 isLoading: false,
                 errorMessage: '',
                 products: _products,
               ),
            ),
          ),
       ],
    );
  }
}