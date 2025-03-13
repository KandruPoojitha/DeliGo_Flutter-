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

      // Prepare cart item data
      final cartItem = {
        'id': menuItem['id'],
        'name': menuItem['name'],
        'description': menuItem['description'],
        'price': menuItem['price'],
        'imageUrl': menuItem['imageUrl'],
        'quantity': 1,
        'totalPrice': menuItem['price'],
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'customizationOptions': menuItem['customizationOptions'],
        'selectedCustomizations': menuItem['selectedCustomizations'] ?? {},
        'addedAt': ServerValue.timestamp,
      };

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

      // Calculate customization price
      if (item['selectedCustomizations'] != null && item['customizationOptions'] != null) {
        final customizations = item['customizationOptions'] as List;
        final selectedCustomizations = Map<String, bool>.from(item['selectedCustomizations'] as Map);

        for (final customization in customizations) {
          final options = customization['options'] as List;
          for (final option in options) {
            if (selectedCustomizations[option['name']] == true) {
              customizationPrice += (option['price'] as num).toDouble();
            }
          }
        }
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
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _database
        .ref()
        .child('customers')
        .child(userId)
        .child('cart')
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return Map<String, dynamic>.from(data);
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