import 'package:flutter/material.dart';
import '../../../services/admin_service.dart';
import 'package:firebase_database/firebase_database.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _database = FirebaseDatabase.instance;
  String? _selectedCategory;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  Future<void> _loadUsers(String category) async {
    setState(() {
      _isLoading = true;
      _users.clear();
    });

    try {
      // Convert category to collection name (e.g., Customer -> customers)
      final collectionName = '${category.toLowerCase()}s';
      
      final snapshot = await _database.ref(collectionName).get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        _users = data.entries.map((entry) {
          final userData = entry.value as Map<dynamic, dynamic>;
          return {
            'id': entry.key,
            'name': userData['fullName'] ?? 'Unknown',
            'email': userData['email'] ?? '',
            'status': userData['status'] ?? 'active',
            'createdAt': userData['createdAt'],
            'blockedAt': userData['blockedAt'],
          };
        }).toList();
      }
    } catch (e) {
      print('Error loading users: $e');
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
                    ? '${_selectedCategory} List'
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Name', user['name']),
            _detailRow('Email', user['email']),
            _detailRow('Role', _selectedCategory ?? 'Unknown'),
            _detailRow('Status', user['status']),
            _detailRow('Created At', _formatTimestamp(user['createdAt'])),
            if (user['status'] == 'blocked')
              _detailRow('Blocked At', _formatTimestamp(user['blockedAt'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    if (timestamp is DateTime) {
      return timestamp.toLocal().toString();
    }
    
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(
        timestamp is int ? timestamp : int.parse(timestamp.toString())
      );
      return dateTime.toLocal().toString();
    } catch (e) {
      return 'Invalid date';
    }
  }
} 