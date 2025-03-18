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
  final String secretKey = "sk_test_51QycXpPFig18ZUMzerj6NO759gulhbh13B9c4DOrsACNwPzABh4psVJudzEIjrPTn7wURMQufxdFrnMcBoZuLwVy00vY2lQpy3";
  final String customersUrl = "https://api.stripe.com/v1/customers";
  final String ephemeralKeyUrl = "https://api.stripe.com/v1/ephemeral_keys";
  final String clientSecretUrl = "https://api.stripe.com/v1/payment_intents";

  String? customerId;
  String? ephemeralKey;
  String? clientSecret;
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
      await createCustomer();
    } catch (e) {
      showError("Failed to initialize payment: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> createCustomer() async {
    final response = await http.post(
      Uri.parse(customersUrl),
      headers: {
        'Authorization': 'Bearer $secretKey',
      },
      body: {
        'email': _user?.email,
        'name': _user?.displayName,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        customerId = data['id'];
      });
      await getEphemeralKey();
    } else {
      showError("Failed to create customer");
    }
  }

  Future<void> getEphemeralKey() async {
    final response = await http.post(
      Uri.parse(ephemeralKeyUrl),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Stripe-Version': '2022-11-15',
      },
      body: {'customer': customerId},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        ephemeralKey = data['id'];
      });
      await getClientSecret();
    } else {
      showError("Failed to get ephemeral key");
    }
  }

  Future<void> getClientSecret() async {
    // Convert amount to cents
    final amountInCents = (widget.amount * 100).round();
    
    final response = await http.post(
      Uri.parse(clientSecretUrl),
      headers: {
        'Authorization': 'Bearer $secretKey',
      },
      body: {
        'customer': customerId!,
        'amount': amountInCents.toString(),
        'currency': 'usd',
        'automatic_payment_methods[enabled]': 'true',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        clientSecret = data['client_secret'];
      });
    } else {
      showError("Failed to get client secret");
    }
  }

  Future<void> startPayment() async {
    if (clientSecret == null) {
      showError("Payment not initialized yet");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret!,
          merchantDisplayName: "DeliGo",
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          style: ThemeMode.system,
        ),
      );

      await stripe.Stripe.instance.presentPaymentSheet();
      
      // Update order status in Firebase
      await _updateOrderStatus();
      
      showSuccess("Payment Successful!");
      
      // Navigate back to previous screen after successful payment
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate successful payment
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