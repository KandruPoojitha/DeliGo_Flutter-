import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/restaurant_service.dart';
import '../models/restaurant.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RestaurantDocumentPage extends StatefulWidget {
  const RestaurantDocumentPage({super.key});

  @override
  State<RestaurantDocumentPage> createState() => _RestaurantDocumentPageState();
}

class _RestaurantDocumentPageState extends State<RestaurantDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantService = RestaurantService();
  final _user = FirebaseAuth.instance.currentUser;
  final _addressController = TextEditingController();
  final _minPriceController = TextEditingController(text: '10');
  final _maxPriceController = TextEditingController(text: '50');
  
  File? _licenseImage;
  File? _ownerIdImage;
  bool _isLoading = false;
  bool _isApproved = false;
  bool _isLoadingPlaces = false;
  List<Map<String, dynamic>> _predictions = [];
  Map<String, dynamic>? _selectedLocation;
  
  // Business hours
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);

  final String _apiKey = 'AIzaSyDHujk0Z7p3_mjmPsicmn7T9iyQBC0ZqtU'; // Replace with your API key

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _loadRestaurantData() async {
    if (_user != null) {
      final restaurant = await _restaurantService.getRestaurant(_user!.uid);
      if (restaurant != null) {
        setState(() {
          _isApproved = restaurant.isApproved;
          if (restaurant.address != null) {
            _addressController.text = restaurant.address!;
          }
        });
      }
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    setState(() {
      _isLoadingPlaces = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$query'
          '&key=$_apiKey'
          '&types=address'
          '&components=country:ca|country:us'
          '&language=en'
          '&sessiontoken=${_user?.uid}'
        ),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(
            data['predictions'].map((prediction) => {
              'description': prediction['description'],
              'place_id': prediction['place_id'],
              'structured_formatting': prediction['structured_formatting'],
            }),
          );
        });
      }
    } catch (e) {
      print('Error searching places: $e');
    } finally {
      setState(() {
        _isLoadingPlaces = false;
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&key=$_apiKey'
          '&fields=formatted_address,geometry,name,address_components'
          '&sessiontoken=${_user?.uid}'
        ),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final result = data['result'];
        setState(() {
          _selectedLocation = {
            'name': result['name'] ?? result['formatted_address'],
            'address': result['formatted_address'],
            'latitude': result['geometry']['location']['lat'],
            'longitude': result['geometry']['location']['lng'],
          };
          _addressController.text = result['formatted_address'];
          _predictions = [];
        });
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  Future<void> _pickImage(bool isLicense) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        if (isLicense) {
          _licenseImage = File(image.path);
        } else {
          _ownerIdImage = File(image.path);
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isOpening) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? _openingTime : _closingTime,
    );
    
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _submitForm() async {
    if (_licenseImage == null || _ownerIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both documents')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid address')),
      );
      return;
    }

    // Validate price range
    final minPrice = double.tryParse(_minPriceController.text);
    final maxPrice = double.tryParse(_maxPriceController.text);
    
    if (minPrice == null || maxPrice == null || minPrice >= maxPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid price range (min must be less than max)')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images to Firebase Storage
      final licenseUrl = await _restaurantService.uploadImage(
        _licenseImage!,
        'restaurants/${_user!.uid}/restaurant_proof.jpg',
      );
      
      final ownerIdUrl = await _restaurantService.uploadImage(
        _ownerIdImage!,
        'restaurants/${_user!.uid}/owner_id.jpg',
      );

      final now = DateTime.now().toIso8601String();

      // Format business hours
      final Map<String, dynamic> hours = {
        'opening': _formatTimeOfDay(_openingTime),
        'closing': _formatTimeOfDay(_closingTime),
        'isOpen': _openingTime.hour < _closingTime.hour || 
                  (_openingTime.hour == _closingTime.hour && _openingTime.minute < _closingTime.minute),
      };

      // Get current user data
      final userData = await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_user!.uid)
          .get();

      final userDataMap = userData.value as Map<dynamic, dynamic>? ?? {};
      
      // Get existing store_info or create new one
      final existingStoreInfo = userDataMap['store_info'] as Map<dynamic, dynamic>? ?? {};
      
      // Update store_info with new address and price range while preserving other fields
      final updatedStoreInfo = {
        ...existingStoreInfo,
        'address': _selectedLocation!['address'],
        'price_range': {
          'min': minPrice,
          'max': maxPrice,
        },
      };

      // Update restaurant information
      await FirebaseDatabase.instance
          .ref()
          .child('restaurants')
          .child(_user!.uid)
          .update({
        'documentsSubmitted': true,
        'documents': {
          'status': 'pending_review',
          'files': {
            'owner_id': {
              'url': ownerIdUrl,
              'uploadTime': now,
            },
            'restaurant_proof': {
              'url': licenseUrl,
              'uploadTime': now,
            }
          }
        },
        'store_info': updatedStoreInfo,
        'location': {
          'latitude': _selectedLocation!['latitude'],
          'longitude': _selectedLocation!['longitude'],
          'name': _selectedLocation!['name'],
        },
        'hours': hours,
        'updatedAt': now,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents and information submitted for approval')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBusinessHoursSection() {
    bool isValidHours = _openingTime.hour < _closingTime.hour || 
                       (_openingTime.hour == _closingTime.hour && _openingTime.minute < _closingTime.minute);
                       
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Hours',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (!isValidHours)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Opening time must be before closing time',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Opening Time:'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _selectTime(context, true),
                    icon: const Icon(Icons.access_time),
                    label: Text(_formatTimeOfDay(_openingTime)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Closing Time:'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _selectTime(context, false),
                    icon: const Icon(Icons.access_time),
                    label: Text(_formatTimeOfDay(_closingTime)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price Range',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _minPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Price (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter minimum price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _maxPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum Price (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter maximum price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Documents'),
      ),
      body: _isApproved
          ? const Center(
              child: Text('Your restaurant has been approved!'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Please upload your restaurant documents for verification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Restaurant Address
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Restaurant Address',
                        hintText: 'Search for your restaurant',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _searchPlaces,
                    ),
                    if (_isLoadingPlaces)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_predictions.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        margin: const EdgeInsets.only(top: 8),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _predictions.length,
                          itemBuilder: (context, index) {
                            final prediction = _predictions[index];
                            final structuredFormatting = prediction['structured_formatting'];
                            return ListTile(
                              title: Text(
                                structuredFormatting?['main_text'] ?? prediction['description'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                structuredFormatting?['secondary_text'] ?? '',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              onTap: () {
                                _getPlaceDetails(prediction['place_id']);
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Restaurant License
                    const Text('Restaurant License Image:'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(true),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                    if (_licenseImage != null) ...[
                      const SizedBox(height: 8),
                      Image.file(_licenseImage!, height: 100),
                    ],
                    const SizedBox(height: 24),

                    // Owner ID
                    const Text('Owner ID Image:'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(false),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Choose from Gallery'),
                    ),
                    if (_ownerIdImage != null) ...[
                      const SizedBox(height: 8),
                      Image.file(_ownerIdImage!, height: 100),
                    ],
                    const SizedBox(height: 32),

                    // Business Hours
                    _buildBusinessHoursSection(),
                    const SizedBox(height: 32),

                    // Price Range
                    _buildPriceRangeSection(),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Submit Documents and Information'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 