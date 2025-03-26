import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/restaurant_service.dart';
import '../models/restaurant.dart';
import '../providers/theme_provider.dart';
import 'admin/chat_management/admin_chat_page.dart';
import 'login_page.dart';
import 'add_menu_item_page.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:math';
import '../pages/admin/chat_management/admin_chat_page.dart';
import '../pages/restaurant_chat_page.dart';
import 'edit_store_info_page.dart';

class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key});

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage> {
  final _user = FirebaseAuth.instance.currentUser;
  final _restaurantService = RestaurantService();
  int _selectedIndex = 0;
  bool _isOpen = false;
  Restaurant? _restaurant;
  int _ordersTabIndex = 0;
  bool _isDarkMode = false;
  bool _isEnglish = true;
  final _menuItemsCount = ValueNotifier<int>(0);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aboutController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, Map<String, dynamic>> _businessHours = {
    'monday': {'openTime': '09:00', 'closeTime': '22:00', 'isOpen': true},
    'tuesday': {'openTime': '09:00', 'closeTime': '22:00', 'isOpen': true},
    'wednesday': {'openTime': '09:00', 'closeTime': '22:00', 'isOpen': true},
    'thursday': {'openTime': '09:00', 'closeTime': '22:00', 'isOpen': true},
    'friday': {'openTime': '09:00', 'closeTime': '23:00', 'isOpen': true},
    'saturday': {'openTime': '09:00', 'closeTime': '23:00', 'isOpen': true},
    'sunday': {'openTime': '09:00', 'closeTime': '22:00', 'isOpen': true},
  };
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoadingAddresses = false;
  final String _apiKey = 'AIzaSyDHujk0Z7p3_mjmPsicmn7T9iyQBC0ZqtU';
  bool _isLoading = false;
  late final Stream<DatabaseEvent> _ordersStream;

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
    _ordersStream = FirebaseDatabase.instance
        .ref()
        .child('orders')
        .orderByChild('restaurantId')
        .equalTo(_user?.uid)
        .onValue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _aboutController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    _menuItemsCount.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurantData() async {
    if (_user != null) {
      print('Loading restaurant data for user: ${_user!.uid}');
      print('User email: ${_user!.email}');

      try {
        // Get the restaurant data directly from Firebase to ensure we have the latest isOpen status
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(_user!.uid)
            .get();

        if (snapshot.exists) {
          final restaurantData = snapshot.value as Map<dynamic, dynamic>;
          
          if (mounted) {
            setState(() {
              _isOpen = restaurantData['isOpen'] ?? false;
              _nameController.text = restaurantData['fullName'] ?? '';
              _emailController.text = restaurantData['email'] ?? '';
              _phoneController.text = restaurantData['phone'] ?? '';
              _addressController.text = restaurantData['address'] ?? '';
              if (restaurantData['store_hours'] != null) {
                _businessHours = Map<String, Map<String, dynamic>>.from(restaurantData['store_hours']);
              }
            });
          }
        } else {
          print('No restaurant data found for user: ${_user!.uid}');
        }
      } catch (e) {
        print('Error loading restaurant data: $e');
      }
    } else {
      print('No user logged in');
    }
  }

  void _updateOpenStatus(Restaurant restaurant) {
    if (restaurant.hours != null) {
      final now = DateTime.now();
      final dayOfWeek = now.weekday;
      final currentDay = _getDayName(dayOfWeek);
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final dayHours = _businessHours[currentDay];
      if (dayHours != null) {
        final openingTime = dayHours['openTime'] as String;
        final closingTime = dayHours['closeTime'] as String;
        final isDayOpen = dayHours['isOpen'] as bool;

        final isCurrentlyOpen = isDayOpen &&
            currentTime.compareTo(openingTime) >= 0 &&
            currentTime.compareTo(closingTime) <= 0;

        setState(() {
          _isOpen = isCurrentlyOpen;
        });

        // Update root level isOpen
        _updateRootIsOpen(isCurrentlyOpen);
      }
    }
  }

  Future<void> _updateRootIsOpen(bool isOpen) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_user!.uid)
          .update({
        'isOpen': isOpen,
      });
    } catch (e) {
      print('Error updating root isOpen status: $e');
    }
  }

  Future<void> _toggleOpenStatus() async {
    final newStatus = !_isOpen;
    try {
      // Update root level isOpen
      await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_user!.uid)
          .update({
        'isOpen': newStatus,
        'updatedAt': ServerValue.timestamp,
      });

      setState(() {
        _isOpen = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restaurant is now ${newStatus ? 'open' : 'closed'}'),
            backgroundColor: newStatus ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating restaurant status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Upload image to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('restaurants')
            .child(user.uid)
            .child('profile_image');

        await storageRef.putFile(File(image.path));
        final imageUrl = await storageRef.getDownloadURL();

        // Update restaurant profile image in database
        await FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(user.uid)
            .update({
          'profileImageUrl': imageUrl,
          'updatedAt': ServerValue.timestamp,
        });

        // Update local state
        if (_restaurant != null) {
          setState(() {
            _restaurant = _restaurant!.copyWith(profileImageUrl: imageUrl);
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile image: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _saveStoreSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Get current store_info to preserve existing data
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(user.uid)
            .child('store_info')
            .get();

        final existingStoreInfo = snapshot.value as Map<dynamic, dynamic>? ?? {};

        // Update only phone and description, preserve other fields
        await FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(user.uid)
            .update({
          'store_info': {
            ...existingStoreInfo,
            'phone': _phoneController.text,
            'description': _aboutController.text,
          },
          'store_hours': _businessHours,
          'updatedAt': ServerValue.timestamp,
        });

        // Update local state
        if (_restaurant != null) {
          setState(() {
            _restaurant = _restaurant!.copyWith(
              phone: _phoneController.text,
              about: _aboutController.text,
              hours: _businessHours,
            );
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Store settings updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating store settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _toggleDayOpen(String day) async {
    final newDayStatus = !(_businessHours[day]!['isOpen'] == true);
    setState(() {
      _businessHours[day]!['isOpen'] = newDayStatus;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Update store_hours in Firebase
      await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(user.uid)
          .child('store_hours')
          .update({day: _businessHours[day]});

      // Check if current day and update root isOpen if needed
      final now = DateTime.now();
      final currentDay = _getDayName(now.weekday);
      if (day == currentDay) {
        final dayHours = _businessHours[currentDay]!;
        final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final isCurrentlyOpen = newDayStatus &&
            currentTime.compareTo(dayHours['openTime']) >= 0 &&
            currentTime.compareTo(dayHours['closeTime']) <= 0;

        await _updateRootIsOpen(isCurrentlyOpen);
        setState(() {
          _isOpen = isCurrentlyOpen;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${day} hours updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating hours: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectTime(BuildContext context, String day, bool isOpening) async {
    final currentTime = _businessHours[day]?[isOpening ? 'openTime' : 'closeTime'] ?? '09:00';
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _businessHours[day]![isOpening ? 'openTime' : 'closeTime'] = newTime;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Update store_hours in Firebase
        await FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(user.uid)
            .child('store_hours')
            .update({day: _businessHours[day]});

        // Check if current day and update root isOpen if needed
        final now = DateTime.now();
        final currentDay = _getDayName(now.weekday);
        if (day == currentDay) {
          final dayHours = _businessHours[currentDay]!;
          final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          final isCurrentlyOpen = dayHours['isOpen'] == true &&
              currentTimeStr.compareTo(dayHours['openTime']) >= 0 &&
              currentTimeStr.compareTo(dayHours['closeTime']) <= 0;

          await _updateRootIsOpen(isCurrentlyOpen);
          setState(() {
            _isOpen = isCurrentlyOpen;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${day} hours updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating hours: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
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
  }

  Future<void> _getPlacePredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictions = [];
        _isLoadingAddresses = false;
      });
      return;
    }

    setState(() {
      _isLoadingAddresses = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
              '?input=$input'
              '&key=$_apiKey'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(data['predictions']);
            _isLoadingAddresses = false;
          });
        } else {
          setState(() {
            _isLoadingAddresses = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${data['status']}')),
            );
          }
        }
      } else {
        setState(() {
          _isLoadingAddresses = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error fetching addresses')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingAddresses = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> prediction) async {
    try {
      final response = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
              '?place_id=${prediction['place_id']}'
              '&key=$_apiKey'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _addressController.text = prediction['description'];
            _predictions = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting place details: $e')),
        );
      }
    }
  }

  Future<void> _updateExistingMenuItems() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final menuItemsRef = FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(user.uid)
          .child('menu_items');

      final snapshot = await menuItemsRef.get();
      if (snapshot.exists) {
        final items = snapshot.value as Map;
        int updatedCount = 0;

        for (var entry in items.entries) {
          final item = entry.value as Map;
          if (item.containsKey('imageUrl')) {
            await menuItemsRef
                .child(entry.key)
                .update({
              'imageURL': item['imageUrl'],
              'imageUrl': null,
            });
            updatedCount++;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated $updatedCount menu items to use imageURL'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating menu items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOrdersTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'New Orders'),
              Tab(text: 'In Progress'),
              Tab(text: 'Delivered'),
            ],
            labelColor: Color(0xFFF4A261),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFF4A261),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return TabBarView(
                    children: List.generate(3, (index) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No ${index == 0 ? 'new' : index == 1 ? 'in progress' : 'delivered'} orders',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )),
                  );
                }

                final ordersMap = Map<dynamic, dynamic>.from(
                    snapshot.data!.snapshot.value as Map
                );

                return TabBarView(
                  children: [
                    _buildOrdersList(ordersMap, 'pending'),
                    _buildOrdersList(ordersMap, 'in_progress'),
                    _buildOrdersList(ordersMap, 'delivered'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(Map<dynamic, dynamic> ordersMap, String status) {
    // Filter orders by status and sort by timestamp
    List<MapEntry<dynamic, dynamic>> orders = ordersMap.entries.where((entry) {
      final order = entry.value as Map<dynamic, dynamic>;
      return order['status'] == status;
    }).toList();

    // Sort by creation timestamp (newest first)
    orders.sort((a, b) {
      final aValue = a.value['createdAt'];
      final bValue = b.value['createdAt'];
      
      // Convert to integers, defaulting to 0 if null or invalid
      final aTime = aValue is int ? aValue : 0;
      final bTime = bValue is int ? bValue : 0;
      
      return bTime.compareTo(aTime);
    });

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No ${status == 'pending' ? 'new' : status} orders',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final order = orders[index].value as Map<dynamic, dynamic>;
        final orderId = orders[index].key as String;
        final items = order['items'] as List<dynamic>;
        final customizations = items.map((item) {
          final itemMap = item as Map<dynamic, dynamic>;
          return itemMap['customizations'];
        }).toList();
        
        // Fix type casting for numeric values
        final subtotal = (order['subtotal'] is int) 
            ? (order['subtotal'] as int).toDouble() 
            : order['subtotal'] as double? ?? 0.0;
            
        final deliveryFee = (order['deliveryFee'] is int)
            ? (order['deliveryFee'] as int).toDouble()
            : order['deliveryFee'] as double? ?? 0.0;
            
        final tip = (order['tip'] is int)
            ? (order['tip'] as int).toDouble()
            : order['tip'] as double? ?? 0.0;
            
        final orderTotal = (order['total'] is int)
            ? (order['total'] as int).toDouble()
            : order['total'] as double? ?? 0.0;
            
        final userId = order['userId']?.toString();
        final deliveryOption = order['deliveryOption']?.toString() ?? 'Pickup';
        final address = order['address'] as Map<dynamic, dynamic>?;
        final createdAt = order['createdAt'] as int? ?? 0;
        
        // Convert timestamp to readable date/time
        final orderTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
        final formattedTime = '${orderTime.hour.toString().padLeft(2, '0')}:${orderTime.minute.toString().padLeft(2, '0')}';

        return Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                          Row(
                            children: [
                              Text(
                                'Order #${orderId.substring(0, 8).toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (userId != null)
                            StreamBuilder<DatabaseEvent>(
                              stream: FirebaseDatabase.instance
                                  .ref()
                                  .child('customers')
                                  .child(userId)
                                  .onValue,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                                  final customerData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                                  final fullName = customerData['fullName'] as String? ?? 'Customer';
                                  return Text(
                                    fullName,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  );
                                }
                                return Text(
                                  'Customer',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                );
                              },
                            )
                          else
                            Text(
                              'Customer',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4A261).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: const Color(0xFFF4A261),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (tip > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tip: \$${tip.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = items[itemIndex] as Map<dynamic, dynamic>;
                    final itemCustomizations = item['customizations'];
                    final customizationsMap = itemCustomizations is Map<dynamic, dynamic> ? itemCustomizations : null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item['quantity']}x ${item['name']}',
                                style: const TextStyle(fontSize: 15),
                              ),
                              Text(
                                '\$${(item['totalPrice'] as num).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                          if (customizationsMap != null && customizationsMap.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: customizationsMap.values.map<Widget>((customization) {
                                  // Handle both Map and List types
                                  Map<dynamic, dynamic> custom;
                                  if (customization is List) {
                                    // If it's a list, take the first item
                                    custom = customization.isNotEmpty ? (customization.first as Map<dynamic, dynamic>) : {};
                                  } else {
                                    custom = customization as Map<dynamic, dynamic>;
                                  }
                                  
                                  final price = custom['price'] as num? ?? 0.0;
                                  final optionName = custom['optionName'] as String? ?? '';
                                  final selectedName = custom['name'] as String? ?? '';
                                  final selectedId = custom['id'] as String? ?? '';
                                  final selectedItems = custom['selectedItems'] as List<dynamic>?;
                                  
                                  if (selectedItems != null && selectedItems.isNotEmpty) {
                                    // If there are selectedItems, display them
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '+ $optionName:',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        ...selectedItems.map((item) {
                                          final itemMap = item as Map<dynamic, dynamic>;
                                          final itemName = itemMap['name'] as String? ?? '';
                                          final itemPrice = itemMap['price'] as num? ?? 0.0;
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 16),
                                            child: Text(
                                              '• $itemName (\$${itemPrice.toStringAsFixed(2)})',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    );
                                  } else {
                                    // If no selectedItems, show the regular customization
                                    return Text(
                                      '+ $optionName: $selectedName (ID: $selectedId) ${price > 0 ? '(\$${price.toStringAsFixed(2)})' : ''}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  }
                                }).toList(),
                              ),
                            ),
                          if (item['specialInstructions']?.isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text(
                                'Note: ${item['specialInstructions']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (deliveryOption == 'Delivery' && address != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const Text(
                          'Delivery Address:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(address['street'] as String),
                        if (address['unit']?.isNotEmpty ?? false)
                          Text('Unit: ${address['unit']}'),
                        if (address['instructions']?.isNotEmpty ?? false)
                          Text(
                            'Instructions: ${address['instructions']}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                const Divider(),
                // Price breakdown
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text('\$${subtotal.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    if (deliveryFee > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Delivery Fee',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text('\$${deliveryFee.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                    if (tip > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tip',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text('\$${tip.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text('\$${orderTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFFF4A261),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (status == 'pending')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'accepted'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'rejected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                if (status == 'in_progress' && order['order_status'] == 'accepted')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'ready_for_pickup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('READY TO PICKUP'),
                        ),
                      ),
                    ],
                  ),
                if (status == 'in_progress' && order['order_status'] == 'ready_for_pickup')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, deliveryOption == 'Delivery' ? 'assign_driver' : 'delivered'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(deliveryOption == 'Delivery' ? 'ASSIGN TO DRIVER' : 'MARK AS DELIVERED'),
                        ),
                      ),
                    ],
                  ),
                if (status == 'in_progress' && (order['order_status'] == 'driver_assigned' || order['order_status'] == 'assigned_driver'))
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(orderId, 'delivered'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('MARK AS DELIVER'),
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
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  Future<void> _showDriversDialog(String orderId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref()
                .child('drivers')
                .orderByChild('isAvailable')
                .equalTo(true)
                .onValue,
            builder: (context, driversSnapshot) {
              if (driversSnapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Error loading drivers'),
                );
              }

              if (!driversSnapshot.hasData || driversSnapshot.data?.snapshot.value == null) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No available drivers at the moment'),
                );
              }

              return StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref()
                    .child('restaurants')
                    .child(_user!.uid)
                    .child('location')
                    .onValue,
                builder: (context, restaurantSnapshot) {
                  if (restaurantSnapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Error loading restaurant location'),
                    );
                  }

                  if (!restaurantSnapshot.hasData || restaurantSnapshot.data?.snapshot.value == null) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Restaurant location not available'),
                    );
                  }

                  final locationData = restaurantSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  final restaurantLat = locationData['latitude'] as double? ?? 0.0;
                  final restaurantLng = locationData['longitude'] as double? ?? 0.0;

                  final driversMap = Map<dynamic, dynamic>.from(
                      driversSnapshot.data!.snapshot.value as Map);
                  final drivers = driversMap.entries.toList();

                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Select Available Driver',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: drivers.length,
                            itemBuilder: (context, index) {
                              final driver = drivers[index].value as Map<dynamic, dynamic>;
                              final driverId = drivers[index].key;
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: driver['profileImageUrl'] != null
                                      ? NetworkImage(driver['profileImageUrl'])
                                      : null,
                                  child: driver['profileImageUrl'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(driver['fullName'] ?? 'Unknown Driver'),
                                subtitle: Text(driver['phone'] ?? 'No phone'),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    await _assignDriverToOrder(orderId, driverId, driver['fullName']);
                                    if (mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF4A261),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Assign'),
                                ),
                                onTap: () async {
                                  await _assignDriverToOrder(orderId, driverId, driver['fullName']);
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
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
      },
    );
  }

  Future<void> _assignDriverToOrder(String orderId, String driverId, String driverName) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId)
          .update({
        'status': 'in_progress',
        'order_status': 'assigned_driver',
        'driverId': driverId,
        'driverName': driverName,
        'assignedAt': ServerValue.timestamp,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order assigned to $driverName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning driver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      if (status == 'assign_driver') {
        await _showDriversDialog(orderId);
        return;
      }

      Map<String, dynamic> updates = {};
      
      switch (status) {
        case 'accepted':
          updates = {
            'status': 'in_progress',
            'order_status': status,
          };
          break;
        case 'ready_for_pickup':
          updates = {
            'status': 'in_progress',
            'order_status': status,
          };
          break;
        case 'delivered':
          updates = {
            'status': status,
            'order_status': status,
            'deliveredAt': ServerValue.timestamp,
          };
          break;
        default:
          updates = {
            'status': status,
            'order_status': status,
          };
      }

      await FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId)
          .update(updates);

      if (mounted) {
        String message = '';
        switch (status) {
          case 'accepted':
            message = 'Order accepted successfully';
            break;
          case 'rejected':
            message = 'Order rejected successfully';
            break;
          case 'ready_for_pickup':
            message = 'Order is ready for pickup';
            break;
          case 'delivered':
            message = 'Order marked as delivered';
            break;
          default:
            message = 'Order status updated successfully';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: status == 'rejected' ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMenuTab() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_user!.uid)
          .child('menu_items')
          .onValue,
      builder: (context, snapshot) {
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

        final menuItems = snapshot.data?.snapshot.value as Map?;
        
        // Schedule the update for the next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _menuItemsCount.value = menuItems?.length ?? 0;
        });

        if (menuItems == null || menuItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Menu Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your first menu item',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMenuItemPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Filter menu items based on search query
        final filteredItems = menuItems.entries.where((entry) {
          final item = entry.value as Map;
          final name = (item['name'] ?? '').toString().toLowerCase();
          final description = (item['description'] ?? '').toString().toLowerCase();
          final searchLower = _searchQuery.toLowerCase();

          return name.contains(searchLower) || description.contains(searchLower);
        }).toList();

        return Stack(
          children: [
            Column(
              children: [
                // Search Bar and Update Button Row
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search menu items...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Update Image URLs',
                        onPressed: _updateExistingMenuItems,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu Items List
                Expanded(
                  child: filteredItems.isEmpty && _searchQuery.isNotEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Results Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No menu items match "$_searchQuery"',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final entry = filteredItems[index];
                      final item = entry.value as Map;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            if (item['imageURL'] != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                child: Image.network(
                                  item['imageURL'],
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ListTile(
                              title: Text(
                                item['name'] ?? 'Unnamed Item',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['description'] ?? ''),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${(item['price'] ?? 0.0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Menu Item'),
                                      content: const Text('Are you sure you want to delete this menu item?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      await FirebaseDatabase.instance
                                          .ref()
                                          .child('restaurants')
                                          .child(_user!.uid)
                                          .child('menu_items')
                                          .child(entry.key)
                                          .remove();

                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Menu item deleted successfully')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error deleting menu item: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Bottom Add Item Button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMenuItemPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _restaurant?.profileImageUrl != null
                            ? NetworkImage(_restaurant!.profileImageUrl!)
                            : null,
                        child: _restaurant?.profileImageUrl == null
                            ? const Icon(Icons.restaurant, size: 50)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFFF4A261),
                          radius: 18,
                          child: _isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : IconButton(
                            icon: const Icon(Icons.camera_alt, size: 18),
                            onPressed: _pickImage,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Store Settings Main Section
            Text(
              'Store Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),

            // Store Information Button
            Card(
              child: ListTile(
                leading: const Icon(Icons.store, color: Color(0xFFF4A261)),
                title: const Text(
                  'Store Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('Edit your store details, description, and contact information'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditStoreInfoPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Store Hours Section
            Card(
              child: ExpansionTile(
                title: const Text(
                  'Store Hours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                leading: const Icon(Icons.access_time),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: _businessHours.entries.map((entry) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Switch(
                                    value: entry.value['isOpen'] == true,
                                    onChanged: (value) => _toggleDayOpen(entry.key),
                                  ),
                                ],
                              ),
                              if (entry.value['isOpen'] == true) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () => _selectTime(context, entry.key, true),
                                        icon: const Icon(Icons.access_time),
                                        label: Text(entry.value['openTime']!),
                                      ),
                                    ),
                                    const Text('to'),
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () => _selectTime(context, entry.key, false),
                                        icon: const Icon(Icons.access_time),
                                        label: Text(entry.value['closeTime']!),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Support Section
            Card(
              child: ListTile(
                leading: const Icon(Icons.support_agent, color: Color(0xFFF4A261)),
                title: const Text(
                  'Support',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  // Fetch restaurant name from store_info
                  final storeInfoSnapshot = await FirebaseDatabase.instance
                      .ref()
                      .child('restaurants')
                      .child(_user!.uid)
                      .child('store_info')
                      .child('name')
                      .get();
                      
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RestaurantChatPage(
                          restaurantId: _user!.uid,
                          restaurantName: storeInfoSnapshot.value?.toString() ?? 'Restaurant',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 32),

            // Appearance Main Section
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),

            // Dark Mode Section
            Card(
              child: ExpansionTile(
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                leading: Icon(
                  Icons.dark_mode,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SwitchListTile(
                      title: Text(
                        'Enable Dark Mode',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Language Section
            Card(
              child: ExpansionTile(
                title: const Text(
                  'Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                leading: const Icon(Icons.language),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SwitchListTile(
                      title: const Text('English'),
                      subtitle: Text(_isEnglish ? 'English' : 'French'),
                      value: _isEnglish,
                      onChanged: (value) {
                        setState(() {
                          _isEnglish = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _restaurant?.fullName ?? 'Restaurant Dashboard',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text(
                  _isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    color: _isOpen ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isOpen,
                  onChanged: (value) => _toggleOpenStatus(),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditStoreInfoPage(),
                ),
              );
            },
            tooltip: 'Edit Store Information',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Orders Tab
          _buildOrdersTab(),

          // Menu Tab
          _buildMenuTab(),

          // Account Tab
          _buildAccountTab(),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _menuItemsCount,
        builder: (context, count, child) {
          if (_selectedIndex == 1 && count > 0) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddMenuItemPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Item',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: const Color(0xFFF4A261),
              elevation: 4,
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
} 