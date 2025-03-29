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
import '../pages/tip_history_screen.dart';
import '../pages/earnings_screen.dart';

class DriverPage extends StatefulWidget {
  const DriverPage({super.key});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  final _formKey = GlobalKey<FormState>();
  final _driverService = DriverService();
  final _user = FirebaseAuth.instance.currentUser;
  
  // Separate streams for current and past orders
  Stream<DatabaseEvent>? _currentOrdersStream;
  Stream<DatabaseEvent>? _pastOrdersStream;
  
  File? _licenseImage;
  File? _govtIdImage;
  bool _isLoading = false;
  bool _isApproved = false;
  bool _isOnline = false;
  bool _isAvailable = true;
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
    _setupOrdersStreams();
    
    // Force check approval status after a delay
    Future.delayed(const Duration(seconds: 2), () {
      _forceCheckApprovalStatus();
    });
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  void _setupOrdersStreams() {
    if (_user != null) {
      // Create separate streams for current and past orders
      _currentOrdersStream = FirebaseDatabase.instance
          .ref()
          .child('orders')
          .orderByChild('driverId')
          .equalTo(_user!.uid)
          .onValue;
          
      _pastOrdersStream = FirebaseDatabase.instance
          .ref()
          .child('orders')
          .orderByChild('driverId')
          .equalTo(_user!.uid)
          .onValue;
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
            _isAvailable = driver.isAvailable ?? true;
            
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
        _isAvailable = !_isAvailable;
      });
      
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('drivers')
            .child(_user!.uid)
            .update({
          'isAvailable': _isAvailable,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        setState(() {
          _isAvailable = !_isAvailable; // Revert on error
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
    return Column(
        children: [
          // Driver Status Card
          Card(
          margin: const EdgeInsets.all(16),
            child: Padding(
            padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                      'Status: ${_isOnline ? 'Online' : 'Offline'}',
                        style: TextStyle(
                        color: _isOnline ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: _isOnline,
                      onChanged: _isApproved ? (value) async {
                        setState(() => _isOnline = value);
                        await _driverService.updateDriverStatus(
                          _user!.uid,
                          isOnline: value,
                        );
                      } : null,
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                if (_isApproved) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available for Orders: ${_isAvailable ? 'Yes' : 'No'}',
                        style: TextStyle(
                          color: _isAvailable ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: _isOnline ? (value) async {
                          setState(() => _isAvailable = value);
                          await _driverService.updateDriverStatus(
                            _user!.uid,
                            isAvailable: value,
                          );
                        } : null,
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ],
                ],
              ),
            ),
          ),

          // Today's Stats Card
          StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref()
                .child('orders')
                .orderByChild('driverId')
                .equalTo(_user!.uid)
                .onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading stats'));
              }

              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                return _buildEmptyStatsCard();
              }

              try {
                final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                // Filter today's delivered orders
                final todayOrders = data.entries.where((entry) {
                  final order = entry.value as Map<dynamic, dynamic>;
                  if (order['order_status'] != 'delivered') return false;

                  // Parse the delivery timestamp
                  final deliveryTime = order['deliveredAt'] ?? order['updatedAt'] ?? '';
                  if (deliveryTime.toString().isEmpty) return false;

                  DateTime? deliveryDate;
                  try {
                    if (deliveryTime.toString().isNotEmpty && RegExp(r'^\d+$').hasMatch(deliveryTime.toString())) {
                      deliveryDate = DateTime.fromMillisecondsSinceEpoch(int.parse(deliveryTime.toString()));
                    } else {
                      deliveryDate = DateTime.parse(deliveryTime.toString());
                    }
                    return deliveryDate.isAfter(today.subtract(const Duration(seconds: 1)));
                  } catch (e) {
                    return false;
                  }
                }).toList();

                // Calculate totals
                double totalDeliveryFees = 0.0;
                double totalTips = 0.0;
                int deliveriesCount = todayOrders.length;

                for (var order in todayOrders) {
                  final orderData = order.value as Map<dynamic, dynamic>;
                  final deliveryFee = (orderData['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                  final tipAmount = (orderData['tipAmount'] as num?)?.toDouble() ?? 0.0;
                  
                  totalDeliveryFees += deliveryFee;
                  totalTips += tipAmount;
                }

                final totalEarnings = totalDeliveryFees + totalTips;

                return Card(
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
                          'Today',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${totalEarnings.toStringAsFixed(2)}',
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
                                  '\$${totalDeliveryFees.toStringAsFixed(2)}',
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
                                  '\$${totalTips.toStringAsFixed(2)}',
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
                                  '$deliveriesCount',
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
                );
              } catch (e) {
                return _buildEmptyStatsCard();
              }
            },
          ),

          // Available Orders Section
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
                      stream: FirebaseDatabase.instance
                          .ref()
                          .child('orders')
                          .orderByChild('driverId')
                          .equalTo(_user!.uid)
                          .onValue,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        
                        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                          return const Center(
                            child: Text(
                      'No available orders',
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
                        'No available orders',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  final ordersData = data as Map<dynamic, dynamic>;
                  final availableOrders = ordersData.entries
                      .where((entry) {
                        final order = entry.value as Map<dynamic, dynamic>;
                        final orderStatus = order['order_status'] as String?;
                        final driverId = order['driverId'] as String?;
                        // Show both assigned and accepted orders
                        return (orderStatus == 'assigned_driver' || orderStatus == 'driver_accepted') && 
                               driverId == _user!.uid;
                      })
                      .toList();

                  if (availableOrders.isEmpty) {
                            return const Center(
                              child: Text(
                        'No available orders',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }
                          
                          return ListView.builder(
                    itemCount: availableOrders.length,
                            itemBuilder: (context, index) {
                      final order = availableOrders[index].value as Map<dynamic, dynamic>;
                      final orderId = availableOrders[index].key as String;
                      final customerName = order['customerName'] as String? ?? 'Unknown Customer';
                      final customerPhone = order['customerPhone'] as String? ?? '';
                      final totalAmount = (order['total'] as num?)?.toDouble() ?? 0.0;
                      final address = order['address'] as Map<dynamic, dynamic>?;
                      final street = address?['street'] as String? ?? 'No address provided';
                      final restaurantId = order['restaurantId'] as String?;

                      return FutureBuilder<DatabaseEvent>(
                        future: FirebaseDatabase.instance
                            .ref()
                            .child('restaurants')
                            .child(restaurantId ?? '')
                            .once(),
                        builder: (context, restaurantSnapshot) {
                          if (restaurantSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (restaurantSnapshot.hasError || !restaurantSnapshot.hasData) {
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Error loading restaurant info'),
                                    const SizedBox(height: 8),
                                    Text('Customer: $customerName'),
                                    Text('Phone: $customerPhone'),
                                    Text('Address: $street'),
                                  ],
                                ),
                              ),
                            );
                          }

                          final restaurantData = restaurantSnapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
                          
                          // Get store_info data
                          final storeInfo = restaurantData?['store_info'] as Map<dynamic, dynamic>?;
                          
                          // Get restaurant details from store_info
                          final restaurantName = storeInfo?['name'] as String? ?? 'Unknown Restaurant';
                          final restaurantPhone = storeInfo?['phone'] as String? ?? 'No phone provided';
                          final restaurantAddress = storeInfo?['address'] as String? ?? 'No restaurant address provided';
                          final restaurantDescription = storeInfo?['description'] as String? ?? '';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                          'Order #$orderId',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '\$${totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFFF4A261),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Customer: $customerName'),
                                  Text('Phone: $customerPhone'),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Restaurant Details:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF4A261),
                                    ),
                                  ),
                                  Text('Name: $restaurantName'),
                                  Text('Phone: $restaurantPhone'),
                                  Text('Address: $restaurantAddress'),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Delivery Address:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF4A261),
                                    ),
                                  ),
                                  Text(street),
                                  const SizedBox(height: 16),
                                  if (order['order_status'] == 'assigned_driver')
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFF4A261),
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => _acceptOrder(orderId),
                                            child: const Text('Accept Order'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => _rejectOrder(orderId),
                                            child: const Text('Reject Order'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (order['order_status'] == 'driver_accepted') ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _markAsPickedUp(orderId),
                                        child: const Text('Mark as Picked Up'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
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
          ),
        ],
      );
  }

  Widget _buildEmptyStatsCard() {
    return Card(
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
              'Today',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '\$0.00',
              style: TextStyle(
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
                  children: const [
                    Text(
                      'Delivery Fees',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '\$0.00',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Tips',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '\$0.00',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Deliveries',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '0',
                      style: TextStyle(
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
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      setState(() => _isLoading = true);
      
      // Get driver data directly from Firebase
      final driverSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(_user!.uid)
          .get();
          
      if (!driverSnapshot.exists) {
        throw Exception('Driver data not found');
      }
      
      final driverData = driverSnapshot.value as Map<dynamic, dynamic>;
      final driverName = driverData['fullName'] as String? ?? 'Unknown Driver';
      final driverPhone = driverData['phone'] as String? ?? '';

      // Update both the order and driver status
      await Future.wait([
        // Update order status
        FirebaseDatabase.instance
            .ref()
            .child('orders')
            .child(orderId)
            .update({
          'driverId': _user!.uid,
          'driverName': driverName,
          'driverPhone': driverPhone,
          'status': 'in_progress',
          'order_status': 'driver_accepted',
          'acceptedAt': ServerValue.timestamp,
        }),
        
        // Update driver availability
        FirebaseDatabase.instance
            .ref()
            .child('drivers')
            .child(_user!.uid)
            .update({
          'isAvailable': false,
          'updatedAt': ServerValue.timestamp,
        }),
      ]);

      // Update local state
      setState(() {
        _isAvailable = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted successfully'),
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      setState(() => _isLoading = true);
      
      // Update both order status and driver availability
      await Future.wait([
        // Update order status and remove driver information
        FirebaseDatabase.instance
            .ref()
            .child('orders')
            .child(orderId)
            .update({
          'order_status': 'ready_for_pickup',
          'driverId': null,
          'driverName': null,
          'driverPhone': null,
          'updatedAt': ServerValue.timestamp,
        }),
        
        // Update driver availability to true
        FirebaseDatabase.instance
            .ref()
            .child('drivers')
            .child(_user!.uid)
            .update({
          'isAvailable': true,
          'updatedAt': ServerValue.timestamp,
        }),
      ]);

      // Update local state
      setState(() {
        _isAvailable = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order rejected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsPickedUp(String orderId) async {
    try {
      setState(() => _isLoading = true);
      
      await FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId)
          .update({
        'status': 'in_progress',
        'order_status': 'picked_up',
        'pickedUpAt': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as picked up'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking order as picked up: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
    if (_currentOrdersStream == null) {
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
      stream: _currentOrdersStream,
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
                          Expanded(
                            child: Text(
                            'Order #$orderId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                              overflow: TextOverflow.ellipsis,
                          ),
                          ),
                          const SizedBox(width: 8),
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
    if (_pastOrdersStream == null) {
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
      stream: _pastOrdersStream,
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
                          Expanded(
                            child: Text(
                            'Order #$orderId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                              overflow: TextOverflow.ellipsis,
                          ),
                          ),
                          const SizedBox(width: 8),
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
  
  Widget _buildAccountTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSection(),
          const SizedBox(height: 16),
          
          // Earnings and Tips Section
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Financial Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tip History
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TipHistoryScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFF4A261),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Tip History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  
                  // Earnings
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EarningsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Color(0xFFF4A261),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Earnings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
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
} 