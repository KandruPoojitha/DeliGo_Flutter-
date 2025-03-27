import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({Key? key}) : super(key: key);

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  double _totalEarnings = 0.0;
  double _totalDeliveryFees = 0.0;
  double _totalTips = 0.0;
  int _deliveriesCompleted = 0;
  
  late TabController _tabController;
  final List<String> _tabs = ['Daily', 'Weekly', 'Monthly'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  String get _periodLabel {
    switch (_tabController.index) {
      case 0:
        return 'Today';
      case 1:
        return 'This Week';
      case 2:
        return 'This Month';
      default:
        return 'Today';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
              indicatorColor: const Color(0xFFF4A261),
              labelColor: const Color(0xFFF4A261),
              unselectedLabelColor: Colors.black,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          
          // Orders Stream
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
                
                // Filter based on selected tab
                final filteredOrders = _filterOrdersByTab(deliveredOrders);
                
                // Calculate totals
                _totalEarnings = 0.0;
                _totalDeliveryFees = 0.0;
                _totalTips = 0.0;
                _deliveriesCompleted = filteredOrders.length;
                
                for (var order in filteredOrders) {
                  final driverPay = (order.value['driverPay'] as num?)?.toDouble() ?? 0.0;
                  final tipAmount = (order.value['tipAmount'] as num?)?.toDouble() ?? 0.0;
                  final deliveryFee = (order.value['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                  
                  _totalDeliveryFees += deliveryFee;
                  _totalTips += tipAmount;
                  _totalEarnings += deliveryFee + tipAmount;
                }
                
                // Sort orders by date (most recent first)
                filteredOrders.sort((a, b) {
                  final aTime = a.value['deliveredAt'] ?? a.value['updatedAt'] ?? '';
                  final bTime = b.value['deliveredAt'] ?? b.value['updatedAt'] ?? '';
                  return bTime.toString().compareTo(aTime.toString());
                });
                
                return Column(
                  children: [
                    // Summary Card
                    Card(
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: const Color(0xFFFFF8F0),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _periodLabel,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${_totalEarnings.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF4A261),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Delivery Fees',
                                      style: TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '\$${_totalDeliveryFees.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tips',
                                      style: TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '\$${_totalTips.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Deliveries',
                                      style: TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '$_deliveriesCompleted',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Order List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          final orderData = order.value as Map<dynamic, dynamic>;
                          final orderId = order.key;
                          final driverPay = (orderData['driverPay'] as num?)?.toDouble() ?? 0.0;
                          final tipAmount = (orderData['tipAmount'] as num?)?.toDouble() ?? 0.0;
                          final deliveryFee = (orderData['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                          final total = deliveryFee + tipAmount;
                          final deliveryTime = orderData['deliveredAt'] ?? orderData['updatedAt'] ?? '';
                          final formattedDeliveryTime = _formatDateTime(deliveryTime.toString());
                          final creationTime = orderData['createdAt'] ?? '';
                          final formattedCreationTime = _formatDateTime(creationTime.toString());
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
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
                                    formattedCreationTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Delivery Fee',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      Text(
                                        '\$${deliveryFee.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Tip',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      Text(
                                        '\$${tipAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: tipAmount > 0 ? const Color(0xFFF4A261) : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '\$${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF4A261),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  List<MapEntry<dynamic, dynamic>> _filterOrdersByTab(List<MapEntry<dynamic, dynamic>> orders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    return orders.where((order) {
      final deliveryDateStr = order.value['deliveredAt'] ?? order.value['updatedAt'] ?? '';
      if (deliveryDateStr.toString().isEmpty) return false;
      
      DateTime? deliveryDate;
      try {
        // Handle numeric timestamp
        if (deliveryDateStr.toString().isNotEmpty && RegExp(r'^\d+$').hasMatch(deliveryDateStr.toString())) {
          final timestamp = int.parse(deliveryDateStr.toString());
          deliveryDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else {
          // Handle ISO date string
          deliveryDate = DateTime.parse(deliveryDateStr.toString());
        }
        
        switch (_tabController.index) {
          case 0: // Daily
            return deliveryDate.isAfter(today.subtract(const Duration(seconds: 1)));
          case 1: // Weekly
            return deliveryDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
          case 2: // Monthly
            return deliveryDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
          default:
            return true;
        }
      } catch (e) {
        return false;
      }
    }).toList();
  }
  
  String _formatDateTime(String dateString) {
    try {
      // Check if the date string is a numeric timestamp (milliseconds since epoch)
      if (dateString.isNotEmpty && RegExp(r'^\d+$').hasMatch(dateString)) {
        final timestamp = int.parse(dateString);
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return DateFormat('MMM d, yyyy hh:mm a').format(dateTime);
      } else {
        // Try to parse as ISO date string
        final dateTime = DateTime.parse(dateString);
        return DateFormat('MMM d, yyyy hh:mm a').format(dateTime);
      }
    } catch (e) {
      return dateString;
    }
  }
} 