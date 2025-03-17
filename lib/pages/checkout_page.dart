import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

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
  double _deliveryFee = 4.99;
  List<dynamic> _predictions = [];
  bool _isLoadingPredictions = false;
  static const String _apiKey = 'AIzaSyDHujk0Z7p3_mjmPsicmn7T9iyQBC0ZqtU';
  bool _isProcessingPayment = false;
  String _selectedPaymentMethod = 'Cash on Delivery';
  double _selectedTipPercentage = 0;
  bool _isProcessing = false;
  static const String _serverUrl = 'http://your-server-url.com';

  @override
  void dispose() {
    _streetController.dispose();
    _unitController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  double get _tipAmount => widget.subtotal * (_tipPercentage / 100);
  double get _totalAmount => widget.subtotal + _tipAmount + (_isDelivery ? _deliveryFee : 0);

  Future<void> _getPlacePredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictions = [];
        _isLoadingPredictions = false;
      });
      return;
    }

    setState(() {
      _isLoadingPredictions = true;
    });

    try {
      final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$input'
        '&key=$_apiKey'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _predictions = data['predictions'];
          _isLoadingPredictions = false;
        });
      } else {
        throw Exception('Failed to load predictions');
      }
    } catch (e) {
      setState(() {
        _isLoadingPredictions = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting address suggestions: $e')),
        );
      }
    }
  }

  Future<void> _selectAddress(Map<String, dynamic> prediction) async {
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
            _streetController.text = prediction['description'];
            _predictions = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting address details: $e')),
        );
      }
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
                        child: Row(
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
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _streetController,
                        decoration: InputDecoration(
                          labelText: 'Street Address',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoadingPredictions
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          _getPlacePredictions(value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your street address';
                          }
                          return null;
                        },
                      ),
                      if (_predictions.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _predictions.length,
                            itemBuilder: (context, index) {
                              final prediction = _predictions[index];
                              return ListTile(
                                title: Text(prediction['description']),
                                onTap: () => _selectAddress(prediction),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit/Apartment Number (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _instructionsController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Instructions (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
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
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          title: const Text('Cash on Delivery'),
          leading: Radio<bool>(
            value: true,
            groupValue: _isCashOnDelivery,
            onChanged: (bool? value) {
              setState(() {
                _isCashOnDelivery = value!;
              });
            },
          ),
        ),
        ListTile(
          title: const Text('Credit/Debit Card'),
          subtitle: const Text('Coming soon'),
          leading: Radio<bool>(
            value: false,
            groupValue: _isCashOnDelivery,
            onChanged: null,  // Disabled radio button
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

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Get current location
      Position position = await Geolocator.getCurrentPosition();

      // Generate a unique order ID using UUID format
      final orderId = const Uuid().v4().toUpperCase();
      final orderRef = FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId);

      // Get the first restaurant ID from cart items
      final firstItem = widget.cartItems.values.first as Map;
      final restaurantId = firstItem['restaurantId'];

      // Process items to match the required structure
      final processedItems = widget.cartItems.entries.map((entry) {
        final item = Map<String, dynamic>.from(entry.value as Map);
        
        // Process customizations if they exist
        final customizations = item['customizations'];
        Map<String, dynamic> processedCustomizations = {};
        
        if (customizations != null) {
          for (var customization in customizations as List) {
            final customId = const Uuid().v4().toUpperCase();
            processedCustomizations[customId] = {
              'optionId': customId,
              'optionName': customization['optionName'],
              'selectedItems': customization['selectedItems'] ?? [],
            };
          }
        }

        return {
          'customizations': processedCustomizations,
          'description': item['description'] ?? '',
          'id': const Uuid().v4().toUpperCase(),
          'imageURL': item['imageURL'] ?? '',
          'menuItemId': item['menuItemId'] ?? '',
          'name': item['name'] ?? 'Unnamed Item',
          'price': item['price'] ?? 0.0,
          'quantity': item['quantity'] ?? 1,
          'specialInstructions': item['specialInstructions'] ?? '',
          'totalPrice': item['totalPrice'] ?? 0.0,
        };
      }).toList();

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
        'paymentMethod': 'Cash on Delivery',
        'restaurantId': restaurantId,
        'status': 'pending',
        'subtotal': widget.subtotal,
        'tipAmount': _tipAmount,
        'tipPercentage': _tipPercentage,
        'total': _totalAmount,
        'userId': userId,
      };

      await orderRef.set(orderData);

      // Clear cart
      await FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(userId)
          .child('cart')
          .remove();

      if (mounted) {
        Navigator.pop(context); // Return to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully! Please pay on delivery.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      if (_selectedPaymentMethod == 'Cash on Delivery') {
        // Get current user location
        Position position = await Geolocator.getCurrentPosition();
        
        // Create order data
        final orderData = {
          'cartItems': widget.cartItems,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'paymentMethod': _selectedPaymentMethod,
          'restaurantId': widget.cartItems.values.first['restaurantId'],
          'status': 'pending',
          'subtotal': widget.subtotal,
          'tipAmount': _calculateTipAmount(),
          'tipPercentage': _selectedTipPercentage,
          'total': _calculateTotal(),
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'timestamp': ServerValue.timestamp,
        };

        // Generate a unique order ID
        final orderId = FirebaseDatabase.instance
            .ref()
            .child('orders')
            .push()
            .key;

        if (orderId != null) {
          // Store order in orders collection
          await FirebaseDatabase.instance
              .ref()
              .child('orders')
              .child(orderId)
              .set(orderData);

          // Clear user's cart
          await FirebaseDatabase.instance
              .ref()
              .child('customers')
              .child(FirebaseAuth.instance.currentUser?.uid ?? '')
              .child('cart')
              .remove();

          if (mounted) {
            // Show success message and navigate back to home
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order placed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      } else {
        // Handle other payment methods (Stripe, etc.)
        final response = await http.post(
          Uri.parse('$_serverUrl/create-payment-intent'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'amount': (_calculateTotal() * 100).round(),
            'currency': 'usd',
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to create payment intent: ${response.body}');
        }

        final jsonResponse = json.decode(response.body);
        final clientSecret = jsonResponse['clientSecret'];

        if (clientSecret == null) {
          throw Exception('Failed to get client secret from server');
        }

        // Continue with Stripe payment...
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  double _calculateTipAmount() {
    return (widget.subtotal * _selectedTipPercentage / 100);
  }

  double _calculateTotal() {
    final tipAmount = _calculateTipAmount();
    final deliveryFee = 5.00; // Fixed delivery fee
    return widget.subtotal + tipAmount + deliveryFee;
  }
} 