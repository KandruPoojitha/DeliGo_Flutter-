import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:math';

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
    final now = DateTime.now();
    switch (_tabController.index) {
      case 0:
        return DateFormat('MMM d, yyyy').format(now); // Today's date
      case 1:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        return '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d, yyyy').format(endOfWeek)}';
      case 2:
        return DateFormat('MMMM yyyy').format(now); // Current month and year
      default:
        return DateFormat('MMM d, yyyy').format(now);
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
                  return _buildLoadingState();
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  print('DEBUG: No data in snapshot or snapshot value is null');
                  print('DEBUG: Current user ID: ${_auth.currentUser?.uid}');
                  return _buildEmptyState('No order history found');
                }
                
                final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                print('DEBUG: Total orders found: ${data.length}');
                
                // Print details of each order to debug
                data.forEach((key, value) {
                  final orderData = value as Map<dynamic, dynamic>;
                  final driverId = orderData['driverId'];
                  final status = orderData['status'];
                  final orderStatus = orderData['order_status'];
                  
                  print('DEBUG: Order $key - driverId: $driverId, status: $status, order_status: $orderStatus');
                });
                
                // First check: just get all orders for this driver, regardless of status
                final allDriverOrders = data.entries
                    .where((order) => order.value['driverId'] == _auth.currentUser?.uid)
                    .toList();
                    
                print('DEBUG: All orders for this driver: ${allDriverOrders.length}');
                
                // Now filter for delivered status, but be more lenient
                final deliveredOrders = data.entries
                    .where((order) => 
                        order.value['driverId'] == _auth.currentUser?.uid &&
                        ((order.value['order_status'] == 'delivered' || 
                          order.value['order_status'] == 'completed' ||
                          order.value['status'] == 'delivered' ||
                          order.value['status'] == 'completed')))
                    .toList();
                
                print('DEBUG: Delivered orders for this driver: ${deliveredOrders.length}');
                
                if (deliveredOrders.isEmpty) {
                  return _buildEmptyState('No delivered orders yet');
                }
                
                // Filter based on selected tab
                final filteredOrders = _filterOrdersByTab(deliveredOrders);
                
                // Calculate totals
                _totalEarnings = 0.0;
                _totalDeliveryFees = 0.0;
                _totalTips = 0.0;
                _deliveriesCompleted = filteredOrders.length;
                
                for (var order in filteredOrders) {
                  try {
                    final orderData = order.value as Map<dynamic, dynamic>;
                    
                    // Get delivery fee
                    double deliveryFee = 0.0;
                    if (orderData.containsKey('deliveryFee') && orderData['deliveryFee'] != null) {
                      deliveryFee = (orderData['deliveryFee'] is num) ? 
                          (orderData['deliveryFee'] as num).toDouble() : 0.0;
                    } else if (orderData.containsKey('delivery_fee') && orderData['delivery_fee'] != null) {
                      deliveryFee = (orderData['delivery_fee'] is num) ? 
                          (orderData['delivery_fee'] as num).toDouble() : 0.0;
                    } else if (orderData.containsKey('driverEarnings') && orderData['driverEarnings'] != null) {
                      // If we have total driver earnings but no breakdown, use that as delivery fee
                      deliveryFee = (orderData['driverEarnings'] is num) ?
                          (orderData['driverEarnings'] as num).toDouble() : 0.0;
                    } else if (orderData.containsKey('total') && orderData['total'] != null) {
                      // Last resort: if we have total, use a portion of that
                      final orderTotal = (orderData['total'] is num) ?
                          (orderData['total'] as num).toDouble() : 0.0;
                      deliveryFee = orderTotal * 0.15; // Assume 15% as delivery fee
                    }
                    
                    // Get tip amount
                    double tipAmount = 0.0;
                    if (orderData.containsKey('tipAmount') && orderData['tipAmount'] != null) {
                      tipAmount = (orderData['tipAmount'] is num) ? 
                          (orderData['tipAmount'] as num).toDouble() : 0.0;
                    } else if (orderData.containsKey('tip') && orderData['tip'] != null) {
                      tipAmount = (orderData['tip'] is num) ? 
                          (orderData['tip'] as num).toDouble() : 0.0;
                    }
                    
                    // Calculate total earnings for this order
                    final total = deliveryFee + tipAmount;
                    
                    // Print debug info for this order
                    print('DEBUG: Order earnings - deliveryFee: $deliveryFee, tip: $tipAmount, total: $total');
                    
                    // Add to totals
                    _totalDeliveryFees += deliveryFee;
                    _totalTips += tipAmount;
                    _totalEarnings += deliveryFee + tipAmount;
                  } catch (e) {
                    print('Error calculating earnings for order: $e');
                  }
                }
                
                // If we have orders but no earnings, something might be wrong with the data
                if (filteredOrders.isNotEmpty && _totalEarnings <= 0) {
                  return Column(
                    children: [
                      Card(
                        margin: const EdgeInsets.all(16),
                        color: Colors.amber[100],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Debug Info',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Found ${filteredOrders.length} orders'),
                              Text('Total calculated earnings: \$${_totalEarnings.toStringAsFixed(2)}'),
                              Text('Delivery fees: \$${_totalDeliveryFees.toStringAsFixed(2)}'),
                              Text('Tips: \$${_totalTips.toStringAsFixed(2)}'),
                              const SizedBox(height: 8),
                              const Text(
                                'Possible issues:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text('- Orders missing payment information'),
                              const Text('- Fields named differently in database'),
                              const Text('- Type conversion errors'),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            final orderId = order.key;
                            final orderData = order.value as Map<dynamic, dynamic>;
                            
                            // Build a debug card for this order
                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order ID: $orderId',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const Divider(),
                                    ...orderData.entries.map((entry) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text('${entry.key}: ${entry.value}'),
                                      );
                                    }).take(10).toList(),
                                    if (orderData.entries.length > 10)
                                      Text('... and ${orderData.entries.length - 10} more fields'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }
                
                // Sort orders by date (most recent first)
                filteredOrders.sort((a, b) {
                  try {
                    final aCreationTime = a.value['createdAt'] ?? a.value['timestamp'] ?? '';
                    final bCreationTime = b.value['createdAt'] ?? b.value['timestamp'] ?? '';
                    
                    // Parse timestamps to DateTime for comparison
                    DateTime? aTime, bTime;
                    
                    // For first timestamp
                    if (aCreationTime.toString().isNotEmpty) {
                      if (RegExp(r'^\d+$').hasMatch(aCreationTime.toString())) {
                        aTime = DateTime.fromMillisecondsSinceEpoch(int.parse(aCreationTime.toString()));
                      } else {
                        aTime = DateTime.parse(aCreationTime.toString());
                      }
                    }
                    
                    // For second timestamp
                    if (bCreationTime.toString().isNotEmpty) {
                      if (RegExp(r'^\d+$').hasMatch(bCreationTime.toString())) {
                        bTime = DateTime.fromMillisecondsSinceEpoch(int.parse(bCreationTime.toString()));
                      } else {
                        bTime = DateTime.parse(bCreationTime.toString());
                      }
                    }
                    
                    // If both valid, compare them
                    if (aTime != null && bTime != null) {
                      return bTime.compareTo(aTime); // Most recent first
                    }
                    
                    // Fallback to string comparison if DateTime parsing fails
                    return bCreationTime.toString().compareTo(aCreationTime.toString());
                  } catch (e) {
                    print('Error sorting orders: $e');
                    return 0;
                  }
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _periodLabel,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '$_deliveriesCompleted ${_deliveriesCompleted == 1 ? 'delivery' : 'deliveries'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
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
                            const SizedBox(height: 8),
                            Text(
                              'Total Earnings',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
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
                                  crossAxisAlignment: CrossAxisAlignment.end,
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
                          
                          // Get delivery fee
                          double deliveryFee = 0.0;
                          if (orderData.containsKey('deliveryFee') && orderData['deliveryFee'] != null) {
                            deliveryFee = (orderData['deliveryFee'] is num) ? 
                                (orderData['deliveryFee'] as num).toDouble() : 0.0;
                          } else if (orderData.containsKey('delivery_fee') && orderData['delivery_fee'] != null) {
                            deliveryFee = (orderData['delivery_fee'] is num) ? 
                                (orderData['delivery_fee'] as num).toDouble() : 0.0;
                          } else if (orderData.containsKey('driverEarnings') && orderData['driverEarnings'] != null) {
                            // If we have total driver earnings but no breakdown, use that as delivery fee
                            deliveryFee = (orderData['driverEarnings'] is num) ?
                                (orderData['driverEarnings'] as num).toDouble() : 0.0;
                          } else if (orderData.containsKey('total') && orderData['total'] != null) {
                            // Last resort: if we have total, use a portion of that
                            final orderTotal = (orderData['total'] is num) ?
                                (orderData['total'] as num).toDouble() : 0.0;
                            deliveryFee = orderTotal * 0.15; // Assume 15% as delivery fee
                          }
                          
                          // Get tip amount
                          double tipAmount = 0.0;
                          if (orderData.containsKey('tipAmount') && orderData['tipAmount'] != null) {
                            tipAmount = (orderData['tipAmount'] is num) ? 
                                (orderData['tipAmount'] as num).toDouble() : 0.0;
                          } else if (orderData.containsKey('tip') && orderData['tip'] != null) {
                            tipAmount = (orderData['tip'] is num) ? 
                                (orderData['tip'] as num).toDouble() : 0.0;
                          }
                          
                          // Calculate total earnings for this order
                          final total = deliveryFee + tipAmount;
                          
                          // Format creation time
                          String formattedCreationTime = 'Unknown';
                          final creationTime = orderData['createdAt'] ?? orderData['timestamp'] ?? '';
                          if (creationTime.toString().isNotEmpty) {
                            try {
                              DateTime createdAt;
                              if (RegExp(r'^\d+$').hasMatch(creationTime.toString())) {
                                createdAt = DateTime.fromMillisecondsSinceEpoch(int.parse(creationTime.toString()));
                              } else {
                                createdAt = DateTime.parse(creationTime.toString());
                              }
                              formattedCreationTime = DateFormat('MMM d, yyyy h:mm a').format(createdAt);
                            } catch (e) {
                              print('Error formatting creation time: $e');
                            }
                          }
                          
                          // Get restaurant name if available
                          String restaurantName = 'Order';
                          if (orderData.containsKey('restaurantName') && orderData['restaurantName'] != null) {
                            restaurantName = orderData['restaurantName'].toString();
                          }
                          
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          restaurantName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.receipt_outlined, size: 12, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Order #${orderId.toString().substring(0, min(8, orderId.toString().length))}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        formattedCreationTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
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
    
    print('DEBUG: Filtering ${orders.length} orders for tab: ${_tabController.index}');
    print('DEBUG: Today: $today, Week start: $startOfWeek, Month start: $startOfMonth');
    
    final filteredOrders = orders.where((order) {
      final orderId = order.key;
      // Use createdAt instead of deliveredAt for filtering
      final creationDateStr = order.value['createdAt'] ?? order.value['timestamp'] ?? '';
      if (creationDateStr.toString().isEmpty) {
        print('DEBUG: Order $orderId skipped - no creation date');
        return false;
      }
      
      DateTime? creationDate;
      try {
        // Handle numeric timestamp
        if (creationDateStr.toString().isNotEmpty && RegExp(r'^\d+$').hasMatch(creationDateStr.toString())) {
          final timestamp = int.parse(creationDateStr.toString());
          creationDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else {
          // Handle ISO date string
          creationDate = DateTime.parse(creationDateStr.toString());
        }
        
        bool included = false;
        switch (_tabController.index) {
          case 0: // Daily
            included = creationDate.isAfter(today.subtract(const Duration(seconds: 1)));
            break;
          case 1: // Weekly
            included = creationDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
            break;
          case 2: // Monthly
            included = creationDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
            break;
          default:
            included = true;
        }
        
        if (included) {
          print('DEBUG: Including order $orderId with date $creationDate');
        } else {
          print('DEBUG: Filtering out order $orderId with date $creationDate');
        }
        
        return included;
      } catch (e) {
        print('DEBUG: Error parsing date: $e for order $orderId with date: $creationDateStr');
        return false;
      }
    }).toList();
    
    print('DEBUG: Filtered to ${filteredOrders.length} orders');
    return filteredOrders;
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
  
  // Widget to display when loading data
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading earnings data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget to display when no data is available
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here after delivery',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 