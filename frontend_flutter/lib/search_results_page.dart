import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'product_model.dart';
import 'widgets/product_grid.dart';
import 'widgets/custom_app_bar.dart';
import 'widgets/bottom_nav_bar.dart';

class SearchResultsPage extends StatefulWidget {
  final String query;

  const SearchResultsPage({super.key, required this.query});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Product> _products = [];
  int _selectedIndex = 0; // Keep state for bottom bar

  @override
  void initState() {
    super.initState();
    print('-----> [Search Page] initState called for query: "${widget.query}"'); // <-- DEBUG PRINT
    _searchProducts(); // Call API when the page loads
  }

  Future<void> _searchProducts() async {
    // Ensure the state is updated to show loading
    // even if called multiple times (though not expected here)
    if (mounted) { // Check if the widget is still in the tree
      setState(() { _isLoading = true; _errorMessage = ''; });
    } else {
      return; // Don't proceed if widget is disposed
    }


    const String miIpLocal = '192.168.1.5';
    final encodedQuery = Uri.encodeComponent(widget.query);
    final String url = 'http://$miIpLocal:8080/search/text?q=$encodedQuery';

    print('-----> [Search Page] Calling API: $url'); // <-- DEBUG PRINT

    try {
      final response = await http.get(Uri.parse(url));

      print('-----> [Search Page] API Response Status: ${response.statusCode}'); // <-- DEBUG PRINT
      // print('-----> [Search Page] API Response Body: ${response.body}'); // <-- UNCOMMENT if detailed body needed

      // Check again if the widget is still mounted before updating state
      if (!mounted) return; 

      if (response.statusCode == 200) {
        final List<Product> results = parseProducts(response.body);
        print('-----> [Search Page] Parsed ${results.length} products'); // <-- DEBUG PRINT

        setState(() {
          _isLoading = false;
          _products = results;
          if (_products.isEmpty) {
            _errorMessage = 'No se encontraron productos para "${widget.query}"';
            print('-----> [Search Page] No products found message set.'); // <-- DEBUG PRINT
          }
        });
      } else {
        print('-----> [Search Page] API Error Status: ${response.statusCode}'); // <-- DEBUG PRINT
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error del servidor: ${response.statusCode}';
        });
      }
    } catch (e) {
       print('-----> [Search Page] Connection Error: $e'); // <-- DEBUG PRINT
       if (mounted) { // Check if mounted before setting state
         setState(() {
           _isLoading = false;
           _errorMessage = 'Error de conexión: $e';
         });
       }
    }
  }

  void _onItemTapped(int index) {
     if (index == 2) return; 
    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst); 
    } else {
      setState(() { _selectedIndex = index; });
      print('SearchResultsPage Nav Tapped: $index');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(initialQuery: widget.query),
      body: _buildResultsBody(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: buildFloatingActionButton(context), // Use the FAB from bottom_nav_bar.dart
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      extendBody: true,
    );
  }

  Widget _buildResultsBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty || _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _errorMessage.isNotEmpty ? _errorMessage : 'No se encontraron productos para "${widget.query}"',
            style: TextStyle(
              fontSize: 18, 
              color: _errorMessage.isNotEmpty ? Colors.red : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80.0), 
      child: ProductGrid(
        isLoading: false, 
        errorMessage: '',  
        products: _products,
      ),
    );
  }
}