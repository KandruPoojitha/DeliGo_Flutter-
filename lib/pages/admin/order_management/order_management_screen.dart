import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../../widgets/unread_message_count.dart';
import '../../../pages/order_chat_page.dart';
import '../../../pages/restaurant_page.dart';
// import '../../../pages/chat/order_group_chat_dialog.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({Key? key}) : super(key: key);

  @override
  _OrderManagementScreenState createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final _database = FirebaseDatabase.instance;
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusOptions = [
    'All',
    'pending',
    'accepted',
    'assigned_driver',
    'driver_accepted',
    'picked_up',
    'delivered',
    'cancelled'
  ];

  final Map<String, int> _statusOrder = {
    'pending': 0,
    'accepted': 1,
    'assigned_driver': 2,
    'driver_accepted': 3,
    'picked_up': 4,
    'delivered': 5,
    'cancelled': -1,
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime dateTime;
    if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Invalid Date';
      }
    } else {
      return 'Invalid Date';
    }

    return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'assigned_driver':
        return Colors.indigo;
      case 'driver_accepted':
        return Colors.purple;
      case 'picked_up':
        return Colors.deepPurple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getDisplayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'assigned_driver':
        return 'Driver Assigned';
      case 'driver_accepted':
        return 'Driver Accepted';
      case 'picked_up':
        return 'Picked Up';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by Order ID or Customer Name',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusOptions.map((status) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status == 'All' ? status : _getDisplayStatus(status)),
                          selected: _selectedStatus == status,
                          selectedColor: status != 'All' ? _getStatusColor(status).withOpacity(0.7) : null,
                          onSelected: (selected) {
                            setState(() {
                              _selectedStatus = status;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _database.ref('orders').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(
                    child: Text('No orders found'),
                  );
                }

                Map<dynamic, dynamic> ordersMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                List<Map<String, dynamic>> orders = [];

                ordersMap.forEach((key, value) {
                  final orderData = value as Map<dynamic, dynamic>;
                  orders.add({
                    'id': key,
                    ...Map<String, dynamic>.from(orderData as Map),
                  });
                });

                // Filter by status
                if (_selectedStatus != 'All') {
                  orders = orders
                      .where((order) => order['order_status'] == _selectedStatus)
                      .toList();
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  orders = orders.where((order) {
                    return order['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        (order['customerName']?.toString()?.toLowerCase()?.contains(_searchQuery.toLowerCase()) ?? false);
                  }).toList();
                }

                // Sort by most recent first
                orders.sort((a, b) {
                  final aTime = a['createdAt'] ?? 0;
                  final bTime = b['createdAt'] ?? 0;
                  return bTime.compareTo(aTime);
                });

                if (orders.isEmpty) {
                  return const Center(
                    child: Text('No orders match your filters'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final status = order['order_status'] ?? 'pending';
                    final total = order['total'] != null
                        ? (order['total'] as num).toDouble()
                        : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          ListTile(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #${order['id'].toString().substring(0, 8)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Chip(
                                      label: Text(
                                        _getDisplayStatus(status),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: _getStatusColor(status),
                                    ),
                                  ],
                                ),
                                Text('Customer: ${order['customerName'] ?? 'Unknown'}'),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${_formatTimestamp(order['createdAt'])}'),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: ${_formatCurrency(total)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: () => _showOrderDetails(order),
                            ),
                            onTap: () => _showOrderDetails(order),
                          ),
                          if (status != 'cancelled')
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: _buildStatusTracker(status),
                            ),
                        ],
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

  Widget _buildStatusTracker(String currentStatus) {
    final currentStep = _statusOrder[currentStatus] ?? 0;

    return Row(
      children: [
        for (int i = 0; i < 6; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= currentStep
                        ? _getStatusColor(_statusOptions[i + 1])
                        : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 4),
                if (i < 5)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Container(
                      height: 2,
                      color: i < currentStep
                          ? _getStatusColor(_statusOptions[i + 2])
                          : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              if (order['order_status'] != 'cancelled')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Status Flow',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusTracker(order['order_status'] ?? 'pending'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pending', style: TextStyle(fontSize: 10)),
                          const Text('Accepted', style: TextStyle(fontSize: 10)),
                          Expanded(
                            child: Text('Assigned',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10)
                            ),
                          ),
                          Expanded(
                            child: Text('Driver Accepted',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 9)
                            ),
                          ),
                          const Text('Picked Up', style: TextStyle(fontSize: 10)),
                          const Text('Delivered', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Order ID'),
                      subtitle: Text(order['id'] ?? 'N/A'),
                    ),
                    ListTile(
                      title: const Text('Customer'),
                      subtitle: Text(order['customerName'] ?? 'Unknown'),
                    ),
                    ListTile(
                      title: const Text('Order Status'),
                      subtitle: Chip(
                        label: Text(
                          _getDisplayStatus(order['order_status'] ?? 'pending'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: _getStatusColor(order['order_status'] ?? 'pending'),
                      ),
                    ),
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(_formatTimestamp(order['createdAt'])),
                    ),
                    ListTile(
                      title: const Text('Delivery Option'),
                      subtitle: Text(order['deliveryOption'] ?? 'N/A'),
                    ),
                    if (order['address'] != null) ...[
                      ListTile(
                        title: const Text('Delivery Address'),
                        subtitle: Text(
                            '${order['address']['street']}, ${order['address']['unit'] ?? ''}'
                        ),
                      ),
                    ],
                    if (order['driverId'] != null) ...[
                      ListTile(
                        title: const Text('Driver'),
                        subtitle: Text(order['driverName'] ?? 'Unknown Driver'),
                      ),
                    ],
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'Order Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (order['items'] != null) ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (order['items'] as List).length,
                        itemBuilder: (context, index) {
                          final item = (order['items'] as List)[index];
                          return ListTile(
                            title: Text(item['name'] ?? 'Unknown Item'),
                            subtitle: Text('Quantity: ${item['quantity']}'),
                            trailing: Text(_formatCurrency((item['totalPrice'] as num).toDouble())),
                          );
                        },
                      ),
                    ],
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal'),
                              Text(_formatCurrency((order['subtotal'] as num?)?.toDouble() ?? 0.0)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount'),
                              Text('-${_formatCurrency((order['discountAmount'] as num?)?.toDouble() ?? 0.0)}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Fee'),
                              Text(_formatCurrency((order['deliveryFee'] as num?)?.toDouble() ?? 0.0)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tip'),
                              Text(_formatCurrency((order['tipAmount'] as num?)?.toDouble() ?? 0.0)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _formatCurrency((order['total'] as num?)?.toDouble() ?? 0.0),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payment Method'),
                              Text(order['paymentMethod'] ?? 'N/A'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payment Status'),
                              Text(order['paymentStatus'] ?? 'pending'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (order['order_status'] == 'delivered') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // One-on-one chat button
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat, size: 20),
                                onPressed: () {
                                  final customerId = order['customerId'] ?? order['userId'] ?? '';
                                  final customerName = order['customerName'] ?? 'Customer';
                                  final restaurantId = order['restaurantId'] ?? '';

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrderChatPage(
                                        orderId: order['id'],
                                        restaurantId: restaurantId,
                                        restaurantName: 'Admin',
                                        customerName: customerName,
                                        userType: 'admin',
                                      ),
                                    ),
                                  );
                                },
                                tooltip: 'Chat with Customer',
                                color: const Color(0xFFF4A261),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: UnreadMessageCount(
                                  orderId: order['id'],
                                  userType: 'admin',
                                ),
                              ),
                            ],
                          ),
                          // Group chat button
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.group, size: 20),
                                onPressed: () async {
                                  final restaurantId = order['restaurantId'] ?? '';

                                  // Get restaurant name from store_info
                                  final storeInfoSnapshot = await FirebaseDatabase.instance
                                      .ref()
                                      .child('restaurants')
                                      .child(restaurantId)
                                      .child('store_info')
                                      .child('name')
                                      .get();

                                  final restaurantName = storeInfoSnapshot.value?.toString() ?? 'Restaurant';
                                  final customerName = order['customerName'] ?? 'Customer';
                                  final driverName = order['driverName'] ?? 'Driver';

                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => OrderGroupChatDialog(
                                        orderId: order['id'],
                                        restaurantId: restaurantId,
                                        restaurantName: restaurantName,
                                        customerName: customerName,
                                        driverName: driverName,
                                        senderType: 'admin',
                                      ),
                                    );
                                  }
                                },
                                tooltip: 'Group Chat',
                                color: Colors.purple,
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: UnreadMessageCount(
                                  orderId: order['id'],
                                  userType: 'admin',
                                  isGroupChat: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton(
                      onPressed: () => _updateOrderStatus(order),
                      child: const Text('Update Order Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
  }

  void _updateOrderStatus(Map<String, dynamic> order) {
    String selectedStatus = order['order_status'] ?? 'pending';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Order Status'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: _statusOptions.where((status) => status != 'All').map((status) {
                  return RadioListTile<String>(
                    title: Text(_getDisplayStatus(status)),
                    value: status,
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _database.ref('orders/${order['id']}').update({
                    'order_status': selectedStatus,
                    'updatedAt': ServerValue.timestamp,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order status updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating order status: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
} 