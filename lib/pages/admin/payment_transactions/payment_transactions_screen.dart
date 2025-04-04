import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class PaymentTransactionsScreen extends StatefulWidget {
  const PaymentTransactionsScreen({Key? key}) : super(key: key);

  @override
  _PaymentTransactionsScreenState createState() => _PaymentTransactionsScreenState();
}

class _PaymentTransactionsScreenState extends State<PaymentTransactionsScreen> {
  final _database = FirebaseDatabase.instance;
  String _selectedPaymentMethod = 'All';
  String _selectedPaymentStatus = 'All';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  
  final List<String> _paymentMethodOptions = [
    'All',
    'Card',
    'Cash',
  ];
  
  final List<String> _paymentStatusOptions = [
    'All',
    'paid',
    'pending',
    'failed',
    'refunded',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    
    // Set default date range to last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Transactions'),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(_startDate != null && _endDate != null
                            ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                            : 'Select Date Range'),
                        onPressed: _selectDateRange,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Method:'),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _paymentMethodOptions.map((method) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(method),
                                    selected: _selectedPaymentMethod == method,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedPaymentMethod = method;
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Status:'),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _paymentStatusOptions.map((status) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(status),
                                    selected: _selectedPaymentStatus == status,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedPaymentStatus = status;
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
                  ],
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
                    child: Text('No payment transactions found'),
                  );
                }

                Map<dynamic, dynamic> ordersMap = 
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                
                List<Map<String, dynamic>> transactions = [];
                
                ordersMap.forEach((key, value) {
                  final orderData = value as Map<dynamic, dynamic>;
                  
                  // Only include orders with payment information
                  if (orderData['paymentMethod'] != null) {
                    transactions.add({
                      'id': key,
                      'orderId': key,
                      'customerName': orderData['customerName'] ?? 'Unknown',
                      'customerId': orderData['customerId'] ?? '',
                      'paymentMethod': orderData['paymentMethod'] ?? 'Unknown',
                      'paymentStatus': orderData['paymentStatus'] ?? 'pending',
                      'amount': orderData['total'] != null 
                          ? (orderData['total'] as num).toDouble() 
                          : 0.0,
                      'date': orderData['paymentTimestamp'] ?? orderData['createdAt'],
                      'createdAt': orderData['createdAt'],
                    });
                  }
                });

                // Filter by date range
                if (_startDate != null && _endDate != null) {
                  transactions = transactions.where((transaction) {
                    if (transaction['date'] == null) return false;
                    
                    DateTime transactionDate;
                    if (transaction['date'] is int) {
                      transactionDate = DateTime.fromMillisecondsSinceEpoch(transaction['date']);
                    } else if (transaction['date'] is String) {
                      try {
                        transactionDate = DateTime.parse(transaction['date']);
                      } catch (e) {
                        return false;
                      }
                    } else {
                      return false;
                    }
                    
                    return transactionDate.isAfter(_startDate!) && 
                           transactionDate.isBefore(_endDate!.add(const Duration(days: 1)));
                  }).toList();
                }

                // Filter by payment method
                if (_selectedPaymentMethod != 'All') {
                  transactions = transactions
                      .where((transaction) => transaction['paymentMethod'] == _selectedPaymentMethod)
                      .toList();
                }

                // Filter by payment status
                if (_selectedPaymentStatus != 'All') {
                  transactions = transactions
                      .where((transaction) => transaction['paymentStatus'] == _selectedPaymentStatus)
                      .toList();
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  transactions = transactions.where((transaction) {
                    return transaction['orderId'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        (transaction['customerName']?.toString()?.toLowerCase()?.contains(_searchQuery.toLowerCase()) ?? false);
                  }).toList();
                }

                // Sort by most recent first
                transactions.sort((a, b) {
                  final aTime = a['date'] ?? a['createdAt'] ?? 0;
                  final bTime = b['date'] ?? b['createdAt'] ?? 0;
                  return bTime.compareTo(aTime);
                });

                if (transactions.isEmpty) {
                  return const Center(
                    child: Text('No transactions match your filters'),
                  );
                }

                // Calculate totals
                double total = 0;
                transactions.forEach((transaction) {
                  if (transaction['paymentStatus'] == 'paid') {
                    total += transaction['amount'];
                  }
                });

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[200],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Transactions: ${transactions.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Total Revenue: ${_formatCurrency(total)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          final status = transaction['paymentStatus'] ?? 'pending';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Transaction #${transaction['orderId'].toString().substring(0, 8)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Chip(
                                        label: Text(
                                          status,
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: _getStatusColor(status),
                                      ),
                                    ],
                                  ),
                                  Text('Customer: ${transaction['customerName']}'),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Date: ${_formatTimestamp(transaction['date'])}'),
                                  Text('Method: ${transaction['paymentMethod']}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Amount: ${_formatCurrency(transaction['amount'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () => _showTransactionDetails(transaction),
                              ),
                              onTap: () => _showTransactionDetails(transaction),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    // We'll need to fetch the full order details
    _database.ref('orders/${transaction['orderId']}').get().then((snapshot) {
      if (!snapshot.exists || !mounted) return;
      
      final orderData = snapshot.value as Map<dynamic, dynamic>;
      
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
                    const Text(
                      'Transaction Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        title: const Text('Transaction ID'),
                        subtitle: Text(transaction['orderId'] ?? 'N/A'),
                      ),
                      ListTile(
                        title: const Text('Payment Status'),
                        subtitle: Chip(
                          label: Text(
                            transaction['paymentStatus'] ?? 'pending',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _getStatusColor(transaction['paymentStatus'] ?? 'pending'),
                        ),
                      ),
                      ListTile(
                        title: const Text('Payment Method'),
                        subtitle: Text(transaction['paymentMethod'] ?? 'N/A'),
                      ),
                      ListTile(
                        title: const Text('Customer'),
                        subtitle: Text(transaction['customerName'] ?? 'Unknown'),
                      ),
                      ListTile(
                        title: const Text('Date'),
                        subtitle: Text(_formatTimestamp(transaction['date'])),
                      ),
                      ListTile(
                        title: const Text('Amount'),
                        subtitle: Text(_formatCurrency(transaction['amount'])),
                        trailing: transaction['paymentStatus'] == 'paid' 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                      ),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Text(
                          'Order Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('Order Status'),
                        subtitle: Text(orderData['status'] ?? 'pending'),
                      ),
                      if (orderData['items'] != null) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, top: 8.0),
                          child: Text(
                            'Items',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (orderData['items'] as List).length,
                          itemBuilder: (context, index) {
                            final item = (orderData['items'] as List)[index];
                            return ListTile(
                              dense: true,
                              title: Text(item['name'] ?? 'Unknown Item'),
                              trailing: Text('${item['quantity']} × ${_formatCurrency((item['price'] as num).toDouble())}'),
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
                              'Payment Breakdown',
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
                                Text(_formatCurrency((orderData['subtotal'] as num?)?.toDouble() ?? 0.0)),
                              ],
                            ),
                            if (orderData['discountAmount'] != null && (orderData['discountAmount'] as num) > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Discount'),
                                  Text('-${_formatCurrency((orderData['discountAmount'] as num).toDouble())}'),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Delivery Fee'),
                                Text(_formatCurrency((orderData['deliveryFee'] as num?)?.toDouble() ?? 0.0)),
                              ],
                            ),
                            if (orderData['tipAmount'] != null && (orderData['tipAmount'] as num) > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Tip'),
                                  Text(_formatCurrency((orderData['tipAmount'] as num).toDouble())),
                                ],
                              ),
                            ],
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _formatCurrency((orderData['total'] as num?)?.toDouble() ?? 0.0),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (transaction['paymentStatus'] != 'refunded') ...[
                        ElevatedButton(
                          onPressed: transaction['paymentStatus'] == 'paid' 
                              ? () => _processRefund(transaction) 
                              : null,
                          child: const Text('Process Refund'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _processRefund(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Process Refund'),
          content: const Text('Are you sure you want to process a refund for this transaction?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _database.ref('orders/${transaction['orderId']}').update({
                    'paymentStatus': 'refunded',
                    'refundedAt': ServerValue.timestamp,
                  });
                  
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refund processed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error processing refund: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Refund'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
} 