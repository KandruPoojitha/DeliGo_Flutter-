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

      // Create a clean cart item with only the necessary fields
      final cartItem = {
        'id': menuItem['id'],
        'name': menuItem['name'],
        'description': menuItem['description'] ?? '',
        'price': menuItem['price'],
        'imageURL': menuItem['imageURL'] ?? menuItem['imageUrl'],
        'menuItemId': menuItem['id'],
        'quantity': 1,
        'totalPrice': menuItem['price'],
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'addedAt': ServerValue.timestamp,
      };
      
      // Only add customizations if they exist in the expected format
      if (menuItem['customizations'] != null) {
        cartItem['customizations'] = menuItem['customizations'];
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
          if (value is Map && value['price'] != null) {
            customizationPrice += (value['price'] as num).toDouble();
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
        .child('users/${user.uid}/cart')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          print("Raw cart data from Firebase: $data");
          
          if (data == null) {
            return null;
          }

          final Map<String, dynamic> cartItems = {};
          try {
            final map = data as Map<dynamic, dynamic>;
            map.forEach((key, value) {
              final item = Map<String, dynamic>.from(value as Map);
              print("Cart item key: $key");
              print("Cart item data structure: ${item.keys.toList()}");
              if (item['customizations'] != null) {
                print("Customizations for item ${item['name']}: ${item['customizations']}");
                print("Customizations type: ${item['customizations'].runtimeType}");
              }
              cartItems[key.toString()] = item;
            });
          } catch (e) {
            print("Error parsing cart data: $e");
          }
          
          print("Transformed cart items: ${cartItems.keys.toList()}");
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