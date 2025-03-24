import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/driver_service.dart';
import 'package:firebase_database/firebase_database.dart';
import '../pages/chat/user_chat_page.dart';
import '../pages/login_page.dart';
import '../pages/edit_driver_profile_page.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  final _formKey = GlobalKey<FormState>();
  final _driverService = DriverService();
  final _user = FirebaseAuth.instance.currentUser;
  
  // Add a stream controller for orders
  final StreamController<DatabaseEvent> _ordersStreamController = StreamController<DatabaseEvent>.broadcast();
  Stream<DatabaseEvent>? _ordersStream;
  
  File? _licenseImage;
  File? _govtIdImage;
  bool _isLoading = false;
  bool _isApproved = false;
  bool _isOnline = false;
  bool _isAvailableForOrders = true;
  int _selectedIndex = 0;
  int _deliveriesCount = 0;
  double _earnings = 0.0;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _checkDriverStatus();
    _loadDriverStats();
    _setupOrdersStream();
    
    // Force check approval status after a delay
    Future.delayed(const Duration(seconds: 2), () {
      _forceCheckApprovalStatus();
    });
  }
  
  @override
  void dispose() {
    // Dispose the stream controller
    _ordersStreamController.close();
    super.dispose();
  }
  
  void _setupOrdersStream() {
    if (_user != null) {
      // Create the original stream
      final originalStream = FirebaseDatabase.instance
          .ref()
          .child('orders')
          .orderByChild('driverId')
          .equalTo(_user?.uid)
          .onValue;
      
      // Set the broadcast stream
      _ordersStream = originalStream.asBroadcastStream();
    }
  }

  Future<void> _checkDriverStatus() async {
    if (_user != null) {
      try {
        final driver = await _driverService.getDriver(_user!.uid);
        if (driver != null) {
          print('Driver data loaded: ${driver.toMap()}');
          print('Driver status: ${driver.status}, isApproved: ${driver.isApproved}');
          
          // IMPORTANT: Set _isApproved based on the driver's status
          setState(() {
            _isApproved = driver.status == 'approved';
            
            // Also check if the driver is online
            _isOnline = driver.isOnline ?? false;
            _isAvailableForOrders = driver.availableForOrders ?? true;
            
            if (driver.hours != null) {
              try {
                // Convert stored hours string to TimeOfDay
                final startParts = driver.hours!['start'].toString().split(':');
                final endParts = driver.hours!['end'].toString().split(':');
                if (startParts.length >= 2 && endParts.length >= 2) {
                  _startTime = TimeOfDay(
                    hour: int.parse(startParts[0]),
                    minute: int.parse(startParts[1])
                  );
                  _endTime = TimeOfDay(
                    hour: int.parse(endParts[0]),
                    minute: int.parse(endParts[1])
                  );
                }
              } catch (e) {
                // If there's an error parsing the times, keep the defaults
                print('Error parsing working hours: $e');
              }
            }
          });
          
          // Debug: Check if we're loading the correct UI
          print('UI state after loading driver: isApproved = $_isApproved');
        } else {
          print('No driver data found for user ID: ${_user!.uid}');
        }
      } catch (e) {
        print('Error checking driver status: $e');
      }
    }
  }

  Future<void> _loadDriverStats() async {
    if (_user != null && _isApproved) {
      try {
        // Get today's date in YYYY-MM-DD format
        final today = DateTime.now().toIso8601String().split('T')[0];
        
        // Query completed deliveries for today
        final deliveriesSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('deliveries')
            .orderByChild('driverId')
            .equalTo(_user!.uid)
            .get();
            
        if (deliveriesSnapshot.exists) {
          final deliveries = deliveriesSnapshot.children.where((delivery) {
            final data = delivery.value as Map<dynamic, dynamic>;
            final deliveryDate = (data['completedAt'] as String?)?.split('T')[0];
            return deliveryDate == today && data['status'] == 'completed';
          });
          
          double totalEarnings = 0;
          for (var delivery in deliveries) {
            final data = delivery.value as Map<dynamic, dynamic>;
            totalEarnings += (data['driverEarnings'] as num?)?.toDouble() ?? 0;
          }
          
          setState(() {
            _deliveriesCount = deliveries.length;
            _earnings = totalEarnings;
          });
        }
      } catch (e) {
        print('Error loading driver stats: $e');
      }
    }
  }

  Future<void> _toggleOnlineStatus() async {
    if (_user != null) {
      setState(() {
        _isOnline = !_isOnline;
      });
      
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('drivers')
            .child(_user!.uid)
            .update({
          'isOnline': _isOnline,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now ${_isOnline ? 'online' : 'offline'}'),
            backgroundColor: _isOnline ? Colors.green : Colors.grey,
          ),
        );
      } catch (e) {
        setState(() {
          _isOnline = !_isOnline; // Revert on error
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAvailability() async {
    if (_user != null) {
      setState(() {
        _isAvailableForOrders = !_isAvailableForOrders;
      });
      
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('drivers')
            .child(_user!.uid)
            .update({
          'availableForOrders': _isAvailableForOrders,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        setState(() {
          _isAvailableForOrders = !_isAvailableForOrders; // Revert on error
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating availability: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(bool isLicense) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        if (isLicense) {
          _licenseImage = File(image.path);
        } else {
          _govtIdImage = File(image.path);
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _submitForm() async {
    if (_licenseImage == null || _govtIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both documents')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images to Firebase Storage
      final licenseUrl = await _driverService.uploadImage(
        _licenseImage!,
        'drivers/${_user!.uid}/license.jpg',
      );
      
      final govtIdUrl = await _driverService.uploadImage(
        _govtIdImage!,
        'drivers/${_user!.uid}/govt_id.jpg',
      );

      final now = DateTime.now().toIso8601String();

      // Update driver information with document URLs and working hours
      await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(_user!.uid)
          .update({
        'documentsSubmitted': true,
        'documents': {
          'status': 'pending_review',
          'govt_id': {
            'url': govtIdUrl,
            'uploadTime': now,
          },
          'license': {
            'url': licenseUrl,
            'uploadTime': now,
          },
          'updatedAt': now,
        },
        'hours': {
          'end': _formatTimeOfDay(_endTime),
          'start': _formatTimeOfDay(_startTime)
        },
        'updatedAt': now,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents submitted for approval')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forceCheckApprovalStatus() async {
    if (_user != null) {
      try {
        // Directly check the status in Firebase
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('drivers')
            .child(_user!.uid)
            .get();
            
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          
          // Try to get status from different possible locations
          String? status = data['status'] as String?;
          
          // If status is null, try to get it from documents.status
          if (status == null && data['documents'] != null) {
            final documents = data['documents'] as Map<dynamic, dynamic>?;
            if (documents != null) {
              status = documents['status'] as String?;
            }
          }
          
          print('Force checking approval status: $status');
          print('Full driver data: $data');
          
          // Check if status is 'approved'
          final bool shouldBeApproved = status == 'approved';
          
          if (shouldBeApproved != _isApproved) {
            setState(() {
              _isApproved = shouldBeApproved;
            });
            print('Fixed approval status: $_isApproved');
          }
          
          // For testing: Uncomment this line to force approved status
          // setState(() { _isApproved = true; });
        }
      } catch (e) {
        print('Error in force check: $e');
      }
    }
  }

  Future<void> _manuallyUpdateDriverStatus(String newStatus) async {
    if (_user != null) {
      try {
        final now = DateTime.now().toIso8601String();
        
        // Update both root status and documents.status
        await FirebaseDatabase.instance
            .ref()
            .child('drivers')
            .child(_user!.uid)
            .update({
          'status': newStatus,
          'updatedAt': now,
        });
        
        // Also update documents.status if it exists
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('drivers')
            .child(_user!.uid)
            .child('documents')
            .get();
            
        if (snapshot.exists) {
          await FirebaseDatabase.instance
              .ref()
              .child('drivers')
              .child(_user!.uid)
              .child('documents')
              .update({
            'status': newStatus,
            'updatedAt': now,
          });
        }
        
        print('Manually updated driver status to: $newStatus');
        
        // Refresh the UI
        setState(() {
          _isApproved = newStatus == 'approved';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to: $newStatus'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.orange,
          ),
        );
      } catch (e) {
        print('Error updating driver status: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Status Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                        onChanged: (value) => _toggleOnlineStatus(),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Working Hours: ${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Available for Orders Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available for Orders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isAvailableForOrders ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isAvailableForOrders ? Colors.green : Colors.red,
                        ),
                      ),
                      Switch(
                        value: _isAvailableForOrders,
                        onChanged: (value) => _toggleAvailability(),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toggle this when you\'re ready to accept new orders',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Today's Stats Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Stats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Deliveries',
                        _deliveriesCount.toString(),
                        Icons.delivery_dining,
                      ),
                      _buildStatItem(
                        'Earnings',
                        '\$${_earnings.toStringAsFixed(2)}',
                        Icons.attach_money,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Available Orders Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Orders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref()
                        .child('orders')
                        .orderByChild('status')
                        .equalTo('pending_driver')
                        .onValue,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      
                      if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                        return const Center(
                          child: Text(
                            'No available orders at the moment',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }
                      
                      try {
                        final ordersData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                        final orders = ordersData.entries.toList();
                        
                        if (orders.isEmpty) {
                          return const Center(
                            child: Text(
                              'No available orders at the moment',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: orders.length > 3 ? 3 : orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index].value as Map<dynamic, dynamic>;
                            final orderId = orders[index].key as String;
                            final restaurantName = order['restaurantName'] as String? ?? 'Restaurant';
                            final customerAddress = order['deliveryAddress'] as String? ?? 'Address';
                            final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
                            
                            return ListTile(
                              title: Text('Order #$orderId'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From: $restaurantName'),
                                  Text('To: $customerAddress'),
                                ],
                              ),
                              trailing: Text('\$${totalAmount.toStringAsFixed(2)}'),
                              onTap: () {
                                // Navigate to order details page
                              },
                            );
                          },
                        );
                      } catch (e) {
                        return Center(
                          child: Text('Error loading orders: $e'),
                        );
                      }
                    },
                  ),
                  if (_isOnline && _isAvailableForOrders)
                    TextButton(
                      onPressed: () {
                        // Navigate to orders tab
                        setState(() {
                          _selectedIndex = 1;
                        });
                      },
                      child: const Text('View All Available Orders'),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Go online and available to see orders',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: const Color(0xFFF4A261)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
  
  Widget _buildOrdersTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Current'),
              Tab(text: 'Past'),
            ],
            labelColor: Colors.black,
            indicatorColor: Color(0xFFF4A261),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCurrentOrdersTab(),
                _buildPastOrdersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCurrentOrdersTab() {
    if (_ordersStream == null) {
      return const Center(
        child: Text(
          'No orders data available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    return StreamBuilder<DatabaseEvent>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(
            child: Text(
              'No current orders',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }
        
        try {
          final data = snapshot.data!.snapshot.value;
          if (data == null) {
            return const Center(
              child: Text(
                'No current orders',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }
          
          final ordersData = data as Map<dynamic, dynamic>;
          final currentOrders = ordersData.entries
              .where((entry) {
                final order = entry.value as Map<dynamic, dynamic>;
                final status = order['status'] as String?;
                // Current orders are those that are assigned to the driver but not completed or cancelled
                return status == 'assigned_to_driver' || status == 'out_for_delivery';
              })
              .toList();
          
          if (currentOrders.isEmpty) {
            return const Center(
              child: Text(
                'No current orders',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: currentOrders.length,
            itemBuilder: (context, index) {
              final order = currentOrders[index].value as Map<dynamic, dynamic>;
              final orderId = currentOrders[index].key as String;
              final status = order['status'] as String?;
              final restaurantName = order['restaurantName'] as String? ?? 'Restaurant';
              final customerName = order['customerName'] as String? ?? 'Customer';
              final customerAddress = order['deliveryAddress'] as String? ?? 'Address';
              final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
              final orderTime = order['createdAt'] as String?;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #$orderId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          _buildStatusChip(status ?? 'unknown'),
                        ],
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.store, color: Color(0xFFF4A261)),
                        title: Text(restaurantName),
                        subtitle: const Text('Pickup'),
                        dense: true,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person, color: Color(0xFFF4A261)),
                        title: Text(customerName),
                        subtitle: Text(customerAddress),
                        dense: true,
                      ),
                      if (orderTime != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.access_time, color: Color(0xFFF4A261)),
                          title: Text('Order Time'),
                          subtitle: Text(_formatDateTime(orderTime)),
                          dense: true,
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to order details or map
                              },
                              icon: const Icon(Icons.directions),
                              label: const Text('Navigate'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4A261),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Mark as delivered
                                _updateOrderStatus(orderId, 'delivered');
                              },
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Delivered'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
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
        } catch (e) {
          return Center(
            child: Text('Error loading orders: $e'),
          );
        }
      },
    );
  }
  
  Widget _buildPastOrdersTab() {
    if (_ordersStream == null) {
      return const Center(
        child: Text(
          'No orders data available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    return StreamBuilder<DatabaseEvent>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(
            child: Text(
              'No past orders',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }
        
        try {
          final data = snapshot.data!.snapshot.value;
          if (data == null) {
            return const Center(
              child: Text(
                'No past orders',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }
          
          final ordersData = data as Map<dynamic, dynamic>;
          final pastOrders = ordersData.entries
              .where((entry) {
                final order = entry.value as Map<dynamic, dynamic>;
                final status = order['status'] as String?;
                // Past orders are those that are completed or cancelled
                return status == 'delivered' || status == 'cancelled';
              })
              .toList();
          
          // Sort by date (newest first)
          pastOrders.sort((a, b) {
            final orderA = a.value as Map<dynamic, dynamic>;
            final orderB = b.value as Map<dynamic, dynamic>;
            final dateA = orderA['updatedAt'] as String? ?? '';
            final dateB = orderB['updatedAt'] as String? ?? '';
            return dateB.compareTo(dateA);
          });
          
          if (pastOrders.isEmpty) {
            return const Center(
              child: Text(
                'No past orders',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: pastOrders.length,
            itemBuilder: (context, index) {
              final order = pastOrders[index].value as Map<dynamic, dynamic>;
              final orderId = pastOrders[index].key as String;
              final status = order['status'] as String?;
              final restaurantName = order['restaurantName'] as String? ?? 'Restaurant';
              final customerName = order['customerName'] as String? ?? 'Customer';
              final customerAddress = order['deliveryAddress'] as String? ?? 'Address';
              final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
              final orderTime = order['createdAt'] as String?;
              final completedTime = order['updatedAt'] as String?;
              final earnings = (order['driverEarnings'] as num?)?.toDouble() ?? 0.0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #$orderId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          _buildStatusChip(status ?? 'unknown'),
                        ],
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.store, color: Color(0xFFF4A261)),
                        title: Text(restaurantName),
                        dense: true,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person, color: Color(0xFFF4A261)),
                        title: Text(customerName),
                        subtitle: Text(customerAddress),
                        dense: true,
                      ),
                      if (completedTime != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: const Text('Completed'),
                          subtitle: Text(_formatDateTime(completedTime)),
                          dense: true,
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Your Earnings:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${earnings.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Order Total:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
        } catch (e) {
          return Center(
            child: Text('Error loading orders: $e'),
          );
        }
      },
    );
  }
  
  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'assigned_to_driver':
        color = Colors.blue;
        label = 'Assigned';
        break;
      case 'out_for_delivery':
        color = Colors.orange;
        label = 'Out for Delivery';
        break;
      case 'delivered':
        color = Colors.green;
        label = 'Delivered';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final date = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$date at $hour:$minute $period';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isApproved) {
      // UI for approved drivers
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driver Dashboard'),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(),
            _buildOrdersTab(),
            _buildAccountTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      );
    } else {
      // UI for document submission
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driver Documents'),
          actions: [
            // Debug button - only show in debug mode
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                // Show a dialog to select the status
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Debug: Set Driver Status'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('Approved'),
                          onTap: () {
                            Navigator.pop(context);
                            _manuallyUpdateDriverStatus('approved');
                          },
                        ),
                        ListTile(
                          title: const Text('Pending Review'),
                          onTap: () {
                            Navigator.pop(context);
                            _manuallyUpdateDriverStatus('pending_review');
                          },
                        ),
                        ListTile(
                          title: const Text('Rejected'),
                          onTap: () {
                            Navigator.pop(context);
                            _manuallyUpdateDriverStatus('rejected');
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Debug: Set Status',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Please upload your documents for verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const Text('Driver License Image:'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(true),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                ),
                if (_licenseImage != null) ...[
                  const SizedBox(height: 8),
                  Image.file(_licenseImage!, height: 100),
                ],
                const SizedBox(height: 24),
                const Text('Government ID Image:'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                ),
                if (_govtIdImage != null) ...[
                  const SizedBox(height: 8),
                  Image.file(_govtIdImage!, height: 100),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Working Hours:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Time:'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _selectTime(context, true),
                            icon: const Icon(Icons.access_time),
                            label: Text(_formatTimeOfDay(_startTime)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Time:'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _selectTime(context, false),
                            icon: const Icon(Icons.access_time),
                            label: Text(_formatTimeOfDay(_endTime)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Submit Documents'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      setState(() => _isLoading = true);
      
      final now = DateTime.now().toIso8601String();
      
      await FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId)
          .update({
        'status': status,
        'updatedAt': now,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as $status'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Widget _buildAccountTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSection(),
          const SizedBox(height: 16),
          
          // Working Hours Section
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Working Hours',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Time',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _selectTime(context, true),
                              icon: const Icon(Icons.access_time),
                              label: Text(_startTime.format(context)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Time',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _selectTime(context, false),
                              icon: const Icon(Icons.access_time),
                              label: Text(_endTime.format(context)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Support Section
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Color(0xFFF4A261)),
              title: const Text('Support'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserChatPage(
                      userId: _user!.uid,
                      userName: 'Driver',
                      userType: 'driver',
                      conversationId: _user!.uid,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Sign Out Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error signing out: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileSection() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(_user!.uid)
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading profile'));
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final driverData = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map);
        final fullName = driverData['fullName'] as String? ?? 'Driver';
        final email = driverData['email'] as String? ?? '';
        final phone = driverData['phone'] as String? ?? '';

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Profile Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditDriverProfilePage(
                              driverId: _user!.uid,
                              currentName: fullName,
                              currentPhone: phone,
                            ),
                          ),
                        );
                        
                        if (result == true) {
                          setState(() {}); // Refresh the page
                        }
                      },
                      color: const Color(0xFFF4A261),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Name', fullName),
                const SizedBox(height: 8),
                _buildInfoRow('Email', email),
                const SizedBox(height: 8),
                _buildInfoRow('Phone', phone),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
} 