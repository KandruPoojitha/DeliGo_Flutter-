import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cart_service.dart';
import 'restaurant_reviews_page.dart';

class MenuItemDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final String restaurantId;
  final String restaurantName;

  const MenuItemDetailsDialog({
    super.key,
    required this.item,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<MenuItemDetailsDialog> createState() => _MenuItemDetailsDialogState();
}

class _MenuItemDetailsDialogState extends State<MenuItemDetailsDialog> {
  final _cartService = CartService();
  int quantity = 1;
  double basePrice = 0;
  double totalPrice = 0;
  Map<String, bool> selectedCustomizations = {};

  String _getPriceRangeText(Map<String, dynamic> item) {
    final price = item['price']?.toDouble() ?? 0.0;
    String dollarSigns = '\$';
    if (price > 30) {
      dollarSigns = '\$\$\$';
    } else if (price > 15) {
      dollarSigns = '\$\$';
    }
    return '$dollarSigns \$${price.toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    basePrice = widget.item['price']?.toDouble() ?? 0.0;
    totalPrice = basePrice;
    
    // Initialize customization options
    final customizations = widget.item['customizationOptions'];
    if (customizations != null) {
      final customizationsList = List<Map<String, dynamic>>.from(
        (customizations as List).map((item) => Map<String, dynamic>.from(item))
      );
      
      for (var customization in customizationsList) {
        if (customization['type'] == 'Single Selection') {
          final options = customization['options'] as List?;
          if (options != null && options.isNotEmpty && customization['isRequired'] == true) {
            final firstOption = Map<String, dynamic>.from(options.first);
            selectedCustomizations[firstOption['name']] = true;
          }
        }
      }
    }
    _updateTotalPrice();
  }

  void _updateTotalPrice() {
    double customizationPrice = 0;
    final customizations = widget.item['customizationOptions'];
    
    if (customizations != null) {
      final customizationsList = List<Map<String, dynamic>>.from(
        (customizations as List).map((item) => Map<String, dynamic>.from(item))
      );
      
      for (var customization in customizationsList) {
        final options = customization['options'] as List?;
        if (options != null) {
          for (var option in options) {
            final optionMap = Map<String, dynamic>.from(option);
            if (selectedCustomizations[optionMap['name']] == true) {
              customizationPrice += optionMap['price']?.toDouble() ?? 0.0;
            }
          }
        }
      }
    }
    
    setState(() {
      totalPrice = (basePrice + customizationPrice) * quantity;
    });
  }

  void _addToCart(Map<String, dynamic> itemData) async {
    try {
      // Format selected customizations
      Map<String, dynamic> formattedCustomizations = {};
      
      if (itemData['customizationOptions'] != null) {
        final customizationsList = itemData['customizationOptions'] as List;
        for (var customization in customizationsList) {
          final options = customization['options'] as List?;
          if (options != null) {
            List<Map<String, dynamic>> selectedItems = [];
            
            for (var option in options) {
              if (selectedCustomizations[option['name']] == true) {
                selectedItems.add({
                  'id': option['id'] ?? UniqueKey().toString(),
                  'name': option['name'],
                  'price': option['price'] ?? 0.0,
                });
              }
            }
            
            if (selectedItems.isNotEmpty) {
              final optionId = customization['id'] ?? UniqueKey().toString();
              formattedCustomizations[optionId] = {
                'optionId': optionId,
                'optionName': customization['name'] ?? 'Unknown Option',
                'price': selectedItems.fold(0.0, (sum, item) => sum + (item['price'] ?? 0.0)),
                'selectedItems': selectedItems,
              };
            }
          }
        }
      }

      // Create clean item data with only necessary fields
      final cleanItemData = {
        'id': itemData['id'],
        'name': itemData['name'],
        'description': itemData['description'] ?? '',
        'price': itemData['price'],
        'imageURL': itemData['imageURL'],
        'menuItemId': itemData['id'],
        'quantity': quantity,
        'totalPrice': totalPrice,
        'restaurantId': widget.restaurantId,
        'restaurantName': widget.restaurantName,
        'customizations': formattedCustomizations,
        'addedAt': ServerValue.timestamp,
      };

      await _cartService.addToCart(
        cleanItemData,
        widget.restaurantId,
        widget.restaurantName,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to cart: $e')),
        );
      }
    }
  }

  Widget _buildCustomizationSection(Map<String, dynamic> customization) {
    final options = customization['options'] as List?;
    if (options == null) return const SizedBox.shrink();

    final optionsList = List<Map<String, dynamic>>.from(
      options.map((item) => Map<String, dynamic>.from(item))
    );

    final title = customization['name'] as String? ?? 'Customization';
    final isSingleSelection = customization['type'] == 'Single Selection';
    final isRequired = customization['isRequired'] == true;
    final maxSelections = customization['maxSelections'] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (!isSingleSelection && maxSelections != null)
                Text(
                  ' (Select up to $maxSelections)',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
        ...optionsList.map((option) {
          final price = option['price']?.toDouble() ?? 0.0;
          return CheckboxListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(option['name'] ?? ''),
                if (price > 0)
                  Text(
                    '+\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFF4A261),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            value: selectedCustomizations[option['name']] ?? false,
            onChanged: (bool? value) {
              setState(() {
                if (isSingleSelection) {
                  // Uncheck all other options in this group
                  for (var opt in optionsList) {
                    selectedCustomizations[opt['name']] = false;
                  }
                } else if (maxSelections != null) {
                  // Check if we're at the max selections
                  final currentSelections = optionsList.where(
                    (opt) => selectedCustomizations[opt['name']] == true
                  ).length;
                  if (currentSelections >= maxSelections && value == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You can only select up to $maxSelections options'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                }
                selectedCustomizations[option['name']] = value ?? false;
                
                // If required and no option selected, select this one
                if (isRequired && isSingleSelection && !selectedCustomizations.values.contains(true)) {
                  selectedCustomizations[option['name']] = true;
                }
              });
              _updateTotalPrice();
            },
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with image or colored container
            Stack(
              children: [
                widget.item['imageURL'] != null
                    ? Image.network(
                        widget.item['imageURL'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: const Color(0xFFF4A261),
                            child: Center(
                              child: Text(
                                widget.item['name'] ?? 'Menu Item',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        height: 200,
                        color: const Color(0xFFF4A261),
                        child: Center(
                          child: Text(
                            widget.item['name'] ?? 'Menu Item',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                // Close button with semi-transparent background
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),

            // Rest of the dialog content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name (show only if image is present)
                  if (widget.item['imageURL'] != null)
                    Text(
                      widget.item['name'] ?? 'Menu Item',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Quantity Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: quantity > 1
                            ? () {
                                setState(() {
                                  quantity--;
                                  _updateTotalPrice();
                                });
                              }
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        quantity.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() {
                            quantity++;
                            _updateTotalPrice();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Customizations
                  if (widget.item['customizationOptions'] != null) ...[
                    const Divider(),
                    const Text(
                      'Customize Your Order',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(widget.item['customizationOptions'] as List)
                      .map((item) => _buildCustomizationSection(Map<String, dynamic>.from(item)))
                      .toList(),
                    const Divider(),
                  ],

                  // Total Price
                  const SizedBox(height: 16),
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

                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4A261),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => _addToCart(widget.item),
                      child: const Text(
                        'Add to Cart',
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
        ),
      ),
    );
  }
}

class RestaurantDetailsPage extends StatefulWidget {
  final String restaurantId;
  final Map<String, dynamic> restaurant;

  const RestaurantDetailsPage({
    super.key,
    required this.restaurantId,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _favoriteItems = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(userId)
          .child('favorites')
          .get();

      if (snapshot.exists) {
        final favorites = snapshot.value as Map;
        setState(() {
          _favoriteItems = Set<String>.from(favorites.keys);
        });
      }
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String itemId, Map<String, dynamic> itemData) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final isFavorite = _favoriteItems.contains(itemId);
      final ref = FirebaseDatabase.instance
          .ref()
          .child('customers')
          .child(userId)
          .child('favorites')
          .child(itemId);

      if (isFavorite) {
        await ref.remove();
        setState(() {
          _favoriteItems.remove(itemId);
        });
      } else {
        // Save complete item data including restaurant info
        final favoriteData = {
          ...itemData,
          'id': itemId,
          'restaurantId': widget.restaurantId,
          'restaurantName': widget.restaurant['store_info']?['name'] ?? 'Unknown Restaurant',
          'category': itemData['category'] ?? 'Uncategorized',
          'hasCustomizations': itemData['hasCustomizations'] ?? false,
          'customizationOptions': itemData['customizationOptions'] ?? [],
        };
        await ref.set(favoriteData);
        setState(() {
          _favoriteItems.add(itemId);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? 'Removed from favorites' : 'Added to favorites'),
          backgroundColor: isFavorite ? Colors.red : Colors.green,
        ),
      );
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorite: $e')),
      );
    }
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

  Widget _buildMenuItemCard(String itemId, Map<String, dynamic> item) {
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
              restaurantId: widget.restaurantId,
              restaurantName: widget.restaurant['fullName'] ?? '',
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
                        StreamBuilder(
                          stream: FirebaseDatabase.instance
                              .ref()
                              .child('customers')
                              .child(FirebaseAuth.instance.currentUser?.uid ?? '')
                              .child('favorites')
                              .child(itemId)
                              .onValue,
                          builder: (context, snapshot) {
                            final isFavorite = snapshot.data?.snapshot.value != null;
                            return IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.grey,
                              ),
                              onPressed: () => _toggleFavorite(itemId, Map<String, dynamic>.from(item)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            );
                          },
                        ),
                      ],
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant['store_info']?['name'] ?? 'Restaurant Details'),
        backgroundColor: const Color(0xFFF4A261),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Restaurant Info Header
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant Image
                Container(
                  height: 200,
                  width: double.infinity,
                  child: widget.restaurant['store_info']?['imageURL'] != null
                      ? Image.network(
                          widget.restaurant['store_info']?['imageURL'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFF4A261),
                              child: Center(
                                child: Text(
                                  widget.restaurant['store_info']?['name'] ?? 'Restaurant',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFFF4A261),
                          child: Center(
                            child: Text(
                              widget.restaurant['store_info']?['name'] ?? 'Restaurant',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
                // Restaurant Details
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.restaurant['store_info']?['name'] ?? 'Unnamed Restaurant',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Description
                      if (widget.restaurant['store_info']?['description'] != null) ...[
                        Text(
                          widget.restaurant['store_info']?['description'],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Address
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.restaurant['store_info']?['address'] ?? 'Address not available',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Operating Hours
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${widget.restaurant['store_info']?['openingTime'] ?? '9:00 AM'} - ${widget.restaurant['store_info']?['closingTime'] ?? '10:00 PM'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Various and Price Range Row
                      Row(
                        children: [
                          const Text(
                            'Various',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _getPriceRangeText(widget.restaurant['store_info'] ?? {}),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFF4A261),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Rating and Reviews Row
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RestaurantReviewsPage(
                                restaurantId: widget.restaurantId,
                                restaurantName: widget.restaurant['store_info']?['name'] ?? 'Restaurant',
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            StreamBuilder(
                              stream: FirebaseDatabase.instance
                                  .ref()
                                  .child('restaurants')
                                  .child(widget.restaurantId)
                                  .child('ratingsandcomments')
                                  .child('rating')
                                  .onValue,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
                                  final ratings = snapshot.data!.snapshot.value as Map;
                                  double totalRating = 0;
                                  int count = 0;
                                  
                                  ratings.forEach((key, value) {
                                    if (value is int) {
                                      totalRating += value;
                                      count++;
                                    }
                                  });
                                  
                                  final averageRating = count > 0 ? totalRating / count : 0.0;
                                  
                                  return Row(
                                    children: [
                                      Text(
                                        '${averageRating.toStringAsFixed(1)} ',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        '(${count.toString()})',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'View Reviews',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFFF4A261),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return const Text(
                                  'No reviews yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            child: StreamBuilder(
              stream: FirebaseDatabase.instance
                  .ref()
                  .child('restaurants')
                  .child(widget.restaurantId)
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

                if (menuItems == null || menuItems.isEmpty) {
                  return const Center(
                    child: Text('No menu items available'),
                  );
                }

                final filteredItems = _searchQuery.isEmpty
                    ? menuItems
                    : Map.fromEntries(
                        menuItems.entries.where((entry) {
                          final item = entry.value as Map;
                          final name = (item['name'] ?? '').toString().toLowerCase();
                          final description = (item['description'] ?? '').toString().toLowerCase();
                          final query = _searchQuery.toLowerCase();
                          return name.contains(query) || description.contains(query);
                        }),
                      );

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('No items match your search'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final itemId = filteredItems.keys.elementAt(index);
                    final item = filteredItems[itemId] as Map;
                    return _buildMenuItemCard(itemId, Map<String, dynamic>.from(item));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 
