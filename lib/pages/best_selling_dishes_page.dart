import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class BestSellingDishesPage extends StatefulWidget {
  const BestSellingDishesPage({Key? key}) : super(key: key);

  @override
  State<BestSellingDishesPage> createState() => _BestSellingDishesPageState();
}

class _BestSellingDishesPageState extends State<BestSellingDishesPage> {
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Selling Dishes'),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance
            .ref()
            .child('orders')
            .orderByChild('restaurantId')
            .equalTo(_auth.currentUser?.uid)
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text('No order history found'));
          }
          
          // Get all orders data
          final data = snapshot.data!.snapshot.value;
          List<Map<dynamic, dynamic>> deliveredOrders = [];
          
          // Extract all delivered orders
          if (data is Map) {
            data.forEach((key, value) {
              if (value is Map) {
                final status = value['order_status'] ?? value['status'] ?? '';
                if (status.toString().toLowerCase() == 'delivered') {
                  deliveredOrders.add(value);
                }
              }
            });
          }
          
          // Calculate best selling dishes
          Map<String, Map<String, dynamic>> dishesMap = {};
          
          for (var order in deliveredOrders) {
            if (order['items'] is List) {
              final items = order['items'] as List;
              
              for (var item in items) {
                if (item is Map) {
                  final name = item['name']?.toString() ?? 'Unknown';
                  final category = item['category']?.toString() ?? 'Main Course';
                  final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                  final menuItemId = item['menuItemId']?.toString();
                  
                  if (!dishesMap.containsKey(name)) {
                    dishesMap[name] = {
                      'name': name,
                      'category': category,
                      'quantity': quantity,
                      'menuItemId': menuItemId,
                    };
                  } else {
                    dishesMap[name]!['quantity'] = (dishesMap[name]!['quantity'] as int) + quantity;
                  }
                }
              }
            }
          }
          
          // Convert to list and sort by quantity (most sold first)
          List<Map<String, dynamic>> bestSellingDishes = dishesMap.values.map((e) => Map<String, dynamic>.from(e)).toList();
          bestSellingDishes.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
          
          if (bestSellingDishes.isEmpty) {
            return const Center(child: Text('No sales data available'));
          }
          
          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref()
                .child('restaurants')
                .child(_auth.currentUser!.uid)
                .child('menu_items')
                .onValue,
            builder: (context, menuSnapshot) {
              if (menuSnapshot.hasData && menuSnapshot.data?.snapshot.value != null) {
                final menuItems = menuSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                
                // Attach image URLs to our best selling dishes
                for (var dish in bestSellingDishes) {
                  final dishName = dish['name'] as String;
                  String? imageUrl;
                  
                  // Find matching menu item by name
                  menuItems.forEach((key, menuItem) {
                    if (menuItem is Map && menuItem['name'] == dishName) {
                      imageUrl = menuItem['imageURL'] ?? menuItem['imageUrl'];
                      dish['imageUrl'] = imageUrl;
                    }
                  });
                }
              }
              
              return ListView.builder(
                itemCount: bestSellingDishes.length,
                itemBuilder: (context, index) {
                  final dish = bestSellingDishes[index];
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Left side: Dish image or placeholder
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: dish['imageUrl'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      dish['imageUrl'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, size: 40),
                                    ),
                                  )
                                : const Icon(Icons.restaurant, size: 40),
                          ),
                          const SizedBox(width: 16),
                          
                          // Right side: Dish details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dish['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dish['category'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.shopping_basket, size: 16, color: Color(0xFFF4A261)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${dish['quantity']} sold',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFFF4A261),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          );
        },
      ),
    );
  }
} 