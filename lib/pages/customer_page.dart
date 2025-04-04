import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';
import 'restaurant_details_page.dart';
import 'checkout_page.dart';
import 'support_chat_detail.dart';
import 'edit_customer_profile_page.dart';
import 'receipt_screen.dart';
import 'order_chat_page.dart';
import '../widgets/unread_message_count.dart';
import '../services/notification_service.dart';
// import 'package:share_plus/share_plus.dart';

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
  String _sortBy = 'none';
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _setupOrderStatusListeners();
    _listenForNewOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notificationService.cancelAllOrderStatusListeners();
    super.dispose();
  }

  Future<void> _setupOrderStatusListeners() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final ordersSnapshot = await _database
          .ref()
          .child('orders')
          .orderByChild('customerId')
          .equalTo(userId)
          .get();

      if (!ordersSnapshot.exists) return;

      final orders = ordersSnapshot.value as Map<dynamic, dynamic>;
      for (final entry in orders.entries) {
        final order = entry.value as Map<dynamic, dynamic>;
        final orderId = entry.key as String;
        final orderStatus = order['order_status'] as String?;

        // Only set up listeners for pending orders
        if (orderStatus == 'pending') {
          _notificationService.listenForOrderStatusChanges(
            orderId: orderId,
            userId: userId,
            context: context,
          );
        }
      }
    } catch (e) {
      debugPrint('Error setting up order status listeners: $e');
    }
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

  String _getPriceRangeValue(Map<dynamic, dynamic> storeInfo) {
    final priceRange = storeInfo['price_range'] as Map?;
    if (priceRange == null) return '25'; // Default max value
    return (priceRange['max']?.toString() ?? '25');
  }

  void _sortRestaurantsByPrice(String order) {
    setState(() {
      _sortBy = order;
      if (order == 'none') return;

      _filteredRestaurants.sort((a, b) {
        final restaurantA = a.value as Map;
        final restaurantB = b.value as Map;
        final storeInfoA = restaurantA['store_info'] as Map? ?? {};
        final storeInfoB = restaurantB['store_info'] as Map? ?? {};
        
        final priceA = double.tryParse(_getPriceRangeValue(storeInfoA)) ?? 25;
        final priceB = double.tryParse(_getPriceRangeValue(storeInfoB)) ?? 25;
        
        return order == 'lowToHigh' 
            ? priceA.compareTo(priceB) 
            : priceB.compareTo(priceA);
      });
    });
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
        // Sorting Options Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Sort by Distance Button
              Expanded(
                child: TextButton.icon(
                  onPressed: _currentPosition != null
                      ? () {
                          setState(() {
                            _sortBy = 'distance';
                            _sortRestaurantsByDistance();
                          });
                        }
                      : null,
                  icon: const Icon(Icons.sort),
                  label: const Text('Sort by Distance'),
                  style: TextButton.styleFrom(
                    foregroundColor: _sortBy == 'distance' 
                        ? const Color(0xFFF4A261) 
                        : Colors.grey,
                  ),
                ),
              ),
              // Sort by Price Range Button
              TextButton.icon(
                onPressed: () {
                  showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      MediaQuery.of(context).size.width - 100,
                      kToolbarHeight + 100,
                      20,
                      0,
                    ),
                    items: [
                      const PopupMenuItem(
                        value: 'none',
                        child: Text('Default Order'),
                      ),
                      const PopupMenuItem(
                        value: 'lowToHigh',
                        child: Text('Price: Low to High'),
                      ),
                      const PopupMenuItem(
                        value: 'highToLow',
                        child: Text('Price: High to Low'),
                      ),
                    ],
                  ).then((value) {
                    if (value != null) {
                      _sortRestaurantsByPrice(value);
                    }
                  });
                },
                icon: const Icon(Icons.sort),
                label: Text(
                  'Price Range',
                  style: TextStyle(
                    color: _sortBy == 'lowToHigh' || _sortBy == 'highToLow'
                        ? const Color(0xFFF4A261)
                        : Colors.grey,
                  ),
                ),
              ),
            ],
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  storeInfo['name'] ?? 'Unnamed Restaurant',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text(
                                      'Various',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Text(
                                      ' • ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _getPriceRangeText(storeInfo),
                                      style: const TextStyle(
                                        color: Color(0xFFF4A261),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                          StreamBuilder(
                            stream: FirebaseDatabase.instance
                                .ref()
                                .child('restaurants')
                                .child(entry.key)
                                .child('ratingsandcomments')
                                .child('rating')
                                .onValue,
                            builder: (context, snapshot) {
                              double rating = 0.0;
                              int reviewCount = 0;
                              
                              if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                                final ratings = snapshot.data!.snapshot.value as Map;
                                double totalRating = 0;
                                
                                ratings.forEach((key, value) {
                                  if (value is int) {
                                    totalRating += value;
                                    reviewCount++;
                                  }
                                });
                                
                                if (reviewCount > 0) {
                                  rating = totalRating / reviewCount;
                                }
                              }
                              
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '($reviewCount)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              );
                            },
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
                              // Display discount if available
                              if (restaurant['discount'] != null && (restaurant['discount'] as int) > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.discount,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${restaurant['discount']}% OFF',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(_auth.currentUser?.uid ?? '')
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

        final favoriteItems = favorites.entries.toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: favoriteItems.length,
          itemBuilder: (context, index) {
            final item = favoriteItems[index].value as Map<dynamic, dynamic>;
            final itemId = favoriteItems[index].key;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => MenuItemDetailsDialog(
                      item: Map<String, dynamic>.from({
                        ...item,
                        'id': itemId,
                      }),
                      restaurantId: item['restaurantId'] ?? '',
                      restaurantName: item['restaurantName'] ?? '',
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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

                              ],
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
                                    .child(_auth.currentUser?.uid ?? '')
                                    .child('favorites')
                                    .child(itemId)
                                    .remove();
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Removed from favorites'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error removing from favorites: $e')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      if (item['description'] != null) ...[
                        const SizedBox(height: 8),
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
              ),
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
                                  Builder(
                                    builder: (context) {
                                      final customizations = item['customizations'];
                                      if (customizations is Map) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: customizations.entries.map<Widget>((entry) {
                                            final option = entry.value;
                                            if (option == null || !(option is Map)) return const SizedBox.shrink();
                                            
                                            final selectedItems = option['selectedItems'] as List?;
                                            if (selectedItems == null || selectedItems.isEmpty) {
                                              return const SizedBox.shrink();
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                '${option['optionName']}: ${selectedItems.map((item) => '${item['name']} (+\$${(item['price'] ?? 0.0).toStringAsFixed(2)})').join(', ')}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      } else {
                                        return const SizedBox.shrink();
                                      }
                                    },
                                  ),
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
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('orders')
          .orderByChild('customerId')
          .equalTo(FirebaseAuth.instance.currentUser?.uid)
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
    return const Center(
            child: Text(
              'No orders',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }
        
        try {
          final data = snapshot.data!.snapshot.value;
          if (data == null) {
            return const Center(
              child: Text(
                'No orders',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }
          
          final ordersData = data as Map<dynamic, dynamic>;
          final allOrders = ordersData.entries.toList();
          
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Current'),
                    Tab(text: 'Past'),
                  ],
                  labelColor: Colors.black,
                  indicatorColor: Color(0xFFF4A261),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOrdersList(
                        allOrders.where((entry) {
                          final order = entry.value as Map<dynamic, dynamic>;
                          final orderStatus = order['order_status'] as String?;
                          return orderStatus != 'delivered';
                        }).toList(),
                        'No current orders',
                      ),
                      _buildOrdersList(
                        allOrders.where((entry) {
                          final order = entry.value as Map<dynamic, dynamic>;
                          final orderStatus = order['order_status'] as String?;
                          return orderStatus == 'delivered';
                        }).toList(),
                        'No past orders',
                        isPastOrders: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } catch (e) {
          return Center(
            child: Text('Error loading orders: $e'),
          );
        }
      },
    );
  }

  Widget _buildOrdersList(List<MapEntry> orders, String emptyMessage, {bool isPastOrders = false}) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    // Set up notifications for pending orders
    if (!isPastOrders) {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        for (final entry in orders) {
          final order = entry.value as Map<dynamic, dynamic>;
          final orderId = entry.key as String;
          final orderStatus = order['order_status'] as String?;
          
          // Only set up listeners for pending orders
          if (orderStatus == 'pending') {
            _notificationService.listenForOrderStatusChanges(
              orderId: orderId,
              userId: userId,
              context: context,
            );
          }
        }
      }
    }

    if (isPastOrders) {
      // Sort past orders by date (newest first)
      orders.sort((a, b) {
        final orderA = a.value as Map<dynamic, dynamic>;
        final orderB = b.value as Map<dynamic, dynamic>;
        final dateA = orderA['updatedAt'];
        final dateB = orderB['updatedAt'];
        
        // Handle both int and String timestamps
        final aTime = dateA is int ? dateA : (dateA is String ? DateTime.parse(dateA).millisecondsSinceEpoch : 0);
        final bTime = dateB is int ? dateB : (dateB is String ? DateTime.parse(dateB).millisecondsSinceEpoch : 0);
        
        return bTime.compareTo(aTime);
      });
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index].value as Map<dynamic, dynamic>;
        final orderId = orders[index].key as String;
        final orderStatus = order['order_status'] as String?;
        final items = order['items'] as List<dynamic>? ?? [];
        final subtotal = (order['subtotal'] as num?)?.toDouble() ?? 0.0;
        final deliveryFee = (order['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        final total = (order['total'] as num?)?.toDouble() ?? 0.0;
        final driverId = order['driverId'] as String?;
        final restaurantId = order['restaurantId'] as String?;
        final restaurantName = order['restaurantName'] as String? ?? 'Restaurant';
        final hasRatedDriver = order['hasRatedDriver'] == true;
        final hasRatedRestaurant = order['hasRatedRestaurant'] == true;
        
        // Get the nested address structure
        final addressData = order['address'] as Map<dynamic, dynamic>?;
        String addressText = 'No delivery address';
        String? instructions;
        
        if (addressData != null) {
          final street = addressData['street'] as String?;
          final unit = addressData['unit'] as String?;
          instructions = addressData['instructions'] as String?;
          
          if (street != null) {
            if (unit != null && unit.isNotEmpty) {
              addressText = "Unit $unit, $street";
            } else {
              addressText = street;
            }
          }
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Order #$orderId',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isPastOrders && orderStatus == 'delivered')
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.receipt_long),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReceiptScreen(
                                    orderData: {
                                      'orderId': orderId.toString(),
                                      'items': List<Map<String, dynamic>>.from(
                                        (items).map((item) => {
                                          'name': (item as Map)['name']?.toString() ?? '',
                                          'quantity': (item['quantity'] as num?)?.toInt() ?? 1,
                                          'price': (item['price'] as num?)?.toDouble() ?? 0.0,
                                        }),
                                      ),
                                      'subtotal': subtotal,
                                      'deliveryFee': deliveryFee,
                                      'total': total,
                                      'createdAt': order['createdAt']?.toString() ?? '',
                                      'deliveryAddress': addressText,
                                      'restaurantName': restaurantName,
                                    },
                                  ),
                                ),
                              );
                            },
                            tooltip: 'View Receipt',
                            color: const Color(0xFFF4A261),
                          ),
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrderChatPage(
                                        orderId: orderId,
                                        restaurantId: restaurantId ?? '',
                                        restaurantName: restaurantName,
                                        customerName: order['customerName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Customer',
                                        userType: 'customer',
                                      ),
                                    ),
                                  );
                                },
                                tooltip: 'Chat with Restaurant',
                                color: const Color(0xFFF4A261),
                              ),
                              Positioned(
                                right: 5,
                                top: 5,
                                child: UnreadMessageCount(
                                  orderId: orderId,
                                  userType: 'customer',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(width: 8),
                    _buildStatusChip(orderStatus ?? 'unknown'),
                  ],
                ),
                const Divider(),
                // Delivery Address
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Color(0xFFF4A261)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        addressText,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (instructions != null && instructions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.note, size: 16, color: Color(0xFFF4A261)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Instructions: $instructions",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Driver chat option for picked_up orders
                if (!isPastOrders && orderStatus == 'picked_up' && driverId != null) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      StreamBuilder<DatabaseEvent>(
                        stream: FirebaseDatabase.instance
                            .ref()
                            .child('drivers')
                            .child(driverId)
                            .onValue,
                        builder: (context, snapshot) {
                          String driverName = 'Driver';
                          
                          if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                            final driverData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                            driverName = driverData['fullName'] ?? 'Driver';
                          }
                          
                          return ElevatedButton.icon(
                            icon: StreamBuilder<DatabaseEvent>(
                              stream: FirebaseDatabase.instance
                                  .ref()
                                  .child('orders')
                                  .child(orderId)
                                  .child('driver_customer_messages')
                                  .onValue,
                              builder: (context, snapshot) {
                                int messageCount = 0;
                                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                                  final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
                                  if (data != null) {
                                    messageCount = data.length;
                                  }
                                }
                                
                                return Stack(
                                  children: [
                                    const Icon(Icons.delivery_dining),
                                    if (messageCount > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 14,
                                            minHeight: 14,
                                          ),
                                          child: Text(
                                            messageCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            label: Text('Chat with $driverName'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _openChatWithDriver(
                              orderId,
                              driverId,
                              driverName,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                // Restaurant Rating Section - Only show for delivered orders
                if (isPastOrders && restaurantId != null && orderStatus == 'delivered') ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Restaurant Rating',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      hasRatedRestaurant
                        ? const Text(
                            'Thank you for rating!',
                            style: TextStyle(
                              color: Colors.green,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              _showRateRestaurantDialog(
                                context, 
                                restaurantId, 
                                restaurantName, 
                                orderId
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF4A261),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: const Text('Rate Restaurant'),
                          ),
                    ],
                  ),
                ],
                // Driver Details (for past orders)
                if (isPastOrders && driverId != null) ...[
                  const Divider(),
                  const Text(
                    'Delivery Driver',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref()
                        .child('drivers')
                        .child(driverId)
                        .onValue,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        );
                      }
                      
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data?.snapshot.value == null) {
                        return const Text('Driver information not available');
                      }
                      
                      final driverData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                      final driverName = driverData['fullName'] ?? 'Unknown Driver';
                      final driverPhone = driverData['phone'] ?? 'No phone';
                      final driverEmail = driverData['email'] ?? 'No email';
                      final driverProfilePic = driverData['profilePicture'] as String?;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  image: driverProfilePic != null && driverProfilePic.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(driverProfilePic),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                ),
                                child: driverProfilePic == null || driverProfilePic.isEmpty
                                  ? const Icon(Icons.person, color: Colors.grey, size: 30)
                                  : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driverName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (driverPhone != 'No phone')
                                      Text(
                                        driverPhone,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // Rating Section - Only show for delivered orders and if not yet rated
                          if (orderStatus == 'delivered') ...[
                            const SizedBox(height: 12),
                            hasRatedDriver
                              ? const Text(
                                  'Thank you for rating this driver!',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    _showRateDriverDialog(
                                      context, 
                                      driverId, 
                                      driverName, 
                                      orderId
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF4A261),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Rate Driver'),
                                ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
                const Divider(),
                // Order Items
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  if (item is! Map<dynamic, dynamic>) return const SizedBox.shrink();
                  
                  final quantity = item['quantity'] as int? ?? 1;
                  final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                  final name = item['name'] as String? ?? 'Unknown Item';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name x$quantity',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '\$${(price * quantity).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const Divider(),
                // Pricing Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text('\$${subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivery Fee'),
                    Text('\$${deliveryFee.toStringAsFixed(2)}'),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFF4A261),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to show rate restaurant dialog
  void _showRateRestaurantDialog(BuildContext context, String restaurantId, String restaurantName, String orderId) {
    int rating = 5;
    final commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Rate $restaurantName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How was your dining experience?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: index < rating ? Colors.amber : Colors.grey,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comments (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _submitRestaurantRating(restaurantId, rating, commentController.text, orderId);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4A261),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Method to submit restaurant rating to Firebase
  Future<void> _submitRestaurantRating(String restaurantId, int rating, String comment, String orderId) async {
    try {
      final customerId = FirebaseAuth.instance.currentUser?.uid;
      
      if (customerId == null) {
        throw Exception('User not logged in');
      }
      
      // Update the ratings and comments in the restaurant document
      final restaurantRef = FirebaseDatabase.instance.ref().child('restaurants').child(restaurantId);
      
      // Create the ratings path if it doesn't exist
      final ratingsRef = restaurantRef.child('ratingsandcomments');
      
      // Add the rating, comment, and timestamp
      if (comment.isNotEmpty) {
        await ratingsRef.child('comment').child(customerId).set(comment);
      }
      
      await ratingsRef.child('rating').child(customerId).set(rating);
      await ratingsRef.child('timestamp').child(customerId).set(ServerValue.timestamp);
      
      // Update the average rating for the restaurant
      final ratingSnapshot = await ratingsRef.child('rating').get();
      if (ratingSnapshot.exists) {
        final ratingsData = ratingSnapshot.value as Map<dynamic, dynamic>;
        double totalRating = 0;
        int count = 0;
        
        ratingsData.forEach((key, value) {
          if (value is int) {
            totalRating += value;
            count++;
          }
        });
        
        if (count > 0) {
          double averageRating = totalRating / count;
          await restaurantRef.child('store_info').child('rating').set(averageRating);
        }
      }
      
      // Mark the order as restaurant rated
      await FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId)
          .update({'hasRatedRestaurant': true});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for rating the restaurant!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to show rate driver dialog
  void _showRateDriverDialog(BuildContext context, String driverId, String driverName, String orderId) {
    int rating = 5;
    final commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Rate $driverName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How was your delivery experience?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: index < rating ? Colors.amber : Colors.grey,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comments (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _submitDriverRating(driverId, rating, commentController.text, orderId);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4A261),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Update the existing method to mark orders as driver rated
  Future<void> _submitDriverRating(String driverId, int rating, String comment, String orderId) async {
    try {
      final customerId = FirebaseAuth.instance.currentUser?.uid;
      
      if (customerId == null) {
        throw Exception('User not logged in');
      }
      
      // Update the ratings and comments in the driver document
      final driverRef = FirebaseDatabase.instance.ref().child('drivers').child(driverId);
      
      // Create the ratings path if it doesn't exist
      final ratingsRef = driverRef.child('ratingsandcomments');
      
      // Add the rating and comment
      if (comment.isNotEmpty) {
        await ratingsRef.child('comment').child(customerId).set(comment);
      }
      
      await ratingsRef.child('rating').child(customerId).set(rating);
      
      // Update the average rating for the driver
      final ratingSnapshot = await ratingsRef.child('rating').get();
      if (ratingSnapshot.exists) {
        final ratingsData = ratingSnapshot.value as Map<dynamic, dynamic>;
        double totalRating = 0;
        int count = 0;
        
        ratingsData.forEach((key, value) {
          if (value is int) {
            totalRating += value;
            count++;
          }
        });
        
        if (count > 0) {
          double averageRating = totalRating / count;
          await driverRef.child('rating').set(averageRating);
        }
      }
      
      // Mark the order as driver rated
      await FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(orderId)
          .update({'hasRatedDriver': true});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for rating your driver!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'accepted':
        color = Colors.blue;
        label = 'Accepted';
        break;
      case 'ready_for_pickup':
        color = Colors.purple;
        label = 'Ready for Pickup';
        break;
      case 'assigned_driver':
        color = Colors.indigo;
        label = 'Assigned to Driver';
        break;
      case 'driver_accepted':
        color = Colors.blue;
        label = 'Driver Accepted';
        break;
      case 'picked_up':
        color = Colors.orange;
        label = 'Picked Up';
        break;
      case 'delivered':
        color = Colors.green;
        label = 'Delivered';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Information Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref()
                        .child('customers')
                        .child(FirebaseAuth.instance.currentUser?.uid ?? '')
                        .onValue,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                        final userData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFF4A261),
                                      child: Icon(Icons.person, color: Colors.white),
                                    ),
                                    title: Text(userData['fullName'] ?? 'Customer'),
                                    subtitle: Text(userData['email'] ?? ''),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditCustomerProfilePage(
                                          customerId: FirebaseAuth.instance.currentUser?.uid ?? '',
                                          currentName: userData['fullName'] ?? '',
                                          currentPhone: userData['phone'] ?? '',
                                        ),
                                      ),
                                    );
                                    
                                    if (result == true) {
                                      setState(() {}); // Refresh the page
                                    }
                                  },
                                  color: const Color(0xFFF4A261),
                                ),
                              ],
                            ),
                            const Divider(),
                            _buildInfoRow('Phone', userData['phone'] ?? 'Not provided'),
                            _buildInfoRow('Address', userData['address'] ?? 'Not provided'),
                          ],
                        );
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Support Card
          Card(
            elevation: 2,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupportChatDetail(
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      userName: FirebaseAuth.instance.currentUser?.displayName ?? 'Customer',
                      userType: 'customer',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4A261).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.support_agent,
                        color: Color(0xFFF4A261),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Chat with our support team',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Share App Card
          Card(
            elevation: 2,
            child: InkWell(
              onTap: () {
                _showShareAppDialog();
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4A261).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.share,
                        color: Color(0xFFF4A261),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share App',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Invite friends to use DeliGo',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4A261),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
          ),
          ),
        ],
      ),
    );
  }

  String _getPriceRangeText(Map<dynamic, dynamic> storeInfo) {
    final priceRange = storeInfo['price_range'] as Map?;
    if (priceRange == null) return '\$\$ \$5-25'; // Default value
    
    final min = priceRange['min']?.toString() ?? '5';
    final max = priceRange['max']?.toString() ?? '25';
    
    // Determine number of dollar signs based on max price
    String dollarSigns = '\$';
    if (double.parse(max) > 30) {
      dollarSigns = '\$\$\$';
    } else if (double.parse(max) > 15) {
      dollarSigns = '\$\$';
    }
    
    return '$dollarSigns \$$min-$max';
  }

  void _showShareAppDialog() {
    final String appLink = 'https://play.google.com/store/apps/details?id=com.deligo.app';
    final String shareMessage = 'Hey! I\'ve been using DeliGo for food delivery and it\'s amazing! Give it a try: $appLink';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.share, color: Color(0xFFF4A261)),
            const SizedBox(width: 8),
            const Text('Share DeliGo'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Copy the link or message and share it with your friends and family:',
                style: TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        appLink,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: appLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                            backgroundColor: Color(0xFFF4A261),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      tooltip: 'Copy to clipboard',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Copy text for:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Email
                  _buildShareOption(
                    icon: Icons.email,
                    label: 'Email',
                    color: Colors.red,
                    onTap: () => _shareViaEmail(shareMessage),
                  ),
                  // WhatsApp
                  _buildShareOption(
                    icon: Icons.chat_bubble,
                    label: 'WhatsApp',
                    color: Colors.green,
                    onTap: () => _launchURL('whatsapp://send?text=${Uri.encodeComponent(shareMessage)}'),
                  ),
                  // SMS
                  _buildShareOption(
                    icon: Icons.sms,
                    label: 'SMS',
                    color: Colors.blue,
                    onTap: () => _launchURL('sms:?body=${Uri.encodeComponent(shareMessage)}'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Twitter/X
                  _buildShareOption(
                    icon: Icons.message,
                    label: 'Twitter',
                    color: Colors.lightBlue,
                    onTap: () => _launchURL('https://twitter.com/intent/tweet?text=${Uri.encodeComponent(shareMessage)}'),
                  ),
                  // Facebook
                  _buildShareOption(
                    icon: Icons.thumb_up,
                    label: 'Facebook',
                    color: Colors.indigo,
                    onTap: () => _launchURL('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(appLink)}'),
                  ),
                  // Instagram
                  _buildShareOption(
                    icon: Icons.camera_alt,
                    label: 'Instagram',
                    color: Colors.purple,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copy the link and share on Instagram'),
                        backgroundColor: Color(0xFFF4A261),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            radius: 22,
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            'Copy for $label',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _shareViaEmail(String message) {
    final String emailText = 'Subject: Check out DeliGo Food Delivery App\n\n$message';
    Clipboard.setData(ClipboardData(text: emailText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email text copied to clipboard. Paste it in your email app.'),
          backgroundColor: Color(0xFFF4A261),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _launchURL(String urlString) async {
    try {
      // Due to platform-specific issues, we'll use clipboard instead
      Clipboard.setData(ClipboardData(text: urlString));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link copied to clipboard: $urlString'),
            backgroundColor: const Color(0xFFF4A261),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  // Method to open the chat dialog with driver
  void _openChatWithDriver(String orderId, String driverId, String driverName) {
    showDialog(
      context: context,
      builder: (context) => CustomerDriverChatDialog(
        orderId: orderId,
        driverId: driverId,
        driverName: driverName,
        customerId: FirebaseAuth.instance.currentUser?.uid ?? '',
        customerName: FirebaseAuth.instance.currentUser?.displayName ?? 'Customer',
      ),
    );
  }

  Future<void> _listenForNewOrders() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Listen for new orders
    _database
        .ref()
        .child('orders')
        .orderByChild('customerId')
        .equalTo(userId)
        .onChildAdded
        .listen((event) {
      if (!event.snapshot.exists) return;

      final order = event.snapshot.value as Map<dynamic, dynamic>?;
      if (order == null) return;

      final orderId = event.snapshot.key as String;
      final orderStatus = order['order_status'] as String?;

      // Set up listener for pending orders
      if (orderStatus == 'pending') {
        _notificationService.listenForOrderStatusChanges(
          orderId: orderId,
          userId: userId,
          context: context,
        );
      }
    });
  }
}

// Dialog for customer to chat with driver
class CustomerDriverChatDialog extends StatefulWidget {
  final String orderId;
  final String driverId;
  final String driverName;
  final String customerId;
  final String customerName;

  const CustomerDriverChatDialog({
    Key? key,
    required this.orderId,
    required this.driverId,
    required this.driverName,
    required this.customerId,
    required this.customerName,
  }) : super(key: key);

  @override
  _CustomerDriverChatDialogState createState() => _CustomerDriverChatDialogState();
}

class _CustomerDriverChatDialogState extends State<CustomerDriverChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  late Stream<DatabaseEvent> _messagesStream;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Set up the stream for driver-customer messages within the orders reference
    _messagesStream = FirebaseDatabase.instance
        .ref()
        .child('orders')
        .child(widget.orderId)
        .child('driver_customer_messages')
        .onValue;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);

    try {
      // Create a new message entry under the specific order
      final ref = FirebaseDatabase.instance
          .ref()
          .child('orders')
          .child(widget.orderId)
          .child('driver_customer_messages')
          .push();

      await ref.set({
        'message': message,
        'senderId': widget.customerId,
        'senderName': widget.customerName,
        'senderType': 'customer',
        'timestamp': ServerValue.timestamp,
        'driverId': widget.driverId,
      });

      // Clear the message field
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Chat with ${widget.driverName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Messages list
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final messagesData = snapshot.data?.snapshot.value;
                  if (messagesData == null) {
                    return const Center(child: Text('No messages yet'));
                  }

                  final List<Map<String, dynamic>> messages = [];
                  
                  // Convert the Firebase data structure to a list
                  if (messagesData is Map<dynamic, dynamic>) {
                    messagesData.forEach((key, value) {
                      if (value is Map) {
                        final message = Map<String, dynamic>.from(value);
                        message['id'] = key;
                        messages.add(message);
                      }
                    });
                  } else {
                    return const Center(child: Text('No messages yet'));
                  }
                  
                  // Sort by timestamp
                  messages.sort((a, b) {
                    final timestampA = a['timestamp'] as int? ?? 0;
                    final timestampB = b['timestamp'] as int? ?? 0;
                    return timestampA.compareTo(timestampB);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isCustomer = message['senderType'] == 'customer';
                      final timestamp = message['timestamp'] as int? ?? 0;
                      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
                      
                      return Align(
                        alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCustomer ? Colors.blue[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message['message'] as String? ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Message input
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.blue),
                    onPressed: _sending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 

// Dialog for customizing menu items
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