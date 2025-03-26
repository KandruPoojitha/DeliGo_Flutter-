import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class MenuItemDetailsDialog extends StatefulWidget {
  // ... (existing code)
}

class _MenuItemDetailsDialogState extends State<MenuItemDetailsDialog> {
  // ... (existing code)

  Future<void> _addToCart() async {
    try {
      final cartRef = FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(FirebaseAuth.instance.currentUser?.uid ?? '')
          .child('cart');

      // Generate a unique ID for the cart item
      final cartItemId = cartRef.push().key;
      if (cartItemId == null) throw Exception('Failed to generate cart item ID');

      // Calculate total price including customizations
      double totalPrice = widget.item['price'] ?? 0.0;
      
      // Format customizations in the new structure
      List<Map<String, dynamic>> formattedCustomizations = [];
      _selectedCustomizations.forEach((optionId, selectedItems) {
        if (selectedItems.isNotEmpty) {
          final option = widget.item['customizations'][optionId];
          formattedCustomizations.add({
            'optionId': optionId,
            'optionName': option['name'] ?? 'Unknown Option',
            'selectedItems': selectedItems.map((item) => {
              'id': item['id'],
              'name': item['name'],
              'price': item['price'] ?? 0.0,
            }).toList(),
          });
          
          // Add customization prices to total
          for (var item in selectedItems) {
            totalPrice += (item['price'] ?? 0.0);
          }
        }
      });

      // Multiply by quantity
      totalPrice *= _quantity;

      // Create cart item data
      final cartItemData = {
        'id': widget.item['id'],
        'name': widget.item['name'],
        'price': widget.item['price'],
        'quantity': _quantity,
        'totalPrice': totalPrice,
        'restaurantId': widget.restaurantId,
        'restaurantName': widget.restaurantName,
        'imageURL': widget.item['imageURL'],
        'customizations': formattedCustomizations,
        'specialInstructions': _specialInstructions.text.trim(),
      };

      // Add to cart
      await cartRef.child(cartItemId).set(cartItemData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to cart: $e')),
        );
      }
    }
  }

  // ... (rest of the existing code)
} 