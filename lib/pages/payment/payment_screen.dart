import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  final Map<String, dynamic> orderData;

  const PaymentScreen({
    Key? key,
    required this.amount,
    required this.orderId,
    required this.orderData,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final String publishableKey = "pk_test_51PlVh8P9Bz7XrwZPnWMN2upZk3x00s3soZgJgM5QTMuwCNoZPBdGtmPRXB29vBnFvOXjEAv2vntLuQaWbPpEHOmP00D7pelv0B";
  final String secretKey = "sk_test_51PlVh8P9Bz7XrwZPWSkDzX7AmaNgVr04yPOQWnbAECiYSWKtsmmVgD2Z8JYBY8a5dmEfKXaTewrBESb3fxIliwDo00HdJmKBKz";
  final String customersUrl = "https://api.stripe.com/v1/customers";
  final String ephemeralKeyUrl = "https://api.stripe.com/v1/ephemeral_keys";
  final String clientSecretUrl = "https://api.stripe.com/v1/payment_intents";

  String? customerId;
  String? ephemeralKey;
  String? clientSecret;
  bool _isLoading = false;
  bool _isInitialized = false;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _initializeStripe();
  }

  Future<void> _initializeStripe() async {
    try {
      stripe.Stripe.publishableKey = publishableKey;
      await stripe.Stripe.instance.applySettings();
      await _initializePayment();
      setState(() => _isInitialized = true);
    } catch (e) {
      showError("Failed to initialize Stripe: ${e.toString()}");
    }
  }

  Future<void> _initializePayment() async {
    if (_user == null) {
      showError("User not logged in");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Create customer
      final customerResponse = await http.post(
        Uri.parse(customersUrl),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': _user.email,
          'name': _user.displayName ?? 'Unknown',
          'metadata[userId]': _user.uid,
        },
      );

      if (customerResponse.statusCode != 200) {
        throw Exception('Failed to create customer: ${customerResponse.body}');
      }

      final customerData = json.decode(customerResponse.body);
      customerId = customerData['id'];

      // Get ephemeral key
      final ephemeralResponse = await http.post(
        Uri.parse(ephemeralKeyUrl),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Stripe-Version': '2023-10-16',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'customer': customerId,
        },
      );

      if (ephemeralResponse.statusCode != 200) {
        throw Exception('Failed to create ephemeral key: ${ephemeralResponse.body}');
      }

      final ephemeralData = json.decode(ephemeralResponse.body);
      ephemeralKey = ephemeralData['secret'];

      // Create payment intent
      final amountInCents = (widget.amount * 100).round();
      final paymentIntentResponse = await http.post(
        Uri.parse(clientSecretUrl),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'customer': customerId,
          'amount': amountInCents.toString(),
          'currency': 'usd',
          'automatic_payment_methods[enabled]': 'true',
          'metadata[orderId]': widget.orderId,
          'metadata[userId]': _user.uid,
        },
      );

      if (paymentIntentResponse.statusCode != 200) {
        throw Exception('Failed to create payment intent: ${paymentIntentResponse.body}');
      }

      final paymentIntentData = json.decode(paymentIntentResponse.body);
      clientSecret = paymentIntentData['client_secret'];

    } catch (e) {
      showError("Payment initialization failed: ${e.toString()}");
      rethrow;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> startPayment() async {
    if (!_isInitialized) {
      showError("Payment system not initialized");
      return;
    }

    if (clientSecret == null || customerId == null || ephemeralKey == null) {
      showError("Payment details not ready");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Configure payment sheet
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret!,
          merchantDisplayName: "DeliGo",
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          style: ThemeMode.system,
          billingDetails: stripe.BillingDetails(
            email: _user?.email,
            name: _user?.displayName,
          ),
          appearance: const stripe.PaymentSheetAppearance(
            colors: stripe.PaymentSheetAppearanceColors(
              primary: Color(0xFFF4A261),
            ),
          ),
        ),
      );

      // Present payment sheet
      await stripe.Stripe.instance.presentPaymentSheet();
      
      // If we get here, payment was successful
      await _updateOrderStatus();
      showSuccess("Payment Successful!");
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on stripe.StripeException catch (e) {
      showError("Stripe error: ${e.error.localizedMessage}");
    } catch (e) {
      showError("Payment failed: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus() async {
    try {
      final orderRef = FirebaseDatabase.instance.ref().child('orders').child(widget.orderId);
      
      // Update the order with payment information
      Map<String, dynamic> updateData = {
        ...widget.orderData,
        'paymentStatus': 'paid',
        'paymentMethod': 'card',
        'paymentTimestamp': DateTime.now().toIso8601String(),
      };
      
      await orderRef.update(updateData);
    } catch (e) {
      showError("Failed to update order status: ${e.toString()}");
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(false), // Return false to indicate payment was cancelled
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount:',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                '\$${widget.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF4A261),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4A261),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Pay Now',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 