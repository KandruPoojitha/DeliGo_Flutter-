import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class TipHistoryScreen extends StatefulWidget {
  const TipHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TipHistoryScreen> createState() => _TipHistoryScreenState();
}

class _TipHistoryScreenState extends State<TipHistoryScreen> {
  final _auth = FirebaseAuth.instance;
  double _totalTips = 0.0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tip History'),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Tips',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '\$${_totalTips.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF4A261),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Tip History
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('orders')
                  .orderByChild('driverId')
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
                
                final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final deliveredOrders = data.entries
                    .where((order) => order.value['order_status'] == 'delivered')
                    .toList();
                
                if (deliveredOrders.isEmpty) {
                  return const Center(child: Text('No delivered orders yet'));
                }
                
                // Calculate total tips
                double totalTips = 0.0;
                for (var order in deliveredOrders) {
                  final tipAmount = (order.value['tipAmount'] as num?)?.toDouble() ?? 0.0;
                  totalTips += tipAmount;
                }
                
                // Update total only if it changed
                if (_totalTips != totalTips) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _totalTips = totalTips;
                    });
                  });
                }
                
                // Sort orders by date (most recent first)
                deliveredOrders.sort((a, b) {
                  final aTime = a.value['deliveredAt'] ?? a.value['updatedAt'] ?? '';
                  final bTime = b.value['deliveredAt'] ?? b.value['updatedAt'] ?? '';
                  return bTime.toString().compareTo(aTime.toString());
                });
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: deliveredOrders.length,
                  itemBuilder: (context, index) {
                    final order = deliveredOrders[index].value as Map<dynamic, dynamic>;
                    final orderId = deliveredOrders[index].key;
                    final tipAmount = (order['tipAmount'] as num?)?.toDouble() ?? 0.0;
                    final deliveryDate = order['deliveredAt'] ?? order['updatedAt'] ?? '';
                    final orderDate = order['createdAt'] ?? '';
                    final formattedDate = _formatDate(deliveryDate.toString());
                    final formattedOrderDate = _formatDate(orderDate.toString());
                    final restaurantName = order['restaurantName'] ?? 'Restaurant';
                    final deliveryAddress = _extractAddress(order);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order #$orderId',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),

                                      Text(
                                        'Delivered: $formattedDate',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: tipAmount > 0 
                                      ? const Color(0xFFF4A261).withOpacity(0.2) 
                                      : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Tip: \$${tipAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: tipAmount > 0 
                                        ? const Color(0xFFF4A261) 
                                        : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.store, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    restaurantName,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    deliveryAddress,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(String dateString) {
    try {
      // Check if the date string is a numeric timestamp (milliseconds since epoch)
      if (dateString.isNotEmpty && RegExp(r'^\d+$').hasMatch(dateString)) {
        final timestamp = int.parse(dateString);
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
      } else {
        // Try to parse as ISO date string
        final dateTime = DateTime.parse(dateString);
        return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
      }
    } catch (e) {
      return dateString;
    }
  }
  
  String _extractAddress(Map<dynamic, dynamic> order) {
    try {
      final addressData = order['address'] as Map<dynamic, dynamic>?;
      if (addressData == null) return 'No delivery address';
      
      final street = addressData['street'] as String?;
      final unit = addressData['unit'] as String?;
      
      if (street != null) {
        if (unit != null && unit.isNotEmpty) {
          return "Unit $unit, $street";
        }
        return street;
      }
      return 'No address details';
    } catch (e) {
      return 'Address unavailable';
    }
  }
} 