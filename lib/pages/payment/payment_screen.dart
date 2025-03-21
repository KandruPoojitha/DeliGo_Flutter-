import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final String publishableKey = "pk_test_51QycXpPFig18ZUMzhwJmZJPMw7ONj9nxCxbr4zwbIzGo9psQgLM9CQZVSuLNNupCPB6lCNLg0NRNz5Q0mwQ7Fqtw005Mf77ZUV";
  // Replace with your backend API URL
  final String backendApiUrl = "http://10.0.2.2:3000";
  
  Map<String, dynamic>? paymentIntent;
  bool _isLoading = false;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    stripe.Stripe.publishableKey = publishableKey;
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    setState(() => _isLoading = true);
    try {
      // Get payment intent from backend
      final response = await http.post(
        Uri.parse('$backendApiUrl/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': (widget.amount * 100).round(),
          'currency': 'usd',
          'customer_email': _user?.email,
          'customer_name': _user?.displayName,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create payment intent');
      }

      paymentIntent = json.decode(response.body);
      
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent!['client_secret'],
          merchantDisplayName: "DeliGo",
          style: ThemeMode.system,
        ),
      );
    } catch (e) {
      showError("Failed to initialize payment: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> startPayment() async {
    if (paymentIntent == null) {
      showError("Payment not initialized yet");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await stripe.Stripe.instance.presentPaymentSheet();
      
      // Verify payment with backend
      final verifyResponse = await http.post(
        Uri.parse('$backendApiUrl/verify-payment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'payment_intent_id': paymentIntent!['id'],
        }),
      );

      if (verifyResponse.statusCode != 200) {
        throw Exception('Failed to verify payment');
      }
      
      // Update order status in Firebase
      await _updateOrderStatus();
      
      showSuccess("Payment Successful!");
      
      // Navigate back to previous screen after successful payment
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      showError("Payment Failed: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus() async {
    try {
      final orderRef = FirebaseDatabase.instance.ref().child('orders').child(widget.orderId);
      
      Map<String, dynamic> updateData = {
        ...widget.orderData,
        'paymentStatus': 'paid',
        'paymentMethod': 'card',
        'paymentTimestamp': DateTime.now().toIso8601String(),
        'stripePaymentIntentId': paymentIntent!['id'],
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
          onPressed: () => Navigator.of(context).pop(false),
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: startPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4A261),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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