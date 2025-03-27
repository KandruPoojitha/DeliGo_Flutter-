import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> orderData;

  const ReceiptScreen({
    Key? key,
    required this.orderData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = (orderData['items'] as List<dynamic>?) ?? [];
    final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (orderData['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final total = (orderData['total'] as num?)?.toDouble() ?? 0.0;
    final createdAt = orderData['createdAt'] as String? ?? '';
    final formattedDate = _formatDateTime(createdAt);
    final deliveryAddress = orderData['deliveryAddress'] as String? ?? '';
    final restaurantName = orderData['restaurantName'] as String? ?? 'Restaurant';
    final orderId = orderData['orderId'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Implement receipt download functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Receipt downloaded')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Receipt Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Center(
                        child: Text(
                          'DeliGo',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'RECEIPT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Order Details
                      _buildInfoRow('Restaurant:', restaurantName),
                      _buildInfoRow('Order #:', orderId),
                      _buildInfoRow('Date:', formattedDate),
                      _buildInfoRow('Status:', 'Delivered'),
                      _buildInfoRow('Delivery Option:', 'Delivery'),
                      _buildInfoRow('Delivery', deliveryAddress),
                      
                      const SizedBox(height: 20),
                      
                      // Items Table Header
                      Row(
                        children: const [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Item',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Qty',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Price',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),

                      // Items
                      ...items.map((item) => _buildItemRow(
                        item['name'] ?? '',
                        item['quantity'] ?? 1,
                        (item['price'] as num?)?.toDouble() ?? 0.0,
                      )),
                      
                      const Divider(),
                      
                      // Totals
                      _buildTotalRow('Subtotal:', subtotal),
                      _buildTotalRow('Delivery Fee:', deliveryFee),
                      const SizedBox(height: 8),
                      _buildTotalRow('Total:', total, isBold: true),
                      
                      const SizedBox(height: 20),
                      
                      // Footer
                      const Center(
                        child: Text(
                          'Thank you for your order!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'We appreciate your business.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'DeliGo Food Delivery',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'Receipt generated on $formattedDate',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String name, int quantity, double price) {
    final total = quantity * price;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(name),
          ),
          Expanded(
            child: Text(
              quantity.toString(),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '\$${price.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              '\$${total.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateString) {
    try {
      DateTime dateTime;
      if (dateString.isNotEmpty && RegExp(r'^\d+$').hasMatch(dateString)) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(int.parse(dateString));
      } else {
        dateTime = DateTime.parse(dateString);
      }
      return DateFormat('MMM dd, yyyy \'at\' hh:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }
} 