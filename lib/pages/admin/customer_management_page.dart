import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
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
          // Customer List
          Expanded(
            child: StreamBuilder(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('customers')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final customers = snapshot.data?.snapshot.value as Map?;

                if (customers == null || customers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Customers Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Customer information will appear here',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter customers based on search query
                final filteredCustomers = customers.entries.where((entry) {
                  final customer = entry.value as Map;
                  final name = (customer['fullName'] ?? '').toString().toLowerCase();
                  final email = (customer['email'] ?? '').toString().toLowerCase();
                  final phone = (customer['phone'] ?? '').toString().toLowerCase();
                  final searchLower = _searchQuery.toLowerCase();
                  
                  return name.contains(searchLower) || 
                         email.contains(searchLower) || 
                         phone.contains(searchLower);
                }).toList();

                if (filteredCustomers.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
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
                          'No customers match "$_searchQuery"',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final entry = filteredCustomers[index];
                    final customer = entry.value as Map;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF4A261),
                          child: Text(
                            (customer['fullName'] ?? 'C')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          customer['fullName'] ?? 'Unnamed Customer',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer['email'] ?? 'No email',
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            if (customer['blocked'] == true)
                              const Text(
                                'BLOCKED',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Email', customer['email'] ?? 'N/A'),
                                _buildInfoRow('Phone', customer['phone'] ?? 'N/A'),
                                _buildInfoRow('Address', customer['address'] ?? 'N/A'),
                                if (customer['createdAt'] != null)
                                  _buildInfoRow(
                                    'Member Since',
                                    DateTime.fromMillisecondsSinceEpoch(customer['createdAt'])
                                        .toString()
                                        .split(' ')[0],
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        // TODO: Implement view order history
                                      },
                                      icon: const Icon(Icons.history),
                                      label: const Text('View Orders'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () {
                                        // TODO: Implement contact customer
                                      },
                                      icon: const Icon(Icons.message),
                                      label: const Text('Contact'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () {
                                        _toggleUserBlock(entry.key, customer['blocked'] == true);
                                      },
                                      icon: const Icon(Icons.block),
                                      label: Text(customer['blocked'] == true ? 'Unblock' : 'Block'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: customer['blocked'] == true ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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

  Future<void> _toggleUserBlock(String customerId, bool isBlocked) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isBlocked ? 'Unblock Customer' : 'Block Customer'),
          content: Text('Are you sure you want to ${isBlocked ? 'unblock' : 'block'} this customer?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isBlocked ? 'Unblock' : 'Block'),
              style: TextButton.styleFrom(
                foregroundColor: isBlocked ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Toggle blocked status (simply flip the current state)
        await FirebaseDatabase.instance.ref('customers')
            .child(customerId)
            .update({
              'blocked': !isBlocked,
              'blockedAt': !isBlocked ? ServerValue.timestamp : null,
            });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${!isBlocked ? 'blocked' : 'unblocked'} successfully'),
            ),
          );
          
          // Refresh the customer list
          setState(() {
            _isLoading = true;
            // This will trigger the UI to show loading state briefly
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            });
          });
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 