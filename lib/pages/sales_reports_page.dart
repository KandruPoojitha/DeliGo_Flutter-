import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SalesReportsPage extends StatefulWidget {
  const SalesReportsPage({Key? key}) : super(key: key);

  @override
  State<SalesReportsPage> createState() => _SalesReportsPageState();
}

class _SalesReportsPageState extends State<SalesReportsPage> {
  final _auth = FirebaseAuth.instance;
  double _totalRevenue = 0.0;
  int _totalOrders = 0;
  double _averageOrderValue = 0.0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
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
          
          // Calculate totals
          _totalOrders = deliveredOrders.length;
          _totalRevenue = 0.0;
          
          for (var order in deliveredOrders) {
            try {
              double orderTotal = 0.0;
              
              // Use total if available
              if (order['total'] != null) {
                orderTotal = (order['total'] as num).toDouble();
              }
              // Or use subtotal + tax
              else if (order['subtotal'] != null) {
                orderTotal += (order['subtotal'] as num).toDouble();
                
                if (order['tax'] != null) {
                  orderTotal += (order['tax'] as num).toDouble();
                }
              }
              // Otherwise calculate from items
              else if (order['items'] is List) {
                final items = order['items'] as List;
                
                for (var item in items) {
                  if (item is Map) {
                    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                    orderTotal += price * quantity;
                  }
                }
                
                if (order['tax'] != null) {
                  orderTotal += (order['tax'] as num).toDouble();
                }
              }
              
              _totalRevenue += orderTotal;
            } catch (e) {
              print('Error calculating order revenue: $e');
            }
          }
          
          _averageOrderValue = _totalOrders > 0 ? _totalRevenue / _totalOrders : 0.0;
          
          // UI with the three cards
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Total Orders Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Orders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _totalOrders.toString(),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Total Revenue Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Revenue',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_totalRevenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF4A261),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Average Order Value Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Average Order Value',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_averageOrderValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 