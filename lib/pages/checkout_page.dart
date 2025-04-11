import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import './payment/payment_screen.dart';

class CheckoutPage extends StatefulWidget {
  final Map<String, dynamic> cartItems;
  final double subtotal;

  const CheckoutPage({
    super.key,
    required this.cartItems,
    required this.subtotal,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isDelivery = true;
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _unitController = TextEditingController();
  final _instructionsController = TextEditingController();
  double _tipPercentage = 0;
  bool _isCashOnDelivery = true;
  double _deliveryFee = 0.0;
  List<dynamic> _predictions = [];
  bool _isLoadingPredictions = false;
  static const String _apiKey = 'AIzaSyDHujk0Z7p3_mjmPsicmn7T9iyQBC0ZqtU';
  bool _isProcessingPayment = false;
  String _selectedPaymentMethod = 'Cash on Delivery';
  double _selectedTipPercentage = 0;
  bool _isProcessing = false;
  static const String _serverUrl = 'http://your-server-url.com';
  static const double _ratePerKm = 1.5; // Rate per kilometer
  
  // Discount properties
  int _discountPercentage = 0;
  bool _isLoadingDiscount = true;
  String _restaurantId = '';
  LatLng? _restaurantLocation;
  LatLng? _deliveryLocation;
  DateTime? _scheduledDateTime;

  @override
  void initState() {
    super.initState();
    // Extract restaurantId from first cart item
    if (widget.cartItems.isNotEmpty) {
      final firstItem = widget.cartItems.values.first as Map;
      _restaurantId = firstItem['restaurantId'] ?? '';
      
      // Fetch restaurant location
      if (_restaurantId.isNotEmpty) {
        _fetchRestaurantLocation();
        _fetchRestaurantDiscount();
      }
    }
  }

  Future<void> _fetchRestaurantLocation() async {
    try {
      final restaurantSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_restaurantId)
          .child('store_info')
          .child('address')
          .get();

      if (restaurantSnapshot.value != null) {
        final address = restaurantSnapshot.value.toString();
        final location = await _getLocationFromAddress(address);
        if (mounted) {
          setState(() {
            _restaurantLocation = location;
          });
        }
      }
    } catch (e) {
      print('Error fetching restaurant location: $e');
    }
  }

  Future<LatLng> _getLocationFromAddress(String address) async {
    try {
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$_apiKey&components=country:ca|country:us'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
      throw Exception('Failed to get location from address');
    } catch (e) {
      print('Error getting location: $e');
      rethrow;
    }
  }

  Future<void> _calculateDeliveryFee() async {
    if (_restaurantLocation == null || _deliveryLocation == null) {
      return;
    }

    try {
      final distance = await Geolocator.distanceBetween(
        _restaurantLocation!.latitude,
        _restaurantLocation!.longitude,
        _deliveryLocation!.latitude,
        _deliveryLocation!.longitude,
      );

      // Convert meters to kilometers and calculate fee
      final distanceInKm = distance / 1000;
      final deliveryFee = distanceInKm * _ratePerKm;

      // Set minimum delivery fee (in CAD)
      final minimumFee = 4.99; // Increased minimum fee for Canada
      final finalFee = deliveryFee < minimumFee ? minimumFee : deliveryFee;

      if (mounted) {
        setState(() {
          _deliveryFee = finalFee;
        });
      }
    } catch (e) {
      print('Error calculating delivery fee: $e');
    }
  }

  Future<void> _onAddressSelected(String address) async {
    try {
      final location = await _getLocationFromAddress(address);
      setState(() {
        _deliveryLocation = location;
        _streetController.text = address;
      });
      await _calculateDeliveryFee();
    } catch (e) {
      print('Error selecting address: $e');
    }
  }

  Future<void> _fetchRestaurantDiscount() async {
    try {
      final discountSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_restaurantId)
          .child('discount')
          .get();

      if (mounted) {
        setState(() {
          _discountPercentage = (discountSnapshot.value as int?) ?? 0;
          _isLoadingDiscount = false;
        });
      }
    } catch (e) {
      print('Error fetching discount: $e');
      if (mounted) {
        setState(() {
          _isLoadingDiscount = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _unitController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  double get _tipAmount => widget.subtotal * (_tipPercentage / 100);
  
  double get _discountAmount => _discountPercentage > 0 
      ? (widget.subtotal * _discountPercentage / 100) 
      : 0.0;
      
  double get _subtotalAfterDiscount => widget.subtotal - _discountAmount;
  
  double get _totalAmount => _subtotalAfterDiscount + _tipAmount + (_isDelivery ? _deliveryFee : 0);

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
            'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_apiKey&components=country:ca|country:us'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _predictions = data['predictions'];
        });
      }
    } catch (e) {
      print('Error searching address: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary
              _buildSection(
                title: 'Order Summary',
                child: Column(
                  children: [
                    ...widget.cartItems.entries.map((entry) {
                      final item = entry.value as Map;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
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
                                        item['name'] ?? 'Unnamed Item',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Quantity: ${item['quantity']}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${(item['totalPrice'] ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF4A261),
                                  ),
                                ),
                              ],
                            ),
                            // Display customizations if they exist
                            if (item['customizations'] != null && 
                                item['customizations'] is Map && 
                                (item['customizations'] as Map).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Customizations:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...(item['customizations'] as Map).entries.map((customization) {
                                      final customizationList = customization.value as List?;
                                      if (customizationList == null || customizationList.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      // Get the first item in the list which contains our customization data
                                      final customizationData = customizationList.first as Map?;
                                      if (customizationData == null) {
                                        return const SizedBox.shrink();
                                      }

                                      final optionName = customizationData['optionName']?.toString();
                                      final selectedItems = customizationData['selectedItems'] as List?;

                                      if (optionName != null && selectedItems != null) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: selectedItems.map<Widget>((selectedItem) {
                                            if (selectedItem is Map) {
                                              final itemName = selectedItem['name']?.toString();
                                              final itemPrice = selectedItem['price'] is num ? 
                                                  (selectedItem['price'] as num).toDouble() : 0.0;
                                              
                                              if (itemName != null) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '$optionName: $itemName',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      if (itemPrice > 0)
                                                        Text(
                                                          '+\$${itemPrice.toStringAsFixed(2)}',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Color(0xFFF4A261),
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            }
                                            return const SizedBox.shrink();
                                          }).toList(),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('\$${widget.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Delivery Options
              _buildSection(
                title: 'Delivery Options',
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('Delivery'),
                      subtitle: Text('Delivery Fee: \$${_deliveryFee.toStringAsFixed(2)}'),
                      value: true,
                      groupValue: _isDelivery,
                      onChanged: (value) {
                        setState(() {
                          _isDelivery = value ?? true;
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      title: const Text('Pickup'),
                      subtitle: const Text('Free'),
                      value: false,
                      groupValue: _isDelivery,
                      onChanged: (value) {
                        setState(() {
                          _isDelivery = value ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Delivery Address
              if (_isDelivery) ...[
                _buildSection(
                  title: 'Delivery Address',
                  child: _buildAddressSearch(),
                ),
                const SizedBox(height: 16),
              ],

              // Tip Selection
              _buildSection(
                title: 'Add Tip',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTipButton(0, '0%'),
                        _buildTipButton(10, '10%'),
                        _buildTipButton(15, '15%'),
                        _buildTipButton(20, '20%'),
                        _buildTipButton(25, '25%'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tip Amount:'),
                        Text(
                          '\$${_tipAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF4A261),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method
              _buildSection(
                title: 'Payment Method',
                child: _buildPaymentMethodSection(),
              ),
              const SizedBox(height: 16),

              // Total Amount
              _buildSection(
                title: 'Total Amount',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('\$${widget.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    // Show discount if present
                    if (_discountPercentage > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount (${_discountPercentage}%)',
                            style: const TextStyle(
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '-\$${_discountAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_isDelivery) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery Fee'),
                          Text('\$${_deliveryFee.toStringAsFixed(2)}'),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tip'),
                        Text('\$${_tipAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF4A261),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Place Order Button
              _buildPlaceOrderButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildTipButton(double percentage, String label) {
    final isSelected = _tipPercentage == percentage;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFFF4A261) : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () {
        setState(() {
          _tipPercentage = percentage;
        });
      },
      child: Text(label),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Cash on Delivery'),
          leading: Radio<String>(
            value: 'Cash on Delivery',
            groupValue: _selectedPaymentMethod,
            onChanged: (String? value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
          ),
        ),
        ListTile(
          title: const Text('Credit/Debit Card'),
          leading: Radio<String>(
            value: 'Card',
            groupValue: _selectedPaymentMethod,
            onChanged: (String? value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF4A261),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: _isProcessingPayment ? null : _placeOrder,
        child: _isProcessingPayment
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          : const Text(
              'Place Order',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }

  Widget _buildAddressSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _streetController,
          decoration: const InputDecoration(
            labelText: 'Street Address',
            hintText: 'Enter your delivery address',
          ),
          onChanged: _searchAddress,
        ),
        if (_predictions.isNotEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return ListTile(
                  title: Text(prediction['description']),
                  onTap: () async {
                    await _onAddressSelected(prediction['description']);
                    setState(() {
                      _predictions = [];
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Get customer information
      final customerSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(userId)
          .get();

      if (!customerSnapshot.exists) {
        throw Exception('Customer information not found');
      }

      final customerData = customerSnapshot.value as Map<dynamic, dynamic>;
      final customerName = customerData['fullName'] as String? ?? 'Unknown Customer';
      final customerPhone = customerData['phone'] as String? ?? '';

      // Get current location
      Position position = await Geolocator.getCurrentPosition();

      // Generate a unique order ID using UUID format
      final orderId = const Uuid().v4().toUpperCase();

      // Get the first restaurant ID from cart items
      final firstItem = widget.cartItems.values.first as Map;
      final restaurantId = firstItem['restaurantId'];
      
      // Check if this is a scheduled order
      final isScheduledOrder = firstItem['scheduledDateTime'] != null;
      final scheduledDateTime = isScheduledOrder ? firstItem['scheduledDateTime'] as int : null;

      // Process items to match the required structure
      final List<Map<String, dynamic>> processedItems = [];
      for (var entry in widget.cartItems.entries) {
        final item = entry.value as Map;
        processedItems.add({
          'id': item['id'],
          'name': item['name'],
          'description': item['description'] ?? '',
          'price': item['price'],
          'imageURL': item['imageURL'],
          'menuItemId': item['menuItemId'],
          'quantity': item['quantity'],
          'totalPrice': item['totalPrice'],
          'customizations': item['customizations'] ?? {},
        });
      }

      final orderData = {
        'address': _isDelivery ? {
          'instructions': _instructionsController.text,
          'street': _streetController.text,
          'unit': _unitController.text,
        } : null,
        'createdAt': ServerValue.timestamp,
        'deliveryFee': _isDelivery ? _deliveryFee : 0,
        'deliveryOption': _isDelivery ? 'Delivery' : 'Pickup',
        'id': orderId,
        'items': processedItems,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'order_status': isScheduledOrder ? 'pending' : 'pending',
        'status': isScheduledOrder ? 'scheduled' : 'pending',
        'paymentMethod': _selectedPaymentMethod,
        'restaurantId': restaurantId,
        'subtotal': widget.subtotal,
        'discountPercentage': _discountPercentage,
        'discountAmount': _discountAmount,
        'subtotalAfterDiscount': _subtotalAfterDiscount,
        'tipAmount': _tipAmount,
        'tipPercentage': _tipPercentage,
        'total': _totalAmount,
        'userId': userId,
        'customerName': customerName,
        'customerId': userId,
        'customerPhone': customerPhone,
      };

      // Add scheduled date and time if it's a scheduled order
      if (scheduledDateTime != null) {
        orderData['scheduledDateTime'] = scheduledDateTime;
      }

      // Store the order in the appropriate reference
      if (isScheduledOrder) {
        // Store only in scheduled_orders for scheduled orders
        await FirebaseDatabase.instance
            .ref()
            .child('scheduled_orders')
            .child(orderId)
            .set(orderData);
      } else {
        // Store regular orders in orders reference
        await FirebaseDatabase.instance
            .ref()
            .child('orders')
            .child(orderId)
            .set(orderData);
      }

      // Clear the cart
      await FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(userId)
          .child('cart')
          .remove();

      if (mounted) {
        // Show success message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isScheduledOrder 
              ? 'Order scheduled successfully!' 
              : 'Order placed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }
} 