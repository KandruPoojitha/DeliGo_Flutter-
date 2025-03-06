import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/driver_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _database = FirebaseDatabase.instance;
  final _driverService = DriverService();
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
      } else {
        // Load other users from their respective collections
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
              child: _isLoading
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
    } else {
      // Handle other user types...
    }
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
                        color: user['status'] == 'approved' 
                            ? Colors.green.withAlpha(51)
                            : Colors.orange.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user['status'] == 'approved' ? 'Approved' : 'Pending Review',
                        style: TextStyle(
                          color: user['status'] == 'approved' ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Name: ${user['name']}'),
                Text('Email: ${user['email']}'),
                Text('Phone: ${user['phone']}'),
                const SizedBox(height: 16),
                if (user['documentsSubmitted'] == true && user['documents'] != null) ...[
                  Text(
                    'Documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Driver License:'),
                            const SizedBox(height: 4),
                            if (user['documents']['license']?['url'] != null)
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
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Government ID:'),
                            const SizedBox(height: 4),
                            if (user['documents']['govt_id']?['url'] != null)
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
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (user['status'] != 'approved') ...[
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
} 