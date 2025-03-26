import 'package:flutter/material.dart';
import '../services/cart_service.dart';

class MenuItemDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> menuItem;
  final String restaurantId;
  final String restaurantName;

  const MenuItemDetailsDialog({
    super.key,
    required this.menuItem,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<MenuItemDetailsDialog> createState() => _MenuItemDetailsDialogState();
}

class _MenuItemDetailsDialogState extends State<MenuItemDetailsDialog> {
  final Map<String, bool> _selectedCustomizations = {};
  final _cartService = CartService();
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    // Initialize selected customizations
    if (widget.menuItem['customizations'] != null) {
      final customizations = widget.menuItem['customizations'] as Map;
      customizations.forEach((key, customization) {
        if (customization is Map && customization['selectedItems'] != null) {
          final selectedItems = customization['selectedItems'] as List;
          for (var item in selectedItems) {
            _selectedCustomizations[item['name']] = true;
          }
        }
      });
    }
  }

  Future<void> _addToCart() async {
    setState(() {
      _isAddingToCart = true;
    });

    try {
      // Structure customizations properly
      Map<String, dynamic> formattedCustomizations = {};
      
      if (widget.menuItem['customizations'] != null) {
        final customizations = widget.menuItem['customizations'] as Map;
        
        customizations.forEach((optionId, option) {
          if (option is Map && option['selectedItems'] != null) {
            List<Map<String, dynamic>> selectedItems = [];
            
            for (var item in option['selectedItems'] as List) {
              if (_selectedCustomizations[item['name']] == true) {
                selectedItems.add({
                  'id': item['id'],
                  'name': item['name'],
                  'price': item['price'] ?? 0.0,
                });
              }
            }
            
            if (selectedItems.isNotEmpty) {
              double optionTotalPrice = 0.0;
              for (var item in selectedItems) {
                optionTotalPrice += (item['price'] ?? 0.0);
              }
              
              formattedCustomizations[optionId] = {
                'optionId': optionId,
                'optionName': option['optionName'] ?? 'Unknown Option',
                'price': optionTotalPrice,
                'selectedItems': selectedItems,
              };
            }
          }
        });
      }
      
      final menuItemWithCustomizations = {
        'id': widget.menuItem['id'],
        'name': widget.menuItem['name'],
        'description': widget.menuItem['description'] ?? '',
        'price': widget.menuItem['price'],
        'imageURL': widget.menuItem['imageURL'] ?? widget.menuItem['imageUrl'],
        'menuItemId': widget.menuItem['id'],
        'customizations': formattedCustomizations,
      };

      // Safety check - explicitly remove any customizationOptions
      if (menuItemWithCustomizations.containsKey('customizationOptions')) {
        menuItemWithCustomizations.remove('customizationOptions');
      }

      await _cartService.addToCart(
        menuItemWithCustomizations,
        widget.restaurantId,
        widget.restaurantName,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item added to cart'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              if (widget.menuItem['imageUrl'] != null) ...[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    widget.menuItem['imageUrl'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.menuItem['imageUrl'] == null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
                Text(
                  widget.menuItem['name'] ?? 'Unnamed Item',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.menuItem['description'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '\$${(widget.menuItem['price'] ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF4A261),
                  ),
                ),
                if (widget.menuItem['customizations'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Customizations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(widget.menuItem['customizations'] as Map).entries.map((entry) {
                    final customization = entry.value;
                    if (customization is! Map) return const SizedBox.shrink();
                    
                    final selectedItems = customization['selectedItems'] as List?;
                    if (selectedItems == null) return const SizedBox.shrink();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customization['optionName'] ?? 'Option',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: selectedItems.map<Widget>((item) {
                            return FilterChip(
                              label: Text(item['name']),
                              selected: _selectedCustomizations[item['name']] ?? false,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCustomizations[item['name']] = selected;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4A261),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isAddingToCart ? null : _addToCart,
                    child: _isAddingToCart
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
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
    );
  }
} 