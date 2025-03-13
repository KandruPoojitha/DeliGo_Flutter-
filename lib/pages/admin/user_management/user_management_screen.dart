import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/driver_service.dart';
import '../../../services/restaurant_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _database = FirebaseDatabase.instance;
  final _driverService = DriverService();
  final _restaurantService = RestaurantService();
  String? _selectedCategory;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  Future<void> _loadUsers(String category) async {
    setState(() {
      _isLoading = true;
      _users.clear();
    });

    try {
      if (category == 'Driver') {
        // Load drivers directly from the drivers collection
        final snapshot = await _database.ref('drivers').get();
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          
          _users = data.entries.map((entry) {
            final userData = entry.value as Map<dynamic, dynamic>;
            return {
              'id': entry.key,
              'name': userData['fullName'] ?? 'Unknown',
              'email': userData['email'] ?? '',
              'phone': userData['phone'] ?? '',
              'status': userData['status'] ?? 'pending_review',
              'documentsSubmitted': userData['documentsSubmitted'] ?? false,
              'documents': userData['documents'],
              'createdAt': userData['createdAt'],
              'updatedAt': userData['updatedAt'],
            };
          }).toList();
        }
      } else if (category == 'Restaurant') {
        // Load restaurants from the restaurants collection
        final snapshot = await _database.ref('restaurants').get();
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          
          _users = data.entries.map((entry) {
            final userData = entry.value as Map<dynamic, dynamic>;
            final storeInfo = userData['store_info'] as Map<dynamic, dynamic>? ?? {};
            return {
              'id': entry.key,
              'store_info': {
                'name': storeInfo['name'] ?? 'Unknown',
                'email': storeInfo['email'] ?? '',
                'phone': storeInfo['phone'] ?? '',
                'address': storeInfo['address'] ?? '',
              },
              'documentsSubmitted': userData['documentsSubmitted'] ?? false,
              'documents': userData['documents'],
              'hours': userData['hours'],
              'isOpen': userData['isOpen'] ?? false,
              'createdAt': userData['createdAt'],
              'updatedAt': userData['updatedAt'],
            };
          }).toList();
        }
      } else {

        final collectionName = '${category}s';
        final snapshot = await _database.ref(collectionName).get();
        
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          
          _users = data.entries.map((entry) {
            final userData = entry.value as Map<dynamic, dynamic>;
            return {
              'id': entry.key,
              'name': userData['fullName'] ?? 'Unknown',
              'email': userData['email'] ?? '',
              'phone': userData['phone'] ?? '',
              'status': userData['status'] ?? 'active',
              'createdAt': userData['createdAt'],
              'blockedAt': userData['blockedAt'],
            };
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'User Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Category buttons in a row with equal width
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _buildCategoryButton('Customer'),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildCategoryButton('Driver'),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildCategoryButton('Restaurant'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selectedCategory != null 
                    ? '$_selectedCategory List'
                    : 'Select a category',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // User list
            Expanded(
              child: _selectedCategory == 'Customer'
                  ? StreamBuilder(
                      stream: _database.ref('customers').onValue,
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

                        final customerList = customers.entries.map((entry) {
                          final userData = entry.value as Map<dynamic, dynamic>;
                          return {
                            'id': entry.key,
                            'name': userData['fullName'] ?? 'Unknown',
                            'email': userData['email'] ?? '',
                            'phone': userData['phone'] ?? '',
                            'status': userData['status'] ?? 'active',
                            'address': userData['address'],
                            'createdAt': userData['createdAt'],
                            'blockedAt': userData['blockedAt'],
                          };
                        }).toList();

                        return ListView.builder(
                          itemCount: customerList.length,
                          itemBuilder: (context, index) {
                            final user = customerList[index];
                            final isBlocked = user['status'] == 'blocked';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFF4A261),
                                  child: Text(
                                    user['name']?[0] ?? '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(user['name'] ?? 'Unknown'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user['email'] ?? ''),
                                    Text(
                                      'Status: ${user['status'] ?? 'active'}',
                                      style: TextStyle(
                                        color: isBlocked ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) => _handleUserAction(value, user),
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Text('View Details'),
                                    ),
                                    PopupMenuItem(
                                      value: isBlocked ? 'unblock' : 'block',
                                      child: Text(isBlocked ? 'Unblock User' : 'Block User'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _users.isEmpty
                          ? const Center(child: Text('No users found'))
                          : ListView.builder(
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final isBlocked = user['status'] == 'blocked';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFF4A261),
                                      child: Text(
                                        _selectedCategory == 'Driver' 
                                            ? (user['name'] ?? 'Unknown')[0].toUpperCase()
                                            : (user['store_info']?['name'] ?? 'Unknown')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Text(_selectedCategory == 'Driver' 
                                        ? user['name'] ?? 'Unknown'
                                        : user['store_info']?['name'] ?? 'Unknown'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (_selectedCategory == 'Driver') ...[
                                          Text(user['email'] ?? ''),
                                          Text(user['phone'] ?? ''),
                                          Text(
                                            'Status: ${user['documents']?['status'] ?? 'pending_review'}',
                                            style: TextStyle(
                                              color: user['documents']?['status'] == 'approved' ? Colors.green : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ] else ...[
                                          Text(user['store_info']?['email'] ?? ''),
                                          Text(user['store_info']?['phone'] ?? ''),
                                          Text(
                                            'Status: ${user['documents']?['status'] ?? 'pending_review'}',
                                            style: TextStyle(
                                              color: user['documents']?['status'] == 'approved' ? Colors.green : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) => _handleUserAction(value, user),
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem(
                                          value: 'view',
                                          child: Text('View Details'),
                                        ),
                                        if (_selectedCategory == 'Restaurant')
                                          PopupMenuItem(
                                            value: user['documents']?['status'] == 'approved' ? 'reject' : 'approve',
                                            child: Text(user['documents']?['status'] == 'approved' ? 'Reject' : 'Approve'),
                                    ),
                                    PopupMenuItem(
                                      value: isBlocked ? 'unblock' : 'block',
                                      child: Text(isBlocked ? 'Unblock User' : 'Block User'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String category) {
    final isSelected = _selectedCategory == category;
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedCategory = category;
        });
        _loadUsers(category);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
        elevation: isSelected ? 4 : 2,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _handleUserAction(String action, Map<String, dynamic> user) async {
    switch (action) {
      case 'view':
        _viewUserDetails(user);
        break;
      case 'approve':
        if (_selectedCategory == 'Driver') {
          await _driverService.updateDriverApproval(user['id'], true);
        } else if (_selectedCategory == 'Restaurant') {
          await _restaurantService.updateRestaurantApproval(user['id'], true);
        }
        _loadUsers(_selectedCategory!);
        break;
      case 'reject':
        if (_selectedCategory == 'Driver') {
          await _driverService.updateDriverApproval(user['id'], false);
        } else if (_selectedCategory == 'Restaurant') {
          await _restaurantService.updateRestaurantApproval(user['id'], false);
        }
        _loadUsers(_selectedCategory!);
        break;
      case 'block':
      case 'unblock':
        await _toggleUserBlock(user, action == 'block');
        break;
    }
  }

  Future<void> _toggleUserBlock(Map<String, dynamic> user, bool block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${block ? 'Block' : 'Unblock'} User'),
        content: Text('Are you sure you want to ${block ? 'block' : 'unblock'} ${user['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(block ? 'Block' : 'Unblock'),
            style: TextButton.styleFrom(
              foregroundColor: block ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && _selectedCategory != null) {
      try {
        final collectionName = '${_selectedCategory!.toLowerCase()}s';
        await _database.ref(collectionName)
            .child(user['id'])
            .update({
              'status': block ? 'blocked' : 'active',
              'blockedAt': block ? ServerValue.timestamp : null,
            });
        
        // Reload the users list
        _loadUsers(_selectedCategory!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User ${block ? 'blocked' : 'unblocked'} successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error updating user status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewUserDetails(Map<String, dynamic> user) {
    if (_selectedCategory == 'Driver') {
      _showDriverVerificationDialog(user);
    } else if (_selectedCategory == 'Restaurant') {
      _showRestaurantVerificationDialog(user);
    } else if (_selectedCategory == 'Customer') {
      _showCustomerDetailsDialog(user);
    }
  }

  Future<void> _showRestaurantVerificationDialog(Map<String, dynamic> user) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Restaurant Verification',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: user['documents']?['status'] == 'approved' 
                            ? Colors.green.withAlpha(51)
                            : Colors.orange.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user['documents']?['status'] == 'approved' ? 'Approved' : 'Pending Review',
                        style: TextStyle(
                          color: user['documents']?['status'] == 'approved' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Store Information
                Text(
                  'Store Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (user['store_info'] != null) ...[
                  _buildDetailRow('Name', user['store_info']['name'] ?? 'N/A'),
                  _buildDetailRow('Email', user['store_info']['email'] ?? 'N/A'),
                  _buildDetailRow('Phone', user['store_info']['phone'] ?? 'N/A'),
                  _buildDetailRow('Address', user['store_info']['address'] ?? 'N/A'),
                ],
                const SizedBox(height: 16),

                // Business Hours
                if (user['hours'] != null) ...[
                  Text(
                    'Business Hours',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Opening Time', user['hours']['opening'] ?? 'N/A'),
                  _buildDetailRow('Closing Time', user['hours']['closing'] ?? 'N/A'),
                  _buildDetailRow('Status', (user['isOpen'] ?? false) ? 'Open' : 'Closed'),
                ],
                const SizedBox(height: 16),

                // Documents
                if (user['documentsSubmitted'] && user['documents'] != null) ...[
                  Text(
                    'Documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (user['documents']['files'] != null) ...[
                    if (user['documents']['files']['restaurant_proof'] != null) ...[
                      const Text('Restaurant Proof:'),
                      const SizedBox(height: 4),
                      if (user['documents']['files']['restaurant_proof']['url'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: user['documents']['files']['restaurant_proof']['url'],
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    if (user['documents']['files']['owner_id'] != null) ...[
                      const Text('Owner ID:'),
                      const SizedBox(height: 4),
                      if (user['documents']['files']['owner_id']['url'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: user['documents']['files']['owner_id']['url'],
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  if (user['documents']?['status'] != 'approved') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _restaurantService.updateRestaurantApproval(user['id'], false);
                            if (mounted) {
                              Navigator.pop(context);
                              _loadUsers('Restaurant');
                            }
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _restaurantService.updateRestaurantApproval(user['id'], true);
                            if (mounted) {
                              Navigator.pop(context);
                              _loadUsers('Restaurant');
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else
                  const Text('No documents uploaded yet'),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDriverVerificationDialog(Map<String, dynamic> user) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Driver Verification',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: user['documents']?['status'] == 'approved' 
                            ? Colors.green.withAlpha(51)
                            : Colors.orange.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user['documents']?['status'] == 'approved' ? 'Approved' : 'Pending Review',
                        style: TextStyle(
                          color: user['documents']?['status'] == 'approved' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Driver Information
                Text(
                  'Driver Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Name', user['name'] ?? 'N/A'),
                _buildDetailRow('Email', user['email'] ?? 'N/A'),
                _buildDetailRow('Phone', user['phone'] ?? 'N/A'),
                const SizedBox(height: 16),

                // Documents
                if (user['documentsSubmitted'] && user['documents'] != null) ...[
                  Text(
                    'Documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (user['documents']['license'] != null) ...[
                            const Text('Driver License:'),
                            const SizedBox(height: 4),
                    if (user['documents']['license']['url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: user['documents']['license']['url'],
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                              ),
                          ],
                  const SizedBox(height: 16),
                  if (user['documents']['govt_id'] != null) ...[
                            const Text('Government ID:'),
                            const SizedBox(height: 4),
                    if (user['documents']['govt_id']['url'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: user['documents']['govt_id']['url'],
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                              ),
                          ],
                  const SizedBox(height: 16),
                  if (user['documents']?['status'] != 'approved') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _driverService.updateDriverApproval(user['id'], false);
                            if (mounted) {
                              Navigator.pop(context);
                              _loadUsers('Driver');
                            }
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _driverService.updateDriverApproval(user['id'], true);
                            if (mounted) {
                              Navigator.pop(context);
                              _loadUsers('Driver');
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else
                  const Text('No documents uploaded yet'),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomerDetailsDialog(Map<String, dynamic> user) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: user['status'] == 'blocked' 
                            ? Colors.red.withAlpha(51)
                            : Colors.green.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user['status'] == 'blocked' ? 'Blocked' : 'Active',
                        style: TextStyle(
                          color: user['status'] == 'blocked' ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Name', user['name'] ?? 'Unknown'),
                _buildDetailRow('Email', user['email'] ?? ''),
                _buildDetailRow('Phone', user['phone'] ?? ''),
                if (user['address'] != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Address', user['address']),
                ],
                const SizedBox(height: 8),
                _buildDetailRow('Member Since', _formatDate(user['createdAt'])),
                if (user['blockedAt'] != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Blocked On', _formatDate(user['blockedAt'])),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement view orders functionality
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View Orders'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4A261),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement contact functionality
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4A261),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    DateTime date;
    if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      try {
        // Try parsing as ISO string
        date = DateTime.parse(timestamp);
      } catch (e) {
        return 'Invalid Date';
      }
    } else {
      return 'Invalid Date';
    }
    
    return '${date.day}/${date.month}/${date.year}';
  }
} 