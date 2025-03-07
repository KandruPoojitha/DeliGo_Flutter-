import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/restaurant_service.dart';
import '../models/restaurant.dart';
import '../providers/theme_provider.dart';
import 'login_page.dart';
import 'add_menu_item_page.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key});

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage> {
  final _user = FirebaseAuth.instance.currentUser;
  final _restaurantService = RestaurantService();
  int _selectedIndex = 0;
  bool _isOpen = false;
  Restaurant? _restaurant;
  int _ordersTabIndex = 0;
  bool _isDarkMode = false;
  bool _isEnglish = true;
  final _menuItemsCount = ValueNotifier<int>(0);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aboutController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, Map<String, dynamic>> _businessHours = {
    'Monday': {'opening': '09:00', 'closing': '22:00', 'isOpen': true},
    'Tuesday': {'opening': '09:00', 'closing': '22:00', 'isOpen': true},
    'Wednesday': {'opening': '09:00', 'closing': '22:00', 'isOpen': true},
    'Thursday': {'opening': '09:00', 'closing': '22:00', 'isOpen': true},
    'Friday': {'opening': '09:00', 'closing': '23:00', 'isOpen': true},
    'Saturday': {'opening': '09:00', 'closing': '23:00', 'isOpen': true},
    'Sunday': {'opening': '09:00', 'closing': '22:00', 'isOpen': true},
  };
  List<Map<String, dynamic>> _predictions = [];
  bool _isLoadingAddresses = false;
  final String _apiKey = 'AIzaSyDHujk0Z7p3_mjmPsicmn7T9iyQBC0ZqtU';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _aboutController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    _menuItemsCount.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurantData() async {
    if (_user != null) {
      print('Loading restaurant data for user: ${_user!.uid}');
      print('User email: ${_user!.email}');
      
      try {
        final restaurant = await _restaurantService.getRestaurant(_user!.uid);
        print('Restaurant data loaded: ${restaurant?.toMap()}');
        
        if (restaurant != null) {
          print('Setting restaurant data in state:');
          print('Full Name: ${restaurant.fullName}');
          print('Email: ${restaurant.email}');
          
          if (mounted) {
            setState(() {
              _restaurant = restaurant;
              _updateOpenStatus(restaurant);
              _nameController.text = restaurant.fullName;
              _emailController.text = restaurant.email;
              _phoneController.text = restaurant.phone;
              _addressController.text = restaurant.address ?? '';
              if (restaurant.hours != null) {
                _businessHours = Map<String, Map<String, dynamic>>.from(restaurant.hours!);
              }
            });
            print('State updated with restaurant data');
          }
        } else {
          print('No restaurant data found for user: ${_user!.uid}');
          // Try to fetch the data directly from Firebase to debug
          final snapshot = await FirebaseDatabase.instance
              .ref()
              .child('restaurants')
              .child(_user!.uid)
              .get();
          print('Direct Firebase data: ${snapshot.value}');
        }
      } catch (e) {
        print('Error loading restaurant data: $e');
      }
    } else {
      print('No user logged in');
    }
  }

  void _updateOpenStatus(Restaurant restaurant) {
    if (restaurant.hours != null) {
      final now = DateTime.now();
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final openingTime = restaurant.hours!['opening'] as String;
      final closingTime = restaurant.hours!['closing'] as String;
      
      setState(() {
        _isOpen = currentTime.compareTo(openingTime) >= 0 && 
                  currentTime.compareTo(closingTime) <= 0 &&
                  restaurant.hours!['isOpen'] == true;
      });
    }
  }

  Future<void> _toggleOpenStatus() async {
    if (_restaurant != null) {
      final newStatus = !_isOpen;
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(_user!.uid)
            .child('hours')
            .update({
          'isOpen': newStatus,
        });
        
        setState(() {
          _isOpen = newStatus;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Restaurant is now ${newStatus ? 'open' : 'closed'}'),
              backgroundColor: newStatus ? Colors.green : Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error updating restaurant status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Upload image to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('restaurants')
            .child(user.uid)
            .child('profile_image');
        
        await storageRef.putFile(File(image.path));
        final imageUrl = await storageRef.getDownloadURL();

        // Update restaurant profile image in database
        await FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(user.uid)
            .update({
          'profileImageUrl': imageUrl,
          'updatedAt': ServerValue.timestamp,
        });

        // Update local state
        if (_restaurant != null) {
          setState(() {
            _restaurant = _restaurant!.copyWith(profileImageUrl: imageUrl);
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile image: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _selectTime(BuildContext context, String day, bool isOpening) async {
    final currentTime = _businessHours[day]?[isOpening ? 'opening' : 'closing'] ?? '09:00';
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    
    if (picked != null) {
      setState(() {
        _businessHours[day]![isOpening ? 'opening' : 'closing'] = 
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _toggleDayOpen(String day) async {
    setState(() {
      _businessHours[day]!['isOpen'] = !(_businessHours[day]!['isOpen'] == true);
    });
    // TODO: Update in Firebase
  }

  Future<void> _saveStoreSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Check if email is being changed
        if (_emailController.text != user.email) {
          // Update email in Firebase Auth
          await user.updateEmail(_emailController.text);
        }

        // Update restaurant data in database
        await FirebaseDatabase.instance
            .ref()
            .child('restaurants')
            .child(user.uid)
            .update({
          'fullName': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'address': _addressController.text,
          'about': _aboutController.text,
          'hours': _businessHours,
          'updatedAt': ServerValue.timestamp,
        });
        
        // Update local state
        if (_restaurant != null) {
          setState(() {
            _restaurant = _restaurant!.copyWith(
              fullName: _nameController.text,
              email: _emailController.text,
              phone: _phoneController.text,
              address: _addressController.text,
              about: _aboutController.text,
              hours: _businessHours,
            );
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Store settings updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating store settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Future<void> _getPlacePredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        _predictions = [];
        _isLoadingAddresses = false;
      });
      return;
    }

    setState(() {
      _isLoadingAddresses = true;
    });

    try {
      final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$input'
        '&key=$_apiKey'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(data['predictions']);
            _isLoadingAddresses = false;
          });
        } else {
          setState(() {
            _isLoadingAddresses = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${data['status']}')),
            );
          }
        }
      } else {
        setState(() {
          _isLoadingAddresses = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error fetching addresses')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingAddresses = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> prediction) async {
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
            _addressController.text = prediction['description'];
            _predictions = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting place details: $e')),
        );
      }
    }
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOrderTabButton('New Orders', 0),
              _buildOrderTabButton('In Progress', 1),
              _buildOrderTabButton('Delivered', 2),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _ordersTabIndex,
            children: [
              // New Orders
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Orders Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'New orders will appear here',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // In Progress
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.restaurant,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Orders In Progress',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Orders being prepared will appear here',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Delivered
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Delivered Orders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Completed orders will appear here',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTabButton(String label, int index) {
    final isSelected = _ordersTabIndex == index;
    return TextButton(
      onPressed: () {
        setState(() {
          _ordersTabIndex = index;
        });
      },
      style: TextButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFFF4A261) : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : Colors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter address';
            }
            return null;
          },
          onChanged: (value) {
            _getPlacePredictions(value);
          },
        ),
        if (_isLoadingAddresses)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        if (_predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(prediction['description']),
                  onTap: () => _selectPlace(prediction),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMenuTab() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_user!.uid)
          .child('menu_items')
          .onValue,
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

        final menuItems = snapshot.data?.snapshot.value as Map?;
        _menuItemsCount.value = menuItems?.length ?? 0;

        if (menuItems == null || menuItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Menu Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your first menu item',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMenuItemPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Filter menu items based on search query
        final filteredItems = menuItems.entries.where((entry) {
          final item = entry.value as Map;
          final name = (item['name'] ?? '').toString().toLowerCase();
          final description = (item['description'] ?? '').toString().toLowerCase();
          final searchLower = _searchQuery.toLowerCase();
          
          return name.contains(searchLower) || description.contains(searchLower);
        }).toList();

        return Stack(
          children: [
            Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search menu items...',
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
                // Menu Items List
                Expanded(
                  child: filteredItems.isEmpty && _searchQuery.isNotEmpty
                      ? Center(
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
                                'No menu items match "$_searchQuery"',
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final entry = filteredItems[index];
                            final item = entry.value as Map;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                children: [
                                  if (item['imageUrl'] != null)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      child: Image.network(
                                        item['imageUrl'],
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ListTile(
                                    title: Text(
                                      item['name'] ?? 'Unnamed Item',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['description'] ?? ''),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${(item['price'] ?? 0.0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Menu Item'),
                                            content: const Text('Are you sure you want to delete this menu item?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          try {
                                            await FirebaseDatabase.instance
                                                .ref()
                                                .child('restaurants')
                                                .child(_user!.uid)
                                                .child('menu_items')
                                                .child(entry.key)
                                                .remove();
                                            
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Menu item deleted successfully')),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error deleting menu item: $e')),
                                              );
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            // Bottom Add Item Button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddMenuItemPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A261),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

  Widget _buildAccountTab() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _restaurant?.profileImageUrl != null
                            ? NetworkImage(_restaurant!.profileImageUrl!)
                            : null,
                        child: _restaurant?.profileImageUrl == null
                            ? const Icon(Icons.restaurant, size: 50)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFFF4A261),
                          radius: 18,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  onPressed: _pickImage,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _restaurant?.fullName ?? 'Restaurant Name',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    _restaurant?.email ?? '',
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Store Settings Main Section
            Text(
              'Store Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),

            // Store Information Section
            Card(
              child: ExpansionTile(
                title: const Text(
                  'Store Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                leading: const Icon(Icons.store),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Restaurant Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter restaurant name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAddressField(),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _aboutController,
                          decoration: const InputDecoration(
                            labelText: 'About',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Store Hours Section
            Card(
              child: ExpansionTile(
                title: const Text(
                  'Store Hours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                leading: const Icon(Icons.access_time),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: _businessHours.entries.map((entry) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Switch(
                                    value: entry.value['isOpen'] == true,
                                    onChanged: (value) => _toggleDayOpen(entry.key),
                                  ),
                                ],
                              ),
                              if (entry.value['isOpen'] == true) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () => _selectTime(context, entry.key, true),
                                        icon: const Icon(Icons.access_time),
                                        label: Text(entry.value['opening']!),
                                      ),
                                    ),
                                    const Text('to'),
                                    Expanded(
                                      child: TextButton.icon(
                                        onPressed: () => _selectTime(context, entry.key, false),
                                        icon: const Icon(Icons.access_time),
                                        label: Text(entry.value['closing']!),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Appearance Main Section
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),

            // Dark Mode Section
            Card(
              child: ExpansionTile(
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                leading: Icon(
                  Icons.dark_mode,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SwitchListTile(
                      title: Text(
                        'Enable Dark Mode',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Language Section
            Card(
              child: ExpansionTile(
                title: const Text(
                  'Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                leading: const Icon(Icons.language),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SwitchListTile(
                      title: const Text('English'),
                      subtitle: Text(_isEnglish ? 'English' : 'French'),
                      value: _isEnglish,
                      onChanged: (value) {
                        setState(() {
                          _isEnglish = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveStoreSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4A261),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _restaurant?.fullName ?? 'Restaurant',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text(
                  _isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    color: _isOpen ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isOpen,
                  onChanged: (value) => _toggleOpenStatus(),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Orders Tab
          _buildOrdersTab(),
          
          // Menu Tab
          _buildMenuTab(),
          
          // Account Tab
          _buildAccountTab(),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _menuItemsCount,
        builder: (context, count, child) {
          if (_selectedIndex == 1 && count > 0) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddMenuItemPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Item',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: const Color(0xFFF4A261),
              elevation: 4,
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
} 