import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ScheduledOrdersPage extends StatefulWidget {
  const ScheduledOrdersPage({super.key});

  @override
  State<ScheduledOrdersPage> createState() => _ScheduledOrdersPageState();
}

class _ScheduledOrdersPageState extends State<ScheduledOrdersPage> {
  final _database = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;
  late Stream<DatabaseEvent> _scheduledOrdersStream;

  @override
  void initState() {
    super.initState();
    final userId = _auth.currentUser?.uid;
    _scheduledOrdersStream = _database
        .ref()
        .child('scheduled_orders')
        .orderByChild('restaurantId')
        .equalTo(userId)
        .onValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Orders'),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _scheduledOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No Scheduled Orders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You have no scheduled orders at the moment',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final ordersData = snapshot.data!.snapshot.value as Map;
          
          // Filter orders with status: scheduled and order_status: pending
          final filteredOrders = ordersData.entries.where((entry) {
            final order = entry.value as Map;
            return order['status'] == 'scheduled' && order['order_status'] == 'pending';
          }).toList();
          
          // Sort filtered orders by scheduledDateTime or scheduledFor
          filteredOrders.sort((a, b) {
            final aMap = a.value as Map;
            final bMap = b.value as Map;
            
            final aTime = aMap['scheduledDateTime'] ?? aMap['scheduledFor'];
            final bTime = bMap['scheduledDateTime'] ?? bMap['scheduledFor'];
            
            // Handle null values
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            
            return (aTime as int).compareTo(bTime as int);
          });

          if (filteredOrders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No Scheduled Orders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You have no pending scheduled orders at the moment',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredOrders.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final order = filteredOrders[index].value as Map<dynamic, dynamic>;
              final orderId = filteredOrders[index].key as String;
              
              // Safely handle scheduledDateTime
              DateTime? scheduledDateTime;
              try {
                // First try scheduledDateTime
                final scheduledDateTimeValue = order['scheduledDateTime'];
                if (scheduledDateTimeValue != null) {
                  scheduledDateTime = DateTime.fromMillisecondsSinceEpoch(
                    scheduledDateTimeValue as int
                  );
                } else {
                  // Try scheduledFor as fallback
                  final scheduledForValue = order['scheduledFor'];
                  if (scheduledForValue != null) {
                    scheduledDateTime = DateTime.fromMillisecondsSinceEpoch(
                      scheduledForValue as int
                    );
                  }
                }
              } catch (e) {
                print('Error parsing scheduled time: $e');
              }
              
              final items = order['items'] as List<dynamic>;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      const Icon(Icons.schedule, color: Color(0xFFF4A261)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${orderId.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (scheduledDateTime != null)
                              Text(
                                DateFormat('MMM d, yyyy h:mm a').format(scheduledDateTime),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order['order_status'] == 'pending' 
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order['order_status'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: order['order_status'] == 'pending' 
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Information
                          Text(
                            'Customer: ${order['customerName']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (order['customerPhone'] != null)
                            Text('Phone: ${order['customerPhone']}'),
                          const SizedBox(height: 16),

                          // Delivery Information
                          if (order['deliveryOption'] != null) ...[
                            Text(
                              'Delivery Option: ${order['deliveryOption']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (order['address'] != null) ...[
                              const SizedBox(height: 8),
                              Text('Address: ${(order['address'] as Map)['street']}'),
                              if ((order['address'] as Map)['unit'] != null)
                                Text('Unit: ${(order['address'] as Map)['unit']}'),
                              if ((order['address'] as Map)['instructions'] != null)
                                Text(
                                  'Instructions: ${(order['address'] as Map)['instructions']}',
                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                            ],
                          ],
                          const SizedBox(height: 16),

                          // Order Items
                          const Text(
                            'Order Items:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            itemBuilder: (context, itemIndex) {
                              final item = items[itemIndex] as Map<dynamic, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['quantity']}x ${item['name']}',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                    Text(
                                      '\$${(item['totalPrice'] as num).toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Divider(),

                          // Order Summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal'),
                              Text('\$${order['subtotal'].toStringAsFixed(2)}'),
                            ],
                          ),
                          if (order['deliveryFee'] != null && order['deliveryFee'] > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Delivery Fee'),
                                Text('\$${order['deliveryFee'].toStringAsFixed(2)}'),
                              ],
                            ),
                          ],
                          if (order['tipAmount'] != null && order['tipAmount'] > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tip'),
                                Text('\$${order['tipAmount'].toStringAsFixed(2)}'),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '\$${order['total'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFFF4A261),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Action Buttons
                          if (order['order_status'] == 'pending')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _acceptScheduledOrder(orderId, order),
                                child: const Text('Accept Order'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _acceptScheduledOrder(String orderId, Map<dynamic, dynamic> orderData) async {
    try {
      // Create a copy of the order data with updated status
      final Map<String, dynamic> updatedOrderData = Map<String, dynamic>.from(orderData);
      updatedOrderData['status'] = 'pending';
      updatedOrderData['order_status'] = 'pending';
      updatedOrderData['acceptedAt'] = ServerValue.timestamp;

      // Add to orders reference
      await FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId)
          .set(updatedOrderData);

      // Remove from scheduled_orders reference
      await FirebaseDatabase.instance
          .ref()
          .child('scheduled_orders')
          .child(orderId)
          .remove();
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order moved to active orders'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 