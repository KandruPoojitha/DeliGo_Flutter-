import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'login_page.dart';
import 'restaurant_details_page.dart';
import 'checkout_page.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  int _selectedIndex = 0;
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  List<MapEntry> _filteredRestaurants = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
          // Sort restaurants when location is updated
          _sortRestaurantsByDistance();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _sortRestaurantsByDistance() {
    if (_currentPosition == null) return;
    
    _filteredRestaurants.sort((a, b) {
      final distanceA = _calculateDistance(a.value as Map);
      final distanceB = _calculateDistance(b.value as Map);
      // Put restaurants with unavailable distances at the end
      if (distanceA == -1) return 1;
      if (distanceB == -1) return -1;
      // Sort by distance (nearest first)
      return distanceA.compareTo(distanceB);
    });
  }

  double _calculateDistance(Map restaurant) {
    if (_currentPosition == null) return -1;
    
    final location = restaurant['location'] as Map?;
    if (location == null) return -1;

    final latitude = location['latitude'] as double?;
    final longitude = location['longitude'] as double?;
    
    if (latitude == null || longitude == null) return -1;

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latitude,
      longitude,
    ) / 1000; // Convert meters to kilometers
  }

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 0) return 'Distance not available';
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)}m away';
    }
    return '${distanceInKm.toStringAsFixed(1)}km away';
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildFavoritesTab();
      case 2:
        return _buildCartTab();
      case 3:
        return _buildOrdersTab();
      case 4:
        return _buildAccountTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search restaurants...',
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
        // Current Location Display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isLoadingLocation
                      ? 'Getting your location...'
                      : _currentPosition != null
                          ? 'Your location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                          : 'Location not available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Sort by Distance Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _currentPosition != null
                  ? () {
                      setState(() {
                        _sortRestaurantsByDistance();
                      });
                    }
                  : null,
              icon: const Icon(Icons.sort),
              label: const Text('Sort by Distance (Nearest First)'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF4A261),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ),
        // Restaurant List
        Expanded(
          child: StreamBuilder(
            stream: FirebaseDatabase.instance
                .ref()
                .child('restaurants')
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

              final restaurants = snapshot.data?.snapshot.value as Map?;

              if (restaurants == null || restaurants.isEmpty) {
                return Center(
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
                        'No Restaurants Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Restaurants will appear here',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Filter restaurants based on search query and approval status
              _filteredRestaurants = restaurants.entries.where((entry) {
                final restaurant = entry.value as Map;
                final storeInfo = restaurant['store_info'] as Map?;
                if (storeInfo == null) return false;

                // Check if restaurant is approved
                final documents = restaurant['documents'] as Map?;
                if (documents == null || documents['status'] != 'approved') return false;
                
                final name = (storeInfo['name'] ?? '').toString().toLowerCase();
                final address = (storeInfo['address'] ?? '').toString().toLowerCase();
                final searchLower = _searchQuery.toLowerCase();
                
                return name.contains(searchLower) || address.contains(searchLower);
              }).toList();

              // Sort restaurants by distance if location is available
              if (_currentPosition != null) {
                _sortRestaurantsByDistance();
              }

              if (_filteredRestaurants.isEmpty) {
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
                        'No Restaurants Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty 
                            ? 'No restaurants match "$_searchQuery"'
                            : 'No approved restaurants available',
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
                itemCount: _filteredRestaurants.length,
                itemBuilder: (context, index) {
                  final entry = _filteredRestaurants[index];
                  final restaurant = entry.value as Map;
                  final storeInfo = restaurant['store_info'] as Map? ?? {};
                  final distance = _calculateDistance(restaurant);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF4A261),
                        child: Text(
                          (storeInfo['name'] ?? 'R')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              storeInfo['name'] ?? 'Unnamed Restaurant',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!_isLoadingLocation) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatDistance(distance),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(storeInfo['rating'] ?? 0.0).toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                restaurant['isOpen'] == true ? Icons.circle : Icons.circle_outlined,
                                size: 12,
                                color: restaurant['isOpen'] == true ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                restaurant['isOpen'] == true ? 'Open' : 'Closed',
                                style: TextStyle(
                                  color: restaurant['isOpen'] == true ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RestaurantDetailsPage(
                              restaurantId: entry.key,
                              restaurant: Map<String, dynamic>.from(restaurant),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesTab() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(FirebaseAuth.instance.currentUser?.uid ?? '')
          .child('favorites')
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

        final favorites = snapshot.data?.snapshot.value as Map?;
        if (favorites == null || favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Favorite Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your favorite items will appear here',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        // Get all favorite item IDs (only include items where the value is true)
        final favoriteItemIds = favorites.entries
            .where((entry) => entry.value == true)
            .map((entry) => entry.key)
            .toList();

        // Stream for all restaurants to get menu items
        return StreamBuilder(
          stream: FirebaseDatabase.instance
              .ref()
              .child('restaurants')
              .onValue,
          builder: (context, restaurantSnapshot) {
            if (restaurantSnapshot.hasError) {
              return Center(
                child: Text('Error: ${restaurantSnapshot.error}'),
              );
            }

            if (restaurantSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final restaurants = restaurantSnapshot.data?.snapshot.value as Map?;
            if (restaurants == null) {
              return const Center(
                child: Text('No restaurants available'),
              );
            }

            // Collect all favorite menu items
            List<Map<String, dynamic>> favoriteItems = [];
            for (var restaurant in restaurants.entries) {
              final restaurantId = restaurant.key;
              final restaurantData = restaurant.value as Map;
              final menuItems = restaurantData['menu_items'] as Map?;
              
              if (menuItems != null) {
                for (var menuItem in menuItems.entries) {
                  final itemId = menuItem.key;
                  if (favoriteItemIds.contains(itemId)) {
                    final itemData = menuItem.value as Map;
                    favoriteItems.add({
                      'id': itemId,
                      'restaurantId': restaurantId,
                      'restaurantName': restaurantData['store_info']?['name'] ?? 'Unknown Restaurant',
                      ...itemData,
                    });
                  }
                }
              }
            }

            if (favoriteItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Favorite Items Found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add items to your favorites to see them here',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favoriteItems.length,
              itemBuilder: (context, index) {
                final item = favoriteItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => MenuItemDetailsDialog(
                          item: Map<String, dynamic>.from({
                            ...item,
                            'id': item['id'],
                          }),
                          restaurantId: item['restaurantId'],
                          restaurantName: item['restaurantName'],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item['imageURL'] != null
                                ? Image.network(
                                    item['imageURL'],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.restaurant,
                                          color: Colors.grey,
                                          size: 40,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          // Item Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name'] ?? 'Unnamed Item',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.favorite,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        try {
                                          await FirebaseDatabase.instance
                                              .ref()
                                              .child('customers')
                                              .child(FirebaseAuth.instance.currentUser?.uid ?? '')
                                              .child('favorites')
                                              .child(item['id'])
                                              .set(false);
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error removing from favorites: $e')),
                                            );
                                          }
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                Text(
                                  item['restaurantName'],
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                if (item['description'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item['description'],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  '\$${(item['price'] ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF4A261),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCustomizationDialog(Map item, String itemId) {
    showDialog(
      context: context,
      builder: (context) => CustomizationDialog(
        item: item,
        itemId: itemId,
        onSave: (Map<String, dynamic> updatedCustomizations) async {
          try {
            // Calculate new total price based on customizations
            double basePrice = (item['price'] ?? 0.0).toDouble();
            double customizationTotal = 0;
            
            // Sum up all customization prices
            updatedCustomizations.forEach((key, value) {
              if (value is Map && value['selected'] == true) {
                customizationTotal += (value['price'] ?? 0.0).toDouble();
              }
            });

            // Update cart item with new customizations and total price
            await FirebaseDatabase.instance
                .ref()
                .child('customers')
                .child(FirebaseAuth.instance.currentUser?.uid ?? '')
                .child('cart')
                .child(itemId)
                .update({
              'customizations': updatedCustomizations,
              'totalPrice': (basePrice + customizationTotal) * (item['quantity'] ?? 1),
            });

            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customizations updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating customizations: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _removeFromCart(String itemId) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(FirebaseAuth.instance.currentUser?.uid ?? '')
          .child('cart')
          .child(itemId)
          .remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item removed from cart'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing item from cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCartTab() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(FirebaseAuth.instance.currentUser?.uid ?? '')
          .child('cart')
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

        final cartItems = snapshot.data?.snapshot.value as Map?;
        if (cartItems == null || cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Cart is Empty',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add items to your cart to see them here',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate total price
        double totalPrice = 0;
        for (var item in cartItems.values) {
          totalPrice += (item['totalPrice'] ?? 0.0).toDouble();
        }

        return Column(
          children: [
            // Cart Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final itemId = cartItems.keys.elementAt(index);
                  final item = cartItems[itemId] as Map;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item['imageURL'] != null
                                ? Image.network(
                                    item['imageURL'],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.restaurant,
                                          color: Colors.grey,
                                          size: 32,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Colors.grey,
                                      size: 32,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          // Item Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Unnamed Item',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (item['customizations'] != null) ...[
                                  const SizedBox(height: 4),
                                  ...(item['customizations'] as List).map((customization) {
                                    if (customization == null) return const SizedBox.shrink();
                                    
                                    final selectedItems = customization['selectedItems'] as List?;
                                    if (selectedItems == null || selectedItems.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '${customization['optionName']}: ${selectedItems.map((item) => '${item['name']} (+\$${(item['price'] ?? 0.0).toStringAsFixed(2)})').join(', ')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                                if (item['specialInstructions'] != null && 
                                    item['specialInstructions'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Note: ${item['specialInstructions']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '\$${(item['totalPrice'] ?? 0.0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF4A261),
                                      ),
                                    ),
                                    Text(
                                      'Quantity: ${item['quantity'] ?? 1}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () => _removeFromCart(itemId),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Total Price and Checkout Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF4A261),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4A261),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutPage(
                              cartItems: Map<String, dynamic>.from(cartItems),
                              subtotal: totalPrice,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Proceed to Checkout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    return const Center(
      child: Text('Orders Tab'),
    );
  }

  Widget _buildAccountTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Account Tab'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4A261),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deligo'),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFF4A261),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
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

class CustomizationDialog extends StatefulWidget {
  final Map item;
  final String itemId;
  final Function(Map<String, dynamic>) onSave;

  const CustomizationDialog({
    super.key,
    required this.item,
    required this.itemId,
    required this.onSave,
  });

  @override
  State<CustomizationDialog> createState() => _CustomizationDialogState();
}

class _CustomizationDialogState extends State<CustomizationDialog> {
  late Map<String, dynamic> _customizations;

  @override
  void initState() {
    super.initState();
    _customizations = Map<String, dynamic>.from(widget.item['customizations'] ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Customize ${widget.item['name']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_customizations.isEmpty)
              const Text('No customization options available')
            else
              ..._customizations.entries.map((entry) {
                final option = entry.value as Map;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(option['options'] as List).map((opt) {
                      final isSelected = _customizations[entry.key]['selected'] == opt;
                      return CheckboxListTile(
                        title: Text(opt),
                        subtitle: Text(
                          '+\$${(option['price'] ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFFF4A261),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            _customizations[entry.key]['selected'] = value == true ? opt : null;
                          });
                        },
                      );
                    }).toList(),
                    const Divider(),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => widget.onSave(_customizations),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF4A261),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
} 