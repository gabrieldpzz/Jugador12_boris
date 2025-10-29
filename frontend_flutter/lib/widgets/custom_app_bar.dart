import 'package:flutter/material.dart';
import '../search_results_page.dart'; // Ensure this import is correct

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? initialQuery; 
  const CustomAppBar({super.key, this.initialQuery});

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomAppBarState extends State<CustomAppBar> {
  late final TextEditingController _searchController; 

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery); 
  }

  @override
  void dispose() {
    _searchController.dispose(); 
    super.dispose();
  }

  // This function triggers the navigation
  void _submitSearch(String query) {
    final trimmedQuery = query.trim();
    print('-----> [AppBar] _submitSearch called with: "$trimmedQuery"'); // <-- DEBUG PRINT
    if (trimmedQuery.isNotEmpty) {
      print('-----> [AppBar] Navigating to SearchResultsPage...'); // <-- DEBUG PRINT
      // Use pushReplacement if you are already on SearchResultsPage to avoid stacking
      // Use push if you are on HomePage
      // Let's check the current route
      final currentRoute = ModalRoute.of(context);
      bool isCurrentlySearchResults = currentRoute is MaterialPageRoute && currentRoute.builder(context) is SearchResultsPage;

      if (isCurrentlySearchResults) {
         // If already on search results, replace the current page with new results
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SearchResultsPage(query: trimmedQuery),
            ),
          );
      } else {
        // If on HomePage or elsewhere, push the new page onto the stack
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchResultsPage(query: trimmedQuery),
          ),
        );
      }
    } else {
       print('-----> [AppBar] Search query was empty, not navigating.'); // <-- DEBUG PRINT
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: true, // Show back button automatically
      iconTheme: const IconThemeData(color: Colors.black), 
      title: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController, 
          decoration: const InputDecoration(
            hintText: 'Search product',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.only(left: 0, right: 15, top: 11, bottom: 9), 
          ),
          textInputAction: TextInputAction.search, 
          onSubmitted: _submitSearch, // This is the trigger
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
          onPressed: () { /* TODO: Lógica del carrito */ },
        ),
      ],
    );
  }
}