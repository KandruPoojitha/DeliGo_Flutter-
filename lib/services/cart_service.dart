import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartService {
  final _database = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> addToCart(Map<String, dynamic> menuItem, String restaurantId, String restaurantName) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Create a unique cart item ID
      final cartItemId = _database
          .ref()
          .child('customers')
          .child(userId)
          .child('cart')
          .push()
          .key;

      if (cartItemId == null) throw Exception('Failed to generate cart item ID');

      // Calculate total price including customizations
      double basePrice = (menuItem['price'] as num).toDouble();
      double customizationPrice = 0.0;

      if (menuItem['customizations'] != null) {
        final customizations = menuItem['customizations'] as Map;
        
        customizations.forEach((key, value) {
          if (value is Map) {
            // Add prices from selected items
            final selectedItems = value['selectedItems'] as List?;
            if (selectedItems != null) {
              for (var selectedItem in selectedItems) {
                if (selectedItem is Map && selectedItem['price'] != null) {
                  customizationPrice += (selectedItem['price'] as num).toDouble();
                }
              }
            }
          }
        });
      }

      final totalPrice = basePrice + customizationPrice;

      // Create a clean cart item with only the necessary fields
      final cartItem = {
        'id': menuItem['id'],
        'name': menuItem['name'],
        'description': menuItem['description'] ?? '',
        'price': menuItem['price'],
        'imageURL': menuItem['imageURL'] ?? menuItem['imageUrl'],
        'menuItemId': menuItem['id'],
        'quantity': 1,
        'totalPrice': totalPrice,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'addedAt': ServerValue.timestamp,
      };
      
      // Only add customizations if they exist in the expected format
      if (menuItem['customizations'] != null) {
        // Clean up customizations to remove option-level prices
        final cleanCustomizations = <String, dynamic>{};
        final customizations = menuItem['customizations'] as Map;
        
        customizations.forEach((key, value) {
          if (value is Map) {
            cleanCustomizations[key] = {
              'optionId': value['optionId'],
              'optionName': value['optionName'],
              'selectedItems': value['selectedItems'],
            };
          }
        });
        
        cartItem['customizations'] = cleanCustomizations;
      }

      // Add to cart
      await _database
          .ref()
          .child('customers')
          .child(userId)
          .child('cart')
          .child(cartItemId)
          .set(cartItem);
    } catch (e) {
      throw Exception('Failed to add item to cart: $e');
    }
  }

  Future<void> removeFromCart(String itemId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      await _database
          .ref()
          .child('customers')
          .child(userId)
          .child('cart')
          .child(itemId)
          .remove();
    } catch (e) {
      throw Exception('Failed to remove item from cart: $e');
    }
  }

  Future<void> updateQuantity(String itemId, Map<String, dynamic> item, int newQuantity) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      if (newQuantity <= 0) {
        await removeFromCart(itemId);
        return;
      }

      final basePrice = (item['price'] as num).toDouble();
      double customizationPrice = 0.0;

      // Calculate customization price from the new structure
      if (item['customizations'] != null) {
        final customizations = item['customizations'] as Map;
        
        customizations.forEach((key, value) {
          if (value is Map) {
            // Add prices from selected items
            final selectedItems = value['selectedItems'] as List?;
            if (selectedItems != null) {
              for (var selectedItem in selectedItems) {
                if (selectedItem is Map && selectedItem['price'] != null) {
                  customizationPrice += (selectedItem['price'] as num).toDouble();
                }
              }
            }
          }
        });
      }

      final totalPrice = (basePrice + customizationPrice) * newQuantity;

      await _database
          .ref()
          .child('customers')
          .child(userId)
          .child('cart')
          .child(itemId)
          .update({
        'quantity': newQuantity,
        'totalPrice': totalPrice,
      });
    } catch (e) {
      throw Exception('Failed to update quantity: $e');
    }
  }

  Stream<Map<String, dynamic>?> getCartStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _database
        .ref()
        .child('customers')
        .child(user.uid)
        .child('cart')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          
          if (data == null) {
            return null;
          }

          final Map<String, dynamic> cartItems = {};
          try {
            final map = data as Map<dynamic, dynamic>;
            map.forEach((key, value) {
              final item = Map<String, dynamic>.from(value as Map);
              cartItems[key.toString()] = item;
            });
          } catch (e) {
            print("Error parsing cart data: $e");
          }
          
          return cartItems;
        });
  }

  Future<Map<String, dynamic>?> getCart() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final snapshot = await _database
          .ref()
          .child('customers')
          .child(userId)
          .child('cart')
          .get();

      if (!snapshot.exists || snapshot.value == null) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      throw Exception('Failed to get cart: $e');
    }
  }
} 