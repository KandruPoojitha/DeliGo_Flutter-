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
        
        // Calculate price first
        customizations.forEach((key, value) {
          try {
            if (value is Map) {
              List? selectedItems;
              if (value['0'] != null && value['0'] is Map) {
                selectedItems = value['0']['selectedItems'] as List?;
              } else {
                selectedItems = value['selectedItems'] as List?;
              }
              
              if (selectedItems != null) {
                for (var selectedItem in selectedItems) {
                  if (selectedItem is Map && selectedItem['price'] != null) {
                    customizationPrice += (selectedItem['price'] as num).toDouble();
                  }
                }
              }
            }
          } catch (e) {
            print('Error calculating price for customization $key: $e');
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
      
      // Add scheduledDateTime if it exists
      if (menuItem['scheduledDateTime'] != null) {
        cartItem['scheduledDateTime'] = menuItem['scheduledDateTime'];
      }
      
      // Only add customizations if they exist in the expected format
      if (menuItem['customizations'] != null) {
        final cleanCustomizations = <String, dynamic>{};
        final customizations = menuItem['customizations'] as Map;
        
        customizations.forEach((key, value) {
          try {
            if (value is Map) {
              final nestedValue = value['0'];
              if (nestedValue != null && nestedValue is Map) {
                cleanCustomizations[key] = {
                  "0": {
                    'optionId': nestedValue['optionId'] ?? key,
                    'optionName': nestedValue['optionName'] ?? 'Unknown Option',
                    'selectedItems': nestedValue['selectedItems'] ?? [],
                  }
                };
              } else {
                // Handle case where value doesn't have nested "0" structure
                cleanCustomizations[key] = {
                  "0": {
                    'optionId': value['optionId'] ?? key,
                    'optionName': value['optionName'] ?? 'Unknown Option',
                    'selectedItems': value['selectedItems'] ?? [],
                  }
                };
              }
            }
          } catch (e) {
            print('Error processing customization $key: $e');
          }
        });
        
        if (cleanCustomizations.isNotEmpty) {
          cartItem['customizations'] = cleanCustomizations;
        }
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
      print('Error adding to cart: $e');
      rethrow;
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
          if (value is Map && value['0'] != null) {
            // Add prices from selected items in the nested structure
            final selectedItems = value['0']['selectedItems'] as List?;
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